#!/usr/bin/env bash
# Helpers comunes para los scripts de AWS CLI de Monitoreo Cloud.
# Source este archivo desde los demás scripts: `source "$(dirname "$0")/lib.sh"`
# Estándares: docs/n8n-aws-standards.md (Free Tier, tags, idempotencia, secretos).

set -euo pipefail

# En Git Bash/MSYS, los argumentos que empiezan con '/' (p. ej. el nombre del parámetro SSM
# /aws/service/...) se convierten a rutas Windows y rompen las llamadas. Lo desactivamos.
# En Linux/macOS esta variable simplemente se ignora.
export MSYS_NO_PATHCONV=1

# --- Configuración del proyecto (override por variables de entorno) ---------
export AWS_REGION="${AWS_REGION:-us-east-2}"
export AWS_DEFAULT_REGION="$AWS_REGION"
PROJECT_TAG="${PROJECT_TAG:-monitoreo-cloud}"
ENV_TAG="${ENV_TAG:-free-tier}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.micro}"   # Free Tier elegible en us-east-2 (x86_64)
KEY_NAME="${KEY_NAME:-monitoreo-cloud-key}"
SG_NAME="${SG_NAME:-monitoreo-cloud-sg}"
IAM_ROLE_NAME="${IAM_ROLE_NAME:-monitoreo-cloud-ec2-role}"
IAM_PROFILE_NAME="${IAM_PROFILE_NAME:-monitoreo-cloud-ec2-profile}"
N8N_PORT="${N8N_PORT:-5678}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
# --- RDS PostgreSQL (Free Tier: db.t3.micro, Single-AZ, 20 GB, 12 meses) ---
DB_SG_NAME="${DB_SG_NAME:-monitoreo-cloud-db-sg}"
DB_INSTANCE_ID="${DB_INSTANCE_ID:-monitoreo-cloud-db}"
DB_INSTANCE_CLASS="${DB_INSTANCE_CLASS:-db.t3.micro}"
DB_NAME="${DB_NAME:-n8n}"
DB_USER="${DB_USER:-n8nadmin}"
DB_PORT="${DB_PORT:-5432}"
DB_ALLOCATED_GB="${DB_ALLOCATED_GB:-20}"
# Vacío = deja que RDS elija la versión default de PostgreSQL (más robusto entre regiones).
DB_ENGINE_VERSION="${DB_ENGINE_VERSION:-}"
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
  # Restricción dura: el tipo debe ser free-tier-eligible en la región (varía por región/cuenta).
  # Se valida contra la API; override explícito con ALLOW_NON_FREE_TIER=1.
  [[ "${ALLOW_NON_FREE_TIER:-0}" == "1" ]] && return 0
  local eligible
  eligible="$(aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
              --query 'InstanceTypes[].InstanceType' --output text 2>/dev/null || true)"
  if [[ -n "$eligible" ]]; then
    grep -qw "$INSTANCE_TYPE" <<<"$eligible" \
      || die "INSTANCE_TYPE='$INSTANCE_TYPE' no es free-tier-eligible en ${AWS_REGION}. Opciones: ${eligible}. Usa ALLOW_NON_FREE_TIER=1 para forzar."
  else
    case "$INSTANCE_TYPE" in t3.micro|t2.micro|t4g.micro) : ;; \
      *) die "INSTANCE_TYPE='$INSTANCE_TYPE' fuera de Free Tier (no se pudo consultar la API). Usa t3.micro." ;; esac
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
# Nota: describe-db-instances falla (exit≠0) si el identificador no existe; con set -e + pipefail
# eso abortaría la sustitución $(...). Por eso se captura con `|| true` antes de filtrar.
find_rds_status() {
  local s
  s="$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
        --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || true)"
  printf '%s' "$s" | tr -d '[:space:]'
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
  local ami
  ami="$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameters[0].Value' --output text 2>/dev/null || true)"
  [[ -n "$ami" && "$ami" != "None" && "$ami" == ami-* ]] \
    || die "No se pudo resolver el AMI de Amazon Linux 2023 (obtuve: '${ami}'). Revisa permisos de SSM o MSYS_NO_PATHCONV."
  printf '%s' "$ami"
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
