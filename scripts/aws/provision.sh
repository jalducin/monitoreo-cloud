#!/usr/bin/env bash
# Provisiona la infraestructura base de Monitoreo Cloud en AWS Free Tier (us-east-2):
#   key pair + security group mínimo + rol IAM (solo lectura CloudWatch) + EC2 t3.micro.
# Idempotente: no recrea la instancia si ya existe una con el tag del proyecto.
# Uso: ./provision.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_aws
guard_free_tier
guard_free_tier_db
ACCOUNT="$(account_id)"
log "Cuenta AWS: ${ACCOUNT} · Región: ${AWS_REGION} · EC2: ${INSTANCE_TYPE} · RDS: ${DB_INSTANCE_CLASS}"

# --- Idempotencia: ¿ya hay instancia? ---------------------------------------
EXISTING="$(find_instance)"
if [[ -n "$EXISTING" && "$EXISTING" != "None" ]]; then
  IP="$(aws ec2 describe-instances --instance-ids "$EXISTING" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
  ok "Ya existe la instancia ${EXISTING} (IP ${IP}). No se crea otra."
  exit 0
fi

# --- Key pair ----------------------------------------------------------------
mkdir -p "$KEY_DIR"; chmod 700 "$KEY_DIR"
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  ok "Key pair '${KEY_NAME}' ya existe."
else
  log "Creando key pair '${KEY_NAME}'..."
  aws ec2 create-key-pair --key-name "$KEY_NAME" \
    --tag-specifications "$(tag_spec key-pair)" \
    --query 'KeyMaterial' --output text > "${KEY_DIR}/${KEY_NAME}.pem"
  chmod 600 "${KEY_DIR}/${KEY_NAME}.pem"
  ok "Llave privada guardada en ${KEY_DIR}/${KEY_NAME}.pem (fuera del repo)."
fi

# --- Security group mínimo ---------------------------------------------------
OPERATOR_IP="$(operator_ip)"
SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)"
if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  log "Creando security group '${SG_NAME}'..."
  SG_ID="$(aws ec2 create-security-group --group-name "$SG_NAME" \
          --description "Monitoreo Cloud - acceso minimo SSH y n8n" \
          --tag-specifications "$(tag_spec security-group)" \
          --query 'GroupId' --output text)"
  ok "Security group creado: ${SG_ID}"
else
  ok "Security group '${SG_NAME}' ya existe: ${SG_ID}"
fi

# Reglas de entrada idempotentes (ignora error si ya existen).
for port in 22 "$N8N_PORT"; do
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port "$port" --cidr "$OPERATOR_IP" >/dev/null 2>&1 \
    && ok "Regla agregada: tcp/${port} desde ${OPERATOR_IP}" \
    || warn "Regla tcp/${port} desde ${OPERATOR_IP} ya existía (o sin cambio)."
done

# --- Security group de la BD (5432 solo desde el SG de la EC2) ---------------
DB_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${DB_SG_NAME}" \
           --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)"
if [[ "$DB_SG_ID" == "None" || -z "$DB_SG_ID" ]]; then
  log "Creando security group de BD '${DB_SG_NAME}'..."
  DB_SG_ID="$(aws ec2 create-security-group --group-name "$DB_SG_NAME" \
             --description "Monitoreo Cloud - acceso a RDS solo desde EC2" \
             --tag-specifications "$(tag_spec security-group)" \
             --query 'GroupId' --output text)"
  ok "Security group de BD creado: ${DB_SG_ID}"
else
  ok "Security group de BD '${DB_SG_NAME}' ya existe: ${DB_SG_ID}"
fi
aws ec2 authorize-security-group-ingress --group-id "$DB_SG_ID" \
  --protocol tcp --port "$DB_PORT" --source-group "$SG_ID" >/dev/null 2>&1 \
  && ok "Regla BD agregada: tcp/${DB_PORT} desde SG de la EC2 (${SG_ID})" \
  || warn "Regla tcp/${DB_PORT} de la BD ya existía (o sin cambio)."

# --- RDS PostgreSQL (creación sin espera; se espera al final) -----------------
DB_STATUS="$(find_rds_status)"
if [[ -n "$DB_STATUS" && "$DB_STATUS" != "None" ]]; then
  ok "RDS '${DB_INSTANCE_ID}' ya existe (estado: ${DB_STATUS}). No se crea otra."
