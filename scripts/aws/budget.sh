#!/usr/bin/env bash
# Crea un AWS Budget mensual de 1 USD con alerta por correo (guardarraíl de costo).
# Uso: ./budget.sh tu-correo@ejemplo.com [monto_usd]
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_aws
EMAIL="${1:-}"
AMOUNT="${2:-1}"
[[ -n "$EMAIL" ]] || die "Uso: ./budget.sh <correo> [monto_usd]"
ACCOUNT="$(account_id)"
BUDGET_NAME="${BUDGET_NAME:-monitoreo-cloud-budget}"

if aws budgets describe-budget --account-id "$ACCOUNT" --budget-name "$BUDGET_NAME" >/dev/null 2>&1; then
  ok "El budget '${BUDGET_NAME}' ya existe. No se recrea."
  exit 0
fi

log "Creando budget '${BUDGET_NAME}' de \$${AMOUNT} USD/mes con alerta a ${EMAIL}..."
BUDGET_JSON="$(cat <<JSON
{"BudgetName":"${BUDGET_NAME}","BudgetLimit":{"Amount":"${AMOUNT}","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}
JSON
)"
NOTIF_JSON="$(cat <<JSON
[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"${EMAIL}"}]}]
JSON
)"
aws budgets create-budget --account-id "$ACCOUNT" \
  --budget "$BUDGET_JSON" \
  --notifications-with-subscribers "$NOTIF_JSON"
ok "Budget creado. Recibirás alerta al superar el 80% de \$${AMOUNT} USD."
log "Revisar gasto: aws ce get-cost-and-usage --time-period Start=\$(date -u +%Y-%m-01),End=\$(date -u +%Y-%m-%d) --granularity MONTHLY --metrics UnblendedCost"
