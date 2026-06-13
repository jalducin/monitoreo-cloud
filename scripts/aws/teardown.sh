#!/usr/bin/env bash
# Elimina TODOS los recursos de Monitoreo Cloud (instancia, SG, key pair, rol IAM, budget).
# Filtra por el tag Project. Requiere confirmación o flag --yes.
# Uso: ./teardown.sh [--yes] [--keep-budget]
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_aws
ACCOUNT="$(account_id)"
ASSUME_YES=0; KEEP_BUDGET=0
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --keep-budget) KEEP_BUDGET=1 ;;
    *) die "Argumento desconocido: $arg" ;;
  esac
done

if [[ "$ASSUME_YES" != "1" ]]; then
  read -r -p "¿Eliminar TODOS los recursos con tag Project=${PROJECT_TAG} en ${AWS_REGION}? (escribe 'si'): " ans
  [[ "$ans" == "si" ]] || { warn "Cancelado."; exit 0; }
fi

# --- Terminar instancias -----------------------------------------------------
IDS="$(aws ec2 describe-instances --filters "${TAG_FILTER[@]}" \
       "Name=instance-state-name,Values=pending,running,stopping,stopped" \
       --query 'Reservations[].Instances[].InstanceId' --output text)"
if [[ -n "$IDS" ]]; then
  log "Terminando instancias: ${IDS}"
  aws ec2 terminate-instances --instance-ids $IDS >/dev/null
  aws ec2 wait instance-terminated --instance-ids $IDS
  ok "Instancias terminadas."
else
  ok "No hay instancias que terminar."
fi

# --- Security group ----------------------------------------------------------
SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)"
if [[ -n "$SG_ID" && "$SG_ID" != "None" ]]; then
  aws ec2 delete-security-group --group-id "$SG_ID" >/dev/null 2>&1 \
    && ok "Security group ${SG_ID} eliminado." || warn "No se pudo eliminar el SG (¿en uso aún?)."
fi

# --- Key pair ----------------------------------------------------------------
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
  aws ec2 delete-key-pair --key-name "$KEY_NAME" >/dev/null
  ok "Key pair '${KEY_NAME}' eliminado de AWS (la .pem local se conserva)."
fi

# --- Rol IAM + instance profile ---------------------------------------------
if aws iam get-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" >/dev/null 2>&1; then
  aws iam remove-role-from-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1 || true
  aws iam delete-instance-profile --instance-profile-name "$IAM_PROFILE_NAME" >/dev/null 2>&1 || true
  ok "Instance profile eliminado."
fi
if aws iam get-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1; then
  aws iam detach-role-policy --role-name "$IAM_ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess >/dev/null 2>&1 || true
  aws iam delete-role --role-name "$IAM_ROLE_NAME" >/dev/null 2>&1 || true
  ok "Rol IAM eliminado."
fi

# --- Budget ------------------------------------------------------------------
if [[ "$KEEP_BUDGET" != "1" ]]; then
  if aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "monitoreo-cloud-budget" >/dev/null 2>&1; then
    aws budgets delete-budget --account-id "$ACCOUNT" --budget-name "monitoreo-cloud-budget" >/dev/null
    ok "Budget eliminado."
  fi
fi

# --- Verificación posterior --------------------------------------------------
REMAIN="$(find_instance)"
[[ -z "$REMAIN" || "$REMAIN" == "None" ]] && ok "Verificado: no quedan instancias del proyecto." \
  || warn "Aún se reportan instancias: ${REMAIN}"
ok "Teardown completo."
