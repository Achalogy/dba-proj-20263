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

El presente informe consolida los resultados y avances alcanzados durante la *Semana 2* del proyecto final de la asignatura *Administración de Bases de Datos*, titulado *"PDET Municipality Boundaries Dataset Integration"*. Este proyecto se desarrolla en el marco de la iniciativa estratégica de la Oficina de Investigaciones e Información de la *Unidad de Planeación Minero Energética (UPME)*, cuyo propósito fundamental es estimar el potencial de energía solar en cubiertas y techos de edificaciones a lo largo del territorio colombiano, priorizando de manera estricta los *170 municipios* focalizados por los Programas de Desarrollo con Enfoque Territorial (PDET).

El objetivo central de este segundo entregable es materializar la capa base territorial del proyecto en una solución de base de datos NoSQL documental (*MongoDB*), asegurando la delimitación precisa de los municipios PDET mediante la integración de fuentes oficiales abiertas y la implementación de mecanismos robustos de indexación y consulta espacial. Para cumplir con esta meta, el trabajo se estructuró en tres ejes metodológicos:

+ *Adquisición y Verificación de Datos:* Descarga formal del *Marco Geoestadístico Nacional (MGN2025)* del Departamento Administrativo Nacional de Estadística (DANE) y desarrollo de pipelines de auditoría para verificar la correspondencia biunívoca entre la capa cartográfica oficial y el catálogo maestro de 170 municipios PDET (`data/MunicipiosPDET.xlsx`), asegurando integridad de geometrías y consistencia de áreas.
+ *Integridad y Formato de Datos:* Diseño e implementación de algoritmos de normalización de identificadores DANE (códigos a 5 y 2 dígitos con relleno de ceros), reproyección geodésica a WGS84 (`EPSG:4326`), simplificación topológica (fuerza 2D y remoción de vértices redundantes), serialización GeoJSON y control estricto de restricciones BSON (< 16 MB), exportando respaldos estructurados en NDJSON.
+ *Integración Espacial NoSQL:* Despliegue de una instancia local contenerizada de MongoDB mediante Docker Compose, carga masiva idempotente de colecciones, construcción de índices espaciales esféricos `2dsphere` y ejecución de pruebas de validación topológica automatizadas mediante consultas `$geoIntersects` y análisis de planes de ejecución (`explain`).

Todo el flujo de trabajo está orquestado a través del gestor moderno de paquetes y entornos *`uv`*, garantizando aislamiento, reproducibilidad determinística y compatibilidad multiplataforma.

#pagebreak()
#include "../docs/3-data_acq_and_verification.typ"
#pagebreak()
#include "../docs/4-data_integrity_and_format.typ"
#pagebreak()
#include "../docs/5-nosql_spatial_integration.typ"

#pagebreak()
= Conclusiones y Trabajo Futuro

La culminación de la Fase 2 establece con éxito los cimientos geoespaciales y de persistencia NoSQL requeridos para el análisis de potencial solar de la UPME. A partir de los resultados empíricos obtenidos en las etapas de adquisición, formato e integración espacial, se formulan las siguientes conclusiones:

+ *Integridad y Cobertura Territorial Total:* Se logró una correspondencia perfecta del 100 % (170 de 170 municipios PDET) entre el catálogo oficial del proyecto y la capa cartográfica municipal del DANE (MGN2025). La auditoría topológica confirmó la ausencia de geometrías nulas o autointersecadas y una coincidencia exacta (0,0 % de desviación) entre las áreas geométricas calculadas bajo la proyección oficial colombiana (`EPSG:9377`) y las áreas oficiales reportadas.
+ *Estandarización y Robustez Documental:* El pipeline de ingesta resolvió con éxito las disparidades toponímicas y la pérdida de ceros iniciales en identificadores DANE, encapsulando cada territorio en documentos BSON conformes al estándar GeoJSON en coordenadas WGS84 (`EPSG:4326`), con tamaños que no superan el 50 % del límite estructural de MongoDB (16 MB).
+ *Efectividad de la Indexación Espacial Esférica (`2dsphere`):* La creación exitosa del índice `geometry_2dsphere` validó la rigidez topológica de los polígonos sobre la esfera. La prueba de validación espacial automatizada alcanzó una efectividad del 100 % (170 / 170 aciertos) utilizando puntos interiores generados mediante `shapely.point_on_surface`, eliminando falsos negativos y traslapes limítrofes.
+ *Eficiencia en Almacenamiento y Complejidad de Búsqueda:* La inspección de planes de ejecución (`explain`) demostró que las consultas de intersección espacial operan exclusivamente bajo escaneos de índice (`IXSCAN` en ~7 ms), descartando escaneos lineales (`COLLSCAN`). Asimismo, el motor WiredTiger evidenció una tasa de compresión en disco cercana al 50 % (de ~50 MB lógicos a ~27 MB físicos), manteniendo los índices en memoria RAM con un costo de apenas 124 KB.
+ *Reproducibilidad Operativa con `uv` y Docker:* La combinación de Docker Compose para la base de datos y `uv` para la orquestación del entorno de Python garantiza que cualquier evaluador pueda recrear el pipeline de datos de inicio a fin con un solo comando y resultados determinísticos.

== Hacia la Fase 3: Integración de Huellas de Edificaciones

Con la capa de límites municipales PDET indexada y operativa en MongoDB, el proyecto queda preparado para abordar la *Fase 3 (Semana 3)*, cuyos objetivos inmediatos son:
- Adquisición masiva y particionamiento de datasets abiertos de huellas de edificaciones satelitales (*Microsoft Building Footprints* y *Google Open Buildings V3*).
- Implementación de estrategias de carga por lotes (*batch bulk loading*) desordenadas para optimizar la inserción de millones de polígonos.
- Indexación espacial `2dsphere` sobre las colecciones de edificaciones y Análisis Exploratorio de Datos (EDA) comparativo entre ambas fuentes satelitales.
