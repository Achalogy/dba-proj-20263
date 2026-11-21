#set page(paper: "a4", margin: 2.5cm)
#set text(font: "Times New Roman", size: 12pt, lang: "es")
#set par(justify: true)

#align(center)[
  #v(2cm)
  #image("../assets/logo.png", width: 25%)
  #v(1cm)

  #text(size: 18pt, weight: "bold")[
    FINAL PROJECT: \
    Final Technical Report \
    #v(0.3cm)
    #text(size: 13pt, weight: "regular")[
      Evaluación NoSQL Geoespacial del Potencial Solar en Cubiertas \
      de los 170 Municipios PDET de Colombia (UPME)
    ]
  ]
  #v(0.25cm)
  #text(size: 10pt)[
    #link("https://github.com/Achalogy/dba-proj-20263")[https://github.com/Achalogy/dba-proj-20263]
  ]

  #v(1.5cm)

  Juliana Sofía Novoa Solano \
  Juan Santiago Saavedra Holguin \
  Juan Esteban Garzón Tinjaca \
  Miguel Francisco Vargas Contreras

  #v(1cm)

  Administración de Bases de Datos

  #v(1cm)

  Profesor: ANDRÉS OSWALDO CALDERÓN ROMERO, Ph.D.

  #v(2.5cm)

  Pontificia Universidad Javeriana \
  Bogotá D.C. \
  2026
]

#pagebreak()
#set page(numbering: "1")
#set heading(numbering: "1.1")

#outline(depth: 3)

#pagebreak()

= Resumen Ejecutivo

El presente Informe Técnico Final consolida el diseño, la implementación, la validación operativa y los resultados analíticos de una *plataforma geoespacial reproducible basada en bases de datos NoSQL (MongoDB 9.0)*, desarrollada para apoyar a la *Oficina de Investigaciones e Información de la Unidad de Planeación Minero Energética (UPME)* en la evaluación del potencial solar fotovoltaico en cubiertas de los *170 municipios PDET* de Colombia (distribuidos en 16 subregiones y 19 departamentos, con una superficie oficial de `389.182,04 km²`).

A lo largo de cuatro fases progresivas se diseñó un modelo documental orientado a GeoJSON (`EPSG:4326`) con medición métrica en `EPSG:9377` (MAGNA-SIRGAS Origen Nacional), se integraron los límites oficiales del *Marco Geoestadístico Nacional (MGN 2025 del DANE)* con el catálogo PDET (`MunicipiosPDET.xlsx`) y se ingirieron, validaron e indexaron espacialmente dos fuentes satelitales abiertas independientes: *Microsoft Global ML Building Footprints* (*1.761.047 edificaciones*) y *Google Open Buildings V3* (*2.694.786 edificaciones*), totalizando *4.455.833 huellas de cubiertas* en la base de datos `upme_pdet`.

=== Principales Hallazgos Técnicos y Analíticos

- *Desempeño e integridad NoSQL:* La estrategia de inserción masiva desordenada (`ordered=False`) con creación de índices `2dsphere` y compuestos (`mpio_area`) al finalizar la ingesta redujo drásticamente el tiempo de carga y mantuvo la base completa en menos de *620 MiB comprimidos* con WiredTiger. Las auditorías `explain(executionStats)` confirman planes `IXSCAN` al 100 % con tiempos entre *1 ms y 53 ms* sobre millones de documentos.
- *Convergencia multi-fuente sobresaliente:* Aunque Google detecta un 53,0 % más de estructuras individuales que Microsoft por efecto de segmentación satelital (`82,76 m²` vs. `125,57 m²` de área media), el área total de cubiertas converge con una diferencia global de apenas *0,85 %* (`223,01 km²` vs. `221,13 km²`) y una correlación municipal de *Pearson $r = 0,9853$* ($R^2 = 0,9708$) y *Spearman $rho = 0,9376$* sobre los 165 municipios con cobertura compartida.
- *Necesidad de enfoque híbrido para equidad territorial:* Google Open Buildings V3 presenta ausencia total de inferencias en *5 municipios de la subregión Chocó* (Bojayá, Vigía del Fuerte, Medio San Juan, Nóvita y Murindó) debido a la nubosidad persistente del Pacífico. El estimador de *consenso híbrido* rescata `8.079 edificaciones` (`73,92 ha`, `59,13 MWp`) mediante respaldo de Microsoft, garantizando cobertura efectiva del *100 % de los territorios PDET (170/170)*.
- *Potencial solar fotovoltaico estimado:* Sobre un área consolidada de *222,44 km²* (`22.243,73 ha`), aplicando un factor de utilización del `40 %` (`88,97 km²` de techo útil), una densidad de potencia de `0,20 kWp/m²` y un rendimiento específico de referencia de `1.450 kWh/kWp·año`, se estima un potencial técnico total de *17,79 GWp* (*17.795,0 MWp*) y *25,80 TWh/año*.
- *Concentración espacial aprovechable:* El potencial exhibe un índice de *Gini de 0,5174*: el *Top 5* municipal (Santa Marta, Valledupar, Buenaventura, Florencia y Turbo) concentra el *22,2 %*, el *Top 10* alcanza el *30,5 %* y solo *27 municipios* reúnen el *50 %* del área de cubiertas PDET.
- *Reproducibilidad integral desde cero:* Todo el flujo —desde `src/1-pdet_mgn/` hasta la compilación de los informes PDF— es reproducible de extremo a extremo mediante el orquestador `./reproduce.sh` (o paso a paso según la guía detallada en la @sec-guia-reproduccion), verificado con huella criptográfica determinística `SHA-256`.

