#!/usr/bin/env bash
# gunshi_self_clear_check.sh — 軍師の自己 /clear 判定スクリプト (cmd_633 Scope C)
#
# Usage: bash scripts/gunshi_self_clear_check.sh [--dry-run] [--tool-count N]
#
# 判定条件(全 AND が必要。1つでも NG → SKIP with reason log):
#   cond_1: queue/inbox/gunshi.yaml に read:false エントリがゼロ
#   cond_2: queue/tasks/gunshi.yaml の status が idle/done/completed
#   cond_3: shogun_to_karo.yaml に preserve_across_stages な in_progress cmd がゼロ
#   cond_4: tool_count > 30 (軍師の閾値)
#
# 全 PASS → safe_window_judge.sh 連携 → context_advisory または clear_command 送信
# NG → SKIP + reason log
#
# exit code: 0=正常終了 (SKIP 含む), 1=引数エラー

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="gunshi"
DRY_RUN=false
TOOL_COUNT_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --tool-count)
            TOOL_COUNT_ARG="${2:-}"
            if [ -z "$TOOL_COUNT_ARG" ]; then
                echo "[gunshi_self_clear_check] --tool-count requires a value" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "[gunshi_self_clear_check] Unknown option: $1" >&2
            shift
            ;;
    esac
done

LOG_FILE="$SCRIPT_DIR/logs/safe_clear/gunshi.log"
TOOL_THRESHOLD=30
PYTHON="$SCRIPT_DIR/.venv/bin/python3"
INBOX_YAML="$SCRIPT_DIR/queue/inbox/gunshi.yaml"
TASK_YAML="$SCRIPT_DIR/queue/tasks/gunshi.yaml"
SHOGUN_TO_KARO="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
SNAPSHOT_YAML="$SCRIPT_DIR/queue/snapshots/gunshi_snapshot.yaml"

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [gunshi_self_clear_check] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

_skip() {
    _log "SKIP: $*"
    _log "=== gunshi_self_clear_check END (SKIP) ==="
    exit 0
}

_log "=== gunshi_self_clear_check START (dry_run=${DRY_RUN}) ==="

