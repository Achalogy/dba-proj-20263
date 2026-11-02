= Plan de Implementación (Implementation Plan)

== Contexto y Objetivos del Proyecto

El presente proyecto se enmarca en la iniciativa estratégica de la Oficina de Investigaciones e Información de la *Unidad de Planeación Minero Energética (UPME)* de Colombia, orientada a evaluar la viabilidad de soluciones de energía renovable no convencional (particularmente granjas solares y techos solares para generación distribuida). La iniciativa prioriza los municipios clasificados como *territorios PDET* (Programas de Desarrollo con Enfoque Territorial), los cuales representan zonas históricamente afectadas por el conflicto armado y con brechas estructurales en infraestructura y acceso a servicios energéticos.

El objetivo central es diseñar e implementar un flujo de trabajo de análisis geoespacial reproducible y de alto rendimiento que permita:
+ Determinar el número exacto o estimado de edificaciones en cada municipio PDET.
+ Estimar el área total de cubiertas/techos (_rooftop area_) con potencial de captación solar en cada municipio.
+ Evaluar y comparar de manera rigurosa al menos dos fuentes de datos abiertas de detección de edificaciones por satélite (*Microsoft Building Footprints* y *Google Open Buildings*).
+ Implementar toda la persistencia, indexación y procesamiento geoespacial sobre una solución de base de datos *NoSQL* (MongoDB con soporte nativo de GeoJSON e índices 2dsphere).
+ Calidad de datos: Validación topológica exhaustiva, reparación de geometrías y control de integridad en cada etapa.
+ Estandarización: Adopción estricta de CRS EPSG:4326 para almacenamiento GeoJSON y EPSG:9377 para proyecciones métricas.
+ Eficiencia: Procesamiento en streaming/chunking y carga masiva desordenada con indexación espacial 2dsphere post-carga.
+ Reproducibilidad: Trazabilidad integral de código en GitHub, aislamiento de entornos y pipelines ejecutables de inicio a fin.
+ Producir un informe técnico exhaustivo con recomendaciones claras para pruebas de concepto de granjas solares y generación solar descentralizada.

== Metodología General del Proyecto

La metodología adoptada sigue un ciclo integral de ingeniería de datos geoespaciales y bases de datos NoSQL, estructurado en fases secuenciales e interconectadas:

#figure(
  table(
    columns: (1.2fr, 2fr, 2.5fr, 1.8fr),
    align: (left, left, left, left),
    stroke: 0.5pt + luma(150),
    fill: (_, row) => if row == 0 { rgb("f0f4f8") } else { none },
    [*Fase*], [*Nombre*], [*Objetivo Principal*], [*Resultado / Entregable*],
    [Fase 1 (Semana 1)],
    [Diseño de Esquema NoSQL y Plan de Implementación],
    [Establecer la metodología detallada, diseñar el modelo de documentos NoSQL y definir el diccionario de datos.],
    [Plan metodológico y diagrama E-R / esquema NoSQL (Semana 1).],

    [Fase 2 (Semana 2)],
    [Integración de Límites Municipales PDET (DANE / MGN)],
    [Descarga, filtrado, normalización y carga del Marco Geoestadístico Nacional (MGN-DANE) para los 170 municipios PDET con índices espaciales.],
    [Colección de municipios PDET indexada y verificada (Semana 2).],

    [Fase 3 (Semana 3)],
    [Carga e Integración de Huellas de Edificaciones],
    [Adquisición, particionamiento y carga por lotes de datasets masivos (Microsoft y Google) optimizando tiempos de inserción e indexación.],
    [Colecciones de huellas indexadas y EDA comparativo (Semana 3).],

    [Fase 4 (Semana 4)],
    [Flujo Geoespacial Reproducible y Estimación Solar],
    [Ejecución de consultas espaciales de intersección, conteo y agregación de área por municipio PDET; generación de mapas temáticos y rankings.],
    [Pipeline reproducible, tablas consolidadas y mapas coropléticos (Semana 4).],

    [Fase 5 (Semana 4)],
    [Informe Técnico Final y Recomendaciones],
    [Síntesis ejecutiva y técnica de resultados, análisis comparativo entre fuentes, identificación de municipios óptimos y sustentación oral.],
    [Reporte técnico final integral y presentación de defensa (Semana 4).]
  ),
  caption: [Matriz metodológica por fases del proyecto UPME - PDET.]
)

