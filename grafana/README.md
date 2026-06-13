# Grafana (self-hosted) — dashboards y alertas

Grafana corre **self-hosted en la EC2** (contenedor `grafana` del compose), no en Grafana Cloud.
Datasource = el **PostgreSQL** del propio compose (tabla `metrics`). Costo $0 indefinido, sin cuenta externa.

- URL: `http://<IP-EC2>:3000` (puerto abierto solo a la IP del operador).
- Admin: usuario/clave en `~/.monitoreo-cloud/n8n-credenciales.txt` (no versionado).
- Token de service account (API): `~/.monitoreo-cloud/grafana-token.txt` (no versionado).

## Provisioning (reproducible)

`provisioning/` versiona la configuración como código:

- `datasources/postgres.yml` — datasource PostgreSQL (password vía `$POSTGRES_PASSWORD`, no se versiona el valor).
- `dashboards/provider.yml` + `dashboards/json/monitoreo-cloud.json` — dashboard cargado desde archivo.

Para un despliegue reproducible, montar esta carpeta en el contenedor:
`-v ./grafana/provisioning:/etc/grafana/provisioning`.

> La instancia actual se inicializó vía API de Grafana (datasource + token + dashboard). Estos archivos
> son la fuente versionada para recrearla.

## Dashboard `monitoreo-cloud`

Panel inicial: **CPU EC2 (%)** leyendo de la tabla `metrics` (columnas `ts`, `value`, `metric_name`).
A medida que el pipeline escriba más métricas (memoria, Lambda), se agregan paneles.

## Alertas

Definir al menos una alerta (p. ej. CPU alta sostenida) en Grafana → Alerting, con contact point
(email/webhook). Documentar aquí umbral, métrica y canal.

| Alerta | Métrica | Condición | Canal |
|---|---|---|---|
| CPU alta sostenida | CPU EC2 | > 80% por 5 min | (por configurar) |
