= Estructura de Datos de Salida y Resultados Analíticos (Output Data Structure & Results)

== Esquema de Salida en MongoDB (`solar_aggregations`) y Exportaciones Abiertas

La ejecución de `src/5-geospatial_workflow/compute_metrics.py` persiste los resultados consolidados en dos planos complementarios: la colección materializada `solar_aggregations` dentro de MongoDB (`upme_pdet`) para consultas operativas en tiempo constante, y un conjunto de archivos abiertos en `reports/workflow/` y `reports/figures/` para interoperabilidad con plataformas SIG (QGIS, ArcGIS), herramientas de inteligencia de negocios y publicación científica.

=== Estructura Documental de `solar_aggregations`

La colección almacena exactamente *170 documentos* (uno por municipio PDET), indexados mediante la llave única `idx_uk_agg_mpio` (`{cod_dane_mpio: 1}`) y el índice compuesto de priorización `idx_solar_rank_subregion` (`{solar_potential.priority_rank: 1, subregion_pdet.id: 1}`). Cada documento encapsula las métricas independientes de Microsoft y Google, sus indicadores comparativos y la estimación de potencial solar:

```json
{
  "cod_dane_mpio": "47001",
  "cod_dane_dpto": "47",
  "municipio": "SANTA MARTA",
  "departamento": "MAGDALENA",
  "subregion_pdet": { "id": 12, "nombre": "SIERRA NEVADA - PERIJÁ" },
  "area_oficial_km2": 2343.9033,
  "bbox": [-74.246, 10.781, -73.606, 11.351],
  "metrics_microsoft": {
    "has_coverage": true, "building_count": 67664,
    "total_area_km2": 14.2102, "avg_area_m2": 210.01, "median_area_m2": 100.48,
    "plausible_count": 67662, "plausible_area_m2": 14165475.80
  },
  "metrics_google": {
    "has_coverage": true, "building_count": 183652,
    "total_area_km2": 16.0496, "avg_area_m2": 87.39, "median_area_m2": 58.43,
    "avg_confidence": 0.7748, "high_conf_count": 117760, "high_conf_area_m2": 13062764.01
  },
  "comparison_metrics": {
    "delta_count": 115988, "count_ratio_g_to_ms": 2.7142,
    "delta_area_pct": 12.16, "signed_delta_area_pct": 12.94,
    "consensus_strategy": "mean_ms_google", "consensus_area_km2": 15.1299,
    "rooftop_density_pct": 0.6455
  },
  "solar_potential": {
    "usable_roof_m2": 6051954.15, "est_capacity_mwp": 1210.39,
    "est_annual_generation_gwh": 1755.07, "priority_rank": 1
  }
}
```

=== Catálogo de Artefactos Exportados

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (2.1fr, 0.9fr, 0.8fr, 2.5fr),
      align: (left, center, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Archivo / Colección*], [*Formato*], [*Tamaño*], [*Contenido y Uso Recomendado*],
      [`upme_pdet.solar_aggregations`], [MongoDB], [170 docs], [Vista materializada indexada para consultas de priorización en `< 2 ms`.],
      [`reports/workflow/workflow_results.json`], [JSON], [875 KB], [Paquete maestro con metadatos, hash `SHA-256`, KPIs globales, estratos, auditoría `explain`, subregiones, departamentos y los 170 municipios.],
      [`reports/workflow/municipalities_metrics.csv`], [CSV], [60 KB], [Tabla plana de 170 filas y 46 variables lista para Excel, R, Python o Power BI.],
      [`reports/workflow/subregions_metrics.csv`], [CSV], [5,2 KB], [Consolidado de las 16 subregiones PDET con ranking de prioridad y discrepancia.],
      [`reports/workflow/departments_metrics.csv`], [CSV], [5,7 KB], [Consolidado de los 19 departamentos con jurisdicción sobre municipios PDET.],
      [`reports/workflow/pdet_solar_metrics.geojson`], [GeoJSON], [1,77 MB], [Capa vectorial de 170 polígonos simplificados (`0,002°`) con métricas embebidas para QGIS/Leaflet.],
      [`reports/figures/01_*.png` .. `09_*.png`], [PNG 300 DPI], [9 figuras], [Visualizaciones cartográficas y estadísticas acompañadas de `manifest.json`.],
    )
  ],
  caption: [Inventario completo de estructuras de salida producidas por el flujo reproducible de la Fase 4.],
)

== Indicadores Globales Consolidados y Convergencia Multi-Fuente

El análisis integrado sobre los *389.182,04 km²* de superficie oficial PDET (170 municipios, 16 subregiones y 19 departamentos) demuestra una notable convergencia en el área agregada de cubiertas pese a las diferencias en el conteo de estructuras individuales: mientras Google Open Buildings V3 detecta *53,0 % más edificaciones* que Microsoft (2,69 M frente a 1,76 M), el área total estimada difiere en apenas *0,85 %* (`223,01 km²` vs. `221,13 km²`). Esta compensación responde al efecto de segmentación satelital: Google delimita cubiertas más granulares (mediana `58,08 m²`), mientras Microsoft tiende a fusionar tejados contiguos en polígonos mayores (mediana `77,00 m²`).

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (2.3fr, 1.2fr, 1.2fr, 1.3fr),
      align: (left, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Indicador Global (Territorios PDET)*], [*Microsoft*], [*Google V3*], [*Consenso Híbrido*],
      [Municipios con cobertura], [170 / 170], [165 / 170], [170 / 170],
      [Total de edificaciones detectadas], [1.761.047], [2.694.786], [—],
      [Área total de cubiertas (km²)], [221,13 km²], [223,01 km²], [*222,44 km²*],
      [Área total de cubiertas (hectáreas)], [22.112,80 ha], [22.300,75 ha], [*22.243,73 ha*],
      [Área bajo filtro de calidad `RN-05` (`10–20.000 m²`)], [221,00 km² (99,94 %)], [222,33 km² (99,70 %)], [—],
      [Área de alta confianza (`confidence >= 0,75`)], [N/A], [180,31 km² (80,85 %)], [—],
      [Área promedio / mediana por edificación (m²)], [125,57 / 77,00], [82,76 / 58,08], [—],
      [Densidad global de cubiertas (% del territorio)], [0,0568 %], [0,0573 %], [*0,0572 %*],
      [Área útil fotovoltaica estimada ($f_u = 40%$)], [88,45 km²], [89,20 km²], [*88,97 km²*],
      [Capacidad instalada potencial ($rho = 0,20 "kWp/m"^2$)], [17,69 GWp], [17,84 GWp], [*17,79 GWp*],
      [Generación anual estimada ($Y = 1.450 "kWh/kWp"$)], [25,65 TWh/año], [25,87 TWh/año], [*25,80 TWh/año*],
    )
  ],
  caption: [Resumen ejecutivo de métricas globales de conteo, área de techos y potencial solar fotovoltaico en los 170 municipios PDET.],
)

La magnitud del potencial técnico estimado —*17,79 GWp* de capacidad pico instalada y *25,80 TWh/año* de generación eléctrica teórica— equivale a aproximadamente un tercio de la demanda eléctrica anual del Sistema Interconectado Nacional (SIN) de Colombia, evidenciando que incluso una fracción modesta de aprovechamiento efectivo (5 % a 10 % en proyectos piloto focalizados) representa entre *0,89 y 1,78 GWp* de capacidad distribuida de alto impacto social y energético en territorios priorizados.

#figure(
  image("../reports/figures/01_map_pdet_rooftop_area.png", width: 100%),
  caption: [Distribución espacial comparativa del área total de cubiertas (km², escala logarítmica) según Microsoft Building Footprints y Google Open Buildings V3. Se resaltan en achurado los 5 municipios de la subregión Chocó sin cobertura satelital en Google.],
) <fig-map-area>

#figure(
  image("../reports/figures/02_map_pdet_solar_potential.png", width: 88%),
  caption: [Mapa coroplético del potencial solar fotovoltaico estimado (MWp, consenso híbrido) en los 170 municipios PDET, destacando los principales polos urbanos y agroindustriales con mayor capacidad instalable.],
) <fig-map-solar>

#figure(
  image("../reports/figures/03_map_pdet_density_and_discrepancy.png", width: 100%),
  caption: [Izquierda: densidad de cubiertas construida ($"m"^2$ de techo por $"km"^2$ de superficie municipal). Derecha: discrepancia relativa con signo entre Google y Microsoft, evidenciando subdetección de Google en corredores selváticos húmedos del Pacífico y el sur del Tolima.],
) <fig-map-density>

== Resultados por Subregión PDET y Priorización Municipal

