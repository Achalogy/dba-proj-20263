import os

import geopandas as gpd
import pandas as pd
import requests
from shapely import wkt
from shapely.geometry import shape

# Rutas del proyecto (configurables vía DATA_DIR para ejecución local o en Docker)
DATA_DIR = os.getenv("DATA_DIR", "data/google_open_buildings")
RAW_DIR = os.getenv("RAW_DIR", os.path.join(DATA_DIR, "raw"))
BOUNDARIES_DIR = os.getenv("BOUNDARIES_DIR", os.path.join(DATA_DIR, "boundaries"))
os.makedirs(RAW_DIR, exist_ok=True)

# 1. Cargar la geometría unificada de los municipios PDET
pdet_union_path = os.path.join(BOUNDARIES_DIR, "pdet_union.geojson")
gdf_pdet = gpd.read_file(pdet_union_path)
union_geom = gdf_pdet.geometry.union_all()

print("Geometría PDET cargada correctamente para el filtro espacial.")

# 2. Obtener el índice de teselas de Google Open Buildings (v3)
index_url = "https://storage.googleapis.com/open-buildings-data/v3/score_thresholds_s2_level_4.csv"
df_index = pd.read_csv(index_url)

# 3. Filtrar qué teselas (S2 cells) intersecan con los municipios PDET
tiles_to_download = []
for _, row in df_index.iterrows():
    cell_geom = shape(wkt.loads(row["geometry"]))
    if union_geom.intersects(cell_geom):
        tiles_to_download.append(row["s2_token"])

print(f"Teselas identificadas que intersecan con PDET: {len(tiles_to_download)}")

# 4. Descargar los archivos comprimidos correspondientes a la carpeta raw
for token in tiles_to_download:
    file_name = f"{token}_buildings.csv.gz"
    file_url = f"https://storage.googleapis.com/open-buildings-data/v3/polygons_s2_level_4_gzip/{file_name}"
    dest_path = os.path.join(RAW_DIR, file_name)

    if not os.path.exists(dest_path):
        print(f"Descargando tesela {file_name}...")
        response = requests.get(file_url, stream=True, timeout=120)
        if response.status_code == 200:
            with open(dest_path, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
        else:
            print(f"No se pudo descargar la tesela {file_name}")
