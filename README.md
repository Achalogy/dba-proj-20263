# Evaluación NoSQL del Potencial Solar en Cubiertas de Municipios PDET (UPME)

Plataforma geoespacial reproducible sobre **MongoDB 9.0** para integrar, auditar y analizar el inventario de edificaciones de los **170 municipios PDET** (16 subregiones) de Colombia a partir de **DANE MGN 2025**, **Microsoft Global ML Building Footprints** y **Google Open Buildings V3**.

---

## Estructura del Repositorio

```text
.
├── reproduce.sh                         # Orquestador único (modos: analysis | archive | full)
├── data/
│   ├── MunicipiosPDET.xlsx              # Catálogo oficial de los 170 municipios PDET
│   └── processed/
│       └── municipalities_pdet.ndjson   # Geometrías validadas EPSG:4326 (64 MB, listas para cargar)
├── src/
│   ├── 1-pdet_mgn/                      # Etapa 1: verificación MGN y carga de 170 municipios PDET
│   ├── 2-mongo_container_test/          # Etapa 2: Docker Compose (MongoDB 9.0 + perfil import)
│   ├── 3-buildings-microsoft/           # Etapa 3A: ETL Microsoft Buildings (1,76 M edificios)
│   ├── 3-google_open_buildings/         # Etapa 3B: ETL Google Open Buildings V3 (2,69 M edificios)
│   ├── 4-eda/                           # Etapa 4: EDA y auditoría de índices 2dsphere
│   └── 5-geospatial_workflow/           # Etapa 5: workflow reproducible, solar_aggregations y 9 figuras
├── reports/
│   ├── workflow/                        # JSON, CSVs y GeoJSON con métricas municipales/subregionales
│   └── figures/                         # 9 figuras (300 DPI) + manifest.json
├── docs/                                # Secciones modulares Typst (1 a 9)
└── outcomes/                            # Entregables semanales e Informe Técnico Final (PDF/Typst)
```

---

## Prerrequisitos

- **Docker** y **Docker Compose** (si se ejecuta MongoDB localmente)
- **[`uv`](https://docs.astral.sh/uv/)** (gestiona automáticamente Python y las dependencias aisladas de cada módulo)
- **Opcional:** `mongorestore` (solo para restauración rápida desde `.archive`) y [`typst`](https://typst.app/) (para compilar los informes en PDF)

---

## Reproducción Rápida con un Solo Comando (`reproduce.sh`)

> Todos los comandos asumen que la terminal está ubicada en la **raíz del repositorio**.

### Opción A — Reproducción completa desde 0 (Etapa 1 → Etapa 5 + PDFs)

Utiliza el catálogo `data/MunicipiosPDET.xlsx` y el archivo validado `data/processed/municipalities_pdet.ndjson` (o bien `--mgn <ruta_shapefile>` si se descargó el MGN oficial del DANE), descarga y procesa Microsoft y Google, ejecuta el EDA, calcula métricas/gráficas y compila los PDFs:

```bash
# Levanta MongoDB local y corre todas las etapas desde 0
./reproduce.sh --mode full --start-mongo

# Alternativa con el shapefile oficial del DANE MGN (3,2 GB):
./reproduce.sh --mode full --start-mongo --mgn data/MGN_ADM_MPIO_GRAFICO.shp
```

### Opción B — Restauración rápida desde respaldo (`mongodump .archive`, ~1 min)

Si se cuenta con el respaldo comprimido `data/upme_pdet.archive` (~282 MB), que se descarga del Drive del grupo (https://drive.google.com/file/d/1iW2zaDCCuD74CivGDBEX6A8XAYrooNqc/view?usp=drive_link) y se guarda con ese nombre dentro de la carpeta `data/`:

```bash
./reproduce.sh --mode archive --start-mongo
```

### Opción C — Solo análisis, gráficas y PDFs sobre una instancia MongoDB existente

```bash
./reproduce.sh --mode analysis \
  --uri "mongodb://acha:acha@localhost:27017/?authSource=admin"
```

---

## Paso a Paso Manual por Etapas

Si se prefiere ejecutar o depurar cada etapa de manera individual, defina primero la URI de conexión:

```bash
export MONGO_URI="mongodb://acha:acha@localhost:27017/?authSource=admin"
export MONGO_DATABASE="upme_pdet"
```

### 1. Infraestructura MongoDB (Docker Compose)

```bash
docker compose -f src/2-mongo_container_test/compose.yml up -d mongodb
```

_(Usa por defecto usuario `acha` y contraseña `acha`, sobreescribibles mediante `src/2-mongo_container_test/.env` a partir de `.env.example`.)_

### 2. Etapa 1 — Municipios PDET (`src/1-pdet_mgn/`)

```bash
# Opción 2a: Desde el shapefile oficial del MGN (DANE)
uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp

uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --mgn data/MGN_ADM_MPIO_GRAFICO.shp \
  --export data/processed/municipalities_pdet.ndjson

# Opción 2b: Desde el NDJSON versionado en el repositorio (sin descargar 3,2 GB)
uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
  --from-ndjson data/processed/municipalities_pdet.ndjson
```

### 3. Etapa 3A — Microsoft Global ML Building Footprints (`src/3-buildings-microsoft/`)

Descarga automáticamente `dataset-links.csv` si no existe, baja los 232 archivos de Colombia, se queda solo con los edificios que caen en los 170 municipios PDET, calcula áreas reales en `EPSG:9377`, inserta en lotes de 5.000 documentos y crea índices al final:

```bash
uv run --project src/3-buildings-microsoft \
  python src/3-buildings-microsoft/load_microsoft.py --batch-size 5000 --tag full
```

### 4. Etapa 3B — Google Open Buildings V3 (`src/3-google_open_buildings/`)

Disuelve la frontera PDET, descarga las teselas S2 nivel 4 que la intersecan y carga en paralelo con control de idempotencia (`etl_processed_files`):

```bash
uv run --project src/3-google_open_buildings python src/3-google_open_buildings/generate_pdet_union.py
uv run --project src/3-google_open_buildings python src/3-google_open_buildings/download_pdet_buildings.py
uv run --project src/3-google_open_buildings python src/3-google_open_buildings/importer.py
```

### 5. Etapa 4 — EDA y Auditoría de Índices Espaciales (`src/4-eda/`)

```bash
uv run --project src/4-eda python src/4-eda/eda.py --output reports/eda_results.json
```

### 6. Etapa 5 — Workflow Geoespacial Reproducible y Gráficas (`src/5-geospatial_workflow/`)

Materializa la colección `solar_aggregations` (170 documentos), exporta `reports/workflow/*` (JSON, CSV, GeoJSON) y genera las 9 figuras en `reports/figures/`:

```bash
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/run_workflow.py
```

Para regenerar únicamente las gráficas o filtrar algunas específicas sin recalcular MongoDB:

```bash
uv run --project src/5-geospatial_workflow \
  python src/5-geospatial_workflow/generate_charts.py --list
```

### 7. Compilación de Informes en PDF (Typst)

```bash
typst compile --root . outcomes/4-semana_4.typ outcomes/4-semana_4.pdf
typst compile --root . outcomes/5-final-technical-report.typ outcomes/5-final-technical-report.pdf
```
