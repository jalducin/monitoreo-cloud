# Runbook de despliegue — Monitoreo Cloud

Despliegue del MVP en AWS Free Tier (`us-east-2`). Requisitos locales: AWS CLI autenticado,
`bash`, `curl`. Estándares: `docs/n8n-aws-standards.md`.

> **Restricción dura:** todo dentro del Free Tier. Antes y después de desplegar, revisa costos.

## 0. Prerrequisitos

```bash
aws sts get-caller-identity        # confirma cuenta y autenticación
aws configure get region           # debe ser us-east-2 (o exporta AWS_REGION)
```

## 1. Guardarraíl de costo (primero)

```bash
cd scripts/aws
./budget.sh tu-correo@ejemplo.com 1     # budget mensual de $1 con alerta al 80%
```

## 2. Provisionar infraestructura (AWS CLI, idempotente)

```bash
./provision.sh
# Crea: key pair (.pem en ~/.monitoreo-cloud/), security group de EC2 (22 y 5678 solo tu IP),
#       security group de BD (5432 solo desde la EC2), rol IAM (CloudWatchReadOnlyAccess) +
#       instance profile, EC2 t3.micro (Amazon Linux 2023) y RDS PostgreSQL db.t3.micro (Single-AZ).
# Imprime InstanceId, IP pública, endpoint de RDS y el comando SSH.
# La password de la BD, si se autogenera, queda en ~/.monitoreo-cloud/db-password.txt.
./status.sh                              # verifica EC2, RDS, SGs y costos
```

> RDS tarda ~5-10 min en quedar `available`; el script espera automáticamente.

## 3. Desplegar n8n en la EC2 (Docker Compose)

```bash
# Copia el compose y crea el .env en la instancia (NO se versiona):
scp -i ~/.monitoreo-cloud/monitoreo-cloud-key.pem infra/docker-compose.yml ec2-user@<IP>:~/
ssh -i ~/.monitoreo-cloud/monitoreo-cloud-key.pem ec2-user@<IP>

# En la EC2:
cp /ruta/.env.example .env && nano .env   # rellena basic auth, host, encryption key
                                           # y DB_POSTGRESDB_HOST/USER/PASSWORD con los datos de RDS
docker compose up -d
docker compose ps                          # n8n debe estar 'running' en :5678
docker compose logs n8n | grep -i database # confirma conexión a PostgreSQL (RDS) sin error
```

Abre `http://<IP>:5678`, inicia sesión (basic auth) y completa el setup de n8n.

## 4. Grafana Cloud (pasos manuales)

1. Crea cuenta free en https://grafana.com/ y un stack.
2. En **Connections → Prometheus (remote write)**: copia URL, *user* (instance id) y genera **API token**.
3. En n8n, crea una credencial HTTP (Basic Auth) con esos valores (queda cifrada en el volumen).

## 5. Pipeline y dashboards

1. Construye el workflow `metricas-cloudwatch-grafana` (ver `n8n/workflows/README.md`), ejecútalo
   manualmente y confirma respuesta 2xx de Grafana.
2. Expórtalo **sin credenciales** a `n8n/workflows/metricas-cloudwatch-grafana.json`.
3. En Grafana Cloud crea el dashboard (ver `grafana/README.md`), expórtalo a `grafana/dashboards/`.
4. Configura la alerta de CPU y su contact point.

## 6. Verificación

```bash
cd scripts/aws && ./status.sh            # instancia, SG, budget, costo del mes
```
- n8n responde con basic auth en `:5678`.
- Las métricas aparecen en el dashboard de Grafana.
- La alerta dispara con un umbral de prueba.
- El costo del mes sigue en \$0 / dentro del Free Tier.

## 7. Limpieza (rollback / fin de demo)

```bash
cd scripts/aws
./teardown.sh --yes                      # elimina instancia, SG, key pair, rol IAM y budget por tag
./status.sh                              # confirma que no quedan recursos
```
> En la EC2, `docker compose down` detiene n8n sin borrar el volumen `n8n_data`.
