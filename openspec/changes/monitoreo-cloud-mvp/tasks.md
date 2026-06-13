# Tareas — monitoreo-cloud-mvp

> Cada tarea ≤ 2 horas. Orden por dependencia. Marcar `[x]` solo tras ejecutar y verificar (el agente
> ejecuta las verificaciones, nunca las delega). Convención de rama: `feature/monitoreo-cloud-mvp`.

## 0. Step 0 — Crear feature branch (SIEMPRE PRIMERO)

- [ ] 0.1 Inicializar git en el repo (si no existe) y crear/cambiar a `feature/monitoreo-cloud-mvp`
- [ ] 0.2 Confirmar `.gitignore` reforzado (`.env`, `*.pem`, secretos, `*.local`, artefactos AWS)

## 1. Scaffolding del repositorio

- [ ] 1.1 Crear estructura: `infra/`, `scripts/aws/`, `n8n/workflows/`, `grafana/`, `docs/`
- [ ] 1.2 Crear `README.md` del proyecto (arquitectura, stack, quickstart, Free Tier) según plantilla del README base
- [ ] 1.3 Crear `.env.example` (variables n8n/Grafana sin valores reales) y documentar su uso
- [ ] 1.4 Crear `docs/DEPLOY.md` con el runbook de despliegue y los pasos manuales de Grafana Cloud

## 2. infra-aws-free-tier — provisión y guardarraíles (AWS CLI)

- [ ] 2.1 `scripts/aws/lib.sh`: helpers comunes (región `us-east-2`, tags, detección de IP, idempotencia por tag)
- [ ] 2.2 `scripts/aws/provision.sh`: key pair + security group mínimo (22 y 5678 solo IP `/32` del operador)
- [ ] 2.3 `scripts/aws/provision.sh`: rol IAM + instance profile con política de **solo lectura de CloudWatch**
- [ ] 2.4 `scripts/aws/provision.sh`: lanzar EC2 `t3.micro` Amazon Linux 2023 con tags y user-data (instala Docker + swap)
- [ ] 2.5 `scripts/aws/provision.sh`: idempotencia EC2 (no recrea si ya existe instancia con tag) + abortar si el tipo no es free-tier-eligible (validado contra la API)
- [ ] 2.6 `scripts/aws/budget.sh`: AWS Budget mensual de $1 USD con alerta por email
- [ ] 2.7 `scripts/aws/status.sh`: reporta EC2, security group y comando de revisión de costos (`aws ce get-cost-and-usage`)
- [ ] 2.8 `scripts/aws/teardown.sh`: elimina recursos por tag (EC2, SG, key pair, rol IAM, budget; y RDS heredada si existiera) con confirmación/`--yes` y verificación posterior

## 3. n8n-host — Docker Compose en EC2

- [ ] 3.1 `infra/docker-compose.yml`: servicios `postgres` (imagen fijada + volumen + healthcheck) y `n8n` (imagen fijada, `DB_TYPE=postgresdb` apuntando a `postgres`, `depends_on` healthy, puerto 5678)
- [ ] 3.2 Configurar basic auth (`N8N_BASIC_AUTH_*`), credenciales de la BD (`DB_POSTGRESDB_*`/`POSTGRES_*`) y secretos vía `.env` (no versionado)
- [ ] 3.3 Documentar en `docs/DEPLOY.md` cómo subir el compose a la EC2, crear el `.env` y `docker compose up -d`
- [ ] 3.4 Verificar que `postgres` queda `healthy`, n8n conecta y aplica migraciones, y persiste tras recrear el contenedor de n8n
- [ ] 3.5 Configurar swap (2 GB) en la EC2 y `mem_limit` en Compose para evitar OOM en 1 GB

## 4. metrics-pipeline — workflow n8n

- [ ] 4.1 Crear workflow n8n: trigger cron (intervalo conservador documentado, dentro de Free Tier)
- [ ] 4.2 Nodo de extracción de métricas CloudWatch (CPU del EC2) usando el rol IAM de la instancia
- [ ] 4.3 Nodo de transformación al formato de remote write de Grafana Cloud (Prometheus): métrica, valor, timestamp, labels
- [ ] 4.4 Nodo HTTP Request a Grafana Cloud (token desde credential store) con reintento/notificación ante fallo
- [ ] 4.5 Exportar workflow a `n8n/workflows/metricas-cloudwatch-grafana.json` **sin credenciales**

