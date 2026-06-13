# 📊 Monitoreo Cloud — n8n + Grafana + AWS Free Tier

> Proyecto de portafolio: pipeline de observabilidad serverless usando herramientas 100% gratuitas.
> 

## 🎯 Objetivo

Construir un sistema de monitoreo en tiempo real que demuestre dominio de **automatización**, **observabilidad** y **cloud (AWS)** usando exclusivamente el Free Tier.

## 🧱 Stack Tecnológico

| Herramienta | Rol | Plan gratuito |
| --- | --- | --- |
| **AWS EC2 t2.micro** | Hostear n8n | 750 hrs/mes |
| **AWS CloudWatch** | Fuente de métricas | 10 métricas custom, 5GB logs |
| **AWS Lambda** | Disparadores / eventos | 1M requests/mes |
| **n8n** | Orquestador / ETL de métricas | Self-hosted en EC2 |
| **Grafana Cloud** | Dashboard de visualización | Gratis (3 usuarios, 10k métricas) |

## 🔄 Arquitectura del Flujo

```
AWS CloudWatch
      ↓
   n8n (EC2 t2.micro)
   - Jala métricas cada X minutos
   - Transforma y enriquece datos
      ↓
 Grafana Cloud
   - Dashboards en tiempo real
   - Alertas configurables
```

## 📋 Fases del Proyecto

### Fase 1 — Setup Base

- [ ]  Levantar EC2 t2.micro con Amazon Linux 2
- [ ]  Instalar n8n con Docker en EC2
- [ ]  Configurar CloudWatch básico (CPU, memoria del EC2)
- [ ]  Crear cuenta Grafana Cloud gratuita

### Fase 2 — Pipeline n8n → Grafana

- [ ]  Crear workflow en n8n para leer métricas de CloudWatch via AWS SDK
- [ ]  Transformar datos al formato de Grafana (Prometheus / InfluxDB)
- [ ]  Conectar n8n con Grafana Cloud API
- [ ]  Validar que las métricas lleguen al dashboard

### Fase 3 — Dashboard

- [ ]  Panel: CPU usage EC2
- [ ]  Panel: Memory usage
- [ ]  Panel: Lambda invocations (si aplica)
- [ ]  Panel: Errores / logs de CloudWatch
- [ ]  Configurar alertas básicas (email / webhook)

### Fase 4 — Portafolio

- [ ]  Screenshots del dashboard funcionando
- [ ]  README en GitHub con arquitectura y setup
- [ ]  Agregar a `jalducin.github.io`
- [ ]  Descripción para LinkedIn/CV

## 💡 Descripción para CV / LinkedIn

> *"Diseñé e implementé un sistema de monitoreo en tiempo real sobre AWS Free Tier, utilizando n8n como orquestador de pipelines de datos y Grafana Cloud para visualización. El sistema integra métricas de CloudWatch, automatiza la recolección con workflows no-code/low-code, y genera dashboards operativos — demostrando habilidades en observabilidad, cloud automation y arquitectura serverless."*
> 

## 📝 Notas

- Mantener siempre dentro del Free Tier: revisar billing dashboard semana a semana
- n8n puede manejar múltiples fuentes en el futuro (RDS, API externas, etc.)
- Este proyecto puede escalar a Prometheus + Grafana self-hosted cuando haya presupuesto

## 🔮 Fase 5 — Capa AI (sin costo adicional)

> Solo implementar cuando la Fase 1-4 estén completas y estables.
> 

### Opción: n8n + OpenAI Free Tier

- [ ]  Crear cuenta OpenAI y usar créditos gratuitos iniciales
- [ ]  Agregar nodo de OpenAI en el workflow de n8n
- [ ]  Prompt: analizar métricas recibidas y detectar anomalías
- [ ]  Si detecta anomalía → enviar resumen por email o webhook
- [ ]  **Costo: $0** (dentro de créditos gratuitos de OpenAI)

### Flujo extendido

```
CloudWatch
    ↓
n8n — jala métricas
    ↓
OpenAI (análisis de anomalías)
    ↓
Alerta inteligente (email / Slack / webhook)
    ↓
Grafana Cloud (visualización)
```

> 💡 Con esta fase el proyecto pasa de "monitoreo" a "monitoreo inteligente con AI" — dos proyectos en uno para el portafolio.
>