#set page(paper: "a4", margin: 2.5cm)
#set text(font: "Times New Roman", size: 12pt, lang: "es")
#set par(justify: true)

#align(center)[
  #v(2cm)
  #image("../assets/logo.png", width: 25%)
  #v(1cm)

  #text(size: 18pt, weight: "bold")[
    FINAL PROJECT: \
    Building Footprint Data Loading and Integration
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

#outline()

#pagebreak()
= Introducción

El presente informe consolida los resultados correspondientes a la *Semana 3* del proyecto final de *Administración de Bases de Datos*, titulado *"Building Footprint Data Loading and Integration"*, en apoyo al estudio de la Oficina de Investigaciones e Información de la *Unidad de Planeación Minero Energética (UPME)* para estimar el potencial solar en cubiertas de edificaciones dentro de los *170 municipios PDET* de Colombia.

A partir de la capa territorial municipal indexada en la Semana 2 (`municipalities_pdet` en MongoDB), este entregable extiende la arquitectura NoSQL incorporando, validando y comparando dos fuentes abiertas globales de detección satelital de edificaciones: *Microsoft Building Footprints* y *Google Open Buildings V3*. Concretamente, el informe documenta:

+ *Adquisición, verificación, formato e integración espacial NoSQL* aplicados a ambos conjuntos de huellas de edificaciones, manteniendo la consistencia del CRS (`EPSG:4326`), la normalización de códigos DANE (`cod_dane_mpio`), la limpieza topológica e índices `2dsphere` verificados con planes de ejecución (`explain`).
+ *Eficiencia en la carga masiva de datos (Data Loading Efficiency):* Estrategias de procesamiento incremental, prefiltrado geoespacial temprano, multiprocesamiento, inserción por lotes desordenada (`ordered=False`), construcción diferida de índices y experimentos comparativos de rendimiento.
+ *Análisis Exploratorio de Datos (Brief EDA):* Caracterización estadística comparativa de los *4.455.833 registros* cargados (1,76 M de Microsoft y 2,69 M de Google), distribución por tamaños de techo, niveles de confianza, cobertura municipal y hallazgos por subregiones PDET.

#pagebreak()
#include "../docs/3-data_acq_and_verification.typ"
#pagebreak()
#include "../docs/4-data_integrity_and_format.typ"
#pagebreak()
#include "../docs/5-nosql_spatial_integration.typ"
#pagebreak()
#include "../docs/6-data_loading_efficiency.typ"
#pagebreak()
#include "../docs/7-eda.typ"

#pagebreak()
= Conclusiones y Trabajo Futuro

La culminación de la Fase 3 deja completamente integrados, indexados y caracterizados los dos conjuntos masivos de huellas de edificaciones sobre la base de datos MongoDB `upme_pdet`:

+ *Cumplimiento integral de calidad e indexación espacial:* Tanto `buildings_microsoft` (1.761.047 polígonos) como `buildings_google` (2.694.786 centroides) cuentan con índices esféricos `2dsphere` e índices compuestos `mpio_area` operativos. Las auditorías con `explain("executionStats")` confirman consultas espaciales y analíticas en el orden de 17 a 128 ms mediante `IXSCAN`.
+ *Efectividad de las técnicas de carga masiva:* El filtrado territorial previo a la inserción (descartando 78,6 % en Microsoft y 91,4 % en Google), el procesamiento por bloques/archivos (pico de 763 MB de RAM en Microsoft y carga paralela de 1,59 min en Google), los lotes desordenados y la creación de índices al final permitieron ingerir más de 4,45 millones de documentos con cero errores de inserción.
+ *Convergencia macro y complementariedad entre fuentes:* Aunque Google detecta 1,53× más estructuras que Microsoft (2,69 M vs. 1,76 M), ambas fuentes convergen notablemente en el área total estimada de techos en territorios PDET (*223,01 km²* en Google frente a *221,13 km²* en Microsoft, una diferencia de apenas *0,85 %*). No obstante, Microsoft cubre el *100 %* de los 170 municipios mientras Google omite *5 municipios* de selva húmeda en Antioquia y Chocó, por lo que combinar ambas fuentes resulta clave para el análisis energético de la UPME.

== Hacia la Fase 4: Flujo Geoespacial Reproducible y Reporte Final

Con las colecciones `municipalities_pdet`, `buildings_microsoft` y `buildings_google` validadas y optimizadas, el proyecto queda preparado para la *Semana 4*, enfocada en:
- Ejecutar los pipelines reproducibles de agregación para construir `solar_aggregations` aplicando filtros de área útil (`RN-05`) y umbrales de confianza.
- Generar las tablas finales de estimación fotovoltaica y los mapas coropléticos por municipio y subregión PDET.
- Consolidar el Informe Técnico Final y preparar la sustentación.
