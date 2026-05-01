#!/usr/bin/env bash
# cmd_kpi_observer.sh — 完遂 cmd の KPI を観測し dashboard 運用指標に書込む (cmd_593 Scope C / AC5)
#
# Usage: bash scripts/cmd_kpi_observer.sh [--dry-run] [--date YYYY-MM-DD]
# cron:  0 9 * * * bash /home/ubuntu/shogun/scripts/cmd_kpi_observer.sh >> /home/ubuntu/shogun/logs/kpi_observer.log 2>&1
#
# 収集 KPI (今日, JST):
#   1. /pub-us 起動回数      (logs/cmd_squash_pub_hook.log: "claude -p '/pub-us")
#   2. /pub-us 成功 / 失敗 / kill-switch (現状ログに明示パターンなし → 0 default)
#   3. karo auto-compact     (compact_observer.sh karo: AGENT_TODAY)
#   4. gunshi auto-compact   (compact_observer.sh gunshi: AGENT_TODAY)
#   5. safe_window_judge 発動 (logs/safe_window/{karo,gunshi}.log の START 件数合計)
#   6. karo_self_clear_check 発動 (logs/safe_clear/karo.log の START 件数, 報告用; dashboard 列なし)
#
# 出力先:
#   dashboard.md ## 📊 運用指標 セクションに今日の日付行を追記または更新

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="${SCRIPT_DIR}/dashboard.md"
DASHBOARD_YAML="${SCRIPT_DIR}/dashboard.yaml"
PUB_LOG="${SCRIPT_DIR}/logs/cmd_squash_pub_hook.log"
SAFE_WINDOW_DIR="${SCRIPT_DIR}/logs/safe_window"
SAFE_CLEAR_DIR="${SCRIPT_DIR}/logs/safe_clear"
COMPACT_OBSERVER="${SCRIPT_DIR}/scripts/compact_observer.sh"
COMPACT_HISTORY_LOG="${SCRIPT_DIR}/logs/compact_history.log"

DRY_RUN=0
TARGET_DATE=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --date=*) TARGET_DATE="${arg#--date=}" ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
    esac
done

_log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [cmd_kpi_observer] $*"
}

_log "=== START (dry_run=${DRY_RUN}) ==="

# cmd_616 Scope C: safe_window stale の根本対策として TODAY=今日(JST) を標準にする。
# 従来の「昨日」集計は safe_window 判定に1日遅延を生むため、日次KPIは当日値を直接扱う。
TODAY="${TARGET_DATE:-$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --date)}"

