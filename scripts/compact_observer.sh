#!/usr/bin/env bash
# compact_observer.sh — role 別 auto-compact 発生回数を記録し、dashboard 連携データを生成する (cmd_592 Scope B)
#
# Usage: bash scripts/compact_observer.sh [karo|gunshi|ashigaru1|...] [--date YYYY-MM-DD]
# cron:  */30 * * * * bash /home/ubuntu/shogun/scripts/compact_observer.sh karo >> /home/ubuntu/shogun/logs/compact_observer.log 2>&1
#        */30 * * * * bash /home/ubuntu/shogun/scripts/compact_observer.sh gunshi >> /home/ubuntu/shogun/logs/compact_observer.log 2>&1
#
# 出力形式 (stdout):
#   ROLE=karo COUNT_TODAY=2 COUNT_7D=12 LAST=2026-04-26T11:50:54+09:00 TRIGGER=pre_compact
#
# 検知方式:
#   1. ~/.claude/sessions/compaction-log.txt — 全 agent 共通の compaction タイムスタンプ
#   2. queue/snapshots/{agent_id}_snapshot.yaml — trigger=pre_compact で agent 特定
#   3. /tmp/compact_stats_{role}.json — 累積カウンタ永続化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${SCRIPT_DIR}/.venv/bin/python3"
if [ ! -x "$PYTHON" ]; then PYTHON="python3"; fi

ROLE=""
TARGET_DATE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --date=*)
            TARGET_DATE="${1#--date=}"
            shift
            ;;
        --date)
            TARGET_DATE="${2:-}"
            shift 2
            ;;
        -h|--help)
            sed -n '2,14p' "$0"
            exit 0
            ;;
        *)
            if [ -z "$ROLE" ]; then
                ROLE="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$ROLE" ]; then
    echo "Usage: compact_observer.sh <agent_id>" >&2
    exit 2
fi

COMPACTION_LOG="${HOME}/.claude/sessions/compaction-log.txt"
SNAPSHOT_YAML="${SCRIPT_DIR}/queue/snapshots/${ROLE}_snapshot.yaml"
STATS_FILE="/tmp/compact_stats_${ROLE}.json"
HISTORY_LOG="${SCRIPT_DIR}/logs/compact_history.log"

_log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [compact_observer/${ROLE}] $*"
}

_log "=== START ==="

# compaction-log.txt が存在しない場合は graceful exit
if [ ! -f "$COMPACTION_LOG" ]; then
    _log "SKIP: compaction-log.txt not found at $COMPACTION_LOG"
    echo "ROLE=${ROLE} COUNT_TODAY=0 COUNT_7D=0 LAST=none TRIGGER=none"
    exit 0
fi

# ── Step 1: compaction-log.txt から今日 / 7日分のイベント数を集計 ─────────────────
TODAY="${TARGET_DATE:-$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --date 2>/dev/null || date '+%Y-%m-%d')}"
CUTOFF_7D=$(date -d "${TODAY} 7 days ago" '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d' 2>/dev/null || echo "2000-01-01")

