# Contexto del proyecto

> Monitoreo Cloud — pipeline de observabilidad sobre AWS Free Tier.

## Qué es

Sistema de monitoreo en tiempo real que recolecta métricas de AWS CloudWatch, las
transforma/enriquece con **n8n** (orquestador self-hosted en EC2) y las visualiza en
**Grafana Cloud**. Proyecto de portafolio que demuestra automatización, observabilidad y
arquitectura cloud usando exclusivamente planes gratuitos (AWS Free Tier + Grafana Cloud free).

## Stack tecnológico

- Orquestación / ETL: **n8n** (self-hosted, Docker en EC2 t3.micro, Amazon Linux 2023)
- Cómputo: **AWS EC2 t3.micro** (750 hrs/mes Free Tier)
- Métricas y logs: **AWS CloudWatch** (10 métricas custom, 5 GB logs Free Tier)
- Eventos / disparadores: **AWS Lambda** (1M requests/mes Free Tier) — opcional
- Visualización: **Grafana Cloud** (free: 3 usuarios, 10k series de métricas)
- Capa AI (Fase 5, opcional): **OpenAI** dentro de créditos gratuitos, vía nodo n8n
- Infra como código / despliegue: **AWS CLI** + scripts bash/PowerShell; **Docker Compose** en EC2
- Contenedores: Docker / Docker Compose

## Arquitectura

Pipeline de observabilidad (pull-based):

```
AWS CloudWatch  ──>  n8n (EC2 t3.micro, Docker)  ──>  Grafana Cloud
  métricas/logs       jala cada X min,                 dashboards +
                      transforma y enriquece           alertas
```

Fase 5 (opcional) inserta análisis de anomalías con OpenAI entre n8n y la alerta inteligente.

## Convenciones

- Idioma: documentación y comentarios en español; identificadores según convención del lenguaje.
- Commits: conventional commits.
- Ramas: `feature/[change-name]`.
- Estándares por área en `docs/*-standards.md` (ver `docs/n8n-aws-standards.md`).
- **Free Tier es restricción dura**: ningún recurso fuera de los límites gratuitos sin autorización
  explícita; revisar el billing dashboard semanalmente.

## Comandos clave

- Levantar stack local (n8n): `docker compose up -d` (en `infra/`)
- Desplegar/gestionar infra AWS: scripts en `scripts/aws/` (usan `aws` CLI, región `us-east-2`)
- Ver estado de la instancia: `aws ec2 describe-instances` (ver `scripts/aws/status.sh`)
- Verificar costos: AWS Billing Console + `aws ce get-cost-and-usage`
