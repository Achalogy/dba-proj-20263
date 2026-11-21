"""Exportación abierta (JSON, CSV, GeoJSON) y resumen ejecutivo en consola."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import geopandas as gpd
import pandas as pd
from shapely.geometry import shape

from workflow.config import WorkflowConfig


def flatten_municipality_row(m: dict[str, Any]) -> dict[str, Any]:
    ms = m["metrics_microsoft"]
    gg = m["metrics_google"]
    cmp = m["comparison_metrics"]
    sp = m["solar_potential"]
    return {
        "priority_rank": sp["priority_rank"],
        "cod_dane_mpio": m["cod_dane_mpio"],
        "municipio": m["municipio"],
        "cod_dane_dpto": m["cod_dane_dpto"],
        "departamento": m["departamento"],
        "subregion_id": m["subregion_pdet"]["id"],
        "subregion_nombre": m["subregion_pdet"]["nombre"],
        "area_oficial_km2": m["area_oficial_km2"],
        "ms_building_count": ms["building_count"],
        "ms_total_area_m2": ms["total_area_m2"],
        "ms_total_area_ha": ms["total_area_ha"],
        "ms_total_area_km2": ms["total_area_km2"],
        "ms_avg_area_m2": ms["avg_area_m2"],
        "ms_median_area_m2": ms["median_area_m2"],
        "ms_plausible_count": ms["plausible_count"],
        "ms_plausible_area_m2": ms["plausible_area_m2"],
        "google_has_coverage": gg["has_coverage"],
        "google_building_count": gg["building_count"],
        "google_total_area_m2": gg["total_area_m2"],
        "google_total_area_ha": gg["total_area_ha"],
        "google_total_area_km2": gg["total_area_km2"],
        "google_avg_area_m2": gg["avg_area_m2"],
        "google_median_area_m2": gg["median_area_m2"],
        "google_avg_confidence": gg["avg_confidence"],
        "google_high_conf_count": gg["high_conf_count"],
        "google_high_conf_area_m2": gg["high_conf_area_m2"],
        "google_plausible_count": gg["plausible_count"],
        "google_plausible_area_m2": gg["plausible_area_m2"],
        "delta_count": cmp["delta_count"],
        "count_ratio_g_to_ms": cmp["count_ratio_g_to_ms"],
        "delta_area_m2": cmp["delta_area_m2"],
        "delta_area_pct": cmp["delta_area_pct"],
        "signed_delta_area_pct": cmp["signed_delta_area_pct"],
        "consensus_strategy": cmp["consensus_strategy"],
        "consensus_area_m2": cmp["consensus_area_m2"],
        "consensus_area_ha": cmp["consensus_area_ha"],
        "consensus_area_km2": cmp["consensus_area_km2"],
        "rooftop_density_pct": cmp["rooftop_density_pct"],
        "rooftop_density_m2_per_km2": cmp["rooftop_density_m2_per_km2"],
        "usable_roof_m2": sp["usable_roof_m2"],
        "est_capacity_kwp": sp["est_capacity_kwp"],
        "est_capacity_mwp": sp["est_capacity_mwp"],
        "est_annual_generation_gwh": sp["est_annual_generation_gwh"],
        "priority_rank_ms": sp["priority_rank_ms"],
        "priority_rank_google": sp["priority_rank_google"],
        "priority_rank_density": sp["priority_rank_density"],
    }


def export_simplified_geojson(
    municipalities: list[dict[str, Any]],
    ndjson_path: Path,
    out_geojson: Path,
    simplify_tolerance: float,
) -> None:
    """Une los resultados municipales con geometrías simplificadas para SIG y mapas."""
    if not ndjson_path.exists():
        print(f"  [aviso] No se encontró {ndjson_path}; se omite exportación GeoJSON.")
        return

    geom_by_code = {}
    with open(ndjson_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                rec = json.loads(line)
                geom_by_code[rec["cod_dane_mpio"]] = shape(rec["geometry"])

    rows, geoms = [], []
    for m in municipalities:
        g = geom_by_code.get(m["cod_dane_mpio"])
        if g is None:
            continue
        if simplify_tolerance > 0:
            g = g.simplify(simplify_tolerance, preserve_topology=True)
        rows.append(flatten_municipality_row(m))
        geoms.append(g)

    gdf = gpd.GeoDataFrame(rows, geometry=geoms, crs="EPSG:4326")
    out_geojson.parent.mkdir(parents=True, exist_ok=True)
    gdf.to_file(out_geojson, driver="GeoJSON")
    size_mb = out_geojson.stat().st_size / (1024 * 1024)
    print(f"  -> GeoJSON simplificado guardado en {out_geojson} ({size_mb:.2f} MB)")


def export_workflow_outputs(
    workflow_results: dict[str, Any],
    flat_rows: list[dict[str, Any]],
    cfg: WorkflowConfig,
) -> Path:
    """Exporta JSON validado, CSVs municipales/subregionales/departamentales y GeoJSON."""
    out_dir = Path(cfg.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    json_path = out_dir / "workflow_results.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(workflow_results, f, indent=2, ensure_ascii=False)
    with open(json_path, "r", encoding="utf-8") as f:
        json.load(f)

    pd.DataFrame(flat_rows).to_csv(
        out_dir / "municipalities_metrics.csv", index=False, encoding="utf-8"
    )
    pd.DataFrame(workflow_results["subregions"]).to_csv(
        out_dir / "subregions_metrics.csv", index=False, encoding="utf-8"
    )
    pd.DataFrame(workflow_results["departments"]).to_csv(
        out_dir / "departments_metrics.csv", index=False, encoding="utf-8"
    )

    if cfg.export_geojson:
        export_simplified_geojson(
            municipalities=workflow_results["municipalities"],
            ndjson_path=Path(cfg.ndjson_path),
            out_geojson=out_dir / "pdet_solar_metrics.geojson",
            simplify_tolerance=cfg.simplify_tol,
        )
    return out_dir


def print_executive_summary(workflow_results: dict[str, Any], out_dir: Path) -> None:
    meta = workflow_results["metadata"]
    gs = workflow_results["global_summary"]
    ms, gg, hc = gs["microsoft"], gs["google"], gs["hybrid_consensus"]
    agr, conc = gs["agreement"], gs["concentration"]
    u_pct = meta["assumptions"]["utilization_factor"] * 100.0

    print("\n=== RESUMEN EJECUTIVO DEL WORKFLOW ===")
    print(f"  Municipios PDET procesados: {gs['municipalities_total']} / 170")
    print(
        f"  Microsoft: {ms['building_count']:,} techos | {ms['total_area_km2']:.2f} km² "
        f"(RN-05: {ms['plausible_rn05_area_km2']:.2f} km²)"
    )
    print(
        f"  Google:    {gg['building_count']:,} techos | {gg['total_area_km2']:.2f} km² "
        f"(RN-04/05: {gg['plausible_rn04_rn05_area_km2']:.2f} km², "
        f"conf>=0.75: {gg['high_conf_area_km2']:.2f} km²)"
    )
    print(
        f"  Consenso híbrido: {hc['total_area_km2']:.2f} km² | "
        f"Área útil ({u_pct:.0f}%): {hc['usable_roof_km2']:.2f} km²"
    )
    print(
        f"  Potencial solar estimado: {hc['est_capacity_gwp']:.2f} GWp "
        f"({hc['est_capacity_mwp']:.1f} MWp) | {hc['est_annual_generation_twh']:.2f} TWh/año"
    )
    print(
        f"  Correlación MS vs Google (n={agr['common_municipalities']}): "
        f"Pearson r={agr['area_pearson_r']:.4f} (R²={agr['area_r_squared']:.4f}), "
        f"Spearman ρ={agr['area_spearman_rho']:.4f}"
    )
    print(
        f"  Concentración: Top 10 = {conc['top10_share_pct']:.1f}% | "
        f"50% del área en {conc['municipalities_for_50pct_area']} mpios | "
        f"80% en {conc['municipalities_for_80pct_area']} mpios"
    )
    print(f"  SHA-256 determinístico: {meta['deterministic_sha256'][:16]}...")
    print(
        f"  Archivos exportados en: {out_dir}/ ({meta['timings_seconds']['total_s']:.2f} s)"
    )
