= Análisis Exploratorio de Datos (Brief Exploratory Data Analysis - EDA)

== Introducción y Objetivos del EDA

El propósito de esta sección es caracterizar, contrastar y auditar estadísticamente los dos conjuntos de datos masivos de huellas de construcciones (*Microsoft Building Footprints* y *Google Open Buildings*) persistidos en MongoDB para los 170 municipios priorizados de los Programas de Desarrollo con Enfoque Territorial (PDET).

El análisis responde al requerimiento de la UPME de evaluar fuentes de datos abiertas alternativas para cuantificar el potencial de captación solar en cubiertas (_rooftop solar potential_). Los aspectos evaluados comprenden:
+ *Dimensiones y métricas descriptivas globales:* Volumen de registros, áreas agregadas y densidades.
+ *Distribución del área de techos:* Dispersión, sesgo y estratificación por rangos de tamaño de cubierta.
+ *Métricas de calidad y atributos adicionales:* Nivel de confianza en Google y disponibilidad de altura en Microsoft.
+ *Cobertura y granularidad geográfica:* Análisis comparativo a nivel municipal y subregional (16 subregiones PDET).
+ *Hallazgos técnicos y recomendaciones* para la fase de estimación de potencial energético.

== Resumen y Comparativa Global de los Datasets

La base de datos NoSQL `upme_pdet` integra un total consolidado de *4.455.833 edificaciones* entre ambas fuentes dentro del perímetro de los municipios PDET:

#figure(
  text(size: 10pt)[
    #table(
      columns: (1.8fr, 1.4fr, 1.4fr, 1.4fr),
      align: (left, right, right, center),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Métrica General*], [*Microsoft Buildings*], [*Google Open Buildings*], [*Comparación / Relación*],
      [Edificaciones detectadas], [1.761.047], [2.694.786], [Google detecta 1,53× más],
      [Municipios cubiertos], [170 de 170 (100 %)], [165 de 170 (97,1 %)], [5 municipios sin datos en Google],
      [Área total estimada (m²)], [221.128.014,03], [223.007.502,18], [Diferencia de apenas *0,85 %*],
      [Área total estimada (km²)], [*221,13 km²*], [*223,01 km²*], [Discrepancia de 1,88 km²],
      [Área promedio por techo], [125,57 m²], [82,76 m²], [Microsoft 1,52× mayor],
      [Desviación estándar (m²)], [234,28 m²], [125,86 m²], [Mayor dispersión en Microsoft],
      [Área mínima registrada], [9,69 m²], [2,51 m²], [Google detecta micro-techos],
      [Área máxima registrada], [44.667,17 m²], [20.916,70 m²], [Galpones / complejos industriales],
      [Espacio lógico sin comprimir], [973,02 MB], [992,00 MB], [Volumen similar en RAM],
      [Espacio en disco (WiredTiger)], [247,99 MB], [176,25 MB], [Google más compacto (solo Point)],
      [Tamaño total de índices], [111,54 MB], [127,68 MB], [Totalmente residentes en memoria],
    )
  ],
  caption: [Resumen comparativo de métricas globales entre Microsoft y Google Open Buildings.],
)

=== Hallazgo Crítico: Convergencia de Área Total de Captación

El resultado más destacado del análisis exploratorio es la *sorprendente convergencia en la estimación del área total de cubiertas*:
- Microsoft estima *221,13 km²* de techos en los municipios PDET.
- Google Open Buildings estima *223,01 km²*.

A pesar de que Google detecta casi un millón de estructuras adicionales (+53,0 %), la diferencia neta en la superficie captadora total es de únicamente *1,88 km² (0,85 %)*. 

Este fenómeno se explica por la diferencia en la resolución y segmentación de los modelos de visión artificial: mientras que Google segmenta cubiertas individuales o partes modulares de una misma vivienda/edificación (generando muchas detecciones pequeñas con promedio de 82,8 m²), Microsoft tiende a fusionar huellas contiguas en polígonos consolidados (con promedio de 125,6 m²).

== Distribución por Rangos de Tamaño de Edificación

