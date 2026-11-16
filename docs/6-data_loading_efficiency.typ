= Data Loading Efficiency

Este capítulo describe cómo se cargaron en MongoDB las huellas de edificios de dos fuentes: *Microsoft* y *Google Open Buildings*. En ambos casos solo se guardan los edificios de los 170 municipios PDET. Las dos cargas comparten la misma preparación previa, que se explica primero.

== Preparación común: municipios PDET

Antes de cargar edificios de cualquier fuente hay que tener la frontera de los 170 municipios PDET. Se hace una sola vez.

+ *Listado oficial.* Se parte del Excel `MunicipiosPDET.xlsx` y del shapefile del marco geoestadístico (DANE/IGAC).
+ *Municipios en formato NDJSON.* Un script (`prepare-pdet.py`) cruza el Excel con el shapefile y genera `data/processed/municipalities_pdet.ndjson`, con la geometría de cada municipio PDET.
+ *Frontera unificada.* Las geometrías de los 170 municipios se disuelven en una sola (`pdet_union.geojson`). Con una única frontera, decidir si un edificio es PDET es una sola pregunta espacial.

```bash
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp \
  --xlsx data/MunicipiosPDET.xlsx \
  --export data/processed/municipalities_pdet.ndjson \
  --uri "$MONGO_URI" --db upme_pdet
```

```python
import json, os
import geopandas as gpd
from shapely.geometry import shape

input_ndjson = "data/processed/municipalities_pdet.ndjson"
output_geojson = "data/google_open_buildings/boundaries/pdet_union.geojson"
os.makedirs(os.path.dirname(output_geojson), exist_ok=True)

geometries = []
with open(input_ndjson, "r", encoding="utf-8") as f:
    for line in f:
        if line.strip():
            record = json.loads(line)
            if "geometry" in record:
                geometries.append(shape(record["geometry"]))

gdf = gpd.GeoDataFrame(geometry=geometries, crs="EPSG:4326")
gdf_union = gpd.GeoDataFrame(geometry=[gdf.geometry.union_all()], crs="EPSG:4326")
gdf_union.to_file(output_geojson, driver="GeoJSON")
```

== Edificios de Microsoft

=== Qué se cargó

Microsoft publica las huellas de los edificios de Colombia en 232 archivos comprimidos, uno por cada cuadro del mapa (llamado _quadkey_). En total pesan 0,63 GB comprimidos y traen 8.221.407 edificios. Como el proyecto solo trabaja con los 170 municipios PDET, antes de guardar cada edificio se revisa en qué municipio cae y se descarta si no es PDET.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1.3fr, 2.2fr),
      align: (left, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Valor*], [*Qué significa*],
      [Archivos de Colombia], [232], [Todos se descargaron y se leyeron.],
      [Edificios leídos], [8.221.407], [Todos los edificios de Colombia que publica Microsoft.],
      [Edificios fuera de PDET], [6.460.360 (78,6 %)], [Se descartan antes de guardar.],
      [Edificios guardados], [1.761.047 (21,4 %)], [Solo los de los 170 municipios PDET.],
      [Geometrías descartadas], [0], [Las dañadas se repararon, ninguna se perdió.],
      [Errores al insertar], [0], [Todos los edificios entraron sin problema.],
    )
  ],
  caption: [Resultado de la carga de Microsoft.],
)

=== Paso a paso

+ *Preparar los municipios PDET* (sección anterior).
+ *Descargar los archivos de Colombia.* Se baja el listado de Microsoft y se descargan los 232 archivos. Los que ya están en disco se reutilizan.
+ *Leer un archivo a la vez.* Cada archivo se lee y se procesa por separado.
+ *Limpiar la geometría.* Las coordenadas se redondean a 7 decimales y los polígonos dañados se reparan.
+ *Asignar el municipio.* Cada edificio se cruza con los municipios PDET. Si no cae en uno, se descarta.
+ *Calcular el área de techo* en metros cuadrados, usando la proyección oficial EPSG:9377.
+ *Guardar por lotes* de 5.000 edificios en MongoDB, en modo "sin orden".
+ *Crear los índices al final*, una sola vez, cuando ya están todos los datos.

La carga completa se puede repetir: cada vez borra la colección y la vuelve a llenar, sin duplicar datos.

=== Cómo se hizo la carga

Para que la carga fuera rápida y no gastara memoria de más, se usaron estas ideas:

- *Descartar lo que no sirve cuanto antes.* Casi cuatro de cada cinco edificios no son de municipios PDET, así que se dejan fuera antes de tocar la base de datos.
- *Un archivo a la vez.* Se lee, se procesa y se guarda cada archivo por separado. Así nunca se tienen los 8 millones de edificios en memoria. El pico fue de 763 MB.
- *Guardar por lotes.* Los edificios se envían a MongoDB en grupos de 5.000, en vez de uno por uno. El modo "sin orden" permite que un edificio con problema no detenga a los demás.
- *Crear los índices al final.* Los índices espaciales se construyen una sola vez, cuando ya están todos los datos.
- *Limpiar las geometrías.* Las coordenadas se redondean a 7 decimales (alrededor de 1 centímetro) y los polígonos dañados se reparan, porque el índice espacial no acepta mapas con errores.
- *No repetir descargas.* Los archivos ya bajados se reutilizan, y la carga completa se puede repetir: cada vez borra la colección y la vuelve a llenar, sin duplicar datos.

Cada edificio queda con su municipio (`cod_dane_mpio`), su área de techo en metros cuadrados (calculada en la proyección oficial EPSG:9377), su altura (vacía cuando Microsoft no la tiene), el cuadro de origen y los datos de la carga.

=== Cuánto tardó

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1fr, 1fr),
      align: (left, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Etapa*], [*Segundos*], [*Del total*],
      [Descargar los 232 archivos], [672], [27 %],
      [Leer los archivos], [898], [37 %],
      [Procesar (cruce con municipios y áreas)], [768], [31 %],
      [Guardar en MongoDB], [64], [3 %],
      [Crear los índices], [45], [2 %],
      [*Total*], [*2.447 (unos 41 min)*], [*100 %*],
    )
  ],
  caption: [Tiempo de la carga completa de Microsoft.],
)

Lo más importante de la tabla: *guardar en MongoDB es lo más rápido de todo* (unos 27.600 edificios por segundo). El tiempo se va en bajar, leer y procesar los archivos. Por eso, mejorar la carga depende más de cómo se leen y se preparan los datos que de la base de datos.

=== Pruebas de eficiencia

Para comparar opciones se cargaron los 5 archivos más pesados (1.499.624 edificios leídos, 96.727 guardados) cuatro veces, cambiando una sola cosa cada vez.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2.2fr, 1fr, 1fr, 1fr),
      align: (left, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Prueba*], [*Guardar (s)*], [*Índices (s)*], [*Guardar + índices (s)*],
      [Lotes de 1.000], [2,7], [2,9], [5,6],
      [Lotes de 5.000], [3,7], [2,7], [6,4],
      [Lotes de 10.000], [3,3], [2,6], [5,9],
      [Lotes de 5.000, índices antes de cargar], [6,5], [0,1], [6,6],
    )
  ],
  caption: [Comparación de opciones sobre los 5 archivos más pesados.],
)

Lo que se vio:

- *El tamaño del lote casi no cambia nada.* Con 1.000, 5.000 o 10.000 el tiempo de guardar y crear índices fue parecido (entre 5,6 y 6,4 segundos). Los tiempos totales de las corridas variaron más por la lectura de archivos (entre 103 y 182 segundos), que depende del computador en ese momento, no del lote. Se dejó 5.000 como valor por defecto.
- *Crear los índices antes de cargar hace más lenta la carga* (6,5 s contra 3,7 s con el mismo lote), porque MongoDB actualiza el índice con cada edificio que entra. Al sumar el tiempo de crear los índices, el total queda casi igual (6,6 s contra 6,4 s), así que con esta cantidad de datos la diferencia es pequeña. Se eligió crearlos al final porque es la práctica recomendada y el costo se paga una sola vez.
- *La memoria se mantuvo baja:* unos 490 MB con 5 archivos y 763 MB en la carga completa, sobre todo por los archivos más grandes.

=== Espacio que ocupa

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1.2fr),
      align: (left, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Valor*],
      [Edificios guardados], [1.761.047],
      [Tamaño promedio de un edificio], [579 bytes],
      [Tamaño de los datos sin comprimir], [1.020 MB],
      [Espacio en disco (comprimido por MongoDB)], [260 MB],
      [Espacio de todos los índices], [117 MB],
    )
  ],
  caption: [Espacio que ocupa la colección `buildings_microsoft`.],
)

MongoDB comprime los datos y los deja casi cuatro veces más pequeños en disco (de 1.020 MB a 260 MB). Los índices pesan 117 MB en total: el espacial del mapa 31,7 MB, el del centroide 27,2 MB, el de municipio y área 29,6 MB, el del cuadro 8,7 MB y el del identificador 19,7 MB.

