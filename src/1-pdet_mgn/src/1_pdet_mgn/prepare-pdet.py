"""Prepara los 170 municipios PDET y los carga en MongoDB.

Flujo:
  1. Lee el Excel (Hoja 1 = catalogo con subregion; Hoja 2 = catalogo con id).
  2. Obtiene los 170 municipios PDET desde:
     - Modo MGN (--mgn): lee la capa municipal del MGN (DANE), cruza por codigo
       de 5 digitos, reproyecta a EPSG:4326, fuerza 2D y limpia vertices repetidos.
     - Modo NDJSON (--from-ndjson): lee data/processed/municipalities_pdet.ndjson
       (incluido en el repositorio) sin requerir la descarga de 3.2 GB del MGN.
  3. Valida (170 municipios, rango lon/lat, validez topologica, tipo Polygon/MultiPolygon,
     tamano BSON < 16 MB). Aborta si algo falla.
  4. Carga en MongoDB: municipalities_pdet (+ catalogo_municipios_pdet),
     crea indices (unico por codigo, 2dsphere en geometry, subregion).
  5. Valida en la base: conteo = 170 y consulta $geoIntersects de prueba (170/170).

Uso (desde la raiz del repositorio):
    # Desde capa oficial del MGN (DANE):
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \\
        --mgn data/MGN_ADM_MPIO_GRAFICO.shp \\
        --export data/processed/municipalities_pdet.ndjson

    # Reproduccion rapida desde el NDJSON versionado en el repositorio:
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \\
        --from-ndjson data/processed/municipalities_pdet.ndjson

    # Modo dry-run (valida sin tocar MongoDB):
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \\
        --from-ndjson data/processed/municipalities_pdet.ndjson --dry-run

Requiere Python >= 3.10 y: geopandas, pyogrio, shapely>=2, pandas, openpyxl, pymongo.
"""

import argparse
import json
import os
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import pandas as pd
import pyogrio
import shapely
from bson import BSON
from shapely.geometry import mapping, shape

COD_MPIO = ["MPIO_CDPMP", "MPIO_CCNCT", "COD_MPIO"]
COD_DPTO = ["DPTO_CCDGO", "COD_DPTO"]
NOM_MPIO = ["MPIO_CNMBR", "NOM_MPIO"]
AREA_OFICIAL = ["MPIO_NAREA", "AREA"]

MAX_DOC_BYTES = 16 * 1024 * 1024
AVISO_DOC_BYTES = 8 * 1024 * 1024
N_ESPERADO = 170
N_SUBREGIONES = 16
DEFAULT_NDJSON = "data/processed/municipalities_pdet.ndjson"


