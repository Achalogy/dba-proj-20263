#import "@preview/touying:0.6.1": *
#import themes.university: *

#show: university-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Potencial Solar en Cubiertas PDET],
    subtitle: [Evaluación Geoespacial NoSQL para la UPME],
    author: [Novoa · Saavedra · Garzón · Vargas],
    date: [Noviembre 2026],
    institution: [Pontificia Universidad Javeriana · Administración de Bases de Datos],
    logo: image("../assets/logo.png", height: 1.3cm),
  ),
  config-colors(
    primary: rgb("#003865"),
    secondary: rgb("#0b63a3"),
    tertiary: rgb("#f0f5fa"),
    neutral-dark: rgb("#1a2433"),
    neutral-light: rgb("#ffffff"),
  ),
  config-common(handout: true),
)

#set text(size: 19pt, font: "Arial", lang: "es")

#let kpi(valor, etiqueta, color: rgb("#003865")) = block(
  fill: rgb("#f0f5fa"), inset: (x: 0.8em, y: 0.65em),
  radius: 0.5em, stroke: 2pt + color, width: 100%,
  align(center)[
    #text(size: 1.8em, weight: "bold", fill: color)[#valor]
    #v(-0.4em)
    #text(size: 0.72em, fill: rgb("#334455"))[#etiqueta]
  ]
)

// ─────────────────────────────────────────
#title-slide()

// ─────────────────────────────────────────
== Agenda

#v(0.8em)
#grid(columns: (1fr, 1fr), gutter: 2em, [
  + Contexto y Mandato UPME
  + Arquitectura NoSQL
  + Integración de Límites PDET
  + Ingesta Masiva (1,76M + 2,69M)
  + Análisis Exploratorio (EDA)
], [
  6. Consenso Híbrido y Modelo Solar
  7. Mapas y Resultados Globales
  8. Top 15 Municipios + Pareto
  9. Recomendaciones UPME
  10. Conclusiones
])

// ─────────────────────────────────────────
== Contexto y Mandato UPME

#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 1em,
  kpi([170], [Municipios PDET]),
  kpi([4,45 M], [Edificios en MongoDB]),
  kpi([222 km²], [Cubiertas Totales]),
  kpi([17,8 GWp], [Potencial Solar], color: rgb("#b86200")),
)

#v(1em)
#grid(columns: (1fr, 1fr), gutter: 2em, [
  *Objetivo UPME:* Cuantificar cubiertas aptas para paneles solares fotovoltaicos en territorios PDET.
], [
  *Requisitos:* MongoDB 9.0 (NoSQL) · Dos fuentes abiertas satelitales: Microsoft y Google.
])

// ─────────────────────────────────────────
== Arquitectura NoSQL — MongoDB 9.0

#v(0.5em)
#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  *Colecciones (`upme_pdet`):*
  - `municipalities_pdet` — 170 polígonos MGN
  - `buildings_microsoft` — 1,76 M documentos
  - `buildings_google` — 2,69 M documentos
  - `solar_aggregations` — 170 métricas finales
], [
  *Indexación Espacial:*
  - Índice `2dsphere` en geometría y centroide
  - Índice compuesto `{mpio, area}`
  - Latencia consulta: *1–15 ms*
  - Plan `explain`: `IXSCAN` al *100 %*
])

// ─────────────────────────────────────────
== Validación Espacial — 170 / 170

#align(center)[
  #v(0.5em)
  #block(fill: rgb("#eef7ee"), inset: 2.5em, radius: 0.8em, stroke: 2pt + rgb("#008800"), width: 60%)[
    #text(size: 4em, weight: "bold", fill: rgb("#008800"))[170/170]
    #v(0.1em)
    #text(size: 1.05em, weight: "bold")[aciertos `$geoIntersects`]
    #v(0.4em)
    #text(size: 0.82em, fill: rgb("#334455"))[
      Punto interior `point_on_surface` dentro de su municipio \
      confirmado con plan `IXSCAN` en < 12 ms.
    ]
  ]
]

