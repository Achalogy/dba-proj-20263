"""Auditoría de planes de ejecución (`explain`) para índices espaciales y analíticos."""

from __future__ import annotations

from typing import Any

from pymongo.errors import PyMongoError


def extract_index_info(explain_doc: dict[str, Any]) -> dict[str, Any]:
    plan = explain_doc.get("queryPlanner", {}).get("winningPlan", {})
    cursor = plan
    index_name = None
    scan_stage = None
    while isinstance(cursor, dict):
        stage = cursor.get("stage")
        if cursor.get("indexName"):
            index_name = cursor["indexName"]
            scan_stage = stage
            break
        cursor = cursor.get("inputStage")
    stats = explain_doc.get("executionStats", {})
    return {
        "winning_stage": plan.get("stage"),
        "scan_stage": scan_stage,
        "index_name": index_name,
        "execution_time_ms": stats.get("executionTimeMillis"),
        "total_keys_examined": stats.get("totalKeysExamined"),
        "total_docs_examined": stats.get("totalDocsExamined"),
        "n_returned": stats.get("nReturned"),
        "uses_index": index_name is not None,
    }


def run_spatial_audit(db) -> dict[str, Any]:
    """Audita el uso real de índices espaciales y analíticos tras materializar solar_aggregations."""
    audit: dict[str, Any] = {}
    tests = [
        (
            "municipalities_pdet_2dsphere",
            {
                "find": "municipalities_pdet",
                "filter": {
                    "geometry": {
                        "$geoIntersects": {
                            "$geometry": {
                                "type": "Point",
                                "coordinates": [-74.199, 11.2408],
                            }
                        }
                    }
                },
            },
        ),
        (
            "buildings_microsoft_geometry_2dsphere",
            {
                "find": "buildings_microsoft",
                "filter": {
                    "geometry": {
                        "$geoIntersects": {
                            "$geometry": {
                                "type": "Point",
                                "coordinates": [-73.8297, 11.2489],
                            }
                        }
                    }
                },
            },
        ),
        (
            "buildings_google_centroid_2dsphere",
            {
                "find": "buildings_google",
                "filter": {
                    "centroid": {
                        "$geoWithin": {"$centerSphere": [[-73.25, 10.46], 1.0 / 6378.1]}
                    }
                },
            },
        ),
        (
            "buildings_microsoft_mpio_area",
            {
                "find": "buildings_microsoft",
                "filter": {"cod_dane_mpio": "47001", "rooftop_area_m2": {"$gte": 150}},
            },
        ),
        (
            "solar_aggregations_priority_rank",
            {
                "find": "solar_aggregations",
                "filter": {"solar_potential.priority_rank": {"$lte": 10}},
                "sort": {"solar_potential.priority_rank": 1},
            },
        ),
    ]

    for key, cmd in tests:
        try:
            exp = db.command("explain", cmd, verbosity="executionStats")
            audit[key] = extract_index_info(exp)
        except PyMongoError as e:
            audit[key] = {"error": str(e), "uses_index": False}

    return audit