=== Desagregación por las 16 Subregiones PDET

El inventario exhibe una marcada heterogeneidad regional. Las tres primeras subregiones —*Sierra Nevada - Perijá* (`50,01 km²`, `4.000,8 MWp`), *Alto Patía y Norte del Cauca* (`30,64 km²`, `2.451,0 MWp`) y *Cuenca del Caguán y Piedemonte Caqueteño* (`21,80 km²`, `1.743,7 MWp`)— agrupan por sí solas el *46,1 %* de toda el área de cubiertas PDET. En el extremo opuesto, *Chocó* (`2,95 km²`, `235,8 MWp`) y *Sur del Tolima* (`3,79 km²`, `303,0 MWp`) presentan la menor superficie construida y, simultáneamente, las mayores brechas entre Microsoft y Google (`-49,5 %` y `-41,0 %`, respectivamente).

#figure(
  text(size: 8.5pt)[
    #table(
      columns: (0.45fr, 2.2fr, 0.55fr, 0.8fr, 0.8fr, 0.85fr, 0.75fr, 0.85fr, 0.85fr),
      align: (center, left, center, right, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*\#*], [*Subregión PDET*], [*Mpios*], [*MS (km²)*], [*Google (km²)*], [*Consenso (km²)*], [*$Delta$ (%)*], [*Potencial (MWp)*], [*Gen. (GWh/año)*],
      [1], [Sierra Nevada - Perijá], [15], [46,27], [53,75], [50,01], [+16,2 %], [4.000,8], [5.801,2],
      [2], [Alto Patía y Norte del Cauca], [24], [30,36], [30,92], [30,64], [+1,8 %], [2.451,0], [3.554,0],
      [3], [Cuenca del Caguán y Piedemonte], [17], [22,57], [21,02], [21,80], [-6,9 %], [1.743,7], [2.528,4],
      [4], [Urabá Antioqueño], [8], [15,34], [18,23], [16,78], [+18,8 %], [1.342,8], [1.947,1],
      [5], [Putumayo], [9], [13,86], [12,61], [13,23], [-9,0 %], [1.058,7], [1.535,1],
      [6], [Montes de María], [15], [11,82], [14,29], [13,06], [+20,9 %], [1.044,5], [1.514,5],
      [7], [Macarena - Guaviare], [12], [11,49], [10,23], [10,86], [-10,9 %], [868,7], [1.259,6],
      [8], [Bajo Cauca y Nordeste Ant.], [13], [10,69], [10,96], [10,83], [+2,5 %], [866,0], [1.255,7],
      [9], [Arauca], [4], [10,20], [9,47], [9,83], [-7,1 %], [786,8], [1.140,8],
      [10], [Catatumbo], [8], [9,22], [8,26], [8,74], [-10,4 %], [699,2], [1.013,8],
      [11], [Pacífico Medio], [4], [8,78], [8,65], [8,72], [-1,5 %], [697,6], [1.011,5],
      [12], [Sur de Córdoba], [5], [8,33], [8,73], [8,53], [+4,7 %], [682,3], [989,3],
      [13], [Pacífico y Frontera Nariñense], [11], [8,17], [5,28], [6,73], [-35,4 %], [538,3], [780,5],
      [14], [Sur de Bolívar], [7], [5,84], [6,06], [5,95], [+3,8 %], [475,8], [689,9],
      [15], [Sur del Tolima], [4], [4,77], [2,81], [3,79], [-41,0 %], [303,0], [439,4],
      [16], [Chocó (9/14 en Google)], [14], [3,43], [1,73], [2,95], [-49,5 %], [235,8], [341,9],
      [*—*], [*Total Territorios PDET*], [*170*], [*221,13*], [*223,01*], [*222,44*], [*+0,85 %*], [*17.795,0*], [*25.802,7*],
    )
  ],
  caption: [Resultados consolidados por subregión PDET ordenados por prioridad de potencial solar fotovoltaico (consenso híbrido).],
)

#figure(
  image("../reports/figures/04_subregions_comparison.png", width: 100%),
  caption: [Comparativa directa entre Microsoft y Google por subregión PDET (izquierda: área de cubiertas en km²; derecha: potencial solar estimado en MWp sobre consenso híbrido).],
) <fig-subregions>

=== Top 15 Municipios PDET Prioritarios

A nivel municipal, *Santa Marta* (`15,13 km²`, `1.210,4 MWp`) y *Valledupar* (`14,45 km²`, `1.156,1 MWp`) lideran con amplia ventaja el inventario, representando conjuntamente el *13,3 %* de toda el área de cubiertas PDET del país. Les siguen polos estratégicos portuarios, amazónicos y agroindustriales como *Buenaventura*, *Florencia*, *Turbo*, *San Andrés de Tumaco* y *Santander de Quilichao*. En términos de densidad territorial construida (techo por $"km"^2$ de suelo), sobresalen municipios compactos como *Piendamó - Tunía* (`1,34 %`), *Santander de Quilichao* (`0,78 %`), *Apartadó* (`0,65 %`) y *Santa Marta* (`0,65 %`).

#figure(
  text(size: 8.5pt)[
    #table(
      columns: (0.4fr, 0.7fr, 1.5fr, 1.5fr, 0.75fr, 0.75fr, 0.8fr, 0.8fr, 0.85fr),
      align: (center, center, left, left, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*\#*], [*DANE*], [*Municipio*], [*Subregión PDET*], [*MS (km²)*], [*Google (km²)*], [*Cons. (km²)*], [*MWp*], [*GWh/año*],
      [1], [`47001`], [Santa Marta], [Sierra Nevada - Perijá], [14,21], [16,05], [15,13], [1.210,4], [1.755,1],
      [2], [`20001`], [Valledupar], [Sierra Nevada - Perijá], [13,51], [15,39], [14,45], [1.156,1], [1.676,4],
      [3], [`76109`], [Buenaventura], [Pacífico Medio], [7,15], [7,67], [7,41], [592,6], [859,3],
      [4], [`18001`], [Florencia], [Cuenca del Caguán], [6,69], [7,36], [7,03], [562,0], [815,0],
      [5], [`05837`], [Turbo], [Urabá Antioqueño], [4,66], [6,05], [5,35], [428,4], [621,1],
      [6], [`52835`], [San Andrés de Tumaco], [Pacífico y Front. Nariñ.], [4,52], [3,78], [4,15], [332,1], [481,6],
      [7], [`19698`], [Santander de Quilichao], [Alto Patía y N. Cauca], [4,24], [3,85], [4,04], [323,5], [469,1],
      [8], [`47189`], [Ciénaga], [Sierra Nevada - Perijá], [3,47], [3,98], [3,73], [298,0], [432,1],
      [9], [`05045`], [Apartadó], [Urabá Antioqueño], [3,37], [3,61], [3,49], [279,0], [404,6],
      [10], [`18753`], [San Vicente del Caguán], [Cuenca del Caguán], [3,76], [2,56], [3,16], [252,7], [366,4],
      [11], [`95001`], [San José del Guaviare], [Macarena - Guaviare], [3,10], [3,17], [3,13], [250,6], [363,4],
      [12], [`81065`], [Arauquita], [Arauca], [3,32], [2,93], [3,13], [250,1], [362,6],
      [13], [`54810`], [Tibú], [Catatumbo], [3,57], [2,65], [3,11], [248,9], [360,8],
      [14], [`23807`], [Tierralta], [Sur de Córdoba], [2,97], [3,09], [3,03], [242,5], [351,6],
      [15], [`81794`], [Tame], [Arauca], [2,76], [3,20], [2,98], [238,5], [345,8],
    )
  ],
  caption: [Ranking de los 15 municipios PDET con mayor área estimada de cubiertas y potencial solar fotovoltaico.],
)

#figure(
  image("../reports/figures/05_top15_municipalities.png", width: 100%),
  caption: [Top 15 municipios PDET por área de cubiertas (consenso, Microsoft y Google) junto con su capacidad pico solar estimada (MWp).],
) <fig-top15>

== Análisis Estadístico Comparativo, Morfología y Calidad de Datos

=== Concordancia Inter-Fuente (Microsoft vs. Google, $n = 165$)

Sobre los 165 municipios con cobertura simultánea, el área total municipal muestra una correlación lineal muy elevada: *Pearson $r = 0,9853$* ($R^2 = 0,9708$, $p < 10^(-126)$) y correlación de rangos *Spearman $rho = 0,9376$* ($p < 10^(-76)$). La discrepancia relativa mediana es del *14,75 %*, y *97 de los 165 municipios (58,8 %)* concuerdan dentro de una banda de $plus.minus 20%$. Las divergencias más pronunciadas se concentran en municipios pequeños de alta nubosidad o dosel arbóreo cerrado (como Sipí, Atrato, Lloró o Planadas), donde Google subestima marcadamente el inventario respecto a Microsoft.

