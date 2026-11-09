# dba-proj-20263

## Contenedor docker de prueba

```
docker compose -f src/2-mongo_container_test/compose.yml up -d
```

## Semana 2 - Ejecución py

```
# Para verificar datos del MGN:
uv run src/1-pdet_mgn/src/1_pdet_mgn/verify_mgn.py --mgn data/MGN_ADM_MPIO_GRAFICO.shp

# Para preparar los datos PDET:
uv run src/1-pdet_mgn/src/1_pdet_mgn/prepare-pdet.py --mgn data/MGN_ADM_MPIO_GRAFICO.shp --xlsx data/MunicipiosPDET.xlsx --dry-run
```
