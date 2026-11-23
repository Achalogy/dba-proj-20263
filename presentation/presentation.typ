#import "@preview/touying:0.6.1": *
#import themes.university: *

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Potencial Solar en Cubiertas de los 170 Municipios PDET],
    subtitle: [Evaluación Geoespacial NoSQL para la UPME],
    author: [Juliana Novoa · Juan Saavedra · Juan Garzón · Miguel Vargas],
    date: [Noviembre 2026],
    institution: [Pontificia Universidad Javeriana · Administración de Bases de Datos],
    logo: image("../assets/logo.png", height: 1.3cm),
  ),
  config-colors(
    primary: rgb("#003865"),       // Azul Javeriano
    secondary: rgb("#0b63a3"),     // Azul acento
    tertiary: rgb("#f0f5fa"),      // Fondo bloques
    neutral-dark: rgb("#1a2433"),
    neutral-light: rgb("#ffffff"),
  ),
  config-common(handout: true),
)

#set text(size: 16pt, font: "Arial", lang: "es")

// Macro para tarjetas de métricas destacadas
#let kpi(valor, etiqueta, color: rgb("#003865")) = block(
  fill: rgb("#f0f5fa"),
  inset: (x: 0.8em, y: 0.7em),
  radius: 0.5em,
  stroke: 1pt + color,
  width: 100%,
  align(center)[
    #text(size: 1.6em, weight: "bold", fill: color)[#valor] \
    #v(-0.4em)
    #text(size: 0.85em, weight: "medium", fill: rgb("#334455"))[#etiqueta]
  ]
)

#title-slide()

// ========================================================
== Contexto y Mandato UPME

#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 1em,
  kpi([170], [Municipios PDET\ 16 Subregiones]),
  kpi([4,45 M], [Huellas de Edificios\ Analizadas en Mongo]),
  kpi([222,4 km²], [Cubiertas Totales\ Consenso Híbrido]),
  kpi([17,79 GWp], [Potencial Solar\ Técnico Estimado], color: rgb("#b86200")),
)

#v(1em)

#grid(
  columns: (1.2fr, 1fr),
  gutter: 1.5em,
  [
    *Objetivo Institucional UPME:*
    - Identificar municipios prioritarios para proyectos solares en techos.
    - Cuantificar número de cubiertas y área útil ($"m"^2$).
    - Transición energética justa con equidad territorial.
  ],
  [
    *Requisitos de Ingeniería:*
    - Base de datos NoSQL escalable (*MongoDB 9.0*).
    - Comparación obligatoria de fuentes abiertas (*Microsoft* vs. *Google*).
    - Flujo 100 % reproducible desde cero.
  ]
)

// ========================================================
== Arquitectura NoSQL y Modelado de Datos

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.4em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Colecciones en MongoDB (`upme_pdet`)]
      - `municipalities_pdet` (170 docs): Límites MGN 2025 DANE.
      - `buildings_microsoft` (1,76 M docs): Huellas satelitales Bing.
      - `buildings_google` (2,69 M docs): Detecciones S2 nivel 4.
      - `solar_aggregations` (170 docs): Vista materializada UPME.
    ]
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.4em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Índices y Desempeño Espacial]
      - `2dsphere` sobre `geometry` y `centroid`.
      - Índice compuesto `{cod_dane_mpio: 1, rooftop_area_m2: 1}`.
      - Planes `explain`: *`IXSCAN` en 100 % de consultas*.
      - Latencia de consulta: *1 a 15 ms*.
    ]
  ]
)

#v(0.6em)
#align(center)[
  #text(weight: "bold", fill: rgb("#003865"))[Estándar Geoespacial:] Coordenadas `EPSG:4326` (GeoJSON) con cálculo de área métrica en `EPSG:9377` (Origen Nacional).
]

// ========================================================
== Validación Espacial de Límites PDET (Semana 2)

#grid(
  columns: (1.3fr, 1fr),
  gutter: 1.5em,
  [
    *Límites MGN 2025 del DANE:*
    - 170 municipios filtrados con `MunicipiosPDET.xlsx`.
    - Geometrías corregidas y topología validada con Shapely 2.0.

    #v(0.5em)
    *Solución al Problema del Centroide:*
    - En municipios cóncavos, el centroide cae fuera del polígono.
    - Se implementó `point_on_surface` (punto interior garantizado).

    #v(0.5em)
    *Prueba Espacial NoSQL:*
    - Consulta `$geoIntersects` ejecutada en MongoDB.
    - *Resultado:* #text(weight: "bold", fill: rgb("#008800"))[170/170 aciertos (100 % éxito)].
  ],
  [
    #block(fill: rgb("#eef7ee"), inset: 1em, radius: 0.5em, stroke: 1pt + rgb("#008800"))[
      #align(center)[
        #text(size: 1.8em, weight: "bold", fill: rgb("#008800"))[100 %]\
        #text(weight: "bold")[Aciertos Espaciales]\
        #v(0.3em)
        #text(size: 0.9em)[170 de 170 puntos interiores confirmados dentro de sus límites municipales con `IXSCAN` (< 12 ms).]
      ]
    ]
  ]
)

