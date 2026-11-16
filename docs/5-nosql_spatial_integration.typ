g= Integración Geoespacial en NoSQL (NoSQL Spatial Integration)

== Alcance y Objetivos de la Etapa

Esta sección documenta la persistencia real y la integración geoespacial de los 170 municipios PDET en el motor de base de datos NoSQL *MongoDB*, concluyendo formalmente los entregables de la Fase 2 del proyecto.

Tras haber verificado la calidad topológica de los datos de origen (MGN2025 del DANE) y haber estructurado y validado el modelo de documentos en formato GeoJSON, en esta etapa se ejecutó el proceso de ingestión directa sobre la base de datos sin restricciones de simulación (`--dry-run`). Los objetivos cumplidos en esta fase son:

+ *Despliegue del entorno NoSQL:* Levantamiento y configuración de una instancia local aislada de MongoDB mediante contenedores Docker.
+ *Carga real e idempotente de datos:* Ingestión de los 170 municipios en la colección `municipalities_pdet` y de los metadatos tabulares en `catalogo_municipios_pdet` a través del script `prepare-pdet.py`.
+ *Creación y verificación de índices:* Construcción del índice espacial esférico `2dsphere` sobre el campo `geometry`, junto con los índices B-Tree únicos y de partición sobre `cod_dane_mpio` y `subregion_pdet.id`.
+ *Validación espacial exhaustiva de punto interior:* Comprobación de integridad topológica y cobertura sobre la esfera mediante consultas `$geoIntersects` generadas a partir del punto interior (`point_on_surface`) de cada uno de los 170 municipios, alcanzando una tasa de éxito de 170/170 aciertos (100 %).
+ *Auditoría de planes de ejecución (`explain`):* Demostración de que las búsquedas espaciales utilizan eficazmente el índice `geometry_2dsphere` mediante escaneos de índice (`IXSCAN`), descartando escaneos lineales de colección (`COLLSCAN`).

== Despliegue de la Instancia de MongoDB

Para asegurar la reproducibilidad del entorno de desarrollo y evitar discrepancias de versión entre los integrantes del equipo, la base de datos NoSQL se ejecuta sobre un contenedor Docker gestionado con Docker Compose (`src/2-mongo_container_test/compose.yml`).

#figure(
  text(size: 9.5pt)[
```yaml
services:
  mongodb:
    image: mongo:latest
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: acha
      MONGO_INITDB_ROOT_PASSWORD: acha
    ports:
      - "27017:27017"
```
  ],
  caption: [Definición del servicio MongoDB en `compose.yml`.],
)

=== Instrucciones de Levantamiento

Desde la raíz del repositorio o dentro de la carpeta del módulo, el servicio se inicia en segundo plano con el siguiente comando:

```powershell
docker compose -f src/2-mongo_container_test/compose.yml up -d
```

Se verificó el estado operativo del contenedor en ejecución mediante `docker ps`:

```text
CONTAINER ID   IMAGE          COMMAND                  STATUS         PORTS                       NAMES
8be53ab428ca   mongo:latest   "docker-entrypoint.s…"   Up 25 minutes  0.0.0.0:27017->27017/tcp    mongodb
```

La cadena de conexión (URI) utilizada para autenticar al usuario administrador en la base de datos de trabajo `upme_pdet` corresponde a:

```text
mongodb://acha:acha@localhost:27017/?authSource=admin
```

== Ejecución de la Carga Real (`prepare-pdet.py`)

Con la base de datos en ejecución y autenticada, se procedió a invocar el script de preparación y carga `prepare-pdet.py` omitiendo la bandera `--dry-run`, habilitando así la escritura activa sobre MongoDB y exportando simultáneamente el archivo consolidado en formato NDJSON para respaldo local.

```powershell
python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py `
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp `
  --xlsx data/MunicipiosPDET.xlsx `
  --export data/processed/municipalities_pdet.ndjson `
  --uri "mongodb://acha:acha@localhost:27017/?authSource=admin" `
  --db upme_pdet
