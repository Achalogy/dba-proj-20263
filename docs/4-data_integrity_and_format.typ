= Data Integrity & Format

== Alcance de esta etapa

Esta etapa toma los datos ya verificados (ver la sección de Adquisición y Verificación de Datos) y los deja en el formato que exige la base de datos MongoDB. En la Fase 2, el script `prepare-pdet.py` construye los documentos de `municipalities_pdet` a partir del MGN2025 y `MunicipiosPDET.xlsx`. En la Fase 3, los pipelines `load_microsoft.py` e `importer.py` estandarizan bajo reglas equivalentes los documentos de `buildings_microsoft` y `buildings_google` antes de su inserción masiva.

*Alcance operativo.* Para los límites municipales, la verificación de integridad puede ejecutarse de manera aislada con `--dry-run` exportando a NDJSON. Para las huellas de edificaciones, `load_microsoft.py` también soporta `--dry-run` y validación previa sin escribir en la base de datos, mientras que ambos pipelines garantizan coordenadas geográficas WGS84 (`EPSG:4326`), formato GeoJSON válido, asignación del código municipal DANE de 5 dígitos (`cod_dane_mpio`) y control de tipos BSON antes de la ingesta.

== Requisitos para repetir el trabajo

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.3fr, 3fr),
      align: (left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Requisito*], [*Detalle*],
      [Gestor de paquetes], [`uv` (herramienta moderna de alto rendimiento para entornos y dependencias en Python).],
      [Python], [Versión 3.10 o superior (3.11+ recomendada para `importer.py`).],
      [Librerías principales],
      [`geopandas`, `pyogrio`, `shapely` (>=2.0), `pandas`, `openpyxl`, `psutil`, `requests` y `pymongo`.],

      [Por qué `pymongo`],
      [El script `prepare-pdet.py` importa `bson` (incluido con `pymongo`) para medir el tamaño exacto de cada documento incluso en modo `--dry-run`.],

      [Excel de municipios], [`data/MunicipiosPDET.xlsx`, con dos hojas estructuradas.],
      [Marco Geoestadístico], [DANE, MGN2025, capa municipal en `data/` o `data/raw/`.],
      [MongoDB], [Requerido para la fase de persistencia y validación espacial (ver siguiente sección).],
    )
  ],
  caption: [Requisitos de entorno para los scripts de preparación y formato.],
)

*Estructura del Excel.* La Hoja 1 (se lee por posición, no por nombre) trae las columnas `Subregión PDET`, `Código DANE Departamento`, `Departamento`, `Código DANE Municipio` y `Municipio`. La Hoja 2 trae además una columna `id`, que se usa solo para la colección `catalogo_municipios_pdet` cuando se active la carga.

== Gestión de Entorno y Dependencias con `uv`

Para asegurar la reproducibilidad estricta y evitar inconsistencias entre sistemas operativos, todos los módulos Python del proyecto (`1-pdet_mgn`, `3-buildings-microsoft`, `3-google_open_buildings` y `4-eda`) declaran sus dependencias en `pyproject.toml` y las fijan determinísticamente en `uv.lock`.

```toml
[project]
name = "1-pdet-mgn"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "geopandas>=1.0.1",
    "openpyxl>=3.1.5",
    "pandas>=2.3.3",
    "pymongo>=4.18.3",
    "pyogrio>=0.11.1",
    "shapely>=2",
]
```

=== Instalación y sincronización

Con `uv` instalado, no es necesario gestionar manualmente entornos virtuales. La sincronización se realiza con:

```bash
cd src/1-pdet_mgn
uv sync
```

O bien, es posible ejecutar cualquier script de forma directa y transparente desde la raíz del proyecto usando `uv run`, el cual resuelve y aísla el entorno en milisegundos:

```bash
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py --help
```

== Organización de los archivos