=== Problemas que aparecieron

- *Un polígono dañado detuvo la primera carga completa* (cerca de Santa Marta). Se agregó un paso que repara los polígonos con errores antes de guardarlos; con eso la carga terminó sin descartar ninguno.
- *La altura viene vacía.* En los archivos de Microsoft la altura y la confianza vienen con el valor -1 cuando no hay dato. Ese -1 se guarda como vacío (`null`), para que no se confunda con una altura real.
- *Los archivos del inicio no tenían edificios PDET.* Los primeros archivos de la lista caen en zonas sin municipios PDET, así que las primeras pruebas no insertaron nada. Esto era correcto, no un error: se confirmó con un archivo de Nariño.
- *El código del cuadro pierde el cero inicial* en la lista de Microsoft (`32203213` en vez de `032203213`). Se completa a 9 dígitos.

=== Comprobaciones finales

Después de la carga completa se hicieron tres comprobaciones en MongoDB:

- *Cobertura.* Los 170 municipios PDET tienen edificios de Microsoft. Ninguno quedó sin datos.
- *Uso del índice.* Se buscó qué edificios contienen un punto dado (consulta `$geoIntersects`). MongoDB usó el índice espacial (`IXSCAN`), revisó solo 3 documentos de los 1,76 millones y respondió en 8 milisegundos.
- *Municipios con más edificios.* El conteo por municipio funciona y da resultados razonables, con las ciudades más grandes arriba.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (0.9fr, 2fr, 1.2fr, 1.4fr),
      align: (center, left, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Código*], [*Municipio*], [*Edificios*], [*Área de techos (km²)*],
      [47001], [Santa Marta (Magdalena)], [67.664], [14,21],
      [20001], [Valledupar (Cesar)], [63.722], [13,51],
      [05837], [Turbo (Antioquia)], [43.360], [4,66],
      [52835], [Tumaco (Nariño)], [41.423], [4,52],
      [54810], [Tibú (Norte de Santander)], [35.478], [3,57],
    )
  ],
  caption: [Los cinco municipios PDET con más edificios en los datos de Microsoft.],
)

== Edificios de Google Open Buildings

=== Qué se cargó

Google Open Buildings publica las edificaciones en archivos comprimidos (`.csv.gz`), uno por cada celda del mapa (llamada _tesela S2_). Cada fila trae la latitud y longitud del edificio, un nivel de confianza, su área en metros cuadrados y la huella en formato WKT. Como el proyecto solo trabaja con los 170 municipios PDET, el proceso hace dos descartes:

- *Al descargar:* solo se bajan las teselas que tocan las zonas de estudio, no todas las de Colombia.
- *Al cargar:* de cada tesela descargada, solo se guardan los edificios cuyo punto cae dentro de un municipio PDET. A cada edificio se le asigna el código de su municipio (`cod_dane_mpio`), igual que en la carga de Microsoft.

Cada edificio guardado queda con estos campos:

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.6fr, 2.6fr),
      align: (left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Campo*], [*Qué contiene*],
      [`cod_dane_mpio`], [Código del municipio PDET donde cae el edificio.],
      [`dataset_source`], [Fuente del dato: `google_open_buildings`.],
      [`centroid`], [Punto GeoJSON (longitud, latitud) del edificio. Tiene el índice espacial.],
      [`rooftop_area_m2`], [Área de la huella, en metros cuadrados, tal como la entrega Google. Vacía (`null`) si falta.],
      [`confidence`], [Confianza de Google de que es un edificio. Vacía (`null`) si falta.],
      [`capture_metadata`], [Licencia, identificador de la carga y fecha en que se cargó.],
      [`source_file`], [Archivo de origen. Sirve para reanudar y para limpiar cargas a medias.],
    )
  ],
  caption: [Campos de cada documento en `buildings_google`.],
)

=== Requisitos

- Python 3.11 o superior, manejado con `uv`.
- Docker y Docker Compose, para el MongoDB local.
- Librerías de Python: `geopandas`, `pandas`, `shapely` (2.0 o superior, por `contains_xy`), `pymongo` y `pyogrio`.

Estructura de carpetas que usa la carga:

```text
dba-proj-20263/
├── data/
│   ├── MunicipiosPDET.xlsx
│   ├── raw/MGN2025/                      # Marco Geoestadístico Nacional
│   ├── processed/municipalities_pdet.ndjson
│   └── google_open_buildings/
│       ├── raw/                          # teselas .csv.gz descargadas
│       └── boundaries/pdet_union.geojson # frontera PDET unificada
├── logs/importacion.log
└── src/
    ├── 1-pdet_mgn/                       # prepare-pdet.py
    ├── 2-mongo_container_test/           # compose.yml y .env
    └── 3-google_open_buildings/
        ├── download_pdet_buildings.py    # descarga selectiva de teselas
        └── importer.py                   # ETL con multiprocesamiento
```

