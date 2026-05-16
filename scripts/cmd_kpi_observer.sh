#!/usr/bin/env bash
# cmd_kpi_observer.sh — 完遂 cmd の KPI を観測し dashboard 運用指標に書込む (cmd_593 Scope C / AC5)
#
# Usage: bash scripts/cmd_kpi_observer.sh [--dry-run] [--date YYYY-MM-DD]
# cron:  0 9 * * * SHOGUN_KPI_CRON_RUN=1 bash /home/ubuntu/shogun/scripts/cmd_kpi_observer.sh >> /home/ubuntu/shogun/logs/kpi_observer.log 2>&1
#
# 収集 KPI (今日, JST):
#   1. publish 成功相当       (当日 JST の git commit 数)
#   2. cron 実行失敗          (logs/cron-status.log の当日 exit != 0 / FAILED 件数)
#   3. karo auto-compact     (compact_observer.sh karo: AGENT_TODAY)
#   4. gunshi auto-compact   (compact_observer.sh gunshi: AGENT_TODAY)
#   5. safe_window_judge 発動 (logs/safe_window/{karo,gunshi}.log の START 件数合計)
#   6. karo_self_clear_check 発動 (logs/safe_clear/karo.log の START 件数)
#   7. gunshi_self_clear_check 発動 (logs/safe_clear/gunshi.log の START 件数)
#   8. karo self_compact 発動 (detect_compact.sh karo + logs/compact_log/karo.log の当日件数)
#   9. gunshi self_compact 発動 (detect_compact.sh gunshi + logs/compact_log/gunshi.log の当日件数)
#
# 出力先:
#   dashboard.md ## 📊 運用指標 セクションに今日の日付行を追記または更新

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="${SCRIPT_DIR}/dashboard.md"
DASHBOARD_YAML="${SCRIPT_DIR}/dashboard.yaml"
SAFE_WINDOW_DIR="${SCRIPT_DIR}/logs/safe_window"
SAFE_CLEAR_DIR="${SCRIPT_DIR}/logs/safe_clear"
COMPACT_OBSERVER="${SCRIPT_DIR}/scripts/compact_observer.sh"
DETECT_COMPACT="${SCRIPT_DIR}/scripts/detect_compact.sh"
COMPACT_HISTORY_LOG="${SCRIPT_DIR}/logs/compact_history.log"
SELF_COMPACT_DIR="${SCRIPT_DIR}/logs/compact_log"
CRON_STATUS_LOG="${SCRIPT_DIR}/logs/cron-status.log"

record_cron_status() {
    local exit_code="$1"
    local status="OK"
    local ts
    [ "${SHOGUN_KPI_CRON_RUN:-0}" = "1" ] || return 0
    [ "$exit_code" -eq 0 ] || status="FAILED"
    mkdir -p "$(dirname "$CRON_STATUS_LOG")"
    ts="$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" 2>/dev/null || date '+%Y-%m-%d %H:%M %Z')"
    printf '[%s] cmd_kpi_observer exit %s %s\n' "$ts" "$exit_code" "$status" >> "$CRON_STATUS_LOG"
}

trap 'rc=$?; record_cron_status "$rc"; exit "$rc"' EXIT

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

# ── KPI 1-2: publish 成功 / cron 実行失敗 (today, JST) ─────────────────────
PUB_US_SUCCESS=0
CRON_FAILURE_COUNT=0
NEXT_DAY="$(python3 - "$TODAY" <<'PYEOF'
import datetime as dt
import sys

print((dt.datetime.strptime(sys.argv[1], "%Y-%m-%d") + dt.timedelta(days=1)).strftime("%Y-%m-%d"))
PYEOF
)"
if git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    PUB_US_SUCCESS=$(
        git -C "$SCRIPT_DIR" log \
            --since="${TODAY} 00:00:00 +0900" \
            --until="${NEXT_DAY} 00:00:00 +0900" \
            --format=%H 2>/dev/null \
        | wc -l | tr -d '[:space:]'
    )
fi
PUB_US_SUCCESS=${PUB_US_SUCCESS:-0}

if [ -f "$CRON_STATUS_LOG" ]; then
    CRON_FAILURE_COUNT=$(
        grep -E "^\[${TODAY} .*cmd_kpi_observer" "$CRON_STATUS_LOG" 2>/dev/null \
        | grep -Ec "(FAILED|exit [1-9][0-9]*)" \
        | tr -d '[:space:]' || true
    )
fi
CRON_FAILURE_COUNT=${CRON_FAILURE_COUNT:-0}

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

# ── KPI 6-7: self_clear_check 発動回数 (today, karo/gunshi) ────────────────
KARO_SELF_CLEAR=0
GUNSHI_SELF_CLEAR=0
if [ -f "${SAFE_CLEAR_DIR}/karo.log" ]; then
    KARO_SELF_CLEAR=$(grep -c "^\[${TODAY}.*karo_self_clear_check START" "${SAFE_CLEAR_DIR}/karo.log" 2>/dev/null | tr -d '\n' || true)
fi
if [ -f "${SAFE_CLEAR_DIR}/gunshi.log" ]; then
    GUNSHI_SELF_CLEAR=$(grep -c "^\[${TODAY}.*gunshi_self_clear_check START" "${SAFE_CLEAR_DIR}/gunshi.log" 2>/dev/null | tr -d '\n' || true)
fi
KARO_SELF_CLEAR=${KARO_SELF_CLEAR:-0}
GUNSHI_SELF_CLEAR=${GUNSHI_SELF_CLEAR:-0}