// ─────────────────────────────────────────
== Ingesta Masiva — Eficiencia NoSQL

#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  #block(fill: rgb("#f0f5fa"), inset: 1em, radius: 0.5em, stroke: 1pt + rgb("#003865"))[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Microsoft]]
    #v(0.3em)
    - *1.761.047* documentos
    - Lotes de 5.000 · `ordered=False`
    - Índices *post-carga*
    - 30 min total
  ]
], [
  #block(fill: rgb("#f0f5fa"), inset: 1em, radius: 0.5em, stroke: 1pt + rgb("#003865"))[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Google Open Buildings]]
    #v(0.3em)
    - *2.694.786* documentos
    - 8 teselas S2 nivel 4
    - Importador multiproceso e idempotente
    - 18 min total
  ]
])

#v(0.8em)
#align(center)[
  #block(fill: rgb("#fff8e7"), inset: 0.6em, radius: 0.4em, stroke: 1pt + rgb("#b86200"), width: 70%)[
    #text(weight: "bold", fill: rgb("#b86200"))[4,45 M documentos · < 620 MiB en disco] con compresión WiredTiger
  ]
]

// ─────────────────────────────────────────
== EDA — Conteo vs. Área

#grid(columns: (1fr, 1fr), gutter: 2em, [
  #kpi([+53 %], [Más detecciones en Google\ (segmentación más fina)], color: rgb("#0b63a3"))
  #v(0.5em)
  - Área media Google: *82,8 m²*
  - Área media Microsoft: *125,6 m²*
], [
  #kpi([0,85 %], [Diferencia de Área Total\ (convergencia casi perfecta)], color: rgb("#008800"))
  #v(0.5em)
  - Solo 1,88 km² de diferencia global
  - Confirma solidez física de la estimación
])

#v(0.6em)
#block(fill: rgb("#fff2f2"), inset: 0.6em, radius: 0.4em, stroke: 1pt + rgb("#cc0000"), width: 100%)[
  #text(weight: "bold", fill: rgb("#cc0000"))[Chocó:] 5 municipios sin datos en Google por nubosidad. Microsoft rescata 8.079 edificios.
]

// ─────────────────────────────────────────
== Validación Cruzada Inter-Fuente

#align(center)[
  #image("../reports/figures/06_ms_vs_google_correlation.png", width: 100%)
]

#v(0.3em)
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 0.8em,
  kpi([$r = 0,985$], [Pearson], color: rgb("#003865")),
  kpi([$rho = 0,938$], [Spearman], color: rgb("#0b63a3")),
  kpi([165], [Municipios comunes], color: rgb("#008800")),
  kpi([0,85 %], [Diferencia de Área], color: rgb("#b86200")),
)

// ─────────────────────────────────────────
== Consenso Híbrido y Modelo Solar

#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  *Estrategia de Consenso:*
  - 165 municipios: media MS + Google
  - 5 municipios Chocó: solo Microsoft
  - Cobertura *100 % (170/170)*

  #v(0.5em)
  $ A_"útil" = A_"consenso" times 40 % $
  $ P = A_"útil" times 0,20 " kWp/m"^2 $
  $ E = P times 1.450 " kWh/kWp" dot "año" $
], [
  #v(0.3em)
  #grid(rows: (1fr, 1fr, 1fr), gutter: 0.8em,
    kpi([222 km²], [Área Consolidada]),
    kpi([88,97 km²], [Techo Útil (40 %)]),
    kpi([17,79 GWp], [Potencial Técnico], color: rgb("#b86200")),
  )
])

// ─────────────────────────────────────────
== Mapa — Área de Cubiertas por Municipio

#align(center)[
  #image("../reports/figures/01_map_pdet_rooftop_area.png", width: 100%)
]