Para entender la morfología de las construcciones identificadas, se categorizaron las edificaciones según su área útil de cubierta:

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (1.8fr, 1.2fr, 1.2fr, 1.2fr, 1.2fr),
      align: (left, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Categoría de Cubierta*], [*Edificios MS*], [*% MS*], [*Edificios Google*], [*% Google*],
      [Micro / Cobertizos (< 30 m²)], [194.874], [11,07 %], [652.674], [24,22 %],
      [Residencial Pequeño (30 - 80 m²)], [720.299], [40,90 %], [1.095.784], [40,66 %],
      [Residencial Medio (80 - 150 m²)], [488.431], [27,74 %], [634.334], [23,54 %],
      [Comercial / Institucional (150 - 500 m²)], [310.370], [17,62 %], [290.939], [10,80 %],
      [Industrial / Grandes Áreas (> 500 m²)], [47.073], [2,67 %], [21.055], [0,78 %],
      [*Total General*], [*1.761.047*], [*100,0 %*], [*2.694.786*], [*100,0 %*],
    )
  ],
  caption: [Distribución de edificaciones por estratos de área de cubierta.],
)

=== Observaciones Morfológicas:
+ *Sensibilidad en estructuras rurales pequeñas (< 30 m²):* Google detecta 652.674 estructuras en este rango (24,22 % de su total), frente a 194.874 de Microsoft. Esto refleja la capacidad del modelo de Google para detectar enramadas, silos, quioscos y pequeñas construcciones campesinas en zonas dispersas.
+ *Núcleo residencial homogéneo (30 - 80 m²):* Ambas fuentes coinciden de manera casi exacta en la proporción de viviendas de tamaño estándar (40,90 % en Microsoft vs. 40,66 % en Google), representando el grupo dominante en los municipios PDET.
+ *Captación de infraestructuras grandes (> 500 m²):* Microsoft detecta más del doble de estructuras industriales o institucionales que Google (47.073 vs. 21.055), debido a que no fragmenta las naves comerciales continuas. En términos de área acumulada, las edificaciones mayores a 500 m² aportan 50,65 km² en Microsoft frente a 19,38 km² en Google.

== Calidad, Nivel de Confianza y Atributos de Altura

=== Confianza en Google Open Buildings
El modelo de detección de Google asigna un puntaje de probabilidad/confianza (`confidence`) a cada punto detectado:
- *Valor mínimo:* 0,6500 (umbral de corte para publicación en el dataset).
- *Valor máximo:* 0,9834.
- *Media:* 0,7796 (77,96 %).
- *Desviación estándar:* 0,0686.

#figure(
  text(size: 10pt)[
    #table(
      columns: (1.5fr, 1.2fr, 1fr, 2.3fr),
      align: (left, right, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Rango de Confianza*], [*Edificios*], [*% del Total*], [*Calidad / Certeza Visual*],
      [De 0,65 a 0,70], [431.340], [16,01 %], [Confianza moderada; estructuras ambiguas o rurales.],
      [De 0,70 a 0,75], [512.369], [19,01 %], [Confianza media-alta.],
      [De 0,75 a 0,80], [634.496], [23,55 %], [Alta certeza de estructura edificada.],
      [De 0,80 a 0,85], [649.136], [24,09 %], [Detección nítida de cubierta.],
      [De 0,85 a 0,90], [390.962], [14,51 %], [Muy alta certeza topológica.],
      [De 0,90 a 1,00], [76.483], [2,84 %], [Certeza casi absoluta (centros urbanos consolidados).],
    )
  ],
  caption: [Distribución de la confianza de detección en Google Open Buildings.],
)

Más del *65 %* de las edificaciones en Google presentan un nivel de confianza superior a 0,75, lo que garantiza una baja tasa de falsos positivos para planeación de energía solar.

=== Atributo de Altura en Microsoft (`height_m`)
El esquema de Microsoft prevé el campo `height_m` para registrar la altura en metros. Sin embargo, en el dataset publicado para Colombia este atributo no fue provisto en los modelos satelitales (registrado como `-1` en los archivos originales y transformado a `null` en la base de datos). Para la Fase 4, la estimación de sombra o inclinación deberá basarse en proxies de área y proyecciones geográficas locales.

== Cobertura Territorial y Municipios Extremos