=== Paso a paso

+ *Levantar MongoDB.* Desde `src/2-mongo_container_test/`, con las credenciales definidas en el archivo `.env`, se inicia el contenedor (red `pdet_network`). La conexión usa una variable de entorno, para no escribir contraseñas en el código:

  ```bash
  export MONGO_URI="mongodb://<usuario>:<contraseña>@localhost:27017/?authSource=admin"
  ```

+ *Preparar los municipios PDET.* Se ejecuta `prepare-pdet.py`, como se explicó en la preparación común.

+ *Generar `pdet_union.geojson`.* Se disuelven los 170 municipios en una sola frontera, también según la preparación común.

+ *Descargar las teselas.* El script cruza las celdas S2 de Google con los límites del área de estudio y baja solo los `.csv.gz` que la tocan, dejándolos en `data/google_open_buildings/raw/`:

  ```bash
  uv run src/3-google_open_buildings/download_pdet_buildings.py
  ```

+ *Ejecutar la carga.* Lee cada tesela, filtra los edificios PDET y los guarda en MongoDB:

  ```bash
  uv run src/3-google_open_buildings/importer.py
  ```

+ *Revisar el resultado.* Al terminar, el script imprime por cada archivo cuántas filas leyó, cuántas insertó y cuánto tardó. Los mismos datos quedan en la colección `etl_processed_files`.

Parámetros que se pueden cambiar sin tocar el código:

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.6fr, 1.1fr, 2.6fr),
      align: (left, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Parámetro*], [*Por defecto*], [*Para qué sirve*],
      [`MONGO_URI`], [local], [Dirección y credenciales de MongoDB.],
      [`ETL_WORKERS`], [núcleos - 1], [Cuántos archivos se procesan a la vez.],
      [`ETL_RESET=1`], [apagado], [Vacía la colección y el registro de control, y empieza de cero.],
      [`CHUNK_SIZE`], [500.000], [Filas del CSV que se leen por bloque. Bajarlo si falta memoria.],
      [`INSERT_BATCH_SIZE`], [50.000], [Documentos por envío a MongoDB.],
    )
  ],
  caption: [Parámetros del ETL de Google Open Buildings.],
)

=== Cómo se hizo la carga

Se aplicaron estas ideas para que la carga fuera rápida y no gastara memoria de más:

- *Leer solo lo necesario.* Se leen únicamente las columnas de latitud, longitud, confianza y área. La columna de la huella, que es la más pesada, no se lee.
- *Leer por bloques.* Los archivos se leen en bloques de 500.000 filas, para no cargar un archivo completo en memoria.
- *Descartar lo que no sirve cuanto antes.* Primero se descartan los puntos fuera del rectángulo que encierra la frontera PDET, que es una prueba muy barata. Después, a los que quedan, se les hace la prueba exacta de pertenencia con `shapely.contains_xy` sobre una frontera "preparada" (`shapely.prepare`), que acelera las consultas repetidas.
- *Sin recorrer fila por fila.* El filtro espacial trabaja sobre todo el bloque a la vez, y los documentos se arman a partir de listas, sin `iterrows`.
- *Asignar el municipio.* Cada proceso carga una vez los 170 municipios desde MongoDB, y a los edificios que pasan el filtro se les busca su municipio con un cruce espacial. Así la colección queda con el mismo esquema que la de Microsoft y se puede contar por municipio sin pasos extra.
- *Un solo campo de ubicación.* El punto se guarda una vez, en `centroid`, con un índice `2dsphere`. Se agregan además un índice por municipio y área (`cod_dane_mpio`, `rooftop_area_m2`) y uno por `source_file`.
- *Varios archivos a la vez.* Cada archivo es independiente, así que se procesan en paralelo con `ProcessPoolExecutor`. Cada proceso abre su propia conexión a MongoDB y carga su propia copia de la frontera.
- *Guardar por lotes.* Los edificios se envían en grupos de 50.000, en modo "sin orden" (`ordered=False`). Si algún lote falla en parte, se reporta cuántos entraron y cuántos no, en vez de ocultar el error.
- *Poder repetir la carga sin duplicar.* Cada archivo terminado se anota en `etl_processed_files` y se salta en la siguiente corrida. Si una carga se corta a la mitad de un archivo, lo que alcanzó a entrar se borra (usando `source_file`) y el archivo se procesa de nuevo.
- *Crear los índices al final.* Los índices (`centroid`, municipio y área, y `source_file`) se construyen una sola vez, cuando ya están todos los datos.

