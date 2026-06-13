## Why

Necesitamos un sistema de monitoreo en tiempo real que sirva como pieza de portafolio y que
demuestre dominio de automatización, observabilidad y cloud (AWS), **sin incurrir en costos**:
todo debe vivir dentro del AWS Free Tier (cómputo) y con software self-hosted gratuito. Hoy no existe infraestructura ni
pipeline; este cambio entrega el MVP (Fases 1–4 del documento fuente) de extremo a extremo:
provisión reproducible por CLI, recolección automatizada de métricas y visualización con alertas.

## What Changes

- Provisión por **AWS CLI idempotente** (región `us-east-2`) de una EC2 `t3.micro` (Amazon Linux 2023),
  key pair, security group mínimo y etiquetado obligatorio (`Project/Env/ManagedBy`).
- **Presupuesto de billing de $1 USD con alerta por correo** y comandos documentados para revisar gasto.
- **n8n self-hosted** en la EC2 vía **Docker Compose**, con secretos fuera del repo.
- **Persistencia en PostgreSQL containerizado** (servicio `postgres` en el mismo compose, volumen
  persistente): n8n usa Postgres como backend (`DB_TYPE=postgresdb`) en vez de SQLite, manteniendo
  el costo en **$0 indefinido** (sin RDS, cuyo Free Tier caduca a los 12 meses).
- **Workflow n8n** que jala métricas de CloudWatch cada X minutos, las normaliza e **inserta en la
  tabla `metrics` de PostgreSQL**, versionado como JSON **sin credenciales**.
- **Grafana self-hosted** (contenedor en la EC2, puerto 3000 solo a la IP del operador) con datasource
  PostgreSQL: dashboards (CPU EC2, memoria, Lambda si aplica) y alerta básica por email/webhook.
- **Script de teardown** que elimina todos los recursos creados (contraparte obligatoria de la provisión).
- Documentación de portafolio: README con arquitectura y setup; base para `jalducin.github.io`.
- **Fuera de alcance (no en este MVP):** Fase 5 (capa AI con OpenAI para detección de anomalías).

## Capabilities

### New Capabilities
- `infra-aws-free-tier`: provisión y limpieza idempotente por AWS CLI de la infraestructura base
  (EC2 t3.micro, key pair, security group, tags) y guardarraíles de costo (budget $1 + alerta billing),
  garantizando permanencia dentro del Free Tier en `us-east-2`.
- `n8n-host`: n8n self-hosted en la EC2 con Docker Compose, **persistencia en PostgreSQL containerizado**
  (volumen persistente) y manejo seguro de secretos (env/credential store, nunca en el repo).
- `metrics-pipeline`: workflow n8n programado que extrae métricas de CloudWatch, las normaliza e
  inserta en la tabla `metrics` de PostgreSQL, con manejo de error/reintento.
- `grafana-dashboards`: Grafana self-hosted con datasource PostgreSQL; dashboards y alertas sobre las
  métricas (CPU, memoria, Lambda, errores/logs), con al menos una alerta por email/webhook.

### Modified Capabilities
<!-- Ninguna: no existen specs previas en openspec/specs/. -->

## Impact

- **Nuevo**: `infra/` (docker-compose de n8n), `scripts/aws/` (provisión/teardown/status/budget),
  `n8n/workflows/` (JSON exportado sin secretos), `grafana/` (dashboards/alertas como código),
  `README.md` del proyecto, `.gitignore` reforzado para secretos.
- **AWS** (cuenta configurada, `us-east-2`): EC2, CloudWatch, IAM mínimo, Budgets — todo Free Tier (sin RDS).
- **Servicios externos**: ninguno (Grafana y PostgreSQL self-hosted en la EC2).
- **Dependencias**: Docker/Docker Compose en EC2, AWS CLI local, `gh` para el repo, imágenes fijadas (n8n, postgres, grafana).
- **Riesgos**: salir del Free Tier (mitigado con budget+alerta+teardown; sin RDS para evitar el corte de
  12 meses), OOM en el `t3.micro` con n8n+postgres (mitigado con swap + límites de memoria),
  exposición de secretos (mitigado con `.gitignore` + export sin credenciales + security group mínimo).