COUNT_TODAY=$(grep -c "$TODAY" "$COMPACTION_LOG" 2>/dev/null || true)
COUNT_TODAY=${COUNT_TODAY:-0}
COUNT_7D=$(awk -v cutoff="$CUTOFF_7D" '
    /Context compaction triggered/ {
        match($0, /\[([0-9]{4}-[0-9]{2}-[0-9]{2})/, arr)
        if (arr[1] >= cutoff) count++
    }
    END { print count+0 }
' "$COMPACTION_LOG" 2>/dev/null || echo "0")

_log "global compaction today=${COUNT_TODAY} 7d=${COUNT_7D}"

# ── Step 2: snapshot YAML から agent 固有の compaction を検知 ──────────────────
LAST_COMPACT="none"
LAST_TRIGGER="none"
AGENT_COMPACT_TODAY=0

if [ -f "$SNAPSHOT_YAML" ]; then
    SNAP_INFO=$("$PYTHON" -c "
import yaml, sys
try:
    with open('$SNAPSHOT_YAML') as f:
        d = yaml.safe_load(f) or {}
    trigger = d.get('trigger', '')
    snap_at = str(d.get('snapshot_at', ''))
    print(trigger + '|' + snap_at)
except Exception as e:
    print('error|')
" 2>/dev/null || echo "error|")

    SNAP_TRIGGER="${SNAP_INFO%%|*}"
    SNAP_AT="${SNAP_INFO##*|}"

    _log "snapshot: trigger=${SNAP_TRIGGER} snapshot_at=${SNAP_AT}"

    if [ "$SNAP_TRIGGER" = "pre_compact" ]; then
        LAST_COMPACT="$SNAP_AT"
        LAST_TRIGGER="pre_compact"

        # snapshot_at と compaction-log のタイムスタンプを照合 (±5分以内)
        AGENT_COMPACT_TODAY=$("$PYTHON" -c "
import re, datetime
snap_at_str = '$SNAP_AT'
log_file = '$COMPACTION_LOG'
today = '$TODAY'

try:
    # snapshot_at をパース (例: 2026-04-26T11:50:54+09:00)
    snap_at_str = re.sub(r'\+09:00$', '', snap_at_str)
    snap_dt = datetime.datetime.fromisoformat(snap_at_str)
    snap_dt_utc = snap_dt - datetime.timedelta(hours=9)  # JST→UTC

    count = 0
    with open(log_file) as f:
        for line in f:
            m = re.search(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]', line)
            if not m: continue
            log_dt = datetime.datetime.strptime(m.group(1), '%Y-%m-%d %H:%M:%S')
            # compaction-log is UTC; convert to JST date for daily bucket
            if (log_dt + datetime.timedelta(hours=9)).strftime('%Y-%m-%d') != today:
                continue
            diff = abs((log_dt - snap_dt_utc).total_seconds())
            if diff <= 300:  # ±5分
                count += 1
    print(count)
except Exception as e:
    print(0)
" 2>/dev/null || echo "0")
        _log "agent-correlated compaction today=${AGENT_COMPACT_TODAY}"
    fi
else
    _log "no snapshot found for ${ROLE}"
fi

# ── Step 3: 累積カウンタを /tmp/compact_stats_{role}.json に記録 ──────────────
NOW_JST=$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --yaml 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S+09:00')

PREV_TOTAL=0
if [ -f "$STATS_FILE" ]; then
    PREV_TOTAL=$("$PYTHON" -c "
import json
try:
    with open('$STATS_FILE') as f:
        d = json.load(f)
    print(d.get('total_compactions', 0))
except:
    print(0)
" 2>/dev/null || echo "0")
fi

# pre_compact snapshot があれば累積を更新 (重複防止: 前回の LAST と比較)
PREV_LAST="none"
if [ -f "$STATS_FILE" ]; then
    PREV_LAST=$("$PYTHON" -c "
import json
try:
    with open('$STATS_FILE') as f:
        d = json.load(f)
    print(d.get('last_compact_at', 'none'))
except:
    print('none')
" 2>/dev/null || echo "none")
fi

NEW_TOTAL=$PREV_TOTAL
if [ "$LAST_TRIGGER" = "pre_compact" ] && [ "$LAST_COMPACT" != "$PREV_LAST" ]; then
    NEW_TOTAL=$((PREV_TOTAL + 1))
    _log "new compaction detected → total=${NEW_TOTAL}"

    # 日次 rotate: 古いカウンタを compact_history.log に追記
    if [ -f "$STATS_FILE" ]; then
        PREV_DATE=$("$PYTHON" -c "
import json
try:
    with open('$STATS_FILE') as f:
        d = json.load(f)
    print(d.get('date', ''))
except:
    print('')
" 2>/dev/null || echo "")
        if [ -n "$PREV_DATE" ] && [ "$PREV_DATE" != "$TODAY" ]; then
            echo "$("$PYTHON" -c "
import json
with open('$STATS_FILE') as f:
    d = json.load(f)
print('${TODAY}|${ROLE}|daily_rotate|' + json.dumps(d))
" 2>/dev/null)" >> "$HISTORY_LOG" 2>/dev/null || true
            _log "daily rotate: prev_date=${PREV_DATE} archived to compact_history.log"
        fi
    fi
fi

# stats ファイル書き込み
"$PYTHON" -c "
import json
data = {
    'role': '$ROLE',
    'date': '$TODAY',
    'updated_at': '$NOW_JST',
    'total_compactions': $NEW_TOTAL,
    'count_today_global': $COUNT_TODAY,
    'count_7d_global': $COUNT_7D,
    'agent_compact_today': $AGENT_COMPACT_TODAY,
    'last_compact_at': '$LAST_COMPACT',
    'last_trigger': '$LAST_TRIGGER',
}
with open('$STATS_FILE', 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print('stats written')
" 2>/dev/null

# ── Step 4: stdout 出力 ────────────────────────────────────────────────────────
echo "ROLE=${ROLE} COUNT_TODAY=${COUNT_TODAY} COUNT_7D=${COUNT_7D} AGENT_TODAY=${AGENT_COMPACT_TODAY} TOTAL=${NEW_TOTAL} LAST=${LAST_COMPACT} TRIGGER=${LAST_TRIGGER}"
_log "=== END ==="
