# 📊 Monitoreo Cloud — n8n + Grafana + AWS Free Tier

> Pipeline de observabilidad **serverless-friendly** que recolecta métricas de AWS CloudWatch,
> las orquesta con **n8n** (self-hosted en EC2) y las visualiza en **Grafana Cloud** —
> 100% sobre planes gratuitos. Proyecto de portafolio.
>
> **Estado:** MVP en desarrollo (Fases 1–4). · Alcance funcional: ver
> [`openspec/changes/monitoreo-cloud-mvp/`](openspec/changes/monitoreo-cloud-mvp/).

## 🎯 Qué resuelve

- Monitoreo en tiempo real de infraestructura AWS **sin costo** (AWS Free Tier + Grafana Cloud free).
- Recolección **automatizada** de métricas con workflows low-code (n8n), sin scripts ad-hoc.
- Dashboards operativos y alertas, demostrando observabilidad y cloud automation.

## 🏗️ Arquitectura

```
┌───────────────────────────────────────────────────────────────┐
│  AWS CloudWatch  — métricas (CPU, memoria, Lambda) y logs       │
└───────────────────────────────────────────────────────────────┘
                    │  pull cada N min (rol IAM, solo lectura)
                    ▼
┌───────────────────────────────────────────────────────────────┐
│  n8n  — EC2 t2.micro (Amazon Linux 2023, Docker Compose)        │
│  Schedule → CloudWatch → transforma (Prometheus) → HTTP push    │
└───────────────────────────────────────────────────────────────┘
                    │  remote write (HTTPS + token)
                    ▼
┌───────────────────────────────────────────────────────────────┐
│  Grafana Cloud  — dashboards en tiempo real + alertas           │
└───────────────────────────────────────────────────────────────┘
```

Detalle de decisiones técnicas: [`openspec/changes/monitoreo-cloud-mvp/design.md`](openspec/changes/monitoreo-cloud-mvp/design.md).

## 🛠️ Tecnologías

| Componente | Tecnología | Plan gratuito |
|---|---|---|
| Cómputo | AWS EC2 `t2.micro` (Amazon Linux 2023) | 750 hrs/mes |
| Métricas / logs | AWS CloudWatch | 10 métricas custom · 5 GB logs |
| Orquestación / ETL | n8n (Docker) | self-hosted |
| Visualización | Grafana Cloud | free (3 usuarios · 10k series) |
| Despliegue | AWS CLI + bash · Docker Compose | — |
| Costo (guardarraíl) | AWS Budgets | alerta a $1 USD |

## 📦 Requisitos

- AWS CLI v2 autenticado (`aws sts get-caller-identity`), región `us-east-2`.
- `bash` y `curl` en la máquina del operador.
- Docker / Docker Compose (se instalan en la EC2 vía user-data).
- Cuenta gratuita de Grafana Cloud (alta manual).

## 🚀 Configuración (quickstart)

```bash
git clone https://github.com/<tu-usuario>/monitoreo-cloud.git
cd monitoreo-cloud/scripts/aws
./budget.sh tu-correo@ejemplo.com 1   # guardarraíl de costo
./provision.sh                        # EC2 + SG + rol IAM + key pair (idempotente)
./status.sh                           # estado y costos
```

Despliegue completo (n8n + Grafana + pipeline): **[`docs/DEPLOY.md`](docs/DEPLOY.md)**.

## ⚙️ Scripts

| Script | Para qué |
|---|---|
| `scripts/aws/provision.sh` | Provisiona EC2 t2.micro, security group, rol IAM y key pair (idempotente) |
| `scripts/aws/budget.sh` | Crea budget de $1 USD con alerta por correo |
| `scripts/aws/status.sh` | Reporta recursos y costo del mes |
| `scripts/aws/teardown.sh` | Elimina todos los recursos por tag (`--yes` para no confirmar) |

## 📁 Estructura

```
.
├── infra/                  # docker-compose.yml de n8n
├── scripts/aws/            # provisión/teardown/status/budget (AWS CLI)
├── n8n/workflows/          # workflows exportados (JSON, sin credenciales)
├── grafana/                # dashboards y alertas como código
├── docs/                   # estándares, runbook de despliegue, fuente del proyecto
├── openspec/               # especificaciones SDD (proposal/specs/design/tasks)
└── .env.example            # plantilla de variables (el .env real no se versiona)
```

## 🔐 Seguridad

- Secretos **nunca** en el repo: `.env`, `*.pem`, tokens y credenciales están en `.gitignore`.
- n8n usa el **rol IAM de la instancia** (solo lectura de CloudWatch), sin llaves estáticas.
- Security group de mínimo privilegio (SSH y n8n solo desde la IP del operador) + basic auth en n8n.

## 📚 Documentación

- [`docs/DEPLOY.md`](docs/DEPLOY.md) — runbook de despliegue paso a paso.
- [`docs/n8n-aws-standards.md`](docs/n8n-aws-standards.md) — estándares de n8n, AWS CLI, Free Tier y secretos.
- [`openspec/`](openspec/) — especificación viva (SDD / OpenSpec).

## 🔄 Cómo contribuir (SDD)

Flujo guiado por especificaciones (OpenSpec): rama `feature/*` → `proposal` → `specs` → `design`
→ `tasks` → implementación + verificación → PR → `archive`. Ver
[`docs/base-standards.md`](docs/base-standards.md).

## 🧠 Roadmap

- **Fase 5 (futuro):** capa AI con OpenAI en n8n para detección de anomalías y alertas inteligentes.

## 💼 Para CV / LinkedIn

> Diseñé e implementé un sistema de monitoreo en tiempo real sobre AWS Free Tier, usando n8n como
> orquestador de pipelines de datos y Grafana Cloud para visualización. Integra métricas de CloudWatch,
> automatiza la recolección con workflows low-code y genera dashboards y alertas operativas —
> demostrando observabilidad, cloud automation y arquitectura serverless, con guardarraíles de costo
> (infra como código idempotente y teardown reproducible).

## 📄 Licencia

MIT.