#figure(
  image("../reports/figures/06_ms_vs_google_correlation.png", width: 100%),
  caption: [Izquierda: dispersión log-log entre áreas municipales estimadas por Microsoft y Google ($r = 0,9853$, $rho = 0,9376$). Derecha: distribución de discrepancias relativas municipales con identificación de las zonas de concordancia ($plus.minus 20%$).],
) <fig-correlation>

=== Distribución Morfológica por Estratos de Tamaño de Cubierta

El análisis por rangos de área revela un patrón decisivo para la planificación energética: en ambas fuentes más del *68 % de los edificios* corresponde a viviendas pequeñas y medianas ($30 "–" 150 "m"^2$), pero el mayor volumen de superficie aprovechable para instalaciones solares de mediana y gran escala se concentra en cubiertas mayores a $80 "m"^2$ (*80,5 %* del área en Microsoft y *68,7 %* en Google). En el segmento de grandes techos ($> 500 "m"^2$, bodegas, equipamiento público, colegios y agroindustria), Microsoft contabiliza 47.073 estructuras (`50,65 km²`, `22,9 %` del área) frente a 21.055 en Google (`19,38 km²`, `8,7 %`), confirmando la tendencia de Microsoft a agrupar manzanas densas o naves contiguas.

#figure(
  text(size: 9pt)[
    #table(
      columns: (1.2fr, 1.1fr, 0.9fr, 1.1fr, 1.1fr, 0.9fr, 1.1fr),
      align: (left, right, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Estrato de Área*], [*MS Conteo*], [*MS % Ár.*], [*MS km²*], [*Google Conteo*], [*G. % Ár.*], [*Google km²*],
      [`< 30 m²`], [194.874], [2,08 %], [4,61], [652.674], [5,42 %], [12,10],
      [`30 – 80 m²`], [720.299], [17,41 %], [38,50], [1.095.784], [25,84 %], [57,62],
      [`80 – 150 m²`], [488.431], [24,00 %], [53,08], [634.334], [30,62 %], [68,29],
      [`150 – 500 m²`], [310.370], [33,60 %], [74,29], [290.939], [29,42 %], [65,62],
      [`> 500 m²`], [47.073], [22,91 %], [50,65], [21.055], [8,69 %], [19,38],
    )
  ],
  caption: [Comparación morfológica por estratos de tamaño de cubierta entre Microsoft Building Footprints y Google Open Buildings V3.],
)

#figure(
  image("../reports/figures/07_roof_size_strata.png", width: 100%),
  caption: [Distribución porcentual de edificaciones (izquierda) y área total de cubiertas (derecha) por estrato de tamaño en Microsoft y Google.],
) <fig-strata>

=== Confianza Satelital, Sensibilidad de Filtros y Vacío de Cobertura en el Pacífico

La distribución de confianza en `buildings_google` (promedio `77,96 %`) muestra una relación directa entre tamaño de cubierta y certeza del modelo: los registros en el tramo `0,65–0,70` promedian apenas `36,07 m²`, mientras que los del tramo `0,90–1,00` alcanzan `265,72 m²`. Por ello, exigir `confidence >= 0,75` reduce el conteo en un `35,0 %`, pero conserva el *80,85 % del área total útil*. Por su parte, los *5 municipios sin registros en Google* se concentran en su totalidad en la subregión *Chocó*, lo cual demuestra la necesidad técnica de la estrategia de respaldo con Microsoft:

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (0.8fr, 1.6fr, 1.3fr, 1.0fr, 1.0fr, 1.0fr, 1.0fr),
      align: (center, left, left, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*DANE*], [*Municipio*], [*Departamento*], [*Edif. MS*], [*Área MS (ha)*], [*Pot. (MWp)*], [*Gen. (GWh/a)*],
      [`27099`], [Bojayá], [Chocó], [2.004], [17,28], [13,83], [20,05],
      [`05873`], [Vigía del Fuerte], [Antioquia], [1.714], [16,28], [13,02], [18,88],
      [`27450`], [Medio San Juan], [Chocó], [1.627], [15,50], [12,40], [17,98],
      [`27491`], [Nóvita], [Chocó], [1.403], [13,83], [11,06], [16,04],
      [`05475`], [Murindó], [Antioquia], [1.331], [11,02], [8,82], [12,79],
      [*Total*], [*5 municipios (subregión Chocó)*], [*—*], [*8.079*], [*73,92 ha*], [*59,13 MWp*], [*85,74 GWh/a*],
    )
  ],
  caption: [Municipios PDET sin cobertura en Google Open Buildings V3 recuperados íntegramente mediante el respaldo de Microsoft Building Footprints.],
)

#figure(
  image("../reports/figures/08_google_confidence_and_filters.png", width: 100%),
  caption: [Izquierda: distribución de edificaciones y área acumulada por intervalo de confianza en Google V3. Derecha: análisis de sensibilidad del área total frente a los filtros de calidad `RN-04` y `RN-05`.],
) <fig-confidence>

=== Concentración Espacial (Curva de Pareto e Índice de Gini)

El análisis de concentración arroja un *índice de Gini de 0,5174* sobre el área de cubiertas municipal: los *5 municipios principales* concentran el *22,2 %* del potencial, el *Top 10* reúne el *30,5 %*, *27 municipios* explican el *50 %* y *78 municipios* (menos de la mitad del universo PDET) alcanzan el *80 %*. Esta estructura bimodal permite a la UPME combinar programas masivos de alto retorno en los polos urbanos priorizados con intervenciones focalizadas de equidad energética en los municipios rurales dispersos.

#figure(
  image("../reports/figures/09_pareto_concentration.png", width: 95%),
  caption: [Curva de concentración acumulada (Pareto) del potencial solar fotovoltaico en los 170 municipios PDET, señalando los umbrales del Top 10 (30,5 %), 50 % (27 municipios) y 80 % (78 municipios).],
) <fig-pareto>
= Estructura de Datos de Salida y Resultados Analíticos (Output Data Structure & Results)

== Esquema de Salida en MongoDB (`solar_aggregations`) y Exportaciones Abiertas

La ejecución de `src/5-geospatial_workflow/compute_metrics.py` persiste los resultados consolidados en dos planos complementarios: la colección materializada `solar_aggregations` dentro de MongoDB (`upme_pdet`) para consultas operativas en tiempo constante, y un conjunto de archivos abiertos en `reports/workflow/` y `reports/figures/` para interoperabilidad con plataformas SIG (QGIS, ArcGIS), herramientas de inteligencia de negocios y publicación científica.

=== Estructura Documental de `solar_aggregations`

La colección almacena exactamente *170 documentos* (uno por municipio PDET), indexados mediante la llave única `idx_uk_agg_mpio` (`{cod_dane_mpio: 1}`) y el índice compuesto de priorización `idx_solar_rank_subregion` (`{solar_potential.priority_rank: 1, subregion_pdet.id: 1}`). Cada documento encapsula las métricas independientes de Microsoft y Google, sus indicadores comparativos y la estimación de potencial solar:

```json
{
  "cod_dane_mpio": "47001",
  "cod_dane_dpto": "47",
  "municipio": "SANTA MARTA",
  "departamento": "MAGDALENA",
  "subregion_pdet": { "id": 12, "nombre": "SIERRA NEVADA - PERIJÁ" },
  "area_oficial_km2": 2343.9033,
  "bbox": [-74.246, 10.781, -73.606, 11.351],
  "metrics_microsoft": {
    "has_coverage": true, "building_count": 67664,
    "total_area_km2": 14.2102, "avg_area_m2": 210.01, "median_area_m2": 100.48,
    "plausible_count": 67662, "plausible_area_m2": 14165475.80
  },
  "metrics_google": {
    "has_coverage": true, "building_count": 183652,
    "total_area_km2": 16.0496, "avg_area_m2": 87.39, "median_area_m2": 58.43,
    "avg_confidence": 0.7748, "high_conf_count": 117760, "high_conf_area_m2": 13062764.01
  },
  "comparison_metrics": {
    "delta_count": 115988, "count_ratio_g_to_ms": 2.7142,
    "delta_area_pct": 12.16, "signed_delta_area_pct": 12.94,
    "consensus_strategy": "mean_ms_google", "consensus_area_km2": 15.1299,
    "rooftop_density_pct": 0.6455
  },
  "solar_potential": {
    "usable_roof_m2": 6051954.15, "est_capacity_mwp": 1210.39,
    "est_annual_generation_gwh": 1755.07, "priority_rank": 1
  }
}
```

