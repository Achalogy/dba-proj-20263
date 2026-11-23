#import "@preview/touying:0.6.1": *
#import themes.simple: *

// Paleta sobria institucional (PUJ + UPME)
#let navy = rgb("#003865")
#let blue = rgb("#0b63a3")
#let amber = rgb("#b45309")
#let forest = rgb("#047857")
#let crimson = rgb("#b91c1c")
#let ink = rgb("#1e293b")
#let muted = rgb("#64748b")
#let soft-rule = rgb("#e2e8f0")

#show: simple-theme.with(
  aspect-ratio: "16-9",
  primary: navy,
  header: self => {
    set text(size: 0.72em, fill: muted)
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      [#text(weight: "semibold", fill: navy)[UPME · Territorios PDET] #h(0.5em) · #h(0.5em) Evaluación Geoespacial NoSQL],
      image("../assets/logo.png", height: 0.85cm),
    )
    v(-0.45em)
    line(length: 100%, stroke: 0.6pt + soft-rule)
  },
  footer: self => {
    set text(size: 0.65em, fill: muted)
    line(length: 100%, stroke: 0.5pt + soft-rule)
    v(-0.35em)
    grid(
      columns: (1fr, 1fr, auto),
      align: (left, center, right),
      [Pontificia Universidad Javeriana · Administración de Bases de Datos],
      [Novoa · Saavedra · Garzón · Vargas],
      [#context utils.slide-counter.display() / #utils.last-slide-number],
    )
  },
  footer-right: none,
  config-common(handout: true),
)

#set text(font: ("Helvetica Neue", "Arial"), size: 17pt, fill: ink, lang: "es")

#show heading.where(level: 1): it => {
  text(size: 1.25em, weight: "bold", fill: navy)[#it.body]
  v(0.25em)
}

// Tipografía limpia para cifras clave (sin cajas ni bordes redondeados)
#let stat(valor, etiqueta, detalle: none, accent: navy, value-size: 1.5em) = {
  block(width: 100%, inset: (top: 0.35em, bottom: 0.1em), stroke: (top: 2pt + accent))[
    #text(size: value-size, weight: "bold", fill: accent)[#valor] \
    #text(size: 0.78em, weight: "semibold", fill: ink)[#etiqueta]
    #if detalle != none [
      \ #text(size: 0.68em, fill: muted)[#detalle]
    ]
  ]
}

// Acento editorial sutil con línea izquierda (sin fondo de caja)
#let note-rule(title, body, accent: crimson) = {
  block(
    width: 100%,
    inset: (left: 0.85em, top: 0.2em, bottom: 0.2em),
    stroke: (left: 2.5pt + accent),
  )[
    #text(weight: "bold", fill: accent)[#title] #body
  ]
}

// Estilos de tabla tipo booktabs
#set table(
  stroke: (_, y) => (
    top: if y == 0 { 1.2pt + navy } else if y == 1 { 0.8pt + navy } else { 0pt },
    bottom: 1pt + navy,
  ),
  inset: (x: 0.55em, y: 0.42em),
)

// ─────────────────────────────────────────────────────────────────────────────
// 1. PORTADA
// ─────────────────────────────────────────────────────────────────────────────
#title-slide[
  #align(left + horizon)[
    #grid(
      columns: (1fr, auto),
      gutter: 2em,
      align: (left + horizon, right + horizon),
      [
        #text(size: 0.78em, weight: "semibold", tracking: 0.08em, fill: blue)[
          PONTIFICIA UNIVERSIDAD JAVERIANA · ADMINISTRACIÓN DE BASES DE DATOS
        ]
        #v(0.6em)
        #text(size: 1.9em, weight: "bold", fill: navy)[
          Potencial Solar en Cubiertas de los 170 Municipios PDET
        ]
        #v(0.35em)
        #text(size: 1.05em, fill: muted)[
          Plataforma Geoespacial Reproducible en MongoDB 9.0 para la UPME
        ]
        #v(1.0em)
        #line(length: 4.5cm, stroke: 2pt + amber)
        #v(0.8em)
        #text(size: 0.85em, fill: ink)[
          Juliana Sofía Novoa Solano · Juan Santiago Saavedra Holguin \
          Juan Esteban Garzón Tinjaca · Miguel Francisco Vargas Contreras
        ]
        #v(0.3em)
        #text(size: 0.75em, fill: muted)[
          Profesor: Andrés Oswaldo Calderón Romero, Ph.D. · Noviembre 2026
        ]
      ],
      image("../assets/logo.png", width: 4.2cm),
    )
  ]
]

