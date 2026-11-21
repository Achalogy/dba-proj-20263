"""Gráficas comparativas de subregiones PDET y ranking Top 15 (gráficas 04 y 05)."""

from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np

from workflow.charts.registry import (
    COLOR_CONS,
    COLOR_GG,
    COLOR_GRID,
    COLOR_MS,
    COLOR_NAVY,
    ChartContext,
    register_chart,
    title_case_es,
)


@register_chart(
    "04_subregions_comparison",
    title="Comparativa Microsoft vs. Google en las 16 Subregiones PDET",
    description="Barras horizontales pareadas de área total de cubiertas (km²) y conteo de edificaciones (miles) por subregión PDET.",
    category="subregions",
)
def chart_subregions_comparison(ctx: ChartContext) -> plt.Figure:
    df = ctx.df_subregions.sort_values("consensus_area_km2", ascending=True).copy()
    labels = [
        f"{title_case_es(n)} ({int(m)} mpios)"
        for n, m in zip(df["subregion_nombre"], df["municipalities_total"])
    ]
    y = np.arange(len(df))
    h = 0.37

    fig, axes = plt.subplots(
        1, 2, figsize=(15.5, 8.2), sharey=True, constrained_layout=True
    )

    # Panel A: Área total (km²)
    ax = axes[0]
    b1 = ax.barh(
        y + h / 2,
        df["ms_total_area_km2"],
        height=h,
        color=COLOR_MS,
        label="Microsoft Buildings",
        alpha=0.92,
    )
    b2 = ax.barh(
        y - h / 2,
        df["google_total_area_km2"],
        height=h,
        color=COLOR_GG,
        label="Google Open Buildings",
        alpha=0.92,
    )
    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=9.2)
    ax.set_xlabel("Área total de techos (km²)")
    ax.set_title("Área Total de Cubiertas por Subregión (km²)")
    ax.grid(axis="x", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    ax.set_xlim(
        0, df[["ms_total_area_km2", "google_total_area_km2"]].max().max() * 1.18
    )
    for bar in b1:
        w = bar.get_width()
        ax.text(
            w + 0.5,
            bar.get_y() + bar.get_height() / 2,
            f"{w:.1f}",
            va="center",
            fontsize=7.8,
            color=COLOR_MS,
        )
    for bar in b2:
        w = bar.get_width()
        ax.text(
            w + 0.5,
            bar.get_y() + bar.get_height() / 2,
            f"{w:.1f}",
            va="center",
            fontsize=7.8,
            color=COLOR_GG,
        )
    ax.legend(loc="lower right", frameon=True, framealpha=0.95)

    # Panel B: Conteo de edificaciones (miles)
    ax = axes[1]
    ms_k = df["ms_building_count"] / 1000.0
    gg_k = df["google_building_count"] / 1000.0
    b3 = ax.barh(
        y + h / 2,
        ms_k,
        height=h,
        color=COLOR_MS,
        label="Microsoft Buildings",
        alpha=0.92,
    )
    b4 = ax.barh(
        y - h / 2,
        gg_k,
        height=h,
        color=COLOR_GG,
        label="Google Open Buildings",
        alpha=0.92,
    )
    ax.set_xlabel("Edificaciones detectadas (miles)")
    ax.set_title("Número de Edificaciones por Subregión (miles)")
    ax.grid(axis="x", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    ax.set_xlim(0, max(ms_k.max(), gg_k.max()) * 1.18)
    for bar in b3:
        w = bar.get_width()
        ax.text(
            w + 5,
            bar.get_y() + bar.get_height() / 2,
            f"{w:.0f}k",
            va="center",
            fontsize=7.8,
            color=COLOR_MS,
        )
    for bar in b4:
        w = bar.get_width()
        ax.text(
            w + 5,
            bar.get_y() + bar.get_height() / 2,
            f"{w:.0f}k",
            va="center",
            fontsize=7.8,
            color=COLOR_GG,
        )

    fig.suptitle(
        "Balance Comparativo de Área y Conteo de Techos en las 16 Subregiones PDET",
        fontsize=14,
        fontweight="bold",
    )
    return fig


@register_chart(
    "05_top15_municipalities",
    title="Top 15 Municipios PDET por Área de Techos y Potencial Solar (MWp)",
    description="Ranking de los 15 municipios PDET prioritarios comparando área estimada por Microsoft, Google y capacidad fotovoltaica de consenso.",
    category="rankings",
)
def chart_top15_municipalities(ctx: ChartContext) -> plt.Figure:
    df = ctx.df_mpios.nsmallest(15, "priority_rank").iloc[::-1].copy()
    labels = [
        f"#{int(r)} {title_case_es(m)} ({title_case_es(d)})"
        for r, m, d in zip(df["priority_rank"], df["municipio"], df["departamento"])
    ]
    y = np.arange(len(df))
    h = 0.38

    fig, ax = plt.subplots(figsize=(12.5, 7.8), constrained_layout=True)
    ax.barh(
        y + h / 2,
        df["ms_total_area_km2"],
        height=h,
        color=COLOR_MS,
        label="Microsoft Buildings (km²)",
        alpha=0.92,
    )
    ax.barh(
        y - h / 2,
        df["google_total_area_km2"],
        height=h,
        color=COLOR_GG,
        label="Google Open Buildings (km²)",
        alpha=0.92,
    )

    ax.scatter(
        df["consensus_area_km2"],
        y,
        color=COLOR_CONS,
        s=55,
        zorder=5,
        edgecolors="white",
        linewidth=0.8,
        label="Área Consenso Híbrido (km²)",
    )

    max_x = max(df["ms_total_area_km2"].max(), df["google_total_area_km2"].max())
    for yi, (_, row) in zip(y, df.iterrows()):
        x_pos = max(row["ms_total_area_km2"], row["google_total_area_km2"]) + 0.25
        ax.text(
            x_pos,
            yi,
            f"{row['consensus_area_km2']:.2f} km²  |  ~{row['est_capacity_mwp']:.0f} MWp",
            va="center",
            fontsize=8.6,
            fontweight="bold",
            color=COLOR_NAVY,
        )

    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=9.3)
    ax.set_xlabel("Área total de techos estimada (km²)")
    ax.set_xlim(0, max_x * 1.36)
    ax.grid(axis="x", linestyle="--", color=COLOR_GRID, alpha=0.8)
    ax.set_axisbelow(True)
    ax.legend(loc="lower right", frameon=True, framealpha=0.95)

    conc = ctx.data["global_summary"]["concentration"]
    ax.set_title(
        "Top 15 Municipios PDET Prioritarios para Proyectos Solares en Cubiertas\n"
        f"El Top 10 concentra el {conc['top10_share_pct']:.1f}% del área total de techos PDET "
        f"(Top 20: {conc['top20_share_pct']:.1f}%)",
        pad=12,
    )
    return fig
