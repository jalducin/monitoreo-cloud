# Workflows de n8n

Aquí se versionan los workflows **exportados como JSON**, **sin credenciales** (ver
`docs/n8n-aws-standards.md` §4). Las credenciales (conexión a PostgreSQL) se configuran en el
*credential store* de n8n y se referencian por nombre.

## `metricas-cloudwatch-postgres.json` (pipeline principal)

Workflow versionado (export sin secretos). **Dos ramas** disparadas por **Cron 5 min** (+ **Run manual**
para pruebas por CLI), ambas firmando **SigV4** con la credencial AWS (usuario IAM `monitoreo-cloud-n8n`,
solo lectura). n8n convierte las respuestas de CloudWatch a JSON.

**Rama Lambda:** `Lambdas` (Code, emite 4 funciones × 3 métricas: Invocations/Errors/Duration) →
`HTTP Lambda` (`GetMetricStatistics` `AWS/Lambda`, `MetricName`/`Stat` por item, dim `FunctionName`, 24h) →
`TF Lambda` (Code, alinea por índice, arma `INSERT` con `metric_name` = `lambda_invocations`/`lambda_errors`/`lambda_duration_ms`) →
`Insert Lambda` (Postgres).

**Rama S3:** `Buckets` (Code, 3 buckets) → `HTTP S3` (`AWS/S3` `NumberOfObjects`, dims `BucketName`+`StorageType=AllStorageTypes`, 3 días) →
`TF S3` (Code, `metric_name='s3_objects'`) → `Insert S3` (Postgres).

`ts` se deja en `DEFAULT now()` (cada corrida = un punto nuevo → serie temporal que crece cada 5 min).

> Arquitectura: **CloudWatch → n8n → PostgreSQL (`metrics`) → Grafana (datasource Postgres)**. Sin Grafana
> Cloud ni remote write. Para más métricas: agrega entradas a `Lambdas`/`Buckets` o una rama nueva (EC2, etc.).

### Tabla destino (`metrics`)

```sql
CREATE TABLE IF NOT EXISTS metrics (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT now(),
  metric_name TEXT NOT NULL,
  value DOUBLE PRECISION NOT NULL,
  instance_id TEXT,
  region TEXT,
  labels JSONB
);
```

## Archivo versionado

`metricas-cloudwatch-postgres.json` es el workflow exportado (sin secretos; solo referencias a
credenciales por `id`/nombre). Nodos: Cron 5 min · Run manual (executeWorkflowTrigger) ·
CloudWatch GetMetricStatistics (HTTP + cred AWS, SigV4) · Transformar (Code) · Insert metrics (Postgres).

> n8n convierte la respuesta XML de CloudWatch a JSON automáticamente (la credencial AWS); el nodo Code
> parsea `GetMetricStatisticsResponse.GetMetricStatisticsResult.Datapoints`, toma el último por
> `Timestamp` (epoch→ISO) y arma el `INSERT` en `metrics`.

## Importar en una instancia nueva (CLI)

1. Crea `credentials.json` a partir de `../credentials.example.json` con los valores reales
   (llaves del usuario IAM `monitoreo-cloud-n8n` y la contraseña de Postgres). **No lo versiones.**
2. Impórtalo y luego el workflow, dentro del contenedor:
   ```bash
   docker cp credentials.json n8n:/tmp/ && docker exec n8n n8n import:credentials --input=/tmp/credentials.json
   docker cp metricas-cloudwatch-postgres.json n8n:/tmp/ && docker exec n8n n8n import:workflow --input=/tmp/metricas-cloudwatch-postgres.json
   docker exec n8n n8n update:workflow --id=monitoreocloudwf --active=true
   docker compose restart n8n   # registra el cron
   rm credentials.json          # borra el plaintext
   ```

## Cómo exportar sin credenciales

`docker exec n8n n8n export:workflow --id=monitoreocloudwf --output=/tmp/wf.json` (el export no incluye
secretos, solo referencias). Verificar antes de commitear.
