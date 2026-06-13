## Context

No existe infraestructura ni pipeline. Partimos de una cuenta AWS ya autenticada por CLI
(`us-east-2`, perfil `default`) y queremos un MVP de observabilidad reproducible y **gratuito**
(AWS Free Tier + Grafana Cloud free), que además sirva de portafolio. La restricción de costo es dura:
toda decisión técnica se subordina a permanecer en los límites gratuitos.

Stakeholders: el operador/autor (uso de portafolio). Sin SLA ni multi-usuario.

Restricciones: 1 vCPU / 1 GB RAM (`t2.micro`); CloudWatch limitado a 10 métricas custom y 5 GB de logs;
Grafana Cloud free con retención de 14 días; secretos jamás en el repo.

## Goals / Non-Goals

**Goals:**
- Provisión y limpieza de infra AWS **idempotente y por CLI** (reproducible, sin consola manual salvo lo inevitable).
- n8n self-hosted estable en `t2.micro` con persistencia y secretos seguros.
- Pipeline CloudWatch → n8n → Grafana Cloud funcionando con dashboards y al menos una alerta.
- Guardarraíles de costo (budget $1 + alerta) y teardown completo.
- Repo público con README de portafolio.

**Non-Goals:**
- Fase 5 (capa AI con OpenAI) — fuera del MVP.
- Alta disponibilidad, multi-región, autoscaling, IaC avanzado (Terraform/CDK) — se usa AWS CLI + bash.
- Hardening de producción (WAF, HTTPS gestionado con dominio) más allá del mínimo razonable.

## Decisions

### D1 — AWS CLI + bash en `scripts/aws/` en lugar de Terraform/CDK
Para un MVP de un solo recurso, Terraform/CDK añade tooling y estado que no aporta. Scripts CLI
idempotentes (consultar por tag antes de crear) son suficientes y transparentes.
**Alternativa descartada:** Terraform (mejor para infra creciente; reconsiderar si escala).
**Trade-off:** la idempotencia es responsabilidad nuestra (checks explícitos por tag).

### D2 — Docker Compose para n8n en EC2
n8n oficial recomienda Docker; Compose da persistencia por volumen, versión fijada y arranque simple.
**Alternativa descartada:** instalar n8n vía npm (más frágil, gestión de procesos manual).

### D3 — Grafana **Cloud** (no self-hosted)
El `t2.micro` no soporta cómodamente n8n + Grafana + Prometheus. Grafana Cloud free externaliza
almacenamiento y dashboards sin costo y con retención suficiente para el MVP.
**Alternativa descartada:** Grafana + Prometheus self-hosted en el mismo EC2 (riesgo de OOM en 1 GB RAM).
**Implicación:** el alta de la cuenta Grafana Cloud y la obtención del endpoint/token de remote write
son **pasos manuales** (no hay CLI oficial para crear la cuenta); se documentan en el README.

### D4 — Ingesta vía Grafana Cloud remote write (Prometheus) desde n8n
n8n arma el payload (HTTP Request node) hacia el endpoint de remote write de Grafana Cloud con el
token en el credential store. Formato de métricas tipo Prometheus.
**Alternativa considerada:** Influx line protocol — equivalente; se elige Prometheus por ser el default de Grafana Cloud.

### D5 — Credenciales AWS para n8n: rol IAM de la instancia (no llaves estáticas)
n8n leerá CloudWatch usando el **instance profile** (rol IAM con política de solo lectura de CloudWatch),
evitando llaves estáticas en el contenedor. El SDK/HTTP usa las credenciales temporales del metadata.
**Alternativa descartada:** Access keys en `.env` (riesgo de fuga, rotación manual).

### D6 — Security group de mínimo privilegio + basic auth en n8n
SSH (22) y n8n (5678) solo desde la IP `/32` del operador; n8n con `N8N_BASIC_AUTH` activo.
**Trade-off:** si la IP del operador cambia, hay que actualizar la regla (script lo recalcula).

### D7 — Guardarraíles de costo: AWS Budgets $1 + tag obligatorio
Budget mensual de $1 con alerta por email; todo recurso etiquetado `Project/Env/ManagedBy` para
filtrar costos y para que el teardown encuentre todo.

## Risks / Trade-offs

- **Salirse del Free Tier** → mitigación: budget $1 + alerta, frecuencia de cron conservadora,
  un solo `t2.micro`, teardown disponible, revisión semanal documentada.
- **OOM en `t2.micro` (1 GB)** → mitigación: solo n8n en el host (Grafana en la nube), swap opcional,
  límites de recursos en Compose.
- **Fuga de secretos** → mitigación: `.gitignore` reforzado, export de workflows sin credenciales,
  rol IAM en vez de llaves, `.pem` fuera del repo.
- **IP pública dinámica del operador rompe el SG** → mitigación: el script recalcula y actualiza la regla.
- **Pasos manuales en Grafana Cloud (alta + token)** → mitigación: documentados paso a paso; el token
  se inyecta vía credential store, nunca al repo.
- **Pérdida de datos de n8n al recrear contenedor** → mitigación: volumen persistente.

## Migration Plan

Despliegue incremental (sin estado previo que migrar):
1. `scripts/aws/provision.sh` → key pair, security group, rol IAM, EC2 `t2.micro`, tags.
2. `scripts/aws/budget.sh` → budget $1 + alerta.
3. En la EC2: instalar Docker, subir `infra/docker-compose.yml` + `.env`, `docker compose up -d`.
4. Configurar credenciales en n8n (rol IAM ya disponible; token Grafana en credential store).
5. Importar `n8n/workflows/*.json`, ejecutar y validar llegada de métricas a Grafana.
6. Importar dashboard y alerta desde `grafana/`.

**Rollback:** `scripts/aws/teardown.sh --yes` elimina todos los recursos por tag; en EC2,
`docker compose down` detiene el stack sin perder el volumen.

## Open Questions

- ¿Métrica de memoria del EC2 vía CloudWatch Agent (requiere instalarlo) o solo métricas nativas
  (CPU, red, disco) en el MVP? Decisión tentativa: empezar con métricas nativas; memoria vía CloudWatch Agent como mejora.
- ¿Region del stack de Grafana Cloud más cercana para minimizar latencia de remote write? Se define al dar de alta la cuenta.
