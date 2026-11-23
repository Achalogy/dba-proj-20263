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

#set text(size: 20pt, font: "Arial", lang: "es")

// Tarjeta KPI grande
#let kpi(valor, etiqueta, color: rgb("#003865")) = block(
  fill: rgb("#f0f5fa"), inset: (x: 0.9em, y: 0.8em),
  radius: 0.6em, stroke: 2pt + color, width: 100%,
  align(center)[
    #text(size: 2em, weight: "bold", fill: color)[#valor]
    #v(-0.5em)
    #text(size: 0.75em, fill: rgb("#334455"))[#etiqueta]
  ]
)

// Slide de imagen full
#let img-slide(titulo, ruta) = {
  [
    == #titulo
    #align(center)[
      #image(ruta, height: 82%)
    ]
  ]
}

// ─────────────────────────────────────────
#title-slide()

// ─────────────────────────────────────────
== Agenda

#v(1em)
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
  10. Conclusiones y Reproducibilidad
])

// ─────────────────────────────────────────
== Contexto y Mandato UPME

#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 1em,
  kpi([170], [Municipios PDET]),
  kpi([4,45 M], [Edificios en MongoDB]),
  kpi([222 km²], [Cubiertas Totales]),
  kpi([17,8 GWp], [Potencial Solar], color: rgb("#b86200")),
)

#v(1.2em)
- *Objetivo UPME:* Cuantificar cubiertas aptas para paneles solares fotovoltaicos en territorios PDET.
- *Mandato NoSQL:* MongoDB 9.0 — almacenamiento e indexación geoespacial escalable.
- *Dos fuentes abiertas:* Microsoft Building Footprints y Google Open Buildings V3.

// ─────────────────────────────────────────
== Arquitectura NoSQL — MongoDB 9.0

#v(0.5em)
#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  *Colecciones (`upme_pdet`):*
  - `municipalities_pdet` → 170 polígonos MGN
  - `buildings_microsoft` → 1,76 M documentos
  - `buildings_google` → 2,69 M documentos
  - `solar_aggregations` → 170 métricas finales
], [
  *Indexación Espacial:*
  - Índice `2dsphere` en geometría y centroide
  - Índice compuesto `{mpio, area}`
  - *Latencia consulta:* 1–15 ms
  - *Plan `explain`:* `IXSCAN` al *100 %*
])

// ─────────────────────────────────────────
== Validación Espacial — 170 / 170

#align(center)[
  #block(fill: rgb("#eef7ee"), inset: 2em, radius: 0.8em, stroke: 2pt + rgb("#008800"), width: 65%)[
    #text(size: 3.5em, weight: "bold", fill: rgb("#008800"))[170/170]
    #v(0.1em)
    #text(size: 1.1em, weight: "bold")[aciertos `$geoIntersects`]
    #v(0.4em)
    #text(size: 0.85em, fill: rgb("#334455"))[
      Punto interior `point_on_surface` dentro de su municipio \
      confirmado con plan `IXSCAN` en < 12 ms.
    ]
  ]
]

// ─────────────────────────────────────────
== Ingesta Masiva — Eficiencia NoSQL

#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  #block(fill: rgb("#f0f5fa"), inset: 1em, radius: 0.5em, stroke: 1pt + rgb("#003865"))[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Microsoft 🗺️]]
    #v(0.3em)
    - *1.761.047* documentos
    - Lotes de 5.000 · `ordered=False`
    - Índices *post-carga* (4× más rápido)
    - ≈ 30 min total
  ]
], [
  #block(fill: rgb("#f0f5fa"), inset: 1em, radius: 0.5em, stroke: 1pt + rgb("#003865"))[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"), size: 1.1em)[Google 🛰️]]
    #v(0.3em)
    - *2.694.786* documentos
    - 8 teselas S2 nivel 4
    - Importador multiproceso e idempotente
    - ≈ 18 min total
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

#v(0.8em)
#grid(columns: (1fr, 1fr), gutter: 2em, [
  #kpi([+53 %], [Más detecciones en Google\ (segmentación más fina)], color: rgb("#0b63a3"))
  #v(0.7em)
  - Área media Google: *82,8 m²*
  - Área media Microsoft: *125,6 m²*
], [
  #kpi([0,85 %], [Diferencia de Área Total\ (convergencia casi perfecta)], color: rgb("#008800"))
  #v(0.7em)
  - Solo 1,88 km² de diferencia global
  - Confirma solidez física de la estimación
])

#v(0.8em)
#block(fill: rgb("#fff2f2"), inset: 0.6em, radius: 0.4em, stroke: 1pt + rgb("#cc0000"), width: 100%)[
  #text(weight: "bold", fill: rgb("#cc0000"))[⚠ Chocó:] 5 municipios sin datos en Google por nubosidad → rescatados por Microsoft (8.079 edificios).
]

// ─────────────────────────────────────────
== Validación Cruzada Inter-Fuente

#align(center)[
  #image("../reports/figures/06_ms_vs_google_correlation.png", height: 72%)
]

#v(0.4em)
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

  #v(0.6em)
  $ A_"útil" = A_"consenso" times 40 % $
  $ P = A_"útil" times 0,20 " kWp/m"^2 $
], [
  #grid(rows: (1fr, 1fr, 1fr), gutter: 0.8em,
    kpi([222 km²], [Área Consolidada]),
    kpi([88,97 km²], [Techo Útil (40 %)]),
    kpi([17,79 GWp], [Potencial Técnico], color: rgb("#b86200")),
  )
])