```

=== Salida Registrada del Proceso

El script procesó las geometrías de los 1.122 municipios del shapefile original, aisló los 170 municipios PDET, reproyectó las coordenadas a WGS84 (EPSG:4326), validó la ausencia de autointersecciones, pobló las colecciones y evaluó las consultas espaciales en la base de datos. La consola reportó el siguiente registro de éxito:

```text
Documentos listos: 170 | subregiones: 16
NDJSON exportado en data\processed\municipalities_pdet.ndjson
OK: 170 municipios en upme_pdet.municipalities_pdet, indices: ['_id_', 'cod_dane_mpio_1', 'geometry_2dsphere', 'subregion_pdet.id_1']
Prueba $geoIntersects (punto interior de cada municipio): 170/170 correctas.
```

=== Idempotencia del Proceso

Para garantizar que el flujo de trabajo sea estrictamente reproducible y no genere estados inconsistentes ante reejecuciones, el script implementa una recarga idempotente:

+ Ejecuta `db.municipalities_pdet.drop()` y `db.catalogo_municipios_pdet.drop()`.
+ Inserta masivamente los documentos utilizando `insert_many(ordered=False)`.
+ Crea los índices requeridos de forma determinística inmediatamente después de la inserción de datos.
+ Realiza las pruebas de validación espacial contra los registros recién insertados.

== Creación y Verificación de Índices

En bases de datos documentales, la correcta selección de índices resulta crítica para garantizar tiempos de respuesta subsegundo en operaciones geoespaciales sobre grandes volúmenes de datos. En particular, la posterior integración con las huellas de edificaciones (que contienen millones de polígonos) exigirá resolver consultas de pertenencia espacial de forma óptima.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.5fr, 1.4fr, 1fr, 1fr, 2.1fr),
      align: (left, left, center, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Colección*], [*Nombre del Índice*], [*Tipo*], [*Tamaño*], [*Propósito y Comportamiento*],
      [`municipalities_pdet`], [`_id_`], [B-Tree], [20 KB], [Identificador único nativo del documento.],
      [`municipalities_pdet`], [`cod_dane_mpio_1`], [B-Tree (Único)], [20 KB], [Garantiza unicidad de los códigos DANE de 5 dígitos y acelera cruces por llave primaria de negocio.],
      [`municipalities_pdet`], [`geometry_2dsphere`], [2dsphere (v4)], [64 KB], [Índice geoespacial esférico sobre WGS84 para operadores `$geoIntersects`, `$geoWithin` y `$near`.],
      [`municipalities_pdet`], [`subregion_pdet.id_1`], [B-Tree], [20 KB], [Indexación de campo anidado para filtrado directo por subregión PDET (1 a 16).],
      [`catalogo_municipios_pdet`], [`_id_`], [B-Tree], [20 KB], [Identificador único nativo del catálogo.],
      [`catalogo_municipios_pdet`], [`cod_dane_mpio_1`], [B-Tree (Único)], [20 KB], [Unicidad e indexación rápida para la entidad de catálogo PDET.],
    )
  ],
  caption: [Índices creados y verificados en la base de datos MongoDB `upme_pdet`.],
)

=== Importancia del Índice `2dsphere`

A diferencia del índice cartesiano plano `2d` de MongoDB, el índice `2dsphere`:
+ *Modela la geometría de la Tierra sobre una esfera (elipsoide WGS84):* Permite calcular distancias geodésicas reales e intersecciones precisas en grados decimales (longitud, latitud).
+ *Valida la rigidez topológica en el motor:* MongoDB rechaza la creación del índice `2dsphere` si alguno de los documentos contiene anillos no cerrados, autointersecciones o geometrías mal orientadas. El hecho de que el índice se haya creado satisfactoriamente en `upme_pdet` constituye una prueba fehaciente de la calidad y validez del GeoJSON ingerido.

== Prueba de Validación Espacial: Punto Interior (`$geoIntersects`)

Para demostrar empíricamente la efectividad del índice espacial y comprobar que las geometrías indexadas responden con exactitud a consultas espaciales en el motor NoSQL, se diseñó una prueba de validación espacial automatizada.

=== Justificación Metodológica: `point_on_surface` vs. Centroide

En análisis espacial clásico suele recurrirse al cálculo del centroide geométrico (`geom.centroid`). Sin embargo, en polígonos irregulares, cóncavos, en forma de herradura o en multipolígonos (como municipios con enclaves, archipiélagos fluviales o límites sinuosos de montaña), el centroide matemático puede localizarse *fuera de los límites reales del polígono*. Si se ejecutara una consulta espacial con un punto exterior, la prueba fallaría erróneamente acusando un falso negativo.

Por esta razón, la prueba emplea la función algorítmica `shapely.point_on_surface(geometry)`:
- Garantiza rigurosamente que el punto de prueba generado se encuentra siempre *estrictamente en el interior* de la superficie del municipio.
- Conserva estabilidad numérica al proyectarse sobre el sistema de coordenadas de la base de datos (WGS84).

=== Ejecución de la Prueba Espacial

El algoritmo recorre secuencialmente cada uno de los 170 municipios cargados, obtiene su punto interior y formula una consulta espacial en MongoDB utilizando el operador `$geoIntersects`:

```python
for _, r in m.iterrows():
    punto = shapely.point_on_surface(r.geometry)
    hit = col.find_one(
        {"geometry": {"$geoIntersects": {"$geometry": mapping(punto)}}},
        {"cod_dane_mpio": 1},
    )
    if not hit or hit["cod_dane_mpio"] != r["cod_dane_mpio"]:
        errores.append(r["cod_dane_mpio"])