=== Catálogo de Artefactos Exportados

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (2.1fr, 0.9fr, 0.8fr, 2.5fr),
      align: (left, center, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Archivo / Colección*], [*Formato*], [*Tamaño*], [*Contenido y Uso Recomendado*],
      [`upme_pdet.solar_aggregations`], [MongoDB], [170 docs], [Vista materializada indexada para consultas de priorización en `< 2 ms`.],
      [`reports/workflow/workflow_results.json`], [JSON], [875 KB], [Paquete maestro con metadatos, hash `SHA-256`, KPIs globales, estratos, auditoría `explain`, subregiones, departamentos y los 170 municipios.],
      [`reports/workflow/municipalities_metrics.csv`], [CSV], [60 KB], [Tabla plana de 170 filas y 46 variables lista para Excel, R, Python o Power BI.],
      [`reports/workflow/subregions_metrics.csv`], [CSV], [5,2 KB], [Consolidado de las 16 subregiones PDET con ranking de prioridad y discrepancia.],
      [`reports/workflow/departments_metrics.csv`], [CSV], [5,7 KB], [Consolidado de los 19 departamentos con jurisdicción sobre municipios PDET.],
      [`reports/workflow/pdet_solar_metrics.geojson`], [GeoJSON], [1,77 MB], [Capa vectorial de 170 polígonos simplificados (`0,002°`) con métricas embebidas para QGIS/Leaflet.],
      [`reports/figures/01_*.png` .. `09_*.png`], [PNG 300 DPI], [9 figuras], [Visualizaciones cartográficas y estadísticas acompañadas de `manifest.json`.],
    )
  ],
  caption: [Inventario completo de estructuras de salida producidas por el flujo reproducible de la Fase 4.],
)

== Indicadores Globales Consolidados y Convergencia Multi-Fuente

El análisis integrado sobre los *389.182,04 km²* de superficie oficial PDET (170 municipios, 16 subregiones y 19 departamentos) demuestra una notable convergencia en el área agregada de cubiertas pese a las diferencias en el conteo de estructuras individuales: mientras Google Open Buildings V3 detecta *53,0 % más edificaciones* que Microsoft (2,69 M frente a 1,76 M), el área total estimada difiere en apenas *0,85 %* (`223,01 km²` vs. `221,13 km²`). Esta compensación responde al efecto de segmentación satelital: Google delimita cubiertas más granulares (mediana `58,08 m²`), mientras Microsoft tiende a fusionar tejados contiguos en polígonos mayores (mediana `77,00 m²`).

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (2.3fr, 1.2fr, 1.2fr, 1.3fr),
      align: (left, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Indicador Global (Territorios PDET)*], [*Microsoft*], [*Google V3*], [*Consenso Híbrido*],
      [Municipios con cobertura], [170 / 170], [165 / 170], [170 / 170],
      [Total de edificaciones detectadas], [1.761.047], [2.694.786], [—],
      [Área total de cubiertas (km²)], [221,13 km²], [223,01 km²], [*222,44 km²*],
      [Área total de cubiertas (hectáreas)], [22.112,80 ha], [22.300,75 ha], [*22.243,73 ha*],
      [Área bajo filtro de calidad `RN-05` (`10–20.000 m²`)], [221,00 km² (99,94 %)], [222,33 km² (99,70 %)], [—],
      [Área de alta confianza (`confidence >= 0,75`)], [N/A], [180,31 km² (80,85 %)], [—],
      [Área promedio / mediana por edificación (m²)], [125,57 / 77,00], [82,76 / 58,08], [—],
      [Densidad global de cubiertas (% del territorio)], [0,0568 %], [0,0573 %], [*0,0572 %*],
      [Área útil fotovoltaica estimada ($f_u = 40%$)], [88,45 km²], [89,20 km²], [*88,97 km²*],
      [Capacidad instalada potencial ($rho = 0,20 "kWp/m"^2$)], [17,69 GWp], [17,84 GWp], [*17,79 GWp*],
      [Generación anual estimada ($Y = 1.450 "kWh/kWp"$)], [25,65 TWh/año], [25,87 TWh/año], [*25,80 TWh/año*],
    )
  ],
  caption: [Resumen ejecutivo de métricas globales de conteo, área de techos y potencial solar fotovoltaico en los 170 municipios PDET.],
)

La magnitud del potencial técnico estimado —*17,79 GWp* de capacidad pico instalada y *25,80 TWh/año* de generación eléctrica teórica— equivale a aproximadamente un tercio de la demanda eléctrica anual del Sistema Interconectado Nacional (SIN) de Colombia, evidenciando que incluso una fracción modesta de aprovechamiento efectivo (5 % a 10 % en proyectos piloto focalizados) representa entre *0,89 y 1,78 GWp* de capacidad distribuida de alto impacto social y energético en territorios priorizados.

#figure(
  image("../reports/figures/01_map_pdet_rooftop_area.png", width: 100%),
  caption: [Distribución espacial comparativa del área total de cubiertas (km², escala logarítmica) según Microsoft Building Footprints y Google Open Buildings V3. Se resaltan en achurado los 5 municipios de la subregión Chocó sin cobertura satelital en Google.],
) <fig-map-area>

#figure(
  image("../reports/figures/02_map_pdet_solar_potential.png", width: 88%),
  caption: [Mapa coroplético del potencial solar fotovoltaico estimado (MWp, consenso híbrido) en los 170 municipios PDET, destacando los principales polos urbanos y agroindustriales con mayor capacidad instalable.],
) <fig-map-solar>

#figure(
  image("../reports/figures/03_map_pdet_density_and_discrepancy.png", width: 100%),
  caption: [Izquierda: densidad de cubiertas construida ($"m"^2$ de techo por $"km"^2$ de superficie municipal). Derecha: discrepancia relativa con signo entre Google y Microsoft, evidenciando subdetección de Google en corredores selváticos húmedos del Pacífico y el sur del Tolima.],
) <fig-map-density>

== Resultados por Subregión PDET y Priorización Municipal

=== Desagregación por las 16 Subregiones PDET

El inventario exhibe una marcada heterogeneidad regional. Las tres primeras subregiones —*Sierra Nevada - Perijá* (`50,01 km²`, `4.000,8 MWp`), *Alto Patía y Norte del Cauca* (`30,64 km²`, `2.451,0 MWp`) y *Cuenca del Caguán y Piedemonte Caqueteño* (`21,80 km²`, `1.743,7 MWp`)— agrupan por sí solas el *46,1 %* de toda el área de cubiertas PDET. En el extremo opuesto, *Chocó* (`2,95 km²`, `235,8 MWp`) y *Sur del Tolima* (`3,79 km²`, `303,0 MWp`) presentan la menor superficie construida y, simultáneamente, las mayores brechas entre Microsoft y Google (`-49,5 %` y `-41,0 %`, respectivamente).

#figure(
  text(size: 8.5pt)[
    #table(
      columns: (0.45fr, 2.2fr, 0.55fr, 0.8fr, 0.8fr, 0.85fr, 0.75fr, 0.85fr, 0.85fr),
      align: (center, left, center, right, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*\#*], [*Subregión PDET*], [*Mpios*], [*MS (km²)*], [*Google (km²)*], [*Consenso (km²)*], [*$Delta$ (%)*], [*Potencial (MWp)*], [*Gen. (GWh/año)*],
      [1], [Sierra Nevada - Perijá], [15], [46,27], [53,75], [50,01], [+16,2 %], [4.000,8], [5.801,2],
      [2], [Alto Patía y Norte del Cauca], [24], [30,36], [30,92], [30,64], [+1,8 %], [2.451,0], [3.554,0],
      [3], [Cuenca del Caguán y Piedemonte], [17], [22,57], [21,02], [21,80], [-6,9 %], [1.743,7], [2.528,4],
      [4], [Urabá Antioqueño], [8], [15,34], [18,23], [16,78], [+18,8 %], [1.342,8], [1.947,1],
      [5], [Putumayo], [9], [13,86], [12,61], [13,23], [-9,0 %], [1.058,7], [1.535,1],
      [6], [Montes de María], [15], [11,82], [14,29], [13,06], [+20,9 %], [1.044,5], [1.514,5],
      [7], [Macarena - Guaviare], [12], [11,49], [10,23], [10,86], [-10,9 %], [868,7], [1.259,6],
      [8], [Bajo Cauca y Nordeste Ant.], [13], [10,69], [10,96], [10,83], [+2,5 %], [866,0], [1.255,7],
      [9], [Arauca], [4], [10,20], [9,47], [9,83], [-7,1 %], [786,8], [1.140,8],
      [10], [Catatumbo], [8], [9,22], [8,26], [8,74], [-10,4 %], [699,2], [1.013,8],
      [11], [Pacífico Medio], [4], [8,78], [8,65], [8,72], [-1,5 %], [697,6], [1.011,5],
      [12], [Sur de Córdoba], [5], [8,33], [8,73], [8,53], [+4,7 %], [682,3], [989,3],
      [13], [Pacífico y Frontera Nariñense], [11], [8,17], [5,28], [6,73], [-35,4 %], [538,3], [780,5],
      [14], [Sur de Bolívar], [7], [5,84], [6,06], [5,95], [+3,8 %], [475,8], [689,9],
      [15], [Sur del Tolima], [4], [4,77], [2,81], [3,79], [-41,0 %], [303,0], [439,4],
      [16], [Chocó (9/14 en Google)], [14], [3,43], [1,73], [2,95], [-49,5 %], [235,8], [341,9],
      [*—*], [*Total Territorios PDET*], [*170*], [*221,13*], [*223,01*], [*222,44*], [*+0,85 %*], [*17.795,0*], [*25.802,7*],
    )
  ],
  caption: [Resultados consolidados por subregión PDET ordenados por prioridad de potencial solar fotovoltaico (consenso híbrido).],
)

