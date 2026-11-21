"""Gráficas analíticas de correlación, morfología, calidad y concentración (06–09)."""

from __future__ import annotations

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from workflow.charts.registry import (
    COLOR_CONS,
    COLOR_GG,
    COLOR_GRID,
    COLOR_MS,
    COLOR_NAVY,
    COLOR_SLATE,
    ChartContext,
    register_chart,
    title_case_es,
)


@register_chart(
    "06_ms_vs_google_correlation",
    title="Análisis de Correlación y Convergencia Microsoft vs. Google (n=165)",
    description="Dispersión log-log de área total (km²) y conteo de edificaciones por municipio con línea de identidad, banda ±20% y estadísticos de acuerdo.",
    category="comparison",
)
def chart_correlation(ctx: ChartContext) -> plt.Figure:
    df = ctx.df_mpios[ctx.df_mpios["google_has_coverage"] == True].copy()
    agr = ctx.data["global_summary"]["agreement"]

    fig, axes = plt.subplots(1, 2, figsize=(14.5, 6.4), constrained_layout=True)

    # Panel A: Área total (km²)
    ax = axes[0]
    x = df["ms_total_area_km2"].to_numpy()
    y = df["google_total_area_km2"].to_numpy()
    lo, hi = 0.03, max(x.max(), y.max()) * 1.4
    grid = np.logspace(np.log10(lo), np.log10(hi), 200)
    ax.fill_between(
        grid,
        grid * 0.8,
        grid * 1.2,
        color="#DCFCE7",
        alpha=0.65,
        label="Banda ±20% de acuerdo",
    )
    ax.plot(
        grid,
        grid,
        linestyle="--",
        color="#1E293B",
        linewidth=1.2,
        label="Identidad perfecta (y = x)",
    )

    sc = ax.scatter(
        x,
        y,
        c=df["google_avg_confidence"],
        cmap="plasma",
        s=36,
        alpha=0.88,
        edgecolors="#1E293B",
        linewidth=0.45,
        zorder=4,
    )
    cb = fig.colorbar(sc, ax=ax, fraction=0.046, pad=0.03)
    cb.set_label("Confianza media Google", fontsize=9)

    for code, dx, dy in [
        ("47001", -52, 7),
        ("20001", -48, -14),
        ("76109", 6, -12),
        ("18001", -42, 6),
        ("05837", -35, 10),
        ("52835", 6, -12),
    ]:
        row = df[df["cod_dane_mpio"] == code]
        if not row.empty:
            r0 = row.iloc[0]
            ax.annotate(
                title_case_es(r0["municipio"]).replace("San Andrés de ", ""),
                xy=(r0["ms_total_area_km2"], r0["google_total_area_km2"]),
                xytext=(dx, dy),
                textcoords="offset points",
                fontsize=8,
                fontweight="bold",
                color=COLOR_NAVY,
            )

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(lo, hi)
    ax.set_ylim(lo, hi)
    ax.set_xlabel("Área total Microsoft (km², escala log)")
    ax.set_ylabel("Área total Google (km², escala log)")
    ax.set_title("Área Total de Techos por Municipio (n = 165)")
    ax.grid(True, which="major", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.legend(loc="upper left", fontsize=8.8, framealpha=0.95)
    ax.text(
        0.97,
        0.04,
        f"Pearson r = {agr['area_pearson_r']:.4f} (R² = {agr['area_r_squared']:.4f})\n"
        f"Spearman ρ = {agr['area_spearman_rho']:.4f}\n"
        f"Discrepancia mediana = {agr['area_median_rel_discrepancy_pct']:.1f}%\n"
        f"Dentro de ±20%: {agr['area_within_20pct_count']}/165 ({agr['area_within_20pct_share']:.1f}%)",
        transform=ax.transAxes,
        ha="right",
        va="bottom",
        fontsize=8.6,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec="#94A3B8", alpha=0.95),
    )

    # Panel B: Conteo de edificaciones
    ax = axes[1]
    xc = df["ms_building_count"].to_numpy()
    yc = df["google_building_count"].to_numpy()
    loc, hic = 200, max(xc.max(), yc.max()) * 1.5
    gridc = np.logspace(np.log10(loc), np.log10(hic), 200)
    med_ratio = agr["count_ratio_median_g_to_ms"]
    ax.plot(
        gridc,
        gridc,
        linestyle="--",
        color="#1E293B",
        linewidth=1.2,
        label="Identidad (1:1)",
    )
    ax.plot(
        gridc,
        gridc * med_ratio,
        linestyle="-.",
        color=COLOR_GG,
        linewidth=1.3,
        label=f"Razón mediana ({med_ratio:.2f}× Google/MS)",
    )
    ax.scatter(
        xc,
        yc,
        color=COLOR_MS,
        s=34,
        alpha=0.78,
        edgecolors="#0F172A",
        linewidth=0.4,
        zorder=4,
    )
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(loc, hic)
    ax.set_ylim(loc, hic)
    ax.set_xlabel("Edificaciones detectadas Microsoft (escala log)")
    ax.set_ylabel("Edificaciones detectadas Google (escala log)")
    ax.set_title("Conteo de Edificaciones por Municipio (n = 165)")
    ax.grid(True, which="major", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.legend(loc="upper left", fontsize=8.8, framealpha=0.95)
    ax.text(
        0.97,
        0.04,
        f"Pearson r = {agr['count_pearson_r']:.4f}\n"
        f"Spearman ρ = {agr['count_spearman_rho']:.4f}\n"
        f"Razón global Google/MS = 1.53×\n"
        f"(Google segmenta micro-techos)",
        transform=ax.transAxes,
        ha="right",
        va="bottom",
        fontsize=8.6,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec="#94A3B8", alpha=0.95),
    )

    fig.suptitle(
        "Validación Cruzada entre Microsoft Building Footprints y Google Open Buildings",
        fontsize=14,
        fontweight="bold",
    )
    return fig