// ========================================================
== Ingesta Masiva y Eficiencia NoSQL (Semana 3)

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.9em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #align(center)[#text(weight: "bold", size: 1.1em, fill: rgb("#003865"))[Microsoft Buildings]]
      #v(0.3em)
      - *1.761.047 cubiertas* cargadas.
      - Inserción en lotes de 5.000 con `ordered=False`.
      - *Patrón Clave:* Índices creados *después* de la carga masiva (ahorro de 4× en tiempo).
      - Tiempo: ≈ 30 min.
    ]
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.9em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #align(center)[#text(weight: "bold", size: 1.1em, fill: rgb("#003865"))[Google Open Buildings]]
      #v(0.3em)
      - *2.694.786 cubiertas* cargadas.
      - Descarga particionada en 8 teselas S2 nivel 4.
      - Importador multiproceso con control de idempotencia por archivo.
      - Tiempo: ≈ 18 min.
    ]
  ]
)

#v(0.8em)
#align(center)[
  #block(fill: rgb("#fff8e7"), inset: (x: 1.5em, y: 0.6em), radius: 0.4em, stroke: 0.5pt + rgb("#b86200"))[
    #text(weight: "bold", fill: rgb("#b86200"))[Eficiencia de Almacenamiento:] Los *4,45 millones de documentos* ocupan *menos de 620 MiB en disco* gracias a la compresión Snappy/Zlib de WiredTiger.
  ]
]

// ========================================================
== EDA: Divergencia en Conteo vs. Convergencia en Área

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #kpi([+53,0 %], [Detecciones en Google\ (2,69M vs. 1,76M)], color: rgb("#0b63a3"))
    #v(0.5em)
    - Google segmenta anexos, patios y subdivisiones.
    - Área media: *82,8 m²* (Google) vs. *125,6 m²* (MS).
    - Mediana: *58,1 m²* (Google) vs. *77,0 m²* (MS).
  ],
  [
    #kpi([0,85 %], [Diferencia Global de Área\ (223,0 km² vs. 221,1 km²)], color: rgb("#008800"))
    #v(0.5em)
    - A pesar de segmentar diferente, el *área total converge*.
    - Diferencia de solo 1,88 km² a nivel nacional.
    - Confirma solidez física de la estimación.
  ]
)

#v(0.8em)
#block(fill: rgb("#fff2f2"), inset: 0.7em, radius: 0.4em, stroke: 0.5pt + rgb("#cc0000"))[
  #text(weight: "bold", fill: rgb("#cc0000"))[Alerta Territorial:] Google tiene *vacío total en 5 municipios del Chocó* por nubosidad (Bojayá, Vigía del Fuerte, Medio San Juan, Nóvita y Murindó). Microsoft rescata sus *8.079 edificios*.
]

// ========================================================
== Validación Cruzada Inter-Fuente (Scatter Plot)

#grid(
  columns: (1.5fr, 1fr),
  gutter: 1.2em,
  align: horizon,
  [
    #image("../reports/figures/06_ms_vs_google_correlation.png", height: 80%)
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.9em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Métricas de Concordancia]
      #v(0.4em)
      - *Pearson:* $r = 0,9853$ ($R^2 = 0,9708$)
      - *Spearman:* $rho = 0,9376$
      - *$n = 165$ municipios* compartidos
      - Discrepancia mediana: *14,75 %*
      - *58,8 %* de municipios dentro del $\pm 20 %$ de acuerdo
    ]
  ]
)

// ========================================================
== Flujo de Consenso Híbrido y Modelo Solar UPME

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.4em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Estrategia de Consenso Híbrido]
      - *165 municipios comunes:* Media aritmética de área Microsoft y Google.
      - *5 municipios Chocó:* Respaldo de Microsoft.
      - *Garantía:* Cobertura equitativa del *100 % de los territorios PDET (170/170)*.
    ]
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.4em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Modelo Paramétrico UPME]
      $ A_"útil" = A_"consenso" times 40 % wide (f_u = 0,40) $
      $ P_"est" = A_"útil" times 0,20 " kWp/m"^2 $
      $ E_"anual" = P_"est" times 1.450 " kWh/kWp" dot "año" $
    ]
  ]
)