def fallar(msg: str):
    print(f"\n[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def norm(texto) -> str:
    t = unicodedata.normalize("NFKD", str(texto).strip().upper())
    return "".join(c for c in t if not unicodedata.combining(c))


def pick(columnas, candidatas, que):
    por_norm = {norm(c): c for c in columnas}
    for c in candidatas:
        if norm(c) in por_norm:
            return por_norm[norm(c)]
    fallar(f"No encontre la columna de {que}. Disponibles: {list(columnas)}")


def elegir_capa(ruta: Path, capa):
    if ruta.suffix.lower() == ".shp":
        return None
    if capa:
        return capa
    capas = [c[0] for c in pyogrio.list_layers(ruta)]
    cand = [c for c in capas if "MPIO" in c.upper()]
    if not cand:
        fallar("No hay capa con 'MPIO'. Usa --layer.")
    print(f"Capa elegida: {cand[0]}")
    return cand[0]


# ---------------------------------------------------------------- Excel
def leer_catalogo(xlsx: str):
    """Hoja 1 (por posicion): Subregion, cod dpto, dpto, cod mpio, municipio."""
    df = pd.read_excel(xlsx, sheet_name=0)
    c_sub = pick(df.columns, ["Subregión PDET", "Subregion PDET"], "subregion")
    c_cd = pick(df.columns, ["Código DANE Departamento"], "codigo departamento")
    c_d = pick(df.columns, ["Departamento"], "departamento")
    c_cm = pick(df.columns, ["Código DANE Municipio"], "codigo municipio")
    c_m = pick(df.columns, ["Municipio"], "municipio")
    out = pd.DataFrame(
        {
            "subregion": df[c_sub].astype(str).str.strip(),
            "cod_dane_dpto": df[c_cd].astype(int).astype(str).str.zfill(2),
            "departamento": df[c_d].astype(str).str.strip(),
            "cod_dane_mpio": df[c_cm].astype(int).astype(str).str.zfill(5),
            "municipio_xlsx": df[c_m].astype(str).str.strip(),
        }
    )
    if len(out) != N_ESPERADO:
        fallar(f"El Excel tiene {len(out)} filas, se esperaban {N_ESPERADO}.")
    dup = out["cod_dane_mpio"][out["cod_dane_mpio"].duplicated()].tolist()
    if dup:
        fallar(f"Codigos repetidos en el Excel: {dup}")
    subs = sorted(out["subregion"].unique(), key=norm)
    if len(subs) != N_SUBREGIONES:
        fallar(f"Hay {len(subs)} subregiones, se esperaban {N_SUBREGIONES}: {subs}")
    sub_id = {s: i + 1 for i, s in enumerate(subs)}  # id determinista 1..16
    out["subregion_id"] = out["subregion"].map(sub_id)
    return out


def leer_hoja2_id(xlsx: str):
    """Hoja 2 (opcional): trae 'id' para catalogo_municipios_pdet."""
    try:
        df = pd.read_excel(xlsx, sheet_name=1)
        c_id = pick(df.columns, ["id"], "id")
        c_cm = pick(df.columns, ["Código DANE Municipio"], "codigo municipio")
        return dict(
            zip(df[c_cm].astype(int).astype(str).str.zfill(5), df[c_id].astype(int))
        )
    except Exception as e:  # noqa: BLE001
        print(
            f"[aviso] No pude leer la Hoja 2 ({e}); el id del catalogo sera consecutivo."
        )
        return {}


# ------------------------------------------------------------ Geometria
def limpiar_geom(g):
    g = shapely.force_2d(g)
    try:
        g = shapely.remove_repeated_points(g, tolerance=0)  # shapely >= 2.1
    except AttributeError:
        pass
    return g


def validar_geom(cod, g):
    if g is None or g.is_empty:
        fallar(f"{cod}: geometria vacia")
    if g.geom_type not in ("Polygon", "MultiPolygon"):
        fallar(f"{cod}: tipo {g.geom_type} no permitido (Polygon/MultiPolygon)")
    if not g.is_valid:
        fallar(f"{cod}: geometria invalida ({shapely.is_valid_reason(g)})")
    minx, miny, maxx, maxy = g.bounds
    if not (-180 <= minx and maxx <= 180 and -90 <= miny and maxy <= 90):
        fallar(f"{cod}: coordenadas fuera de rango lon/lat {g.bounds}")


def construir_desde_mgn(ruta: Path, capa_arg, cat: pd.DataFrame, xlsx_path: str):
    capa = elegir_capa(ruta, capa_arg)
    gdf = gpd.read_file(ruta, layer=capa)
    if gdf.crs is None:
        fallar("La capa del MGN no tiene CRS.")
    c_mpio = pick(gdf.columns, COD_MPIO, "codigo municipio MGN")
    c_dpto = pick(gdf.columns, COD_DPTO, "codigo departamento MGN")
    c_nom = pick(gdf.columns, NOM_MPIO, "nombre MGN")
    c_area = pick(gdf.columns, AREA_OFICIAL, "area oficial")
    gdf[c_mpio] = gdf[c_mpio].astype(str).str.zfill(5)
    gdf[c_dpto] = gdf[c_dpto].astype(str).str.zfill(2)

    if gdf[c_mpio].duplicated().any():
        fallar("Hay codigos de municipio repetidos en el MGN.")

    sub = gdf[gdf[c_mpio].isin(cat["cod_dane_mpio"])].copy()
    faltan = sorted(set(cat["cod_dane_mpio"]) - set(sub[c_mpio]))
    if faltan:
        fallar(f"PDET que faltan en el MGN: {faltan}")
    m = sub.merge(cat, left_on=c_mpio, right_on="cod_dane_mpio", validate="1:1")
    if len(m) != N_ESPERADO:
        fallar(f"Tras el cruce hay {len(m)} municipios, se esperaban {N_ESPERADO}.")
    malos = m[m[c_dpto] != m["cod_dane_dpto"]][c_mpio].tolist()
    if malos:
        fallar(f"Departamento distinto entre Excel y MGN: {malos}")

    m = gpd.GeoDataFrame(m, geometry="geometry", crs=gdf.crs).to_crs(4326)
    m["geometry"] = m.geometry.apply(limpiar_geom)

    ahora = datetime.now(timezone.utc)
    docs, geoms_check, grandes = [], [], []
    for _, r in m.iterrows():
        cod = r["cod_dane_mpio"]
        validar_geom(cod, r.geometry)
        doc = {
            "cod_dane_mpio": cod,
            "cod_dane_dpto": r["cod_dane_dpto"],
            "municipio": str(r[c_nom]).strip(),  # nombre canonico = MGN
            "departamento": r["departamento"],
            "subregion_pdet": {"id": int(r["subregion_id"]), "nombre": r["subregion"]},
            "area_oficial_km2": float(r[c_area]),
            "geometry": mapping(r.geometry),
            "bbox": [
                float(x) for x in r.geometry.bounds
            ],  # minLon,minLat,maxLon,maxLat
            "metadata_mgn": {
                "vigencia": 2025,
                "crs": "EPSG:4326",
                "source_xlsx": Path(xlsx_path).name,
                "nombre_xlsx": r["municipio_xlsx"],
                "cargado_en": ahora.isoformat(timespec="seconds"),
            },
        }
        tam = len(BSON.encode(doc))
        if tam >= MAX_DOC_BYTES:
            fallar(f"{cod}: documento de {tam / 1e6:.1f} MB supera 16 MB")
        if tam >= AVISO_DOC_BYTES:
            grandes.append((cod, round(tam / 1e6, 2)))
        docs.append(doc)
        geoms_check.append((cod, r.geometry))
    return docs, geoms_check, grandes


def construir_desde_ndjson(ruta: Path, cat: pd.DataFrame):
    if not ruta.exists():
        fallar(f"No existe el archivo NDJSON: {ruta}")
    esperados = set(cat["cod_dane_mpio"])
    docs, geoms_check, grandes = [], [], []
    vistos = set()
    with open(ruta, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            doc = json.loads(line)
            doc.pop("_id", None)
            cod = str(doc["cod_dane_mpio"]).zfill(5)
            doc["cod_dane_mpio"] = cod
            if cod in vistos:
                fallar(f"Codigo duplicado en NDJSON: {cod}")
            vistos.add(cod)
            g = shape(doc["geometry"])
            validar_geom(cod, g)
            tam = len(BSON.encode(doc))
            if tam >= MAX_DOC_BYTES:
                fallar(f"{cod}: documento de {tam / 1e6:.1f} MB supera 16 MB")
            if tam >= AVISO_DOC_BYTES:
                grandes.append((cod, round(tam / 1e6, 2)))
            docs.append(doc)
            geoms_check.append((cod, g))

    if len(docs) != N_ESPERADO:
        fallar(f"El NDJSON tiene {len(docs)} municipios, se esperaban {N_ESPERADO}.")
    faltan = sorted(esperados - vistos)
    if faltan:
        fallar(f"Codigos PDET faltantes en el NDJSON: {faltan}")
    return docs, geoms_check, grandes


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(
        description="Prepara y valida los 170 municipios PDET en MongoDB."
    )
    ap.add_argument(
        "--mgn",
        default=None,
        help="Ruta a la capa municipal MGN (.shp, .gdb o .gpkg)",
    )
    ap.add_argument(
        "--from-ndjson",
        default=None,
        help=(
            "Carga desde NDJSON preprocesado sin requerir el shapefile MGN "
            f"(ej. {DEFAULT_NDJSON})"
        ),
    )
    ap.add_argument("--layer", default=None)
    ap.add_argument("--xlsx", default="data/MunicipiosPDET.xlsx")
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
    ap.add_argument("--export", default=None, help="Ruta .ndjson opcional")
    ap.add_argument("--dry-run", action="store_true", help="No escribe en MongoDB")
    a = ap.parse_args()

    if a.mgn and a.from_ndjson:
        fallar("Usa --mgn o --from-ndjson, no ambos simultaneamente.")
    if not a.mgn and not a.from_ndjson:
        if Path(DEFAULT_NDJSON).exists():
            print(
                f"[info] No se indico --mgn; usando NDJSON versionado: {DEFAULT_NDJSON}"
            )
            a.from_ndjson = DEFAULT_NDJSON
        else:
            fallar("Debes indicar --mgn <ruta_MGN> o --from-ndjson <ruta_ndjson>.")

    cat = leer_catalogo(a.xlsx)
    id_hoja2 = leer_hoja2_id(a.xlsx)

    if a.mgn:
        docs, geoms_check, grandes = construir_desde_mgn(
            Path(a.mgn), a.layer, cat, a.xlsx
        )
    else:
        docs, geoms_check, grandes = construir_desde_ndjson(Path(a.from_ndjson), cat)

    print(
        f"Documentos listos: {len(docs)} | subregiones: {cat['subregion_id'].nunique()}"
    )
    if grandes:
        print(f"[aviso] Documentos > 8 MB: {grandes}")

    if a.export:
        Path(a.export).parent.mkdir(parents=True, exist_ok=True)
        with open(a.export, "w", encoding="utf-8") as f:
            for d in docs:
                d2 = {k: v for k, v in d.items()}
                f.write(json.dumps(d2, ensure_ascii=False) + "\n")
        print(f"NDJSON exportado en {a.export}")

    if a.dry_run:
        print("Dry-run: validaciones OK, MongoDB no se toco.")
        return

    from pymongo import ASCENDING, GEOSPHERE, MongoClient
    from pymongo.errors import PyMongoError

    cli = MongoClient(a.uri, serverSelectionTimeoutMS=5000)
    try:
        cli.admin.command("ping")
    except PyMongoError as e:
        fallar(f"No pude conectar a MongoDB en {a.uri}: {e}")
    db = cli[a.db]

    # Idempotente: recarga completa
    db.municipalities_pdet.drop()
    db.catalogo_municipios_pdet.drop()

    catalogo = []
    for i, r in enumerate(cat.itertuples(index=False), start=1):
        catalogo.append(
            {
                "id": int(id_hoja2.get(r.cod_dane_mpio, i)),
                "subregion_pdet": r.subregion,
                "cod_dane_dpto": int(r.cod_dane_dpto),
                "departamento": r.departamento,
                "cod_dane_mpio": int(r.cod_dane_mpio),
                "municipio": r.municipio_xlsx,
            }
        )
    db.catalogo_municipios_pdet.insert_many(catalogo, ordered=False)
    db.catalogo_municipios_pdet.create_index("cod_dane_mpio", unique=True)

    col = db.municipalities_pdet
    col.insert_many(docs, ordered=False)
    col.create_index([("cod_dane_mpio", ASCENDING)], unique=True)
    try:
        col.create_index(
            [("geometry", GEOSPHERE)]
        )  # falla si alguna geometria no es valida en esfera
    except PyMongoError as e:
        fallar(f"MongoDB rechazo el indice 2dsphere: {e}")
    col.create_index([("subregion_pdet.id", ASCENDING)])

    # Validacion en la base
    n = col.count_documents({})
    if n != N_ESPERADO:
        fallar(f"En MongoDB hay {n} documentos, se esperaban {N_ESPERADO}.")
    errores = []
    for cod, geom in geoms_check:
        punto = shapely.point_on_surface(geom)
        hit = col.find_one(
            {"geometry": {"$geoIntersects": {"$geometry": mapping(punto)}}},
            {"cod_dane_mpio": 1},
        )
        if not hit or hit["cod_dane_mpio"] != cod:
            errores.append(cod)
    if errores:
        fallar(f"$geoIntersects no devolvio el municipio esperado en: {errores}")

    print(
        f"OK: {n} municipios en {a.db}.municipalities_pdet, indices: "
        f"{[i['name'] for i in col.list_indexes()]}"
    )
    print(
        "Prueba $geoIntersects (punto interior de cada municipio): 170/170 correctas."
    )


if __name__ == "__main__":
    main()
