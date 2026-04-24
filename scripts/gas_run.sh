#!/bin/bash
set -euo pipefail
FUNC="${1:-processAllCustomers}"
CMD_ID="${2:-manual}"
cd /home/ubuntu/gas-mail-manager
echo "=== clasp run $FUNC ===" | tee /tmp/gas_run_${CMD_ID}.log
clasp run "$FUNC" 2>&1 | tee -a /tmp/gas_run_${CMD_ID}.log
echo "=== clasp logs ===" >> /tmp/gas_run_${CMD_ID}.log
clasp logs --simplified 2>&1 | tail -50 | tee -a /tmp/gas_run_${CMD_ID}.log