@register_chart(
    "07_roof_size_strata",
    title="Distribución Morfológica por Estratos de Tamaño de Cubierta",
    description="Contraste entre participación en número de edificaciones (%) y aporte al área total de techos (%) según tamaño de cubierta.",
    category="morphology",
)
def chart_size_strata(ctx: ChartContext) -> plt.Figure:
    strata = pd.DataFrame(ctx.data["size_strata_summary"])
    x = np.arange(len(strata))
    w = 0.36

    fig, axes = plt.subplots(1, 2, figsize=(14.0, 5.8), constrained_layout=True)

    # Panel A: % del número de edificios
    ax = axes[0]
    b1 = ax.bar(
        x - w / 2,
        strata["ms_pct_count"],
        width=w,
        color=COLOR_MS,
        label="Microsoft",
        alpha=0.92,
    )
    b2 = ax.bar(
        x + w / 2,
        strata["google_pct_count"],
        width=w,
        color=COLOR_GG,
        label="Google",
        alpha=0.92,
    )
    ax.set_xticks(x)
    ax.set_xticklabels(strata["label"], fontsize=9.2)
    ax.set_ylabel("Participación en el conteo de edificaciones (%)")
    ax.set_title("Distribución por Número de Edificaciones (%)")
    ax.set_ylim(
        0, max(strata["ms_pct_count"].max(), strata["google_pct_count"].max()) * 1.2
    )
    ax.grid(axis="y", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    for b in list(b1) + list(b2):
        h = b.get_height()
        ax.text(
            b.get_x() + b.get_width() / 2,
            h + 0.7,
            f"{h:.1f}%",
            ha="center",
            va="bottom",
            fontsize=8.2,
        )
    ax.legend(framealpha=0.95)

    # Panel B: % del área total acumulada (y km²)
    ax = axes[1]
    b3 = ax.bar(
        x - w / 2,
        strata["ms_pct_area"],
        width=w,
        color=COLOR_MS,
        label="Microsoft",
        alpha=0.92,
    )
    b4 = ax.bar(
        x + w / 2,
        strata["google_pct_area"],
        width=w,
        color=COLOR_GG,
        label="Google",
        alpha=0.92,
    )
    ax.set_xticks(x)
    ax.set_xticklabels(strata["label"], fontsize=9.2)
    ax.set_ylabel("Participación en el área total de techos (%)")
    ax.set_title("Contribución al Área Total de Captación Solar (%)")
    ax.set_ylim(
        0, max(strata["ms_pct_area"].max(), strata["google_pct_area"].max()) * 1.24
    )
    ax.grid(axis="y", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    for b, km2 in zip(b3, strata["ms_total_area_km2"]):
        h = b.get_height()
        ax.text(
            b.get_x() + b.get_width() / 2,
            h + 0.7,
            f"{h:.1f}%\n({km2:.1f} km²)",
            ha="center",
            va="bottom",
            fontsize=7.5,
            color=COLOR_MS,
        )
    for b, km2 in zip(b4, strata["google_total_area_km2"]):
        h = b.get_height()
        ax.text(
            b.get_x() + b.get_width() / 2 + 0.04,
            h + 0.7,
            f"{h:.1f}%\n({km2:.1f} km²)",
            ha="center",
            va="bottom",
            fontsize=7.0,
            color=COLOR_GG,
        )
    ax.legend(framealpha=0.95)

    fig.suptitle(
        "Morfología de Cubiertas PDET: Conteo de Estructuras vs. Aporte Real al Área Solar",
        fontsize=13.8,
        fontweight="bold",
    )
    return fig


@register_chart(
    "08_google_confidence_and_filters",
    title="Distribución de Confianza (Google) y Sensibilidad a Filtros de Calidad",
    description="Histograma de puntaje de confianza en Google Open Buildings y comparación de área retenida bajo RN-04, RN-05 y umbral de alta certeza (>=0.75).",
    category="quality",
)
def chart_confidence_and_filters(ctx: ChartContext) -> plt.Figure:
    conf = pd.DataFrame(ctx.data["google_confidence_bins"])
    gs = ctx.data["global_summary"]

    fig, axes = plt.subplots(1, 2, figsize=(14.2, 5.8), constrained_layout=True)

    # Panel A: Confianza Google (conteo y área)
    ax = axes[0]
    x = np.arange(len(conf))
    colors = ["#F59E0B" if lb < 0.75 else "#059669" for lb in conf["lower_bound"]]
    bars = ax.bar(
        x,
        conf["total_area_km2"],
        color=colors,
        edgecolor="#1E293B",
        linewidth=0.5,
        alpha=0.9,
    )
    ax.axvline(
        1.5,
        color="#DC2626",
        linestyle="--",
        linewidth=1.3,
        label="Umbral alta certeza (0.75)",
    )
    ax.set_xticks(x)
    ax.set_xticklabels(conf["label"], fontsize=9)
    ax.set_xlabel("Rango de puntaje de confianza (Google V3)")
    ax.set_ylabel("Área total de techos (km²)")
    ax.set_title("Área de Techos por Nivel de Confianza en Google")
    ax.set_ylim(0, conf["total_area_km2"].max() * 1.24)
    ax.grid(axis="y", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    for b, row in zip(bars, conf.itertuples()):
        h = b.get_height()
        ax.text(
            b.get_x() + b.get_width() / 2,
            h + 1.0,
            f"{h:.1f} km²\n({row.pct_area:.1f}%)",
            ha="center",
            va="bottom",
            fontsize=8,
        )
    p_mod = mpatches.Patch(color="#F59E0B", label="Confianza moderada (0.65–0.75)")
    p_hi = mpatches.Patch(
        color="#059669",
        label=f"Alta confianza ≥ 0.75 ({gs['google']['high_conf_pct_area']:.1f}% del área)",
    )
    ax.legend(handles=[p_mod, p_hi], loc="upper right", fontsize=8.4, framealpha=0.95)

    # Panel B: Sensibilidad a reglas de negocio RN-04 / RN-05
    ax = axes[1]
    scenarios = [
        ("Microsoft\n(Bruto 100%)", gs["microsoft"]["total_area_km2"], COLOR_MS),
        (
            "Microsoft\n(RN-05: 10–20k m²)",
            gs["microsoft"]["plausible_rn05_area_km2"],
            "#60A5FA",
        ),
        ("Google\n(Bruto ≥0.65)", gs["google"]["total_area_km2"], COLOR_GG),
        ("Google\n(RN-04+05)", gs["google"]["plausible_rn04_rn05_area_km2"], "#FB923C"),
        ("Google\n(Alta Conf. ≥0.75)", gs["google"]["high_conf_area_km2"], "#F59E0B"),
        (
            "Consenso Híbrido\n(Recomendado)",
            gs["hybrid_consensus"]["total_area_km2"],
            COLOR_CONS,
        ),
    ]
    sx = np.arange(len(scenarios))
    vals = [s[1] for s in scenarios]
    scols = [s[2] for s in scenarios]
    sbars = ax.bar(
        sx, vals, color=scols, edgecolor="#1E293B", linewidth=0.5, alpha=0.92
    )
    ax.set_xticks(sx)
    ax.set_xticklabels([s[0] for s in scenarios], fontsize=8.3)
    ax.set_ylabel("Área total estimada de techos (km²)")
    ax.set_title("Sensibilidad del Área Total frente a Reglas de Calidad")
    ax.set_ylim(0, max(vals) * 1.18)
    ax.grid(axis="y", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    for b, v in zip(sbars, vals):
        ax.text(
            b.get_x() + b.get_width() / 2,
            v + 3.0,
            f"{v:.2f}\nkm²",
            ha="center",
            va="bottom",
            fontsize=8.3,
            fontweight="bold",
        )

    fig.suptitle(
        "Auditoría de Confianza Satelital y Estabilidad ante Filtros de Calidad (RN-04 / RN-05)",
        fontsize=13.5,
        fontweight="bold",
    )
    return fig


@register_chart(
    "09_pareto_concentration",
    title="Curva de Concentración (Pareto) del Potencial Solar en Municipios PDET",
    description="Porcentaje acumulado del área total de cubiertas al priorizar municipios del 1 al 170, indicando umbrales del 50% y 80%.",
    category="strategy",
)
def chart_pareto_concentration(ctx: ChartContext) -> plt.Figure:
    df = ctx.df_mpios.sort_values("priority_rank").copy()
    n = len(df)
    ranks = np.arange(1, n + 1)
    cum_cons = np.cumsum(df["consensus_area_km2"].to_numpy())
    cum_pct = cum_cons / cum_cons[-1] * 100.0
    cum_mwp = np.cumsum(df["est_capacity_mwp"].to_numpy()) / 1000.0  # GWp

    conc = ctx.data["global_summary"]["concentration"]
    n50 = conc["municipalities_for_50pct_area"]
    n80 = conc["municipalities_for_80pct_area"]

    fig, ax1 = plt.subplots(figsize=(11.5, 6.0), constrained_layout=True)

    ax1.fill_between(ranks, 0, cum_pct, color="#D1FAE5", alpha=0.55)
    ax1.plot(
        ranks,
        cum_pct,
        color=COLOR_CONS,
        linewidth=2.4,
        label="% acumulado de área de techos (Consenso)",
    )
    ax1.plot(
        [1, n],
        [100.0 / n, 100.0],
        linestyle=":",
        color="#64748B",
        linewidth=1.2,
        label="Distribución uniforme (igualdad perfecta)",
    )

    for target, n_req, col in [(50, n50, COLOR_MS), (80, n80, COLOR_GG)]:
        ax1.axhline(target, color=col, linestyle="--", linewidth=1.0, alpha=0.75)
        ax1.axvline(n_req, color=col, linestyle="--", linewidth=1.0, alpha=0.75)
        ax1.scatter(
            [n_req], [cum_pct[n_req - 1]], color=col, s=60, zorder=5, edgecolors="white"
        )
        ax1.annotate(
            f"{target}% del potencial\nen solo {n_req} municipios\n({n_req / n * 100:.1f}% del total)",
            xy=(n_req, cum_pct[n_req - 1]),
            xytext=(n_req + 10, target - 14),
            fontsize=8.8,
            fontweight="bold",
            color=col,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=col, alpha=0.95),
            arrowprops=dict(arrowstyle="->", color=col, lw=1.0),
        )

    ax1.set_xlim(1, n)
    ax1.set_ylim(0, 104)
    ax1.set_xlabel(
        "Municipios PDET ordenados por prioridad solar (1 = mayor potencial → 170)"
    )
    ax1.set_ylabel("Porcentaje acumulado del área total de techos (%)")
    ax1.grid(True, linestyle="--", color=COLOR_GRID, alpha=0.8)

    ax2 = ax1.twinx()
    ax2.set_ylim(0, cum_mwp[-1] * 1.04)
    ax2.set_ylabel("Capacidad fotovoltaica acumulada estimada (GWp)", color=COLOR_SLATE)
    ax2.tick_params(axis="y", colors=COLOR_SLATE)

    ax1.legend(loc="lower right", framealpha=0.95)
    ax1.text(
        0.98,
        0.24,
        f"Índice de Gini territorial: {conc['gini_consensus_area']:.3f}\n"
        f"• Top 5 mpios: {conc['top5_share_pct']:.1f}%\n"
        f"• Top 10 mpios: {conc['top10_share_pct']:.1f}%\n"
        f"• Top 20 mpios: {conc['top20_share_pct']:.1f}%",
        transform=ax1.transAxes,
        ha="right",
        va="bottom",
        fontsize=8.8,
        bbox=dict(boxstyle="round,pad=0.35", fc="white", ec="#94A3B8", alpha=0.95),
    )

    ax1.set_title(
        "Curva de Concentración (Pareto) para Focalización de Proyectos Piloto UPME",
        pad=12,
    )
    return fig
