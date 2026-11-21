"""CLI del generador modular y extensible de gráficas y mapas coropléticos (UPME - PDET).

Lee únicamente los resultados ya calculados (`reports/workflow/workflow_results.json`)
y las geometrías municipales (`reports/workflow/pdet_solar_metrics.geojson` o
`data/processed/municipalities_pdet.ndjson`), desacoplando visualización de MongoDB.

Las gráficas están organizadas por categoría bajo `workflow/charts/`:
  - `workflow/charts/maps.py`      (01–03: mapas coropléticos nacionales)
  - `workflow/charts/rankings.py`  (04–05: subregiones y Top 15 municipal)
  - `workflow/charts/analytics.py` (06–09: correlación, estratos, confianza y Pareto)

Para agregar nuevas gráficas en el futuro, basta con decorar una función con
`@register_chart("nombre_grafica", title=..., description=..., category=...)`
e importar su módulo en `workflow/charts/__init__.py`.

Uso:
    uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/generate_charts.py
    uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/generate_charts.py --list
    uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/generate_charts.py --charts 01_map_pdet_rooftop_area,05_top15_municipalities --formats png,svg
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt

from workflow.charts import CHART_REGISTRY, load_context


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Genera gráficas y mapas coropléticos a partir de workflow_results.json."
    )
    ap.add_argument(
        "--input",
        default="reports/workflow/workflow_results.json",
        help="Ruta al archivo JSON de resultados del workflow",
    )
    ap.add_argument(
        "--geojson",
        default="reports/workflow/pdet_solar_metrics.geojson",
        help="Ruta al GeoJSON simplificado de municipios PDET",
    )
    ap.add_argument(
        "--ndjson",
        default="data/processed/municipalities_pdet.ndjson",
        help="Ruta de respaldo al NDJSON de municipios PDET",
    )
    ap.add_argument(
        "--output-dir",
        default="reports/figures",
        help="Carpeta destino para las imágenes generadas",
    )
    ap.add_argument(
        "--charts",
        default="all",
        help="Lista separada por comas de IDs de gráficas o 'all' (default: all)",
    )
    ap.add_argument(
        "--formats",
        default="png",
        help="Formatos de salida separados por comas (ej. png o png,svg; default: png)",
    )
    ap.add_argument(
        "--dpi", type=int, default=300, help="Resolución DPI para PNG (default: 300)"
    )
    ap.add_argument(
        "--list", action="store_true", help="Listar las gráficas disponibles y salir"
    )
    args = ap.parse_args()

    if args.list:
        print("Gráficas registradas disponibles:")
        for cid, spec in CHART_REGISTRY.items():
            print(f"  - {cid} [{spec.category}]: {spec.title}")
        return

    selected_ids = (
        list(CHART_REGISTRY.keys())
        if args.charts.strip().lower() == "all"
        else [c.strip() for c in args.charts.split(",") if c.strip()]
    )
    unknown = [c for c in selected_ids if c not in CHART_REGISTRY]
    if unknown:
        print(
            f"[ERROR] Gráficas desconocidas: {unknown}. Usa --list para ver disponibles.",
            file=sys.stderr,
        )
        sys.exit(1)

    formats = [fmt.strip().lower() for fmt in args.formats.split(",") if fmt.strip()]
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print("Cargando resultados y geometrías PDET...")
    ctx = load_context(Path(args.input), Path(args.geojson), Path(args.ndjson))

    manifest = {
        "source_results": str(args.input),
        "generated_at": ctx.data["metadata"]["generated_at"],
        "dpi": args.dpi,
        "formats": formats,
        "figures": [],
    }

    for cid in selected_ids:
        spec = CHART_REGISTRY[cid]
        print(f"  -> Generando {cid} ({spec.title})...")
        fig = spec.fn(ctx)
        saved_files = []
        for fmt in formats:
            out_file = out_dir / f"{cid}.{fmt}"
            fig.savefig(out_file, dpi=args.dpi, format=fmt)
            saved_files.append(str(out_file))
        plt.close(fig)
        manifest["figures"].append(
            {
                "id": cid,
                "category": spec.category,
                "title": spec.title,
                "description": spec.description,
                "files": saved_files,
            }
        )

    manifest_path = out_dir / "manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(
        f"\n[OK] {len(selected_ids)} gráficas generadas en {out_dir}/ (manifiesto: {manifest_path})"
    )


if __name__ == "__main__":
    main()