== Fases Detalladas de Ejecución

=== Fase 1: Arquitectura, Modelado NoSQL y Plan de Trabajo (Semana 1)
- *Definición Metodológica:* Documentación de la hoja de ruta técnica, requerimientos de hardware/software, supuestos del proyecto y dependencias de librerías.
- *Selección del Motor NoSQL:* Adopción de MongoDB como motor NoSQL documental por su madurez en almacenamiento BSON, consultas de agregación geoespacial (`$geoIntersects`, `$geoWithin`, `$nearSphere`) y soporte de índices geoespaciales `2dsphere` basados en el estándar WGS84 (EPSG:4326).
- *Modelado de Datos:* Diseño del esquema conceptual y lógico en colecciones (`municipalities_pdet`, `buildings_microsoft`, `buildings_google`, `solar_aggregations`). Definición de tipos de datos, sistemas de referencia de coordenadas (CRS), estructuras embebidas GeoJSON (`Polygon`, `MultiPolygon`, `Point`) y reglas de integridad.
- *Entregable:* Documento del Plan de Implementación y Esquema de Datos con Diccionario y Diagrama Entidad-Relación adaptado a NoSQL.

=== Fase 2: Integración de Límites Territoriales PDET (Semana 2)
- *Adquisición de Datos Oficiales:* Descarga de las capas vectoriales del *Marco Geoestadístico Nacional (MGN 2025)* suministrado por el DANE a nivel municipal.
- *Identificación de Municipios PDET:* Cruce del listado oficial de los 170 municipios priorizados por la Agencia de Renovación del Territorio (ART) mediante el código DANE oficial (`cod_mpio` o `cod_dane`).
- *Control de Calidad e Integridad:*
  - Validación topológica de geometrías (reparación de polígonos no válidos, auto-intersecciones o anillos desorientados usando `shapely.make_valid`).
  - Estandarización de nombres, codificación UTF-8 y transformación a EPSG:4326.
  - Simplificación controlada de geometrías complejas si se requiere optimizar las operaciones de contención espacial.
- *Ingesta en NoSQL e Indexación Espacial:* Transformación a registros GeoJSON, inserción en MongoDB y creación del índice `2dsphere` sobre el campo `geometry`.
- *Validación:* Comprobación de que exactamente los 170 municipios PDET se encuentran correctamente indexados y consultables.

=== Fase 3: Adquisición, Procesamiento y Carga Eficiente de Huellas de Edificaciones (Semana 3)
- *Selección de Datasets Abiertos:*
  1. *Microsoft Building Footprints:* Cobertura global basada en imágenes de satélite Bing Maps (Maxar/Airbus), formato GeoJSON/Parquet bajo licencia ODbL.
  2. *Google Open Buildings (V3):* Detección por IA en alta resolución sobre 58M de $text("km")^2$, suministrado en formato CSV/Parquet con polígonos WKT/GeoJSON, puntaje de confianza (_confidence score_) y área en $text("m")^2$.
- *Estrategia de Descarga y Recorte:*
  - Extracción de _bounding boxes_ (cajas envolventes) o filtrado espacial preliminar para la extensión geográfica de Colombia.
- *Técnicas de Carga Masiva y Eficiencia (Bulk Loading):*
  - Procesamiento por fragmentos (_chunking/streaming_) usando Python (`geopandas`, `pyarrow`, `pymongo`).
  - Operaciones de inserción en bloque (`bulk_write` / `insert_many` con `ordered=False`).
  - Creación de índices espaciales `2dsphere` post-carga o por particiones para no penalizar el rendimiento de inserción.
  - Monitoreo del consumo de memoria, ancho de banda de I/O y uso de disco.
- *Análisis Exploratorio de Datos (EDA):*
  - Distribución del número de huellas por departamento y región.
  - Métricas de confianza de detección y dispersión de áreas de cubiertas.
  - Detección de valores atípicos (_outliers_) y áreas inconsistentes.

