"""Mapas coropléticos nacionales PDET (gráficas 01, 02 y 03)."""

from __future__ import annotations

import matplotlib.colors as mcolors
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

from workflow.charts.registry import (
    COLOR_MISSING,
    COLOR_NAVY,
    ChartContext,
    register_chart,
    style_map_axes,
    title_case_es,
)


@register_chart(
    "01_map_pdet_rooftop_area",
    title="Mapa Coroplético de Área Total de Techos (Microsoft vs. Google)",
    description="Comparación espacial de la superficie total de cubiertas (km², escala logarítmica) en los 170 municipios PDET.",
    category="maps",
)
def chart_map_rooftop_area(ctx: ChartContext) -> plt.Figure:
    gdf = ctx.gdf
    bounds = tuple(gdf.total_bounds)
    fig, axes = plt.subplots(1, 2, figsize=(14.5, 8.2), constrained_layout=True)

    vmin = 0.05
    vmax = max(gdf["ms_total_area_km2"].max(), gdf["google_total_area_km2"].max())
    norm = mcolors.LogNorm(vmin=vmin, vmax=vmax)
    cmap = plt.get_cmap("YlOrRd")

    # Panel A: Microsoft
    ax = axes[0]
    gdf.plot(
        column="ms_total_area_km2",
        cmap=cmap,
        norm=norm,
        linewidth=0.35,
        edgecolor="#334155",
        ax=ax,
    )
    style_map_axes(ax, bounds)
    ms_sum = ctx.data["global_summary"]["microsoft"]
    ax.set_title(
        f"Microsoft Building Footprints\n"
        f"170/170 municipios | {ms_sum['total_area_km2']:.2f} km² ({ms_sum['building_count']:,} techos)",
        pad=10,
    )

    # Panel B: Google
    ax = axes[1]
    covered = gdf[gdf["google_has_coverage"] == True]
    missing = gdf[gdf["google_has_coverage"] == False]
    covered.plot(
        column="google_total_area_km2",
        cmap=cmap,
        norm=norm,
        linewidth=0.35,
        edgecolor="#334155",
        ax=ax,
    )
    if not missing.empty:
        missing.plot(
            color=COLOR_MISSING,
            edgecolor="#DC2626",
            linewidth=0.8,
            hatch="////",
            ax=ax,
        )
        missing_patch = mpatches.Patch(
            facecolor=COLOR_MISSING,
            edgecolor="#DC2626",
            hatch="////",
            label="Sin inferencia en Google (5 mpios Chocó/Antioquia)",
        )
        ax.legend(
            handles=[missing_patch],
            loc="lower left",
            fontsize=8.5,
            framealpha=0.95,
            edgecolor="#CBD5E1",
        )
    style_map_axes(ax, bounds)
    gg_sum = ctx.data["global_summary"]["google"]
    ax.set_title(
        f"Google Open Buildings V3\n"
        f"165/170 municipios | {gg_sum['total_area_km2']:.2f} km² ({gg_sum['building_count']:,} techos)",
        pad=10,
    )

    # Barra de color compartida
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])
    cbar = fig.colorbar(
        sm, ax=axes, orientation="horizontal", fraction=0.04, pad=0.03, aspect=42
    )
    cbar.set_label(
        "Área total de techos por municipio (km², escala logarítmica)", fontsize=10.5
    )
    cbar.set_ticks([0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 15])
    cbar.ax.xaxis.set_major_formatter(mticker.FormatStrFormatter("%g"))

    fig.suptitle(
        "Distribución Espacial del Área de Techos en los 170 Municipios PDET de Colombia",
        fontsize=14.5,
        fontweight="bold",
    )
    return fig


