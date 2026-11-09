= Data Integrity & Format

== Alcance de esta etapa

Esta etapa toma los datos ya verificados (ver la sección de Adquisición y Verificación de Datos) y los deja en el formato que pide la base de datos. El script `Prepare_pdet.py` lee el Excel de municipios PDET y la capa municipal del MGN del DANE, cruza ambos por código, reproyecta las geometrías, valida el resultado y construye un documento por municipio siguiendo el esquema `municipalities_pdet` del diagrama E-R.

*Estado en este commit.* La rama solo genera los documentos y los exporta a un archivo en formato NDJSON (un documento JSON por línea). *Todavía no se conecta a MongoDB*: el código de carga, los índices y las pruebas dentro de la base existen en el diseño, pero están deshabilitados en esta versión. Por eso el script se ejecuta siempre con la opción `--dry-run`. Los índices `2dsphere` y la consulta `$geoIntersects` quedan pendientes para la siguiente etapa.

== Requisitos para repetir el trabajo

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.3fr, 3fr),
      align: (left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Requisito*], [*Detalle*],
      [Python], [Versión 3.10 o superior (el código usa la sintaxis `str | None`).],
      [Librerías], [`geopandas`, `pyogrio`, `shapely` (2.0 o superior), `pandas`, `openpyxl` y `pymongo`.],
      [Por qué `pymongo`], [El script importa `bson` (que viene con `pymongo`) para medir el tamaño de cada documento. Hace falta aunque no se use MongoDB.],
      [Excel de municipios], [`data/MunicipiosPDET.xlsx`, con dos hojas (ver abajo).],
      [Marco Geoestadístico], [DANE, MGN2025, descargado y descomprimido en `data/` (ver la sección de adquisición).],
      [MongoDB], [No se necesita en este commit.],
    )
  ],
  caption: [Requisitos para ejecutar el script.],
)

*Estructura del Excel.* La Hoja 1 (se lee por posición, no por nombre) trae las columnas `Subregión PDET`, `Código DANE Departamento`, `Departamento`, `Código DANE Municipio` y `Municipio`. La Hoja 2 trae además una columna `id`, que se usa solo para la colección `catalogo_municipios_pdet` cuando se active la carga.

== Instalación de dependencias

Se recomienda trabajar en un entorno virtual para no mezclar librerías con otros proyectos. Desde la raíz del repositorio, en PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install geopandas pyogrio "shapely>=2" pandas openpyxl pymongo
```

En Linux o macOS, el entorno se activa con `source .venv/bin/activate` y el resto es igual. Para dejar las versiones registradas, el archivo `requirements.txt` debe incluir:

```text
geopandas
pyogrio
shapely>=2
pandas
openpyxl
pymongo
```

Si `pip` no puede instalar `geopandas` en Windows, la alternativa más estable es usar un entorno de `conda` con `conda install -c conda-forge geopandas pyogrio`.

== Organización de los archivos

```text
repositorio/
├── data/
│   ├── MunicipiosPDET.xlsx          (se sube al repositorio)
│   ├── raw/                         (excluida con .gitignore)
│   │   └── MGN2025.../ADMINISTRATIVO/MGN_ADM_MPIO_GRAFICO.shp
│   └── processed/
│       └── municipalities_pdet.ndjson   (salida del script)
├── scripts/
│   ├── verify_mgn.py                (verificación, solo lectura)
│   └── prepare_pdet.py              (preparación y exportación)
└── reports/
    └── mgn_verification.json
```

La carpeta `data/raw/` pesa varios gigabytes y no se sube a GitHub. La carpeta `data/processed/` se crea sola al exportar.

== Cómo ejecutar el script

Los comandos se escriben desde la raíz del repositorio, para que las rutas relativas funcionen.

*Comando recomendado en este commit:*

```powershell
python scripts/prepare_pdet.py `
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp `
  --xlsx data/MunicipiosPDET.xlsx `
  --dry-run `
  --export data/processed/municipalities_pdet.ndjson
```

En PowerShell, el acento grave al final de cada línea permite partir el comando en varias líneas. En Linux o macOS se usa `\`, y en CMD se usa `^`. También puede escribirse todo en una sola línea.

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
      [`--dry-run`], [No, pero necesario hoy], [Valida y exporta sin tocar MongoDB. En este commit debe usarse siempre.],
      [`--uri`, `--db`], [No], [Conexión y nombre de la base de MongoDB. *Deshabilitados en este commit*; se activan con la carga.],
    )
  ],
  caption: [Argumentos de `prepare_pdet.py`.],
)

*Importante.* Si el script se ejecuta sin `--dry-run` en esta versión, genera los documentos y luego falla con un error de tipo `AttributeError`, porque el bloque de conexión a MongoDB está deshabilitado. No se pierde ni se daña ningún dato, pero tampoco se carga nada.

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

== Resultado obtenido en este commit

Con los datos reales (MGN2025 y `MunicipiosPDET.xlsx`), el script terminó sin errores y mostró:

```text
Documentos listos: 170 | subregiones: 16
```

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2.2fr, 1.2fr, 2.4fr),
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

== Lo que aún no hace esta rama

- *No se conecta a MongoDB.* El código de carga está deshabilitado en este commit.
- *No crea índices.* El índice único sobre `cod_dane_mpio`, el `2dsphere` sobre `geometry` y el de `subregion_pdet.id` quedan pendientes.
- *No prueba el `2dsphere`.* Una geometría válida para Shapely puede ser rechazada por el índice esférico de MongoDB. Esa comprobación solo es posible al crear el índice en la base.
- *No carga el catálogo* `catalogo_municipios_pdet` del diagrama E-R.
- *No valida dentro de la base*: falta el conteo de 170 documentos y la consulta `$geoIntersects` con un punto de cada municipio.

== Siguiente paso

Reactivar el bloque de MongoDB: restaurar los argumentos `--uri` (por defecto `mongodb://localhost:27017`) y `--db` (por defecto `upme_pdet`), iniciar el servicio local de MongoDB, ejecutar el script sin `--dry-run`, y registrar en esta sección los índices creados y el resultado de las pruebas de validación. Con eso queda cubierto el requisito de evidencia de índices espaciales de la Fase 2.
