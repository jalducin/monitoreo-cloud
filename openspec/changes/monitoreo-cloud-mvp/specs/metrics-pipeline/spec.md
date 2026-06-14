## ADDED Requirements

### Requirement: Extracción programada de métricas de CloudWatch

El sistema SHALL ejecutar un workflow de n8n que, en una programación definida (cron, cada X minutos),
extrae métricas de AWS CloudWatch de los recursos de la cuenta vía `GetMetricStatistics` usando
credenciales de **solo lectura** (usuario IAM dedicado). Implementado: **Lambda** (Invocations, Errors,
Duration por función) y **S3** (NumberOfObjects por bucket); ampliable a EC2 y otros. La frecuencia MUST
elegirse para no exceder el Free Tier de CloudWatch.

#### Scenario: Ejecución programada exitosa

- **WHEN** se cumple el intervalo programado del workflow
- **THEN** n8n consulta CloudWatch por cada función Lambda configurada y obtiene sus datapoints (suma de invocaciones) sin error

#### Scenario: Frecuencia respeta Free Tier

- **WHEN** se revisa la configuración del cron del workflow
- **THEN** el intervalo documentado mantiene el número de llamadas y métricas dentro de los límites gratuitos de CloudWatch

### Requirement: Normalización de los datapoints

El sistema SHALL transformar los datapoints de CloudWatch a filas con las columnas de la tabla `metrics`:
`metric_name`, `value`, `ts`, `instance_id`, `region` (y opcionalmente `labels`).

#### Scenario: Transformación correcta

- **WHEN** el workflow recibe datapoints de CloudWatch
- **THEN** produce, por cada datapoint, una fila con `metric_name`, `value` numérico, `ts` y los identificadores de instancia/región

### Requirement: Persistencia en PostgreSQL con manejo de error

El sistema SHALL insertar las métricas normalizadas en la tabla `metrics` del PostgreSQL del compose
(nodo Postgres de n8n) y MUST manejar los fallos de inserción con reintento o notificación, sin perder
silenciosamente datos. Grafana lee esa tabla como datasource (no se usa Grafana Cloud ni remote write).

#### Scenario: Inserción exitosa

- **WHEN** el workflow inserta las filas en la tabla `metrics`
- **THEN** las filas quedan disponibles en PostgreSQL y el dashboard de Grafana las muestra

#### Scenario: Fallo de inserción

- **WHEN** la inserción en PostgreSQL falla (BD no disponible, error de conexión)
- **THEN** el workflow reintenta según su política y, si persiste, registra/notifica el fallo en lugar de ignorarlo

### Requirement: Workflow versionado sin credenciales

El sistema SHALL versionar el workflow como JSON exportado en `n8n/workflows/`, **sin** credenciales
embebidas; las credenciales se referencian por nombre y se configuran en el credential store de n8n.

#### Scenario: Export sin secretos

- **WHEN** se exporta y commitea el workflow
- **THEN** el JSON no contiene llaves, tokens ni contraseñas, solo referencias a credenciales por nombre