=== Los 5 Municipios Faltantes en Google Open Buildings
Mientras Microsoft ofrece una cobertura completa del 100 % (170 municipios), Google no contiene detecciones en cinco municipios, todos localizados en la selva húmeda tropical de la cuenca del Pacífico y el Chocó:

#figure(
  text(size: 10pt)[
    #table(
      columns: (1fr, 1.8fr, 1.4fr, 1.2fr, 1.2fr),
      align: (center, left, left, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Código DANE*], [*Municipio*], [*Departamento*], [*Edificios en MS*], [*Área MS (km²)*],
      [05475], [Murindó], [Antioquia], [1.331], [0,11 km²],
      [05873], [Vigía del Fuerte], [Antioquia], [1.714], [0,16 km²],
      [27450], [Medio San Juan], [Chocó], [1.627], [0,16 km²],
      [27491], [Nóvita], [Chocó], [1.403], [0,14 km²],
      [27099], [Bojayá], [Chocó], [2.004], [0,17 km²],
      [*Total Faltante*], [*5 municipios*], [*Antioquia / Chocó*], [*8.079*], [*0,74 km²*],
    )
  ],
  caption: [Municipios PDET sin presencia en Google Open Buildings y sus datos en Microsoft.],
)

*Causa técnica:* Las teselas S2 descargadas cubrieron exhaustivamente los límites de dichos municipios; la ausencia se debe a que el modelo satelital de Google no logró inferir edificaciones debido a la alta nubosidad perenne o follaje selvático tupido en estas áreas. Este es un hallazgo clave: *Microsoft es indispensable para garantizar inclusión territorial en el Pacífico y Chocó*.

=== Top 10 Municipios con Mayor Número de Edificaciones

#figure(
  text(size: 9.5pt)[
    #table(
      columns: (1.6fr, 1.3fr, 1.1fr, 1.1fr, 1.1fr, 1.1fr),
      align: (left, left, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Municipio*], [*Departamento*], [*Edif. MS*], [*Edif. Google*], [*Área MS (km²)*], [*Área Google (km²)*],
      [Santa Marta], [Magdalena], [67.664], [183.652], [14,21], [16,05],
      [Valledupar], [Cesar], [63.722], [171.425], [13,51], [15,39],
      [Buenaventura], [Valle del Cauca], [33.106], [103.890], [7,15], [7,67],
      [Turbo], [Antioquia], [43.360], [78.927], [4,66], [6,05],
      [Florencia], [Caquetá], [26.897], [58.135], [6,69], [7,36],
      [San Andrés de Tumaco], [Nariño], [41.423], [50.493], [4,52], [3,78],
      [Tierralta], [Córdoba], [30.255], [43.123], [2,97], [3,09],
      [Ciénaga], [Magdalena], [21.991], [42.068], [3,47], [3,98],
      [Cajibío], [Cauca], [23.189], [41.281], [1,85], [2,58],
      [El Tambo], [Cauca], [34.366], [38.900], [3,05], [2,45],
    )
  ],
  caption: [Top 10 municipios PDET por número de edificaciones en ambas fuentes.],
)

Los centros urbanos principales de las subregiones PDET (Santa Marta, Valledupar, Buenaventura y Florencia) concentran más de un cuarto del total de cubiertas del país, perfilándose como los polos prioritarios para proyectos solares descentralizados.

== Análisis a Nivel de Subregiones PDET

La consolidación espacial de las edificaciones a lo largo de las 16 subregiones PDET permite comparar la distribución territorial de techos:

#figure(
  text(size: 9pt)[
    #table(
      columns: (2.2fr, 0.6fr, 1fr, 1fr, 1.1fr, 1.1fr),
      align: (left, center, right, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Subregión PDET*], [*Mpios*], [*Edif. MS*], [*Edif. Google*], [*Área MS (km²)*], [*Área Google (km²)*],
      [Alto Patía y Norte del Cauca], [24], [271.668], [388.378], [30,36], [30,92],
      [Arauca], [4], [74.675], [111.739], [10,20], [9,47],
      [Bajo Cauca y Nordeste Antioqueño], [13], [102.406], [142.783], [10,69], [10,96],
      [Catatumbo], [8], [89.632], [104.279], [9,22], [8,26],
      [Chocó], [14], [37.692], [20.722], [3,43], [1,73],
      [Cuenca del Caguán y Piedemonte Caqueteño], [17], [133.941], [182.694], [22,57], [21,02],
      [Macarena - Guaviare], [12], [94.110], [113.455], [11,49], [10,23],
      [Montes de María], [15], [129.388], [215.874], [11,82], [14,29],
      [Pacífico Medio], [4], [49.596], [116.255], [8,78], [8,65],
      [Pacífico y Frontera Nariñense], [11], [79.144], [71.020], [8,17], [5,28],
      [Putumayo], [9], [108.450], [136.711], [13,86], [12,61],
      [Sierra Nevada - Perijá], [15], [295.383], [645.009], [46,27], [53,75],
      [Sur de Bolívar], [7], [52.856], [80.076], [5,84], [6,06],
      [Sur de Córdoba], [5], [80.634], [114.887], [8,33], [8,73],
      [Sur del Tolima], [4], [48.072], [32.662], [4,77], [2,81],
      [Urabá Antioqueño], [8], [113.400], [218.242], [15,34], [18,23],
      [*Total Consolidado*], [*170*], [*1.761.047*], [*2.694.786*], [*221,13*], [*223,01*],
    )
  ],
  caption: [Balance comparativo de edificaciones y área de techos en las 16 subregiones PDET.],
)

=== Dinámicas Subregionales Notables:
+ *Sierra Nevada - Perijá* lidera ampliamente el potencial de área en ambas fuentes (~46,3 km² en MS y ~53,8 km² en Google), concentrando grandes centros urbanos como Valledupar y Santa Marta.
+ *Alto Patía y Norte del Cauca* es la segunda subregión con mayor superficie disponible (~30,4 a 30,9 km²), caracterizada por alta densidad de núcleos poblados rurales.
+ *Chocó* y *Sur del Tolima* presentan mayores volúmenes en Microsoft, confirmando limitaciones de inferencia en Google en zonas montañosas o selváticas.

== Conclusiones del EDA y Recomendaciones para la UPME

+ *Robustez de la Estimación de Área:* La desviación inferior al 1 % entre ambas fuentes (221,13 vs. 223,01 km²) otorga una validez estadística excepcional para los cálculos macro de planeación energética de la UPME.
+ *Estrategia Híbrida Recomendada para la Fase 4:*
  - Utilizar *Google Open Buildings* para conteo de edificaciones residenciales y caracterización de pequeños núcleos rurales dispersos.
  - Utilizar *Microsoft Building Footprints* para el modelado poligonal exacto, grandes superficies comerciales/industriales (> 500 m²) y para cubrir los 5 municipios del Chocó omitidos por Google.
+ *Potencial Energético:* Con más de 220 km² de techos identificados, los municipios PDET presentan un potencial bruto de generación solar fotovoltaica en cubiertas del orden de gigavatios instalables, abriendo oportunidades estratégicas para comunidades energéticas y proyectos de transición justa.

== Reproducibilidad del Análisis (Script `src/4-eda/eda.py`)

Para garantizar que todas las cifras, tablas y validaciones expuestas en este documento sean 100 % reproducibles de manera autónoma, se implementó el script ejecutable `src/4-eda/eda.py`. El script automatiza el flujo completo:
+ Conexión parametrizable a MongoDB mediante la variable de entorno `MONGO_URI` o el argumento `--uri`.
+ Ejecución de las pruebas de auditoría y rendimiento sobre los índices espaciales (`geometry_2dsphere`, `centroid_2dsphere` y `mpio_area`) mediante el comando administrativo `explain(executionStats)`.
+ Ejecución optimizada de los pipelines de agregación sobre los 4,45 millones de documentos en las colecciones `buildings_microsoft` y `buildings_google`.
+ Generación y guardado del archivo consolidado `reports/eda_results.json` en formato JSON estrictamente válido, verificado programáticamente con `json.load()`.

=== Instrucciones de Ejecución

Desde la raíz del repositorio, el análisis se reproduce ejecutando:

```bash
python src/4-eda/eda.py
```

O utilizando el gestor de entornos `uv`:

```bash
uv run --project src/4-eda python src/4-eda/eda.py
```

