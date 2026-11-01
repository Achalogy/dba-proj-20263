#set page(paper: "a4", margin: 2.5cm)
#set text(font: "Times New Roman", size: 12pt, lang: "es")
#set par(justify: true)

#align(center)[
  #v(2cm)
  #image("../assets/logo.png", width: 25%)
  #v(1cm)

  #text(size: 18pt, weight: "bold")[
    FINAL PROJECT: \
    PDET Municipality Boundaries Dataset Integration
  ]

  #v(1.5cm)

  Juliana Sofía Novoa Solano \
  Juan Santiago Saavedra Holguin \
  Juan Garzón Tinjaca \
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

#outline()

#include "../docs/3-data_acq_and_verification.typ"
#include "../docs/4-data_integrity_and_format.typ"
#include "../docs/5-nosql_spatial_integration.typ"