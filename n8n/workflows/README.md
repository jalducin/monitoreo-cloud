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

## Cómo exportar sin credenciales

En n8n: menú del workflow → **Download** (exporta el JSON). Verificar que el JSON **no** contenga
tokens ni contraseñas (solo referencias a credenciales por nombre) antes de commitear.