## 5. grafana-dashboards — dashboards y alertas

- [ ] 5.1 Crear dashboard con paneles de CPU y memoria del EC2; exportar definición a `grafana/dashboards/`
- [ ] 5.2 Añadir panel de invocaciones Lambda y panel de errores/logs (documentar como opcional si no hay métricas)
- [ ] 5.3 Configurar al menos una alerta (CPU alta sostenida) con canal email/webhook; documentar umbral y canal
- [ ] 5.4 Versionar definiciones en `grafana/` sin tokens ni secretos embebidos

## 6. Step N — Revisar y preparar verificaciones (OBLIGATORIO)

- [ ] 6.1 Crear `scripts/aws/lint.sh` o checks (`bash -n`, `shellcheck` si está) para validar sintaxis de los scripts
- [ ] 6.2 Definir caso válido e inválido para cada script (p. ej. tipo de instancia no permitido, teardown sin recursos)
- [ ] 6.3 Validar `docker-compose.yml` con `docker compose config` y el JSON del workflow con un parser

## 7. Step N+1 — Ejecutar pruebas y verificar estado (OBLIGATORIO — EL AGENTE EJECUTA)

- [ ] 7.1 Capturar estado previo: `aws ec2 describe-instances` y `aws budgets describe-budgets` (conteos antes)
- [ ] 7.2 Ejecutar checks de sintaxis (6.1) y `docker compose config`; confirmar sin errores
- [ ] 7.3 Ejecutar `provision.sh` y verificar EC2 `running`, SG y tags vía `describe-*`
- [ ] 7.4 Verificar idempotencia: re-ejecutar `provision.sh` y confirmar que NO crea recursos nuevos
- [ ] 7.5 Verificar estado posterior y, si la corrida fue de prueba, restaurar con `teardown.sh --yes`
- [ ] 7.6 Crear el reporte en `openspec/changes/monitoreo-cloud-mvp/reports/AAAA-MM-DD-step-7-pruebas-y-verificacion.md`

## 8. Step N+2 — Verificación manual según stack (OBLIGATORIO — EL AGENTE EJECUTA)

- [ ] 8.1 **CLI/infra**: ejecutar `provision.sh` (válido) y un caso inválido (tipo no free-tier-eligible); verificar salida y códigos de retorno; restaurar con `teardown.sh`
- [ ] 8.2 **n8n + postgres**: en la EC2, `docker compose up -d`, confirmar `postgres healthy` y migraciones de n8n en logs, abrir UI, ejecutar el workflow manualmente y confirmar 2xx de Grafana Cloud
- [ ] 8.3 **Datos/observabilidad**: confirmar que las métricas llegan al dashboard de Grafana y que la alerta dispara con un umbral de prueba
- [ ] 8.4 **Costos**: ejecutar `aws ce get-cost-and-usage` y confirmar que el proyecto sigue en $0 / dentro de Free Tier
- [ ] 8.5 Documentar comandos, salidas y restauración de estado en el reporte del Step N+1

## 9. Step N+3 — Actualizar documentación técnica (OBLIGATORIO)

- [ ] 9.1 Actualizar `README.md` (arquitectura final, screenshots del dashboard) y `docs/DEPLOY.md` (runbook real)
- [ ] 9.2 Actualizar `docs/n8n-aws-standards.md` si cambió alguna convención durante la implementación
- [ ] 9.3 Verificar consistencia documental: una fuente canónica por dato, 0 enlaces rotos, índice de docs al día
- [ ] 9.4 Redactar descripción para CV/LinkedIn en el README (sección portafolio)

## 10. Cierre

- [ ] 10.1 Commit(s) con conventional commits y push de la rama `feature/monitoreo-cloud-mvp`
- [ ] 10.2 Ejecutar `/opsx:verify` contra los artefactos actualizados antes de archivar
- [ ] 10.3 Abrir PR y, tras merge, `/opsx:archive` del cambio
