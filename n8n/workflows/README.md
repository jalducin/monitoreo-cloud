# Workflows de n8n

Aquí se versionan los workflows **exportados como JSON**, **sin credenciales** (ver
`docs/n8n-aws-standards.md` §4). Las credenciales (conexión a PostgreSQL) se configuran en el
*credential store* de n8n y se referencian por nombre.

## `metricas-cloudwatch-postgres.json` (pipeline principal)

Workflow versionado (export sin secretos). Nodos:

1. **Cron 5 min** (Schedule Trigger) + **Run manual** (Execute Workflow Trigger, para pruebas por CLI).
2. **Funciones** (Code) — emite un item por función Lambda a monitorear (`metalshop-api-dev`,
   `trackion-develop-api`, `jalducin-assistant`, `trackion-develop-authorizer`).
3. **Lambda Invocations** (HTTP Request) — corre por item: `GetMetricStatistics` de `AWS/Lambda`
   `Invocations` (Sum, ventana 24h, dimensión `FunctionName={{ $json.fn }}`), firmado **SigV4** con la
   credencial AWS (usuario IAM `monitoreo-cloud-n8n`, solo lectura). n8n convierte la respuesta a JSON.
4. **Transformar** (Code) — alinea por índice con `Funciones`, toma el último datapoint y arma el `INSERT`
   (`metric_name='lambda_invocations'`, `value`, `ts`, `instance_id=<función>`, `region`).
5. **Insert metrics** (Postgres, executeQuery) — inserta en la tabla `metrics`. Grafana lee de ahí.

> Arquitectura: **CloudWatch → n8n → PostgreSQL (`metrics`) → Grafana (datasource Postgres)**. Sin Grafana
> Cloud ni remote write. Ampliable a errores/duración de Lambda, S3 y EC2 agregando funciones/métricas.

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
