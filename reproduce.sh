#!/usr/bin/env bash
# ==============================================================================
# UPME - PDET | Orquestador de Reproducción Integral (Etapa 1 -> Etapa 5 + PDFs)
# ==============================================================================
# Modos disponibles (--mode):
#   analysis (default): Ejecuta EDA (Etapa 4), Workflow Geoespacial (Etapa 5)
#                       y compila reportes PDF (requiere MongoDB ya poblado).
#   archive:            Restaura data/upme_pdet.archive (~282 MB) con
#                       mongorestore y ejecuta el modo analysis (~1 min).
#   full:               Ejecuta todo desde 0:
#                       Etapa 1 (MGN/NDJSON PDET) -> Etapa 3A (Microsoft) ->
#                       Etapa 3B (Google Open Buildings) -> Etapa 4 (EDA) ->
#                       Etapa 5 (Workflow + 9 figuras) -> Compilación Typst.
#
# Ejemplos:
#   ./reproduce.sh --mode analysis --uri "mongodb://acha:acha@tally:27017/?authSource=admin"
#   ./reproduce.sh --mode archive --start-mongo
#   ./reproduce.sh --mode full --start-mongo
#   ./reproduce.sh --mode full --mgn data/MGN_ADM_MPIO_GRAFICO.shp --uri "mongodb://acha:acha@localhost:27017/?authSource=admin"
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

MODE="analysis"
MONGO_URI="${MONGO_URI:-mongodb://acha:acha@localhost:27017/?authSource=admin}"
MONGO_DB="${MONGO_DATABASE:-upme_pdet}"
MGN_PATH=""
ARCHIVE_PATH="data/upme_pdet.archive"
START_MONGO=0
SKIP_PDF=0

usage() {
  sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

Opciones:
  --mode <analysis|archive|full>  Modo de ejecución (default: analysis)
  --uri <MONGO_URI>               URI de conexión a MongoDB
  --db <NOMBRE_BD>                Base de datos destino (default: upme_pdet)
  --mgn <RUTA_MGN>                Capa MGN (.shp/.gdb/.gpkg) para Etapa 1 (opcional)
  --archive <RUTA_ARCHIVE>        Archivo mongodump .archive para modo archive
  --start-mongo                   Levanta el contenedor MongoDB local vía Docker Compose
  --skip-pdf                      Omite la compilación de reportes PDF con Typst
  -h, --help                      Muestra esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)        MODE="$2"; shift 2 ;;
    --uri)         MONGO_URI="$2"; shift 2 ;;
    --db)          MONGO_DB="$2"; shift 2 ;;
    --mgn)         MGN_PATH="$2"; shift 2 ;;
    --archive)     ARCHIVE_PATH="$2"; shift 2 ;;
    --start-mongo) START_MONGO=1; shift ;;
    --skip-pdf)    SKIP_PDF=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "[ERROR] Opción no reconocida: $1" >&2; usage; exit 1 ;;
  esac
done

export MONGO_URI
export MONGO_DATABASE="$MONGO_DB"
export MONGO_DB

log() {
  printf '\n\033[1;34m===> %s\033[0m\n' "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] No se encontró el comando requerido '$1' en el PATH." >&2
    exit 1
  fi
}

start_mongo_container() {
  require_cmd docker
  log "Etapa 2 | Levantando contenedor MongoDB (src/2-mongo_container_test/compose.yml)"
  docker compose -f src/2-mongo_container_test/compose.yml up -d mongodb
  echo "Esperando a que el contenedor 'mongodb' esté saludable..."
  for _ in $(seq 1 30); do
    status="$(docker inspect -f '{{.State.Health.Status}}' mongodb 2>/dev/null || echo "starting")"
    if [[ "$status" == "healthy" ]]; then
      echo "[OK] Contenedor mongodb healthy."
      return 0
    fi
    sleep 2
  done
  echo "[ERROR] El contenedor mongodb no alcanzó estado healthy a tiempo." >&2
  exit 1
}

