#import "@preview/touying:0.6.1": *
#import themes.university: *

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Evaluación NoSQL Geoespacial del Potencial Solar en Cubiertas],
    subtitle: [170 Municipios PDET de Colombia · Unidad de Planeación Minero Energética (UPME)],
    author: [Juliana Novoa · Juan Saavedra · Juan Garzón · Miguel Vargas],
    date: [Noviembre 2026],
    institution: [Pontificia Universidad Javeriana · Administración de Bases de Datos],
    logo: image("../assets/logo.png", height: 1.2cm),
  ),
  config-colors(
    primary: rgb("#003865"),       // Azul institucional Javeriano
    secondary: rgb("#006699"),     // Azul medio
    tertiary: rgb("#eef5f9"),      // Fondo bloques claros
    neutral-dark: rgb("#1d2a3a"),
    neutral-light: rgb("#ffffff"),
  ),
  config-common(handout: true),
)

#set text(size: 17pt, font: "Arial", lang: "es")

#title-slide()

== Contenido de la Presentación

#grid(
  columns: (1fr, 1fr),
  gutter: 2cm,
  [
    + *Contexto y Mandato UPME*
    + *Arquitectura NoSQL y Modelado (Semana 1)*
    + *Integración de Límites PDET (Semana 2)*
    + *Ingesta Masiva y Eficiencia NoSQL (Semana 3)*
    + *Análisis Exploratorio de Datos (EDA) (Semana 3)*
  ],
  [
    6. *Flujo Geoespacial Reproducible (Semana 4)*
    7. *Convergencia Satelital y Resultados Globales*
    8. *Priorización Territorial y Top 15 Municipal*
    9. *Recomendaciones Estratégicas para la UPME*
    10. *Reproducibilidad Integral y Conclusiones*
  ]
)

= Contexto y Planteamiento del Problema

== Contexto Institucional y Mandato UPME

#grid(
  columns: (3fr, 2fr),
  gutter: 1.5cm,
  [
    - *Iniciativa Estratégica UPME:* Apoyar la transición energética justa y evaluar la prefactibilidad de techos solares comunitarios y granjas solares.
    - *Población Objetivo:* *170 Municipios PDET* (Programas de Desarrollo con Enfoque Territorial) distribuidos en 16 subregiones y 19 departamentos.
    - *Reto Central:* Cuantificar el número y área total de cubiertas ($"m"^2$) aptas para paneles fotovoltaicos.
    - *Requisito Tecnológico Mandatorio:* Aplicar *soluciones de bases de datos NoSQL* capaces de almacenar e indexar millones de geometrías vectoriales complejas.
    - *Evaluación Multi-Fuente:* Contrastar fuentes abiertas satelitales globales (*Microsoft Building Footprints* y *Google Open Buildings V3*).
  ],
  [
    #block(
      fill: rgb("#eef5f9"),
      inset: 1em,
      radius: 0.6em,
      stroke: 0.5pt + rgb("#003865"),
    )[
      #text(weight: "bold", size: 1.1em, fill: rgb("#003865"))[Alcance Territorial]
      #v(0.3em)
      - *170 municipios* PDET
      - *16 subregiones* territoriales
      - *389.182,04 km²* área oficial
      - *4.455.833 huellas* satelitales analizadas en MongoDB
      - Cobertura de equidad: Zonas interconectadas (SIN) y no interconectadas (ZNI)
    ]
  ]
)

= Arquitectura NoSQL y Modelado de Datos

== Arquitectura NoSQL en MongoDB 9.0 (Semana 1)

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Colecciones de Ingesta y Análisis]
      - `municipalities_pdet` (170 docs): Polígonos DANE MGN 2025, atributos administrativos y punto interior.
      - `buildings_microsoft` (1,76M docs): Polígonos GeoJSON, centroide, área en EPSG:9377.
      - `buildings_google` (2,69M docs): Polígonos GeoJSON, centroide, confianza $\ge 0,50$.
      - `solar_aggregations` (170 docs): Colección materializada analítica con métricas consolidadas.
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Estrategia de Indexación NoSQL]
      - *Índices `2dsphere`:*
        - `geometry_2dsphere` para intersección poligonal.
        - `centroid_2dsphere` para proximidad radial.
      - *Índices Compuestos de Alta Velocidad:*
        - `{cod_dane_mpio: 1, rooftop_area_m2: 1}` (MS)
        - `{cod_dane_mpio: 1, confidence: 1}` (Google)
        - `{solar_potential.priority_rank: 1, subregion_pdet.id: 1}`
    ]
  ]
)

#v(0.5em)
- *Proyección y Métrica:* Coordenadas en `EPSG:4326` (WGS 84) con cálculo de área métrica en `EPSG:9377` (MAGNA-SIRGAS Origen Nacional) para eliminar distorsión esferoidal.

