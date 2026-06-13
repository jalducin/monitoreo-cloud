## Why

Necesitamos un sistema de monitoreo en tiempo real que sirva como pieza de portafolio y que
demuestre dominio de automatización, observabilidad y cloud (AWS), **sin incurrir en costos**:
todo debe vivir dentro del AWS Free Tier y de Grafana Cloud free. Hoy no existe infraestructura ni
pipeline; este cambio entrega el MVP (Fases 1–4 del documento fuente) de extremo a extremo:
provisión reproducible por CLI, recolección automatizada de métricas y visualización con alertas.

## What Changes

- Provisión por **AWS CLI idempotente** (región `us-east-2`) de una EC2 `t2.micro` (Amazon Linux 2023),
  key pair, security group mínimo y etiquetado obligatorio (`Project/Env/ManagedBy`).
- **Presupuesto de billing de $1 USD con alerta por correo** y comandos documentados para revisar gasto.
- **n8n self-hosted** en la EC2 vía **Docker Compose**, con volumen persistente y secretos fuera del repo.
- **Workflow n8n** que jala métricas de CloudWatch cada X minutos, las transforma/enriquece y las
  publica a **Grafana Cloud** (remote write / API), versionado como JSON **sin credenciales**.
- **Dashboards y alertas en Grafana Cloud**: CPU EC2, memoria, invocaciones Lambda (si aplica),
  errores/logs de CloudWatch; alerta básica por email/webhook.
- **Script de teardown** que elimina todos los recursos creados (contraparte obligatoria de la provisión).
- Documentación de portafolio: README con arquitectura y setup; base para `jalducin.github.io`.
- **Fuera de alcance (no en este MVP):** Fase 5 (capa AI con OpenAI para detección de anomalías).

## Capabilities

### New Capabilities
- `infra-aws-free-tier`: provisión y limpieza idempotente por AWS CLI de la infraestructura base
  (EC2 t2.micro, key pair, security group, tags) y guardarraíles de costo (budget $1 + alerta billing),
  garantizando permanencia dentro del Free Tier en `us-east-2`.
- `n8n-host`: n8n self-hosted en la EC2 con Docker Compose, persistencia de workflows/credenciales y
  manejo seguro de secretos (env/credential store, nunca en el repo).
- `metrics-pipeline`: workflow n8n programado que extrae métricas de CloudWatch, las transforma al
  formato de Grafana y las envía a Grafana Cloud, con manejo de error/reintento e idempotencia.
- `grafana-dashboards`: dashboards y alertas en Grafana Cloud sobre las métricas recibidas
  (CPU, memoria, Lambda, errores/logs), con al menos una alerta por email/webhook.

### Modified Capabilities
<!-- Ninguna: no existen specs previas en openspec/specs/. -->

## Impact

- **Nuevo**: `infra/` (docker-compose de n8n), `scripts/aws/` (provisión/teardown/status/budget),
  `n8n/workflows/` (JSON exportado sin secretos), `grafana/` (dashboards/alertas como código),
  `README.md` del proyecto, `.gitignore` reforzado para secretos.
- **AWS** (cuenta configurada, `us-east-2`): EC2, CloudWatch, IAM mínimo, Budgets — todo Free Tier.
- **Servicios externos**: Grafana Cloud (cuenta free, paso manual de alta documentado).
- **Dependencias**: Docker/Docker Compose en EC2, AWS CLI local, `gh` para el repo, n8n (imagen fijada).
- **Riesgos**: salir del Free Tier (mitigado con budget+alerta+teardown), exposición de secretos
  (mitigado con `.gitignore` + export sin credenciales + security group mínimo).
