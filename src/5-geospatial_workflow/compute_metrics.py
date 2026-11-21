"""CLI del Flujo Reproducible de Análisis Geoespacial (Conteo de Techos, Área y Potencial Solar).

Orquesta los módulos de `workflow/`:
  - `workflow.mongo_pipelines`: conexión, agregaciones por municipio/estratos y `solar_aggregations`
  - `workflow.metrics`: consenso híbrido MS-Google, potencial solar y agregación territorial
  - `workflow.summary`: concordancia, morfología, Pareto/Gini, resumen global y SHA-256
  - `workflow.spatial_audit`: verificación `explain("executionStats")` de índices
  - `workflow.exporters`: exportación abierta (JSON, CSV, GeoJSON)

Uso:
    uv run --project src/5-geospatial_workflow python src/5-geospatial_workflow/compute_metrics.py \\
        --uri "mongodb://acha:acha@tally:27017/?authSource=admin" \\
        --db upme_pdet
"""

from __future__ import annotations

import argparse
import os
import time
from datetime import datetime, timezone

from workflow.config import WorkflowConfig, get_git_commit
from workflow.exporters import (
    export_workflow_outputs,
    flatten_municipality_row,
    print_executive_summary,
)
from workflow.metrics import aggregate_groups, consolidate_municipalities
from workflow.mongo_pipelines import (
    build_municipal_building_pipeline,
    compute_global_percentiles,
    compute_google_confidence_bins,
    connect_database,
    materialize_solar_aggregations,
    read_municipalities_metadata,
    supports_percentile_operator,
)
from workflow.spatial_audit import run_spatial_audit
from workflow.summary import (
    build_rankings,
    compute_agreement_stats,
    compute_deterministic_checksum,
    compute_global_summary,
    compute_strata_and_concentration,
)


def parse_args() -> WorkflowConfig:
    ap = argparse.ArgumentParser(
        description="Ejecuta el flujo reproducible de análisis geoespacial PDET-UPME."
    )
    ap.add_argument(
        "--uri",
        default=os.getenv(
            "MONGO_URI", "mongodb://acha:acha@localhost:27017/?authSource=admin"
        ),
        help="URI de conexión a MongoDB",
    )
    ap.add_argument(
        "--db",
        default=os.getenv("MONGO_DATABASE") or os.getenv("MONGO_DB") or "upme_pdet",
        help="Base de datos MongoDB",
    )
    ap.add_argument(
        "--output-dir",
        default="reports/workflow",
        help="Directorio de salida para JSON, CSV y GeoJSON",
    )
    ap.add_argument(
        "--ndjson",
        default="data/processed/municipalities_pdet.ndjson",
        help="Ruta a municipalities_pdet.ndjson para exportar GeoJSON",
    )
    ap.add_argument(
        "--utilization-factor",
        type=float,
        default=0.40,
        help="Fracción aprovechable de área de techo para paneles solares (default: 0.40)",
    )
    ap.add_argument(
        "--power-density",
        type=float,
        default=0.20,
        help="Densidad de potencia fotovoltaica en kWp/m² (default: 0.20 = 200 Wp/m²)",
    )
    ap.add_argument(
        "--specific-yield",
        type=float,
        default=1450.0,
        help="Rendimiento específico anual de referencia en kWh/kWp·año (default: 1450)",
    )
    ap.add_argument(
        "--min-plausible-m2",
        type=float,
        default=10.0,
        help="Umbral mínimo RN-05 en m² (default: 10)",
    )
    ap.add_argument(
        "--max-plausible-m2",
        type=float,
        default=20000.0,
        help="Umbral máximo RN-05 en m² (default: 20000)",
    )
    ap.add_argument(
        "--high-conf",
        type=float,
        default=0.75,
        help="Umbral de alta confianza en Google Open Buildings (default: 0.75)",
    )
    ap.add_argument(
        "--simplify-tol",
        type=float,
        default=0.002,
        help="Tolerancia de simplificación en grados para GeoJSON de salida (default: 0.002)",
    )
    ap.add_argument(
        "--no-write-db",
        action="store_true",
        help="No materializar la colección solar_aggregations en MongoDB",
    )
    ap.add_argument(
        "--no-geojson",
        action="store_true",
        help="Omitir la generación de pdet_solar_metrics.geojson",
    )
    args = ap.parse_args()
    return WorkflowConfig(
        uri=args.uri,
        db_name=args.db,
        output_dir=args.output_dir,
        ndjson_path=args.ndjson,
        utilization_factor=args.utilization_factor,
        power_density=args.power_density,
        specific_yield=args.specific_yield,
        min_plausible_m2=args.min_plausible_m2,
        max_plausible_m2=args.max_plausible_m2,
        high_conf=args.high_conf,
        simplify_tol=args.simplify_tol,
        write_db=not args.no_write_db,
        export_geojson=not args.no_geojson,
    )


