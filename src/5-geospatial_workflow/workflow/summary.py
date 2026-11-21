"""Estadísticos de concordancia, estratos morfológicos, concentración y resumen global."""

from __future__ import annotations

import hashlib
import json
import math
from typing import Any

import numpy as np
from scipy import stats as scipy_stats

from workflow.config import STRATA_DEFS, gini_coefficient


def compute_agreement_stats(municipalities: list[dict[str, Any]]) -> dict[str, Any]:
    """Calcula estadísticos de concordancia inter-fuente sobre los municipios comunes."""
    common = [m for m in municipalities if m["metrics_google"]["has_coverage"]]
    missing = [m for m in municipalities if not m["metrics_google"]["has_coverage"]]

    ms_areas = np.array([m["metrics_microsoft"]["total_area_m2"] for m in common])
    gg_areas = np.array([m["metrics_google"]["total_area_m2"] for m in common])
    ms_cnts = np.array([m["metrics_microsoft"]["building_count"] for m in common])
    gg_cnts = np.array([m["metrics_google"]["building_count"] for m in common])
    rel_diffs = np.array([m["comparison_metrics"]["delta_area_pct"] for m in common])

    p_area_r, p_area_p = scipy_stats.pearsonr(ms_areas, gg_areas)
    s_area_r, s_area_p = scipy_stats.spearmanr(ms_areas, gg_areas)
    p_cnt_r, _ = scipy_stats.pearsonr(ms_cnts, gg_cnts)
    s_cnt_r, _ = scipy_stats.spearmanr(ms_cnts, gg_cnts)

    return {
        "common_municipalities": len(common),
        "missing_in_google_count": len(missing),
        "area_pearson_r": round(float(p_area_r), 5),
        "area_r_squared": round(float(p_area_r**2), 5),
        "area_pearson_p": float(p_area_p),
        "area_spearman_rho": round(float(s_area_r), 5),
        "area_spearman_p": float(s_area_p),
        "area_mae_km2": round(float(np.mean(np.abs(gg_areas - ms_areas)) / 1e6), 4),
        "area_rmse_km2": round(
            float(np.sqrt(np.mean((gg_areas - ms_areas) ** 2)) / 1e6), 4
        ),
        "area_median_rel_discrepancy_pct": round(float(np.median(rel_diffs)), 2),
        "area_mean_rel_discrepancy_pct": round(float(np.mean(rel_diffs)), 2),
        "area_within_20pct_count": int(np.sum(rel_diffs <= 20.0)),
        "area_within_20pct_share": round(float(np.mean(rel_diffs <= 20.0) * 100.0), 2),
        "count_pearson_r": round(float(p_cnt_r), 5),
        "count_spearman_rho": round(float(s_cnt_r), 5),
        "count_ratio_median_g_to_ms": round(float(np.median(gg_cnts / ms_cnts)), 3),
    }


