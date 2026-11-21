"""Carga de las huellas de edificios de Microsoft (Colombia) a MongoDB.

Uso (desde la raíz del repositorio o desde src/3-buildings-microsoft):
    uv run --project src/3-buildings-microsoft python src/3-buildings-microsoft/load_microsoft.py --limit-files 1 --dry-run
    uv run --project src/3-buildings-microsoft python src/3-buildings-microsoft/load_microsoft.py --batch-size 5000 --tag full
    uv run --project src/3-buildings-microsoft python src/3-buildings-microsoft/load_microsoft.py --index-first --tag indice_antes

Requiere que municipalities_pdet ya esté cargada (prepare-pdet.py).
Si dataset-links.csv no existe localmente, se descarga automáticamente.
"""

import argparse
import gzip
import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import psutil
import shapely
from pymongo import ASCENDING, DESCENDING, GEOSPHERE, MongoClient
from pymongo.errors import BulkWriteError
from shapely.geometry import mapping, shape

REPO_ROOT = Path(__file__).resolve().parents[2]
DATASET_LINKS_URL = (
    "https://minedbuildings.z5.web.core.windows.net/global-buildings/dataset-links.csv"
)


def fallar(msg):
    print(f"[ERROR] {msg}")
    sys.exit(1)


def leer_municipios(db):
    docs = list(db["municipalities_pdet"].find({}, {"cod_dane_mpio": 1, "geometry": 1}))
    if len(docs) != 170:
        fallar(
            f"municipalities_pdet tiene {len(docs)} docs, se esperaban 170. ¿Corriste prepare-pdet.py?"
        )
    return gpd.GeoDataFrame(
        {"cod_dane_mpio": [d["cod_dane_mpio"] for d in docs]},
        geometry=[shape(d["geometry"]) for d in docs],
        crs=4326,
    )


def bajar(url, destino: Path):
    if destino.exists() and destino.stat().st_size > 0:
        return False
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(".part")
    urllib.request.urlretrieve(url, tmp)
    tmp.replace(destino)
    return True


def leer_archivo(path: Path):
    geoms, alturas = [], []
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if not linea:
                continue
            feat = json.loads(linea)
            geoms.append(shape(feat["geometry"]))
            alturas.append((feat.get("properties") or {}).get("height", -1))
    return np.array(geoms, dtype=object), np.array(alturas, dtype=float)


def limpiar(geoms):
    """Redondea a 1e-7 grados; si hay geometrías dañadas, repara una por una."""
    try:
        return shapely.set_precision(geoms, 1e-7)
    except shapely.errors.GEOSException:
        pass
    salida = np.empty(len(geoms), dtype=object)
    for i, g in enumerate(geoms):
        try:
            if not g.is_valid:
                g = shapely.make_valid(g)
            salida[i] = shapely.set_precision(g, 1e-7)
        except shapely.errors.GEOSException:
            salida[i] = None
    return salida


def procesar(geoms, alturas, muni, quadkey, meta, stats):
    stats["leidos"] += len(geoms)

    # redondeo a ~1 cm y limpieza topológica (2dsphere rechaza geometrías malas)
    geoms = limpiar(geoms)
    ok = shapely.is_valid(geoms) & ~shapely.is_empty(geoms)
    ok &= np.isin(shapely.get_type_id(geoms), [3, 6])  # Polygon / MultiPolygon
    stats["descartados_geometria"] += int((~ok).sum())
    geoms, alturas = geoms[ok], alturas[ok]
    if len(geoms) == 0:
        return []

    # asignar municipio por centroide y quedarse solo con los PDET
    cent = shapely.centroid(geoms)
    pts = gpd.GeoDataFrame(geometry=cent, crs=4326)
    j = gpd.sjoin(pts, muni, how="inner", predicate="within")
    j = j[~j.index.duplicated()]
    stats["fuera_pdet"] += len(geoms) - len(j)
    if len(j) == 0:
        return []
    idx = j.index.to_numpy()
    codigos = j["cod_dane_mpio"].to_numpy()
    geoms, cent, alturas = geoms[idx], cent[idx], alturas[idx]

    # área en metros cuadrados (EPSG:9377)
    areas = gpd.GeoSeries(geoms, crs=4326).to_crs(9377).area.to_numpy()

    docs = []
    for g, c, h, a, cod in zip(geoms, cent, alturas, areas, codigos):
        docs.append(
            {
                "quadkey": quadkey,
                "cod_dane_mpio": cod,
                "dataset_source": "microsoft_buildings",
                "geometry": mapping(g),
                "centroid": mapping(c),
                "rooftop_area_m2": round(float(a), 2),
                "height_m": None if h < 0 else float(h),
                "capture_metadata": meta,
            }
        )
    return docs