#figure(
  image("../reports/figures/04_subregions_comparison.png", width: 100%),
  caption: [Comparativa directa entre Microsoft y Google por subregión PDET (izquierda: área de cubiertas en km²; derecha: potencial solar estimado en MWp sobre consenso híbrido).],
) <fig-subregions>

=== Top 15 Municipios PDET Prioritarios

A nivel municipal, *Santa Marta* (`15,13 km²`, `1.210,4 MWp`) y *Valledupar* (`14,45 km²`, `1.156,1 MWp`) lideran con amplia ventaja el inventario, representando conjuntamente el *13,3 %* de toda el área de cubiertas PDET del país. Les siguen polos estratégicos portuarios, amazónicos y agroindustriales como *Buenaventura*, *Florencia*, *Turbo*, *San Andrés de Tumaco* y *Santander de Quilichao*. En términos de densidad territorial construida (techo por $"km"^2$ de suelo), sobresalen municipios compactos como *Piendamó - Tunía* (`1,34 %`), *Santander de Quilichao* (`0,78 %`), *Apartadó* (`0,65 %`) y *Santa Marta* (`0,65 %`).

#figure(
  text(size: 8.5pt)[
    #table(
      columns: (0.4fr, 0.7fr, 1.5fr, 0.85fr, 1.0fr, 0.75fr, 0.85fr, 0.75fr, 0.8fr, 0.85fr),
      align: (center, center, left, right, right, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*\#*], [*DANE*], [*Municipio*], [*Edif. MS*], [*Edif. Google*], [*MS (km²)*], [*Google (km²)*], [*Cons. (km²)*], [*MWp*], [*GWh/año*],
      [1], [`47001`], [Santa Marta], [67.664], [183.652], [14,21], [16,05], [15,13], [1.210,4], [1.755,1],
      [2], [`20001`], [Valledupar], [63.722], [171.425], [13,51], [15,39], [14,45], [1.156,1], [1.676,4],
      [3], [`76109`], [Buenaventura], [33.106], [103.890], [7,15], [7,67], [7,41], [592,6], [859,3],
      [4], [`18001`], [Florencia], [26.897], [58.135], [6,69], [7,36], [7,03], [562,0], [815,0],
      [5], [`05837`], [Turbo], [43.360], [78.927], [4,66], [6,05], [5,35], [428,4], [621,1],
      [6], [`52835`], [San Andrés de Tumaco], [41.423], [50.493], [4,52], [3,78], [4,15], [332,1], [481,6],
      [7], [`19698`], [Santander de Quilichao], [30.843], [35.691], [4,24], [3,85], [4,04], [323,5], [469,1],
      [8], [`47189`], [Ciénaga], [21.991], [42.068], [3,47], [3,98], [3,73], [298,0], [432,1],
      [9], [`05045`], [Apartadó], [9.813], [36.337], [3,37], [3,61], [3,49], [279,0], [404,6],
      [10], [`18753`], [San Vicente del Caguán], [23.587], [21.599], [3,76], [2,56], [3,16], [252,7], [366,4],
      [11], [`95001`], [San José del Guaviare], [21.446], [32.695], [3,10], [3,17], [3,13], [250,6], [363,4],
      [12], [`81065`], [Arauquita], [27.815], [35.077], [3,32], [2,93], [3,13], [250,1], [362,6],
      [13], [`54810`], [Tibú], [35.478], [32.843], [3,57], [2,65], [3,11], [248,9], [360,8],
      [14], [`23807`], [Tierralta], [30.255], [43.123], [2,97], [3,09], [3,03], [242,5], [351,6],
      [15], [`81794`], [Tame], [20.959], [35.958], [2,76], [3,20], [2,98], [238,5], [345,8],
    )
  ],
  caption: [Ranking de los 15 municipios PDET con mayor área estimada de cubiertas y potencial solar fotovoltaico, con el número de edificaciones detectadas por cada fuente.],
)

#figure(
  image("../reports/figures/05_top15_municipalities.png", width: 100%),
  caption: [Top 15 municipios PDET por área de cubiertas (consenso, Microsoft y Google) junto con su capacidad pico solar estimada (MWp).],
) <fig-top15>

== Análisis Estadístico Comparativo, Morfología y Calidad de Datos

=== Concordancia Inter-Fuente (Microsoft vs. Google, $n = 165$)

Sobre los 165 municipios con cobertura simultánea, el área total municipal muestra una correlación lineal muy elevada: *Pearson $r = 0,9853$* ($R^2 = 0,9708$, $p < 10^(-126)$) y correlación de rangos *Spearman $rho = 0,9376$* ($p < 10^(-76)$). La discrepancia relativa mediana es del *14,75 %*, y *97 de los 165 municipios (58,8 %)* concuerdan dentro de una banda de $plus.minus 20%$. Las divergencias más pronunciadas se concentran en municipios pequeños de alta nubosidad o dosel arbóreo cerrado (como Sipí, Atrato, Lloró o Planadas), donde Google subestima marcadamente el inventario respecto a Microsoft.

#figure(
  image("../reports/figures/06_ms_vs_google_correlation.png", width: 100%),
  caption: [Izquierda: dispersión log-log entre áreas municipales estimadas por Microsoft y Google ($r = 0,9853$, $rho = 0,9376$). Derecha: distribución de discrepancias relativas municipales con identificación de las zonas de concordancia ($plus.minus 20%$).],
) <fig-correlation>

=== Distribución Morfológica por Estratos de Tamaño de Cubierta

El análisis por rangos de área revela un patrón decisivo para la planificación energética: en ambas fuentes más del *68 % de los edificios* corresponde a viviendas pequeñas y medianas ($30 "–" 150 "m"^2$), pero el mayor volumen de superficie aprovechable para instalaciones solares de mediana y gran escala se concentra en cubiertas mayores a $80 "m"^2$ (*80,5 %* del área en Microsoft y *68,7 %* en Google). En el segmento de grandes techos ($> 500 "m"^2$, bodegas, equipamiento público, colegios y agroindustria), Microsoft contabiliza 47.073 estructuras (`50,65 km²`, `22,9 %` del área) frente a 21.055 en Google (`19,38 km²`, `8,7 %`), confirmando la tendencia de Microsoft a agrupar manzanas densas o naves contiguas.

#figure(
  text(size: 9pt)[
    #table(
      columns: (1.2fr, 1.1fr, 0.9fr, 1.1fr, 1.1fr, 0.9fr, 1.1fr),
      align: (left, right, right, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Estrato de Área*], [*MS Conteo*], [*MS % Ár.*], [*MS km²*], [*Google Conteo*], [*G. % Ár.*], [*Google km²*],
      [`< 30 m²`], [194.874], [2,08 %], [4,61], [652.674], [5,42 %], [12,10],
      [`30 – 80 m²`], [720.299], [17,41 %], [38,50], [1.095.784], [25,84 %], [57,62],
      [`80 – 150 m²`], [488.431], [24,00 %], [53,08], [634.334], [30,62 %], [68,29],
      [`150 – 500 m²`], [310.370], [33,60 %], [74,29], [290.939], [29,42 %], [65,62],
      [`> 500 m²`], [47.073], [22,91 %], [50,65], [21.055], [8,69 %], [19,38],
    )
  ],
  caption: [Comparación morfológica por estratos de tamaño de cubierta entre Microsoft Building Footprints y Google Open Buildings V3.],
)