@register_chart(
    "02_map_pdet_solar_potential",
    title="Mapa de Potencial Solar Fotovoltaico Estimado (MWp) en Municipios PDET",
    description="Capacidad fotovoltaica instalable estimada (consenso híbrido MS-Google) destacando los municipios prioritarios para pilotos UPME.",
    category="maps",
)
def chart_map_solar_potential(ctx: ChartContext) -> plt.Figure:
    gdf = ctx.gdf.copy()
    bounds = tuple(gdf.total_bounds)
    fig, ax = plt.subplots(figsize=(9.5, 10.2), constrained_layout=True)

    vmin = max(2.0, float(gdf["est_capacity_mwp"].min()))
    vmax = float(gdf["est_capacity_mwp"].max())
    norm = mcolors.LogNorm(vmin=vmin, vmax=vmax)
    cmap = plt.get_cmap("magma_r")

    gdf.plot(
        column="est_capacity_mwp",
        cmap=cmap,
        norm=norm,
        linewidth=0.4,
        edgecolor="#334155",
        ax=ax,
    )

    # Anotar los 8 principales municipios prioritarios con desplazamientos curados sin solapamiento
    label_offsets = {
        "47001": (-2.1, 0.9),  # Santa Marta
        "20001": (1.2, 0.7),  # Valledupar
        "76109": (-2.4, 0.2),  # Buenaventura
        "18001": (-0.6, -1.65),  # Florencia
        "05837": (-2.3, 0.4),  # Turbo
        "52835": (-2.1, 0.75),  # Tumaco
        "19698": (1.5, 0.3),  # Santander de Quilichao
        "47189": (-2.3, -0.3),  # Ciénaga
    }

    top8 = gdf.nsmallest(8, "priority_rank")
    for _, row in top8.iterrows():
        code = row["cod_dane_mpio"]
        pt = row.geometry.representative_point()
        dx, dy = label_offsets.get(code, (1.0, 0.5))
        name = title_case_es(row["municipio"]).replace("San Andrés de ", "")
        txt = (
            f"#{int(row['priority_rank'])} {name}\n({row['est_capacity_mwp']:.0f} MWp)"
        )
        ax.annotate(
            txt,
            xy=(pt.x, pt.y),
            xytext=(pt.x + dx, pt.y + dy),
            fontsize=8.2,
            fontweight="bold",
            color=COLOR_NAVY,
            bbox=dict(
                boxstyle="round,pad=0.25", fc="white", ec="#64748B", alpha=0.92, lw=0.7
            ),
            arrowprops=dict(
                arrowstyle="->", color="#334155", lw=0.85, shrinkA=2, shrinkB=2
            ),
        )

    style_map_axes(ax, bounds)
    minx, miny, maxx, maxy = bounds
    ax.set_xlim(minx - 2.6, maxx + 2.1)
    ax.set_ylim(miny - 1.2, maxy + 1.5)

    sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=ax, fraction=0.032, pad=0.02)
    cbar.set_label(
        "Potencial fotovoltaico instalable estimado (MWp, escala log)", fontsize=10
    )
    cbar.set_ticks([5, 10, 25, 50, 100, 250, 500, 1000])
    cbar.ax.yaxis.set_major_formatter(mticker.FormatStrFormatter("%g"))

    hc = ctx.data["global_summary"]["hybrid_consensus"]
    assump = ctx.data["metadata"]["assumptions"]
    kpi_box = (
        f"Síntesis Nacional PDET (170 mpios)\n"
        f"• Área consenso: {hc['total_area_km2']:.2f} km²\n"
        f"• Área útil ({assump['utilization_factor'] * 100:.0f}%): {hc['usable_roof_km2']:.2f} km²\n"
        f"• Capacidad est.: {hc['est_capacity_gwp']:.2f} GWp\n"
        f"• Generación ref.: {hc['est_annual_generation_twh']:.2f} TWh/año"
    )
    ax.text(
        0.02,
        0.02,
        kpi_box,
        transform=ax.transAxes,
        fontsize=8.8,
        verticalalignment="bottom",
        bbox=dict(
            boxstyle="round,pad=0.45", fc="white", ec="#1E293B", alpha=0.94, lw=0.9
        ),
    )

    ax.set_title(
        "Potencial Solar Fotovoltaico en Techos — Municipios PDET (Consenso Híbrido)\n"
        f"Supuestos: factor útil {assump['utilization_factor'] * 100:.0f}%, "
        f"{assump['power_density_kwp_per_m2'] * 1000:.0f} Wp/m², "
        f"rendimiento ref. {assump['specific_yield_kwh_per_kwp_year']:.0f} kWh/kWp·año",
        pad=12,
    )
    return fig