// ─────────────────────────────────────────
== Mapa — Área de Cubiertas por Municipio

#align(center)[
  #image("../reports/figures/01_map_pdet_rooftop_area.png", height: 86%)
]

// ─────────────────────────────────────────
== Mapa — Potencial Solar Fotovoltaico (MWp)

#align(center)[
  #image("../reports/figures/02_map_pdet_solar_potential.png", height: 86%)
]

// ─────────────────────────────────────────
== Desagregación por Subregiones PDET

#grid(columns: (3fr, 2fr), gutter: 1em, align: horizon, [
  #image("../reports/figures/04_subregions_comparison.png", height: 82%)
], [
  *Top 3 Subregiones:*
  #v(0.4em)
  + *Sierra Nevada - Perijá*\ 50,01 km² · 4.001 MWp
  + *Alto Patía - Norte Cauca*\ 22,76 km² · 1.821 MWp
  + *Macarena - Guaviare*\ 19,53 km² · 1.562 MWp
])

// ─────────────────────────────────────────
== Top 15 Municipios Prioritarios

#grid(columns: (3fr, 2fr), gutter: 1em, align: horizon, [
  #image("../reports/figures/05_top15_municipalities.png", height: 82%)
], [
  *Top 5:*
  #v(0.4em)
  - *Santa Marta* — 1.210 MWp
  - *Valledupar* — 1.156 MWp
  - *Buenaventura* — 593 MWp
  - *Florencia* — 562 MWp
  - *Turbo* — 428 MWp
])

// ─────────────────────────────────────────
== Concentración Espacial: Curva de Pareto

#grid(columns: (3fr, 2fr), gutter: 1em, align: horizon, [
  #image("../reports/figures/09_pareto_concentration.png", height: 82%)
], [
  *Índice de Gini: 0,52*
  #v(0.5em)
  - Top 10 → *30,5 %* del potencial
  - Top 27 → *50 %* del potencial
  - Top 78 → *80 %* del potencial
  #v(0.5em)
  #text(size: 0.85em, style: "italic", fill: rgb("#555"))[Distribución concentrada → estrategia escalonada.]
])

// ─────────────────────────────────────────
== Recomendaciones UPME

#v(0.6em)
#grid(columns: (1fr, 1fr, 1fr), gutter: 1em, [
  #block(fill: rgb("#eef5fa"), inset: 1em, radius: 0.5em, stroke: 2pt + rgb("#003865"), height: 100%)[
    #align(center)[#text(weight: "bold", fill: rgb("#003865"))[⚡ Horizonte 1\ Pilotos]]
    #v(0.4em)
    *Top 10 municipios*\ 30,5 % del potencial\
    Techos comerciales y públicos · Rápida escala
  ]
], [
  #block(fill: rgb("#eef5fa"), inset: 1em, radius: 0.5em, stroke: 2pt + rgb("#0b63a3"), height: 100%)[
    #align(center)[#text(weight: "bold", fill: rgb("#0b63a3"))[🌿 Horizonte 2\ Expansión]]
    #v(0.4em)
    *Top 27 municipios*\ 50 % del potencial\
    Agroindustria, Cauca, Arauca, Putumayo
  ]
], [
  #block(fill: rgb("#fff8ee"), inset: 1em, radius: 0.5em, stroke: 2pt + rgb("#b86200"), height: 100%)[
    #align(center)[#text(weight: "bold", fill: rgb("#b86200"))[🤝 Horizonte 3\ Equidad ZNI]]
    #v(0.4em)
    *Chocó · Pacífico · Sur Tolima*\ Reemplazar generación diésel\ Microrredes comunitarias
  ]
])

// ─────────────────────────────────────────
== Conclusiones

#v(0.8em)
#grid(columns: (1fr, 1fr), gutter: 1.5em, [
  #block(fill: rgb("#eef7ee"), inset: 1em, radius: 0.6em, stroke: 2pt + rgb("#008800"), height: 100%)[
    #text(weight: "bold", fill: rgb("#008800"), size: 1.05em)[✅ Ingeniería NoSQL]
    #v(0.4em)
    - 4,45 M cubiertas gestionadas
    - Consultas `IXSCAN` < 15 ms
    - 100 % territorios cubiertos
    - < 620 MiB en disco total
  ]
], [
  #block(fill: rgb("#eef5fa"), inset: 1em, radius: 0.6em, stroke: 2pt + rgb("#003865"), height: 100%)[
    #text(weight: "bold", fill: rgb("#003865"), size: 1.05em)[🌞 Aporte Estratégico UPME]
    #v(0.4em)
    - 222 km² de cubiertas cuantificadas
    - *17,79 GWp* de potencial técnico
    - *25,8 TWh/año* generación estimada
    - Plataforma reproducible y transferible
  ]
])

#v(1em)
#align(center)[
  #text(size: 1.3em, weight: "bold", fill: rgb("#003865"))[¡Muchas gracias! Sesión de preguntas] \
  #v(0.2em)
  #link("https://github.com/Achalogy/dba-proj-20263")[#text(size: 0.85em)[github.com/Achalogy/dba-proj-20263]]
]
