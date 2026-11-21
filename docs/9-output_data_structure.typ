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