```

=== Resultados de la Validación

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2.2fr, 1.2fr, 2.6fr),
      align: (left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Métrica de Evaluación*], [*Resultado*], [*Observación / Diagnóstico*],
      [Puntos interiores evaluados], [170 / 170], [Se probó un punto interior por cada municipio PDET.],
      [Coincidencias exactas (`$geoIntersects`)], [170 / 170], [El municipio retornado coincidió al 100 % con el código esperado.],
      [Falsos negativos o fallos de intersección], [0 / 170], [Ningún punto interior cayó en vacío o fuera de su polígono.],
      [Confusiones o colisiones espaciales], [0 / 170], [Ningún punto interior intersectó erróneamente un municipio vecino.],
      [Tasa de efectividad de la prueba], [100.0 %], [Validación espacial superada de forma íntegra.],
    )
  ],
  caption: [Resultados cuantitativos de la prueba de validación espacial.],
)

== Análisis del Plan de Ejecución (`explain`)

Para corroborar que las consultas espaciales no degradan el rendimiento mediante escaneos secuenciales de la colección (`COLLSCAN`), se inspeccionó el plan de ejecución generado por el optimizador de consultas de MongoDB (`queryPlanner`) sobre una consulta `$geoIntersects` representativa:

```python
plan = db.command('explain', {
    'find': 'municipalities_pdet',
    'filter': {
        'geometry': {
            '$geoIntersects': {
                '$geometry': {'type': 'Point', 'coordinates': [-74.95147, 7.02048]}
            }
        }
    }
}, verbosity='executionStats')
```

=== Evidencia del Plan Ganador (`winningPlan`)

El análisis arrojó las siguientes estadísticas de ejecución:

```text
Etapas del Plan Ganador: ['FETCH', 'IXSCAN']
Etapa de Entrada (Index Scan):
  - stage: 'IXSCAN'
  - indexName: 'geometry_2dsphere'
  - isMultiKey: true
  - keyPattern: { 'geometry': '2dsphere' }
Métricas de Rendimiento:
  - totalDocsExamined: 1
  - nReturned: 1
  - executionTimeMillis: ~7 ms