#pagebreak()
#include "../docs/1-implementation_plan.typ"
#pagebreak()
#include "../docs/2-schema_and_data_modeling.typ"
#pagebreak()
#include "../docs/3-data_acq_and_verification.typ"
#pagebreak()
#include "../docs/4-data_integrity_and_format.typ"
#pagebreak()
#include "../docs/5-nosql_spatial_integration.typ"
#pagebreak()
#include "../docs/6-data_loading_efficiency.typ"
#pagebreak()
#include "../docs/7-eda.typ"
#pagebreak()
#include "../docs/8-reproducibility_and_methodology.typ"
#pagebreak()
#include "../docs/9-output_data_structure.typ"
#pagebreak()

= Guía Paso a Paso para Reproducir el Proyecto desde Cero <sec-guia-reproduccion>

Esta guía describe de forma autosuficiente cómo replicar el proyecto íntegro desde la clonación del repositorio hasta la obtención de la base de datos poblada (`upme_pdet`), los resultados geoespaciales abiertos, las 9 visualizaciones y los informes técnicos en PDF.

== Prerrequisitos de Software y Hardware

- *Sistema operativo:* Linux, macOS o Windows (WSL2 / PowerShell).
- *Herramientas obligatorias:* *Docker* + *Docker Compose* (para desplegar MongoDB 9.0) y *`uv`* (gestor de entornos Python que resuelve automáticamente todas las dependencias declaradas en cada `pyproject.toml` y `uv.lock`).
- *Herramientas opcionales:* `mongorestore` (únicamente si se emplea la ruta rápida de restauración desde respaldo `.archive`) y `typst` (v0.14+, para recompilar los reportes en PDF).
- *Capacidad recomendada:* Al menos 8 GB de RAM y 15 GB de espacio libre en disco si se descargan los datasets satelitales crudos de Microsoft y Google desde cero (o ≈ 2 GB libres si se restaura el respaldo comprimido).

== Ejecución Automatizada en un Solo Comando (`reproduce.sh`)

El repositorio incorpora el orquestador raíz `reproduce.sh`, el cual soporta tres modos de reproducción según la disponibilidad de tiempo y datos:

```bash
# 1. Clonar el repositorio y ubicarse en la raíz
git clone https://github.com/Achalogy/dba-proj-20263.git
cd dba-proj-20263

# Opción A (Desde 0 completo: Etapa 1 -> Microsoft -> Google -> EDA -> Workflow -> PDFs)
./reproduce.sh --mode full --start-mongo

# Opción A2 (Desde 0 partiendo del shapefile oficial MGN 2025 del DANE)
./reproduce.sh --mode full --start-mongo --mgn data/MGN_ADM_MPIO_GRAFICO.shp

# Opción B (Restauración rápida desde respaldo mongodump ~282 MB + análisis + PDFs)
./reproduce.sh --mode archive --start-mongo

# Opción C (Solo recalcular EDA, métricas, 9 figuras y PDFs sobre una BD ya poblada)
./reproduce.sh --mode analysis \
  --uri "mongodb://acha:acha@localhost:27017/?authSource=admin"
```

== Paso a Paso Detallado por Etapa (Ejecución Manual)

Para auditar o ejecutar cada módulo de manera individual desde la raíz del repositorio, defina primero las variables de entorno comunes:

```bash
export MONGO_URI="mongodb://acha:acha@localhost:27017/?authSource=admin"
export MONGO_DATABASE="upme_pdet"
```

