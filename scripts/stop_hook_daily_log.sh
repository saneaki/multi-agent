#!/usr/bin/env bash
# ============================================================
# stop_hook_daily_log.sh — Stop Hook for Daily Log Enforcement
# ============================================================
# Checks if today's daily log exists and contains completed cmd entries.
# If missing or empty, outputs a warning message (non-blocking: exit 0).
#
# Called as a Stop hook in ~/.claude/settings.json
# ============================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
LOG_DIR="${SHOGUN_ROOT}/logs/daily"

# Get today's JST date
TODAY=$(bash "${SHOGUN_ROOT}/scripts/jst_now.sh" --date 2>/dev/null || date -u +"%Y-%m-%d")
LOG_FILE="${LOG_DIR}/${TODAY}.md"

# Non-blocking: always exit 0 but output warning if needed
if [ ! -f "$LOG_FILE" ]; then
    echo "⚠️ [daily-log-guard] 本日(${TODAY})の日報が未生成です。"
    echo "   → logs/daily/${TODAY}.md を作成し、完了cmdを記録してください。"
    echo "   → 参考: logs/daily/2026-03-29.md のフォーマットに従うこと。"
    exit 2
fi

# Check if any cmd entries exist (lines starting with "## cmd_")
CMD_COUNT=$(grep -c "^## cmd_" "$LOG_FILE" 2>/dev/null; true)
CMD_COUNT="${CMD_COUNT:-0}"
CMD_COUNT=$(echo "$CMD_COUNT" | tr -d '[:space:]')

if [ "${CMD_COUNT}" = "0" ]; then
    echo "⚠️ [daily-log-guard] 本日(${TODAY})の日報にcmdエントリがありません。"
    echo "   → ${LOG_FILE} に本日完了したcmdのサマリーを追記してください。"
    exit 2
fi

# All good
exit 0