= Integración de Límites PDET y Validación Espacial

== Límites Municipales y Validación de Punto Interior (Semana 2)

#grid(
  columns: (3fr, 2fr),
  gutter: 1.2cm,
  [
    - *Extracción y Filtrado:* Delimitación oficial a partir del *Marco Geoestadístico Nacional (MGN 2025 DANE)* cruzado con el catálogo oficial `MunicipiosPDET.xlsx`.
    - *Problema del Centroide Convexo:* En geometrías complejas (polígonos cóncavos, en herradura o archipiélagos), el centroide geométrico puede caer en municipios limítrofes o cuerpos de agua.
    - *Solución Implementada:* Generación algorítmica de `point_on_surface` (punto interior garantizado).
    - *Validación Espacial NoSQL:*
      - Consulta `$geoIntersects` ejecutada en MongoDB sobre los 170 municipios.
      - *Resultado:* *170/170 aciertos (100 % de efectividad)*.
      - *Plan `explain`:* Etapa `IXSCAN` sobre `geometry_2dsphere` en $< 12 "ms"$.
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Garantías de Calidad (MGN)]
      - Topología validada con Shapely 2.0.
      - Eliminación de auto-intersecciones (`make_valid`).
      - Coordenadas GeoJSON estándar (RFC 7946).
      - Exportación idempotente a NDJSON (64 MB) para reproducción inmediata sin descargar 1,5 GB.
    ]
  ]
)

= Ingesta Masiva y Eficiencia de Carga

== Eficiencia de Ingesta Masiva en MongoDB (Semana 3)

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Microsoft Building Footprints]
      - *1.761.047 documentos* insertados.
      - Inserción masiva en lotes de 5.000 con `ordered=False` (no bloqueante).
      - *Patrón Crítico:* Índices creados *después* de la carga para no degradar el árbol B de WiredTiger.
      - Tiempo total: ≈ 30–35 min en máquina estándar.
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Google Open Buildings V3]
      - *2.694.786 documentos* cargados.
      - Particionamiento en 8 teselas S2 nivel 4 intersecadas con el polígono disuelto PDET.
      - Ingesta multiproceso con control de idempotencia por archivo (`etl_processed_files`).
      - Tiempo total: ≈ 15–20 min.
    ]
  ]
)

#v(0.8em)
#align(center)[
  #text(weight: "bold", fill: rgb("#003865"))[Almacenamiento Total:] Base de datos completa en *menos de 620 MiB* en disco gracias a la compresión Snappy/Zlib de WiredTiger.
]

= Análisis Exploratorio de Datos (EDA)

== Hallazgos del EDA: Morfología y Calidad Satelital

#grid(
  columns: (3fr, 2fr),
  gutter: 1.2cm,
  [
    - *Volumen Total:* *4.455.833 huellas* satelitales analizadas en la base de datos `upme_pdet`.
    - *Divergencia en Conteo vs. Convergencia en Área:*
      - Google detecta un *53,0 % más estructuras* que Microsoft (2,69M vs. 1,76M).
      - *Causa morfológica:* Google segmenta patios, anexos y divisiones finas ($"área media" = 82,76 "m"^2$, mediana $58,08 "m"^2$), mientras Microsoft agrupa estructuras contiguas ($"área media" = 125,57 "m"^2$, mediana $77,00 "m"^2$).
      - *Convergencia de Área:* La superficie total difiere en apenas *0,85 %* ($223,01 "km"^2$ vs. $221,13 "km"^2$).
    - *Sensibilidad de Filtros de Calidad:*
      - Filtro de confianza Google ($\ge 0,65$, `RN-04`): retiene el *99,7 % del área de cubiertas*.
      - Filtro de plausibilidad ($15 "m"^2 \le "área" \le 10.000 "m"^2$, `RN-05`): retiene el *99,94 %* en Microsoft.
  ],
  [
    #block(fill: rgb("#fff2f2"), inset: 1em, radius: 0.5em, stroke: 0.5pt + rgb("#cc0000"))[
      #text(weight: "bold", fill: rgb("#cc0000"))[Hallazgo Crítico: Vacío Pacífico]
      Google Open Buildings V3 presenta *ausencia total de datos en 5 municipios* de la subregión Chocó por nubosidad persistente:
      - Bojayá, Vigía del Fuerte, Medio San Juan, Nóvita y Murindó.
      - *8.079 estructuras* rescatadas gracias a Microsoft (*73,92 ha*).
    ]
  ]
)

= Flujo Geoespacial Reproducible y Metodología

