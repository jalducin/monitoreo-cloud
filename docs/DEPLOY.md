# Runbook de despliegue — Monitoreo Cloud

Despliegue del MVP en AWS Free Tier (`us-east-2`). Requisitos locales: AWS CLI autenticado,
`bash`, `curl`. Estándares: `docs/n8n-aws-standards.md`.

> **Restricción dura:** todo dentro del Free Tier. Antes y después de desplegar, revisa costos.

## 0. Prerrequisitos

```bash
aws sts get-caller-identity        # confirma cuenta y autenticación
aws configure get region           # debe ser us-east-2 (o exporta AWS_REGION)
```

## 1. Guardarraíl de costo (primero)

```bash
cd scripts/aws
./budget.sh tu-correo@ejemplo.com 1     # budget mensual de $1 con alerta al 80%
```

## 2. Provisionar infraestructura (AWS CLI, idempotente)

```bash
./provision.sh
# Crea: key pair (.pem en ~/.monitoreo-cloud/), security group de EC2 (22 y 5678 solo tu IP),
#       rol IAM (CloudWatchReadOnlyAccess) + instance profile y EC2 t3.micro (Amazon Linux 2023).
# Imprime InstanceId, IP pública y el comando SSH. (La base de datos NO usa RDS: corre en contenedor.)
./status.sh                              # verifica EC2, SG y costos
```

## 3. Desplegar n8n + PostgreSQL en la EC2 (Docker Compose)

```bash
# Copia el compose y crea el .env en la instancia (NO se versiona):
scp -i ~/.monitoreo-cloud/monitoreo-cloud-key.pem infra/docker-compose.yml ec2-user@<IP>:~/monitoreo/
ssh -i ~/.monitoreo-cloud/monitoreo-cloud-key.pem ec2-user@<IP>

# En la EC2 (~/monitoreo):
cp /ruta/.env.example .env && nano .env   # basic auth, N8N_HOST=<IP>, encryption key,
                                           # y POSTGRES_*/DB_POSTGRESDB_* (la BD es el contenedor 'postgres')
docker compose up -d
docker compose ps                          # 'postgres' healthy y 'n8n' running en :5678
docker compose logs n8n | grep -i migration # confirma que n8n aplicó migraciones en PostgreSQL
```

Abre `http://<IP>:5678`, inicia sesión (basic auth) y completa el setup de n8n.

## 4. Grafana self-hosted (en el mismo compose)

Grafana ya arranca con `docker compose up -d` (servicio `grafana`, puerto 3000). Bootstrap por API/provisioning:

1. Abre `http://<IP>:3000` y entra con el admin del `.env` (`GF_SECURITY_ADMIN_USER/PASSWORD`).
2. Datasource **PostgreSQL** → host `postgres:5432`, db `n8n`, user/clave del `.env` (`sslmode=disable`).
   Reproducible vía `grafana/provisioning/datasources/postgres.yml`.
3. (Opcional) genera un **service-account token** (Administration → Service accounts) para automatizar dashboards.
4. Crea la tabla destino en Postgres:
   `docker exec -i n8n-postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < <(echo "CREATE TABLE IF NOT EXISTS metrics (...)" )`
   (esquema completo en `n8n/workflows/README.md`).

## 5. Pipeline y dashboards

1. Construye el workflow `metricas-cloudwatch-postgres` (ver `n8n/workflows/README.md`), ejecútalo
   manualmente y confirma que aparecen filas en la tabla `metrics`.
2. Expórtalo **sin credenciales** a `n8n/workflows/metricas-cloudwatch-postgres.json`.
3. Crea/ajusta el dashboard en Grafana (datasource PostgreSQL), expórtalo a `grafana/provisioning/dashboards/json/`.
4. Configura la alerta de CPU y su contact point.

## 6. Verificación

```bash
cd scripts/aws && ./status.sh            # instancia, SG, budget, costo del mes
```
- n8n responde con basic auth en `:5678`.
- Las métricas aparecen en el dashboard de Grafana.
- La alerta dispara con un umbral de prueba.
- El costo del mes sigue en \$0 / dentro del Free Tier.

## 6b. Modo local (sin AWS, $0 sin límite)

Para correr todo en tu máquina con Docker (sin EC2):

```bash
cd infra
cp ../.env.example .env && nano .env   # N8N_HOST=localhost, claves locales, POSTGRES_*/GF_*
docker compose --env-file .env up -d   # postgres + n8n + grafana
```

Luego, dentro del contenedor (usa `MSYS_NO_PATHCONV=1` en Git Bash para que `/tmp/...` no se convierta):

```bash
docker exec -i n8n-postgres psql -U n8n -d n8n -c "CREATE TABLE IF NOT EXISTS metrics (...);"  # esquema en n8n/workflows/README.md
docker cp credentials.json n8n:/tmp/ && docker exec n8n n8n import:credentials --input=/tmp/credentials.json
docker cp n8n/workflows/metricas-cloudwatch-postgres.json n8n:/tmp/ && docker exec n8n n8n import:workflow --input=/tmp/metricas-cloudwatch-postgres.json
docker exec n8n n8n update:workflow --id=monitoreocloudwf --active=true && docker compose restart n8n
```

- n8n: `http://localhost:5678` · Grafana: `http://localhost:3000` (datasource Postgres, mismo `uid` que el dashboard del repo).
- Para leer CloudWatch necesitas el usuario IAM `monitoreo-cloud-n8n` (se conserva en AWS, es gratis);
  apunta el workflow a un recurso AWS existente. Sin recurso vivo no hay datos nuevos.
- Apagar: `docker compose down` (los volúmenes `n8n_data`, `pg_data`, `grafana_data` se conservan).

## 7. Limpieza (rollback / fin de demo)

```bash
cd scripts/aws
./teardown.sh --yes                      # elimina instancia, SG, key pair, rol IAM y budget por tag
./status.sh                              # confirma que no quedan recursos
```
> En la EC2, `docker compose down` detiene n8n sin borrar el volumen `n8n_data`.