// ─────────────────────────────────────────────────────────────────────────────
// 2. AGENDA
// ─────────────────────────────────────────────────────────────────────────────
== Agenda

#v(0.6em)
#grid(
  columns: (1fr, 1pt, 1fr),
  gutter: 1.8em,
  [
    #set par(leading: 1.15em)
    #text(weight: "bold", fill: navy, size: 0.85em)[FASE DE DATOS E INFRAESTRUCTURA]
    #v(0.3em)
    + Contexto y mandato UPME
    + Arquitectura NoSQL en MongoDB 9.0
    + Integración PDET e ingesta masiva
    + Análisis exploratorio y brecha en Chocó
  ],
  line(angle: 90deg, length: 8.5cm, stroke: 0.6pt + soft-rule),
  [
    #set par(leading: 1.15em)
    #text(weight: "bold", fill: navy, size: 0.85em)[RESULTADOS Y DECISIÓN ESTRATÉGICA]
    #v(0.3em)
    5. Validación cruzada y calidad satelital
    + Consenso híbrido y mapas de potencial solar
    + Ranking subregional, municipal y Pareto
    + Recomendaciones UPME y conclusiones
  ],
)

// ─────────────────────────────────────────────────────────────────────────────
// 3. CONTEXTO Y MANDATO UPME
// ─────────────────────────────────────────────────────────────────────────────
== Contexto y Mandato UPME

#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 1.4em,
  stat([170], [Municipios PDET], detalle: [16 subregiones · 389.182 km²]),
  stat([4,45 M], [Edificios en MongoDB], detalle: [1,76 M MS + 2,69 M Google], accent: blue),
  stat([222,4 km²], [Cubiertas estimadas], detalle: [Consenso híbrido multi-fuente], accent: forest),
  stat([17,79 GWp], [Potencial solar], detalle: [≈ 25,80 TWh/año de referencia], accent: amber),
)

#v(1.2em)
#line(length: 100%, stroke: 0.6pt + soft-rule)
#v(0.8em)

#grid(
  columns: (1fr, 1fr),
  gutter: 2.2em,
  [
    #text(weight: "bold", fill: navy)[Objetivo del estudio] \
    #v(0.25em)
    Estimar el conteo de techos, su superficie útil y el potencial fotovoltaico en los territorios priorizados para la transición energética justa en Colombia.
  ],
  [
    #text(weight: "bold", fill: navy)[Enfoque de ingeniería] \
    #v(0.25em)
    Canalización reproducible sobre *MongoDB 9.0* que cruza el MGN 2025 del DANE con dos inventarios satelitales globales (*Microsoft* y *Google V3*).
  ],
)

// ─────────────────────────────────────────────────────────────────────────────
// 4. ARQUITECTURA NOSQL — MONGODB 9.0
// ─────────────────────────────────────────────────────────────────────────────
== Arquitectura NoSQL — MongoDB 9.0

#grid(
  columns: (0.95fr, 1.25fr),
  gutter: 1.8em,
  [
    #text(weight: "bold", fill: navy)[Modelo documental (`upme_pdet`)]
    #v(0.3em)
    - `municipalities_pdet`: 170 polígonos MGN 2025
    - `buildings_microsoft`: 1.761.047 huellas (`EPSG:9377`)
    - `buildings_google`: 2.694.786 centroides + confianza
    - `solar_aggregations`: 170 documentos materializados

    #v(0.7em)
    #note-rule(
      [Separación de CRS:],
      [Almacenamiento e indexación `2dsphere` en `EPSG:4326`; cálculo métrico oficial en `EPSG:9377`.],
      accent: blue,
    )
  ],
  [
    #text(weight: "bold", fill: navy)[Auditoría de planes `explain` (100 % `IXSCAN`)]
    #v(0.3em)
    #set text(size: 0.72em)
    #table(
      columns: (1.25fr, 1.25fr, auto, auto),
      align: (left, left, center, right),
      [*Consulta*], [*Índice*], [*Plan*], [*Tiempo*],
      [`municipalities_pdet` (`$geoIntersects`)], [`geometry_2dsphere`], [`IXSCAN`], [10 ms],
      [`buildings_microsoft` (`$geoIntersects`)], [`geometry_2dsphere`], [`IXSCAN`], [1 ms],
      [`buildings_google` (`$geoWithin` 1 km)], [`centroid_2dsphere`], [`IXSCAN`], [53 ms],
      [`buildings_microsoft` (`mpio + area`)], [`mpio_area`], [`IXSCAN`], [39 ms],
      [`solar_aggregations` (Top 10)], [`idx_solar_rank`], [`IXSCAN`], [1 ms],
    )
  ],
)

