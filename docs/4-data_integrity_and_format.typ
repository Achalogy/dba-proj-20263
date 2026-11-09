= Data Integrity & Format

== Alcance de esta etapa

Esta etapa toma los datos ya verificados (ver la sección de Adquisición y Verificación de Datos) y los deja en el formato que pide la base de datos. El script `prepare-pdet.py` lee el Excel de municipios PDET y la capa municipal del MGN del DANE, cruza ambos por código, reproyecta las geometrías, valida el resultado y construye un documento por municipio siguiendo el esquema `municipalities_pdet` del diagrama E-R.

*Alcance operativo.* Esta etapa se enfoca en la estructuración, validación geométrica y exportación de los documentos a formato NDJSON (un documento JSON por línea) antes de su ingesta en base de datos. Por ello, la verificación de integridad puede ejecutarse de manera aislada con la opción `--dry-run`. La conexión activa, los índices `2dsphere` y la validación con consultas `$geoIntersects` se abordan y consolidan de manera exhaustiva en la siguiente sección del informe.

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
      [Python], [Versión 3.10 o superior (manejada automáticamente por `uv`).],
      [Librerías principales], [`geopandas`, `pyogrio`, `shapely` (>=2.0), `pandas`, `openpyxl` y `pymongo`.],
      [Por qué `pymongo`], [El script importa `bson` (incluido con `pymongo`) para medir el tamaño exacto de cada documento. Hace falta incluso en modo `--dry-run`.],
      [Excel de municipios], [`data/MunicipiosPDET.xlsx`, con dos hojas estructuradas.],
      [Marco Geoestadístico], [DANE, MGN2025, capa municipal en `data/` o `data/raw/`.],
      [MongoDB], [Requerido para la fase de persistencia (ver siguiente sección).],
    )
  ],
  caption: [Requisitos para ejecutar el script.],
)

*Estructura del Excel.* La Hoja 1 (se lee por posición, no por nombre) trae las columnas `Subregión PDET`, `Código DANE Departamento`, `Departamento`, `Código DANE Municipio` y `Municipio`. La Hoja 2 trae además una columna `id`, que se usa solo para la colección `catalogo_municipios_pdet` cuando se active la carga.

== Gestión de Entorno y Dependencias con `uv`

Para asegurar la reproducibilidad estricta y evitar inconsistencias entre sistemas operativos, el proyecto utiliza *`uv`*. Todas las dependencias se encuentran declaradas en `src/1-pdet_mgn/pyproject.toml` y fijadas determinísticamente en `src/1-pdet_mgn/uv.lock`.

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

O bien, es posible ejecutar cualquier script de forma directa y transparente desde la raíz del proyecto usando `uv run`, el cual resuelve y aisla el entorno en milisegundos:

```bash
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py --help
```

== Organización de los archivos

```text
repositorio/
├── data/
│   ├── MunicipiosPDET.xlsx          (catálogo oficial PDET)
│   ├── raw/                         (excluida con .gitignore)
│   │   └── MGN2025.../ADMINISTRATIVO/MGN_ADM_MPIO_GRAFICO.shp
│   └── processed/
│       └── municipalities_pdet.ndjson   (salida del script)
├── src/
│   ├── 1-pdet_mgn/
│   │   ├── pyproject.toml           (declaración de dependencias para uv)
│   │   ├── uv.lock                  (bloqueo de dependencias)
│   │   └── src/1_pdet_mgn/
│   │       ├── verify_mgn.py        (verificación de calidad de capas)
│   │       └── prepare-pdet.py      (limpieza, reproyección y carga)
│   └── 2-mongo_container_test/
│       └── compose.yml              (instancia local de MongoDB)
└── reports/
    └── mgn_verification.json
```

