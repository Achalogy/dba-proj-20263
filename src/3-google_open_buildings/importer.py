"""
ETL: Google Open Buildings -> MongoDB (solo edificios dentro de municipios PDET).

Optimizaciones respecto a la versión original:
  - Lectura solo de las columnas necesarias (usecols).
  - Prefiltro por bounding box + shapely.contains_xy con geometría preparada
    (sin construir GeoDataFrames ni usar iterrows).
  - Un único campo GeoJSON `location` (antes `geometry` y `location` eran idénticos).
  - Procesamiento en paralelo por archivo (ProcessPoolExecutor).
  - Idempotencia: los archivos ya cargados se registran y se saltan al relanzar.
  - Manejo explícito de BulkWriteError.
  - Índices creados una sola vez al final.
"""

import glob
import os
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

import geopandas as gpd
import pandas as pd
import shapely
from pymongo import MongoClient
from pymongo.errors import BulkWriteError
from shapely.geometry import shape

# ----------------------------------------------------------------------
# Configuración
# ----------------------------------------------------------------------
MONGO_URI = os.getenv(
    "MONGO_URI", "mongodb://acha:acha123@localhost:27017/?authSource=admin"
)
DATABASE_NAME = "upme_pdet"
COLLECTION_NAME = "buildings_google"
CONTROL_COLLECTION = "etl_processed_files"

RAW_DIR = "data/google_open_buildings/raw"
BOUNDARIES_DIR = "data/google_open_buildings/boundaries"
PDET_UNION_PATH = os.path.join(BOUNDARIES_DIR, "pdet_union.geojson")

CHUNK_SIZE = 500_000          # filas leídas por bloque del CSV
INSERT_BATCH_SIZE = 50_000    # documentos por insert_many
MAX_WORKERS = int(os.getenv("ETL_WORKERS", max(1, (os.cpu_count() or 2) - 1)))

# Si necesitas conservar el polígono de la huella (WKT) en lugar de solo el
# centroide, pon esto en True. Aumenta bastante el tiempo y el almacenamiento.
KEEP_FOOTPRINT = False

# Reprocesar todo desde cero (vacía la colección y el registro de control).
RESET = os.getenv("ETL_RESET", "0") == "1"

USECOLS = ["latitude", "longitude", "confidence", "area_in_meters"]


# ----------------------------------------------------------------------
# Estado por proceso (se inicializa en cada worker)
# ----------------------------------------------------------------------
_UNION_GEOM = None
_BOUNDS = None
_COL = None
_CONTROL = None
_MUNI = None


def _init_worker():
    """Carga la geometría PDET preparada y abre una conexión propia a Mongo."""
    global _UNION_GEOM, _BOUNDS, _COL, _CONTROL, _MUNI

    gdf_pdet = gpd.read_file(PDET_UNION_PATH)
    union_geom = gdf_pdet.geometry.union_all()
    shapely.prepare(union_geom)
    _UNION_GEOM = union_geom
    _BOUNDS = union_geom.bounds  # (minx, miny, maxx, maxy)

    client = MongoClient(MONGO_URI, compressors="zstd,zlib,snappy")
    db = client[DATABASE_NAME]
    _COL = db[COLLECTION_NAME]
    _CONTROL = db[CONTROL_COLLECTION]
    docs = list(db["municipalities_pdet"].find({}, {"cod_dane_mpio": 1, "geometry": 1}))
    _MUNI = gpd.GeoDataFrame(
        {"cod_dane_mpio": [d["cod_dane_mpio"] for d in docs]},
        geometry=[shape(d["geometry"]) for d in docs],
        crs=4326,
    )


def _build_docs(chunk: pd.DataFrame, source_file: str):
    """Asigna el municipio a cada edificio y arma los documentos."""
    pts = gpd.GeoDataFrame(
        chunk[["confidence", "area_in_meters"]].reset_index(drop=True),
        geometry=gpd.points_from_xy(chunk["longitude"], chunk["latitude"]),
        crs=4326,
    )
    j = gpd.sjoin(pts, _MUNI, how="inner", predicate="within")
    j = j[~j.index.duplicated()]
    meta = {
        "imagery_dates": None,
        "license": "ODbL-1.0",
        "batch_id": f"google-{source_file}",
        "loaded_at": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
    }
    return [
        {
            "cod_dane_mpio": cod,
            "dataset_source": "google_open_buildings",
            "centroid": {"type": "Point", "coordinates": [x, y]},
            "rooftop_area_m2": None if pd.isna(a) else float(a),
            "confidence": None if pd.isna(c) else float(c),
            "capture_metadata": meta,
            "source_file": source_file,
        }
        for cod, x, y, a, c in zip(
            j["cod_dane_mpio"], j.geometry.x, j.geometry.y,
            j["area_in_meters"], j["confidence"],
        )
    ]

