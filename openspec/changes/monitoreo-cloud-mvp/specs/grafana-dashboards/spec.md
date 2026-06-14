## ADDED Requirements

### Requirement: Dashboard de observabilidad

El sistema SHALL proveer un dashboard en **Grafana self-hosted** (contenedor) alimentado desde el
**datasource PostgreSQL** (tabla `metrics`), con paneles de: **invocaciones**, **errores** y **duración**
por función Lambda (serie por `instance_id`) y **objetos en S3** por bucket; ampliable a EC2 y otros.
El dashboard SHALL versionarse como código (JSON) en `grafana/` para ser reproducible. El acceso a Grafana
SHALL restringirse a la IP del operador (security group en AWS, o solo `localhost` en modo local).

#### Scenario: Paneles con datos

- **WHEN** el pipeline ha enviado métricas y el operador abre el dashboard
- **THEN** los paneles de CPU y memoria muestran las series temporales recibidas

#### Scenario: Dashboard reproducible

- **WHEN** se inspecciona el repositorio
- **THEN** existe la definición del dashboard como código en `grafana/`, sin tokens ni secretos embebidos

### Requirement: Paneles adicionales según disponibilidad

El sistema SHALL incluir paneles para invocaciones de Lambda (si aplica) y para errores/logs de
CloudWatch cuando esas métricas estén disponibles en el pipeline.

#### Scenario: Panel de Lambda condicional

- **WHEN** existen métricas de Lambda en el pipeline
- **THEN** el dashboard muestra un panel de invocaciones de Lambda; si no hay métricas, el panel se documenta como opcional

### Requirement: Alerta básica configurada

El sistema SHALL definir al menos una alerta en Grafana (p. ej. CPU alta sostenida) con notificación
por email o webhook, y MUST documentar el umbral y el canal de notificación.

#### Scenario: Disparo de alerta

- **WHEN** una métrica cruza el umbral configurado durante el periodo definido
- **THEN** Grafana envía la notificación por el canal configurado (email/webhook)

#### Scenario: Umbral documentado

- **WHEN** se revisa la documentación del dashboard
- **THEN** el umbral, la métrica y el canal de la alerta están descritos explícitamente