@register_chart(
    "03_map_pdet_density_and_discrepancy",
    title="Mapa de Densidad de Cubiertas y Discrepancia Relativa (Google vs. Microsoft)",
    description="Densidad de área de techos respecto a la superficie municipal (m²/km²) y sesgo geográfico entre Microsoft y Google.",
    category="maps",
)
def chart_map_density_and_discrepancy(ctx: ChartContext) -> plt.Figure:
    gdf = ctx.gdf.copy()
    bounds = tuple(gdf.total_bounds)
    fig, axes = plt.subplots(1, 2, figsize=(14.5, 8.2), constrained_layout=True)

    # Panel A: Densidad de cubiertas (m² de techo / km² municipal)
    ax = axes[0]
    dens_vals = gdf["rooftop_density_m2_per_km2"].clip(lower=10.0)
    norm_d = mcolors.LogNorm(vmin=float(dens_vals.min()), vmax=float(dens_vals.max()))
    cmap_d = plt.get_cmap("viridis")
    gdf.assign(_dens=dens_vals).plot(
        column="_dens",
        cmap=cmap_d,
        norm=norm_d,
        linewidth=0.35,
        edgecolor="#334155",
        ax=ax,
    )
    style_map_axes(ax, bounds)
    sm_d = plt.cm.ScalarMappable(cmap=cmap_d, norm=norm_d)
    sm_d.set_array([])
    cb_d = fig.colorbar(sm_d, ax=ax, orientation="horizontal", fraction=0.042, pad=0.04)
    cb_d.set_label(
        "Densidad de techos (m² de techo por km² municipal, log)", fontsize=9.5
    )
    ax.set_title(
        "Densidad Superficial de Cubiertas\n(Intensidad edificada respecto al área DANE)",
        pad=10,
    )

    # Panel B: Discrepancia con signo (Google - MS) / MS %
    ax = axes[1]
    covered = gdf[gdf["google_has_coverage"] == True].copy()
    missing = gdf[gdf["google_has_coverage"] == False]
    covered["_clipped_diff"] = covered["signed_delta_area_pct"].clip(-60, 60)
    norm_b = mcolors.TwoSlopeNorm(vmin=-60, vcenter=0, vmax=60)
    cmap_b = plt.get_cmap("RdBu_r")
    covered.plot(
        column="_clipped_diff",
        cmap=cmap_b,
        norm=norm_b,
        linewidth=0.35,
        edgecolor="#334155",
        ax=ax,
    )
    if not missing.empty:
        missing.plot(
            color=COLOR_MISSING,
            edgecolor="#111827",
            linewidth=0.8,
            hatch="////",
            ax=ax,
        )
        ax.legend(
            handles=[
                mpatches.Patch(
                    facecolor=COLOR_MISSING,
                    edgecolor="#111827",
                    hatch="////",
                    label="Sin datos Google (5 mpios)",
                )
            ],
            loc="lower left",
            fontsize=8.5,
            framealpha=0.95,
        )
    style_map_axes(ax, bounds)
    sm_b = plt.cm.ScalarMappable(cmap=cmap_b, norm=norm_b)
    sm_b.set_array([])
    cb_b = fig.colorbar(sm_b, ax=ax, orientation="horizontal", fraction=0.042, pad=0.04)
    cb_b.set_label(
        "Diferencia relativa de área: (Google − MS) / MS (%) [acotado ±60%]",
        fontsize=9.5,
    )
    ax.set_title(
        "Sesgo Geográfico Entre Fuentes (Google vs. Microsoft)\n"
        "Azul: Microsoft estima más área | Rojo: Google estima más área",
        pad=10,
    )

    fig.suptitle(
        "Análisis Espacial de Densidad Edificada y Divergencia entre Sensores Satelitales",
        fontsize=14,
        fontweight="bold",
    )
    return fig