#figure(
  image("../reports/figures/07_roof_size_strata.png", width: 100%),
  caption: [Distribución porcentual de edificaciones (izquierda) y área total de cubiertas (derecha) por estrato de tamaño en Microsoft y Google.],
) <fig-strata>

=== Confianza Satelital, Sensibilidad de Filtros y Vacío de Cobertura en el Pacífico

La distribución de confianza en `buildings_google` (promedio `77,96 %`) muestra una relación directa entre tamaño de cubierta y certeza del modelo: los registros en el tramo `0,65–0,70` promedian apenas `36,07 m²`, mientras que los del tramo `0,90–1,00` alcanzan `265,72 m²`. Por ello, exigir `confidence >= 0,75` reduce el conteo en un `35,0 %`, pero conserva el *80,85 % del área total útil*. Por su parte, los *5 municipios sin registros en Google* se concentran en su totalidad en la subregión *Chocó*, lo cual demuestra la necesidad técnica de la estrategia de respaldo con Microsoft:

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (0.8fr, 1.6fr, 1.3fr, 1.0fr, 1.0fr, 1.0fr, 1.0fr),
      align: (center, left, left, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*DANE*], [*Municipio*], [*Departamento*], [*Edif. MS*], [*Área MS (ha)*], [*Pot. (MWp)*], [*Gen. (GWh/a)*],
      [`27099`], [Bojayá], [Chocó], [2.004], [17,28], [13,83], [20,05],
      [`05873`], [Vigía del Fuerte], [Antioquia], [1.714], [16,28], [13,02], [18,88],
      [`27450`], [Medio San Juan], [Chocó], [1.627], [15,50], [12,40], [17,98],
      [`27491`], [Nóvita], [Chocó], [1.403], [13,83], [11,06], [16,04],
      [`05475`], [Murindó], [Antioquia], [1.331], [11,02], [8,82], [12,79],
      [*Total*], [*5 municipios (subregión Chocó)*], [*—*], [*8.079*], [*73,92 ha*], [*59,13 MWp*], [*85,74 GWh/a*],
    )
  ],
  caption: [Municipios PDET sin cobertura en Google Open Buildings V3 recuperados íntegramente mediante el respaldo de Microsoft Building Footprints.],
)

#figure(
  image("../reports/figures/08_google_confidence_and_filters.png", width: 100%),
  caption: [Izquierda: distribución de edificaciones y área acumulada por intervalo de confianza en Google V3. Derecha: análisis de sensibilidad del área total frente a los filtros de calidad `RN-04` y `RN-05`.],
) <fig-confidence>

=== Concentración Espacial (Curva de Pareto e Índice de Gini)

El análisis de concentración arroja un *índice de Gini de 0,5174* sobre el área de cubiertas municipal: los *5 municipios principales* concentran el *22,2 %* del potencial, el *Top 10* reúne el *30,5 %*, *27 municipios* explican el *50 %* y *78 municipios* (menos de la mitad del universo PDET) alcanzan el *80 %*. Esta estructura bimodal permite a la UPME combinar programas masivos de alto retorno en los polos urbanos priorizados con intervenciones focalizadas de equidad energética en los municipios rurales dispersos.

#figure(
  image("../reports/figures/09_pareto_concentration.png", width: 95%),
  caption: [Curva de concentración acumulada (Pareto) del potencial solar fotovoltaico en los 170 municipios PDET, señalando los umbrales del Top 10 (30,5 %), 50 % (27 municipios) y 80 % (78 municipios).],
) <fig-pareto>

#pagebreak()

== Anexo: Resultados por Municipio PDET (170 municipios)

La @tab-anexo-municipios presenta, para cada uno de los 170 municipios PDET, el número de edificaciones y el área total de cubiertas estimados por Microsoft y por Google, el área de consenso y el potencial solar. Los municipios se ordenan por código DANE para facilitar la consulta. En los cinco municipios sin cobertura de Google (`—`) el consenso es el valor de Microsoft. La misma información, con 46 variables por municipio, está en `reports/workflow/municipalities_metrics.csv`.

