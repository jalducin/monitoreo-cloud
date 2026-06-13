#!/usr/bin/env bash
# Reporta el estado de los recursos de Monitoreo Cloud y cómo revisar costos.
# Uso: ./status.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_aws
ACCOUNT="$(account_id)"
log "Cuenta ${ACCOUNT} · Región ${AWS_REGION}"

echo "== Instancias (tag Project=${PROJECT_TAG}) =="
aws ec2 describe-instances --filters "${TAG_FILTER[@]}" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Estado:State.Name,Tipo:InstanceType,IP:PublicIpAddress}' \
  --output table

echo "== Security groups =="
aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \
  --query 'SecurityGroups[].{Id:GroupId,Nombre:GroupName}' --output table

echo "== Budget =="
aws budgets describe-budgets --account-id "$ACCOUNT" \
  --query 'Budgets[?starts_with(BudgetName, `monitoreo-cloud`)].{Nombre:BudgetName,Limite:BudgetLimit.Amount,Gastado:CalculatedSpend.ActualSpend.Amount}' \
  --output table 2>/dev/null || warn "No se pudo leer budgets (permisos)."

echo "== Costo del mes en curso =="
START="$(date -u +%Y-%m-01)"; END="$(date -u +%Y-%m-%d)"
[[ "$START" == "$END" ]] && END="$(date -u -d '+1 day' +%Y-%m-%d 2>/dev/null || date -u -v+1d +%Y-%m-%d)"
aws ce get-cost-and-usage --time-period "Start=${START},End=${END}" \
  --granularity MONTHLY --metrics UnblendedCost \
  --query 'ResultsByTime[0].Total.UnblendedCost' --output json 2>/dev/null \
  || warn "Cost Explorer no disponible (puede requerir habilitarse en la consola)."
