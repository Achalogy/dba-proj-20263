"""Verificación de calidad de la capa municipal del MGN (DANE) frente al
catálogo de municipios PDET (data/MunicipiosPDET.xlsx).

Uso:
    python scripts/verify_mgn.py --mgn data/raw/MGN.gdb
    python scripts/verify_mgn.py --mgn data/raw/MGN_ADM_MPIO_GRAFICO.shp
    python scripts/verify_mgn.py --mgn data/raw/MGN.gdb --layer MGN_ADM_MPIO_GRAFICO

Solo LEE los datos y escribe un reporte pequeño en reports/. No modifica nada.
"""
import argparse
import hashlib
import json
import unicodedata
from datetime import datetime
from pathlib import Path

import geopandas as gpd
import pandas as pd
import pyogrio

# Columnas típicas del MGN (se prueban en orden)
COD_MPIO = ["MPIO_CDPMP", "MPIO_CCNCT", "COD_MPIO"]
COD_DPTO = ["DPTO_CCDGO", "COD_DPTO"]
NOM_MPIO = ["MPIO_CNMBR", "NOM_MPIO"]
AREA_OFICIAL = ["MPIO_NAREA", "AREA"]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for bloque in iter(lambda: f.read(1024 * 1024), b""):
            h.update(bloque)
    return h.hexdigest()


def norm(texto) -> str:
    """Mayúsculas y sin tildes, para comparar nombres."""
    t = unicodedata.normalize("NFKD", str(texto).strip().upper())
    return "".join(c for c in t if not unicodedata.combining(c))


def pick(columnas, candidatas, que):
    """Busca la columna sin importar mayúsculas/minúsculas."""
    por_minuscula = {str(c).lower(): c for c in columnas}
    for c in candidatas:
        if c.lower() in por_minuscula:
            return por_minuscula[c.lower()]
    raise SystemExit(f"No encontré la columna de {que}. Columnas disponibles: {list(columnas)}")


def elegir_capa(ruta: Path, capa: str | None):
    """Devuelve el nombre de la capa municipal (None si es un shapefile)."""
    if ruta.suffix.lower() == ".shp":
        return None
    capas = [c[0] for c in pyogrio.list_layers(ruta)]
    print(f"Capas encontradas ({len(capas)}):")
    for c in capas:
        print("  -", c)
    if capa:
        return capa
    candidatas = [c for c in capas if "MPIO" in c.upper()]
    if not candidatas:
        raise SystemExit("No encontré una capa con 'MPIO'. Pásala con --layer.")
    print(f"Capa elegida: {candidatas[0]}  (si no es la correcta usa --layer)")
    return candidatas[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mgn", required=True, help="Ruta a .gdb, .gpkg o .shp del MGN")
    ap.add_argument("--layer", default=None)
    ap.add_argument("--xlsx", default="data/MunicipiosPDET.xlsx")
    ap.add_argument("--zip", default=None, help="(opcional) ZIP original, para registrar su SHA-256")
    ap.add_argument("--out", default="reports")
    a = ap.parse_args()

    out = Path(a.out)
    out.mkdir(exist_ok=True)
    rep = {"fecha": datetime.now().isoformat(timespec="seconds"), "archivo_mgn": a.mgn}

    if a.zip:
        z = Path(a.zip)
        rep["zip_original"] = {"nombre": z.name, "tamano_mb": round(z.stat().st_size / 1e6, 1),
                               "sha256": sha256(z)}

    # 1. Catálogo PDET
    pdet = pd.read_excel(a.xlsx, sheet_name="MunicipiosPDET")
    pdet["cod_mpio"] = pdet["Código DANE Municipio"].astype(int).astype(str).str.zfill(5)
    pdet["cod_dpto"] = pdet["Código DANE Departamento"].astype(int).astype(str).str.zfill(2)
    rep["catalogo_pdet"] = {"filas": len(pdet), "codigos_unicos": int(pdet["cod_mpio"].nunique())}

    # 2. Capa municipal del MGN
    ruta = Path(a.mgn)
    capa = elegir_capa(ruta, a.layer)
    gdf = gpd.read_file(ruta, layer=capa)
    c_mpio = pick(gdf.columns, COD_MPIO, "código de municipio")
    c_dpto = pick(gdf.columns, COD_DPTO, "código de departamento")
    c_nom = pick(gdf.columns, NOM_MPIO, "nombre de municipio")
    c_area = pick(gdf.columns, AREA_OFICIAL, "área oficial")
    gdf[c_mpio] = gdf[c_mpio].astype(str).str.zfill(5)
    gdf[c_dpto] = gdf[c_dpto].astype(str).str.zfill(2)

    rep["mgn"] = {
        "capa": capa,
        "municipios_totales": len(gdf),
        "codigos_unicos": int(gdf[c_mpio].nunique()),
        "codigos_repetidos": sorted(gdf[c_mpio][gdf[c_mpio].duplicated()].unique().tolist()),
        "crs": str(gdf.crs),
        "columnas_usadas": {"municipio": c_mpio, "departamento": c_dpto, "nombre": c_nom, "area": c_area},
    }

    # 3. Cruce PDET vs MGN
    cod_pdet = set(pdet["cod_mpio"])
    cod_mgn = set(gdf[c_mpio])
    faltan = sorted(cod_pdet - cod_mgn)
    rep["cruce"] = {"pdet_encontrados_en_mgn": len(cod_pdet & cod_mgn),
                    "pdet_que_faltan_en_mgn": faltan}

    sub = gdf[gdf[c_mpio].isin(cod_pdet)].copy()

    # 4. Coherencia de departamento y nombre
    m = sub.merge(pdet, left_on=c_mpio, right_on="cod_mpio")
    dif_dpto = m[m[c_dpto] != m["cod_dpto"]][c_mpio].tolist()
    dif_nom = m[m[c_nom].map(norm) != m["Municipio"].map(norm)][[c_mpio, c_nom, "Municipio"]]
    rep["coherencia"] = {"departamento_distinto": dif_dpto,
                         "nombres_distintos": dif_nom.rename(columns={c_mpio: "cod", c_nom: "mgn", "Municipio": "xlsx"}
                                                             ).to_dict("records")}

    # 5. Geometrías (solo se cuentan; arreglarlas es de la issue #4)
    geom = sub.geometry
    invalidas = ~geom.is_valid & geom.notna() & ~geom.is_empty
    rep["geometrias"] = {
        "tipos": geom.geom_type.value_counts().to_dict(),
        "nulas": int(geom.isna().sum()),
        "vacias": int(geom.is_empty.sum()),
        "invalidas": int(invalidas.sum()),
        "codigos_invalidos": sub.loc[invalidas, c_mpio].tolist(),
    }

    # 6. Área calculada (EPSG:9377) vs área oficial
    if gdf.crs is not None:
        km2 = sub.to_crs(9377).geometry.area / 1e6
        rel = ((km2 - sub[c_area].astype(float)).abs() / sub[c_area].astype(float)) * 100
        rep["area"] = {"diferencia_relativa_mediana_pct": round(float(rel.median()), 3),
                       "diferencia_relativa_max_pct": round(float(rel.max()), 3),
                       "municipios_con_dif_mayor_5pct": int((rel > 5).sum())}

    # 7. Resumen en pantalla
    print("\n=== RESULTADOS ===")
    print(json.dumps(rep, indent=2, ensure_ascii=False))
    destino = out / "mgn_verification.json"
    destino.write_text(json.dumps(rep, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nReporte guardado en {destino}")


if __name__ == "__main__":
    main()