=== Fase 4: Flujo de Análisis Geoespacial Reproducible (Semana 4)
- *Pipeline de Cruce Espacial:*
  - Cruce de cada polígono municipal PDET contra las colecciones de huellas mediante consultas `$geoIntersects` o `$geoWithin`.
  - Proyección de geometrías a sistema métrico proyectado (MAGNA-SIRGAS Origen Nacional EPSG:9377 o cálculo geodésico de área elipsoidal) para garantizar exactitud métrica en el cálculo de áreas en metros cuadrados ($text("m")^2$).
- *Métricas Clave Calculadas por Municipio:*
  + Cantidad total de edificaciones detectadas por dataset ($N_"MS"$, $N_"Google"$).
  + Área total acumulada de techos ($A_"total"$ en $text("m")^2$ y hectáreas).
  + Área promedio y mediana de techos por edificación.
  + Densidad de cubiertas (área de techos respecto al área urbana/total municipal).
  + Discrepancia relativa entre fuentes ($Delta% = (|A_"Google" - A_"MS"|) / A_"promedio"$).
- *Estructura de Salida y Visualización:*
  - Tablas resumen agregadas en formato tabular (CSV, Parquet, MongoDB Collection).
  - Mapas temáticos coropléticos que resalten los municipios PDET con mayor densidad y área neta de techos disponibles.

=== Fase 5: Reporte Técnico Final y Recomendaciones UPME (Semana 4)
- *Indicadores Clave de Comparación (KPIs):* Evaluación analítica de cantidad de edificios detectados, área total de huellas (m² y ha), y área promedio y mediana por edificación (m²).
- *Consolidación de Evidencias:* Integración metodológica de los códigos, gráficos, mapas y resultados cuantitativos.
- *Priorización de Sitios para Granjas / Techos Solares:* Identificación del Top 10 de municipios PDET con mayor potencial técnico para proyectos piloto de autogeneración y microrredes solares comunitarias.
- *Recomendaciones Estratégicas a la UPME:* Directrices sobre selección de datasets satelitales, limitaciones de resolución en zonas selváticas/rurales dispersas y arquitectura NoSQL recomendada para producción continua.
- *Preparación para Defensa Técnica:* Ensayos grupales para garantizar el dominio integral de la arquitectura y resultados por parte de todos los miembros del equipo.

== Cronograma de Hitos y Distribución de Responsabilidades

#figure(
  table(
    columns: (1fr, 1.3fr, 2.7fr, 1.5fr),
    align: (center, left, left, left),
    stroke: 0.5pt + luma(150),
    fill: (_, row) => if row == 0 { rgb("f0f4f8") } else { none },
    [*Semana*], [*Entregable*], [*Actividades Críticas*], [*Responsables*],
    [Semana 1],
    [Hito 1: Esquema NoSQL y Plan],
    [Formulación de la metodología, especificación de requerimientos, diseño del modelo de datos BSON y diccionario de entidades.],
    [Juliana Novoa\ Juan Saavedra\ Juan Garzón\ Miguel Vargas],

    [Semana 2],
    [Hito 2: Límites DANE PDET],
    [Extracción MGN 2025, filtrado de 170 municipios PDET, control de topología, ingesta NoSQL y creación de índices 2dsphere.],
    [Juliana Novoa\ Juan Saavedra\ Juan Garzón\ Miguel Vargas],

    [Semana 3],
    [Hito 3: Integración de Huellas y EDA],
    [Descarga de huellas (Microsoft & Google), pipeline de bulk loading, optimización de inserciones, cálculo de estadísticas exploratorias.],
    [Juliana Novoa\ Juan Saavedra\ Juan Garzón\ Miguel Vargas],

    [Semana 4],
    [Hito 4 & 5: Pipeline Final y Reporte],
    [Cálculo de métricas de área y conteo, generación de mapas coropléticos, redacción del reporte técnico UPME y defensa del proyecto.],
    [Juliana Novoa\ Juan Saavedra\ Juan Garzón\ Miguel Vargas]
  ),
  caption: [Cronograma de hitos semanales y asignación de responsabilidades de equipo.]
)

== Consideraciones Técnicas y Criterios de Calidad