#show figure: set block(breakable: true)
#figure(
  text(size: 7.5pt)[
    #table(
      columns: (0.55fr, 1.7fr, 0.45fr, 0.8fr, 0.8fr, 0.65fr, 0.65fr, 0.65fr, 0.65fr),
      align: (center, left, center, right, right, right, right, right, right),
      stroke: 0.4pt + luma(150),
      inset: 3pt,
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      table.header(repeat: true, [*DANE*], [*Municipio*], [*Sub.*], [*Edif. MS*], [*Edif. Google*], [*MS (km²)*], [*Google (km²)*], [*Cons. (km²)*], [*MWp*]),
      [`05031`], [Amalfi], [3], [6.860], [2.983], [0,87], [0,19], [0,53], [42,1],
      [`05040`], [Anorí], [3], [7.234], [7.652], [0,65], [0,49], [0,57], [45,9],
      [`05045`], [Apartadó], [16], [9.813], [36.337], [3,37], [3,61], [3,49], [279,0],
      [`05107`], [Briceño], [3], [3.316], [3.565], [0,30], [0,21], [0,25], [20,2],
      [`05120`], [Cáceres], [3], [10.142], [12.425], [0,93], [0,97], [0,95], [76,0],
      [`05147`], [Carepa], [16], [8.699], [16.657], [1,57], [1,73], [1,65], [131,8],
      [`05154`], [Caucasia], [3], [11.455], [30.474], [1,93], [2,77], [2,35], [187,9],
      [`05172`], [Chigorodó], [16], [9.008], [18.871], [1,62], [1,88], [1,75], [140,3],
      [`05234`], [Dabeiba], [16], [7.911], [7.696], [0,72], [0,51], [0,61], [49,2],
      [`05250`], [El Bagre], [3], [9.660], [14.768], [0,89], [1,31], [1,10], [88,2],
      [`05361`], [Ituango], [3], [8.361], [9.063], [0,75], [0,63], [0,69], [55,3],
      [`05475`], [Murindó], [5], [1.331], [—], [0,11], [—], [0,11], [8,8],
      [`05480`], [Mutatá], [16], [4.295], [5.537], [0,47], [0,47], [0,47], [37,4],
      [`05490`], [Necoclí], [16], [18.357], [32.183], [1,64], [2,34], [1,99], [159,2],
      [`05495`], [Nechí], [3], [4.519], [3.492], [0,35], [0,23], [0,29], [23,4],
      [`05604`], [Remedios], [3], [10.208], [13.248], [1,03], [0,96], [1,00], [79,8],
      [`05665`], [San Pedro de Urabá], [16], [11.957], [22.034], [1,29], [1,64], [1,47], [117,5],
      [`05736`], [Segovia], [3], [9.766], [16.158], [1,05], [1,20], [1,13], [90,0],
      [`05790`], [Tarazá], [3], [8.815], [11.438], [0,91], [0,82], [0,86], [69,0],
      [`05837`], [Turbo], [16], [43.360], [78.927], [4,66], [6,05], [5,35], [428,4],
      [`05854`], [Valdivia], [3], [4.485], [6.329], [0,38], [0,44], [0,41], [32,8],
      [`05873`], [Vigía del Fuerte], [5], [1.714], [—], [0,16], [—], [0,16], [13,0],
      [`05893`], [Yondó], [13], [7.133], [10.688], [0,87], [0,89], [0,88], [70,2],
      [`05895`], [Zaragoza], [3], [7.585], [11.188], [0,65], [0,73], [0,69], [55,2],
      [`13042`], [Arenal], [13], [3.888], [7.022], [0,35], [0,49], [0,42], [34,0],
      [`13160`], [Cantagallo], [13], [3.936], [4.822], [0,38], [0,34], [0,36], [28,7],
      [`13212`], [Córdoba], [8], [5.980], [10.271], [0,50], [0,68], [0,59], [46,9],
      [`13244`], [El Carmen de Bolívar], [8], [24.235], [38.386], [2,19], [2,55], [2,37], [189,7],
      [`13248`], [El Guamo], [8], [3.056], [4.923], [0,29], [0,37], [0,33], [26,5],
      [`13442`], [María la Baja], [8], [13.881], [20.569], [1,32], [1,46], [1,39], [111,4],
      [`13473`], [Morales], [13], [6.896], [11.982], [0,70], [0,88], [0,79], [63,4],
      [`13654`], [San Jacinto], [8], [9.088], [14.706], [0,87], [0,98], [0,92], [73,9],
      [`13657`], [San Juan Nepomuceno], [8], [11.579], [21.831], [1,19], [1,45], [1,32], [105,7],
      [`13670`], [San Pablo], [13], [9.776], [15.636], [1,12], [1,12], [1,12], [89,5],
      [`13688`], [Santa Rosa del Sur], [13], [14.033], [18.908], [1,61], [1,49], [1,55], [124,1],
      [`13744`], [Simití], [13], [7.194], [11.018], [0,80], [0,84], [0,82], [65,8],
      [`13894`], [Zambrano], [8], [3.500], [6.080], [0,35], [0,44], [0,40], [31,8],
      [`18001`], [Florencia], [6], [26.897], [58.135], [6,69], [7,36], [7,03], [562,0],
      [`18029`], [Albania], [6], [2.096], [3.012], [0,35], [0,33], [0,34], [27,2],
      [`18094`], [Belén de los Andaquíes], [6], [3.765], [5.328], [0,58], [0,57], [0,58], [46,0],
      [`18150`], [Cartagena del Chairá], [6], [14.037], [15.932], [2,14], [1,86], [2,00], [160,0],
      [`18205`], [Curillo], [6], [2.503], [3.856], [0,39], [0,40], [0,40], [31,7],
      [`18247`], [El Doncello], [6], [5.816], [9.151], [1,15], [1,18], [1,17], [93,5],
      [`18256`], [El Paujíl], [6], [4.686], [6.283], [0,80], [0,74], [0,77], [61,5],
      [`18410`], [La Montañita], [6], [7.701], [9.501], [0,98], [0,93], [0,95], [76,4],
      [`18460`], [Milán], [6], [3.690], [3.630], [0,53], [0,36], [0,45], [35,9],
      [`18479`], [Morelia], [6], [1.558], [2.402], [0,25], [0,28], [0,26], [21,0],
      [`18592`], [Puerto Rico], [6], [11.431], [12.306], [1,75], [1,33], [1,54], [123,0],
      [`18610`], [San José del Fragua], [6], [4.850], [5.240], [0,62], [0,53], [0,58], [46,0],
      [`18753`], [San Vicente del Caguán], [6], [23.587], [21.599], [3,76], [2,56], [3,16], [252,7],
      [`18756`], [Solano], [6], [6.171], [6.067], [0,71], [0,61], [0,66], [52,7],
      [`18785`], [Solita], [6], [2.508], [2.992], [0,32], [0,31], [0,31], [25,2],
      [`18860`], [Valparaíso], [6], [4.367], [4.922], [0,63], [0,54], [0,59], [46,9],
      [`19050`], [Argelia], [1], [9.940], [13.691], [1,04], [0,98], [1,01], [80,7],
      [`19075`], [Balboa], [1], [8.853], [12.679], [0,90], [0,88], [0,89], [71,3],
      [`19110`], [Buenos Aires], [1], [11.444], [13.439], [1,13], [1,08], [1,10], [88,4],
      [`19130`], [Cajibío], [1], [23.771], [41.281], [2,27], [2,58], [2,42], [194,0],
      [`19137`], [Caldono], [1], [12.547], [15.303], [1,18], [1,24], [1,21], [96,7],
      [`19142`], [Caloto], [1], [9.562], [12.220], [1,24], [1,29], [1,26], [101,1],
      [`19212`], [Corinto], [1], [8.784], [10.517], [1,02], [0,90], [0,96], [77,0],
      [`19256`], [El Tambo], [1], [34.366], [38.900], [3,05], [2,45], [2,75], [220,2],
      [`19318`], [Guapi], [9], [5.344], [6.403], [0,56], [0,54], [0,55], [44,0],
      [`19364`], [Jambaló], [1], [5.066], [6.514], [0,43], [0,41], [0,42], [33,8],
      [`19418`], [López de Micay], [9], [5.968], [24], [0,51], [0,00], [0,26], [20,5],
      [`19450`], [Mercaderes], [1], [7.167], [11.486], [0,79], [0,91], [0,85], [67,8],
      [`19455`], [Miranda], [1], [6.625], [10.353], [1,06], [1,21], [1,14], [90,9],
      [`19473`], [Morales], [1], [16.396], [31.057], [1,49], [1,97], [1,73], [138,3],
      [`19532`], [Patía], [1], [11.031], [17.995], [1,36], [1,50], [1,43], [114,4],
      [`19548`], [Piendamó - Tunía], [1], [16.673], [30.220], [2,22], [2,63], [2,42], [193,8],
      [`19698`], [Santander de Quilichao], [1], [30.843], [35.691], [4,24], [3,85], [4,04], [323,5],
      [`19780`], [Suárez], [1], [10.556], [14.544], [0,93], [0,89], [0,91], [72,7],
      [`19809`], [Timbiquí], [9], [5.178], [5.938], [0,56], [0,45], [0,51], [40,4],
      [`19821`], [Toribío], [1], [10.253], [11.452], [0,90], [0,78], [0,84], [67,3],
      [`20001`], [Valledupar], [12], [63.722], [171.425], [13,51], [15,39], [14,45], [1.156,1],
      [`20013`], [Agustín Codazzi], [12], [21.305], [34.733], [2,26], [2,71], [2,49], [199,1],
      [`20045`], [Becerril], [12], [8.044], [12.958], [0,80], [0,93], [0,86], [69,0],
      [`20400`], [La Jagua de Ibirico], [12], [14.624], [20.110], [1,67], [1,65], [1,66], [132,8],
      [`20443`], [Manaure Balcón del Cesar], [12], [3.441], [5.951], [0,42], [0,46], [0,44], [35,4],
      [`20570`], [Pueblo Bello], [12], [10.975], [15.833], [0,91], [0,99], [0,95], [75,9],
      [`20621`], [La Paz], [12], [10.597], [20.413], [1,20], [1,38], [1,29], [103,3],
      [`20750`], [San Diego], [12], [6.632], [12.205], [0,70], [0,90], [0,80], [64,0],
      [`23466`], [Montelíbano], [14], [19.046], [28.089], [2,52], [2,52], [2,52], [201,4],
      [`23580`], [Puerto Libertador], [14], [13.728], [14.553], [1,26], [1,13], [1,20], [95,7],
      [`23682`], [San José de Uré], [14], [4.003], [4.028], [0,36], [0,27], [0,32], [25,4],
      [`23807`], [Tierralta], [14], [30.255], [43.123], [2,97], [3,09], [3,03], [242,5],
      [`23855`], [Valencia], [14], [13.602], [25.094], [1,21], [1,72], [1,46], [117,2],
      [`27006`], [Acandí], [5], [5.372], [6.395], [0,52], [0,46], [0,49], [39,3],
      [`27099`], [Bojayá], [5], [2.004], [—], [0,17], [—], [0,17], [13,8],
      [`27150`], [Carmen del Darién], [5], [3.832], [281], [0,31], [0,01], [0,16], [12,8],
      [`27205`], [Condoto], [5], [2.110], [239], [0,26], [0,02], [0,14], [11,3],
      [`27250`], [El Litoral del San Juan], [5], [2.010], [309], [0,18], [0,04], [0,11], [8,6],
      [`27361`], [Istmina], [5], [1.928], [6.766], [0,17], [0,67], [0,42], [33,6],
      [`27425`], [Medio Atrato], [5], [1.615], [313], [0,16], [0,02], [0,09], [7,0],
      [`27450`], [Medio San Juan], [5], [1.627], [—], [0,16], [—], [0,16], [12,4],
      [`27491`], [Nóvita], [5], [1.403], [—], [0,14], [—], [0,14], [11,1],
      [`27615`], [Riosucio], [5], [6.107], [1.000], [0,50], [0,06], [0,28], [22,2],
      [`27745`], [Sipí], [5], [653], [1], [0,05], [0,00], [0,03], [2,1],
      [`27800`], [Unguía], [5], [5.986], [5.418], [0,54], [0,45], [0,50], [39,8],
      [`41020`], [Algeciras], [6], [8.278], [12.338], [0,92], [1,13], [1,02], [81,9],
      [`44090`], [Dibulla], [12], [12.003], [23.094], [0,96], [1,33], [1,14], [91,3],
      [`44279`], [Fonseca], [12], [13.332], [23.632], [1,54], [1,71], [1,63], [130,0],
      [`44650`], [San Juan del Cesar], [12], [15.579], [28.564], [1,72], [2,02], [1,87], [149,8],
      [`47001`], [Santa Marta], [12], [67.664], [183.652], [14,21], [16,05], [15,13], [1.210,4],
      [`47053`], [Aracataca], [12], [9.653], [19.780], [0,97], [1,71], [1,34], [107,3],
      [`47189`], [Ciénaga], [12], [21.991], [42.068], [3,47], [3,98], [3,73], [298,0],
      [`47288`], [Fundación], [12], [15.821], [30.591], [1,92], [2,54], [2,23], [178,3],
      [`50325`], [Mapiripán], [7], [4.059], [6.776], [0,43], [0,52], [0,48], [38,0],
      [`50330`], [Mesetas], [7], [6.706], [5.795], [0,82], [0,54], [0,68], [54,3],
      [`50350`], [La Macarena], [7], [12.895], [9.900], [1,79], [1,06], [1,42], [114,0],
      [`50370`], [Uribe], [7], [6.705], [3.567], [0,70], [0,30], [0,50], [40,0],
      [`50450`], [Puerto Concordia], [7], [3.682], [5.893], [0,39], [0,47], [0,43], [34,3],
      [`50577`], [Puerto Lleras], [7], [5.569], [6.595], [0,65], [0,58], [0,61], [49,0],
      [`50590`], [Puerto Rico], [7], [7.422], [9.290], [0,78], [0,75], [0,77], [61,3],
      [`50711`], [Vistahermosa], [7], [9.989], [12.234], [1,09], [1,08], [1,09], [86,9],
      [`52079`], [Barbacoas], [10], [8.429], [6.234], [0,83], [0,45], [0,64], [51,2],
      [`52233`], [Cumbitara], [1], [3.975], [5.350], [0,36], [0,36], [0,36], [28,8],
      [`52250`], [El Charco], [10], [6.503], [5.210], [0,62], [0,37], [0,49], [39,3],
      [`52256`], [El Rosario], [1], [4.855], [7.594], [0,40], [0,45], [0,43], [34,1],
      [`52390`], [La Tola], [10], [1.510], [2.009], [0,16], [0,16], [0,16], [12,6],
      [`52405`], [Leiva], [1], [3.980], [6.096], [0,38], [0,39], [0,38], [30,7],
      [`52418`], [Los Andes], [1], [3.875], [7.184], [0,30], [0,42], [0,36], [28,8],
      [`52427`], [Magüí], [10], [3.442], [2.548], [0,40], [0,23], [0,32], [25,4],
      [`52473`], [Mosquera], [10], [1.731], [597], [0,19], [0,04], [0,11], [9,1],
      [`52490`], [Olaya Herrera], [10], [4.394], [1.208], [0,45], [0,07], [0,26], [21,0],
      [`52520`], [Francisco Pizarro], [10], [1.845], [656], [0,17], [0,04], [0,11], [8,4],
      [`52540`], [Policarpa], [1], [5.303], [7.628], [0,49], [0,51], [0,50], [39,7],
      [`52612`], [Ricaurte], [10], [4.878], [196], [0,36], [0,01], [0,18], [14,8],
      [`52621`], [Roberto Payán], [10], [2.501], [364], [0,22], [0,02], [0,12], [9,7],
      [`52696`], [Santa Bárbara], [10], [2.488], [1.505], [0,26], [0,11], [0,18], [14,6],
      [`52835`], [San Andrés de Tumaco], [10], [41.423], [50.493], [4,52], [3,78], [4,15], [332,1],
      [`54206`], [Convención], [4], [8.465], [14.277], [0,90], [1,12], [1,01], [80,9],
      [`54245`], [El Carmen], [4], [5.884], [8.903], [0,54], [0,68], [0,61], [48,8],
      [`54250`], [El Tarra], [4], [10.956], [9.826], [1,18], [0,79], [0,98], [78,7],
      [`54344`], [Hacarí], [4], [4.874], [6.756], [0,47], [0,49], [0,48], [38,7],
      [`54670`], [San Calixto], [4], [5.360], [7.736], [0,50], [0,54], [0,52], [41,8],
      [`54720`], [Sardinata], [4], [10.090], [13.388], [1,11], [1,11], [1,11], [88,8],
      [`54800`], [Teorama], [4], [8.525], [10.550], [0,93], [0,88], [0,91], [72,6],
      [`54810`], [Tibú], [4], [35.478], [32.843], [3,57], [2,65], [3,11], [248,9],
      [`70204`], [Colosó], [8], [3.999], [6.278], [0,32], [0,40], [0,36], [28,9],
      [`70230`], [Chalán], [8], [1.902], [3.144], [0,15], [0,21], [0,18], [14,4],
      [`70418`], [Los Palmitos], [8], [7.011], [13.792], [0,67], [0,86], [0,76], [61,1],
      [`70473`], [Morroa], [8], [5.015], [10.424], [0,51], [0,65], [0,58], [46,6],
      [`70508`], [Ovejas], [8], [9.648], [16.588], [0,81], [1,07], [0,94], [75,4],
      [`70523`], [Palmito], [8], [4.812], [8.938], [0,38], [0,50], [0,44], [35,1],
      [`70713`], [San Onofre], [8], [17.349], [24.614], [1,49], [1,70], [1,59], [127,6],
      [`70823`], [San José de Toluviejo], [8], [8.333], [15.330], [0,77], [0,97], [0,87], [69,5],
      [`73067`], [Ataco], [15], [10.931], [5.354], [1,02], [0,44], [0,73], [58,2],
      [`73168`], [Chaparral], [15], [16.849], [18.703], [1,97], [1,73], [1,85], [148,0],
      [`73555`], [Planadas], [15], [11.274], [7.276], [0,98], [0,54], [0,76], [60,9],
      [`73616`], [Rioblanco], [15], [9.018], [1.329], [0,79], [0,10], [0,45], [35,8],
      [`76109`], [Buenaventura], [9], [33.106], [103.890], [7,15], [7,67], [7,41], [592,6],
      [`76275`], [Florida], [1], [8.375], [14.231], [1,63], [1,67], [1,65], [131,8],
      [`76563`], [Pradera], [1], [7.428], [12.953], [1,57], [1,56], [1,56], [125,1],
      [`81065`], [Arauquita], [2], [27.815], [35.077], [3,32], [2,93], [3,13], [250,1],
      [`81300`], [Fortul], [2], [9.760], [15.564], [1,16], [1,34], [1,25], [99,6],
      [`81736`], [Saravena], [2], [16.141], [25.140], [2,96], [2,00], [2,48], [198,6],
      [`81794`], [Tame], [2], [20.959], [35.958], [2,76], [3,20], [2,98], [238,5],
      [`86001`], [Mocoa], [11], [12.229], [22.816], [2,09], [2,25], [2,17], [173,4],
      [`86320`], [Orito], [11], [17.840], [18.074], [2,03], [1,63], [1,83], [146,3],
      [`86568`], [Puerto Asís], [11], [21.234], [27.581], [3,06], [2,67], [2,86], [228,9],
      [`86569`], [Puerto Caicedo], [11], [6.093], [7.768], [0,73], [0,69], [0,71], [56,9],
      [`86571`], [Puerto Guzmán], [11], [10.746], [8.326], [1,12], [0,70], [0,91], [72,7],
      [`86573`], [Puerto Leguízamo], [11], [7.851], [10.392], [0,97], [0,96], [0,96], [77,0],
      [`86757`], [San Miguel], [11], [8.558], [12.160], [0,89], [0,93], [0,91], [72,6],
      [`86865`], [Valle del Guamuez], [11], [14.349], [16.228], [1,63], [1,49], [1,56], [125,1],
      [`86885`], [Villagarzón], [11], [9.550], [13.366], [1,35], [1,30], [1,32], [105,8],
      [`95001`], [San José del Guaviare], [7], [21.446], [32.695], [3,10], [3,17], [3,13], [250,6],
      [`95015`], [Calamar], [7], [5.411], [5.708], [0,62], [0,52], [0,57], [45,9],
      [`95025`], [El Retorno], [7], [8.453], [11.332], [0,90], [0,93], [0,91], [73,0],
      [`95200`], [Miraflores], [7], [1.773], [3.670], [0,21], [0,32], [0,26], [21,1],
      [], [*Total (170)*], [], [*1.761.047*], [*2.694.786*], [*221,13*], [*223,01*], [*222,44*], [*17.795,0*],
    )
  ],
  caption: [Edificaciones, área de cubiertas (km²) y potencial solar (MWp) de los 170 municipios PDET. «Sub.» es el número de la subregión PDET (1 a 16) del catálogo `MunicipiosPDET.xlsx`.],
) <tab-anexo-municipios>