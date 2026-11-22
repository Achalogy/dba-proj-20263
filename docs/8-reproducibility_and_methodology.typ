= Flujo de Análisis Geoespacial Reproducible y Metodología (Reproducibility & Methodology)
== Cómo se calcula el conteo y el área por municipio

La pregunta central del proyecto es cuántos techos hay en cada municipio PDET y cuánta área suman. Se responde en tres pasos, para cada fuente por separado:

+ *Cada edificio ya sabe en qué municipio está.* Al cargar los datos, a cada edificio se le guardó el código DANE de su municipio. Así no hace falta repetir el cruce espacial en el análisis.
+ *Se agrupa por municipio.* MongoDB agrupa los edificios por el código del municipio, cuenta cuántos hay y suma el área de sus techos (`rooftop_area_m2`).
+ *Se unen las dos fuentes.* Los resultados de Microsoft y de Google se ponen lado a lado en una sola tabla de 170 filas, una por municipio. De ahí salen las comparaciones, el consenso y el potencial solar.

Un detalle importante: el área de los techos no se midió igual en las dos fuentes. En Microsoft la calculamos nosotros a partir del polígono, en la proyección oficial de Colombia (EPSG:9377). En Google es el área que ya trae el dato original. Por eso las comparaciones entre fuentes deben leerse con ese matiz.
== Arquitectura Modular del Flujo de Análisis Geoespacial

El flujo analítico de la Fase 4 se implementó en el módulo `src/5-geospatial_workflow/` como una canalización (_pipeline_) completamente automatizada, idempotente, modular y extensible sobre *MongoDB 9.0*. A diferencia de los flujos exploratorios manuales en hojas de cálculo o cuadernos dispersos, toda la agregación de los *4.455.833 documentos de edificaciones* se ejecuta directamente dentro del motor NoSQL mediante el *Aggregation Framework*, garantizando bajo consumo de memoria en el cliente y tiempos de respuesta inferiores a 35 segundos sobre la base completa.

La arquitectura separa los puntos de entrada CLI de la lógica de negocio en un paquete Python cohesivo (`workflow/`):

+ *Puntos de entrada CLI (`compute_metrics.py`, `generate_charts.py`, `run_workflow.py`):* Interfaces ligeras de línea de comandos para ejecutar el cálculo de métricas, la generación de visualizaciones o ambos pasos encadenados en un solo comando.
+ *Núcleo analítico y de persistencia (`workflow/`):*
  - `config.py`: configuración tipada (`WorkflowConfig`), definición de estratos morfológicos, intervalos de confianza y utilidades matemáticas (`gini_coefficient`).
  - `mongo_pipelines.py`: conexión autenticada a MongoDB, pipelines nativos de agregación por municipio (`$percentile` de MongoDB 7+/9+, `RN-04`, `RN-05`) y materialización idempotente de `solar_aggregations` con índices secundarios.
  - `metrics.py`: normalización por fuente, consenso híbrido MS–Google, estimación del potencial solar fotovoltaico y agregación por subregiones y departamentos.
  - `summary.py`: estadísticos de concordancia inter-fuente (Pearson, Spearman, MAE, RMSE), estratos morfológicos, concentración Pareto/Gini, rankings precalculados y cálculo del hash determinístico `SHA-256`.
  - `spatial_audit.py`: ejecución automatizada de auditorías `explain(executionStats)` sobre índices `2dsphere` y compuestos.
  - `exporters.py`: exportación validada a formatos abiertos (`workflow_results.json`, tablas `CSV` y `pdet_solar_metrics.geojson`) y resumen ejecutivo en consola.
+ *Subpaquete extensible de visualización (`workflow/charts/`):* Consume exclusivamente los artefactos de salida (`reports/workflow/workflow_results.json` y `pdet_solar_metrics.geojson`) sin volver a consultar MongoDB. Agrupa el registro modular `@register_chart` y la paleta institucional (`registry.py`), el cargador de contexto (`loader.py`) y tres módulos temáticos: mapas coropléticos (`maps.py`, figuras 01–03), rankings territoriales (`rankings.py`, figuras 04–05) y análisis estadístico (`analytics.py`, figuras 06–09). Permite listar figuras (`--list`), regenerar subconjuntos selectivos (`--charts`) y exportar múltiples formatos (`--formats png,svg`).

== Metodología de Estimación de Conteo, Área y Potencial Solar

=== Consistencia Espacial y Proyección Métrica

Para evitar distorsiones geométricas en el cálculo de superficies, la arquitectura mantiene una separación estricta entre el sistema de almacenamiento e indexación y el sistema de medición métrica:

- *Almacenamiento e indexación (`EPSG:4326` — WGS84):* Todas las geometrías GeoJSON (`geometry` y `centroid`) se almacenan en coordenadas geográficas decimales compatibles con los índices `2dsphere` de MongoDB.
- *Medición de áreas reales (`EPSG:9377` — MAGNA-SIRGAS Origen Nacional):* En `load_microsoft.py`, cada huella de edificación se reproyecta al sistema oficial único de Colombia (`EPSG:9377`) para calcular `rooftop_area_m2` con precisión métrica; en `buildings_google`, se conserva la métrica geodésica `area_in_meters` suministrada en origen por Google Open Buildings V3.
- *Asignación municipal unívoca:* Cada edificación se vincula a su código DANE de 5 dígitos (`cod_dane_mpio`) mediante predicado espacial `within` contra los 170 polígonos validados de `municipalities_pdet`, eliminando duplicados en bordes municipales.

=== Estrategia de Consenso Híbrido Multi-Fuente (Microsoft + Google)

Las dos fuentes miden distinto. Google detecta más edificios, pero más pequeños (82,76 m² de promedio), y Microsoft menos, pero más grandes (125,57 m²). Una explicación posible es que cada modelo separa o une de forma diferente las construcciones vecinas, aunque esto no se comprobó. Además, Google no tiene ningún edificio en 5 municipios de la selva del Pacífico (Chocó y Urabá), tal vez por la nubosidad y la vegetación, pero tampoco se comprobó la causa. Para no perder esos municipios, se definió un estimador de *consenso híbrido* $A_("consenso", i)$ para cada municipio $i in {1, dots.c, 170}$:
$
  A_("consenso", i) = cases(
    frac(A_("MS", i) + A_("Google", i), 2) & "si el municipio" i "cuenta con cobertura en ambas fuentes (" n = 165 ")",
    A_("MS", i) & "respaldo Microsoft si Google no reporta inferencia (" n = 5 ")"
  )
$

Esta regla preserva la cobertura territorial del *100 % de los municipios PDET (170/170)*, evita sesgar a cero los territorios más vulnerables del Pacífico y atenúa el ruido sistemático individual de cada modelo de visión por computador. Adicionalmente, para cada municipio se calculan la discrepancia relativa simétrica (SMAPE) y la discrepancia relativa con signo respecto a Microsoft:

$
  Delta_("sim", i) = frac(|A_("Google", i) - A_("MS", i)|, (A_("Google", i) + A_("MS", i)) / 2) times 100%, quad
  Delta_("signo", i) = frac(A_("Google", i) - A_("MS", i), A_("MS", i)) times 100%
$

=== Reglas de Calidad y Análisis de Sensibilidad (`RN-04` y `RN-05`)

Con el fin de garantizar total transparencia analítica, los agregadores calculan simultáneamente las métricas *crudas* (inventario completo en MongoDB) y las métricas filtradas bajo dos reglas de negocio auditables:

- *Regla `RN-04` (Confianza satelital en Google):* El conjunto ingerido cumple en su totalidad `confidence >= 0,65`. Adicionalmente se cuantifica el subconjunto de *alta confianza (`confidence >= 0,75`)*, que concentra el *64,98 %* de las edificaciones y el *80,85 %* del área total de Google (`180,31 km²`).
- *Regla `RN-05` (Rango plausible de área de cubierta):* Evalúa edificaciones con $10 "m"^2 <= A <= 20.000 "m"^2$, descartando microestructuras menores a $10 "m"^2$ y polígonos atípicos gigantes. Bajo este filtro se retiene el *99,94 %* del área total en Microsoft (`221,00 km²`) y el *99,70 %* en Google (`222,33 km²`), confirmando que los valores extremos no distorsionan las estimaciones municipales.

=== Modelo Paramétrico de Potencial Solar Fotovoltaico

A partir del área de consenso $A_("consenso", i)$ (en $"m"^2$), el potencial técnico fotovoltaico de referencia para cada municipio $i$ se estima mediante un modelo lineal completamente parametrizable por línea de comandos en `compute_metrics.py`:

$
  A_("útil", i) = f_u dot A_("consenso", i), quad
  P_("kWp", i) = rho_("FV") dot A_("útil", i), quad
  E_("GWh/año", i) = frac(P_("kWp", i) dot Y_("esp"), 10^6)
$

#figure(
  text(size: 10pt)[
    #table(
      columns: (1.5fr, 1.1fr, 1.3fr, 2.5fr),
      align: (left, center, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Parámetro*], [*Valor Base*], [*Bandera CLI*], [*Justificación Técnica*],
      [Factor de utilización de techo ($f_u$)],
      [`0,40` (40 %)],
      [`--utilization-factor`],
      [Descuenta sombras, orientación desfavorable, chimeneas, tanques, patios internos y capacidad estructural limitada.],

      [Densidad de potencia FV ($rho_("FV")$)],
      [`0,20 kWp/m²`],
      [`--power-density`],
      [Equivalente a módulos monocristalinos comerciales de 20 % de eficiencia nominal ($approx 200 "Wp/m"^2$).],

      [Rendimiento específico ($Y_("esp")$)],
      [`1.450 kWh/kWp·año`],
      [`--specific-yield`],
      [Referencia conservadora para Colombia (irradiación media 4,5–5,2 $"kWh/m"^2 dot "día"$ y _Performance Ratio_ $approx 0,78$).],
    )
  ],
  caption: [Parámetros configurables del modelo de estimación de potencial solar fotovoltaico en `compute_metrics.py`.],
)

