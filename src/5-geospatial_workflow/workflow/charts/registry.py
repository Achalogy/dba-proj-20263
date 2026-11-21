"""Registro modular de gráficas, paleta institucional y utilidades de estilo."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

import geopandas as gpd
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd

matplotlib.use("Agg")

# Paleta corporativa / académica consistente y apta para impresión
COLOR_MS = "#1D4ED8"  # Azul Microsoft
COLOR_GG = "#EA580C"  # Naranja Google
COLOR_CONS = "#047857"  # Verde esmeralda Consenso
COLOR_NAVY = "#0F172A"  # Texto / títulos
COLOR_SLATE = "#475569"  # Subtítulos / anotaciones
COLOR_GRID = "#CBD5E1"  # Grilla sutil
COLOR_MISSING = "#E2E8F0"  # Municipios sin datos en Google

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "axes.titlesize": 12.5,
        "axes.titleweight": "bold",
        "axes.labelsize": 10.5,
        "axes.labelcolor": COLOR_NAVY,
        "axes.edgecolor": "#94A3B8",
        "axes.linewidth": 0.8,
        "xtick.color": COLOR_SLATE,
        "ytick.color": COLOR_SLATE,
        "text.color": COLOR_NAVY,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",
        "savefig.bbox": "tight",
    }
)


@dataclass
class ChartContext:
    data: dict[str, Any]
    df_mpios: pd.DataFrame
    df_subregions: pd.DataFrame
    gdf: gpd.GeoDataFrame


@dataclass
class ChartSpec:
    chart_id: str
    title: str
    description: str
    category: str
    fn: Callable[[ChartContext], plt.Figure]


CHART_REGISTRY: dict[str, ChartSpec] = {}


def register_chart(chart_id: str, title: str, description: str, category: str):
    """Decorador para registrar nuevas gráficas de forma modular."""

    def decorator(fn: Callable[[ChartContext], plt.Figure]):
        CHART_REGISTRY[chart_id] = ChartSpec(
            chart_id=chart_id,
            title=title,
            description=description,
            category=category,
            fn=fn,
        )
        return fn

    return decorator


def style_map_axes(ax: plt.Axes, bounds: tuple[float, float, float, float]) -> None:
    """Aplica estilo cartográfico estándar (grilla, grados °O/°N y márgenes)."""
    minx, miny, maxx, maxy = bounds
    padx = (maxx - minx) * 0.06
    pady = (maxy - miny) * 0.05
    ax.set_xlim(minx - padx, maxx + padx)
    ax.set_ylim(miny - pady, maxy + pady)
    ax.set_aspect("equal")
    ax.set_facecolor("#F8FAFC")
    ax.grid(True, linestyle="--", linewidth=0.5, color="#CBD5E1", alpha=0.7)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{abs(x):.0f}°O"))
    ax.yaxis.set_major_formatter(
        mticker.FuncFormatter(
            lambda y, _: f"{abs(y):.0f}°N" if y >= 0 else f"{abs(y):.0f}°S"
        )
    )
    ax.set_xlabel("Longitud", fontsize=9.5)
    ax.set_ylabel("Latitud", fontsize=9.5)
    ax.tick_params(labelsize=8.5)
    for spine in ax.spines.values():
        spine.set_edgecolor("#CBD5E1")


def title_case_es(text: str) -> str:
    """Formatea nombres de municipios/subregiones respetando preposiciones en español."""
    minor = {"de", "del", "la", "las", "el", "los", "y", "e", "en"}
    words = text.lower().split()
    out = []
    for i, w in enumerate(words):
        if i > 0 and w in minor:
            out.append(w)
        else:
            out.append(w.capitalize())
    return " ".join(out)
