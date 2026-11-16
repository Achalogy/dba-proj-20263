= Adquisición y Verificación de Datos (Data Acquisition & Verification)

== Qué datos se necesitaban

El proyecto trabaja solo con los 170 municipios PDET. Para saber dónde queda cada uno hacen falta dos cosas: la lista oficial de municipios PDET (`data/MunicipiosPDET.xlsx`, entregada con el enunciado) y los límites de cada municipio, que publica el DANE en el *Marco Geoestadístico Nacional (MGN)*. Posteriormente, para la Fase 3 se incorporan los dos conjuntos abiertos de huellas de edificaciones seleccionados: *Microsoft Building Footprints* y *Google Open Buildings V3*. Esta sección explica de dónde salió cada fuente, cómo se descargó y qué revisiones de calidad se ejecutaron antes de su persistencia.

== Fuente y descarga del Marco Geoestadístico Nacional (MGN)

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
  caption: [Resumen de las fuentes de datos territoriales (DANE MGN y catálogo PDET).],
)

El archivo ZIP trae muchas carpetas (zona urbana, zona rural, vías, símbolos) y documentos del DANE: el diccionario de datos, el catálogo de objetos, la especificación técnica y el informe de calidad. Para este proyecto solo se necesita la capa de municipios; el resto no se usa.

Como el archivo pesa varios gigabytes, *no se sube a GitHub*. Se guarda en la carpeta `data/raw/`, que está excluida del repositorio con `.gitignore`. Quien quiera repetir el trabajo debe descargar el mismo archivo desde el enlace de arriba y descomprimirlo en esa carpeta.

== Revisiones de calidad del MGN

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

== Adquisición y Verificación de Huellas de Edificaciones (Microsoft y Google)

Para la Fase 3 se aplicaron los mismos principios de adquisición trazable y control de calidad sobre los dos conjuntos satelitales abiertos seleccionados: *Microsoft Building Footprints* y *Google Open Buildings V3*. Al igual que el MGN, los archivos crudos descargados quedan excluidos de GitHub mediante `.gitignore`.

=== Microsoft Building Footprints

*Mecanismo de descarga.* El script `src/3-buildings-microsoft/load_microsoft.py` lee el catálogo maestro `dataset-links.csv` (distribuido por Microsoft Planetary Computer / Global Building Footprints bajo licencia ODbL-1.0), filtra los registros con `Location == "Colombia"` y ordena las *232 teselas (`QuadKey`)* resultantes. Cada tesela se descarga de forma automatizada e idempotente en `data/raw/microsoft/colombia/{quadkey}.csv.gz` (GeoJSON Lines comprimido con gzip) escribiendo primero en un archivo temporal `.part` para evitar archivos corruptos si la descarga se interrumpe. El volumen total descargado para Colombia es de *0,63 GB comprimidos*.

*Revisiones de calidad.* Antes de insertar en MongoDB, el pipeline ejecuta automáticamente las siguientes validaciones sobre los *8.221.407 edificios* leídos en las 232 teselas:
+ *Normalización de `QuadKey`:* Relleno a 9 dígitos con ceros a la izquierda (`zfill(9)`), corrigiendo entradas como `32203213` $arrow.r$ `032203213`.
+ *Validez topológica y tipo geométrico:* Se aplica redondeo de precisión (`1e-7` grados) y reparación con `shapely.make_valid` cuando aparecen polígonos dañados (como un polígono inválido detectado cerca de Santa Marta). Posteriormente se filtra por `is_valid`, `~is_empty` y tipo `Polygon` / `MultiPolygon`. Resultado: *0 geometrías descartadas*.
+ *Valores centinela en atributos:* El campo `height` viene codificado como `-1` cuando Microsoft no dispone de estimación de altura para Colombia; dicho valor se normaliza a `null` (`None`) para evitar distorsiones estadísticas.
+ *Filtrado territorial y cobertura:* El cruce por centroide (`within`) contra los 170 municipios PDET descarta 6.460.360 huellas fuera del área de estudio (78,6 %) y retiene *1.761.047 edificaciones*, logrando cobertura en *170 de 170 municipios PDET (100 %)*.

=== Google Open Buildings V3