#v(0.6em)
#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1em,
  kpi([222,4 km²], [Techo Total Consolidado]),
  kpi([88,97 km²], [Cubierta Útil (40 %)]),
  kpi([25,8 TWh/año], [Generación Estimada], color: rgb("#b86200")),
)

// ========================================================
== Mapa: Área de Cubiertas en Municipios PDET

#align(center)[
  #image("../reports/figures/01_map_pdet_rooftop_area.png", height: 85%)
]

// ========================================================
== Mapa: Potencial Solar Fotovoltaico (MWp)

#align(center)[
  #image("../reports/figures/02_map_pdet_solar_potential.png", height: 85%)
]

// ========================================================
== Desagregación por Subregiones PDET

#grid(
  columns: (1.5fr, 1fr),
  gutter: 1.2em,
  align: horizon,
  [
    #image("../reports/figures/04_subregions_comparison.png", height: 82%)
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Jerarquía Regional]
      - *Sierra Nevada - Perijá:* Lidera con *50,01 km²* (22,5 %) y *4.001 MWp*.
      - *Alto Patía y Norte del Cauca:* 22,76 km² (1.821 MWp).
      - *Macarena - Guaviare:* 19,53 km² (1.562 MWp).
      - *Chocó:* 2,95 km² (236 MWp) — Menor área pero mayor impacto social (ZNI).
    ]
  ]
)

// ========================================================
== Priorización Territorial: Top 15 Municipios

#grid(
  columns: (1.5fr, 1fr),
  gutter: 1.2em,
  align: horizon,
  [
    #image("../reports/figures/05_top15_municipalities.png", height: 82%)
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Top 5 Municipal]
      - *Santa Marta:* 15,1 km² ($1.210 "MWp"$)
      - *Valledupar:* 14,5 km² ($1.156 "MWp"$)
      - *Buenaventura:* 7,4 km² ($593 "MWp"$)
      - *Florencia:* 7,0 km² ($562 "MWp"$)
      - *Turbo:* 5,4 km² ($428 "MWp"$)
      #v(0.3em)
      *Mayor Densidad Construida:*
      - *Piendamó - Tunía:* 1,34 % de su área municipal.
    ]
  ]
)

// ========================================================
== Concentración Espacial: Curva de Pareto y Gini

#grid(
  columns: (1.5fr, 1fr),
  gutter: 1.2em,
  align: horizon,
  [
    #image("../reports/figures/09_pareto_concentration.png", height: 82%)
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Índice de Gini: 0,5174]
      #v(0.3em)
      - *Top 5:* Concentran el *22,2 %*.
      - *Top 10:* Reúnen el *30,5 %* (5.435 MWp).
      - *Top 27:* Reúnen el *50 %* del potencial.
      - *Top 78:* Alcanzan el *80 %*.
      #v(0.3em)
      #text(size: 0.9em, style: "italic")[Permite a la UPME proyectos masivos en cabeceras y proyectos de equidad en áreas rurales.]
    ]
  ]
)

// ========================================================
== Filtros de Calidad y Confianza Satelital

#grid(
  columns: (1.5fr, 1fr),
  gutter: 1.2em,
  align: horizon,
  [
    #image("../reports/figures/08_google_confidence_and_filters.png", height: 82%)
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.8em, radius: 0.5em)[
      #text(weight: "bold", fill: rgb("#003865"))[Sensibilidad de Filtros]
      - *Confianza Google $\ge 0,65$ (`RN-04`):*
        Retiene el *99,7 % del área* descartando falsos positivos.
      - *Plausibilidad 15–10.000 m² (`RN-05`):*
        Retiene el *99,94 %* en Microsoft.
      - Confirma que la estimación de energía es altamente robusta frente a ruido.
    ]
  ]
)

