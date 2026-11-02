= Diseño de Esquema y Modelado de Datos (Schema Design & Data Modeling)

== Paradigma de Modelado NoSQL Geoespacial

Para responder a los requerimientos de escalabilidad, flexibilidad estructural y procesamiento espacial masivo planteados por la *Oficina de Investigaciones e Información de la UPME*, se diseñó un modelo de datos orientado a documentos sobre *MongoDB*. A diferencia de un esquema relacional tradicional normalizado en tercera forma normal (3NF), el enfoque documental BSON (_Binary JSON_) permite:

+ *Almacenamiento Nativo de Geometrías Complejas:* Representación directa de objetos estándar *GeoJSON* (`Polygon`, `MultiPolygon` y `Point`) embebidos dentro de cada documento territorial o de edificación, evitando costosos _joins_ entre tablas de vértices, anillos y atributos alfanuméricos.
+ *Integración del Catálogo Oficial PDET (`data/MunicipiosPDET.xlsx`) con el MGN-DANE:* Fusión directa de la tabla maestra suministrada en `data/MunicipiosPDET.xlsx` (170 municipios distribuidos en 16 subregiones PDET) con los polígonos oficiales del *Marco Geoestadístico Nacional (MGN 2025)* del DANE en una única colección maestra (`municipalities_pdet`), aplicando normalización de códigos DANE con ceros a la izquierda (`zfill(5)` y `zfill(2)`).
+ *Indexación Espacial Esférica (`2dsphere`):* Creación de índices geoespaciales sobre coordenadas geográficas *WGS84 (EPSG:4326)* que aceleran exponencialmente predicados espaciales como `$geoIntersects` y `$geoWithin` mediante una grilla jerárquica de celdas esféricas (Google S2).
+ *Coexistencia de Fuentes Heterogéneas:* Almacenamiento independiente y desacoplado de los datasets satelitales (*Microsoft Building Footprints* y *Google Open Buildings V3*), preservando los metadatos nativos de cada proveedor (como `quadkey` en Microsoft o `full_plus_code` y `confidence` en Google) junto con campos homologados (`rooftop_area_m2` y `cod_dane_mpio`).
+ *Vista Materializada de Agregación (`solar_aggregations`):* Desnormalización controlada de las métricas calculadas por municipio PDET mediante subdocumentos embebidos (`metrics_microsoft`, `metrics_google`, `comparison_metrics`, `solar_potential`), optimizando la lectura analítica y la generación de reportes y mapas coropléticos en tiempo constante $O(1)$ por municipio.

== Diagrama Entidad-Relación Adaptado a NoSQL

La @fig-er-diagram presenta el diagrama Entidad-Relación (E-R), donde se detallan el dataset maestro de entrada (`data/MunicipiosPDET.xlsx`), las cuatro colecciones principales en MongoDB, sus llaves primarias (`PK`), llaves únicas de negocio (`UK`), referencias lógicas (`FK`), índices espaciales (`2dsphere`), subdocumentos BSON embebidos (`Object {...}`) y los mecanismos de interacción espacial y de agregación.

#figure(
  image("../diagrams/1-er.png", width: 100%),
  caption: [Diagrama Entidad-Relación Documental (NoSQL MongoDB) integrando `data/MunicipiosPDET.xlsx` y el MGN-DANE para la estimación de potencial solar.],
) <fig-er-diagram>

== Diccionario de Datos de las Entidades Clave

A continuación, se presenta el diccionario de datos detallado para la fuente maestra de territorios PDET (`data/MunicipiosPDET.xlsx`) y cada una de las cuatro colecciones que conforman la arquitectura de persistencia NoSQL del proyecto.

=== Fuente Maestra de Filtrado: `catalogo_municipios_pdet` (`data/MunicipiosPDET.xlsx`)

