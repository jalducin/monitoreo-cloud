#!/usr/bin/env bash
# Helpers comunes para los scripts de AWS CLI de Monitoreo Cloud.
# Source este archivo desde los demás scripts: `source "$(dirname "$0")/lib.sh"`
# Estándares: docs/n8n-aws-standards.md (Free Tier, tags, idempotencia, secretos).

set -euo pipefail

# --- Configuración del proyecto (override por variables de entorno) ---------
export AWS_REGION="${AWS_REGION:-us-east-2}"
export AWS_DEFAULT_REGION="$AWS_REGION"
PROJECT_TAG="${PROJECT_TAG:-monitoreo-cloud}"
ENV_TAG="${ENV_TAG:-free-tier}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"   # Free Tier: solo t2.micro
KEY_NAME="${KEY_NAME:-monitoreo-cloud-key}"
SG_NAME="${SG_NAME:-monitoreo-cloud-sg}"
IAM_ROLE_NAME="${IAM_ROLE_NAME:-monitoreo-cloud-ec2-role}"
IAM_PROFILE_NAME="${IAM_PROFILE_NAME:-monitoreo-cloud-ec2-profile}"
N8N_PORT="${N8N_PORT:-5678}"
# --- RDS PostgreSQL (Free Tier: db.t3.micro, Single-AZ, 20 GB, 12 meses) ---
DB_SG_NAME="${DB_SG_NAME:-monitoreo-cloud-db-sg}"
DB_INSTANCE_ID="${DB_INSTANCE_ID:-monitoreo-cloud-db}"
DB_INSTANCE_CLASS="${DB_INSTANCE_CLASS:-db.t3.micro}"
DB_NAME="${DB_NAME:-n8n}"
DB_USER="${DB_USER:-n8nadmin}"
DB_PORT="${DB_PORT:-5432}"
DB_ALLOCATED_GB="${DB_ALLOCATED_GB:-20}"
DB_ENGINE_VERSION="${DB_ENGINE_VERSION:-16.4}"
# Directorio local (fuera del repo) para guardar la llave .pem
KEY_DIR="${KEY_DIR:-$HOME/.monitoreo-cloud}"

# Tags comunes en formato para `aws ec2 create-tags` / filtros.
TAG_FILTER=( "Name=tag:Project,Values=${PROJECT_TAG}" )

# --- Utilidades de salida ----------------------------------------------------
log()  { printf '\033[0;36m[monitoreo-cloud]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[0;32m[ok]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[0;33m[warn]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# --- Verificaciones previas --------------------------------------------------
require_aws() {
  command -v aws >/dev/null 2>&1 || die "AWS CLI no está instalado."
  aws sts get-caller-identity >/dev/null 2>&1 || die "AWS CLI no autenticado (aws sts get-caller-identity falló)."
}

guard_free_tier() {
  # Restricción dura: solo t2.micro salvo override explícito ALLOW_NON_FREE_TIER=1
  if [[ "$INSTANCE_TYPE" != "t2.micro" && "${ALLOW_NON_FREE_TIER:-0}" != "1" ]]; then
    die "INSTANCE_TYPE='$INSTANCE_TYPE' está fuera del Free Tier. Solo 't2.micro'. Usa ALLOW_NON_FREE_TIER=1 para forzar."
  fi
}

guard_free_tier_db() {
  # RDS Free Tier: solo db.t3.micro / db.t4g.micro salvo override explícito.
  case "$DB_INSTANCE_CLASS" in
    db.t3.micro|db.t4g.micro) : ;;
    *) [[ "${ALLOW_NON_FREE_TIER:-0}" == "1" ]] || \
       die "DB_INSTANCE_CLASS='$DB_INSTANCE_CLASS' fuera de Free Tier. Solo db.t3.micro/db.t4g.micro. Usa ALLOW_NON_FREE_TIER=1 para forzar." ;;
  esac
}

# Devuelve el estado de la RDS del proyecto, o vacío si no existe.
find_rds_status() {
  aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null | tr -d '[:space:]'
}

account_id() { aws sts get-caller-identity --query Account --output text; }

# IP pública del operador (para el security group /32).
operator_ip() {
  local ip
  ip="$(curl -fsS https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')" || true
  [[ -n "$ip" ]] || die "No se pudo detectar la IP pública del operador."
  echo "${ip}/32"
}

# AMI más reciente de Amazon Linux 2023 (x86_64) vía SSM Parameter Store.
al2023_ami() {
  aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameters[0].Value' --output text
}

# Devuelve el InstanceId de la instancia del proyecto en running/pending, o vacío.
find_instance() {
  aws ec2 describe-instances \
    --filters "${TAG_FILTER[@]}" "Name=instance-state-name,Values=pending,running" \
    --query 'Reservations[].Instances[0].InstanceId' --output text 2>/dev/null | tr -d '[:space:]'
}

# Tag spec reutilizable para create.
tag_spec() {
  local resource="$1"
  echo "ResourceType=${resource},Tags=[{Key=Project,Value=${PROJECT_TAG}},{Key=Env,Value=${ENV_TAG}},{Key=ManagedBy,Value=cli}]"
}