== Metodología del Flujo Geoespacial (Semana 4)

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Estrategia de Consenso Híbrido]
      - *165 municipios compartidos:* Media aritmética de área entre Microsoft y Google.
      - *5 municipios sin Google:* Respaldo íntegro de Microsoft Footprints.
      - *Garantía:* Cobertura equitativa del *100 % de los territorios PDET (170/170)*.
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Modelo Paramétrico Solar UPME]
      $ A_"útil" = A_"consenso" times f_u wide (f_u = 0,40) $
      $ P_"est" = A_"útil" times 0,20 "kWp/m"^2 $
      $ E_"anual" = P_"est" times 1.450 " kWh/kWp" dot "año" $
    ]
  ]
)

#v(0.8em)
- *Pipeline Modular:* `src/5-geospatial_workflow/` desacopla extracción MongoDB, cálculo de KPIs y renderizado de figuras.
- *Determinismo Criptográfico:* Exportación de `reports/workflow/workflow_results.json` auditada con hash determinístico *SHA-256*.

= Resultados Analíticos y Visualizaciones

== Resultados Globales y Convergencia Satelital

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #image("../reports/figures/06_ms_vs_google_correlation.png", width: 95%)
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Validación Cruzada Inter-Fuente]
      - *Correlación Pearson:* $r = 0,9853$ ($R^2 = 0,9708$)
      - *Correlación Spearman:* $rho = 0,9376$
      - *Diferencia Global de Área:* Solo *0,85 %* ($1,88 "km"^2$)
      - *Área Consolidada Híbrida:* *222,44 km²*
      - *Área de Techo Útil (40 %):* *88,97 km²*
      - *Potencial Técnico Estimado:* *17.795 MWp (17,79 GWp)*
      - *Generación Anual:* *25.803 GWh/año (25,80 TWh/año)*
    ]
  ]
)

== Distribución Geográfica del Potencial Solar

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #image("../reports/figures/01_map_pdet_rooftop_area.png", width: 95%)
    #align(center)[#text(size: 0.85em)[Área de Cubiertas por Municipio (km²)]]
  ],
  [
    #image("../reports/figures/02_map_pdet_solar_potential.png", width: 95%)
    #align(center)[#text(size: 0.85em)[Capacidad Fotovoltaica Estimada (MWp)]]
  ]
)

== Desagregación por Subregiones PDET

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #image("../reports/figures/04_subregions_comparison.png", width: 95%)
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Jerarquía Territorial]
      + *Sierra Nevada - Perijá:* Lidera ampliamente con *50,01 km²* (22,5 % del total PDET) y *4.000,9 MWp*.
      + *Alto Patía y Norte del Cauca:* 22,76 km² (1.821 MWp).
      + *Macarena - Guaviare:* 19,53 km² (1.562 MWp).
      + *Urabá Antioqueño:* 17,21 km² (1.377 MWp).
      + *Cuenca del Caguán y Piedemonte:* 16,91 km² (1.353 MWp).
      #v(0.3em)
      *Zonas de Menor Área pero Alto Impacto Social:*
      - *Chocó:* 2,95 km² (235,8 MWp) — Crítica por alta dependencia de diésel costoso en ZNI.
    ]
  ]
)

== Priorización Territorial: Top 15 Municipios PDET

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #image("../reports/figures/05_top15_municipalities.png", width: 95%)
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Top 5 Municipios Prioritarios]
      - *Santa Marta (47001):* 15,13 km² ($1.210,4 "MWp"$)
      - *Valledupar (20001):* 14,45 km² ($1.156,1 "MWp"$)
      - *Buenaventura (76109):* 7,41 km² ($592,6 "MWp"$)
      - *Florencia (18001):* 7,03 km² ($562,0 "MWp"$)
      - *Turbo (05837):* 5,35 km² ($428,4 "MWp"$)
      #v(0.4em)
      *Densidad de Cubiertas Sobresaliente:*
      - *Piendamó - Tunía (Cauca):* 1,34 % de su área municipal construida (la más alta del país PDET).
      - *Santander de Quilichao:* 0,81 %.
    ]
  ]
)

== Concentración Espacial: Curva de Pareto e Índice de Gini

#grid(
  columns: (1fr, 1fr),
  gutter: 1cm,
  [
    #image("../reports/figures/09_pareto_concentration.png", width: 95%)
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Índice de Gini: 0,5174]
      - *Top 5 Municipios:* Concentran el *22,2 %* de la capacidad total.
      - *Top 10 Municipios:* Reúnen el *30,5 %* (5.435 MWp).
      - *Top 27 Municipios:* Explican el *50 %* de todo el potencial solar PDET.
      - *Top 78 Municipios:* Alcanzan el *80 %* acumulado.
      #v(0.4em)
      *Implicación de Política Energética:*
      Permite a la UPME una estrategia bimodal: proyectos masivos de alta escala en el Top 10 y proyectos de equidad social en los 143 municipios rurales dispersos.
    ]
  ]
)