+ *Reproducibilidad:* Todos los scripts de adquisición, ingesta y análisis se estructuran en Python con entornos controlados (`requirements.txt`), permitiendo su ejecución determinística de inicio a fin.
+ *Escalabilidad NoSQL:* Empleo de índices compuestos y geoespaciales para garantizar que las consultas sobre millones de polígonos se ejecuten en tiempos eficientes de agregación.
+ *Precisión Cartográfica:* Manejo riguroso de transformaciones de coordenadas elipsoidales y proyectadas para evitar distorsiones en el cálculo de áreas superficiales de techos.
+ *Colaboración Continua:* Control de versiones estricto en GitHub con commits y pull requests frecuentes y equilibrados entre todos los integrantes, garantizando trazabilidad y preparación homogénea para las evaluaciones orales individuales.

== Herramientas y Tecnologías Propuestas

El stack tecnológico seleccionado garantiza procesamiento geoespacial de alto rendimiento, escalabilidad NoSQL y reproducibilidad absoluta del pipeline[cite: 2.2]:

#figure(
  table(
    columns: (1.5fr, 1.5fr, 3fr),
    align: (left, left, left),
    stroke: 0.5pt + luma(150),
    fill: (_, row) => if row == 0 { rgb("f0f4f8") } else { none },
    [*Herramienta*], [*Categoría*], [*Rol en el Proyecto*],
    [Python 3.10+], [Lenguaje de Programación], [Lenguaje núcleo para la extracción, limpieza, transformación, orquestación de ingesta y modelado estadístico.][cite: 2.2],
    [MongoDB (Community/Atlas)], [Motor de Base de Datos NoSQL], [Repositorio central documental BSON con indexación geoespacial 2dsphere y soporte de consultas espaciales nativas.][cite: 2.2],
    [MongoDB Compass], [Cliente Gráfico NoSQL], [Inspección visual de esquemas documentales, validación de índices 2dsphere y depuración de pipelines de agregación.][cite: 2.2],
    [GeoPandas], [Librería de Análisis Geoespacial], [Manipulación de GeoDataFrames, particionamiento espacial, operaciones vectoriales y generación de mapas temáticos.][cite: 2.2],
    [Shapely], [Geometría Computacional], [Validación topológica, reparación de geometrías (`make_valid`), simplificación y cálculo de intersecciones poligonales.][cite: 2.2],
    [PyProj], [Transformación Cartográfica], [Reproyección rigurosa entre CRS geodésico (WGS84 EPSG:4326) y métrico proyectado (MAGNA-SIRGAS EPSG:9377).][cite: 2.2],
    [Pandas], [Procesamiento Tabular], [Consolidación de tablas resumen, agregaciones estadísticas, cálculo de discrepancias y métricas comparativas.][cite: 2.2],
    [PyMongo], [Driver de Base de Datos], [Conexión e inserciones masivas por lotes (`bulk_write` con `InsertOne`) optimizando tiempos de I/O en MongoDB.][cite: 2.2],
    [Git & GitHub], [Control de Versiones y CI], [Control de versiones del repositorio, gestión colaborativa por ramas, trazabilidad de commits y revisión por pull requests.][cite: 2.2],
    [QGIS], [SIG de Escritorio], [Inspección visual cartográfica externa, control de calidad visual y validación de geometrías exportadas.][cite: 2.2]
  ),
  caption: [Stack tecnológico del proyecto.]
)

== Reglas de Negocio Explícitas (RN-01 a RN-10)

- *RN-01 (Alcance Territorial):* El análisis se circunscribe estrictamente a los 170 municipios priorizados como territorios PDET por el Gobierno Nacional y la ART[cite: 2.2].
- *RN-02 (Estándar Geodésico de Almacenamiento):* Todas las geometrías almacenadas en MongoDB deben adoptar el estándar WGS84 (EPSG:4326) con formato GeoJSON válido[cite: 2.2].
- *RN-03 (Exactitud Métrica de Áreas):* El cálculo del área de cubiertas ($m^2$) debe realizarse mediante proyección cartográfica métrica oficial (EPSG:9377 Origen Nacional) o cálculo geodésico elipsoidal[cite: 2.2].
- *RN-04 (Umbral Mínimo de Confianza):* Para el conjunto Google Open Buildings, únicamente se consideran polígonos con un índice de confianza igual o superior a 0.65[cite: 2.2].
- *RN-05 (Filtro de Área Plausible para Techos):* Se descartan huellas con área inferior a $10 m^2$ (ruido de detección satelital) y huellas con área superior a $20,000 m^2$ no validadas estructuralmente[cite: 2.2].
- *RN-06 (Integridad Topológica Obligatoria):* Ninguna geometría con auto-intersecciones, anillos no cerrados o vértices inválidos puede insertarse en las colecciones limpias de la base de datos[cite: 2.2].
- *RN-07 (Separación de Capas Raw vs Cleaned):* Se mantiene estricta segregación física o lógica entre las capas crudas (_raw data_ de ingesta) y las colecciones limpias y normalizadas (_cleaned data_)[cite: 2.2].
- *RN-08 (Indexación Espacial 2dsphere):* Cada colección con datos vectoriales debe poseer un índice espacial 2dsphere activo sobre el campo `geometry` para habilitar consultas espaciales nativas[cite: 2.2].
- *RN-09 (Trazabilidad y Linaje de Fuente):* Cada documento de huella debe incorporar obligatoriamente los atributos de linaje: `building_id`, `source`, `municipality_code` y timestamp de ingesta[cite: 2.2].
- *RN-10 (Determinismo y Reproducibilidad):* La ejecución del pipeline automatizado sobre los mismos datasets de entrada debe producir idénticas métricas agregadas por municipio[cite: 2.2].