=== Cuánto tardó

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1fr, 2fr),
      align: (left, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Valor*], [*De dónde sale*],
      [Teselas descargadas], [8], [Archivos `.csv.gz` en `raw/`.],
      [Edificios leídos], [31.499.115], [Suma de `rows_read` en `etl_processed_files`.],
      [Edificios guardados], [2.694.786 (8,6 %)], [Suma de `rows_inserted` en `etl_processed_files`.],
      [Tiempo de la carga], [X minutos], [Mensaje final del script (poner el valor real).],
      [Tamaño de los datos sin comprimir], [1.040 MB], [`db.buildings_google.stats()`.],
      [Espacio en disco], [184 MB], [`db.buildings_google.stats()`.],
      [Espacio de los índices], [134 MB], [`db.buildings_google.stats()`.],
    )
  ],
  caption: [Resultados de la carga de Google Open Buildings.],
)

Como en Microsoft, la gran mayoría de los edificios leídos (91,4 %) queda fuera, porque no está en un municipio PDET.

=== Cosas a tener en cuenta

- *Solo se guarda el centroide.* El archivo de Google trae la huella del edificio como polígono, pero se guarda solo el punto, que es lo que hace falta para contar edificios por municipio. El área sí se conserva, tal como la calcula Google.
- *Cinco municipios sin edificios de Google.* Murindó y Vigía del Fuerte (Antioquia), y Bojayá, Medio San Juan y Nóvita (Chocó) no tienen ningún edificio en esta colección. Las teselas que cubren esas zonas sí se descargaron y se cargaron completas, así que con los datos de Google que se bajaron esos municipios simplemente no aparecen. Microsoft sí tiene edificios en los cinco (entre 1.331 y 2.004 en cada uno). Por eso los dos conjuntos no cubren lo mismo y el análisis final debe decirlo.
- *Datos vacíos.* La confianza y el área vacías se guardan como `null`, igual que en Microsoft, para no confundir "sin dato" con "cero".
- *Los puntos justo sobre el borde.* La prueba de pertenencia deja fuera los puntos que están exactamente sobre el límite de un municipio. Es una diferencia mínima y no afecta los resultados en la práctica.
- *Memoria.* Cada proceso mantiene su propio bloque de filas y su copia de los municipios. Si la memoria es justa, conviene bajar `ETL_WORKERS` o `CHUNK_SIZE`.
- *Credenciales.* La contraseña no debe escribirse en el código ni en este documento: se pasa por `MONGO_URI`.

=== Comprobaciones finales

Después de la carga se revisó lo mismo que con Microsoft:

- *Conteo.* La colección `buildings_google` tiene 2.694.786 documentos, igual a la suma de `rows_inserted` en `etl_processed_files`.
- *Índices.* Quedaron creados `centroid_2dsphere`, `mpio_area` y `source_file_1`.
- *Cobertura.* 165 de los 170 municipios PDET tienen edificios. Los cinco que faltan se explican en "Cosas a tener en cuenta".

== Microsoft y Google: en qué se parecen y en qué no

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.4fr, 2fr, 2fr),
      align: (left, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Aspecto*], [*Microsoft*], [*Google Open Buildings*],
      [Archivos de origen], [232 archivos por _quadkey_], [Archivos `.csv.gz` por tesela S2],
      [Descarte de lo no PDET], [Por municipio, antes de guardar], [Por frontera PDET unificada, antes de guardar],
      [Qué se guarda por edificio], [Huella, municipio, área de techo, altura, cuadro de origen], [Punto, municipio, área de techo, confianza, archivo de origen],
      [Municipio], [Se asigna al cargar (`cod_dane_mpio`)], [Se asigna al cargar (`cod_dane_mpio`)],
      [Datos vacíos], [Se guardan como `null`], [Se guardan como `null`],
      [Forma de procesar], [Un archivo a la vez, lotes de 5.000], [Varios archivos en paralelo, lotes de 50.000],
      [Repetir la carga], [Borra la colección y la vuelve a llenar], [Salta los archivos ya cargados; `ETL_RESET=1` para empezar de cero],
      [Índices], [Se crean al final], [Se crean al final],
      [Municipios PDET con edificios], [170 de 170], [165 de 170],
    )
  ],
  caption: [Comparación de las dos cargas.],
)
