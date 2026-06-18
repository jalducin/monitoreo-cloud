# Estándares n8n + AWS (Free Tier)

> Estándares específicos del stack de **Monitoreo Cloud**. Complementan `docs/base-standards.md`.
> Cubren n8n (workflows), AWS CLI / Free Tier, Docker en EC2 y manejo seguro de credenciales.

## 1. Free Tier como restricción dura

- **Nada fuera del Free Tier sin autorización explícita.** Límites de referencia:
  - EC2 `t3.micro`: 750 hrs/mes (una sola instancia encendida 24/7 cabe el primer año).
  - La base de datos NO usa RDS (su Free Tier caduca a los 12 meses): PostgreSQL corre en contenedor
    dentro de la EC2 → costo $0 indefinido.
  - CloudWatch: 10 métricas custom, 10 alarmas, 5 GB de logs ingeridos.
  - Lambda: 1M requests/mes + 400k GB-s.
  - Grafana: self-hosted en contenedor (no Grafana Cloud), datasource = el PostgreSQL local. $0 indefinido.
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

## 5. Docker en EC2 y base de datos (PostgreSQL en contenedor)

- Stack definido en `infra/docker-compose.yml`: servicios `postgres` y `n8n`. El contenedor de n8n es **desechable**.
- **Persistencia en PostgreSQL containerizado** (`DB_TYPE=postgresdb` → servicio `postgres`), no en RDS ni
  SQLite: los datos viven en un **volumen persistente** de Docker, sobreviviendo a la recreación de n8n.
  Decisión por costo $0 indefinido (RDS Free Tier caduca a los 12 meses).
- `n8n` arranca tras `postgres healthy` (`depends_on` + healthcheck). La BD no se expone fuera de la red Docker.
- Credenciales de la BD vía `.env` del host (en `.gitignore`); nunca en el compose versionado ni en logs.
  La password generada se guarda fuera del repo (`~/.monitoreo-cloud/db-password.txt`).
- **Backups**: al no ser gestionada, respaldar manualmente (`pg_dump` o copia del volumen) cuando haya datos relevantes.
- Fijar versiones de imagen (no `latest`) para reproducibilidad (n8n y postgres).
- Recursos acotados al `t3.micro` (1 vCPU, 1 GB RAM): **swap de 2 GB** + `mem_limit` en Compose; vigilar OOM.

## 6. Verificación (según pasos obligatorios OpenSpec)

- **CLI/infra**: ejecutar el script con caso válido e inválido, verificar `describe-*` posterior y
  restaurar estado (teardown) si el cambio fue de prueba.
- **n8n**: ejecutar el workflow manualmente (o un run de prueba), verificar que la métrica llega a
  Grafana; documentar el resultado.
- Documentar todos los comandos y salidas en el reporte del cambio
  (`specs/<change>/reports/`), incluyendo verificación de que **no** se salió del Free Tier.
