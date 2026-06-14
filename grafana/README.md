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

## Dashboard `trackion-tickets` — Trackion (Tickets & SLA)

> Agregado el 2026-06-14. Este Grafana también monitorea el **helpdesk Trackion**
> (proyecto aparte: `c:/Desarrollo/Python/Trackion`), no solo el pipeline n8n.

- **Dashboard:** "Trackion — Tickets & SLA" (uid `trackion-tickets`) → `http://localhost:3000/d/trackion-tickets`.
  Paneles: totales, abiertos, **SLA vencido / por vencer**, tickets por estado, **estado de SLA** (donut),
  tickets por prioridad y creados por día, más tabla de tickets con SLA vencido.
- **Datasource:** "Trackion PostgreSQL" (uid `trackionpg`) → contenedor `trackion-db-1` (BD `trackion`).
  Definido en `provisioning/datasources/trackion-postgres.yml`; el dashboard en
  `provisioning/dashboards/json/trackion-tickets.json`.
- **SLA por prioridad** (definido en Trackion): urgente 4 h · alto 6 h · medio 24 h · bajo 48 h.
  `sla_status` ∈ {En tiempo, Por vencer (≥80% del plazo), Vencido, Cumplido}.
- **Conectividad (local):** Trackion corre en su propio compose; su BD está en otra red Docker. Para que
  este Grafana la lea se conectó el contenedor a esa red:
  ```bash
  docker network connect trackion_default grafana
  ```
  Re-ejecutar si se recrea cualquiera de los dos stacks. (Despliegue actual aplicado vía API de Grafana;
  los archivos de `provisioning/` son la fuente versionada para recrearlo.)

## Alertas

Definir al menos una alerta (p. ej. CPU alta sostenida) en Grafana → Alerting, con contact point
(email/webhook). Documentar aquí umbral, métrica y canal.

| Alerta | Métrica | Condición | Canal |
|---|---|---|---|
| CPU alta sostenida | CPU EC2 | > 80% por 5 min | (por configurar) |