// ─────────────────────────────────────────────────────────────────────────────
// 5. INTEGRACIÓN TERRITORIAL E INGESTA MASIVA
// ─────────────────────────────────────────────────────────────────────────────
== Integración Territorial e Ingesta Masiva

#set text(size: 0.85em)
#table(
  columns: (1.1fr, 1.0fr, 1.6fr, 0.8fr, 1.1fr),
  align: (left, right, left, right, left),
  [*Colección*], [*Documentos*], [*Estrategia de carga*], [*Tiempo*], [*Validación*],
  [`municipalities_pdet`], [170], [Normalización DANE + geometría 2D válida], [≈ 20 s], [170/170 `$geoIntersects`],
  [`buildings_microsoft`],
  [1.761.047],
  [Prefiltrado bbox · lotes 5.000 · `ordered=False`],
  [≈ 30 min],
  [Índices post-carga],

  [`buildings_google`],
  [2.694.786],
  [8 teselas S2 nivel 4 · multiproceso idempotente],
  [≈ 18 min],
  [Control `etl_processed_files`],
)

#v(0.9em)
#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.5em,
  stat([< 620 MiB], [Almacenamiento en disco], detalle: [Compresión WiredTiger para 4,45 M docs]),
  stat([78–91 %], [Descarte temprano], detalle: [Filtrado espacial previo a inserción], accent: blue),
  stat([30 s], [Re-cálculo completo], detalle: [Pipelines nativos + `$percentile` en MongoDB], accent: forest),
)

// ─────────────────────────────────────────────────────────────────────────────
// 6. EDA — CONTEO VS. ÁREA Y BRECHA EN CHOCÓ
// ─────────────────────────────────────────────────────────────────────────────
== EDA — Conteo vs. Área y Cobertura Territorial

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #stat([+53,0 %], [Más edificaciones en Google], detalle: [2,69 M vs. 1,76 M estructuras], accent: blue)
    #v(0.5em)
    - Área media Google: *82,8 m²* (segmenta micro-techos contiguos)
    - Área media Microsoft: *125,6 m²* (agrupa cubiertas vecinas)
  ],
  [
    #stat([0,85 %], [Diferencia global de área], detalle: [223,01 km² vs. 221,13 km²], accent: forest)
    #v(0.5em)
    - Brecha neta de solo *1,88 km²* sobre todo el universo PDET
    - Valida la consistencia física entre ambos sensores
  ],
)

#v(1.0em)
#note-rule(
  [Hallazgo crítico en Chocó:],
  [Google Open Buildings V3 reporta *cero detecciones en 5 municipios* (Bojayá, Vigía del Fuerte, Medio San Juan, Nóvita y Murindó) por nubosidad ecuatorial persistente. El respaldo de Microsoft recupera *8.079 edificaciones* (73,9 ha · 59,1 MWp).],
  accent: crimson,
)

// ─────────────────────────────────────────────────────────────────────────────
// 7. VALIDACIÓN CRUZADA INTER-FUENTE
// ─────────────────────────────────────────────────────────────────────────────
== Validación Cruzada Inter-Fuente (n = 165)

#align(center)[
  #image("../reports/figures/06_ms_vs_google_correlation.png", width: 100%, height: 9.6cm, fit: "contain")
]

#v(0.3em)
#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 1.2em,
  stat([$r = 0,985$], [Correlación Pearson], detalle: [$R^2 = 0,971$ en área municipal]),
  stat([$rho = 0,938$], [Correlación Spearman], detalle: [Consistencia de ranking], accent: blue),
  stat([14,8 %], [Discrepancia mediana], detalle: [58,8 % dentro de banda ±20 %], accent: forest),
  stat([1,40×], [Razón mediana conteo], detalle: [Google / Microsoft por mpio], accent: amber),
)

