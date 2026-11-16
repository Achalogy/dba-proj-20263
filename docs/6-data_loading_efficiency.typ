= Data Loading Efficiency
== Edificios de Microsoft

=== Qué se cargó

Microsoft publica las huellas de los edificios de Colombia en 232 archivos comprimidos, uno por cada cuadro del mapa (llamado _quadkey_). En total pesan 0,63 GB comprimidos y traen 8.221.407 edificios. Como el proyecto solo trabaja con los 170 municipios PDET, antes de guardar cada edificio se revisa en qué municipio cae y se descarta si no es PDET.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1.3fr, 2.2fr),
      align: (left, right, left),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Valor*], [*Qué significa*],
      [Archivos de Colombia], [232], [Todos se descargaron y se leyeron.],
      [Edificios leídos], [8.221.407], [Todos los edificios de Colombia que publica Microsoft.],
      [Edificios fuera de PDET], [6.460.360 (78,6 %)], [Se descartan antes de guardar.],
      [Edificios guardados], [1.761.047 (21,4 %)], [Solo los de los 170 municipios PDET.],
      [Geometrías descartadas], [0], [Las dañadas se repararon, ninguna se perdió.],
      [Errores al insertar], [0], [Todos los edificios entraron sin problema.],
    )
  ],
  caption: [Resultado de la carga de Microsoft.],
)

=== Cómo se hizo la carga

Para que la carga fuera rápida y no gastara memoria de más, se usaron estas ideas:

- *Descartar lo que no sirve cuanto antes.* Casi cuatro de cada cinco edificios no son de municipios PDET, así que se dejan fuera antes de tocar la base de datos.
- *Un archivo a la vez.* Se lee, se procesa y se guarda cada archivo por separado. Así nunca se tienen los 8 millones de edificios en memoria. El pico fue de 763 MB.
- *Guardar por lotes.* Los edificios se envían a MongoDB en grupos de 5.000, en vez de uno por uno. El modo "sin orden" permite que un edificio con problema no detenga a los demás.
- *Crear los índices al final.* Los índices espaciales se construyen una sola vez, cuando ya están todos los datos.
- *Limpiar las geometrías.* Las coordenadas se redondean a 7 decimales (alrededor de 1 centímetro) y los polígonos dañados se reparan, porque el índice espacial no acepta mapas con errores.
- *No repetir descargas.* Los archivos ya bajados se reutilizan, y la carga completa se puede repetir: cada vez borra la colección y la vuelve a llenar, sin duplicar datos.

Cada edificio queda con su municipio (`cod_dane_mpio`), su área de techo en metros cuadrados (calculada en la proyección oficial EPSG:9377), su altura (vacía cuando Microsoft no la tiene), el cuadro de origen y los datos de la carga.

=== Cuánto tardó

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1fr, 1fr),
      align: (left, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Etapa*], [*Segundos*], [*Del total*],
      [Descargar los 232 archivos], [672], [27 %],
      [Leer los archivos], [898], [37 %],
      [Procesar (cruce con municipios y áreas)], [768], [31 %],
      [Guardar en MongoDB], [64], [3 %],
      [Crear los índices], [45], [2 %],
      [*Total*], [*2.447 (unos 41 min)*], [*100 %*],
    )
  ],
  caption: [Tiempo de la carga completa de Microsoft.],
)

Lo más importante de la tabla: *guardar en MongoDB es lo más rápido de todo* (unos 27.600 edificios por segundo). El tiempo se va en bajar, leer y procesar los archivos. Por eso, mejorar la carga depende más de cómo se leen y se preparan los datos que de la base de datos.

=== Pruebas de eficiencia

Para comparar opciones se cargaron los 5 archivos más pesados (1.499.624 edificios leídos, 96.727 guardados) cuatro veces, cambiando una sola cosa cada vez.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2.2fr, 1fr, 1fr, 1fr),
      align: (left, right, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Prueba*], [*Guardar (s)*], [*Índices (s)*], [*Guardar + índices (s)*],
      [Lotes de 1.000], [2,7], [2,9], [5,6],
      [Lotes de 5.000], [3,7], [2,7], [6,4],
      [Lotes de 10.000], [3,3], [2,6], [5,9],
      [Lotes de 5.000, índices antes de cargar], [6,5], [0,1], [6,6],
    )
  ],
  caption: [Comparación de opciones sobre los 5 archivos más pesados.],
)