def insertar(col, docs, batch, stats):
    for i in range(0, len(docs), batch):
        trozo = docs[i : i + batch]
        try:
            res = col.insert_many(trozo, ordered=False)
            stats["insertados"] += len(res.inserted_ids)
        except BulkWriteError as e:
            stats["insertados"] += e.details["nInserted"]
            stats["errores_insercion"] += len(e.details["writeErrors"])
            stats.setdefault("primer_error", e.details["writeErrors"][0]["errmsg"])


def crear_indices(col):
    col.create_index([("geometry", GEOSPHERE)], name="geometry_2dsphere")
    col.create_index([("centroid", GEOSPHERE)], name="centroid_2dsphere")
    col.create_index(
        [("cod_dane_mpio", ASCENDING), ("rooftop_area_m2", DESCENDING)],
        name="mpio_area",
    )
    col.create_index([("quadkey", ASCENDING)], name="quadkey_1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--links",
        default=str(REPO_ROOT / "data/raw/microsoft/dataset-links.csv"),
    )
    ap.add_argument(
        "--data-dir",
        default=str(REPO_ROOT / "data/raw/microsoft/colombia"),
    )
    ap.add_argument(
        "--reports-dir",
        default=str(REPO_ROOT / "reports"),
    )
    ap.add_argument(
        "--uri",
        default=os.getenv(
            "MONGO_URI", "mongodb://acha:acha@localhost:27017/?authSource=admin"
        ),
    )
    ap.add_argument(
        "--db",
        default=os.getenv("MONGO_DATABASE") or os.getenv("MONGO_DB") or "upme_pdet",
    )
    ap.add_argument("--collection", default="buildings_microsoft")
    ap.add_argument("--batch-size", type=int, default=5000)
    ap.add_argument(
        "--index-first", action="store_true", help="crear índices ANTES de cargar"
    )
    ap.add_argument("--limit-files", type=int, default=None)
    ap.add_argument(
        "--license", default="ODbL-1.0", help="confirmar con el README de Microsoft"
    )
    ap.add_argument("--tag", default="corrida")
    ap.add_argument(
        "--dry-run", action="store_true", help="procesa pero no escribe en Mongo"
    )
    ap.add_argument("--quadkey", default=None, help="cargar solo este quadkey")
    ap.add_argument(
        "--largest", type=int, default=None, help="usar solo los N archivos más pesados"
    )
    a = ap.parse_args()

    links_path = Path(a.links)
    if not links_path.exists():
        print(f"Descargando índice de Microsoft en {links_path}...")
        bajar(DATASET_LINKS_URL, links_path)

    links = pd.read_csv(links_path)
    co = links[links["Location"] == "Colombia"].sort_values("QuadKey")
    if a.quadkey:
        co = co[co["QuadKey"].astype(str).str.zfill(9) == a.quadkey.zfill(9)]
    if a.largest:

        def _mb(s):
            n, u = str(s)[:-2], str(s)[-2:].upper()
            return float(n.replace(",", ".")) * {
                "KB": 1 / 1024,
                "MB": 1,
                "GB": 1024,
            }.get(u, 0)

        co = (
            co.assign(_mb=co["Size"].map(_mb))
            .sort_values("_mb", ascending=False)
            .head(a.largest)
        )
    if a.limit_files:
        co = co.head(a.limit_files)
    if co.empty:
        fallar("No hay archivos de Colombia en dataset-links.csv")

    cliente = MongoClient(a.uri, serverSelectionTimeoutMS=5000)
    db = cliente[a.db]
    muni = leer_municipios(db)
    col = db[a.collection]
    data_dir = Path(a.data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)

    proc = psutil.Process()
    stats = dict(
        leidos=0,
        descartados_geometria=0,
        fuera_pdet=0,
        insertados=0,
        errores_insercion=0,
        archivos=0,
    )
    t = dict(descarga=0.0, lectura=0.0, proceso=0.0, insercion=0.0, indices=0.0)
    pico_mb = 0.0
    inicio = time.perf_counter()

    if not a.dry_run:
        col.drop()  # carga idempotente
        if a.index_first:
            t0 = time.perf_counter()
            crear_indices(col)
            t["indices"] += time.perf_counter() - t0

    for fila in co.itertuples():
        qk = str(fila.QuadKey).zfill(9)
        archivo = data_dir / f"{qk}.csv.gz"
        t0 = time.perf_counter()
        bajar(fila.Url, archivo)
        t["descarga"] += time.perf_counter() - t0

        t0 = time.perf_counter()
        geoms, alturas = leer_archivo(archivo)
        t["lectura"] += time.perf_counter() - t0

        meta = {
            "imagery_dates": None,
            "license": a.license,
            "batch_id": f"ms-{fila.UploadDate}-{qk}",
            "loaded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }
        t0 = time.perf_counter()
        docs = procesar(geoms, alturas, muni, qk, meta, stats)
        t["proceso"] += time.perf_counter() - t0

        if docs and not a.dry_run:
            t0 = time.perf_counter()
            insertar(col, docs, a.batch_size, stats)
            t["insercion"] += time.perf_counter() - t0
        elif docs:
            stats["insertados"] += len(
                docs
            )  # en dry-run cuenta los que se habrían insertado

        stats["archivos"] += 1
        pico_mb = max(pico_mb, proc.memory_info().rss / 1e6)
        print(
            f"[{stats['archivos']}/{len(co)}] {qk}: leídos acumulado {stats['leidos']:,}, "
            f"insertados {stats['insertados']:,}"
        )

    if not a.dry_run and not a.index_first:
        t0 = time.perf_counter()
        try:
            crear_indices(col)
        except Exception as e:
            fallar(f"No se pudieron crear los índices: {e}")
        t["indices"] += time.perf_counter() - t0

    total = time.perf_counter() - inicio
    rep = {
        "tag": a.tag,
        "batch_size": a.batch_size,
        "index_first": a.index_first,
        "dry_run": a.dry_run,
        **stats,
        "segundos": {k: round(v, 1) for k, v in t.items()} | {"total": round(total, 1)},
        "docs_por_segundo": round(stats["insertados"] / total) if total else 0,
        "memoria_pico_mb": round(pico_mb),
    }
    if not a.dry_run:
        cs = db.command("collstats", a.collection)
        rep["almacenamiento"] = {
            "tamano_logico_mb": round(cs["size"] / 1e6, 1),
            "en_disco_mb": round(cs["storageSize"] / 1e6, 1),
            "indices_mb": round(cs["totalIndexSize"] / 1e6, 1),
            "documentos": cs["count"],
        }
    print("\n=== RESUMEN ===")
    print(json.dumps(rep, indent=2, ensure_ascii=False))
    reports_dir = Path(a.reports_dir)
    reports_dir.mkdir(parents=True, exist_ok=True)
    (reports_dir / f"load_microsoft_{a.tag}.json").write_text(
        json.dumps(rep, indent=2, ensure_ascii=False), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