// ─────────────────────────────────────────────────────────────────────────────
// 8. CONFIANZA SATELITAL Y FILTROS DE CALIDAD
// ─────────────────────────────────────────────────────────────────────────────
== Confianza Satelital y Estabilidad ante Filtros (`RN-04` / `RN-05`)

#align(center)[
  #image("../reports/figures/08_google_confidence_and_filters.png", width: 100%, height: 10.6cm, fit: "contain")
]

#v(0.2em)
#align(center)[
  #text(size: 0.84em, fill: muted)[
    El *80,85 %* del área en Google supera confianza `0,75`; el filtro plausible `10–20.000 m²` retiene *> 99,7 %* de la superficie en ambas fuentes.
  ]
]

// ─────────────────────────────────────────────────────────────────────────────
// 9. MAPA COMPARATIVO DE ÁREA DE CUBIERTAS
// ─────────────────────────────────────────────────────────────────────────────
== Distribución Espacial — Área de Techos (Microsoft vs. Google)

#align(center)[
  #image("../reports/figures/01_map_pdet_rooftop_area.png", width: 100%, height: 11.4cm, fit: "contain")
]

#align(center)[
  #text(size: 0.82em, fill: muted)[
    Correspondencia espacial en todo el país y visibilización de los 5 municipios sin inferencia en Google (achurado rojo en Chocó / Antioquia).
  ]
]

// ─────────────────────────────────────────────────────────────────────────────
// 10. CONSENSO HÍBRIDO Y MAPA DE POTENCIAL SOLAR
// ─────────────────────────────────────────────────────────────────────────────
== Consenso Híbrido y Potencial Solar Fotovoltaico

#grid(
  columns: (1.05fr, 1fr),
  gutter: 1.6em,
  align: (center + horizon, left + horizon),
  image("../reports/figures/02_map_pdet_solar_potential.png", width: 100%, height: 12.1cm, fit: "contain"),
  [
    #text(weight: "bold", fill: navy)[Regla de consenso híbrido] \
    - 165 mpios con doble fuente: media aritmética MS–Google
    - 5 mpios de Chocó sin Google: respaldo Microsoft (*170/170* cobertura)

    #v(0.55em)
    #text(weight: "bold", fill: navy)[Parámetros conservadores] \
    $A_"útil" = A_"consenso" times 40 % quad ("88,97 km"^2)$ \
    $P = A_"útil" times "0,20 kWp/m"^2$ \
    $E = P times "1.450 kWh/kWp" dot "año"$

    #v(0.7em)
    #grid(
      columns: (1fr, 1fr),
      gutter: 1.1em,
      stat([17,79 GWp], [Capacidad técnica], accent: amber, value-size: 1.32em),
      stat([25,80 TWh/año], [Generación ref.], accent: forest, value-size: 1.32em),
    )
  ],
)

// ─────────────────────────────────────────────────────────────────────────────
// 11. DESAGREGACIÓN POR SUBREGIONES PDET
// ─────────────────────────────────────────────────────────────────────────────
== Balance Comparativo en las 16 Subregiones PDET

#align(center)[
  #image("../reports/figures/04_subregions_comparison.png", width: 100%, height: 11.3cm, fit: "contain")
]

#align(center)[
  #text(size: 0.82em, fill: muted)[
    *Sierra Nevada – Perijá* (`50,01 km²`) y *Alto Patía – Norte del Cauca* (`30,65 km²`) lideran la superficie construida; *Chocó* y *Sur del Tolima* reflejan mayor sesgo relativo.
  ]
]

// ─────────────────────────────────────────────────────────────────────────────
// 12. TOP 15 MUNICIPIOS PRIORITARIOS
// ─────────────────────────────────────────────────────────────────────────────
== Top 15 Municipios PDET Prioritarios

#align(center)[
  #image("../reports/figures/05_top15_municipalities.png", width: 100%, height: 11.4cm, fit: "contain")
]

#align(center)[
  #text(size: 0.82em, fill: muted)[
    *Santa Marta* (`1.210 MWp`), *Valledupar* (`1.156 MWp`), *Buenaventura* (`593 MWp`), *Florencia* (`562 MWp`) y *Turbo* (`428 MWp`) encabezan el portafolio.
  ]
]

