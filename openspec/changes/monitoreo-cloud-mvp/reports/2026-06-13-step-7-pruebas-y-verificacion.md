# Reporte Step 7 — Pruebas y verificación de estado

- Fecha: 2026-06-13
- Cambio: monitoreo-cloud-mvp
- Agente: Claude (Opus 4.8 1M)

## Comandos ejecutados

- `bash -n scripts/aws/*.sh` (sintaxis de todos los scripts)
- `docker compose config` (validación del compose)
- `openspec validate monitoreo-cloud-mvp`
- `bash scripts/aws/budget.sh valentin.alducin88@gmail.com 1`
- `bash scripts/aws/provision.sh` (3 corridas — ver incidencias)
- `ssh ... ec2-user@3.137.209.184` + `scp docker-compose.yml` + `docker-compose up -d`
- `bash scripts/aws/status.sh`
- `curl -I http://3.137.209.184:5678`

## Resultados de pruebas

- Sintaxis (bash -n): 5/5 scripts OK.
- `docker compose config`: válido (solo warnings de variables no definidas, esperado sin `.env`).
- `openspec validate`: **valid**.
- Provisión idempotente: confirmada — la 2ª y 3ª corrida no recrearon key pair, SGs ni RDS.

## Incidencias encontradas y corregidas (durante la verificación)

1. **`find_rds_status` abortaba** con `set -e`/`pipefail` cuando la RDS no existía
   (`DBInstanceNotFound`, exit 254). Fix: captura con `|| true` antes de filtrar.
2. **AMI no resolvía en Git Bash**: MSYS convertía `/aws/service/...` en ruta Windows.
   Fix: `export MSYS_NO_PATHCONV=1` + `al2023_ami` falla claro si no resuelve.
3. **`t2.micro` no es free-tier-eligible** en us-east-2 (plan Free Tier nuevo rechaza el launch).
   Fix: `t3.micro` por defecto y `guard_free_tier` valida contra la API (`describe-instance-types`).
4. **RDS PG16 fuerza SSL** y su CA no está en el trust store de n8n.
   Fix: `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false` (conexión cifrada, sin verificación de CA).

## Verificación de estado (después)

- **EC2**: `i-0dbfa95b85e86f444`, t3.micro, `running`, IP `3.137.209.184`.
- **RDS**: `monitoreo-cloud-db`, db.t3.micro, `available`, endpoint `...cnk4auc4g4ms.us-east-2.rds.amazonaws.com`.
- **Security groups**: `monitoreo-cloud-sg` (EC2) y `monitoreo-cloud-db-sg` (BD, 5432 solo desde EC2).
- **Budget**: `monitoreo-cloud-budget` límite 1.0 USD, gastado 0.0.
- **Costo del mes**: ~0 USD (dentro del Free Tier).
- **n8n**: contenedor `Up`, migraciones aplicadas sobre PostgreSQL (RDS), HTTP 200 en `:5678`.
- **Estado restaurado**: No (despliegue real solicitado por el usuario; los recursos quedan activos).
  Teardown disponible: `bash scripts/aws/teardown.sh --yes`.

## Resultado

- Estado Step 7: **PASS** (infra + n8n + RDS verificados en vivo).
- Bloqueos para cerrar el MVP (pasos manuales): alta de Grafana Cloud + token, construcción del
  workflow n8n y dashboards/alertas (Fases 2–3). No automatizables por CLI.