*Paso 1 — Infraestructura NoSQL (`src/2-mongo_container_test/`):*
Despliegue el contenedor oficial de MongoDB 9.0 con límite de caché WiredTiger y chequeo de salud (`healthcheck`). El archivo `compose.yml` cuenta con valores por defecto seguros (`acha`/`acha`), personalizables copiando `.env.example` a `.env`:

```bash
docker compose -f src/2-mongo_container_test/compose.yml up -d mongodb
docker ps --filter "name=mongodb"
```

*Paso 2 — Límites Municipales PDET (`src/1-pdet_mgn/`):*
Carga y valida los 170 municipios PDET (16 subregiones), crea el índice `geometry_2dsphere` y verifica 170/170 intersecciones con `point_on_surface`. Existen dos entradas equivalentes:

- *Desde el NDJSON validado incluido en el repositorio* (64 MB, sin necesidad de descargar el ZIP de 3,2 GB del DANE):
```bash
uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --from-ndjson data/processed/municipalities_pdet.ndjson
```
- *Desde el shapefile oficial del DANE (MGN 2025):*
```bash
uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp
uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp \
  --export data/processed/municipalities_pdet.ndjson
```

*Paso 3 — Ingesta de Microsoft Global ML Building Footprints (`src/3-buildings-microsoft/`):*
Descarga automáticamente el índice oficial `dataset-links.csv` si no existe localmente, procesa las cuadrículas de Colombia, filtra los centroides dentro de los 170 municipios PDET, calcula `rooftop_area_m2` en `EPSG:9377`, inserta los *1.761.047 documentos* en lotes de 5.000 y construye los índices `2dsphere` y `mpio_area` al finalizar:

```bash
uv run --project src/3-buildings-microsoft \
  python src/3-buildings-microsoft/load_microsoft.py \
  --batch-size 5000 --tag full
```

*Paso 4 — Ingesta de Google Open Buildings V3 (`src/3-google_open_buildings/`):*
Disuelve el polígono unificado PDET (`pdet_union.geojson`), identifica y descarga con escritura atómica las 8 teselas S2 nivel 4 que intersecan el territorio PDET y ejecuta el importador multiproceso con idempotencia por archivo (`etl_processed_files`), cargando *2.694.786 documentos*:

```bash
uv run --project src/3-google_open_buildings \
  python src/3-google_open_buildings/generate_pdet_union.py
uv run --project src/3-google_open_buildings \
  python src/3-google_open_buildings/download_pdet_buildings.py
uv run --project src/3-google_open_buildings \
  python src/3-google_open_buildings/importer.py
```

*Paso 5 — Análisis Exploratorio y Auditoría Espacial (`src/4-eda/`):*
Valida el conteo de colecciones, estadísticas de almacenamiento (`collStats`) y planes `explain` (`IXSCAN`) generando `reports/eda_results.json`:

```bash
uv run --project src/4-eda python src/4-eda/eda.py --output reports/eda_results.json
```

*Paso 6 — Workflow Geoespacial Reproducible y Gráficas (`src/5-geospatial_workflow/`):*
Ejecuta los módulos de `workflow/` para materializar `solar_aggregations` en MongoDB, exportar `JSON`, `CSV` y `GeoJSON` en `reports/workflow/`, auditar los 5 índices con `explain`, verificar el hash determinístico `SHA-256` y generar las 9 visualizaciones de `workflow/charts/` en `reports/figures/`:

```bash
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/run_workflow.py
```

*Paso 7 — Compilación de Informes Técnicos (`outcomes/`):*
Genera los documentos PDF finales directamente a partir de las fuentes Typst y las figuras recién producidas:

```bash
typst compile --root . outcomes/4-semana_4.typ outcomes/4-semana_4.pdf
typst compile --root . outcomes/5-final-technical-report.typ outcomes/5-final-technical-report.pdf
```

