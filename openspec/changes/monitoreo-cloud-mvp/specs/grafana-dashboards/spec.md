## ADDED Requirements

### Requirement: Dashboard de observabilidad del EC2

El sistema SHALL proveer un dashboard en Grafana Cloud con, como mínimo, paneles de uso de CPU y de
memoria del EC2 alimentados por las métricas del pipeline. El dashboard SHALL versionarse como código
(JSON/IaC) en `grafana/` para ser reproducible.

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

El sistema SHALL definir al menos una alerta en Grafana Cloud (p. ej. CPU alta sostenida) con notificación
por email o webhook, y MUST documentar el umbral y el canal de notificación.

#### Scenario: Disparo de alerta

- **WHEN** una métrica cruza el umbral configurado durante el periodo definido
- **THEN** Grafana Cloud envía la notificación por el canal configurado (email/webhook)

#### Scenario: Umbral documentado

- **WHEN** se revisa la documentación del dashboard
- **THEN** el umbral, la métrica y el canal de la alerta están descritos explícitamente
