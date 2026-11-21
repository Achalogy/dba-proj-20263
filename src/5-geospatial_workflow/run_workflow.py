"""Orquestador de un solo comando del Flujo Reproducible de Análisis Geoespacial.

Ejecuta secuencialmente:
  1. `compute_metrics.py`: agregaciones en MongoDB, materialización de
     `solar_aggregations` y exportación a JSON, CSV y GeoJSON.
  2. `generate_charts.py`: generación de mapas coropléticos y gráficas en PNG/SVG.

Uso:
    uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/run_workflow.py \
        --uri "mongodb://acha:acha@tally:27017/?authSource=admin"
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Ejecuta de inicio a fin el flujo geoespacial reproducible (cálculo + gráficas)."
    )
    ap.add_argument(
        "--uri",
        default=os.getenv(
            "MONGO_URI", "mongodb://acha:acha@localhost:27017/?authSource=admin"
        ),
        help="URI de conexión a MongoDB",
    )
    ap.add_argument("--db", default=os.getenv("MONGO_DATABASE", "upme_pdet"))
    ap.add_argument("--workflow-dir", default="reports/workflow")
    ap.add_argument("--figures-dir", default="reports/figures")
    ap.add_argument("--charts", default="all")
    ap.add_argument("--formats", default="png")
    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument(
        "--skip-compute",
        action="store_true",
        help="Reutilizar workflow_results.json existente",
    )
    ap.add_argument("--no-write-db", action="store_true")
    args = ap.parse_args()

    here = Path(__file__).resolve().parent

    if not args.skip_compute:
        cmd_compute = [
            sys.executable,
            str(here / "compute_metrics.py"),
            "--uri",
            args.uri,
            "--db",
            args.db,
            "--output-dir",
            args.workflow_dir,
        ]
        if args.no_write_db:
            cmd_compute.append("--no-write-db")
        subprocess.run(cmd_compute, check=True)

    cmd_charts = [
        sys.executable,
        str(here / "generate_charts.py"),
        "--input",
        str(Path(args.workflow_dir) / "workflow_results.json"),
        "--geojson",
        str(Path(args.workflow_dir) / "pdet_solar_metrics.geojson"),
        "--output-dir",
        args.figures_dir,
        "--charts",
        args.charts,
        "--formats",
        args.formats,
        "--dpi",
        str(args.dpi),
    ]
    subprocess.run(cmd_charts, check=True)


if __name__ == "__main__":
    main()