#figure(
  text(size: 9pt)[
    #table(
      columns: (0.7fr, 1.6fr, 1.3fr, 1.0fr, 2.0fr),
      align: (center, left, left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Paso*], [*Módulo / Script*], [*Salida Principal*], [*Tiempo Est.*], [*Criterio de Verificación*],
      [1], [`src/2-mongo_container_test/`], [Contenedor `mongodb:9.0`], [< 30 s], [Estado `healthy` y `ping == 1`.],
      [2],
      [`src/1-pdet_mgn/prepare-pdet.py`],
      [`municipalities_pdet`],
      [≈ 20 s],
      [170 docs y 170/170 `$geoIntersects`.],

      [3],
      [`src/3-buildings-microsoft/`],
      [`buildings_microsoft`],
      [≈ 25–40 min],
      [1.761.047 docs e índices `2dsphere`.],

      [4],
      [`src/3-google_open_buildings/`],
      [`buildings_google`],
      [≈ 10–25 min],
      [2.694.786 docs y 8 teselas en control.],

      [5], [`src/4-eda/eda.py`], [`reports/eda_results.json`], [≈ 12 s], [4/4 auditorías `IXSCAN` en `OK`.],
      [6],
      [`src/5-geospatial_workflow/`],
      [`solar_aggregations` + 9 PNG],
      [≈ 35 s],
      [SHA-256 determinístico + 5/5 `IXSCAN` + 9 PNG.],

      [7], [`typst compile`], [Informes PDF (`outcomes/`)], [< 5 s], [Compilación limpia sin errores.],
    )
  ],
  caption: [Resumen operativo de las siete etapas para reproducir el proyecto completo desde cero (la ruta alternativa `--mode archive` reemplaza los pasos 2–4 en ≈ 1 minuto).],
)

#pagebreak()

= Discusión Estratégica y Recomendaciones para la UPME

Los resultados obtenidos a partir del inventario multi-fuente en MongoDB permiten traducir el análisis geoespacial en lineamientos accionables para el diseño de pruebas de concepto (PoC), programas de generación distribuida y políticas de transición energética justa en los territorios PDET.

== Estrategia de Priorización Territorial para Pruebas de Concepto (PoC)

Dada la distribución concentrada del recurso (índice de Gini `0,5174`), se recomienda estructurar un portafolio escalonado en tres horizontes complementarios:

+ *Fase Piloto de Alto Impacto y Rápida Escala (Top 10 Municipios — 30,5 % del potencial):* Concentrar las primeras pruebas de concepto de techos solares comunitarios, edificios públicos y agroindustria en *Santa Marta* (`1.210,4 MWp`), *Valledupar* (`1.156,1 MWp`), *Buenaventura* (`592,6 MWp`), *Florencia* (`562,0 MWp`) y *Turbo* (`428,4 MWp`), complementados por *Tumaco*, *Santander de Quilichao*, *Ciénaga*, *Apartadó* y *San Vicente del Caguán*. Estas cabeceras presentan alta densidad de cubiertas medianas y grandes (`> 150 m²`), acceso logístico consolidado y una excelente convergencia entre Microsoft y Google. En particular, *Sierra Nevada - Perijá* destaca por combinar el mayor volumen de techo PDET (`50,01 km²`) con los niveles de irradiación solar más elevados del país (Caribe colombiano).
+ *Expansión Regional Estructurada (Top 27 Municipios — 50 % del potencial):* Incorporar los polos intermedios de *Alto Patía y Norte del Cauca* (como Piendamó - Tunía, con la mayor densidad construida de todo el universo PDET: `1,34 %`), *Montes de María* (El Carmen de Bolívar), *Macarena - Guaviare* (San José del Guaviare), *Arauca* (Arauquita y Tame), *Catatumbo* (Tibú) y *Putumayo* (Puerto Asís). Esta cohorte ofrece sinergias directas con cadenas productivas agropecuarias que demandan refrigeración, bombeo y procesamiento local.
+ *Portafolio de Equidad Energética en Zonas No Interconectadas (ZNI):* Evitar asignar recursos únicamente por volumen absoluto de techo. Las subregiones *Chocó* (`235,8 MWp`), *Pacífico y Frontera Nariñense* (`538,3 MWp`) y *Sur del Tolima* (`303,0 MWp`) tienen menor área construida total, pero presentan brechas críticas de cobertura eléctrica y alto costo de generación diésel. En estos territorios, proyectos solares de pequeña escala (`50–500 kWp`) sobre escuelas, puestos de salud y centros comunitarios generan el mayor retorno social por kilovatio instalado.

== Recomendaciones sobre Gobernanza de Datos y Arquitectura NoSQL