```text
repositorio/
├── data/
│   ├── MunicipiosPDET.xlsx          (catálogo oficial PDET)
│   ├── raw/                         (excluida con .gitignore)
│   │   ├── MGN2025.../ADMINISTRATIVO/MGN_ADM_MPIO_GRAFICO.shp
│   │   └── microsoft/               (dataset-links.csv y 232 .csv.gz)
│   ├── google_open_buildings/       (teselas .csv.gz y pdet_union.geojson)
│   └── processed/
│       └── municipalities_pdet.ndjson   (salida del script MGN)
├── src/
│   ├── 1-pdet_mgn/
│   │   ├── pyproject.toml           (declaración de dependencias para uv)
│   │   ├── uv.lock                  (bloqueo de dependencias)
│   │   └── src/1_pdet_mgn/
│   │       ├── verify_mgn.py        (verificación de calidad de capas)
│   │       └── prepare-pdet.py      (limpieza, reproyección y carga)
│   ├── 2-mongo_container_test/
│   │   ├── .env.example             (plantilla de credenciales y MONGO_URI)
│   │   └── compose.yml              (instancia local de MongoDB)
│   ├── 3-buildings-microsoft/
│   │   ├── pyproject.toml           (dependencias para Microsoft)
│   │   └── load_microsoft.py        (limpieza, formato y carga MS)
│   ├── 3-google_open_buildings/
│   │   ├── pyproject.toml           (dependencias para Google con uv)
│   │   ├── uv.lock
│   │   ├── generate_pdet_union.py   (unión de frontera PDET)
│   │   ├── download_pdet_buildings.py
│   │   └── importer.py              (formato y carga paralela Google)
│   └── 4-eda/
│       ├── pyproject.toml           (dependencias para EDA y auditoría)
│       ├── uv.lock
│       └── eda.py                   (auditoría explain y agregaciones EDA)
└── reports/
    ├── mgn_verification.json
    ├── load_microsoft_completa.json
    └── eda_results.json
```

== Integridad y Formato de Municipios PDET (`prepare-pdet.py`)

=== Cómo ejecutar el script

Los comandos se escriben desde la raíz del repositorio empleando `uv run`:

*Comando para validación y exportación en modo autónomo (`--dry-run`):*

```bash
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp \
  --xlsx data/MunicipiosPDET.xlsx \
  --dry-run \
  --export data/processed/municipalities_pdet.ndjson
```

En entornos Windows PowerShell, el salto de línea se realiza con acento grave (\`):

```powershell
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py `
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp `
  --xlsx data/MunicipiosPDET.xlsx `
  --dry-run `
  --export data/processed/municipalities_pdet.ndjson
```

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.2fr, 0.9fr, 3fr),
      align: (left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Argumento*], [*¿Obligatorio?*], [*Qué hace*],
      [`--mgn`], [Sí], [Ruta al shapefile (`.shp`), a la geodatabase (`.gdb`) o al GeoPackage del MGN.],
      [`--layer`],
      [No],
      [Nombre de la capa municipal. Solo hace falta con `.gdb` o `.gpkg`; con un `.shp` se ignora. Si no se indica, se busca una capa cuyo nombre contenga `MPIO`.],

      [`--xlsx`], [No], [Ruta al Excel de municipios PDET. Por defecto es `data/MunicipiosPDET.xlsx`.],
      [`--export`], [No], [Ruta del archivo `.ndjson` de salida. Si no se indica, no se escribe ningún archivo.],
      [`--dry-run`], [No], [Valida y exporta sin tocar MongoDB. Ideal para pruebas de integridad previas a la ingesta.],
      [`--uri`, `--db`],
      [No],
      [Conexión y nombre de la base de MongoDB. Por defecto `mongodb://localhost:27017` y `upme_pdet`.],
    )
  ],
  caption: [Argumentos de `prepare-pdet.py`.],
)

=== Qué hace el script, paso a paso

+ *Lee el Excel* y arma el catálogo: completa los códigos a 5 dígitos (municipio) y 2 dígitos (departamento) con ceros a la izquierda, comprueba que haya 170 filas, que no haya códigos repetidos y que existan 16 subregiones.
+ *Asigna un `id` a cada subregión* del 1 al 16, ordenando los nombres alfabéticamente sin tildes. Así el `id` es siempre el mismo en cada ejecución. Este `id` no viene del Excel.
+ *Lee la capa del MGN*, comprueba que tenga sistema de coordenadas y que no haya códigos de municipio repetidos.
+ *Cruza por código*, nunca por nombre. Detiene el proceso si falta algún municipio PDET o si el departamento del Excel no coincide con el del MGN.
+ *Reproyecta a EPSG:4326*, que es el sistema que usa el índice `2dsphere`. Luego fuerza las geometrías a 2D y elimina vértices repetidos consecutivos.
+ *Valida cada geometría:* que no esté vacía, que sea `Polygon` o `MultiPolygon`, que sea válida y que sus coordenadas estén en el rango de longitud y latitud.
+ *Construye el documento* de cada municipio y mide su tamaño en BSON. Falla si alguno supera los 16 MB, que es el límite de MongoDB, y avisa si alguno pasa de 8 MB.
+ *Exporta* los documentos a NDJSON, si se indicó `--export`.

Ante cualquier problema de integridad el script termina con un mensaje `[ERROR]` y un código de salida distinto de cero, en lugar de continuar con datos dudosos.

=== Resultado obtenido en municipios PDET