== Auditoría Espacial y Determinismo Verificable

Cada ejecución de `compute_metrics.py` realiza dos verificaciones automáticas obligatorias:

+ *Auditoría de planes de ejecución (`explain` con `executionStats`):* Verifica que las consultas espaciales y analíticas sobre las cuatro colecciones activas operen con `IXSCAN` y sin escaneos lineales (`COLLSCAN`). En la ejecución de referencia sobre MongoDB 9.0 se obtuvieron cinco aprobaciones (5/5 `OK`) con latencias entre *1 ms y 53 ms*.
+ *Huella criptográfica determinística (`SHA-256`):* El script serializa en orden canónico las claves numéricas de las 170 filas municipales (excluyendo marcas de tiempo) y calcula su resumen criptográfico. Ejecuciones independientes sobre la base de datos restaurada producen exactamente el mismo hash:
  `312d57042a23729103d0a16c8950947730795b4c206335630e883e89441e84a6`, demostrando reproducibilidad determinística bit a bit.

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (1.7fr, 1.3fr, 0.9fr, 0.8fr, 1.0fr, 0.9fr),
      align: (left, left, center, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Consulta Auditada*], [*Índice Utilizado*], [*Plan*], [*Tiempo*], [*Docs Exam.*], [*Retornados*],
      [`municipalities_pdet` (`$geoIntersects`)], [`geometry_2dsphere`], [`IXSCAN`], [10 ms], [1], [1],
      [`buildings_microsoft` (`$geoIntersects`)], [`geometry_2dsphere`], [`IXSCAN`], [1 ms], [62], [1],
      [`buildings_google` (`$geoWithin` 1 km)], [`centroid_2dsphere`], [`IXSCAN`], [53 ms], [17.413], [11.604],
      [`buildings_microsoft` (`mpio + area`)], [`mpio_area`], [`IXSCAN`], [39 ms], [23.211], [23.211],
      [`solar_aggregations` (Top 10 rank)], [`idx_solar_rank_subregion`], [`IXSCAN`], [1 ms], [10], [10],
    )
  ],
  caption: [Resultados de la auditoría automática `explain(executionStats)` ejecutada por `compute_metrics.py` sobre MongoDB 9.0 .],
)

== Verificación en un segundo equipo

El flujo se ejecutó de nuevo en otro computador (Windows, Python 3.14, `uv` y MongoDB 9.0.8), sobre una base de datos cargada otra vez con los scripts del proyecto. El resultado fue el mismo: 170 municipios, 1.761.047 techos de Microsoft, 2.694.786 de Google y el mismo código `SHA-256` (`312d5704...`). El cálculo completo tardó unos 31 segundos (6 segundos con Microsoft y 24 con Google), y las 5 consultas de verificación usaron índice.
Además, los archivos que genera el flujo (el JSON de resultados, las tablas CSV, el GeoJSON y las 9 figuras) quedaron idénticos a los que ya estaban guardados en el repositorio.

== Ejecución Reproducible del Flujo Analítico (Fase 4)

Con la base de datos `upme_pdet` operativa en MongoDB, el flujo de la Fase 4 se reproduce con un único comando mediante `uv`, o de forma independiente entre cálculo de métricas y visualización:

```bash
# Flujo completo de la Fase 4 (agregación + solar_aggregations + JSON/CSV/GeoJSON + 9 figuras)
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/run_workflow.py \
  --uri "mongodb://acha:acha@localhost:27017/?authSource=admin"

# Listar gráficas registradas en workflow/charts/ sin consultar MongoDB
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/generate_charts.py --list

# Regenerar gráficas específicas en PNG y SVG desde reports/workflow/workflow_results.json
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/generate_charts.py \
  --charts 02_map_pdet_solar_potential,09_pareto_concentration --formats png,svg
```

Para reproducir el proyecto completo de extremo a extremo desde `src/1-pdet_mgn/` (incluyendo despliegue de Docker, carga de límites PDET, ingesta de Microsoft y Google, EDA y compilación de informes), el repositorio provee el orquestador raíz `./reproduce.sh` (`--mode full`, `--mode archive` y `--mode analysis`), documentado en detalle en la guía paso a paso del Informe Técnico Final y en el `README.md`.

== Supuestos y límites

- *Los parámetros del modelo solar son supuestos del grupo.* El 40 % de uso del techo, los 0,20 kWp/m² y los 1.450 kWh/kWp al año no vienen de la UPME. Se pueden cambiar con las opciones del programa, y el resultado cambia en la misma proporción.
- *No hay un valor "verdadero" con el cual comparar.* El consenso promedia dos estimaciones de satélite; es una aproximación, no una medición en terreno.
- *Google solo guarda el punto central del edificio*, no su forma, por lo que no se pueden comparar formas entre las dos fuentes.