El archivo `data/MunicipiosPDET.xlsx` constituye el insumo oficial de focalización territorial del proyecto. Contiene exactamente *170 filas de datos* (más encabezado) distribuidas en *16 subregiones PDET* y cuenta con dos hojas de cálculo complementarias (`MunicipiosPDET` con 5 columnas y `Hoja1` que adiciona la columna `id` numérico de la subregión del `1` al `16`).

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.5fr, 1.1fr, 0.9fr, 2.5fr),
      align: (left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Columna en Excel*], [*Campo Normalizado*], [*Tipo / Regla*], [*Descripción y Regla de Transformación*],
      [`id` _(Hoja1)_],
      [`subregion_pdet.id`],
      [`Int32 [1..16]`],
      [Identificador secuencial de la subregión PDET (de `1: ALTO PATÍA Y NORTE DEL CAUCA` a `16: URABÁ ANTIOQUEÑO`).],

      [`Subregión PDET`],
      [`subregion_pdet.nombre`],
      [`String`],
      [Nombre oficial de la subregión PDET en mayúsculas sostenidas.],

      [`Código DANE Departamento`],
      [`cod_dane_dpto`],
      [`String (2)`],
      [Almacenado como entero en Excel (ej. `5` para Antioquia, `19` para Cauca). Se normaliza con `str.zfill(2)` a `"05"` para cruzar con `DPTO_CCDGO` del MGN.],

      [`Departamento`],
      [`departamento`],
      [`String`],
      [Nombre oficial del departamento (ej. `"CAUCA"`, `"ANTIOQUIA"`, `"NARIÑO"`).],

      [`Código DANE Municipio`],
      [`cod_dane_mpio`],
      [`UK`, `String (5)`],
      [Llave única natural del municipio (código DANE único para cada uno de los 170 municipios PDET). En Excel viene como entero (ej. `5045` para Apartadó, `19050` para Argelia); se transforma con `str.zfill(5)` a `"05045"` para cruzar exactamente con `MPIO_CDPMP` del MGN-DANE.],

      [`Municipio`],
      [`municipio`],
      [`String`],
      [Nombre oficial del municipio priorizado como territorio PDET (170 municipios en total).],
    )
  ],
  caption: [Estructura y reglas de normalización del archivo fuente `data/MunicipiosPDET.xlsx`.],
)

=== Entidad 1: `municipalities_pdet` (Límites Político-Administrativos PDET)

Esta colección es el resultado del cruce (`INNER JOIN` `1:1`) entre el catálogo `data/MunicipiosPDET.xlsx` y la capa vectorial municipal del *Marco Geoestadístico Nacional (MGN 2025)* del DANE. Almacena exactamente los *170 documentos municipales PDET* con su geometría validada.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.4fr, 1.1fr, 0.9fr, 2.6fr),
      align: (left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("dae8fc") } else { none },
      [*Campo / Atributo*], [*Tipo BSON*], [*Restricción / Índice*], [*Descripción y Dominio*],
      [`_id`],
      [`ObjectId`],
      [`PK`],
      [Identificador único interno autogenerado por MongoDB para cada documento municipal.],

      [`cod_dane_mpio`],
      [`String (5)`],
      [`UK`, `NOT NULL`],
      [Código DANE concatenado de 5 dígitos (`MPIO_CDPMP` del MGN homologado con `Código DANE Municipio` vía `zfill(5)`, ej. `"05045"`).],

      [`cod_dane_dpto`],
      [`String (2)`],
      [`INDEX`],
      [Código DANE departamental de 2 dígitos (`DPTO_CCDGO` homologado con `Código DANE Departamento` vía `zfill(2)`, ej. `"05"`).],

      [`municipio`],
      [`String`],
      [`NOT NULL`],
      [Nombre oficial del municipio proveniente de `MunicipiosPDET.xlsx` y verificado frente a `MPIO_CNMBR` del MGN.],

      [`departamento`],
      [`String`],
      [`NOT NULL`],
      [Nombre oficial del departamento (`Departamento` en Excel / `DPTO_CNMBR` en MGN).],

      [`subregion_pdet`],
      [`Object`],
      [`INDEX`],
      [Subdocumento embebido `{id: Int32 [1..16], nombre: String}` construido a partir de las columnas `id` y `Subregión PDET` de `MunicipiosPDET.xlsx`.],

      [`area_oficial_km2`],
      [`Double`],
      [`> 0`],
      [Área superficial municipal en kilómetros cuadrados ($text("km")^2$), obtenida de `MPIO_NAREA` y verificada en proyección `EPSG:9377`.],

      [`geometry`],
      [`Object (GeoJSON)`],
      [`2dsphere`],
      [Objeto geométrico estándar GeoJSON de tipo `Polygon` o `MultiPolygon` en coordenadas geográficas WGS84 (`EPSG:4326`).],

      [`bbox`],
      [`Array<Double>`],
      [`4 elem.`],
      [Caja envolvente mínima (`[minLon, minLat, maxLon, maxLat]`) utilizada para pre-filtrado espacial rápido.],

      [`metadata_mgn`],
      [`Object`],
      [`NOT NULL`],
      [Subdocumento de linaje: `{vigencia: 2025, crs: "EPSG:4326", source_mgn: "DANE", source_xlsx: "MunicipiosPDET.xlsx", ingested_at: ISODate}`.],
    )
  ],
  caption: [Diccionario de datos de la colección `municipalities_pdet`.],
)