Con los datos reales (MGN2025 y `MunicipiosPDET.xlsx`), el script terminó sin errores y mostró:

```text
Documentos listos: 170 | subregiones: 16
```

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2.2fr, 1.2fr, 2.6fr),
      align: (left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Comprobación*], [*Resultado*], [*Cómo se verificó*],
      [Municipios PDET encontrados en el MGN], [170 de 170], [El script se detiene si falta alguno.],
      [Departamento del Excel igual al del MGN], [170 de 170], [El script se detiene si hay diferencias.],
      [Subregiones identificadas], [16], [Mensaje final del script.],
      [Geometrías válidas, Polygon o MultiPolygon, en rango lon/lat],
      [170 de 170],
      [El script se detiene si alguna falla.],

      [Documentos de más de 8 MB], [Ninguno], [No apareció el aviso de documentos grandes.],
      [Documentos exportados al NDJSON], [170], [Conteo de líneas del archivo.],
      [Nombres con tilde], [Correctos], [Se leen bien `PIENDAMÓ - TUNÍA`, `PUERTO LEGUÍZAMO` y `VISTAHERMOSA`.],
    )
  ],
  caption: [Resultados de las comprobaciones sobre `municipalities_pdet`.],
)

*Nombres.* El nombre que queda en el campo `municipio` es el del MGN, que viene en mayúsculas. El nombre original del Excel se conserva en `metadata_mgn.nombre_xlsx`, así que los seis municipios con nombre distinto no se pierden.

*Ejemplo de documento.* Este es el primer documento del archivo exportado, con la geometría omitida para que sea legible:

```json
{
  "cod_dane_mpio": "05031",
  "cod_dane_dpto": "05",
  "municipio": "AMALFI",
  "departamento": "ANTIOQUIA",
  "subregion_pdet": { "id": 3, "nombre": "BAJO CAUCA Y NORDESTE ANTIOQUEÑO" },
  "area_oficial_km2": 1208.3461881,
  "geometry": { "type": "Polygon | MultiPolygon", "coordinates": [ ... ] },
  "bbox": [-75.1824, 6.7484, -74.8363, 7.2925],
  "metadata_mgn": {
    "vigencia": 2025,
    "crs": "EPSG:4326",
    "source_xlsx": "MunicipiosPDET.xlsx",
    "nombre_xlsx": "AMALFI",
    "cargado_en": "2026-11-09T01:16:14+00:00"
  }
}
```

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.5fr, 1fr, 3fr),
      align: (left, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Campo*], [*Tipo*], [*Contenido*],
      [`cod_dane_mpio`], [String (5)], [Código DANE del municipio, con ceros a la izquierda.],
      [`cod_dane_dpto`], [String (2)], [Código DANE del departamento.],
      [`municipio`], [String], [Nombre según el MGN.],
      [`departamento`], [String], [Nombre del departamento según el Excel.],
      [`subregion_pdet`], [Objeto], [`id` (1 a 16) y `nombre` de la subregión PDET.],
      [`area_oficial_km2`], [Double], [Área oficial publicada por el DANE.],
      [`geometry`], [GeoJSON], [Polígono o multipolígono en EPSG:4326.],
      [`bbox`], [Arreglo de 4], [Caja envolvente: mínima longitud, mínima latitud, máxima longitud, máxima latitud.],
      [`metadata_mgn`],
      [Objeto],
      [Vigencia, sistema de coordenadas, archivo de origen, nombre en el Excel y fecha de generación.],
    )
  ],
  caption: [Campos de cada documento de `municipalities_pdet`.],
)

*Reproducibilidad.* Todos los campos salen igual en cada ejecución, excepto `metadata_mgn.cargado_en`, que guarda la fecha y hora (UTC) de generación. Por eso dos archivos exportados en momentos distintos no serán idénticos byte a byte, aunque los datos sean los mismos.

== Integridad y Formato de Huellas de Edificaciones (Microsoft y Google)

Para garantizar la compatibilidad entre ambos datasets satelitales y la colección `municipalities_pdet` en MongoDB, los scripts `load_microsoft.py` e `importer.py` aplican un conjunto común de reglas de formato previo a la inserción:

