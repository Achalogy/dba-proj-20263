"""Carga de datos y geometrías desacoplada de MongoDB para generación de gráficas."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import shape

from workflow.charts.registry import ChartContext


def load_context(
    results_path: Path, geojson_path: Path, ndjson_path: Path
) -> ChartContext:
    """Lee `workflow_results.json` y la capa municipal simplificada (GeoJSON o NDJSON)."""
    if not results_path.exists():
        print(
            f"[ERROR] No existe {results_path}. Ejecuta compute_metrics.py primero.",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(results_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    rows = []
    for m in data["municipalities"]:
        ms = m["metrics_microsoft"]
        gg = m["metrics_google"]
        cmp = m["comparison_metrics"]
        sp = m["solar_potential"]
        rows.append(
            {
                "cod_dane_mpio": m["cod_dane_mpio"],
                "municipio": m["municipio"],
                "departamento": m["departamento"],
                "subregion_id": m["subregion_pdet"]["id"],
                "subregion_nombre": m["subregion_pdet"]["nombre"],
                "area_oficial_km2": m["area_oficial_km2"],
                "ms_building_count": ms["building_count"],
                "ms_total_area_km2": ms["total_area_km2"],
                "ms_total_area_m2": ms["total_area_m2"],
                "ms_avg_area_m2": ms["avg_area_m2"],
                "ms_median_area_m2": ms["median_area_m2"],
                "google_has_coverage": gg["has_coverage"],
                "google_building_count": gg["building_count"],
                "google_total_area_km2": gg["total_area_km2"],
                "google_total_area_m2": gg["total_area_m2"],
                "google_avg_area_m2": gg["avg_area_m2"],
                "google_median_area_m2": gg["median_area_m2"],
                "google_avg_confidence": gg["avg_confidence"],
                "delta_area_pct": cmp["delta_area_pct"],
                "signed_delta_area_pct": cmp["signed_delta_area_pct"],
                "consensus_area_km2": cmp["consensus_area_km2"],
                "consensus_area_m2": cmp["consensus_area_m2"],
                "rooftop_density_pct": cmp["rooftop_density_pct"],
                "rooftop_density_m2_per_km2": cmp["rooftop_density_m2_per_km2"],
                "est_capacity_mwp": sp["est_capacity_mwp"],
                "est_annual_generation_gwh": sp["est_annual_generation_gwh"],
                "priority_rank": sp["priority_rank"],
            }
        )
    df_mpios = pd.DataFrame(rows)
    df_subregions = pd.DataFrame(data["subregions"])

    # Priorizar GeoJSON simplificado por velocidad; respaldo con NDJSON
    if geojson_path.exists():
        gdf = gpd.read_file(geojson_path)
    elif ndjson_path.exists():
        geoms = {}
        with open(ndjson_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    r = json.loads(line)
                    geoms[r["cod_dane_mpio"]] = shape(r["geometry"]).simplify(
                        0.002, preserve_topology=True
                    )
        gdf = gpd.GeoDataFrame(
            df_mpios.copy(),
            geometry=[geoms[c] for c in df_mpios["cod_dane_mpio"]],
            crs="EPSG:4326",
        )
    else:
        print(
            f"[ERROR] No se encontró {geojson_path} ni {ndjson_path} para generar mapas.",
            file=sys.stderr,
        )
        sys.exit(1)

    return ChartContext(
        data=data, df_mpios=df_mpios, df_subregions=df_subregions, gdf=gdf
    )
