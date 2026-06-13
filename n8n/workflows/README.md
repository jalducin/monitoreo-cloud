# Workflows de n8n

Aquí se versionan los workflows **exportados como JSON**, **sin credenciales** (ver
`docs/n8n-aws-standards.md` §4). Las credenciales (token de Grafana Cloud) se configuran en el
*credential store* de n8n y se referencian por nombre.

## `metricas-cloudwatch-grafana` (pipeline principal)

Construir en la UI de n8n y exportar a `metricas-cloudwatch-grafana.json`. Nodos:

1. **Schedule Trigger** — cron cada N minutos (empezar conservador, p. ej. cada 5 min;
   respetar límites Free Tier de CloudWatch).
2. **AWS CloudWatch / HTTP Request** — `GetMetricData` de CPU del EC2 usando el **rol IAM de la
   instancia** (sin llaves estáticas). Dimensión `InstanceId`.
3. **Code / Function** — transforma los datapoints al formato de *remote write* de Grafana Cloud
   (Prometheus): nombre de métrica, valor, timestamp (ms), labels (`instance`, `region`).
4. **HTTP Request** — `POST` al endpoint de remote write de Grafana Cloud con auth básica
   (user = instance id numérico, password = API token), credencial guardada en n8n.
   Política de reintento activada; ante fallo persistente, notificar (email/webhook).

## Cómo exportar sin credenciales

En n8n: menú del workflow → **Download** (exporta el JSON). Verificar que el JSON **no** contenga
tokens ni contraseñas (solo referencias a credenciales por nombre) antes de commitear.