=== Entidad 2: `buildings_microsoft` (Huellas de Edificaciones — Microsoft)

Almacena los polígonos de cubiertas de edificaciones extraídos del dataset abierto *Microsoft Building Footprints* (derivado de imágenes satelitales Bing Maps / Maxar / Airbus bajo licencia ODbL) que intersectan los 170 municipios PDET.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.4fr, 1.1fr, 0.9fr, 2.6fr),
      align: (left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d5e8d4") } else { none },
      [*Campo / Atributo*], [*Tipo BSON*], [*Restricción / Índice*], [*Descripción y Dominio*],
      [`_id`], [`ObjectId`], [`PK`], [Identificador único BSON del documento de edificación.],
      [`quadkey`],
      [`String`],
      [`INDEX`],
      [Identificador jerárquico de tesela (_Bing Maps Tile System QuadKey_) de donde proviene la detección satelital.],

      [`cod_dane_mpio`],
      [`String (5)`],
      [`FK`, `INDEX`],
      [Código DANE del municipio PDET asignado tras el cruce espacial con `municipalities_pdet`.],

      [`dataset_source`],
      [`String`],
      [`NOT NULL`],
      [Etiqueta constante de trazabilidad de la fuente: `"microsoft_buildings"`.],

      [`geometry`],
      [`Object (GeoJSON)`],
      [`2dsphere`],
      [Contorno de la huella de techo en formato GeoJSON `{type: "Polygon", coordinates: [...]}` sobre datum `EPSG:4326`.],

      [`centroid`],
      [`Object (GeoJSON)`],
      [`2dsphere`],
      [Punto centroide `{type: "Point", coordinates: [lon, lat]}` precalculado para acelerar consultas de contención puntual.],

      [`rooftop_area_m2`],
      [`Double`],
      [`> 0`],
      [Área plana de la cubierta en metros cuadrados ($text("m")^2$), calculada mediante reproyección métrica a `EPSG:9377`.],

      [`height_m`],
      [`Double`],
      [`NULLABLE`],
      [Altura estimada de la edificación en metros cuando el registro fuente la incluye (`null` en caso contrario).],

      [`capture_metadata`],
      [`Object`],
      [`NOT NULL`],
      [Metadatos de captura e ingesta: `{imagery_dates: String, license: "ODbL", batch_id: String, loaded_at: ISODate}`.],
    )
  ],
  caption: [Diccionario de datos de la colección `buildings_microsoft`.],
)

=== Entidad 3: `buildings_google` (Huellas de Edificaciones — Google Open Buildings V3)

Almacena los contornos de edificaciones provenientes de *Google Open Buildings V3*, incorporando métricas propias del modelo de inferencia profunda de Google como el puntaje de confianza (`confidence`) y el código de localización abierta (`full_plus_code`).

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.4fr, 1.1fr, 0.9fr, 2.6fr),
      align: (left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("fff2cc") } else { none },
      [*Campo / Atributo*], [*Tipo BSON*], [*Restricción / Índice*], [*Descripción y Dominio*],
      [`_id`], [`ObjectId`], [`PK`], [Identificador único BSON del registro en la colección.],
      [`full_plus_code`],
      [`String`],
      [`UK`],
      [Código global _Open Location Code (Plus Code)_ asignado por Google al centroide de la huella detectada.],

      [`cod_dane_mpio`],
      [`String (5)`],
      [`FK`, `INDEX`],
      [Referencia lógica al campo `cod_dane_mpio` de la colección `municipalities_pdet` donde se ubica la edificación.],

      [`dataset_source`],
      [`String`],
      [`NOT NULL`],
      [Etiqueta constante de trazabilidad de la fuente: `"google_open_buildings_v3"`.],

      [`geometry`],
      [`Object (GeoJSON)`],
      [`2dsphere`],
      [Polígono GeoJSON (`Polygon`) convertido desde la representación WKT original en coordenadas `EPSG:4326`.],

      [`centroid`],
      [`Object (GeoJSON)`],
      [`2dsphere`],
      [Geometría puntual GeoJSON (`Point`) con la longitud y latitud reportadas por el dataset original.],

      [`area_in_meters`],
      [`Double`],
      [`> 0`],
      [Área superficial original en $text("m")^2$ reportada directamente en el archivo fuente de Google.],

      [`rooftop_area_m2`],
      [`Double`],
      [`> 0`],
      [Área de techo recalculada bajo el mismo sistema proyectado `EPSG:9377` que Microsoft para garantizar comparabilidad estricta.],

      [`confidence`],
      [`Double`],
      [`INDEX`, `[0.65, 1.0]`],
      [Puntaje de confianza del modelo de visión por computador. Permite filtrar umbrales de calidad (rojo $< 0.70$, amarillo $0.70-0.75$, verde $>= 0.75$).],

      [`capture_metadata`],
      [`Object`],
      [`NOT NULL`],
      [Subdocumento de origen: `{s2_token: String, version: "v3", license: "CC-BY-4.0 / ODbL", loaded_at: ISODate}`.],
    )
  ],
  caption: [Diccionario de datos de la colección `buildings_google`.],
)