// ========================================================
== Recomendaciones UPME: Portafolio en 3 Horizontes

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1em,
  [
    #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 1pt + rgb("#003865"), height: 100%)[
      #align(center)[#text(weight: "bold", fill: rgb("#003865"))[Horizonte 1: Pilotos Top 10]]
      #v(0.3em)
      - *30,5 % del potencial* (5.435 MWp).
      - Santa Marta, Valledupar, Buenaventura, Florencia.
      - Techos comerciales, industriales y edificios públicos.
      - Rápida escala y menor costo unitario.
    ]
  ],
  [
    #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 1pt + rgb("#0b63a3"), height: 100%)[
      #align(center)[#text(weight: "bold", fill: rgb("#0b63a3"))[Horizonte 2: Expansión Top 27]]
      #v(0.3em)
      - *50 % del potencial solar*.
      - Cauca, Montes de María, Arauca, Putumayo.
      - Sinergia agroindustrial: bombeo de agua, refrigeración y secado agrícola.
    ]
  ],
  [
    #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 1pt + rgb("#b86200"), height: 100%)[
      #align(center)[#text(weight: "bold", fill: rgb("#b86200"))[Horizonte 3: Equidad ZNI]]
      #v(0.3em)
      - Chocó, Pacífico y Sur del Tolima.
      - Menor volumen de techo, pero *mayor impacto social*.
      - Sustitución de generación diésel por microrredes solares comunitarias.
    ]
  ]
)

// ========================================================
== Hoja de Ruta Técnica para Fases Posteriores

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.9em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Refinamiento Geoespacial]
      - *Irradiancia Local (GHI/DNI):* Integrar ráster de Solargis/IDEAM para diferenciar Caribe (~1.750 kWh/kWp) vs. Pacífico (~1.200 kWh/kWp).
      - *Modelado de Inclinación/Sombras:* LiDAR o DSM para ajustar el factor de uso ($f_u$) por orientación de cubiertas.
    ]
  ],
  [
    #block(fill: rgb("#f0f5fa"), inset: 0.9em, radius: 0.5em, stroke: 0.5pt + rgb("#003865"))[
      #text(weight: "bold", fill: rgb("#003865"))[Interoperabilidad y Catastro]
      - *Cruce con Redes Eléctricas:* Superponer con subestaciones del SIN y localidades ZNI del IPSE.
      - *Catastro Multipropósito IGAC:* Priorizar cubiertas de colegios, centros de salud y alcaldías con menor barrera jurídica.
    ]
  ]
)

// ========================================================
== Reproducibilidad en 1 Comando (`reproduce.sh`)

#grid(
  columns: (1.3fr, 1fr),
  gutter: 1.5em,
  [
    *Orquestador Automatizado:*
    - Automatiza las 7 etapas desde descarga hasta PDFs.
    - Manejo hermético de dependencias con `uv`.
    - Integridad auditada con hash determinístico *SHA-256*.

    #v(0.5em)
    *Tres Modos de Uso:*
    - `--mode full`: Descarga, ETL, Mongo, EDA y reportes.
    - `--mode archive`: Carga rápida desde respaldo (1 min).
    - `--mode analysis`: Recálculo analítico sobre Mongo.
  ],
  [
    #block(fill: rgb("#1d2a3a"), inset: 1em, radius: 0.5em)[
      #text(fill: rgb("#88cc88"), font: "Consolas", size: 0.85em)[
        \$ git clone ... \
        \$ cd dba-proj-20263 \
        \
        \# Reproducción total: \
        \$ ./reproduce.sh \\ \
        #h(1em) --mode full \\ \
        #h(1em) --start-mongo
      ]
    ]
  ]
)

// ========================================================
== Conclusiones

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  [
    #block(fill: rgb("#eef7ee"), inset: 0.9em, radius: 0.5em, stroke: 1pt + rgb("#008800"), height: 100%)[
      #text(weight: "bold", fill: rgb("#008800"), size: 1.05em)[Ingeniería NoSQL Exitosa]
      - 4,45M huellas gestionadas sobre 170 municipios.
      - 100 % consultas aceleradas por `IXSCAN` (< 15 ms).
      - Menos de 620 MiB en disco con WiredTiger.
    ]
  ],
  [
    #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 1pt + rgb("#003865"), height: 100%)[
      #text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Aporte Estratégico a la UPME]
      - 222,4 km² de cubiertas y 17,79 GWp cuantificados.
      - Consenso híbrido que evita excluir territorios vulnerables (Chocó).
      - Plataforma auditable y transferible a la UPME.
    ]
  ]
)

#v(0.8em)
#align(center)[
  #text(size: 1.3em, weight: "bold", fill: rgb("#003865"))[
    ¡Muchas Gracias!
  ] \
  #v(0.2em)
  #text(size: 0.9em)[
    *Repositorio Oficial:* #link("https://github.com/Achalogy/dba-proj-20263")[https://github.com/Achalogy/dba-proj-20263] · Sesión de Preguntas
  ]
]