// ─────────────────────────────────────────
== Mapa — Potencial Solar Fotovoltaico (MWp)

#align(center)[
  #image("../reports/figures/02_map_pdet_solar_potential.png", width: 100%)
]

// ─────────────────────────────────────────
== Desagregación por Subregiones PDET

#align(center)[
  #image("../reports/figures/04_subregions_comparison.png", width: 90%)
]

// ─────────────────────────────────────────
== Top 15 Municipios Prioritarios

#align(center)[
  #image("../reports/figures/05_top15_municipalities.png", width: 90%)
]

// ─────────────────────────────────────────
== Concentración Espacial — Curva de Pareto

#align(center)[
  #image("../reports/figures/09_pareto_concentration.png", width: 80%)
]

#v(0.2em)
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 0.8em,
  kpi([0,52], [Índice de Gini], color: rgb("#003865")),
  kpi([30,5 %], [Top 10 Municipios], color: rgb("#0b63a3")),
  kpi([50 %], [27 Municipios], color: rgb("#008800")),
  kpi([80 %], [78 Municipios], color: rgb("#b86200")),
)

// ─────────────────────────────────────────
== Recomendaciones UPME

#v(0.5em)
#grid(columns: (1fr, 1fr, 1fr), gutter: 1em, [
  #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 2pt + rgb("#003865"), )[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"))[Horizonte 1 — Pilotos]]
    #v(0.4em)
    *Top 10 municipios* \
    30,5 % del potencial \
    Techos comerciales y públicos \
    Rápida escala
  ]
], [
  #block(fill: rgb("#eef5fa"), inset: 0.9em, radius: 0.5em, stroke: 2pt + rgb("#0b63a3"), )[
    #align(center)[#text(weight: "bold", fill: rgb("#0b63a3"))[Horizonte 2 — Expansión]]
    #v(0.4em)
    *Top 27 municipios* \
    50 % del potencial \
    Cauca, Arauca, Putumayo \
    Sinergia agroindustrial
  ]
], [
  #block(fill: rgb("#fff8ee"), inset: 0.9em, radius: 0.5em, stroke: 2pt + rgb("#b86200"), )[
    #align(center)[#text(weight: "bold", fill: rgb("#b86200"))[Horizonte 3 — Equidad ZNI]]
    #v(0.4em)
    *Chocó · Pacífico · Sur Tolima* \
    Mayor impacto social \
    Reemplazar generación diésel \
    Microrredes comunitarias
  ]
])

// ─────────────────────────────────────────
== Conclusiones

#v(0.5em)
#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  #block(fill: rgb("#eef7ee"), inset: 1em, radius: 0.6em, stroke: 2pt + rgb("#008800"), )[
    #align(center)[#text(weight: "bold", fill: rgb("#008800"), size: 1.05em)[Ingeniería NoSQL]]
    #v(0.4em)
    - 4,45 M cubiertas gestionadas
    - Consultas `IXSCAN` < 15 ms
    - 100 % territorios cubiertos
    - < 620 MiB en disco total
    - Reproducible con `reproduce.sh`
  ]
], [
  #block(fill: rgb("#eef5fa"), inset: 1em, radius: 0.6em, stroke: 2pt + rgb("#003865"), )[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[Aporte Estratégico UPME]]
    #v(0.4em)
    - 222 km² de cubiertas cuantificadas
    - *17,79 GWp* de potencial técnico
    - *25,8 TWh/año* generación estimada
    - Plataforma auditable y transferible
    - Equidad territorial: 170/170 municipios
  ]
])

#v(0.8em)
#align(center)[
  #text(size: 1.2em, weight: "bold", fill: rgb("#003865"))[Muchas gracias — Sesión de preguntas] \
  #v(0.2em)
  #link("https://github.com/Achalogy/dba-proj-20263")[#text(size: 0.82em)[github.com/Achalogy/dba-proj-20263]]
]