=== Entidad 4: `solar_aggregations` (Síntesis Analítica y Potencial Solar por Municipio)

Representa la colección consolidada (vista materializada generada mediante pipelines de agregación `$match` $arrow.r$ `$group` $arrow.r$ `$project` $arrow.r$ `$merge`) que almacena los indicadores comparativos de conteo de edificaciones, área total de techos y potencial fotovoltaico estimado para cada uno de los 170 municipios PDET definidos en `MunicipiosPDET.xlsx`.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.4fr, 1.1fr, 0.9fr, 2.6fr),
      align: (left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("e1d5e7") } else { none },
      [*Campo / Atributo*], [*Tipo BSON*], [*Restricción / Índice*], [*Descripción y Dominio*],
      [`_id`], [`ObjectId`], [`PK`], [Identificador único del documento de agregación municipal.],
      [`cod_dane_mpio`],
      [`String (5)`],
      [`FK`, `UK`],
      [Llave única y referencia `1:1` hacia el campo `cod_dane_mpio` de `municipalities_pdet`.],

      [`municipio`],
      [`String`],
      [`NOT NULL`],
      [Nombre del municipio PDET (desnormalizado desde `MunicipiosPDET.xlsx` para reportes tabulares y mapas).],

      [`departamento`], [`String`], [`NOT NULL`], [Nombre del departamento correspondiente.],
      [`subregion_pdet`],
      [`Object`],
      [`INDEX`],
      [Subdocumento `{id: Int32 [1..16], nombre: String}` para agregaciones por subregión PDET.],

      [`metrics_microsoft`],
      [`Object`],
      [`NOT NULL`],
      [Subdocumento con métricas agregadas de Microsoft: `{building_count: Int64, total_area_m2: Double, total_area_ha: Double, avg_area_m2: Double, median_area_m2: Double}`.],

      [`metrics_google`],
      [`Object`],
      [`NOT NULL`],
      [Subdocumento con métricas agregadas de Google: `{building_count: Int64, total_area_m2: Double, total_area_ha: Double, avg_area_m2: Double, avg_confidence: Double}`.],

      [`comparison_metrics`],
      [`Object`],
      [`NOT NULL`],
      [Indicadores de contraste entre fuentes: `{delta_count: Int64, delta_area_m2: Double, delta_area_pct: Double, rooftop_density_pct: Double}`.],

      [`solar_potential`],
      [`Object`],
      [`INDEX`],
      [Estimación energética preliminar: `{usable_roof_m2: Double, est_capacity_kwp: Double, priority_rank: Int32}`.],

      [`computed_at`],
      [`ISODate`],
      [`NOT NULL`],
      [Marca temporal exacta de ejecución del flujo reproducible de agregación.],
    )
  ],
  caption: [Diccionario de datos de la colección `solar_aggregations`.],
)

== Interacciones entre Entidades y Operaciones Espaciales

Las interacciones entre las fuentes y colecciones combinan *normalización alfanumérica*, *predicados topológicos geoespaciales* y *referencias lógicas indexadas*, estructuradas en cuatro mecanismos principales:

+ *Integración y Filtrado Alfanumérico (`1 : 1` entre `MunicipiosPDET.xlsx` y MGN-DANE):*
  El archivo `data/MunicipiosPDET.xlsx` define el universo exacto de los 170 municipios PDET. Dado que en el archivo Excel los códigos de departamentos y municipios entre `01` y `09` (como Antioquia `5` y Apartadó `5045`) se almacenan como enteros sin cero inicial, el pipeline de ingesta aplica relleno de ceros a la izquierda (`zfill(2)` para `Código DANE Departamento` y `zfill(5)` para `Código DANE Municipio`). Con esta llave normalizada de 5 caracteres se realiza un cruce `1:1` contra el campo `MPIO_CDPMP` del shapefile municipal del MGN-DANE 2025, descartando los municipios no PDET y poblando `municipalities_pdet`.

