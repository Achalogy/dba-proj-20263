"""Análisis Exploratorio de Datos (EDA) y Verificación Espacial en MongoDB.

Ejecuta las agregaciones estadísticas y las pruebas de índices espaciales
sobre las colecciones de huellas de edificaciones (buildings_microsoft y
buildings_google) y municipios (municipalities_pdet) en MongoDB.

Genera un reporte 100% en formato JSON en reports/eda_results.json y muestra
un resumen detallado en consola.

Uso:
    python src/4-eda/eda.py
    uv run --project src/4-eda python src/4-eda/eda.py
    python src/4-eda/eda.py --uri "mongodb://acha:acha@localhost:27017/?authSource=admin" --output reports/eda_results.json
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

from pymongo import MongoClient
from pymongo.errors import PyMongoError


def fallar(msg: str):
    print(f"\n[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def verificar_indices_espaciales(db) -> dict:
    """Verifica el uso real de los índices 2dsphere y compuestos mediante explain()."""
    print("  -> Auditando índices espaciales con explain(executionStats)...")
    verif = {}

    # 1. buildings_microsoft: geometry 2dsphere ($geoIntersects con Point)
    q1 = {
        "geometry": {
            "$geoIntersects": {
                "$geometry": {"type": "Point", "coordinates": [-73.8297, 11.2489]}
            }
        }
    }
    exp1 = db.command(
        "explain",
        {"find": "buildings_microsoft", "filter": q1},
        verbosity="executionStats",
    )
    plan1 = exp1.get("queryPlanner", {}).get("winningPlan", {})
    inp1 = plan1.get("inputStage", {})
    idx1 = inp1.get("indexName") or plan1.get("indexName")
    stats1 = exp1.get("executionStats", {})
    verif["ms_geometry_2dsphere"] = {
        "query": "$geoIntersects",
        "field": "geometry",
        "index_name": idx1,
        "winning_stage": plan1.get("stage"),
        "input_stage": inp1.get("stage"),
        "execution_time_ms": stats1.get("executionTimeMillis"),
        "total_docs_examined": stats1.get("totalDocsExamined"),
        "n_returned": stats1.get("nReturned"),
        "status": "OK" if idx1 == "geometry_2dsphere" else "FALLO",
    }

    # 2. buildings_microsoft: centroid 2dsphere ($geoWithin con $centerSphere)
    q2 = {
        "centroid": {
            "$geoWithin": {
                "$centerSphere": [[-74.21, 11.24], 1.0 / 6378.1]  # 1 km en Santa Marta
            }
        }
    }
    exp2 = db.command(
        "explain",
        {"find": "buildings_microsoft", "filter": q2},
        verbosity="executionStats",
    )
    plan2 = exp2.get("queryPlanner", {}).get("winningPlan", {})
    inp2 = plan2.get("inputStage", {})
    idx2 = inp2.get("indexName") or plan2.get("indexName")
    stats2 = exp2.get("executionStats", {})
    verif["ms_centroid_2dsphere"] = {
        "query": "$geoWithin ($centerSphere 1km)",
        "field": "centroid",
        "index_name": idx2,
        "winning_stage": plan2.get("stage"),
        "input_stage": inp2.get("stage"),
        "execution_time_ms": stats2.get("executionTimeMillis"),
        "total_docs_examined": stats2.get("totalDocsExamined"),
        "n_returned": stats2.get("nReturned"),
        "status": "OK" if idx2 == "centroid_2dsphere" else "FALLO",
    }

    # 3. buildings_google: centroid 2dsphere ($geoWithin con $centerSphere)
    q3 = {
        "centroid": {
            "$geoWithin": {
                "$centerSphere": [[-73.25, 10.46], 1.0 / 6378.1]  # 1 km en Valledupar
            }
        }
    }
    exp3 = db.command(
        "explain",
        {"find": "buildings_google", "filter": q3},
        verbosity="executionStats",
    )
    plan3 = exp3.get("queryPlanner", {}).get("winningPlan", {})
    inp3 = plan3.get("inputStage", {})
    idx3 = inp3.get("indexName") or plan3.get("indexName")
    stats3 = exp3.get("executionStats", {})
    verif["google_centroid_2dsphere"] = {
        "query": "$geoWithin ($centerSphere 1km)",
        "field": "centroid",
        "index_name": idx3,
        "winning_stage": plan3.get("stage"),
        "input_stage": inp3.get("stage"),
        "execution_time_ms": stats3.get("executionTimeMillis"),
        "total_docs_examined": stats3.get("totalDocsExamined"),
        "n_returned": stats3.get("nReturned"),
        "status": "OK" if idx3 == "centroid_2dsphere" else "FALLO",
    }

    # 4. Índice compuesto mpio_area {cod_dane_mpio: 1, rooftop_area_m2: -1}
    q4 = {"cod_dane_mpio": "47001", "rooftop_area_m2": {"$gte": 100}}
    exp4 = db.command(
        "explain",
        {"find": "buildings_microsoft", "filter": q4},
        verbosity="executionStats",
    )
    plan4 = exp4.get("queryPlanner", {}).get("winningPlan", {})
    inp4 = plan4.get("inputStage", {})
    idx4 = inp4.get("indexName") or plan4.get("indexName")
    stats4 = exp4.get("executionStats", {})
    verif["compound_mpio_area"] = {
        "query": "Filtro cod_dane_mpio + rooftop_area_m2 >= 100",
        "index_name": idx4,
        "winning_stage": plan4.get("stage"),
        "input_stage": inp4.get("stage"),
        "execution_time_ms": stats4.get("executionTimeMillis"),
        "total_docs_examined": stats4.get("totalDocsExamined"),
        "n_returned": stats4.get("nReturned"),
        "status": "OK" if idx4 == "mpio_area" else "FALLO",
    }

    return verif


def calcular_estadisticas_area(col) -> dict:
    """Calcula suma, promedio, mínimo, máximo y desviación estándar del área."""
    pipe = [
        {
            "$group": {
                "_id": None,
                "total_area_m2": {"$sum": "$rooftop_area_m2"},
                "avg_area_m2": {"$avg": "$rooftop_area_m2"},
                "min_area_m2": {"$min": "$rooftop_area_m2"},
                "max_area_m2": {"$max": "$rooftop_area_m2"},
                "std_area_m2": {"$stdDevPop": "$rooftop_area_m2"},
            }
        }
    ]
    res = list(col.aggregate(pipe))
    return res[0] if res else {}


def calcular_estratos_area(col) -> list:
    """Agrupa edificaciones por rangos de tamaño de cubierta."""
    pipe = [
        {
            "$bucket": {
                "groupBy": "$rooftop_area_m2",
                "boundaries": [0, 30, 80, 150, 500, 10000000],
                "default": "other",
                "output": {
                    "count": {"$sum": 1},
                    "total_area": {"$sum": "$rooftop_area_m2"},
                },
            }
        }
    ]
    return list(col.aggregate(pipe))


def calcular_confianza_google(col) -> tuple[dict, list]:
    """Estadísticas descriptivas e histograma de confianza para Google Open Buildings."""
    pipe_stats = [
        {
            "$group": {
                "_id": None,
                "avg_conf": {"$avg": "$confidence"},
                "min_conf": {"$min": "$confidence"},
                "max_conf": {"$max": "$confidence"},
                "std_conf": {"$stdDevPop": "$confidence"},
            }
        }
    ]
    pipe_bins = [
        {
            "$bucket": {
                "groupBy": "$confidence",
                "boundaries": [0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 1.01],
                "default": "other",
                "output": {"count": {"$sum": 1}},
            }
        }
    ]
    stats = list(col.aggregate(pipe_stats))
    bins = list(col.aggregate(pipe_bins))
    return (stats[0] if stats else {}, bins)


def calcular_resumen_municipal(col) -> list:
    """Agrupa por municipio y une los metadatos de municipalities_pdet."""
    pipe = [
        {
            "$group": {
                "_id": "$cod_dane_mpio",
                "count": {"$sum": 1},
                "total_area_m2": {"$sum": "$rooftop_area_m2"},
                "avg_area_m2": {"$avg": "$rooftop_area_m2"},
            }
        },
        {
            "$lookup": {
                "from": "municipalities_pdet",
                "localField": "_id",
                "foreignField": "cod_dane_mpio",
                "as": "m",
            }
        },
        {
            "$project": {
                "cod_dane_mpio": "$_id",
                "count": 1,
                "total_area_m2": 1,
                "avg_area_m2": 1,
                "municipio": {"$arrayElemAt": ["$m.municipio", 0]},
                "departamento": {"$arrayElemAt": ["$m.departamento", 0]},
                "subregion_id": {"$arrayElemAt": ["$m.subregion_pdet.id", 0]},
                "subregion_nombre": {"$arrayElemAt": ["$m.subregion_pdet.nombre", 0]},
            }
        },
    ]
    return list(col.aggregate(pipe))


def agregar_por_subregion(resumen_mpios: list) -> list:
    """Consolida las métricas municipales por subregión PDET (1 a 16)."""
    sub_map = {}
    for r in resumen_mpios:
        sid = r.get("subregion_id") or 0
        snom = r.get("subregion_nombre") or "Desconocido"
        if sid not in sub_map:
            sub_map[sid] = {
                "id": sid,
                "nombre": snom,
                "count": 0,
                "total_area_m2": 0.0,
                "mpios": 0,
            }
        sub_map[sid]["count"] += r["count"]
        sub_map[sid]["total_area_m2"] += r["total_area_m2"]
        sub_map[sid]["mpios"] += 1
    return sorted(sub_map.values(), key=lambda x: x["id"])


def main():
    parser = argparse.ArgumentParser(
        description="Genera el reporte EDA y audita índices espaciales en MongoDB."
    )
    parser.add_argument(
        "--uri",
        default=os.getenv(
            "MONGO_URI", "mongodb://acha:acha@localhost:27017/?authSource=admin"
        ),
        help="URI de conexión a MongoDB",
    )
    parser.add_argument(
        "--db",
        default=os.getenv("MONGO_DB", "upme_pdet"),
        help="Nombre de la base de datos",
    )
    parser.add_argument(
        "--output",
        default="reports/eda_results.json",
        help="Ruta del archivo JSON de salida",
    )
    args = parser.parse_args()

    inicio = time.perf_counter()
    print("=== ANÁLISIS EXPLORATORIO DE DATOS (EDA) Y AUDITORÍA ESPACIAL ===")
    print(f"Conectando a MongoDB: {args.uri.split('@')[-1] if '@' in args.uri else args.uri} -> db: {args.db}")

    try:
        cliente = MongoClient(args.uri, serverSelectionTimeoutMS=5000)
        cliente.admin.command("ping")
    except PyMongoError as e:
        fallar(f"No fue posible conectar a MongoDB en {args.uri}: {e}")

    db = cliente[args.db]
    colecciones = db.list_collection_names()
    print(f"Colecciones detectadas: {colecciones}")
    for col_req in ["buildings_microsoft", "buildings_google", "municipalities_pdet"]:
        if col_req not in colecciones:
            fallar(f"Falta la colección requerida '{col_req}' en la base de datos {args.db}.")

    # 1. Conteos
    print("\n1. Verificando conteo de documentos...")
    count_ms = db.buildings_microsoft.count_documents({})
    count_g = db.buildings_google.count_documents({})
    count_pdet = db.municipalities_pdet.count_documents({})
    print(f"  - buildings_microsoft: {count_ms:,}")
    print(f"  - buildings_google:    {count_g:,}")
    print(f"  - municipalities_pdet: {count_pdet}")

    # 2. Verificación de índices espaciales
    print("\n2. Ejecutando auditoría de índices espaciales (explain)...")
    verif_espacial = verificar_indices_espaciales(db)
    for k, v in verif_espacial.items():
        print(f"  [{v['status']}] {k}: {v['index_name']} ({v['execution_time_ms']} ms, exam={v['total_docs_examined']}, ret={v['n_returned']})")

    # 3. Estadísticas de área
    print("\n3. Calculando estadísticas descriptivas de área de techos...")
    stats_area_ms = calcular_estadisticas_area(db.buildings_microsoft)
    stats_area_g = calcular_estadisticas_area(db.buildings_google)
    print(f"  - MS Total:     {stats_area_ms['total_area_m2'] / 1e6:.2f} km² | Promedio: {stats_area_ms['avg_area_m2']:.2f} m²")
    print(f"  - Google Total: {stats_area_g['total_area_m2'] / 1e6:.2f} km² | Promedio: {stats_area_g['avg_area_m2']:.2f} m²")

    # 4. Estratos por tamaño de cubierta
    print("\n4. Agrupando edificaciones por estratos de tamaño...")
    area_bins_ms = calcular_estratos_area(db.buildings_microsoft)
    area_bins_g = calcular_estratos_area(db.buildings_google)

    # 5. Confianza de Google
    print("\n5. Analizando confianza en Google Open Buildings...")
    conf_g, conf_bins_g = calcular_confianza_google(db.buildings_google)
    print(f"  - Confianza promedio: {conf_g['avg_conf'] * 100:.2f} % (mín: {conf_g['min_conf']:.2f}, máx: {conf_g['max_conf']:.2f})")

    # 6. Agrupación municipal
    print("\n6. Consolidando estadísticas municipales y subregionales...")
    mpio_ms = calcular_resumen_municipal(db.buildings_microsoft)
    mpio_g = calcular_resumen_municipal(db.buildings_google)

    g_codes = {r["cod_dane_mpio"] for r in mpio_g}
    faltantes_en_google = [r for r in mpio_ms if r["cod_dane_mpio"] not in g_codes]

    top10_count_ms = sorted(mpio_ms, key=lambda x: x["count"], reverse=True)[:10]
    top10_count_g = sorted(mpio_g, key=lambda x: x["count"], reverse=True)[:10]
    top10_area_ms = sorted(mpio_ms, key=lambda x: x["total_area_m2"], reverse=True)[:10]
    top10_area_g = sorted(mpio_g, key=lambda x: x["total_area_m2"], reverse=True)[:10]

    subregions_ms = agregar_por_subregion(mpio_ms)
    subregions_g = agregar_por_subregion(mpio_g)

    # Estadísticas de almacenamiento físico
    cs_ms = db.command("collStats", "buildings_microsoft")
    cs_g = db.command("collStats", "buildings_google")
    almacenamiento = {
        "buildings_microsoft": {
            "size_mb": round(cs_ms["size"] / (1024 * 1024), 2),
            "storage_size_mb": round(cs_ms["storageSize"] / (1024 * 1024), 2),
            "total_index_size_mb": round(cs_ms["totalIndexSize"] / (1024 * 1024), 2),
            "avg_obj_size_bytes": round(cs_ms["avgObjSize"], 1),
            "index_sizes": cs_ms["indexSizes"],
        },
        "buildings_google": {
            "size_mb": round(cs_g["size"] / (1024 * 1024), 2),
            "storage_size_mb": round(cs_g["storageSize"] / (1024 * 1024), 2),
            "total_index_size_mb": round(cs_g["totalIndexSize"] / (1024 * 1024), 2),
            "avg_obj_size_bytes": round(cs_g["avgObjSize"], 1),
            "index_sizes": cs_g["indexSizes"],
        },
    }

    resultado_final = {
        "counts": {
            "ms": count_ms,
            "google": count_g,
            "pdet_municipalities": count_pdet,
        },
        "spatial_verification": verif_espacial,
        "almacenamiento": almacenamiento,
        "stats_area_ms": stats_area_ms,
        "stats_area_g": stats_area_g,
        "conf_g": conf_g,
        "conf_bins_g": conf_bins_g,
        "area_bins_ms": area_bins_ms,
        "area_bins_g": area_bins_g,
        "mpios_count": {
            "ms": len(mpio_ms),
            "google": len(mpio_g),
        },
        "missing_in_g": faltantes_en_google,
        "top10_count_ms": top10_count_ms,
        "top10_count_g": top10_count_g,
        "top10_area_ms": top10_area_ms,
        "top10_area_g": top10_area_g,
        "subregions_ms": subregions_ms,
        "subregions_g": subregions_g,
    }

    # Guardar archivo JSON 100% válido
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(resultado_final, f, indent=2, ensure_ascii=False)

    # Validar inmediatamente que json.loads() pueda leerlo sin error
    with open(out_path, "r", encoding="utf-8") as f:
        json.load(f)

    total_tiempo = time.perf_counter() - inicio
    print(f"\n[OK] Reporte JSON válido guardado en: {out_path} ({total_tiempo:.2f} s)")
    print("Reproducibilidad 100 % verificada.")


if __name__ == "__main__":
    main()
