"""Consolidación de métricas municipales, consenso híbrido y agregación territorial."""

from __future__ import annotations

from typing import Any

from workflow.config import STRATA_DEFS, WorkflowConfig, safe_round


def format_source_metrics(
    raw: dict[str, Any] | None, is_google: bool
) -> dict[str, Any]:
    """Normaliza las métricas agregadas por municipio de una fuente."""
    if not raw or raw.get("building_count", 0) == 0:
        base: dict[str, Any] = {
            "has_coverage": False,
            "building_count": 0,
            "total_area_m2": 0.0,
            "total_area_ha": 0.0,
            "total_area_km2": 0.0,
            "avg_area_m2": None,
            "median_area_m2": None,
            "p25_area_m2": None,
            "p75_area_m2": None,
            "p90_area_m2": None,
            "min_area_m2": None,
            "max_area_m2": None,
            "std_area_m2": None,
            "plausible_count": 0,
            "plausible_area_m2": 0.0,
            "strata": {
                k: {"count": 0, "total_area_m2": 0.0} for k, _, _, _ in STRATA_DEFS
            },
        }
        if is_google:
            base.update(
                {
                    "avg_confidence": None,
                    "min_confidence": None,
                    "max_confidence": None,
                    "std_confidence": None,
                    "high_conf_count": 0,
                    "high_conf_area_m2": 0.0,
                }
            )
        return base

    pcts = raw.get("percentiles") or [None, None, None, None]
    total_m2 = float(raw["total_area_m2"])
    out: dict[str, Any] = {
        "has_coverage": True,
        "building_count": int(raw["building_count"]),
        "total_area_m2": round(total_m2, 2),
        "total_area_ha": round(total_m2 / 1e4, 4),
        "total_area_km2": round(total_m2 / 1e6, 6),
        "avg_area_m2": safe_round(raw.get("avg_area_m2"), 2),
        "median_area_m2": safe_round(pcts[1], 2),
        "p25_area_m2": safe_round(pcts[0], 2),
        "p75_area_m2": safe_round(pcts[2], 2),
        "p90_area_m2": safe_round(pcts[3], 2),
        "min_area_m2": safe_round(raw.get("min_area_m2"), 2),
        "max_area_m2": safe_round(raw.get("max_area_m2"), 2),
        "std_area_m2": safe_round(raw.get("std_area_m2"), 2),
        "plausible_count": int(raw.get("plausible_count", 0)),
        "plausible_area_m2": round(float(raw.get("plausible_area_m2", 0.0)), 2),
        "strata": {
            key: {
                "count": int(raw.get(f"cnt_{key}", 0)),
                "total_area_m2": round(float(raw.get(f"area_{key}", 0.0)), 2),
            }
            for key, _, _, _ in STRATA_DEFS
        },
    }
    if is_google:
        out.update(
            {
                "avg_confidence": safe_round(raw.get("avg_confidence"), 4),
                "min_confidence": safe_round(raw.get("min_confidence"), 4),
                "max_confidence": safe_round(raw.get("max_confidence"), 4),
                "std_confidence": safe_round(raw.get("std_confidence"), 4),
                "high_conf_count": int(raw.get("high_conf_count", 0)),
                "high_conf_area_m2": round(float(raw.get("high_conf_area_m2", 0.0)), 2),
            }
        )
    return out