def _insert(docs):
    """Inserta en lotes y reporta errores parciales sin ocultarlos."""
    inserted = 0
    for i in range(0, len(docs), INSERT_BATCH_SIZE):
        batch = docs[i : i + INSERT_BATCH_SIZE]
        try:
            _COL.insert_many(batch, ordered=False)
            inserted += len(batch)
        except BulkWriteError as e:
            n_ok = e.details.get("nInserted", 0)
            inserted += n_ok
            print(
                f"  !! BulkWriteError: {n_ok}/{len(batch)} insertados;"
                f" errores: {len(e.details.get('writeErrors', []))}"
            )
    return inserted


def process_file(file_path: str):
    """Procesa un .csv.gz completo. Se ejecuta en un proceso worker."""
    filename = os.path.basename(file_path)
    start = time.perf_counter()
    total_read = 0
    total_inserted = 0

    # Si una corrida previa quedó a medias, limpia lo parcial de este archivo.
    _COL.delete_many({"source_file": filename})

    minx, miny, maxx, maxy = _BOUNDS

    for chunk in pd.read_csv(
        file_path, chunksize=CHUNK_SIZE, compression="gzip", usecols=USECOLS
    ):
        total_read += len(chunk)
        chunk = chunk.dropna(subset=["latitude", "longitude"])
        if chunk.empty:
            continue

        # 1) Prefiltro barato por bounding box
        chunk = chunk[
            chunk["longitude"].between(minx, maxx)
            & chunk["latitude"].between(miny, maxy)
        ]
        if chunk.empty:
            continue

        # 2) Filtro exacto vectorizado contra la geometría preparada
        mask = shapely.contains_xy(
            _UNION_GEOM, chunk["longitude"].to_numpy(), chunk["latitude"].to_numpy()
        )
        chunk = chunk[mask]
        if chunk.empty:
            continue

        total_inserted += _insert(_build_docs(chunk, filename))

    elapsed = time.perf_counter() - start

    # Marca el archivo como completado (idempotencia)
    _CONTROL.update_one(
        {"_id": filename},
        {
            "$set": {
                "rows_read": total_read,
                "rows_inserted": total_inserted,
                "seconds": elapsed,
                "finished_at": time.time(),
            }
        },
        upsert=True,
    )
    return filename, total_read, total_inserted, elapsed


def main():
    start_global = time.perf_counter()

    if not os.path.exists(PDET_UNION_PATH):
        raise FileNotFoundError(
            f"No se encontró el archivo de unión PDET en {PDET_UNION_PATH}."
        )

    csv_files = sorted(glob.glob(os.path.join(RAW_DIR, "*.csv.gz")))
    if not csv_files:
        print(f"¡Advertencia! No se encontraron archivos .csv.gz en {RAW_DIR}.")
        return

    print("Conectando a MongoDB...")
    client = MongoClient(MONGO_URI)
    db = client[DATABASE_NAME]
    buildings_col = db[COLLECTION_NAME]
    control_col = db[CONTROL_COLLECTION]

    if RESET:
        print("RESET activo: vaciando colección y registro de control...")
        buildings_col.drop()
        control_col.drop()

    done = {d["_id"] for d in control_col.find({}, {"_id": 1})}
    pending = [f for f in csv_files if os.path.basename(f) not in done]
    print(
        f"{len(csv_files)} archivos encontrados, {len(done)} ya cargados,"
        f" {len(pending)} pendientes. Workers: {MAX_WORKERS}"
    )

    total_inserted = 0
    if pending:
        with ProcessPoolExecutor(
            max_workers=min(MAX_WORKERS, len(pending)), initializer=_init_worker
        ) as pool:
            futures = {pool.submit(process_file, f): f for f in pending}
            for fut in as_completed(futures):
                path = futures[fut]
                try:
                    name, n_read, n_ins, secs = fut.result()
                    total_inserted += n_ins
                    print(
                        f"[OK] {name}: leídos {n_read:,}, insertados {n_ins:,}"
                        f" en {secs:.1f}s"
                    )
                except Exception as e:
                    print(f"[ERROR] {os.path.basename(path)}: {e}")

    # Índices al final para máximo rendimiento de carga
    print("\nCreando índices en MongoDB...")
    buildings_col.create_index([("centroid", "2dsphere")], name="centroid_2dsphere")
    buildings_col.create_index(
        [("cod_dane_mpio", 1), ("rooftop_area_m2", -1)], name="mpio_area"
    )
    buildings_col.create_index([("source_file", 1)], name="source_file_1")
    

    client.close()
    elapsed = time.perf_counter() - start_global
    print(
        f"\n¡ETL completado! Registros insertados en esta corrida:"
        f" {total_inserted:,} en {elapsed / 60:.2f} minutos."
    )


if __name__ == "__main__":
    main()