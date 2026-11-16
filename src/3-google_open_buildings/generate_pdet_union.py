import json
import os
import geopandas as gpd
from shapely.geometry import shape

# Rutas
input_ndjson = "data/processed/municipalities_pdet.ndjson"
output_dir = "data/google_open_buildings/boundaries"
output_geojson = os.path.join(output_dir, "pdet_union.geojson")

# Crear carpeta si no existe
os.makedirs(output_dir, exist_ok=True)

# Leer el archivo NDJSON línea por línea
print("Leyendo municipios PDET desde NDJSON...")
geometries = []
with open(input_ndjson, "r", encoding="utf-8") as f:
  for line in f:
    if line.strip():
      record = json.loads(line)
      # Extraer la geometría dependiendo de cómo esté estructurado el documento
      if "geometry" in record:
        geometries.append(shape(record["geometry"]))
      else:
        geometries.append(shape(record))

# Crear GeoDataFrame con las geometrías extraídas
gdf = gpd.GeoDataFrame(geometry=geometries, crs="EPSG:4326")

# Unir todas las geometrías en un solo polígono/multipolígono disuelto
print("Unificando geometrías de los 170 municipios...")
dissolved_geom = gdf.unary_union

# Guardar el resultado en formato GeoJSON
gdf_union = gpd.GeoDataFrame(geometry=[dissolved_geom], crs="EPSG:4326")
gdf_union.to_file(output_geojson, driver="GeoJSON")

print(f"¡Archivo generado con éxito en: {output_geojson}!")