def consolidate_municipalities(
    mpio_docs: list[dict[str, Any]],
    ms_by_mpio: dict[str, dict[str, Any]],
    gg_by_mpio: dict[str, dict[str, Any]],
    cfg: WorkflowConfig,
    computed_at_iso: str,
) -> list[dict[str, Any]]:
    """Consolida los 170 municipios con consenso híbrido, potencial solar y rankings."""
    municipalities: list[dict[str, Any]] = []
    for m in mpio_docs:
        code = m["cod_dane_mpio"]
        area_km2 = float(m["area_oficial_km2"])
        ms_m = format_source_metrics(ms_by_mpio.get(code), is_google=False)
        gg_m = format_source_metrics(gg_by_mpio.get(code), is_google=True)

        ms_cnt, gg_cnt = ms_m["building_count"], gg_m["building_count"]
        ms_area, gg_area = ms_m["total_area_m2"], gg_m["total_area_m2"]

        if gg_m["has_coverage"]:
            consensus_strategy = "mean_ms_google"
            consensus_area_m2 = (ms_area + gg_area) / 2.0
            delta_count = gg_cnt - ms_cnt
            count_ratio = (gg_cnt / ms_cnt) if ms_cnt > 0 else None
            delta_area_m2 = gg_area - ms_area
            avg_both = (ms_area + gg_area) / 2.0
            delta_area_pct = (
                (abs(gg_area - ms_area) / avg_both * 100.0) if avg_both > 0 else None
            )
            signed_delta_area_pct = (
                ((gg_area - ms_area) / ms_area * 100.0) if ms_area > 0 else None
            )
        else:
            consensus_strategy = "microsoft_only_fallback"
            consensus_area_m2 = ms_area
            delta_count = count_ratio = delta_area_m2 = None
            delta_area_pct = signed_delta_area_pct = None

        density_pct = (
            (consensus_area_m2 / (area_km2 * 1e6) * 100.0) if area_km2 > 0 else 0.0
        )
        density_m2_km2 = (consensus_area_m2 / area_km2) if area_km2 > 0 else 0.0

        usable_m2 = consensus_area_m2 * cfg.utilization_factor
        usable_ms_m2 = ms_area * cfg.utilization_factor
        usable_gg_m2 = gg_area * cfg.utilization_factor
        cap_kwp = usable_m2 * cfg.power_density
        cap_ms_kwp = usable_ms_m2 * cfg.power_density
        cap_gg_kwp = usable_gg_m2 * cfg.power_density
        gen_gwh = cap_kwp * cfg.specific_yield / 1e6

        municipalities.append(
            {
                "cod_dane_mpio": code,
                "cod_dane_dpto": m["cod_dane_dpto"],
                "municipio": m["municipio"],
                "departamento": m["departamento"],
                "subregion_pdet": m["subregion_pdet"],
                "area_oficial_km2": round(area_km2, 4),
                "bbox": m.get("bbox"),
                "metrics_microsoft": ms_m,
                "metrics_google": gg_m,
                "comparison_metrics": {
                    "delta_count": delta_count,
                    "count_ratio_g_to_ms": safe_round(count_ratio, 4),
                    "delta_area_m2": safe_round(delta_area_m2, 2),
                    "delta_area_pct": safe_round(delta_area_pct, 2),
                    "signed_delta_area_pct": safe_round(signed_delta_area_pct, 2),
                    "consensus_strategy": consensus_strategy,
                    "consensus_area_m2": round(consensus_area_m2, 2),
                    "consensus_area_ha": round(consensus_area_m2 / 1e4, 4),
                    "consensus_area_km2": round(consensus_area_m2 / 1e6, 6),
                    "rooftop_density_pct": round(density_pct, 6),
                    "rooftop_density_m2_per_km2": round(density_m2_km2, 2),
                },
                "solar_potential": {
                    "usable_roof_m2": round(usable_m2, 2),
                    "usable_roof_m2_ms": round(usable_ms_m2, 2),
                    "usable_roof_m2_google": round(usable_gg_m2, 2),
                    "est_capacity_kwp": round(cap_kwp, 2),
                    "est_capacity_mwp": round(cap_kwp / 1000.0, 4),
                    "est_capacity_mwp_ms": round(cap_ms_kwp / 1000.0, 4),
                    "est_capacity_mwp_google": round(cap_gg_kwp / 1000.0, 4),
                    "est_annual_generation_gwh": round(gen_gwh, 4),
                    "priority_rank": 0,
                    "priority_rank_ms": 0,
                    "priority_rank_google": None,
                    "priority_rank_density": 0,
                },
                "computed_at": computed_at_iso,
            }
        )

    _assign_priority_rankings(municipalities)
    municipalities.sort(key=lambda x: x["solar_potential"]["priority_rank"])
    return municipalities


def _assign_priority_rankings(municipalities: list[dict[str, Any]]) -> None:
    """Asigna rankings determinísticos (desempate por `cod_dane_mpio`)."""
    specs = [
        (
            "priority_rank",
            municipalities,
            lambda x: (-x["solar_potential"]["est_capacity_kwp"], x["cod_dane_mpio"]),
        ),
        (
            "priority_rank_ms",
            municipalities,
            lambda x: (-x["metrics_microsoft"]["total_area_m2"], x["cod_dane_mpio"]),
        ),
        (
            "priority_rank_google",
            [x for x in municipalities if x["metrics_google"]["has_coverage"]],
            lambda x: (-x["metrics_google"]["total_area_m2"], x["cod_dane_mpio"]),
        ),
        (
            "priority_rank_density",
            municipalities,
            lambda x: (
                -x["comparison_metrics"]["rooftop_density_m2_per_km2"],
                x["cod_dane_mpio"],
            ),
        ),
    ]
    for field, subset, key_fn in specs:
        for rank, m in enumerate(sorted(subset, key=key_fn), start=1):
            m["solar_potential"][field] = rank