# ── KPI 1: /pub-us 起動回数 (today) ──────────────────────────────────────────
PUB_US_INVOKE=0
if [ -f "$PUB_LOG" ]; then
    PUB_US_INVOKE=$(grep -c "^\[${TODAY}.*claude -p '/pub-us" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
fi
PUB_US_INVOKE=${PUB_US_INVOKE:-0}

# ── KPI 2: /pub-us 成功 / 失敗 / kill-switch (today) ─────────────────────────
# 現状ログに明示パターンが無いため 0 default。将来パターン整備後に拡張する。
PUB_US_SUCCESS=0
PUB_US_FAIL=0
PUB_US_KILL=0
if [ -f "$PUB_LOG" ]; then
    PUB_US_SUCCESS=$(grep -c "^\[${TODAY}.*\(success\|成功\|completed\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
    PUB_US_FAIL=$(grep -c "^\[${TODAY}.*\(failed\|失敗\|error\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
    PUB_US_KILL=$(grep -c "^\[${TODAY}.*\(kill-switch\|kill_switch\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
fi
PUB_US_SUCCESS=${PUB_US_SUCCESS:-0}
PUB_US_FAIL=${PUB_US_FAIL:-0}
PUB_US_KILL=${PUB_US_KILL:-0}

# ── KPI 3-4: karo / gunshi auto-compact (today) ─────────────────────────────
KARO_COMPACT=0
GUNSHI_COMPACT=0
derive_agent_compact_count() {
    local role="$1"
    local observer_out="$2"
    local fallback="$3"
    local total prev_date
    total="$(echo "$observer_out" | grep -oE 'TOTAL=[0-9]+' | cut -d= -f2 | tr -d '\n' || true)"
    total="${total:-0}"
    prev_date="$(date -d "${TODAY} -1 day" '+%Y-%m-%d' 2>/dev/null || true)"
    if [ -z "$prev_date" ] || [ ! -f "$COMPACT_HISTORY_LOG" ]; then
        echo "${fallback:-0}"
        return
    fi
    python3 - "$COMPACT_HISTORY_LOG" "$role" "$prev_date" "$total" "$fallback" "$TODAY" "$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --date)" <<'PYEOF'
import json, sys
import datetime as dt
path, role, prev_date, total_s, fallback_s, target_date, current_jst = sys.argv[1:]
total = int(total_s or "0")
fallback = int(fallback_s or "0")
date_to_total = {}
with open(path) as f:
    for line in f:
        parts = line.strip().split("|", 3)
        if len(parts) != 4:
            continue
        _, line_role, kind, payload = parts
        if line_role != role or kind != "daily_rotate":
            continue
        try:
            data = json.loads(payload)
        except Exception:
            continue
        d = str(data.get("date", ""))
        try:
            date_to_total[d] = int(data.get("total_compactions", 0))
        except Exception:
            pass

def day_before(d):
    return (dt.datetime.strptime(d, "%Y-%m-%d") - dt.timedelta(days=1)).strftime("%Y-%m-%d")

if target_date in date_to_total and day_before(target_date) in date_to_total:
    print(max(date_to_total[target_date] - date_to_total[day_before(target_date)], 0))
elif target_date == current_jst and target_date not in date_to_total and day_before(target_date) in date_to_total:
    # today 未rotate (compact_history 未確定) でも TOTAL 差分で当日件数を復元する。
    print(max(total - date_to_total[day_before(target_date)], 0))
elif target_date == day_before(current_jst) and prev_date in date_to_total:
    print(max(total - date_to_total[prev_date], 0))
else:
    print(fallback)
PYEOF
}

if [ -x "$COMPACT_OBSERVER" ] || [ -f "$COMPACT_OBSERVER" ]; then
    KARO_OUT=$(bash "$COMPACT_OBSERVER" karo --date "$TODAY" 2>/dev/null | grep -m1 "^ROLE=" || true)
    GUNSHI_OUT=$(bash "$COMPACT_OBSERVER" gunshi --date "$TODAY" 2>/dev/null | grep -m1 "^ROLE=" || true)
    KARO_AGENT_TODAY=$(echo "$KARO_OUT" | grep -oE 'AGENT_TODAY=[0-9]+' | cut -d= -f2 | tr -d '\n' || true)
    GUNSHI_AGENT_TODAY=$(echo "$GUNSHI_OUT" | grep -oE 'AGENT_TODAY=[0-9]+' | cut -d= -f2 | tr -d '\n' || true)
    KARO_COMPACT=$(derive_agent_compact_count "karo" "$KARO_OUT" "${KARO_AGENT_TODAY:-0}")
    GUNSHI_COMPACT=$(derive_agent_compact_count "gunshi" "$GUNSHI_OUT" "${GUNSHI_AGENT_TODAY:-0}")
fi
KARO_COMPACT=${KARO_COMPACT:-0}
GUNSHI_COMPACT=${GUNSHI_COMPACT:-0}

# ── KPI 5: safe_window_judge 発動回数 (today, karo+gunshi) ──────────────────
SAFE_WINDOW_COUNT=0
for log in "${SAFE_WINDOW_DIR}/karo.log" "${SAFE_WINDOW_DIR}/gunshi.log"; do
    [ -f "$log" ] || continue
    count=$(grep -c "^\[${TODAY}.*=== START" "$log" 2>/dev/null | tr -d '\n' || true)
    SAFE_WINDOW_COUNT=$((SAFE_WINDOW_COUNT + ${count:-0}))
done

# ── KPI 6: karo_self_clear_check 発動回数 (today, 報告用) ───────────────────
SELF_CLEAR_COUNT=0
if [ -f "${SAFE_CLEAR_DIR}/karo.log" ]; then
    SELF_CLEAR_COUNT=$(grep -c "^\[${TODAY}.*safe_clear_check START" "${SAFE_CLEAR_DIR}/karo.log" 2>/dev/null | tr -d '\n' || true)
fi
SELF_CLEAR_COUNT=${SELF_CLEAR_COUNT:-0}

_log "KPI: pub_us_invoke=${PUB_US_INVOKE} success=${PUB_US_SUCCESS} fail=${PUB_US_FAIL} kill=${PUB_US_KILL}"
_log "KPI: karo_compact=${KARO_COMPACT} gunshi_compact=${GUNSHI_COMPACT} safe_window=${SAFE_WINDOW_COUNT} self_clear=${SELF_CLEAR_COUNT}"

if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN — would update dashboard.yaml metrics:"
    _log "date=${TODAY} pub_us=${PUB_US_INVOKE} success=${PUB_US_SUCCESS} fail=${PUB_US_FAIL} kill=${PUB_US_KILL} karo_compact=${KARO_COMPACT} gunshi_compact=${GUNSHI_COMPACT} safe_window=${SAFE_WINDOW_COUNT}"
    _log "=== END (dry_run) ==="
    exit 0
fi

# ── dashboard.yaml metrics 更新 + dashboard.md 再生成 ───────────────────────
python3 - "$DASHBOARD_YAML" "$TODAY" \
    "$PUB_US_INVOKE" "$PUB_US_SUCCESS" "$PUB_US_FAIL" "$PUB_US_KILL" \
    "$KARO_COMPACT" "$GUNSHI_COMPACT" "$SAFE_WINDOW_COUNT" <<'PYEOF'
import yaml, sys, subprocess
from pathlib import Path

dashboard_yaml, today = sys.argv[1], sys.argv[2]
pub_us, success, failure, kill_switch = sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
karo_compact, gunshi_compact, safe_window = sys.argv[7], sys.argv[8], sys.argv[9]

def to_int_or_str(v):
    return int(v) if v.lstrip('-').isdigit() else v

with open(dashboard_yaml) as f:
    d = yaml.safe_load(f) or {}

metrics = d.get('metrics', [])
row = next((m for m in metrics if str(m.get('date', '')) == today), None)
if row is None:
    row = {'date': today, 'pub_us': 0, 'success': 0, 'failure': 0, 'kill_switch': 0,
           'karo_compact': '-', 'gunshi_compact': '-', 'safe_window': '-'}
    metrics.append(row)

row.update({
    'pub_us': to_int_or_str(pub_us),
    'success': to_int_or_str(success),
    'failure': to_int_or_str(failure),
    'kill_switch': to_int_or_str(kill_switch),
    'karo_compact': to_int_or_str(karo_compact),
    'gunshi_compact': to_int_or_str(gunshi_compact),
    'safe_window': to_int_or_str(safe_window),
})
d['metrics'] = sorted(metrics, key=lambda m: str(m.get('date', '')))[-7:]

with open(dashboard_yaml, 'w') as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False)

subprocess.run(['python3', 'scripts/generate_dashboard_md.py'], check=True,
               cwd=str(Path(dashboard_yaml).parent))
PYEOF

_log "dashboard.yaml metrics updated + dashboard.md regenerated"
_log "=== END ==="
