# Grafana Cloud — dashboards y alertas como código

Aquí se versionan las definiciones de dashboards (JSON) y la documentación de alertas. **Sin tokens
ni secretos embebidos** (ver `docs/n8n-aws-standards.md` §3).

## Dashboard `monitoreo-cloud` (`dashboards/monitoreo-cloud.json`)

Exportar desde Grafana Cloud (Dashboard → Share → Export → *Save to file*). Paneles mínimos:

- **CPU EC2** — `aws_ec2_cpu_utilization` (o el nombre de métrica que emita el pipeline), por `instance`.
- **Memoria EC2** — requiere CloudWatch Agent en la instancia (mejora; opcional en el MVP).
- **Invocaciones Lambda** — opcional, solo si hay funciones Lambda con métricas.
- **Errores / logs** — conteo de errores desde CloudWatch Logs (opcional).

## Alertas

Definir al menos una alerta y documentar aquí su **umbral**, **métrica** y **canal**:

| Alerta | Métrica | Condición | Canal |
|---|---|---|---|
| CPU alta sostenida | CPU EC2 | > 80% por 5 min | email/webhook |

El *contact point* (email/webhook) y el token se configuran en Grafana Cloud, **no** en el repo.

## Pasos manuales (no hay CLI oficial para el alta)

1. Crear cuenta gratuita en https://grafana.com/ (stack free).
2. En **Connections → Prometheus / Remote Write**, copiar URL, *user* (instance id) y generar un **API token**.
3. Cargar esos valores en el credential store de n8n (no aquí).