- *Mantener la política obligatoria de doble fuente (Microsoft + Google):* El estudio demuestra empíricamente que depender de una sola fuente satelital introduce riesgos severos. Utilizar exclusivamente Google habría invisibilizado por completo a Bojayá, Vigía del Fuerte, Medio San Juan, Nóvita y Murindó, además de subestimar en 35 %–49 % el Pacífico y el Sur del Tolima. Utilizar exclusivamente Microsoft habría sobrestimado el peso de grandes cubiertas fusionadas (`> 500 m²`). El esquema de consenso híbrido con métricas separadas en `solar_aggregations` permite auditar ambos límites en todo momento.
- *Aprovechar la arquitectura extensible en producción:* La colección materializada `solar_aggregations` y los archivos abiertos (`pdet_solar_metrics.geojson`, `municipalities_metrics.csv`, `workflow_results.json`) pueden integrarse directamente en visores institucionales de la UPME (SIEL, ArcGIS Enterprise, QGIS o tableros BI) con latencias de consulta inferiores a `2 ms`.
- *Establecer ciclos anuales de actualización idempotente:* Gracias al diseño idempotente de `prepare-pdet.py`, `load_microsoft.py`, `importer.py` y `compute_metrics.py` (orquestados por `reproduce.sh`), la UPME puede reejecutar el flujo completo ante nuevas vigencias del MGN-DANE o futuras versiones de Microsoft/Google, registrando cambios históricos mediante versiones fechadas de `solar_aggregations`.

== Limitaciones Técnicas y Hoja de Ruta de Trabajo Futuro

Para transitar desde esta evaluación macro-territorial de prefactibilidad hacia ingeniería de detalle de proyectos solares, se identifican cuatro mejoras prioritarias para fases posteriores:

+ *Irradiancia solar espacialmente explícita:* Sustituir el rendimiento específico nacional constante (`1.450 kWh/kWp·año`) por capas ráster locales de irradiación global horizontal (GHI) y temperatura ambiente (IDEAM / Global Solar Atlas / Solargis) cruzadas por municipio o por centroide. Esto diferenciará cuantitativamente el mayor rendimiento del Caribe (`~1.650–1.800 kWh/kWp·año` en Sierra Nevada - Perijá) frente al Pacífico húmedo (`~1.150–1.300 kWh/kWp·año` en Chocó).
+ *Modelado de sombras, orientación y capacidad estructural:* Integrar modelos digitales de superficie (DSM / LiDAR) o levantamientos con drones en los municipios piloto del Top 10 para refinar el factor de utilización ($f_u = 40%$) según inclinación de techos, vegetación circundante y materialidad estructural (cubiertas en zinc ligero vs. losas de concreto o naves industriales).
+ *Cruce con infraestructura eléctrica (SIN y ZNI):* Superponer la capa `pdet_solar_metrics.geojson` con la red de subestaciones, circuitos de distribución del SIN y localidades ZNI del IPSE para priorizar techos con capacidad de inyección inmediata o sustitución directa de plantas diésel.
+ *Validación catastral y de uso del suelo:* Cruzar el segmento de cubiertas mayores a `150 m²` con la información catastral multipropósito del IGAC para identificar primero techos públicos (colegios, hospitales, alcaldías) y agroindustriales con menor barrera jurídica y financiera para su implementación.

= Conclusiones Generales

+ *Cumplimiento integral de los objetivos de ingeniería NoSQL:* Se diseñó, desplegó y validó una solución geoespacial robusta sobre *MongoDB 9.0* que integra 170 municipios PDET (`MGN 2025`), *1.761.047 edificaciones de Microsoft* y *2.694.786 edificaciones de Google* (*4.455.833 huellas en total*), demostrando eficiencia de carga, compresión efectiva bajo WiredTiger y tiempos de consulta geoespacial en el rango de *1 a 53 ms* respaldados por índices `2dsphere` y compuestos (`IXSCAN` al 100 %).
+ *Evidencia cuantitativa sólida para la planeación energética:* La convergencia global entre fuentes (`0,85 %` de diferencia total; $r = 0,9853$) y la estabilidad frente a los filtros de calidad `RN-04` y `RN-05` (`> 99,7 %` de área retenida) confirman la confiabilidad del inventario consolidado de *222,44 km² de cubiertas* y su potencial técnico estimado de *17,79 GWp* y *25,80 TWh/año* en los territorios PDET.
+ *Valor diferencial del enfoque multi-fuente:* La combinación de Microsoft y Google no solo valida estadísticamente las estimaciones municipales, sino que corrige vacíos críticos de cobertura satelital en el Chocó (5 municipios completamente omitidos por Google), evitando sesgos de exclusión territorial en políticas públicas de energía limpia.
+ *Reproducibilidad total de extremo a extremo:* Con la automatización completa desde `src/1-pdet_mgn/` hasta la generación de métricas, 9 figuras de publicación y reportes en PDF mediante `reproduce.sh` —y con huella determinística `SHA-256` verificada—, el proyecto entrega a la UPME una herramienta auditable, abierta y extensible para la toma de decisiones en transición energética justa.