def aggregate_groups(
    municipalities: list[dict[str, Any]], key_fn, meta_fn
) -> list[dict[str, Any]]:
    """Agrega las métricas municipales por subregión PDET o departamento."""
    groups: dict[Any, dict[str, Any]] = {}
    for m in municipalities:
        gk = key_fn(m)
        if gk not in groups:
            groups[gk] = {
                **meta_fn(m),
                "municipalities_total": 0,
                "municipalities_google_covered": 0,
                "area_oficial_km2": 0.0,
                "ms_building_count": 0,
                "ms_total_area_m2": 0.0,
                "ms_plausible_area_m2": 0.0,
                "google_building_count": 0,
                "google_total_area_m2": 0.0,
                "google_plausible_area_m2": 0.0,
                "google_high_conf_area_m2": 0.0,
                "google_conf_weighted_sum": 0.0,
                "consensus_area_m2": 0.0,
                "usable_roof_m2": 0.0,
                "est_capacity_kwp": 0.0,
                "est_annual_generation_gwh": 0.0,
            }
        g = groups[gk]
        ms, gg = m["metrics_microsoft"], m["metrics_google"]
        cmp, sp = m["comparison_metrics"], m["solar_potential"]

        g["municipalities_total"] += 1
        if gg["has_coverage"]:
            g["municipalities_google_covered"] += 1
        g["area_oficial_km2"] += m["area_oficial_km2"]
        g["ms_building_count"] += ms["building_count"]
        g["ms_total_area_m2"] += ms["total_area_m2"]
        g["ms_plausible_area_m2"] += ms["plausible_area_m2"]
        g["google_building_count"] += gg["building_count"]
        g["google_total_area_m2"] += gg["total_area_m2"]
        g["google_plausible_area_m2"] += gg["plausible_area_m2"]
        g["google_high_conf_area_m2"] += gg["high_conf_area_m2"]
        if gg["has_coverage"] and gg["avg_confidence"] is not None:
            g["google_conf_weighted_sum"] += gg["avg_confidence"] * gg["building_count"]
        g["consensus_area_m2"] += cmp["consensus_area_m2"]
        g["usable_roof_m2"] += sp["usable_roof_m2"]
        g["est_capacity_kwp"] += sp["est_capacity_kwp"]
        g["est_annual_generation_gwh"] += sp["est_annual_generation_gwh"]

    result = []
    for g in groups.values():
        ms_a, gg_a = g["ms_total_area_m2"], g["google_total_area_m2"]
        avg_a = (ms_a + gg_a) / 2.0 if (ms_a + gg_a) > 0 else 0.0
        delta_pct = (abs(gg_a - ms_a) / avg_a * 100.0) if avg_a > 0 else None
        signed_pct = ((gg_a - ms_a) / ms_a * 100.0) if ms_a > 0 else None
        avg_conf = (
            g["google_conf_weighted_sum"] / g["google_building_count"]
            if g["google_building_count"] > 0
            else None
        )
        area_km2 = g["area_oficial_km2"]
        density_pct = (
            (g["consensus_area_m2"] / (area_km2 * 1e6) * 100.0) if area_km2 > 0 else 0.0
        )

        rec = {k: v for k, v in g.items() if k != "google_conf_weighted_sum"}
        rec.update(
            {
                "area_oficial_km2": round(area_km2, 2),
                "ms_total_area_m2": round(ms_a, 2),
                "ms_total_area_km2": round(ms_a / 1e6, 4),
                "ms_total_area_ha": round(ms_a / 1e4, 2),
                "ms_avg_area_m2": round(ms_a / g["ms_building_count"], 2)
                if g["ms_building_count"]
                else None,
                "ms_plausible_area_km2": round(g["ms_plausible_area_m2"] / 1e6, 4),
                "google_total_area_m2": round(gg_a, 2),
                "google_total_area_km2": round(gg_a / 1e6, 4),
                "google_total_area_ha": round(gg_a / 1e4, 2),
                "google_avg_area_m2": round(gg_a / g["google_building_count"], 2)
                if g["google_building_count"]
                else None,
                "google_plausible_area_km2": round(
                    g["google_plausible_area_m2"] / 1e6, 4
                ),
                "google_high_conf_area_km2": round(
                    g["google_high_conf_area_m2"] / 1e6, 4
                ),
                "google_avg_confidence": safe_round(avg_conf, 4),
                "consensus_area_m2": round(g["consensus_area_m2"], 2),
                "consensus_area_km2": round(g["consensus_area_m2"] / 1e6, 4),
                "consensus_area_ha": round(g["consensus_area_m2"] / 1e4, 2),
                "delta_area_pct": safe_round(delta_pct, 2),
                "signed_delta_area_pct": safe_round(signed_pct, 2),
                "rooftop_density_pct": round(density_pct, 5),
                "rooftop_density_m2_per_km2": round(
                    g["consensus_area_m2"] / area_km2, 2
                )
                if area_km2 > 0
                else 0.0,
                "usable_roof_m2": round(g["usable_roof_m2"], 2),
                "usable_roof_km2": round(g["usable_roof_m2"] / 1e6, 4),
                "est_capacity_kwp": round(g["est_capacity_kwp"], 2),
                "est_capacity_mwp": round(g["est_capacity_kwp"] / 1000.0, 3),
                "est_annual_generation_gwh": round(g["est_annual_generation_gwh"], 3),
            }
        )
        result.append(rec)
    return result