# ── cond_1: gunshi inbox の未読エントリ ──────────────────────────────────────
UNREAD_COUNT=0
if [ -f "$INBOX_YAML" ]; then
    UNREAD_COUNT=$("$PYTHON" -c "
import yaml
try:
    with open('$INBOX_YAML') as f:
        d = yaml.safe_load(f) or {}
    msgs = d.get('messages', [])
    print(sum(1 for m in msgs if not m.get('read', True)))
except Exception:
    print(0)
" 2>/dev/null || echo "0")
else
    _log "cond_1: inbox YAML not found — treating as 0 unread (fail-safe)."
fi

_log "cond_1: unread_inbox_count=${UNREAD_COUNT}"
if [ "${UNREAD_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    _skip "cond_1 NG: ${UNREAD_COUNT} unread inbox message(s) in gunshi.yaml"
fi

# ── cond_2: gunshi task status チェック ─────────────────────────────────────
if [ ! -f "$TASK_YAML" ]; then
    _log "cond_2: task YAML not found — SKIP (fail-safe)."
    _skip "cond_2 NG: task YAML not found"
fi

TASK_STATUS=$("$PYTHON" -c "
import yaml
try:
    with open('$TASK_YAML') as f:
        d = yaml.safe_load(f) or {}
    print(d.get('status', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")

_log "cond_2: task_status=${TASK_STATUS}"
case "$TASK_STATUS" in
    idle|done|completed) ;;
    *)
        _skip "cond_2 NG: task status='${TASK_STATUS}' (not idle/done/completed)"
        ;;
esac

# ── cond_3: preserve_across_stages チェック (defense-in-depth) ──────────────
IN_PROGRESS_COUNT=0
PRESERVE_CMDS=""
IN_PROGRESS_LIST=""
if [ ! -f "$SHOGUN_TO_KARO" ]; then
    _log "cond_3: shogun_to_karo.yaml not found — treating as no in_progress cmds."
else
    SCAN_OUTPUT=$("$PYTHON" <<PYEOF
import re

with open("$SHOGUN_TO_KARO") as f:
    content = f.read()

blocks = re.split(r'(?m)^(?=- (?:cmd_id|id): cmd_\d+)', content)

in_progress = []
preserve = []
for block in blocks:
    m = re.match(r'- (?:cmd_id|id): (cmd_\d+)', block)
    if not m:
        continue
    cmd_id = m.group(1)
    status_m = re.search(r'(?m)^  status:\s*["\']?([A-Za-z_]+)["\']?', block)
    if not status_m:
        continue
    if status_m.group(1) != 'in_progress':
        continue
    in_progress.append(cmd_id)
    policy_m = re.search(r'(?m)^  context_policy:\s*["\']?([A-Za-z_]+)["\']?', block)
    policy = policy_m.group(1) if policy_m else 'clear_between'
    if policy == 'preserve_across_stages':
        preserve.append(cmd_id)

print(f"IN_PROGRESS_COUNT={len(in_progress)}")
print(f"IN_PROGRESS_LIST={','.join(in_progress)}")
print(f"PRESERVE_LIST={','.join(preserve)}")
PYEOF
)
    IN_PROGRESS_COUNT=$(echo "$SCAN_OUTPUT" | grep '^IN_PROGRESS_COUNT=' | cut -d= -f2)
    IN_PROGRESS_LIST=$(echo "$SCAN_OUTPUT" | grep '^IN_PROGRESS_LIST=' | cut -d= -f2-)
    PRESERVE_CMDS=$(echo "$SCAN_OUTPUT" | grep '^PRESERVE_LIST=' | cut -d= -f2-)
    IN_PROGRESS_COUNT="${IN_PROGRESS_COUNT:-0}"
fi

_log "cond_3: in_progress=${IN_PROGRESS_COUNT} list=[${IN_PROGRESS_LIST:-}]"
if [ -n "${PRESERVE_CMDS:-}" ]; then
    _skip "cond_3 NG: preserve_across_stages cmd(s) detected [${PRESERVE_CMDS}]"
fi
_log "cond_3: no preserve_across_stages cmd in progress."

# ── cond_4: tool_count 取得と閾値判定 ─────────────────────────────────────────
TOOL_COUNT=0
if [ -n "$TOOL_COUNT_ARG" ]; then
    TOOL_COUNT="$TOOL_COUNT_ARG"
    _log "cond_4: tool_count from --tool-count arg: ${TOOL_COUNT}"
elif [ -f "$SNAPSHOT_YAML" ]; then
    SNAP_COUNT=$("$PYTHON" -c "
import yaml
try:
    with open('$SNAPSHOT_YAML') as f:
        d = yaml.safe_load(f) or {}
    ctx = d.get('agent_context', {}) or {}
    v = ctx.get('tool_count', d.get('tool_count', 0))
    print(int(v) if v is not None else 0)
except Exception:
    print(0)
" 2>/dev/null || echo "0")
    if [ "${SNAP_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        TOOL_COUNT="$SNAP_COUNT"
        _log "cond_4: tool_count from gunshi_snapshot.yaml: ${TOOL_COUNT}"
    fi
fi

if [ "${TOOL_COUNT:-0}" -eq 0 ] 2>/dev/null; then
    COUNTER_FILE_1="$HOME/.claude/tool_call_counter/${AGENT_ID}.json"
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    SESSION_ID_SAFE="${SESSION_ID//[^a-zA-Z0-9_-]/}"
    SESSION_ID_SAFE="${SESSION_ID_SAFE:-default}"
    COUNTER_FILE_2="/tmp/claude-tool-count-${SESSION_ID_SAFE}"

    if [ -f "$COUNTER_FILE_1" ]; then
        RAW=$("$PYTHON" -c "
import json
try:
    with open('$COUNTER_FILE_1') as f:
        d = json.load(f)
    print(d.get('count', 0))
except Exception:
    print(0)
" 2>/dev/null || echo "0")
        TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
        _log "cond_4: tool_count from ${COUNTER_FILE_1}: ${TOOL_COUNT}"
    elif [ -f "$COUNTER_FILE_2" ]; then
        RAW=$(cat "$COUNTER_FILE_2" 2>/dev/null | tr -d '[:space:]')
        TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
        _log "cond_4: tool_count from ${COUNTER_FILE_2}: ${TOOL_COUNT}"
    else
        _log "cond_4: no counter file found. Treating as 0 (graceful degradation)."
    fi
fi

_log "cond_4: tool_count=${TOOL_COUNT}, threshold=${TOOL_THRESHOLD}"
if [ "${TOOL_COUNT:-0}" -le "$TOOL_THRESHOLD" ] 2>/dev/null; then
    _skip "cond_4 NG: tool_count(${TOOL_COUNT}) <= threshold(${TOOL_THRESHOLD})"
fi

# ── 全 PASS → safe_window_judge.sh 連携 → context_advisory or clear_command ──
_log "ALL CONDITIONS PASSED."

SAFE_WINDOW_JUDGE="$SCRIPT_DIR/scripts/safe_window_judge.sh"
if [ -f "$SAFE_WINDOW_JUDGE" ]; then
    JUDGE_OUTPUT=$(bash "$SAFE_WINDOW_JUDGE" --agent-id gunshi 2>/dev/null || echo "SAFE_WINDOW_RESULT=false")
    SAFE_WINDOW_RESULT=$(echo "$JUDGE_OUTPUT" | grep -oE 'SAFE_WINDOW_RESULT=(true|false)' | head -1 | cut -d= -f2 || echo "false")
    case "$SAFE_WINDOW_RESULT" in
        true) JUDGE_VERDICT="APPROVE" ;;
        *) JUDGE_VERDICT="SKIP" ;;
    esac
    _log "safe_window_judge verdict: ${JUDGE_OUTPUT:-SKIP}"

    if [ "$JUDGE_VERDICT" = "APPROVE" ]; then
        JUDGE_PCT=$(echo "$JUDGE_OUTPUT" | grep -oE 'context_pct=[0-9]+' | cut -d= -f2 || echo "")
        JUDGE_RECOMMEND=$(echo "$JUDGE_OUTPUT" | grep -oE 'RECOMMENDATION=(/clear|/compact)' | head -1 | cut -d= -f2 | sed 's|^/||' || echo "clear")

        DEDUP_MARKER="/tmp/gunshi_context_advisory_last_sent"
        SEND_ADVISORY=true
        if [ -f "$DEDUP_MARKER" ]; then
            LAST_SENT=$(cat "$DEDUP_MARKER" 2>/dev/null | tr -d '[:space:]' || echo "0")
            NOW_EPOCH=$(date +%s)
            if echo "$LAST_SENT" | grep -qE '^[0-9]+$'; then
                ELAPSED=$((NOW_EPOCH - LAST_SENT))
                if [ "$ELAPSED" -lt 1800 ]; then
                    _log "context_advisory dedup: last sent ${ELAPSED}s ago (< 1800s) — skip"
                    SEND_ADVISORY=false
                fi
            fi
        fi

        if [ "$SEND_ADVISORY" = true ]; then
            PCT_PART=""
            [ -n "$JUDGE_PCT" ] && PCT_PART="context_pct=${JUDGE_PCT}%。"
            RECOMMEND="${JUDGE_RECOMMEND:-clear}"
            ADV_MSG="safe window 到達。${PCT_PART}推奨: /${RECOMMEND}。全条件PASS(cond_1-4)。"
            if [ "$DRY_RUN" = true ]; then
                _log "DRY-RUN: would send context_advisory: ${ADV_MSG}"
            else
                bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
                    "$AGENT_ID" "$ADV_MSG" "context_advisory" "gunshi_self_judge"
                date +%s > "$DEDUP_MARKER"
                _log "context_advisory sent (recommend=/${RECOMMEND})"
            fi
        fi
    else
        _log "safe_window_judge did not APPROVE — no context_advisory sent"
    fi
else
    # safe_window_judge.sh 未実装 → 旧来の clear_command フォールバック
    _log "safe_window_judge.sh not found — fallback: clear_command (tool_count=${TOOL_COUNT})"
    if [ "$DRY_RUN" = true ]; then
        _log "DRY-RUN: would send clear_command to ${AGENT_ID} (tool_count=${TOOL_COUNT}) — not sent."
    else
        bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
            "$AGENT_ID" \
            "auto self-clear: tool count ${TOOL_COUNT} exceeded threshold ${TOOL_THRESHOLD}" \
            "clear_command" \
            "$AGENT_ID"
        _log "clear_command sent."
    fi
fi

_log "=== gunshi_self_clear_check END ==="
exit 0
