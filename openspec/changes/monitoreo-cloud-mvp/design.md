## Context

No existe infraestructura ni pipeline. Partimos de una cuenta AWS ya autenticada por CLI
(`us-east-2`, perfil `default`) y queremos un MVP de observabilidad reproducible y **gratuito**
(AWS Free Tier para cómputo + software self-hosted gratuito), que además sirva de portafolio. La restricción de costo es dura:
toda decisión técnica se subordina a permanecer en los límites gratuitos.

Stakeholders: el operador/autor (uso de portafolio). Sin SLA ni multi-usuario.

Restricciones: 1 vCPU / 1 GB RAM (`t3.micro`) que aloja n8n + PostgreSQL + Grafana (con swap);
CloudWatch limitado a 10 métricas custom y 5 GB de logs; secretos jamás en el repo.

## Goals / Non-Goals

**Goals:**
- Provisión y limpieza de infra AWS **idempotente y por CLI** (reproducible, sin consola manual salvo lo inevitable).
- n8n self-hosted estable en `t3.micro` con persistencia y secretos seguros.
- Pipeline CloudWatch → n8n → PostgreSQL → Grafana (self-hosted) funcionando con dashboard y al menos una alerta.
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
n8n oficial recomienda Docker; Compose da arranque simple, versión fijada y configuración por entorno.
**Alternativa descartada:** instalar n8n vía npm (más frágil, gestión de procesos manual).

### D8 — Persistencia de n8n en PostgreSQL containerizado (no RDS, no SQLite)
n8n se configura con `DB_TYPE=postgresdb` apuntando a un servicio `postgres` en el mismo
`docker compose` (imagen fijada, volumen persistente), corriendo en la propia EC2.
**Motivación (revisada):** el objetivo es **$0 indefinido** ("tier 0"). RDS Free Tier caduca a los
12 meses (luego ~$13-15/mes); un contenedor Postgres en el `t3.micro` es gratis para siempre y
conserva el mismo esquema/driver que RDS (migración trivial, solo cambia el host).
**Alternativas descartadas:**
- *RDS PostgreSQL* — gestionado y con backups, pero gratis solo 12 meses; sobra para un MVP de portafolio.
- *SQLite (default n8n)* — lo más simple, pero menos robusto para concurrencia y respaldos.
- *DynamoDB* — **no es opción**: n8n no soporta NoSQL como backend (solo SQLite/Postgres/MySQL).
**Trade-offs:** sin backups gestionados (se documenta respaldo manual del volumen / `pg_dump`);
consume ~150-200 MB de la RAM del `t3.micro` (mitigado con swap y límites de memoria en Compose).
**Seguridad:** la BD no se expone fuera de la red de Docker; n8n la alcanza por el nombre de servicio;
credenciales en el `.env` del host (no versionado).

### D3 — Grafana **self-hosted** en la EC2 (no Grafana Cloud)
Grafana corre como contenedor (`grafana-oss`) en el mismo compose, en el puerto 3000 (abierto solo a la
IP del operador). Motivación: **$0 indefinido** y **cero pasos manuales/cuentas externas** — yo provisiono
todo por CLI/API. Grafana Cloud free es viable, pero su alta es manual (signup + token) y tiene trial de
14 días en algunos flujos; además duplica almacenamiento que ya tenemos.
**Alternativa descartada:** Grafana Cloud (manual, dependencia externa).
**RAM:** Grafana (~150-250 MB) cabe en el `t3.micro` con swap de 2 GB y `mem_limit` en Compose.
No se usa Prometheus self-hosted (pesado): el datasource es el PostgreSQL existente.

### D4 — Datasource PostgreSQL: n8n escribe en una tabla, Grafana la lee
n8n inserta los datapoints en la tabla `metrics` del PostgreSQL del compose (nodo Postgres) y Grafana
usa ese PostgreSQL como datasource. Evita Prometheus/remote write y reaprovecha la BD que ya existe.
**Alternativa descartada:** remote write a Grafana Cloud (Prometheus) — requería cuenta y token externos.
**Esquema:** `metrics(id, ts, metric_name, value, instance_id, region, labels)` con índices por `ts` y `(metric_name, ts)`.

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
  un solo `t3.micro`, teardown disponible, revisión semanal documentada.
- **OOM en el `t3.micro` (1 GB) con n8n + postgres + grafana** → mitigación: swap de 2 GB en la EC2,
  `mem_limit` por servicio en Compose; sin Prometheus (Grafana lee de Postgres).
- **Fuga de secretos** → mitigación: `.gitignore` reforzado, export de workflows sin credenciales,
  rol IAM en vez de llaves, `.pem`/tokens fuera del repo (`~/.monitoreo-cloud/`).
- **IP pública dinámica del operador rompe el SG** → mitigación: el script recalcula y actualiza la regla.
- **Acceso a Grafana/n8n por HTTP (no HTTPS)** → mitigación: puertos abiertos solo a la IP del operador;
  para portafolio es aceptable. TLS con dominio queda como mejora.
- **Pérdida de datos al recrear el contenedor** → mitigación: volumen persistente para PostgreSQL y Grafana;
  respaldo manual (`pg_dump` / copia del volumen). Los contenedores de n8n/grafana son desechables.
- **Sin backups gestionados (vs RDS)** → mitigación: `pg_dump` programado opcional; aceptable para un MVP.

## Migration Plan

Despliegue incremental (sin estado previo que migrar):
1. `scripts/aws/provision.sh` → key pair, security group (EC2), rol IAM, EC2 `t3.micro`, tags.
2. `scripts/aws/budget.sh` → budget $1 + alerta.
3. En la EC2: instalar Docker (+ swap), subir `infra/docker-compose.yml` + `.env`,
   `docker compose up -d` (levanta `postgres`, luego `n8n` y `grafana`).
4. Crear tabla `metrics` en Postgres; provisionar datasource Postgres + dashboard en Grafana (vía API/provisioning) y generar service-account token.
5. Construir el workflow n8n (CloudWatch → transformar → INSERT en `metrics`), ejecutar y validar.
6. Verificar que el dashboard de Grafana muestra las métricas y configurar la alerta.

**Rollback:** `scripts/aws/teardown.sh --yes` elimina todos los recursos por tag; en EC2,
`docker compose down` detiene el stack sin perder el volumen.

## Open Questions

- ¿Métrica de memoria del EC2 vía CloudWatch Agent (requiere instalarlo) o solo métricas nativas
  (CPU, red, disco) en el MVP? Decisión tentativa: empezar con métricas nativas; memoria vía CloudWatch Agent como mejora.
- ¿Conviene un `pg_dump` programado (cron/n8n) para respaldar la tabla `metrics` y la BD de n8n? Evaluar tras el MVP.