- *Sistema de referencia espacial único:* Todas las geometrías GeoJSON (`geometry` y `centroid`) se almacenan en coordenadas geográficas *WGS84 (`EPSG:4326`)* requeridas por los índices `2dsphere`.
- *Homologación de llave municipal (`cod_dane_mpio`):* A cada edificación se le asigna su código DANE de 5 dígitos mediante unión espacial (`gpd.sjoin(..., predicate="within")`) contra los 170 polígonos cargados en `municipalities_pdet`, descartando duplicados en fronteras (`~j.index.duplicated()`).
- *Representación explícita de nulos:* Los atributos faltantes (`height_m` cuando Microsoft reporta `-1`, o `confidence` / `rooftop_area_m2` cuando aparecen `NaN` en Google) se persisten como `null` en BSON en lugar de valores centinela numéricos.
- *Conformidad de tamaño BSON:* Ningún documento individual se acerca al límite de 16 MB de MongoDB; el tamaño promedio es de *579 bytes* en `buildings_microsoft` y ~*386 bytes* en `buildings_google`.

=== Formato y esquema implementado: `buildings_microsoft`

El script `src/3-buildings-microsoft/load_microsoft.py` (ejecutable en modo validación con `--dry-run`) limpia cada geometría con `shapely.set_precision(..., 1e-7)` (~1 cm), repara polígonos inválidos mediante `shapely.make_valid`, verifica que sean `Polygon` o `MultiPolygon`, calcula el centroide (`shapely.centroid`), proyecta las huellas a *`EPSG:9377`* (MAGNA-SIRGAS Origen Nacional) para obtener `rooftop_area_m2` redondeada a 2 decimales y genera documentos con la siguiente estructura:

```json
{
  "quadkey": "032203213",
  "cod_dane_mpio": "47001",
  "dataset_source": "microsoft_buildings",
  "geometry": { "type": "Polygon", "coordinates": [ [ [-74.2101234, 11.2405678], ... ] ] },
  "centroid": { "type": "Point", "coordinates": [-74.2101500, 11.2405900] },
  "rooftop_area_m2": 114.82,
  "height_m": null,
  "capture_metadata": {
    "imagery_dates": null,
    "license": "ODbL-1.0",
    "batch_id": "ms-2023-01-01-032203213",
    "loaded_at": "2026-11-16T08:15:30+00:00"
  }
}
```

=== Formato y esquema implementado: `buildings_google`

El pipeline `src/3-google_open_buildings/importer.py` construye el punto GeoJSON `centroid` de forma vectorizada (`gpd.points_from_xy`), asigna `cod_dane_mpio`, conserva `rooftop_area_m2` (directamente desde `area_in_meters` en m² provisto por Google) y `confidence`, e incluye `source_file` para trazabilidad e idempotencia:

```json
{
  "cod_dane_mpio": "47001",
  "dataset_source": "google_open_buildings",
  "centroid": { "type": "Point", "coordinates": [-74.210152, 11.240591] },
  "rooftop_area_m2": 87.45,
  "confidence": 0.8412,
  "capture_metadata": {
    "imagery_dates": null,
    "license": "CC-BY-4.0 / ODbL-1.0",
    "batch_id": "google-8e7_buildings.csv.gz",
    "loaded_at": "2026-11-16T10:30:12+00:00"
  },
  "source_file": "8e7_buildings.csv.gz"
}
```

=== Decisiones de diseño respecto al esquema preliminar (Semana 1)

Durante la implementación de la Fase 3 se adoptaron tres ajustes documentados respecto al diseño conceptual inicial de `docs/1-implementation_plan.typ` y `docs/2-schema_and_data_modeling.typ`:
+ *Simplificación geométrica en `buildings_google`:* Se almacenó únicamente `centroid` (`Point`) junto con `rooftop_area_m2` precalculada por Google, omitiendo el polígono WKT (`geometry`) y `full_plus_code`. Esta decisión reduce drásticamente el consumo de RAM, tiempo de ingesta y espacio en disco (~176 MiB comprimidos para 2,69 millones de documentos) sin afectar el objetivo del proyecto (conteo y área agregada por municipio).
+ *Atributo `source_file` para idempotencia:* Se incorporó el campo `source_file` en `buildings_google` para permitir reanudación segura y limpieza parcial ante fallos por archivo sin duplicar registros.
+ *Aplicación diferida de la regla `RN-05`:* No se filtraron áreas extremas (`< 10 m²` o `> 20.000 m²`) durante la carga inicial para preservar íntegra la distribución cruda observada en el EDA (mínimos de `9,69 m²` en MS y `2,51 m²` en Google; máximos de `44.667,17 m²` y `20.916,70 m²`). Los umbrales de área útil para instalación solar se aplicarán en la fase analítica de la Semana 4.

== Transición a la Integración NoSQL

Una vez garantizada la integridad topológica, la conformidad de tamaños en BSON y la estandarización de atributos tanto de los 170 municipios PDET como de los 4,45 millones de edificaciones de Microsoft y Google, los datos quedan listos para su persistencia e indexación espacial en MongoDB, lo cual se detalla en la siguiente sección.