```

Este resultado confirma que el motor:
+ Utiliza de manera exclusiva el índice espacial `geometry_2dsphere` mediante la etapa `IXSCAN`.
+ Recupera directamente el registro mediante la etapa `FETCH`, evaluando exactamente un documento (`totalDocsExamined: 1`).
+ Evita por completo la inspección lineal de la colección, asegurando una complejidad de búsqueda de orden logarítmico apta para procesos de alta concurrencia.

== Métricas de Almacenamiento en la Base de Datos

Mediante el comando administrativo `collStats`, se recolectaron las dimensiones de almacenamiento físico y lógico en disco de las colecciones gestionadas:

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.8fr, 1.3fr, 1.5fr, 1.4fr),
      align: (left, center, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Colección*], [*Documentos*], [*Tamaño Lógico*], [*Tamaño en Disco (WiredTiger)*],
      [`municipalities_pdet`], [170], [50,41 MB], [27,24 MB],
      [`catalogo_municipios_pdet`], [170], [0,027 MB (27 KB)], [0,024 MB (24 KB)],
      [*Total General Base de Datos*], [*340*], [*50,44 MB*], [*27,26 MB*],
    )
  ],
  caption: [Métricas de almacenamiento de la base de datos `upme_pdet` en MongoDB.],
)

El motor de almacenamiento *WiredTiger* logra una compresión física de casi el 50 % sobre las coordenadas de los polígonos, manteniendo los índices espaciales completamente en memoria RAM (apenas 124 KB totales de índice para toda la colección).

== Integración Espacial de Huellas de Edificaciones (Microsoft y Google)

Tras la ingestión y restauración del conjunto masivo de huellas de construcciones (`buildings_microsoft` con 1.761.047 registros y `buildings_google` con 2.694.786 registros), se implementaron y verificaron los índices espaciales esféricos (`2dsphere`) y compuestos requeridos para habilitar consultas de alta velocidad sobre los 4,45 millones de edificaciones.

=== Catálogo de Índices Implementados

#figure(
  text(size: 10pt)[
    #table(
      columns: (1.4fr, 1.3fr, 1.1fr, 0.9fr, 2.3fr),
      align: (left, left, center, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Colección*], [*Nombre del Índice*], [*Tipo*], [*Espacio*], [*Campos Indexados y Propósito*],
      [`buildings_microsoft`], [`geometry_2dsphere`], [2dsphere (v4)], [31,69 MB], [`geometry`: Polígonos GeoJSON de huella para `$geoIntersects` y topología exacta.],
      [`buildings_microsoft`], [`centroid_2dsphere`], [2dsphere (v4)], [27,22 MB], [`centroid`: Punto GeoJSON de ubicación para `$near`, `$geoWithin` y clustering.],
      [`buildings_microsoft`], [`mpio_area`], [B-Tree Compuesto], [29,62 MB], [`{cod_dane_mpio: 1, rooftop_area_m2: -1}`: Filtrado municipal y ordenamiento por área.],
      [`buildings_microsoft`], [`quadkey_1`], [B-Tree], [8,72 MB], [`quadkey`: Trazabilidad y partición por tesela de Microsoft.],
      [`buildings_google`], [`centroid_2dsphere`], [2dsphere (v4)], [41,62 MB], [`centroid`: Punto GeoJSON para operadores esféricos (`$geoWithin`, `$near`).],
      [`buildings_google`], [`mpio_area`], [B-Tree Compuesto], [49,37 MB], [`{cod_dane_mpio: 1, rooftop_area_m2: -1}`: Consultas analíticas y percentiles por municipio.],
      [`buildings_google`], [`source_file_1`], [B-Tree], [12,90 MB], [`source_file`: Control de ingestión y reanudación idempotente.],
    )
  ],
  caption: [Índices espaciales y analíticos en las colecciones de huellas de edificaciones.],
)

=== Evidencia de Auditoría con Planes de Ejecución (`explain`)

Para comprobar empíricamente que MongoDB utiliza los índices espaciales construidos y no realiza escaneos exhaustivos sobre los millones de documentos, se auditaron las siguientes consultas mediante `explain("executionStats")`:

==== 1. Intersección Espacial sobre Polígonos de Microsoft (`$geoIntersects`)
Se consultó la edificación cuya huella encierra un punto arbitrario en el municipio de Santa Marta:

```javascript
db.buildings_microsoft.find({
  geometry: {
    $geoIntersects: {
      $geometry: { type: "Point", coordinates: [-73.8297, 11.2489] }
    }
  }
}).explain("executionStats");
```

- *Etapa ganadora (`winningPlan`):* `FETCH` $arrow.l$ `IXSCAN`.
- *Índice utilizado:* `geometry_2dsphere`.
- *Tiempo de ejecución:* *22 ms*.
- *Documentos examinados:* 62 documentos (descartando 1.760.985 registros no pertinentes).
- *Documentos retornados:* 1 documento coincidente exacto.

==== 2. Consulta de Proximidad Radial sobre Centroides de Microsoft (`$geoWithin`)
Se realizó una búsqueda de edificaciones en un radio de 1 km alrededor de Santa Marta (`$centerSphere`):

```javascript
db.buildings_microsoft.find({
  centroid: {
    $geoWithin: {
      $centerSphere: [ [-74.21, 11.24], 1 / 6378.1 ]
    }
  }
}).explain("executionStats");
```

- *Etapa ganadora:* `FETCH` $arrow.l$ `IXSCAN`.
- *Índice utilizado:* `centroid_2dsphere`.
- *Tiempo de ejecución:* *13 ms*.
- *Documentos examinados:* 2.519 candidatos espaciales.
- *Documentos retornados:* 1.977 edificaciones en el radio definido.

==== 3. Consulta de Proximidad Radial sobre Centroides de Google (`$geoWithin`)
Se ejecutó una consulta esférica análoga sobre la colección de Google (2,69 millones de documentos) en un radio de 1 km en la cabecera de Valledupar:

```javascript
db.buildings_google.find({
  centroid: {
    $geoWithin: {
      $centerSphere: [ [-73.25, 10.46], 1 / 6378.1 ]
    }
  }
}).explain("executionStats");
```

- *Etapa ganadora:* `FETCH` $arrow.l$ `IXSCAN`.
- *Índice utilizado:* `centroid_2dsphere`.
- *Tiempo de ejecución:* *93 ms*.
- *Documentos examinados:* 17.413 candidatos espaciales.
- *Documentos retornados:* 11.604 edificaciones identificadas.

==== 4. Aceleración Analítica con Índice Compuesto `mpio_area`
Se evaluó el filtrado de construcciones con potencial solar superior a 100 m² en Santa Marta (`cod_dane_mpio: "47001"`):

- *Índice utilizado:* `mpio_area`.
- *Tiempo de ejecución:* *91 ms*.
- *Documentos examinados:* 33.971 documentos.
- *Documentos retornados:* 33.971 registros (`totalDocsExamined == nReturned`, eficiencia perfecta 1:1 sin inspección de documentos ajenos).

== Conclusión de la Fase 2 y Enlace con Fase 3

Con la ejecución de esta etapa, se da cumplimiento total a los requisitos establecidos para la integración espacial NoSQL:
+ *Límites Municipales:* 170 municipios PDET cargados e indexados con `2dsphere` y validados con 170/170 aciertos en pruebas de punto interior.
+ *Huellas Masivas:* 4.455.833 edificaciones (1,76 M en Microsoft y 2,69 M en Google) indexadas espacialmente con tiempos de respuesta inferiores a 100 milisegundos.

La infraestructura NoSQL queda completamente optimizada para el análisis exploratorio de datos (EDA) y la estimación geoespacial del potencial solar fotovoltaico en cubiertas.