def compute_strata_and_concentration(
    municipalities: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Calcula la tabla global de estratos morfológicos y la concentración Pareto/Gini."""
    tot_ms_cnt = sum(m["metrics_microsoft"]["building_count"] for m in municipalities)
    tot_ms_area = sum(m["metrics_microsoft"]["total_area_m2"] for m in municipalities)
    tot_gg_cnt = sum(m["metrics_google"]["building_count"] for m in municipalities)
    tot_gg_area = sum(m["metrics_google"]["total_area_m2"] for m in municipalities)
    tot_cons_area = sum(
        m["comparison_metrics"]["consensus_area_m2"] for m in municipalities
    )

    strata_summary = []
    for key, label, lo, hi in STRATA_DEFS:
        ms_c = sum(
            m["metrics_microsoft"]["strata"][key]["count"] for m in municipalities
        )
        ms_a = sum(
            m["metrics_microsoft"]["strata"][key]["total_area_m2"]
            for m in municipalities
        )
        gg_c = sum(m["metrics_google"]["strata"][key]["count"] for m in municipalities)
        gg_a = sum(
            m["metrics_google"]["strata"][key]["total_area_m2"] for m in municipalities
        )
        strata_summary.append(
            {
                "key": key,
                "label": label,
                "min_m2": lo,
                "max_m2": None if math.isinf(hi) else hi,
                "ms_count": ms_c,
                "ms_pct_count": round(ms_c / tot_ms_cnt * 100.0, 2)
                if tot_ms_cnt
                else 0,
                "ms_total_area_m2": round(ms_a, 2),
                "ms_total_area_km2": round(ms_a / 1e6, 4),
                "ms_pct_area": round(ms_a / tot_ms_area * 100.0, 2)
                if tot_ms_area
                else 0,
                "google_count": gg_c,
                "google_pct_count": round(gg_c / tot_gg_cnt * 100.0, 2)
                if tot_gg_cnt
                else 0,
                "google_total_area_m2": round(gg_a, 2),
                "google_total_area_km2": round(gg_a / 1e6, 4),
                "google_pct_area": round(gg_a / tot_gg_area * 100.0, 2)
                if tot_gg_area
                else 0,
            }
        )

    areas_sorted = [
        m["comparison_metrics"]["consensus_area_m2"] for m in municipalities
    ]
    cum_shares = np.cumsum(areas_sorted) / tot_cons_area
    concentration = {
        "gini_consensus_area": round(gini_coefficient(areas_sorted), 4),
        "top5_share_pct": round(float(cum_shares[4] * 100.0), 2),
        "top10_share_pct": round(float(cum_shares[9] * 100.0), 2),
        "top20_share_pct": round(float(cum_shares[19] * 100.0), 2),
        "top50_share_pct": round(float(cum_shares[49] * 100.0), 2),
        "municipalities_for_50pct_area": int(np.searchsorted(cum_shares, 0.50) + 1),
        "municipalities_for_80pct_area": int(np.searchsorted(cum_shares, 0.80) + 1),
    }
    return strata_summary, concentration


def compute_global_summary(
    municipalities: list[dict[str, Any]],
    subregions: list[dict[str, Any]],
    departments: list[dict[str, Any]],
    ms_global_pcts: dict[str, float | None],
    gg_global_pcts: dict[str, float | None],
    agreement_stats: dict[str, Any],
    concentration: dict[str, Any],
) -> dict[str, Any]:
    """Construye el bloque `global_summary` consolidado de todo el universo PDET."""
    tot_ms_cnt = sum(m["metrics_microsoft"]["building_count"] for m in municipalities)
    tot_ms_area = sum(m["metrics_microsoft"]["total_area_m2"] for m in municipalities)
    tot_gg_cnt = sum(m["metrics_google"]["building_count"] for m in municipalities)
    tot_gg_area = sum(m["metrics_google"]["total_area_m2"] for m in municipalities)
    tot_cons_area = sum(
        m["comparison_metrics"]["consensus_area_m2"] for m in municipalities
    )
    tot_official_km2 = sum(m["area_oficial_km2"] for m in municipalities)

    tot_ms_plaus_cnt = sum(
        m["metrics_microsoft"]["plausible_count"] for m in municipalities
    )
    tot_ms_plaus_area = sum(
        m["metrics_microsoft"]["plausible_area_m2"] for m in municipalities
    )
    tot_gg_plaus_cnt = sum(
        m["metrics_google"]["plausible_count"] for m in municipalities
    )
    tot_gg_plaus_area = sum(
        m["metrics_google"]["plausible_area_m2"] for m in municipalities
    )
    tot_gg_hconf_cnt = sum(
        m["metrics_google"]["high_conf_count"] for m in municipalities
    )
    tot_gg_hconf_area = sum(
        m["metrics_google"]["high_conf_area_m2"] for m in municipalities
    )
    tot_usable_m2 = sum(m["solar_potential"]["usable_roof_m2"] for m in municipalities)
    tot_cap_kwp = sum(m["solar_potential"]["est_capacity_kwp"] for m in municipalities)
    tot_gen_gwh = sum(
        m["solar_potential"]["est_annual_generation_gwh"] for m in municipalities
    )
    global_delta_pct = (
        abs(tot_gg_area - tot_ms_area) / ((tot_gg_area + tot_ms_area) / 2.0) * 100.0
    )

    return {
        "municipalities_total": len(municipalities),
        "subregions_total": len(subregions),
        "departments_total": len(departments),
        "total_official_area_km2": round(tot_official_km2, 2),
        "microsoft": {
            "municipalities_covered": sum(
                1 for m in municipalities if m["metrics_microsoft"]["has_coverage"]
            ),
            "building_count": tot_ms_cnt,
            "total_area_m2": round(tot_ms_area, 2),
            "total_area_ha": round(tot_ms_area / 1e4, 2),
            "total_area_km2": round(tot_ms_area / 1e6, 4),
            "avg_area_m2": round(tot_ms_area / tot_ms_cnt, 2) if tot_ms_cnt else None,
            "percentiles_m2": ms_global_pcts,
            "plausible_rn05_count": tot_ms_plaus_cnt,
            "plausible_rn05_area_km2": round(tot_ms_plaus_area / 1e6, 4),
            "plausible_rn05_area_retention_pct": round(
                tot_ms_plaus_area / tot_ms_area * 100.0, 2
            ),
        },
        "google": {
            "municipalities_covered": agreement_stats["common_municipalities"],
            "building_count": tot_gg_cnt,
            "total_area_m2": round(tot_gg_area, 2),
            "total_area_ha": round(tot_gg_area / 1e4, 2),
            "total_area_km2": round(tot_gg_area / 1e6, 4),
            "avg_area_m2": round(tot_gg_area / tot_gg_cnt, 2) if tot_gg_cnt else None,
            "percentiles_m2": gg_global_pcts,
            "plausible_rn04_rn05_count": tot_gg_plaus_cnt,
            "plausible_rn04_rn05_area_km2": round(tot_gg_plaus_area / 1e6, 4),
            "plausible_rn04_rn05_area_retention_pct": round(
                tot_gg_plaus_area / tot_gg_area * 100.0, 2
            ),
            "high_conf_count": tot_gg_hconf_cnt,
            "high_conf_pct_count": round(tot_gg_hconf_cnt / tot_gg_cnt * 100.0, 2),
            "high_conf_area_km2": round(tot_gg_hconf_area / 1e6, 4),
            "high_conf_pct_area": round(tot_gg_hconf_area / tot_gg_area * 100.0, 2),
        },
        "hybrid_consensus": {
            "strategy": "Media aritmética MS-Google en 165 municipios con cobertura compartida; respaldo Microsoft en 5 municipios de Chocó/Antioquia sin inferencia en Google.",
            "total_area_m2": round(tot_cons_area, 2),
            "total_area_ha": round(tot_cons_area / 1e4, 2),
            "total_area_km2": round(tot_cons_area / 1e6, 4),
            "global_delta_ms_vs_google_pct": round(global_delta_pct, 3),
            "rooftop_density_pct": round(
                tot_cons_area / (tot_official_km2 * 1e6) * 100.0, 5
            ),
            "usable_roof_km2": round(tot_usable_m2 / 1e6, 4),
            "est_capacity_mwp": round(tot_cap_kwp / 1000.0, 2),
            "est_capacity_gwp": round(tot_cap_kwp / 1e6, 3),
            "est_annual_generation_gwh": round(tot_gen_gwh, 2),
            "est_annual_generation_twh": round(tot_gen_gwh / 1000.0, 3),
        },
        "agreement": agreement_stats,
        "concentration": concentration,
    }


def build_rankings(flat_rows: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    """Construye los subconjuntos Top/Bottom precalculados para consumo analítico."""
    return {
        "top20_by_consensus_area": flat_rows[:20],
        "top20_by_ms_area": sorted(
            flat_rows, key=lambda x: (-x["ms_total_area_m2"], x["cod_dane_mpio"])
        )[:20],
        "top20_by_google_area": sorted(
            [r for r in flat_rows if r["google_has_coverage"]],
            key=lambda x: (-x["google_total_area_m2"], x["cod_dane_mpio"]),
        )[:20],
        "top20_by_density": sorted(
            flat_rows,
            key=lambda x: (-x["rooftop_density_m2_per_km2"], x["cod_dane_mpio"]),
        )[:20],
        "top20_by_discrepancy_pct": sorted(
            [r for r in flat_rows if r["delta_area_pct"] is not None],
            key=lambda x: (-x["delta_area_pct"], x["cod_dane_mpio"]),
        )[:20],
        "bottom10_by_consensus_area": sorted(
            flat_rows, key=lambda x: (x["consensus_area_m2"], x["cod_dane_mpio"])
        )[:10],
        "missing_in_google": [r for r in flat_rows if not r["google_has_coverage"]],
    }


def compute_deterministic_checksum(flat_rows: list[dict[str, Any]]) -> str:
    """Checksum SHA-256 determinístico (RN-10) sobre métricas municipales sin timestamps."""
    canonical_payload = [
        {
            "cod_dane_mpio": r["cod_dane_mpio"],
            "ms_building_count": r["ms_building_count"],
            "ms_total_area_m2": r["ms_total_area_m2"],
            "google_building_count": r["google_building_count"],
            "google_total_area_m2": r["google_total_area_m2"],
            "consensus_area_m2": r["consensus_area_m2"],
            "est_capacity_kwp": r["est_capacity_kwp"],
        }
        for r in sorted(flat_rows, key=lambda x: x["cod_dane_mpio"])
    ]
    return hashlib.sha256(
        json.dumps(canonical_payload, sort_keys=True, separators=(",", ":")).encode(
            "utf-8"
        )
    ).hexdigest()