+ *Interacción Espacial de Asignación Territorial (`1 : 0..N` vía `$geoIntersects` / `$geoWithin`):*
  Cada polígono municipal en `municipalities_pdet` (`geometry` indexado con `2dsphere`) se cruza espacialmente contra millones de huellas en `buildings_microsoft` y `buildings_google`. Para maximizar el rendimiento durante la ingesta y vinculación:
  - Primero se filtra por la caja envolvente (`bbox`) del municipio o tesela (`quadkey` / `s2_token`).
  - Luego se ejecuta la consulta espacial `{ "geometry": { "$geoIntersects": { "$geometry": mpio_polygon } } }` (o `$geoWithin` sobre el campo `centroid` para evitar duplicidad en edificaciones limítrofes), estampando el atributo `cod_dane_mpio` en cada huella perteneciente al territorio PDET.

+ *Interacción de Agregación Analítica (`N : 1` vía MongoDB Aggregation Pipeline):*
  Una vez vinculadas las edificaciones con su respectivo `cod_dane_mpio`, las colecciones `buildings_microsoft` y `buildings_google` alimentan la colección `solar_aggregations` mediante un pipeline de agregación que agrupa (`$group`) por `cod_dane_mpio`, calculando el conteo total de techos (`$sum: 1`), el área total acumulada (`$sum: "$rooftop_area_m2"`), el área promedio (`$avg: "$rooftop_area_m2"`) y la confianza media (`$avg: "$confidence"`).

+ *Interacción Referencial Directa (`1 : 1` vía `cod_dane_mpio`):*
  Existe una correspondencia biunívoca (`1 : 1`) entre cada documento de `municipalities_pdet` y su resumen analítico en `solar_aggregations` a través del índice único `cod_dane_mpio`. Esta relación permite unir en milisegundos (mediante `$lookup` o en la capa de visualización en Python/GeoPandas) las métricas de área de techos con la geometría municipal y la subregión PDET para renderizar los mapas coropléticos de potencial solar.

== Estrategia de Indexación en MongoDB

Para garantizar que tanto las inserciones masivas (_bulk loading_) como los cruces espaciales y las agregaciones por municipio y subregión PDET se ejecuten con baja latencia, se definen los siguientes índices sobre las colecciones:

```javascript
// 1. Índices en municipalities_pdet
db.municipalities_pdet.createIndex({ "cod_dane_mpio": 1 }, { unique: true, name: "idx_uk_cod_dane" });
db.municipalities_pdet.createIndex({ "geometry": "2dsphere" }, { name: "idx_geo_mpio_2dsphere" });
db.municipalities_pdet.createIndex({ "subregion_pdet.id": 1, "cod_dane_dpto": 1 }, { name: "idx_subregion_dpto" });

// 2. Índices en buildings_microsoft
db.buildings_microsoft.createIndex({ "geometry": "2dsphere" }, { name: "idx_geo_ms_footprint" });
db.buildings_microsoft.createIndex({ "centroid": "2dsphere" }, { name: "idx_geo_ms_centroid" });
db.buildings_microsoft.createIndex({ "cod_dane_mpio": 1, "rooftop_area_m2": -1 }, { name: "idx_ms_mpio_area" });

// 3. Índices en buildings_google
db.buildings_google.createIndex({ "full_plus_code": 1 }, { unique: true, name: "idx_uk_plus_code" });
db.buildings_google.createIndex({ "geometry": "2dsphere" }, { name: "idx_geo_gg_footprint" });
db.buildings_google.createIndex({ "centroid": "2dsphere" }, { name: "idx_geo_gg_centroid" });
db.buildings_google.createIndex({ "cod_dane_mpio": 1, "confidence": -1 }, { name: "idx_gg_mpio_conf" });

// 4. Índices en solar_aggregations
db.solar_aggregations.createIndex({ "cod_dane_mpio": 1 }, { unique: true, name: "idx_uk_agg_mpio" });
db.solar_aggregations.createIndex({ "solar_potential.priority_rank": 1, "subregion_pdet.id": 1 }, { name: "idx_solar_rank_subregion" });
```
