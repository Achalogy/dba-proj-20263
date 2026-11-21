"""Pipelines de agregación y persistencia analítica en MongoDB."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pymongo import ASCENDING, MongoClient
from pymongo.errors import PyMongoError

from workflow.config import CONF_BUCKETS, fail, safe_round


def connect_database(uri: str, db_name: str):
    """Abre conexión autenticada a MongoDB y valida las colecciones requeridas."""
    try:
        client = MongoClient(uri, serverSelectionTimeoutMS=8000)
        client.admin.command("ping")
        server_version = client.server_info().get("version", "unknown")
    except PyMongoError as e:
        fail(f"No fue posible conectar a MongoDB: {e}")

    db = client[db_name]
    cols = set(db.list_collection_names())
    for req in ("municipalities_pdet", "buildings_microsoft", "buildings_google"):
        if req not in cols:
            fail(
                f"Falta la colección requerida '{req}' en '{db_name}'. "
                f"Encontradas: {sorted(cols)}"
            )
    return client, db, server_version


def supports_percentile_operator(db) -> bool:
    """Comprueba si la versión de MongoDB soporta $percentile (MongoDB >= 7.0)."""
    try:
        info = db.client.server_info()
        major = int(str(info.get("version", "0")).split(".")[0])
        return major >= 7
    except Exception:
        return False


def read_municipalities_metadata(db) -> list[dict[str, Any]]:
    """Lee metadatos base de los 170 municipios PDET ordenados por código DANE."""
    docs = list(
        db.municipalities_pdet.find(
            {},
            {
                "_id": 0,
                "cod_dane_mpio": 1,
                "cod_dane_dpto": 1,
                "municipio": 1,
                "departamento": 1,
                "subregion_pdet": 1,
                "area_oficial_km2": 1,
                "bbox": 1,
            },
        ).sort("cod_dane_mpio", ASCENDING)
    )
    if len(docs) != 170:
        fail(f"Se esperaban 170 municipios PDET, encontrados {len(docs)}.")
    return docs


def build_municipal_building_pipeline(
    is_google: bool,
    use_percentile: bool,
    min_plausible_m2: float,
    max_plausible_m2: float,
    high_conf_threshold: float,
) -> list[dict[str, Any]]:
    """Pipeline de agregación determinístico por municipio en MongoDB."""
    area = "$rooftop_area_m2"
    plausible_cond: Any = {
        "$and": [
            {"$gte": [area, min_plausible_m2]},
            {"$lte": [area, max_plausible_m2]},
        ]
    }
    if is_google:
        plausible_cond = {
            "$and": [
                {"$gte": [area, min_plausible_m2]},
                {"$lte": [area, max_plausible_m2]},
                {"$gte": ["$confidence", 0.65]},
            ]
        }

    def _range_cond(lo: float, hi: float) -> dict[str, Any]:
        return {"$and": [{"$gte": [area, lo]}, {"$lt": [area, hi]}]}

    group_stage: dict[str, Any] = {
        "_id": "$cod_dane_mpio",
        "building_count": {"$sum": 1},
        "total_area_m2": {"$sum": area},
        "avg_area_m2": {"$avg": area},
        "min_area_m2": {"$min": area},
        "max_area_m2": {"$max": area},
        "std_area_m2": {"$stdDevPop": area},
        "plausible_count": {"$sum": {"$cond": [plausible_cond, 1, 0]}},
        "plausible_area_m2": {"$sum": {"$cond": [plausible_cond, area, 0.0]}},
        "cnt_lt_30": {"$sum": {"$cond": [{"$lt": [area, 30.0]}, 1, 0]}},
        "area_lt_30": {"$sum": {"$cond": [{"$lt": [area, 30.0]}, area, 0.0]}},
        "cnt_30_80": {"$sum": {"$cond": [_range_cond(30.0, 80.0), 1, 0]}},
        "area_30_80": {"$sum": {"$cond": [_range_cond(30.0, 80.0), area, 0.0]}},
        "cnt_80_150": {"$sum": {"$cond": [_range_cond(80.0, 150.0), 1, 0]}},
        "area_80_150": {"$sum": {"$cond": [_range_cond(80.0, 150.0), area, 0.0]}},
        "cnt_150_500": {"$sum": {"$cond": [_range_cond(150.0, 500.0), 1, 0]}},
        "area_150_500": {"$sum": {"$cond": [_range_cond(150.0, 500.0), area, 0.0]}},
        "cnt_gt_500": {"$sum": {"$cond": [{"$gte": [area, 500.0]}, 1, 0]}},
        "area_gt_500": {"$sum": {"$cond": [{"$gte": [area, 500.0]}, area, 0.0]}},
    }

    if use_percentile:
        group_stage["percentiles"] = {
            "$percentile": {
                "input": area,
                "p": [0.25, 0.50, 0.75, 0.90],
                "method": "approximate",
            }
        }

    if is_google:
        high_conf_cond = {"$gte": ["$confidence", high_conf_threshold]}
        group_stage["avg_confidence"] = {"$avg": "$confidence"}
        group_stage["min_confidence"] = {"$min": "$confidence"}
        group_stage["max_confidence"] = {"$max": "$confidence"}
        group_stage["std_confidence"] = {"$stdDevPop": "$confidence"}
        group_stage["high_conf_count"] = {"$sum": {"$cond": [high_conf_cond, 1, 0]}}
        group_stage["high_conf_area_m2"] = {
            "$sum": {"$cond": [high_conf_cond, area, 0.0]}
        }

    return [
        {"$match": {"cod_dane_mpio": {"$ne": None}, "rooftop_area_m2": {"$gt": 0}}},
        {"$group": group_stage},
        {"$sort": {"_id": 1}},
    ]


def compute_global_percentiles(col, use_percentile: bool) -> dict[str, float | None]:
    if not use_percentile:
        return {"p25": None, "p50": None, "p75": None, "p90": None}
    pipe = [
        {"$match": {"rooftop_area_m2": {"$gt": 0}}},
        {
            "$group": {
                "_id": None,
                "p": {
                    "$percentile": {
                        "input": "$rooftop_area_m2",
                        "p": [0.25, 0.50, 0.75, 0.90],
                        "method": "approximate",
                    }
                },
            }
        },
    ]
    res = list(col.aggregate(pipe, allowDiskUse=True))
    if not res or not res[0].get("p"):
        return {"p25": None, "p50": None, "p75": None, "p90": None}
    p = res[0]["p"]
    return {
        "p25": safe_round(p[0], 2),
        "p50": safe_round(p[1], 2),
        "p75": safe_round(p[2], 2),
        "p90": safe_round(p[3], 2),
    }


def compute_google_confidence_bins(col) -> list[dict[str, Any]]:
    pipe = [
        {"$match": {"confidence": {"$ne": None}}},
        {
            "$bucket": {
                "groupBy": "$confidence",
                "boundaries": CONF_BUCKETS,
                "default": "other",
                "output": {
                    "count": {"$sum": 1},
                    "total_area_m2": {"$sum": "$rooftop_area_m2"},
                    "avg_area_m2": {"$avg": "$rooftop_area_m2"},
                },
            }
        },
    ]
    rows = list(col.aggregate(pipe, allowDiskUse=True))
    labels = {
        0.65: "0.65 – 0.70",
        0.70: "0.70 – 0.75",
        0.75: "0.75 – 0.80",
        0.80: "0.80 – 0.85",
        0.85: "0.85 – 0.90",
        0.90: "0.90 – 1.00",
    }
    total_cnt = sum(r["count"] for r in rows) or 1
    total_area = sum(r["total_area_m2"] for r in rows) or 1.0
    return [
        {
            "lower_bound": r["_id"],
            "label": labels.get(r["_id"], str(r["_id"])),
            "count": int(r["count"]),
            "pct_count": round(r["count"] / total_cnt * 100.0, 2),
            "total_area_m2": round(float(r["total_area_m2"]), 2),
            "total_area_km2": round(float(r["total_area_m2"]) / 1e6, 4),
            "pct_area": round(float(r["total_area_m2"]) / total_area * 100.0, 2),
            "avg_area_m2": round(float(r["avg_area_m2"]), 2),
        }
        for r in rows
    ]


def materialize_solar_aggregations(
    db, municipalities: list[dict[str, Any]], computed_at: datetime
) -> int:
    """Persiste de forma idempotente la colección `solar_aggregations` y sus índices."""
    col_agg = db["solar_aggregations"]
    col_agg.drop()
    docs_to_insert = [{**m, "computed_at": computed_at} for m in municipalities]
    col_agg.insert_many(docs_to_insert, ordered=False)
    col_agg.create_index(
        [("cod_dane_mpio", ASCENDING)], unique=True, name="idx_uk_agg_mpio"
    )
    col_agg.create_index(
        [
            ("solar_potential.priority_rank", ASCENDING),
            ("subregion_pdet.id", ASCENDING),
        ],
        name="idx_solar_rank_subregion",
    )
    n_agg = col_agg.count_documents({})
    if n_agg != 170:
        fail(f"solar_aggregations terminó con {n_agg} docs, se esperaban 170.")
    return n_agg
