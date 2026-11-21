#set page(paper: "a4", margin: 2.5cm)
#set text(font: "Times New Roman", size: 12pt, lang: "es")
#set par(justify: true)

#align(center)[
  #v(2cm)
  #image("../assets/logo.png", width: 25%)
  #v(1cm)

  #text(size: 18pt, weight: "bold")[
    FINAL PROJECT: \
    Reproducible Geospatial Analysis Workflow (Rooftop Count and Area Estimation)
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

  #v(3cm)

  Pontificia Universidad Javeriana \
  Bogotá D.C. \
  2026
]

#pagebreak()
#set page(numbering: "1")
#set heading(numbering: "1.1")

#outline(depth: 3)

#pagebreak()

= Introducción

Este entregable corresponde a la Fase 4 (Semana 4) del proyecto final de Administración de Bases de Datos para la *Unidad de Planeación Minero Energética (UPME)*. Con la infraestructura NoSQL de *MongoDB 9.0* poblada e indexada espacialmente con los 170 municipios PDET y los *4.455.833 registros de edificaciones* provenientes de Microsoft Building Footprints y Google Open Buildings V3, esta fase diseña, ejecuta y verifica el *flujo de análisis geoespacial reproducible* encargado de estimar el conteo de techos, el área total de cubiertas y el potencial solar fotovoltaico por municipio, subregión y departamento.

El documento se estructura en dos bloques principales: (1) la arquitectura modular del paquete `workflow/`, la metodología de agregación, consenso híbrido multi-fuente, auditoría de índices `2dsphere`, verificación determinística (`SHA-256`) y comandos de reproducción; y (2) el esquema de salida materializado en `solar_aggregations`, los artefactos abiertos (`JSON`, `CSV`, `GeoJSON`) y el análisis completo de resultados soportado por 9 visualizaciones cartográficas y estadísticas.

#pagebreak()
#include "../docs/8-reproducibility_and_methodology.typ"
#pagebreak()
#include "../docs/9-output_data_structure.typ"
#pagebreak()

= Conclusiones de la Fase 4

+ *Reproducibilidad determinística verificada:* El flujo `src/5-geospatial_workflow/` se ejecuta en ≈ 30 segundos sobre 4,45 millones de documentos en MongoDB 9.0, supera las 5 auditorías `explain` mediante planes `IXSCAN` (1–53 ms) y genera resultados bit a bit idénticos verificados mediante el hash `SHA-256` (`312d57042a237291...`).
+ *Convergencia multi-fuente y cobertura territorial completa:* Pese a que Google detecta un 53 % más de polígonos individuales que Microsoft, la discrepancia global en superficie total es de solo *0,85 %* (`223,01 km²` vs. `221,13 km²`, $r = 0,9853$). El consenso híbrido recupera los 5 municipios selváticos del Chocó omitidos por Google, garantizando cobertura en los 170 municipios PDET (`222,44 km²`).
+ *Magnitud y focalización del potencial solar:* Bajo supuestos técnicos conservadores ($f_u = 40%$, $rho = 0,20 "kWp/m"^2$, $Y = 1.450 "kWh/kWp" dot "año"$), los territorios PDET ofrecen un potencial técnico estimado de *17,79 GWp* y *25,80 TWh/año*, con una concentración de Gini `0,5174` donde 27 municipios concentran el 50 % del potencial nacional PDET.
+ *Plataforma modular, abierta y extensible:* La arquitectura desacoplada en `workflow/` (`config`, `mongo_pipelines`, `metrics`, `summary`, `spatial_audit`, `exporters`) y el registro extensible `@register_chart` en `workflow/charts/` dejan el sistema preparado para incorporar nuevas métricas, parámetros de irradiancia municipal y visualizaciones adicionales sin modificar el núcleo de la base de datos.