== Cómo ejecutar el script

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
      [`--layer`], [No], [Nombre de la capa municipal. Solo hace falta con `.gdb` o `.gpkg`; con un `.shp` se ignora. Si no se indica, se busca una capa cuyo nombre contenga `MPIO`.],
      [`--xlsx`], [No], [Ruta al Excel de municipios PDET. Por defecto es `data/MunicipiosPDET.xlsx`.],
      [`--export`], [No], [Ruta del archivo `.ndjson` de salida. Si no se indica, no se escribe ningún archivo.],
      [`--dry-run`], [No], [Valida y exporta sin tocar MongoDB. Ideal para pruebas de integridad previas a la ingesta.],
      [`--uri`, `--db`], [No], [Conexión y nombre de la base de MongoDB. Por defecto `mongodb://localhost:27017` y `upme_pdet`.],
    )
  ],
  caption: [Argumentos de `prepare-pdet.py`.],
)

== Qué hace el script, paso a paso

+ *Lee el Excel* y arma el catálogo: completa los códigos a 5 dígitos (municipio) y 2 dígitos (departamento) con ceros a la izquierda, comprueba que haya 170 filas, que no haya códigos repetidos y que existan 16 subregiones.
+ *Asigna un `id` a cada subregión* del 1 al 16, ordenando los nombres alfabéticamente sin tildes. Así el `id` es siempre el mismo en cada ejecución. Este `id` no viene del Excel.
+ *Lee la capa del MGN*, comprueba que tenga sistema de coordenadas y que no haya códigos de municipio repetidos.
+ *Cruza por código*, nunca por nombre. Detiene el proceso si falta algún municipio PDET o si el departamento del Excel no coincide con el del MGN.
+ *Reproyecta a EPSG:4326*, que es el sistema que usa el índice `2dsphere`. Luego fuerza las geometrías a 2D y elimina vértices repetidos consecutivos.
+ *Valida cada geometría:* que no esté vacía, que sea `Polygon` o `MultiPolygon`, que sea válida y que sus coordenadas estén en el rango de longitud y latitud.
+ *Construye el documento* de cada municipio y mide su tamaño en BSON. Falla si alguno supera los 16 MB, que es el límite de MongoDB, y avisa si alguno pasa de 8 MB.
+ *Exporta* los documentos a NDJSON, si se indicó `--export`.

Ante cualquier problema de integridad el script termina con un mensaje `[ERROR]` y un código de salida distinto de cero, en lugar de continuar con datos dudosos.

== Resultado obtenido en esta etapa

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
      [Geometrías válidas, Polygon o MultiPolygon, en rango lon/lat], [170 de 170], [El script se detiene si alguna falla.],
      [Documentos de más de 8 MB], [Ninguno], [No apareció el aviso de documentos grandes.],
      [Documentos exportados al NDJSON], [170], [Conteo de líneas del archivo.],
      [Nombres con tilde], [Correctos], [Se leen bien `PIENDAMÓ - TUNÍA`, `PUERTO LEGUÍZAMO` y `VISTAHERMOSA`.],
    )
  ],
  caption: [Resultados de las comprobaciones de esta etapa.],
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
      [`metadata_mgn`], [Objeto], [Vigencia, sistema de coordenadas, archivo de origen, nombre en el Excel y fecha de generación.],
    )
  ],
  caption: [Campos de cada documento de `municipalities_pdet`.],
)

*Reproducibilidad.* Todos los campos salen igual en cada ejecución, excepto `metadata_mgn.cargado_en`, que guarda la fecha y hora (UTC) de generación. Por eso dos archivos exportados en momentos distintos no serán idénticos byte a byte, aunque los datos sean los mismos.

== Transición a la Integración NoSQL

Una vez garantizada la integridad topológica, la conformidad de tamaños en BSON y la estandarización de atributos de los 170 municipios PDET, los datos quedan listos para su persistencia en el motor de base de datos NoSQL:

- *Conexión activa a MongoDB:* Despliegue del servicio mediante contenedores Docker y autenticación administrativa.
- *Carga e idempotencia:* Ingesta masiva en las colecciones `municipalities_pdet` y `catalogo_municipios_pdet`.
- *Indexación espacial esférica:* Creación y comprobación de los índices `2dsphere` sobre `geometry`, junto con los índices únicos B-Tree.
- *Validación espacial in situ:* Ejecución de pruebas de intersección esférica `$geoIntersects` con el punto interior (`point_on_surface`) de cada municipio.

Las anteriores actividades se consolidan y evidencian de manera exhaustiva en la siguiente sección del informe (*Integración Geoespacial en NoSQL*).