// ─────────────────────────────────────────────────────────────────────────────
// 13. CONCENTRACIÓN ESPACIAL — CURVA DE PARETO
// ─────────────────────────────────────────────────────────────────────────────
== Concentración Espacial — Curva de Pareto

#align(center)[
  #image("../reports/figures/09_pareto_concentration.png", width: 100%, height: 9.6cm, fit: "contain")
]

#v(0.3em)
#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 1.2em,
  stat([0,517], [Índice de Gini], detalle: [Alta concentración territorial]),
  stat([30,5 %], [Top 10 municipios], detalle: [Más de un cuarto en 10 ciudades], accent: blue),
  stat([27 mpios], [50 % del potencial], detalle: [15,9 % del universo PDET], accent: forest),
  stat([78 mpios], [80 % del potencial], detalle: [Base para despliegue gradual], accent: amber),
)

// ─────────────────────────────────────────────────────────────────────────────
// 14. RECOMENDACIONES PARA LA UPME
// ─────────────────────────────────────────────────────────────────────────────
== Hoja de Ruta y Recomendaciones para la UPME

#v(0.4em)
#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.8em,
  [
    #block(width: 100%, inset: (top: 0.5em), stroke: (top: 2.5pt + navy))[
      #text(weight: "bold", fill: navy)[Horizonte 1 · Pilotos PoC]
      #v(0.35em)
      - *Top 10 municipios* (30,5 % del área)
      - Techos públicos, colegios y comercio en Santa Marta, Valledupar y Buenaventura
      - Incorporar irradiancia GHI local (IDEAM)
    ]
  ],
  [
    #block(width: 100%, inset: (top: 0.5em), stroke: (top: 2.5pt + blue))[
      #text(weight: "bold", fill: blue)[Horizonte 2 · Escala Regional]
      #v(0.35em)
      - *Top 27 municipios* (50 % del área)
      - Polos agroindustriales en Cauca, Caquetá, Arauca y Putumayo
      - Cruce con subestaciones SIN y catastro IGAC
    ]
  ],
  [
    #block(width: 100%, inset: (top: 0.5em), stroke: (top: 2.5pt + amber))[
      #text(weight: "bold", fill: amber)[Horizonte 3 · Equidad ZNI]
      #v(0.35em)
      - *Chocó, Pacífico y Sur del Tolima*
      - Microrredes de `50–500 kWp` para sustituir generación diésel
      - Mantener política de doble fuente satelital
    ]
  ],
)

// ─────────────────────────────────────────────────────────────────────────────
// 15. CONCLUSIONES
// ─────────────────────────────────────────────────────────────────────────────
== Conclusiones

#v(0.3em)
#grid(
  columns: (1fr, 1pt, 1fr),
  gutter: 1.8em,
  [
    #text(weight: "bold", fill: forest, size: 1.05em)[Ingeniería y Reproducibilidad NoSQL]
    #v(0.4em)
    - *4,45 M* de huellas integradas y validadas en MongoDB 9.0 (`< 620 MiB`)
    - Consultas `IXSCAN` al 100 % en *1–53 ms*
    - Flujo determinístico de punta a punta (`./reproduce.sh`, SHA-256 verificado)
    - Código modular y gráficas extensibles (`workflow/`)
  ],
  line(angle: 90deg, length: 7.5cm, stroke: 0.6pt + soft-rule),
  [
    #text(weight: "bold", fill: navy, size: 1.05em)[Aporte Estratégico para la UPME]
    #v(0.4em)
    - Inventario consolidado de *222,44 km²* de cubiertas (`170/170` municipios)
    - Potencial técnico estimado de *17,79 GWp* y *25,80 TWh/año*
    - Convergencia sólida entre sensores ($r = 0,985$; Δ global `0,85 %`)
    - Rescate satelital del Chocó evitando exclusión territorial
  ],
)

#v(1.2em)
#line(length: 100%, stroke: 0.6pt + soft-rule)
#v(0.4em)
#grid(
  columns: (1fr, auto),
  align: (left + horizon, right + horizon),
  [#text(weight: "bold", fill: navy)[Muchas gracias · Sesión de preguntas]],
  [#link("https://github.com/Achalogy/dba-proj-20263")[#text(
    size: 0.85em,
    fill: blue,
  )[github.com/Achalogy/dba-proj-20263]]],
)