== Niveles de Limpieza de Datos y Esquema Unificado de Huellas

La arquitectura de datos implementa una estrategia de transformación por capas[cite: 2.2]:
- *Capa Cruda (Raw Level):* Ingesta directa de archivos fuente en su formato nativo (GeoJSON, GeoParquet, CSV con WKT). Se preservan metadatos originales sin filtrado para garantizar auditoría técnica[cite: 2.2].
- *Capa Limpia (Cleaned Level):* Aplicación de filtros de calidad (confianza $>= 0.65$, área entre $10 m^2$ y $20,000 m^2$), reparación topológica con Shapely y estructuración al esquema BSON unificado[cite: 2.2].

*Esquema BSON Unificado para la Colección Cleaned Buildings:*
```json
{
  "_id": "ObjectId(...)",
  "building_id": "String (identificador único original o hash sintético)",
  "source": "String ('microsoft' | 'google')",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[[ -75.1234, 4.5678 ], ... ]]
  },
  "municipality_code": "String (código DANE 5 dígitos, ej. '19001')",
  "area_m2": "Double (área calculada en proyección EPSG:9377)",
  "confidence": "Double (opcional para Google, null para Microsoft)",
  "processed_at": "ISODate(...)"
}

== Roles Específicos del Equipo de Trabajo
- *Analista de Requerimientos y Datos Territoriales (Juliana Novoa):* Formalización de especificaciones técnicas, adquisición del MGN 2025 DANE, filtrado oficial de los 170 municipios PDET y liderazgo del reporte técnico para la UPME.
- *Especialista en Adquisición y Calidad de Datos (Juan Saavedra):* Descarga y particionamiento de datasets masivos (Microsoft y Google), pipeline de limpieza topológica con Shapely y aplicación de reglas de negocio para capas raw y cleaned.
- *Administrador de Bases de Datos NoSQL (Juan Garzón):* Arquitectura de MongoDB, diseño del esquema BSON unificado, optimización de inserciones masivas desordenadas y gestión de índices espaciales 2dsphere.
- *Analista Geoespacial e Integración (Miguel Vargas):* Desarrollo de pipelines de análisis espacial con GeoPandas y PyMongo, agregación de métricas solares por municipio, síntesis cartográfica y orquestación reproducible en GitHub.

== Criterios de Finalización y Aceptación

- Cobertura Territorial Total: Verificación exitosa del 100% de los 170 municipios PDET indexados y cruzados en la base de datos sin omisiones[cite: 2.2].
- Cumplimiento de Reglas Topológicas: Tasa del 100% de geometrías válidas en las colecciones limpias tras el proceso de corrección geométrica[cite: 2.2].
- Eficiencia en Consultas Espaciales: Confirmación de uso efectivo del índice 2dsphere en todas las agregaciones espaciales documentado mediante cursor.explain()[cite: 2.2].
- Consistencia del Pipeline de Métricas: Generación determinística de tablas agregadas de área, recuento y análisis de discrepancia relativa entre fuentes[cite: 2.2].
- Trazabilidad y Repartición Colaborativa: Historial de Git con aportes balanceados y verificables entre los cuatro integrantes y documentación técnica completa[cite: 2.2].