def main() -> None:
    cfg = parse_args()
    t_start = time.perf_counter()
    timings: dict[str, float] = {}

    print("=== FLUJO REPRODUCIBLE DE ANÁLISIS GEOESPACIAL (UPME - PDET) ===")
    safe_uri = cfg.uri.split("@")[-1] if "@" in cfg.uri else cfg.uri
    print(f"Conectando a MongoDB: {safe_uri} (db={cfg.db_name})")

    client, db, server_version = connect_database(cfg.uri, cfg.db_name)
    try:
        use_pct = supports_percentile_operator(db)
        print(f"MongoDB v{server_version} | soporte nativo $percentile: {use_pct}")

        # 1. Leer metadatos de los 170 municipios PDET
        t0 = time.perf_counter()
        mpio_docs = read_municipalities_metadata(db)
        timings["read_municipalities_s"] = round(time.perf_counter() - t0, 3)

        # 2. Agregación por municipio en Microsoft
        print("1. Ejecutando pipeline de agregación sobre buildings_microsoft...")
        t0 = time.perf_counter()
        ms_pipe = build_municipal_building_pipeline(
            is_google=False,
            use_percentile=use_pct,
            min_plausible_m2=cfg.min_plausible_m2,
            max_plausible_m2=cfg.max_plausible_m2,
            high_conf_threshold=cfg.high_conf,
        )
        ms_by_mpio = {
            r["_id"]: r
            for r in db.buildings_microsoft.aggregate(ms_pipe, allowDiskUse=True)
        }
        ms_global_pcts = compute_global_percentiles(db.buildings_microsoft, use_pct)
        timings["aggregate_microsoft_s"] = round(time.perf_counter() - t0, 3)
        print(
            f"   -> {len(ms_by_mpio)} municipios agregados en {timings['aggregate_microsoft_s']} s"
        )

        # 3. Agregación por municipio en Google
        print("2. Ejecutando pipeline de agregación sobre buildings_google...")
        t0 = time.perf_counter()
        gg_pipe = build_municipal_building_pipeline(
            is_google=True,
            use_percentile=use_pct,
            min_plausible_m2=cfg.min_plausible_m2,
            max_plausible_m2=cfg.max_plausible_m2,
            high_conf_threshold=cfg.high_conf,
        )
        gg_by_mpio = {
            r["_id"]: r
            for r in db.buildings_google.aggregate(gg_pipe, allowDiskUse=True)
        }
        gg_global_pcts = compute_global_percentiles(db.buildings_google, use_pct)
        gg_conf_bins = compute_google_confidence_bins(db.buildings_google)
        timings["aggregate_google_s"] = round(time.perf_counter() - t0, 3)
        print(
            f"   -> {len(gg_by_mpio)} municipios agregados en {timings['aggregate_google_s']} s"
        )

        # 4. Consolidar los 170 municipios con comparación y potencial solar
        print(
            "3. Consolidando métricas comparativas y estimación de potencial solar..."
        )
        t0 = time.perf_counter()
        computed_at = datetime.now(timezone.utc)
        computed_at_iso = computed_at.isoformat(timespec="seconds")
        municipalities = consolidate_municipalities(
            mpio_docs, ms_by_mpio, gg_by_mpio, cfg, computed_at_iso
        )
        timings["consolidate_s"] = round(time.perf_counter() - t0, 3)

        # 5. Materializar colección analítica solar_aggregations
        if cfg.write_db:
            print("4. Materializando colección `solar_aggregations` en MongoDB...")
            t0 = time.perf_counter()
            n_agg = materialize_solar_aggregations(db, municipalities, computed_at)
            timings["write_solar_aggregations_s"] = round(time.perf_counter() - t0, 3)
            print(
                f"   -> {n_agg} documentos persistidos con índices en {timings['write_solar_aggregations_s']} s"
            )

        # 6. Auditoría de índices espaciales y analíticos
        print("5. Auditando uso de índices espaciales y analíticos (`explain`)...")
        t0 = time.perf_counter()
        spatial_audit = run_spatial_audit(db)
        timings["spatial_audit_s"] = round(time.perf_counter() - t0, 3)
        used = sum(1 for v in spatial_audit.values() if v.get("uses_index"))
        print(f"   -> {used}/{len(spatial_audit)} consultas verificadas usando índice")
    finally:
        client.close()

    # 7. Agregaciones territoriales, estadísticos globales y checksum determinístico
    subregions = sorted(
        aggregate_groups(
            municipalities,
            key_fn=lambda m: m["subregion_pdet"]["id"],
            meta_fn=lambda m: {
                "subregion_id": m["subregion_pdet"]["id"],
                "subregion_nombre": m["subregion_pdet"]["nombre"],
            },
        ),
        key=lambda x: x["subregion_id"],
    )
    for rank, s in enumerate(
        sorted(subregions, key=lambda x: (-x["consensus_area_m2"], x["subregion_id"])),
        start=1,
    ):
        s["priority_rank"] = rank

    departments = sorted(
        aggregate_groups(
            municipalities,
            key_fn=lambda m: m["cod_dane_dpto"],
            meta_fn=lambda m: {
                "cod_dane_dpto": m["cod_dane_dpto"],
                "departamento": m["departamento"],
            },
        ),
        key=lambda x: (-x["consensus_area_m2"], x["cod_dane_dpto"]),
    )

    agreement_stats = compute_agreement_stats(municipalities)
    strata_summary, concentration = compute_strata_and_concentration(municipalities)
    global_summary = compute_global_summary(
        municipalities,
        subregions,
        departments,
        ms_global_pcts,
        gg_global_pcts,
        agreement_stats,
        concentration,
    )
    flat_rows = [flatten_municipality_row(m) for m in municipalities]
    rankings = build_rankings(flat_rows)
    deterministic_sha256 = compute_deterministic_checksum(flat_rows)
    timings["total_s"] = round(time.perf_counter() - t_start, 3)

    workflow_results = {
        "metadata": {
            "schema_version": "1.0.0",
            "generated_at": computed_at_iso,
            "git_commit": get_git_commit(),
            "database": cfg.db_name,
            "mongodb_version": server_version,
            "deterministic_sha256": deterministic_sha256,
            "timings_seconds": timings,
            "assumptions": {
                "area_projection_crs": "EPSG:9377 (MAGNA-SIRGAS Origen Nacional)",
                "storage_crs": "EPSG:4326 (WGS84)",
                "rn04_google_min_confidence": 0.65,
                "high_confidence_threshold": cfg.high_conf,
                "rn05_min_plausible_area_m2": cfg.min_plausible_m2,
                "rn05_max_plausible_area_m2": cfg.max_plausible_m2,
                "utilization_factor": cfg.utilization_factor,
                "power_density_kwp_per_m2": cfg.power_density,
                "specific_yield_kwh_per_kwp_year": cfg.specific_yield,
            },
        },
        "global_summary": global_summary,
        "size_strata_summary": strata_summary,
        "google_confidence_bins": gg_conf_bins,
        "subregions": subregions,
        "departments": departments,
        "rankings": rankings,
        "spatial_audit": spatial_audit,
        "municipalities": municipalities,
    }

    # 8. Exportar archivos abiertos e imprimir resumen ejecutivo
    out_dir = export_workflow_outputs(workflow_results, flat_rows, cfg)
    print_executive_summary(workflow_results, out_dir)


if __name__ == "__main__":
    main()
