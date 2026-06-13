# Workflows de n8n

Aquí se versionan los workflows **exportados como JSON**, **sin credenciales** (ver
`docs/n8n-aws-standards.md` §4). Las credenciales (conexión a PostgreSQL) se configuran en el
*credential store* de n8n y se referencian por nombre.

## `metricas-cloudwatch-postgres` (pipeline principal)

Construir en la UI de n8n y exportar a `metricas-cloudwatch-postgres.json`. Nodos:

1. **Schedule Trigger** — cron cada N minutos (empezar conservador, p. ej. cada 5 min;
   respetar límites Free Tier de CloudWatch).
2. **AWS CloudWatch / HTTP Request** — `GetMetricData` de CPU del EC2 usando el **rol IAM de la
   instancia** (sin llaves estáticas). Dimensión `InstanceId`.
3. **Code / Function** — normaliza cada datapoint a: `metric_name`, `value`, `ts`, `instance_id`, `region`.
4. **Postgres (Insert)** — inserta en la tabla `metrics` del PostgreSQL del compose
   (credencial de n8n apuntando a `postgres:5432`, db `n8n`). Grafana lee de esa tabla.
   Activar reintento; ante fallo persistente, notificar.

> Arquitectura: **n8n → PostgreSQL (`metrics`) → Grafana (datasource Postgres)**. No se usa Grafana
> Cloud ni remote write; todo vive en la EC2.

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