else
  # Password maestra: usa DB_PASSWORD del entorno o genera una y la guarda fuera del repo.
  if [[ -z "${DB_PASSWORD:-}" ]]; then
    DB_PASSWORD="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)"
    echo "$DB_PASSWORD" > "${KEY_DIR}/db-password.txt"; chmod 600 "${KEY_DIR}/db-password.txt"
    warn "Password de BD generada y guardada en ${KEY_DIR}/db-password.txt (fuera del repo)."
  fi
  log "Creando RDS PostgreSQL '${DB_INSTANCE_ID}' (${DB_INSTANCE_CLASS}, Single-AZ, ${DB_ALLOCATED_GB}GB)..."
  ENGINE_ARGS=()
  [[ -n "$DB_ENGINE_VERSION" ]] && ENGINE_ARGS=(--engine-version "$DB_ENGINE_VERSION")
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine postgres "${ENGINE_ARGS[@]}" \
    --master-username "$DB_USER" --master-user-password "$DB_PASSWORD" \
    --allocated-storage "$DB_ALLOCATED_GB" --storage-type gp2 \
    --db-name "$DB_NAME" --port "$DB_PORT" \
    --vpc-security-group-ids "$DB_SG_ID" \
    --no-multi-az --no-publicly-accessible \
    --backup-retention-period 1 \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value="$ENV_TAG" Key=ManagedBy,Value=cli >/dev/null
  ok "RDS en creación (tomará varios minutos). Se esperará al final."
fi

# --- Rol IAM con solo lectura de CloudWatch ----------------------------------
if ! aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
  log "Creando rol IAM '${IAM_ROLE_NAME}'..."
  TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
  aws iam create-role --role-name "$IAM_ROLE_NAME" \
    --assume-role-policy-document "$TRUST" \
    --tags Key=Project,Value="$PROJECT_TAG" Key=Env,Value="$ENV_TAG" Key=ManagedBy,Value=cli >/dev/null
  aws iam attach-role-policy --role-name "$IAM_ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess >/dev/null
  ok "Rol IAM creado con CloudWatchReadOnlyAccess."
else
  ok "Rol IAM '${IAM_ROLE_NAME}' ya existe."
fi
if ! aws iam get-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" >/dev/null 2>&1; then
  aws iam create-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" \
    --role-name "$IAM_ROLE_NAME" >/dev/null
  ok "Instance profile creado."
  sleep 10  # propagación del instance profile
else
  ok "Instance profile '${IAM_PROFILE_NAME}' ya existe."
fi

# --- Lanzar la EC2 -----------------------------------------------------------
AMI="$(al2023_ami)"
log "AMI Amazon Linux 2023: ${AMI}"
USER_DATA="$(cat ./user-data.sh 2>/dev/null || echo '#!/bin/bash
dnf update -y
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose')"

log "Lanzando EC2 ${INSTANCE_TYPE}..."
INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$AMI" --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" --security-group-ids "$SG_ID" \
  --iam-instance-profile "Name=${IAM_PROFILE_NAME}" \
  --user-data "$USER_DATA" \
  --tag-specifications "$(tag_spec instance)" \
  --query 'Instances[0].InstanceId' --output text)"
ok "Instancia lanzada: ${INSTANCE_ID}. Esperando 'running'..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
IP="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
ok "EC2 lista: ${INSTANCE_ID} · IP pública: ${IP}"

# --- Esperar RDS disponible y reportar endpoint ------------------------------
log "Esperando a que la RDS esté 'available' (puede tardar ~5-10 min)..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_ID"
DB_ENDPOINT="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
              --query 'DBInstances[0].Endpoint.Address' --output text)"
ok "RDS disponible · endpoint: ${DB_ENDPOINT}:${DB_PORT} · db: ${DB_NAME} · user: ${DB_USER}"

echo ""
ok "Provisión completa."
log "SSH:  ssh -i ${KEY_DIR}/${KEY_NAME}.pem ec2-user@${IP}"
log "n8n:  http://${IP}:${N8N_PORT} (tras desplegar el compose)"
log "BD:   en el .env de la EC2 usa DB_POSTGRESDB_HOST=${DB_ENDPOINT}"
[[ -f "${KEY_DIR}/db-password.txt" ]] && log "Password BD en: ${KEY_DIR}/db-password.txt"
