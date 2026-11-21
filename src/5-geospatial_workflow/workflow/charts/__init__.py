"""Subpaquete de visualización modular.

Al importar este paquete se registran automáticamente las gráficas 01–09 en
`CHART_REGISTRY` ordenadas por identificador. Para añadir nuevas gráficas en el
futuro, basta con crear una función decorada con `@register_chart(...)` e
importar su módulo aquí.
"""

from workflow.charts import analytics as _analytics  # noqa: F401
from workflow.charts import maps as _maps  # noqa: F401
from workflow.charts import rankings as _rankings  # noqa: F401
from workflow.charts.loader import load_context
from workflow.charts.registry import (
    CHART_REGISTRY,
    ChartContext,
    ChartSpec,
    register_chart,
)

# Garantizar orden determinístico (01..09) independiente del orden de importación
_ordered_specs = sorted(CHART_REGISTRY.items())
CHART_REGISTRY.clear()
CHART_REGISTRY.update(_ordered_specs)

__all__ = [
    "CHART_REGISTRY",
    "ChartContext",
    "ChartSpec",
    "load_context",
    "register_chart",
]