*Mecanismo de descarga.* La adquisición se realiza de forma selectiva en dos pasos para evitar descargar las teselas de todo el continente:
+ `src/3-google_open_buildings/generate_pdet_union.py` disuelve los 170 polígonos de `municipalities_pdet.ndjson` en una frontera única (`data/google_open_buildings/boundaries/pdet_union.geojson`).
+ `src/3-google_open_buildings/download_pdet_buildings.py` consulta el índice oficial de teselas S2 de nivel 4 (`https://storage.googleapis.com/open-buildings-data/v3/score_thresholds_s2_level_4.csv`), parsea las geometrías WKT de cada celda y descarga en streaming únicamente las *8 teselas S2* que intersecan la frontera PDET (`polygons_s2_level_4_gzip/{s2_token}_buildings.csv.gz`), guardándolas en `data/google_open_buildings/raw/`.

*Revisiones de calidad.* Durante la ingesta en `src/3-google_open_buildings/importer.py` y el análisis posterior (`reports/eda_results.json`), se verificaron los siguientes aspectos sobre las *31.499.115 filas* leídas:
+ *Integridad de coordenadas y campos numéricos:* Se leen las columnas esenciales (`latitude`, `longitude`, `confidence`, `area_in_meters`), descartando cualquier fila con `latitude` o `longitude` nulos (`dropna`) y convirtiendo `NaN` en `area_in_meters` o `confidence` a `null` (`None`).
+ *Verificación de dominios:* Las estadísticas registradas confirman valores consistentes sin ceros espurios ni desbordamientos: `confidence` en el rango `[0,6500; 0,9834]` (media `0,7796`) y `rooftop_area_m2` en `[2,51; 20.916,70]` m².
+ *Filtrado espacial y cobertura:* El prefiltro por caja envolvente y la verificación exacta con `shapely.contains_xy` + cruce municipal retuvieron *2.694.786 edificaciones PDET (8,6 %)* y descartaron el 91,4 % exterior. La auditoría de cobertura evidenció presencia en *165 de 170 municipios*, identificando 5 municipios del Pacífico/Chocó (`05475` Murindó, `05873` Vigía del Fuerte, `27450` Medio San Juan, `27491` Nóvita y `27099` Bojayá) sin detecciones en las teselas descargadas por nubosidad y cobertura selvática densa.
+ *Licencia:* Google distribuye Open Buildings V3 bajo `CC-BY-4.0 / ODbL-1.0`, etiqueta registrada en `capture_metadata.license` dentro de `importer.py`.

#figure(
  text(size: 9.8pt)[
    #table(
      columns: (1.3fr, 1.4fr, 1.5fr, 1.5fr),
      align: (left, left, left, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Aspecto*], [*DANE MGN2025*], [*Microsoft Buildings*], [*Google Open Buildings V3*],
      [Mecanismo de descarga],
      [Manual (ZIP ~3,2 GB)],
      [Script automático (`dataset-links.csv`, 232 `.csv.gz`, 0,63 GB)],
      [Descarga selectiva por intersección con `pdet_union.geojson` (8 teselas S2 `.csv.gz`)],

      [Registros leídos], [1.122 municipios], [8.221.407 huellas], [31.499.115 detecciones],
      [Registros PDET válidos], [170 municipios], [1.761.047 huellas (21,4 %)], [2.694.786 centroides (8,6 %)],
      [Cobertura PDET], [170 / 170 (100 %)], [170 / 170 (100 %)], [165 / 170 (97,1 %)],
      [Chequeo de calidad clave],
      [Unicidad DANE, validez geométrica, área `EPSG:9377`],
      [Reparación `make_valid` (0 descartados), `-1` $arrow.r$ `null`],
      [`dropna` lat/lon, rango `confidence >= 0.65`, `NaN` $arrow.r$ `null`],
    )
  ],
  caption: [Síntesis comparativa de adquisición y verificación de calidad entre las tres fuentes del proyecto.],
)

== Conclusión

Los tres conjuntos de datos fueron adquiridos de forma reproducible y sometidos a controles de calidad documentados: el MGN2025 del DANE delimita con exactitud los 170 municipios PDET sin errores geométricos; Microsoft aporta 1,76 millones de polígonos válidos con cobertura del 100 % de los municipios; y Google aporta 2,69 millones de detecciones validadas en confianza y área para 165 municipios, dejando documentadas las causas de los 5 municipios faltantes en el Pacífico.
