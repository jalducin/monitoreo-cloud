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
ACCOUNT="$(account_id)"
log "Cuenta AWS: ${ACCOUNT} · Región: ${AWS_REGION} · EC2: ${INSTANCE_TYPE} · BD: PostgreSQL en contenedor"

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
for port in 22 "$N8N_PORT" "$GRAFANA_PORT"; do
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port "$port" --cidr "$OPERATOR_IP" >/dev/null 2>&1 \
    && ok "Regla agregada: tcp/${port} desde ${OPERATOR_IP}" \
    || warn "Regla tcp/${port} desde ${OPERATOR_IP} ya existía (o sin cambio)."
done

# Nota: la base de datos NO usa RDS. PostgreSQL corre en un contenedor dentro de la EC2
# (ver infra/docker-compose.yml) para mantener el costo en $0 indefinido.

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
# Swap de 2 GB (el t3.micro tiene 1 GB; n8n + postgres lo agradecen)
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
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

echo ""
ok "Provisión completa."
log "SSH:  ssh -i ${KEY_DIR}/${KEY_NAME}.pem ec2-user@${IP}"
log "n8n:  http://${IP}:${N8N_PORT} (tras desplegar el compose con postgres)"
log "BD:   PostgreSQL corre en contenedor (servicio 'postgres'); configúralo en el .env de la EC2."