# ── KPI 8-9: self_compact 検出回数 (today, karo/gunshi) ────────────────────
KARO_SELF_COMPACT=0
GUNSHI_SELF_COMPACT=0
if [ -f "$DETECT_COMPACT" ]; then
    bash "$DETECT_COMPACT" karo >/dev/null 2>&1 || true
    bash "$DETECT_COMPACT" gunshi >/dev/null 2>&1 || true
fi
if [ -f "${SELF_COMPACT_DIR}/karo.log" ]; then
    KARO_SELF_COMPACT=$(grep -c "^${TODAY}T.* karo self_compact detected" "${SELF_COMPACT_DIR}/karo.log" 2>/dev/null | tr -d '\n' || true)
fi
if [ -f "${SELF_COMPACT_DIR}/gunshi.log" ]; then
    GUNSHI_SELF_COMPACT=$(grep -c "^${TODAY}T.* gunshi self_compact detected" "${SELF_COMPACT_DIR}/gunshi.log" 2>/dev/null | tr -d '\n' || true)
fi
KARO_SELF_COMPACT=${KARO_SELF_COMPACT:-0}
GUNSHI_SELF_COMPACT=${GUNSHI_SELF_COMPACT:-0}

_log "KPI: git_commit_success=${PUB_US_SUCCESS} cron_fail=${CRON_FAILURE_COUNT}"
_log "KPI: karo_compact=${KARO_COMPACT} gunshi_compact=${GUNSHI_COMPACT} safe_window=${SAFE_WINDOW_COUNT}"
_log "KPI: karo_self_clear=${KARO_SELF_CLEAR} gunshi_self_clear=${GUNSHI_SELF_CLEAR} karo_self_compact=${KARO_SELF_COMPACT} gunshi_self_compact=${GUNSHI_SELF_COMPACT}"

if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN — would update dashboard.yaml metrics:"
    _log "date=${TODAY} success=${PUB_US_SUCCESS} cron_fail=${CRON_FAILURE_COUNT} karo_compact=${KARO_COMPACT} gunshi_compact=${GUNSHI_COMPACT} safe_window=${SAFE_WINDOW_COUNT} karo_self_clear=${KARO_SELF_CLEAR} gunshi_self_clear=${GUNSHI_SELF_CLEAR} karo_self_compact=${KARO_SELF_COMPACT} gunshi_self_compact=${GUNSHI_SELF_COMPACT}"
    _log "=== END (dry_run) ==="
    exit 0
fi

# ── dashboard.yaml metrics 更新 + dashboard.md 再生成 ───────────────────────
python3 - "$DASHBOARD_YAML" "$TODAY" \
    "$PUB_US_SUCCESS" "$CRON_FAILURE_COUNT" \
    "$KARO_COMPACT" "$GUNSHI_COMPACT" "$SAFE_WINDOW_COUNT" \
    "$KARO_SELF_CLEAR" "$GUNSHI_SELF_CLEAR" "$KARO_SELF_COMPACT" "$GUNSHI_SELF_COMPACT" <<'PYEOF'
import os, tempfile, yaml, sys, subprocess
from pathlib import Path

dashboard_yaml, today = sys.argv[1], sys.argv[2]
success, failure = sys.argv[3], sys.argv[4]
karo_compact, gunshi_compact, safe_window = sys.argv[5], sys.argv[6], sys.argv[7]
karo_self_clear, gunshi_self_clear = sys.argv[8], sys.argv[9]
karo_self_compact, gunshi_self_compact = sys.argv[10], sys.argv[11]

def to_int_or_str(v):
    return int(v) if v.lstrip('-').isdigit() else v

with open(dashboard_yaml) as f:
    d = yaml.safe_load(f) or {}

metrics = d.get('metrics', [])
row = next((m for m in metrics if str(m.get('date', '')) == today), None)
if row is None:
    row = {'date': today, 'success': 0, 'failure': 0,
           'karo_compact': '-', 'gunshi_compact': '-', 'safe_window': '-'}
    metrics.append(row)

row.pop('pub_us', None)
row.pop('kill_switch', None)
row.update({
    'success': to_int_or_str(success),
    'failure': to_int_or_str(failure),
    'karo_compact': to_int_or_str(karo_compact),
    'gunshi_compact': to_int_or_str(gunshi_compact),
    'safe_window': to_int_or_str(safe_window),
    'karo_self_clear': to_int_or_str(karo_self_clear),
    'gunshi_self_clear': to_int_or_str(gunshi_self_clear),
    'karo_self_compact': to_int_or_str(karo_self_compact),
    'gunshi_self_compact': to_int_or_str(gunshi_self_compact),
})
d['metrics'] = sorted(metrics, key=lambda m: str(m.get('date', '')))[-7:]

achievements = d.get('achievements') or {}
today_items = achievements.get('today') or []
frog = d.get('frog') or {}
frog['completed_today'] = len(today_items)
d['frog'] = frog

# Atomic write: tempfile + os.replace to prevent TOCTOU race (AC-8)
dir_path = os.path.dirname(os.path.abspath(dashboard_yaml))
fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix='.tmp')
try:
    with os.fdopen(fd, 'w') as f:
        yaml.dump(d, f, allow_unicode=True, default_flow_style=False)
    os.replace(tmp_path, dashboard_yaml)
except Exception:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    raise

subprocess.run(['python3', 'scripts/generate_dashboard_md.py'], check=True,
               cwd=str(Path(dashboard_yaml).parent))
PYEOF

_log "dashboard.yaml metrics updated + dashboard.md regenerated"
_log "=== END ==="