Lo que se vio:

- *El tamaño del lote casi no cambia nada.* Con 1.000, 5.000 o 10.000 el tiempo de guardar y crear índices fue parecido (entre 5,6 y 6,4 segundos). Los tiempos totales de las corridas variaron más por la lectura de archivos (entre 103 y 182 segundos), que depende del computador en ese momento, no del lote. Se dejó 5.000 como valor por defecto.
- *Crear los índices antes de cargar hace más lenta la carga* (6,5 s contra 3,7 s con el mismo lote), porque MongoDB actualiza el índice con cada edificio que entra. Al sumar el tiempo de crear los índices, el total queda casi igual (6,6 s contra 6,4 s), así que con esta cantidad de datos la diferencia es pequeña. Se eligió crearlos al final porque es la práctica recomendada y el costo se paga una sola vez.
- *La memoria se mantuvo baja:* unos 490 MB con 5 archivos y 763 MB en la carga completa, sobre todo por los archivos más grandes.

=== Espacio que ocupa

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (2fr, 1.2fr),
      align: (left, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Dato*], [*Valor*],
      [Edificios guardados], [1.761.047],
      [Tamaño promedio de un edificio], [579 bytes],
      [Tamaño de los datos sin comprimir], [1.020 MB],
      [Espacio en disco (comprimido por MongoDB)], [260 MB],
      [Espacio de todos los índices], [117 MB],
    )
  ],
  caption: [Espacio que ocupa la colección `buildings_microsoft`.],
)

MongoDB comprime los datos y los deja casi cuatro veces más pequeños en disco (de 1.020 MB a 260 MB). Los índices pesan 117 MB en total: el espacial del mapa 31,7 MB, el del centroide 27,2 MB, el de municipio y área 29,6 MB, el del cuadro 8,7 MB y el del identificador 19,7 MB.

=== Problemas que aparecieron

- *Un polígono dañado detuvo la primera carga completa* (cerca de Santa Marta). Se agregó un paso que repara los polígonos con errores antes de guardarlos; con eso la carga terminó sin descartar ninguno.
- *La altura viene vacía.* En los archivos de Microsoft la altura y la confianza vienen con el valor -1 cuando no hay dato. Ese -1 se guarda como vacío (`null`), para que no se confunda con una altura real.
- *Los archivos del inicio no tenían edificios PDET.* Los primeros archivos de la lista caen en zonas sin municipios PDET, así que las primeras pruebas no insertaron nada. Esto era correcto, no un error: se confirmó con un archivo de Nariño.
- *El código del cuadro pierde el cero inicial* en la lista de Microsoft (`32203213` en vez de `032203213`). Se completa a 9 dígitos.

=== Comprobaciones finales

Después de la carga completa se hicieron tres comprobaciones en MongoDB:

- *Cobertura.* Los 170 municipios PDET tienen edificios de Microsoft. Ninguno quedó sin datos.
- *Uso del índice.* Se buscó qué edificios contienen un punto dado (consulta `$geoIntersects`). MongoDB usó el índice espacial (`IXSCAN`), revisó solo 3 documentos de los 1,76 millones y respondió en 8 milisegundos.
- *Municipios con más edificios.* El conteo por municipio funciona y da resultados razonables, con las ciudades más grandes arriba.

#figure(
  text(size: 10.5pt)[
    #table(
      columns: (0.9fr, 2fr, 1.2fr, 1.4fr),
      align: (center, left, right, right),
      stroke: 0.5pt + luma(150),
      fill: (_, row) => if row == 0 { rgb("d0e2ff") } else { none },
      [*Código*], [*Municipio*], [*Edificios*], [*Área de techos (km²)*],
      [47001], [Santa Marta (Magdalena)], [67.664], [14,21],
      [20001], [Valledupar (Cesar)], [63.722], [13,51],
      [05837], [Turbo (Antioquia)], [43.360], [4,66],
      [52835], [Tumaco (Nariño)], [41.423], [4,52],
      [54810], [Tibú (Norte de Santander)], [35.478], [3,57],
    )
  ],
  caption: [Los cinco municipios PDET con más edificios en los datos de Microsoft.],
)
