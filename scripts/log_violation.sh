#!/usr/bin/env bash
# ============================================================
# Log Violation: Record rule violations to daily log
#
# Usage:
#   bash scripts/log_violation.sh <rule_id> <agent_id> <detail> [cmd_id]
#
# Example:
#   bash scripts/log_violation.sh IR-1 ashigaru3 "F001: Shogun edited implementation file directly" cmd_381/subtask_381a
#
# Output: Appends to logs/daily/YYYY-MM-DD.md
# ============================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
RULE_ID="${1:-}"
AGENT_ID="${2:-}"
DETAIL="${3:-}"
CMD_ID="${4:-}"

if [ -z "$RULE_ID" ] || [ -z "$AGENT_ID" ] || [ -z "$DETAIL" ]; then
    echo "Usage: log_violation.sh <rule_id> <agent_id> <detail> [cmd_id]" >&2
    exit 1
fi

# Get JST date and timestamp
DATE=$(bash "${SHOGUN_ROOT}/scripts/jst_now.sh" --date)
TIMESTAMP=$(bash "${SHOGUN_ROOT}/scripts/jst_now.sh" --yaml)

LOG_DIR="${SHOGUN_ROOT}/logs/daily"
LOG_FILE="${LOG_DIR}/${DATE}.md"
LOCKFILE="/tmp/log_violation.lock"

mkdir -p "$LOG_DIR"

(
    flock -w 5 200 || { echo "Failed to acquire lock" >&2; exit 1; }

    # Create daily log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        echo "# 日報 ${DATE}" > "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi

    # Append a single pipe-delimited violation line (no heading, no table header)
    # Karo consolidates these raw lines into cmd entries in Step 11.7
    echo "| ${TIMESTAMP} | ${RULE_ID} | ${AGENT_ID} | ${CMD_ID} | ${DETAIL} |" >> "$LOG_FILE"

) 200>"$LOCKFILE"

echo "violation logged: ${RULE_ID} by ${AGENT_ID} → ${LOG_FILE}"
