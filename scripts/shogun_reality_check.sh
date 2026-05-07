#!/usr/bin/env bash
# shogun_reality_check.sh — 将軍見回りスクリプト
# 6項目検査 + 将軍 inbox 通知 (冪等)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${SCRIPT_DIR}/.venv/bin/python3"
SHOGUN_INBOX="${SCRIPT_DIR}/queue/inbox/shogun.yaml"
RULES_PY="${SCRIPT_DIR}/scripts/lib/status_check_rules.py"

already_sent() {
    local alert_key="$1"
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, sys
from datetime import datetime, timedelta, timezone

try:
    with open('${SHOGUN_INBOX}') as f:
        data = yaml.safe_load(f)
    if data is None:
        data = {}
    if not data.get('messages'):
        print('no'); sys.exit(0)

    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)

    for msg in data.get('messages', []):
        if msg.get('type') != 'reality_check_alert':
            continue
        if '${alert_key}' not in str(msg.get('content', '')):
            continue
        ts_str = str(msg.get('timestamp', ''))
        try:
            if ts_str.endswith('Z'):
                ts_str = ts_str[:-1] + '+00:00'
            ts = datetime.fromisoformat(ts_str)
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if ts >= one_hour_ago:
                print('yes'); sys.exit(0)
        except ValueError:
            continue
    print('no')
except FileNotFoundError:
    print('no')
except Exception:
    print('no')
PYEOF
}

send_alert() {
    local content="$1"
    local with_ntfy="${2:-no}"

    bash "${SCRIPT_DIR}/scripts/inbox_write.sh" shogun "${content}" reality_check_alert shogun_reality_check

    if [ "${with_ntfy}" = "yes" ]; then
        bash "${SCRIPT_DIR}/scripts/notify.sh" "${content}" "⚠️ 将軍見回り検知" "reality_check_alert" 2>/dev/null || true
    fi
}

run_rule_check() {
    local check_name="$1"
    "${PYTHON}" "${RULES_PY}" "${check_name}" "${SCRIPT_DIR}" 2>/dev/null || true
}

handle_check_result() {
    local idx="$1"
    local result="$2"
    local with_ntfy="$3"

    if [[ "${result}" == "ok" ]]; then
        return
    fi

    local alert_key="見回り-${idx}"
    if [[ "${result}" == error:* ]]; then
        alert_key="見回り-ERR-${idx}"
        if [ "$(already_sent "${alert_key}")" = "no" ]; then
            send_alert "🚨 [${alert_key}] 見回り自体の異常: ${result}" "yes"
            ALERTS_FOUND=$((ALERTS_FOUND + 1))
            echo "${JST_NOW} [reality_check] ERROR: ${result}"
        fi
        return
    fi

    if [ "$(already_sent "${alert_key}")" = "no" ]; then
        send_alert "⚠️ [${alert_key}] ${result}" "${with_ntfy}"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${result}"
    fi
}

JST_NOW=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
ALERTS_FOUND=0

RESULT1=$(run_rule_check check_dashboard_stall)
handle_check_result "1" "${RESULT1}" "yes"

RESULT2=$(run_rule_check check_ash_done_pending)
handle_check_result "2" "${RESULT2}" "yes"

RESULT3=$(run_rule_check check_inbox_unread)
handle_check_result "3" "${RESULT3}" "yes"

RESULT4=$(run_rule_check check_action_required_stale)
handle_check_result "4" "${RESULT4}" "no"

RESULT5=$(run_rule_check check_hook_liveness)
handle_check_result "5" "${RESULT5}" "no"

RESULT6=$(run_rule_check check_git_uncommitted)
handle_check_result "6" "${RESULT6}" "no"

if [ "${ALERTS_FOUND}" -eq 0 ]; then
    echo "${JST_NOW} [reality_check] 全6項目異常なし"
else
    echo "${JST_NOW} [reality_check] ${ALERTS_FOUND}件のアラートを将軍 inbox に送信"
fi
