## ADDED Requirements

### Requirement: Extracción programada de métricas de CloudWatch

El sistema SHALL ejecutar un workflow de n8n que, en una programación definida (cron, cada X minutos),
extrae métricas de AWS CloudWatch (al menos CPU y memoria del EC2) usando credenciales de solo lectura.
La frecuencia MUST elegirse para no exceder los límites del Free Tier de CloudWatch.

#### Scenario: Ejecución programada exitosa

- **WHEN** se cumple el intervalo programado del workflow
- **THEN** n8n consulta CloudWatch y obtiene los datapoints de las métricas configuradas sin error

#### Scenario: Frecuencia respeta Free Tier

- **WHEN** se revisa la configuración del cron del workflow
- **THEN** el intervalo documentado mantiene el número de llamadas y métricas dentro de los límites gratuitos de CloudWatch

### Requirement: Transformación al formato de Grafana

El sistema SHALL transformar los datapoints de CloudWatch al formato esperado por Grafana Cloud
(p. ej. payload de remote write / API de métricas), conservando timestamp, nombre de métrica y labels.

#### Scenario: Transformación correcta

- **WHEN** el workflow recibe datapoints de CloudWatch
- **THEN** produce un payload con el nombre de métrica, valor, timestamp y labels en el formato que Grafana Cloud acepta

### Requirement: Envío a Grafana Cloud con manejo de error

El sistema SHALL enviar las métricas transformadas a Grafana Cloud mediante su API/endpoint autenticado y
MUST manejar los fallos de envío con reintento o notificación, sin perder silenciosamente datos.

#### Scenario: Envío exitoso

- **WHEN** el payload se envía a Grafana Cloud y la API responde 2xx
- **THEN** el workflow marca la ejecución como exitosa y las métricas quedan disponibles en Grafana

#### Scenario: Fallo de envío

- **WHEN** la API de Grafana Cloud responde con error o no responde
- **THEN** el workflow reintenta según su política y, si persiste, registra/notifica el fallo en lugar de ignorarlo

### Requirement: Workflow versionado sin credenciales

El sistema SHALL versionar el workflow como JSON exportado en `n8n/workflows/`, **sin** credenciales
embebidas; las credenciales se referencian por nombre y se configuran en el credential store de n8n.

#### Scenario: Export sin secretos

- **WHEN** se exporta y commitea el workflow
- **THEN** el JSON no contiene llaves, tokens ni contraseñas, solo referencias a credenciales por nombre
