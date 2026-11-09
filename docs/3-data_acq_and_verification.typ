= Adquisición y Verificación de Datos (Data Acquisition & Verification)

== Qué datos se necesitaban

El proyecto trabaja solo con los 170 municipios PDET. Para saber dónde queda cada uno hacen falta dos cosas: la lista oficial de municipios PDET (`data/MunicipiosPDET.xlsx`, entregada con el enunciado) y los límites de cada municipio, que publica el DANE en el *Marco Geoestadístico Nacional (MGN)*. Esta sección explica de dónde salió el MGN, cómo se descargó y qué revisiones se le hicieron antes de usarlo.

== Fuente y descarga

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.3fr, 3fr),
      align: (left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Detalle*],
      [Fuente], [DANE, Marco Geoestadístico Nacional, versión MGN2025 (todos los niveles geográficos).],
      [Página de descarga],
      [#link(
        "https://geoportal.dane.gov.co/servicios/descarga-y-metadatos/datos-geoestadisticos/?cod=111",
      )[Geoportal del DANE, datos geoestadísticos]],

      [Fecha de descarga], [7 de noviembre de 2026, 8:28 p. m.],
      [Tamaño del archivo ZIP], [3 310 468 KB (unos 3,2 GB).],
      [Forma de descarga], [Manual, desde el navegador, con el botón de descarga de la página.],
      [Capa que se usa], [`MGN_ADM_MPIO_GRAFICO` (límites de los municipios), dentro de la carpeta `ADMINISTRATIVO`.],
      [Formato de la capa], [Shapefile, con 1.122 municipios en todo el país.],
      [Lista de municipios PDET], [`data/MunicipiosPDET.xlsx`: 170 municipios en 16 subregiones.],
    )
  ],
  caption: [Resumen de las fuentes de datos de esta etapa.],
)

El archivo ZIP trae muchas carpetas (zona urbana, zona rural, vías, símbolos) y documentos del DANE: el diccionario de datos, el catálogo de objetos, la especificación técnica y el informe de calidad. Para este proyecto solo se necesita la capa de municipios; el resto no se usa.

Como el archivo pesa varios gigabytes, *no se sube a GitHub*. Se guarda en la carpeta `data/raw/`, que está excluida del repositorio con `.gitignore`. Quien quiera repetir el trabajo debe descargar el mismo archivo desde el enlace de arriba y descomprimirlo en esa carpeta.

== Revisiones de calidad

Antes de usar los datos se revisaron con el programa (`src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py`), ejecutado de forma reproducible mediante el gestor `uv`:

```bash
uv run src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py --mgn data/MGN_ADM_MPIO_GRAFICO.shp
```

El programa solo lee los datos, no los modifica, y deja el resultado en `reports/mgn_verification.json`, así cualquiera puede repetir la revisión y obtener exactamente el mismo diagnóstico.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (1.6fr, 1.3fr, 2.4fr),
      align: (left, center, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Qué se revisó*], [*Resultado*], [*Qué significa*],
      [Municipios del MGN con código repetido], [0 de 1.122], [Cada municipio tiene un código único.],
      [Municipios PDET encontrados en el MGN], [170 de 170], [No falta ninguno y no sobra ninguno.],
      [Departamento del Excel igual al del MGN], [170 de 170], [Todos están en el departamento correcto.],
      [Nombre del Excel igual al del MGN], [164 de 170], [Seis nombres se escriben distinto (ver más abajo).],
      [Geometrías vacías o sin datos], [0 de 170], [Todos los municipios tienen su mapa.],
      [Geometrías inválidas], [0 de 170], [Los dibujos no tienen errores, no hay que repararlos.],
      [Área calculada igual al área oficial del DANE],
      [170 de 170],
      [Diferencia de 0,000 %, el mapa y el área oficial coinciden.],
    )
  ],
  caption: [Resultados de la revisión de calidad sobre los 170 municipios PDET.],
)

*Forma de los municipios.* De los 170 municipios, 168 son un solo polígono y 2 están formados por varias partes (por ejemplo, con islas o zonas separadas). Ambos casos son normales y la base de datos los acepta.

*Área.* Se calculó el área de cada municipio en la proyección oficial de Colombia (EPSG:9377) y se comparó con el área que publica el DANE. Salieron iguales. Por ejemplo, Apartadó da 535,35 km² en ambos casos y Argelia 776,46 km². Esto confirma que EPSG:9377 es la proyección correcta para medir áreas más adelante.

*Códigos.* En el Excel los códigos vienen como número, y los que empiezan en cero lo pierden (Apartadó aparece como 5045 en lugar de 05045). Son 24 de los 170. Para poder cruzar con el MGN, todos los códigos de municipio se completan a 5 dígitos con ceros a la izquierda.

*Nombres distintos.* Seis municipios se escriben distinto en el Excel y en el MGN. Los códigos sí coinciden, por eso el cruce se hace siempre *por código y nunca por nombre*.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (0.8fr, 1.6fr, 1.8fr),
      align: (center, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Código*], [*Nombre en el Excel*], [*Nombre en el MGN*],
      [19418], [López], [López de Micay],
      [19548], [Piendamó], [Piendamó - Tunía],
      [50711], [Vista Hermosa], [Vistahermosa],
      [70523], [San Antonio de Palmito], [Palmito],
      [70823], [Tolú Viejo], [San José de Toluviejo],
      [86573], [Leguízamo], [Puerto Leguízamo],
    )
  ],
  caption: [Municipios cuyo nombre es distinto entre el Excel y el MGN.],
)

== Conclusión

Los datos del DANE están completos y en buen estado para el proyecto: aparecen los 170 municipios PDET, ninguno tiene errores en su geometría y el área coincide con la oficial. Las únicas diferencias encontradas (ceros iniciales en los códigos y seis nombres escritos distinto) se resuelven cruzando por código completado a 5 dígitos. Con esto, los datos quedan listos para el siguiente paso: dejarlos en el formato que pide la base de datos y cargarlos.