= Discusión y Recomendaciones UPME

== Recomendaciones Estratégicas para la UPME

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[1. Portafolio Escalonado en 3 Fases]
      - *Fase Piloto (Top 10 — 30,5 %):* Santa Marta, Valledupar, Buenaventura, Florencia, Turbo. Rápida escala en techos comerciales y públicos.
      - *Expansión Regional (Top 27 — 50 %):* Cauca, Montes de María, Arauca, Putumayo. Sinergias agroindustriales (refrigeración, bombeo).
      - *Equidad en ZNI:* Chocó, Pacífico Nariñense y Sur del Tolima. Reemplazo de plantas diésel por microrredes solares comunitarias.
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[2. Gobernanza de Datos NoSQL]
      - *Doble Aprovisionamiento Obligatorio:* Depender solo de Google habría excluido a 5 municipios del Chocó; depender solo de Microsoft sobreestimaría techos fusionados.
      - *Interoperabilidad:* Estructuras abiertas listas para visores institucionales UPME (SIEL, ArcGIS Enterprise, QGIS) con latencias $< 2 "ms"$.
      - *Ciclos de Actualización Idempotentes:* Re-ejecución automatizada ante nuevos censos o versiones satelitales.
    ]
  ]
)

== Hoja de Ruta Técnica de Trabajo Futuro

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Refinamiento Geoespacial]
      - *Irradiancia Espacialmente Explícita:* Sustituir el rendimiento constante (1.450 kWh/kWp·año) por mapas ráster de irradiancia local (GHI/DNI de Solargis/IDEAM), diferenciando el Caribe (~1.700) del Pacífico húmedo (~1.200).
      - *Modelado de Inclinación y Sombras:* Integrar modelos digitales de superficie (DSM/LiDAR) en los municipios del Top 10 para refinar el factor de utilización ($f_u$).
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Integración Eléctrica y Catastral]
      - *Superposición con Redes Eléctricas:* Cruzar cubiertas con subestaciones del SIN y localidades ZNI del IPSE para evaluar capacidad de inyección inmediata.
      - *Cruce Catastral IGAC:* Identificar techos de propiedad pública (escuelas, hospitales, alcaldías) con menor barrera jurídica para instalación rápida.
    ]
  ]
)

= Reproducibilidad y Conclusiones

== Reproducibilidad de Extremo a Extremo (`reproduce.sh`)

#grid(
  columns: (3fr, 2fr),
  gutter: 1.2cm,
  [
    - *Orquestador Central:* Script raíz `./reproduce.sh` totalmente parametrizado.
    - *Tres Modos Operativos:*
      - `--mode full`: Pipeline completo desde descarga y ETL hasta PDF.
      - `--mode archive`: Restauración rápida desde respaldo `mongodump` (1 min).
      - `--mode analysis`: Recálculo inmediato de métricas, 9 gráficas y PDFs sobre una base ya poblada.
    - *Gestión Moderna de Dependencias:* Implementada con `uv` en cada módulo (`src/*/pyproject.toml` y `uv.lock`), garantizando resolución reproducible y hermética.
    - *Auditoría Determinística:* Verificación de huella SHA-256 en salida.
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 1em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Comando Único de Reproducción]
      ```bash
      # Clonar y ejecutar:
      git clone https://github.com/Achalogy/dba-proj-20263.git
      cd dba-proj-20263

      # Ejecutar flujo completo:
      ./reproduce.sh --mode full --start-mongo
      ```
    ]
  ]
)

== Conclusiones Generales

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2cm,
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Éxito de Ingeniería NoSQL]
      - Se gestionaron e indexaron *4.455.833 huellas satelitales* sobre *170 municipios PDET*.
      - Planes de ejecución `IXSCAN` al 100 % con latencias en el rango de *1 a 53 ms*.
      - Almacenamiento eficiente (< 620 MiB en disco) con WiredTiger.
    ]
  ],
  [
    #block(fill: rgb("#eef5f9"), inset: 0.9em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Impacto en Política Energética]
      - Inventario unificado de *222,44 km²* de cubiertas y *17,79 GWp* de potencial técnico.
      - Convergencia inter-fuente (0,85 % delta; $r = 0,9853$).
      - Enfoque híbrido que garantiza justicia territorial en zonas vulnerables como el Chocó.
    ]
  ]
)

#v(1em)
#align(center)[
  #text(size: 1.2em, weight: "bold", fill: rgb("#003865"))[
    ¡Gracias por su atención!
  ] \
  #v(0.3em)
  #text(size: 0.95em)[
    *Repositorio Oficial:* #link("https://github.com/Achalogy/dba-proj-20263")[https://github.com/Achalogy/dba-proj-20263] \
    *Preguntas y Discusión Técnica*
  ]
]
