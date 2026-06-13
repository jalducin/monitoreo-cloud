# Estándares n8n + AWS (Free Tier)

> Estándares específicos del stack de **Monitoreo Cloud**. Complementan `docs/base-standards.md`.
> Cubren n8n (workflows), AWS CLI / Free Tier, Docker en EC2 y manejo seguro de credenciales.

## 1. Free Tier como restricción dura

- **Nada fuera del Free Tier sin autorización explícita.** Límites de referencia:
  - EC2 `t3.micro`: 750 hrs/mes (una sola instancia encendida 24/7 cabe el primer año).
  - RDS `db.t3.micro` Single-AZ: 750 hrs/mes + 20 GB gp2 + 20 GB backup (**solo 12 meses**).
  - CloudWatch: 10 métricas custom, 10 alarmas, 5 GB de logs ingeridos.
  - Lambda: 1M requests/mes + 400k GB-s.
  - Grafana Cloud free: 3 usuarios, 10k series de métricas, 14 días de retención.
- **Región única**: `us-east-2` (coincide con la cuenta configurada). No crear recursos en otras regiones.
- **Etiquetado obligatorio** en todo recurso AWS: `Project=monitoreo-cloud`, `Env=free-tier`,
  `ManagedBy=cli`. Permite filtrar costos y limpiar.
- **Apagado/limpieza**: todo script que cree recursos debe tener su contraparte de borrado
  (`teardown`). Un cambio que crea infra está incompleto sin su script de limpieza.
- **Revisión de costos**: documentar cómo verificar gasto (`aws ce get-cost-and-usage`,
  Billing Console). Configurar un presupuesto de **$1 USD** con alerta por correo.

## 2. AWS CLI

- Usar el perfil `default` y región `us-east-2` salvo indicación contraria.
- Scripts en `scripts/aws/`, idempotentes: comprobar existencia antes de crear
  (`describe-*` / filtros por tag) y no fallar si el recurso ya existe.
- Nunca incrustar Account ID, IPs públicas ni claves en el repo: leerlos en tiempo de ejecución
  (`aws sts get-caller-identity`, `aws ec2 describe-instances`) o vía variables de entorno.
- Toda operación destructiva (terminate, delete) pide confirmación o requiere flag `--yes`.
- Preferir `--query` + `--output text/json` para parsear; documentar el comando en el reporte.

## 3. Seguridad y credenciales (PII / secretos)

- **Prohibido** commitear: llaves AWS, `.pem` de EC2, tokens de Grafana, API keys de OpenAI,
  credenciales de n8n, IPs o ARNs sensibles. Todo va en `.gitignore`.
- Secretos en EC2/n8n vía variables de entorno o el credential store de n8n, nunca en el workflow JSON
  exportado: exportar workflows **sin** credenciales.
- Security Group mínimo: SSH (22) restringido a la IP del operador; n8n (5678) solo lo necesario
  (idealmente detrás de túnel/HTTPS, no abierto a `0.0.0.0/0` en producción de portafolio).
- Llave SSH generada localmente; la privada nunca sale de la máquina ni del repo.

## 4. n8n (workflows)

- Workflows versionados como **JSON exportado** en `n8n/workflows/`, sin credenciales embebidas.
- Nombrar workflows y nodos en español, descriptivos (p. ej. "Jalar métricas CloudWatch").
- Idempotencia y manejo de error: cada workflow define qué pasa ante fallo (reintento/alerta).
- Programación (cron) explícita y documentada; respetar el "cada X minutos" sin saturar CloudWatch
  (cada llamada a la API de CloudWatch puede tener costo si se excede el Free Tier).
- Documentar entradas/salidas de cada workflow y las credenciales que requiere (por referencia, no valor).

## 5. Docker en EC2 y base de datos (RDS PostgreSQL)

- Stack definido en `infra/docker-compose.yml`; el contenedor de n8n es **desechable**.
- **Persistencia en AWS RDS PostgreSQL** (`DB_TYPE=postgresdb`), no en SQLite/volumen: los workflows y
  credenciales viven en la BD gestionada (con backups), sobreviviendo a la recreación del contenedor o la EC2.
- RDS dentro de Free Tier: `db.t3.micro`/`db.t4g.micro`, **Single-AZ**, 20 GB, **sin acceso público**
  (solo desde el security group de la EC2 en 5432). Recordar que el Free Tier de RDS es de 12 meses.
- Credenciales de la BD vía `.env` del host (en `.gitignore`) o secreto; nunca en el compose versionado
  ni impresas en logs. La password maestra autogenerada se guarda fuera del repo (`~/.monitoreo-cloud/`).
- Fijar versiones de imagen (no `latest`) para reproducibilidad.
- Recursos acotados al `t3.micro` (1 vCPU, 1 GB RAM): habilitar swap si hace falta; vigilar OOM.

## 6. Verificación (según pasos obligatorios OpenSpec)

- **CLI/infra**: ejecutar el script con caso válido e inválido, verificar `describe-*` posterior y
  restaurar estado (teardown) si el cambio fue de prueba.
- **n8n**: ejecutar el workflow manualmente (o un run de prueba), verificar que la métrica llega a
  Grafana; documentar el resultado.
- Documentar todos los comandos y salidas en el reporte del cambio
  (`specs/<change>/reports/`), incluyendo verificación de que **no** se salió del Free Tier.
