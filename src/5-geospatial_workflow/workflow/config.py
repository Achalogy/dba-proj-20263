"""Constantes, configuración y utilidades matemáticas para el flujo geoespacial."""

from __future__ import annotations

import math
import subprocess
import sys
from dataclasses import dataclass

import numpy as np

STRATA_DEFS: list[tuple[str, str, float, float]] = [
    ("lt_30", "< 30 m²", 0.0, 30.0),
    ("30_80", "30 – 80 m²", 30.0, 80.0),
    ("80_150", "80 – 150 m²", 80.0, 150.0),
    ("150_500", "150 – 500 m²", 150.0, 500.0),
    ("gt_500", "> 500 m²", 500.0, float("inf")),
]

CONF_BUCKETS: list[float] = [0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 1.01]


@dataclass(frozen=True)
class WorkflowConfig:
    uri: str
    db_name: str
    output_dir: str = "reports/workflow"
    ndjson_path: str = "data/processed/municipalities_pdet.ndjson"
    utilization_factor: float = 0.40
    power_density: float = 0.20
    specific_yield: float = 1450.0
    min_plausible_m2: float = 10.0
    max_plausible_m2: float = 20000.0
    high_conf: float = 0.75
    simplify_tol: float = 0.002
    write_db: bool = True
    export_geojson: bool = True


def fail(msg: str) -> None:
    print(f"\n[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def safe_round(val: float | None, ndigits: int = 4) -> float | None:
    if val is None or (isinstance(val, float) and (math.isnan(val) or math.isinf(val))):
        return None
    return round(float(val), ndigits)


def get_git_commit() -> str | None:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return out or None
    except Exception:
        return None


def gini_coefficient(values: list[float]) -> float:
    arr = np.array([v for v in values if v is not None and v >= 0], dtype=float)
    if len(arr) == 0 or arr.sum() == 0:
        return 0.0
    arr = np.sort(arr)
    n = len(arr)
    index = np.arange(1, n + 1)
    return float((2.0 * np.sum(index * arr)) / (n * np.sum(arr)) - (n + 1.0) / n)