run_stage1_pdet() {
  log "Etapa 1 | Preparación y validación de los 170 municipios PDET"
  if [[ -n "$MGN_PATH" ]]; then
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py \
      --mgn "$MGN_PATH" \
      --xlsx data/MunicipiosPDET.xlsx \
      --out reports
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
      --mgn "$MGN_PATH" \
      --xlsx data/MunicipiosPDET.xlsx \
      --uri "$MONGO_URI" \
      --db "$MONGO_DB" \
      --export data/processed/municipalities_pdet.ndjson
  else
    uv run --project src/1-pdet_mgn python src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py \
      --from-ndjson data/processed/municipalities_pdet.ndjson \
      --xlsx data/MunicipiosPDET.xlsx \
      --uri "$MONGO_URI" \
      --db "$MONGO_DB"
  fi
}

run_stage3_microsoft() {
  log "Etapa 3A | Ingesta de Microsoft Global ML Building Footprints"
  uv run --project src/3-buildings-microsoft python src/3-buildings-microsoft/load_microsoft.py \
    --uri "$MONGO_URI" \
    --db "$MONGO_DB" \
    --batch-size 5000 \
    --tag full
}

run_stage3_google() {
  log "Etapa 3B | Ingesta de Google Open Buildings V3"
  uv run --project src/3-google_open_buildings python src/3-google_open_buildings/generate_pdet_union.py
  uv run --project src/3-google_open_buildings python src/3-google_open_buildings/download_pdet_buildings.py
  uv run --project src/3-google_open_buildings python src/3-google_open_buildings/importer.py
}

run_restore_archive() {
  require_cmd mongorestore
  if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "[ERROR] No existe el archivo de respaldo: $ARCHIVE_PATH" >&2
    exit 1
  fi
  log "Restaurando respaldo MongoDB desde $ARCHIVE_PATH"
  mongorestore --uri="$MONGO_URI" --gzip --archive="$ARCHIVE_PATH" --drop
}

run_stage4_eda() {
  log "Etapa 4 | Análisis Exploratorio (EDA) y auditoría de índices espaciales"
  uv run --project src/4-eda python src/4-eda/eda.py \
    --uri "$MONGO_URI" \
    --db "$MONGO_DB" \
    --output reports/eda_results.json
}

run_stage5_workflow() {
  log "Etapa 5 | Workflow Geoespacial Reproducible (métricas, colecciones y 9 figuras)"
  uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/run_workflow.py \
    --uri "$MONGO_URI" \
    --db "$MONGO_DB"
}

compile_pdfs() {
  if [[ "$SKIP_PDF" -eq 1 ]]; then
    echo "[info] Compilación de PDFs omitida (--skip-pdf)."
    return 0
  fi
  if ! command -v typst >/dev/null 2>&1; then
    echo "[aviso] 'typst' no está instalado; se omite la compilación de PDFs."
    return 0
  fi
  log "Compilando entregables técnicos en PDF (Typst)"
  typst compile --root . outcomes/4-semana_4.typ outcomes/4-semana_4.pdf
  typst compile --root . outcomes/5-final-technical-report.typ outcomes/5-final-technical-report.pdf
  echo "[OK] PDFs generados en outcomes/4-semana_4.pdf y outcomes/5-final-technical-report.pdf"
}

require_cmd uv

if [[ "$START_MONGO" -eq 1 ]]; then
  start_mongo_container
fi

case "$MODE" in
  analysis)
    run_stage4_eda
    run_stage5_workflow
    compile_pdfs
    ;;
  archive)
    run_restore_archive
    run_stage4_eda
    run_stage5_workflow
    compile_pdfs
    ;;
  full)
    run_stage1_pdet
    run_stage3_microsoft
    run_stage3_google
    run_stage4_eda
    run_stage5_workflow
    compile_pdfs
    ;;
  *)
    echo "[ERROR] Modo inválido: '$MODE'. Usa analysis, archive o full." >&2
    exit 1
    ;;
esac

log "Reproducción finalizada correctamente (modo: $MODE)"
