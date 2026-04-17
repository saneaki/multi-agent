#!/usr/bin/env bash
# gunshi_self_clear_check.sh — 軍師の自己 /clear 判定スクリプト
#
# Usage: bash scripts/gunshi_self_clear_check.sh [--dry-run]
#
# 動作:
#   1. queue/tasks/gunshi.yaml を読み status 確認
#   2. status=assigned/in_progress → skip (clear しない)
#   3. status=done/idle → 未読 inbox + context_policy を確認
#   4. preserve_across_stages cmd 進行中なら SKIP
#   5. tool count 閾値を確認 → 超過なら self inbox_write (clear_command)
#   6. 判定ログを /tmp/self_clear_gunshi.log に記録
#
# exit code: 0=正常終了, 1=エラー

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="gunshi"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "[gunshi_self_clear_check] Unknown option: $arg" >&2 ;;
    esac
done

LOG_FILE="/tmp/self_clear_gunshi.log"
TOOL_THRESHOLD=30
TASK_YAML="$SCRIPT_DIR/queue/tasks/gunshi.yaml"
INBOX_YAML="$SCRIPT_DIR/queue/inbox/gunshi.yaml"
SHOGUN_TO_KARO="$SCRIPT_DIR/queue/shogun_to_karo.yaml"

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [gunshi_self_clear_check] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

_log "=== gunshi_self_clear_check START (dry_run=${DRY_RUN}) ==="

# ── Step 1: task YAML から status を取得 ──────────────────────────────────
if [ ! -f "$TASK_YAML" ]; then
    _log "SKIP: task YAML not found: $TASK_YAML"
    exit 0
fi

STATUS=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml, sys
with open('$TASK_YAML') as f:
    data = yaml.safe_load(f)
print(data.get('status', 'unknown'))
" 2>/dev/null || echo "unknown")

_log "Task status: $STATUS"

# ── Step 2: status が assigned/in_progress なら skip ──────────────────────
case "$STATUS" in
    assigned|in_progress)
        _log "SKIP: active task (status=${STATUS}). /clear not issued."
        exit 0
        ;;
    done|idle|completed)
        _log "Task is ${STATUS} — proceeding to inbox + policy check."
        ;;
    *)
        _log "SKIP: unknown status '${STATUS}'. Treating as active. /clear not issued."
        exit 0
        ;;
esac

# ── Step 3: 未読 inbox を確認 ─────────────────────────────────────────────
UNREAD_COUNT=0
if [ -f "$INBOX_YAML" ]; then
    UNREAD_COUNT=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml
with open('$INBOX_YAML') as f:
    data = yaml.safe_load(f) or {}
msgs = data.get('messages', [])
print(sum(1 for m in msgs if not m.get('read', True)))
" 2>/dev/null || echo "0")
fi

_log "unread_inbox_count=${UNREAD_COUNT}"

if [ "$UNREAD_COUNT" -gt 0 ] 2>/dev/null; then
    _log "SKIP: ${UNREAD_COUNT} unread inbox message(s). /clear not issued."
    exit 0
fi

# ── Step 4: context_policy = preserve_across_stages チェック ─────────────
# 直近の task_assigned inbox メッセージから cmd_id を逆引きし、
# shogun_to_karo.yaml の context_policy を確認する
CMD_ID=""
if [ -f "$INBOX_YAML" ]; then
    CMD_ID=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml, re
with open('$INBOX_YAML') as f:
    data = yaml.safe_load(f) or {}
msgs = data.get('messages', [])
# Find the most recent task_assigned message
for m in reversed(msgs):
    if m.get('type') == 'task_assigned':
        content = m.get('content', '')
        # Extract cmd_NNN from content
        match = re.search(r'\bcmd_\d+\b', content)
        if match:
            print(match.group(0))
            break
" 2>/dev/null || echo "")
fi

CONTEXT_POLICY=""
if [ -n "$CMD_ID" ] && [ -f "$SHOGUN_TO_KARO" ]; then
    CONTEXT_POLICY=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml, sys
cmd_id = '$CMD_ID'
with open('$SHOGUN_TO_KARO') as f:
    content = f.read()
# Parse as YAML — shogun_to_karo may be large, use safe_load
try:
    data = yaml.safe_load(content) or {}
except Exception:
    sys.exit(0)
# Navigate to cmd entry
cmds = data.get('commands', data.get('cmds', {}))
if isinstance(cmds, dict):
    entry = cmds.get(cmd_id, {})
elif isinstance(cmds, list):
    entry = next((c for c in cmds if c.get('cmd_id') == cmd_id or c.get('id') == cmd_id), {})
else:
    entry = {}
print(entry.get('context_policy', ''))
" 2>/dev/null || echo "")
    _log "cmd_id=${CMD_ID}, context_policy=${CONTEXT_POLICY}"
fi

if [ "$CONTEXT_POLICY" = "preserve_across_stages" ]; then
    _log "SKIP: context_policy=preserve_across_stages for ${CMD_ID}. /clear prohibited during multi-stage cmd."
    exit 0
fi

# ── Step 5: tool call counter を取得 ─────────────────────────────────────
TOOL_COUNT=0

COUNTER_FILE_1="$HOME/.claude/tool_call_counter/${AGENT_ID}.json"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_ID_SAFE="${SESSION_ID//[^a-zA-Z0-9_-]/}"
SESSION_ID_SAFE="${SESSION_ID_SAFE:-default}"
COUNTER_FILE_2="/tmp/claude-tool-count-${SESSION_ID_SAFE}"

if [ -f "$COUNTER_FILE_1" ]; then
    RAW=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import json
with open('$COUNTER_FILE_1') as f:
    d = json.load(f)
print(d.get('count', 0))
" 2>/dev/null || echo "0")
    TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
    _log "counterFile (agent-specific): $COUNTER_FILE_1 → count=${TOOL_COUNT}"
elif [ -f "$COUNTER_FILE_2" ]; then
    RAW=$(cat "$COUNTER_FILE_2" 2>/dev/null | tr -d '[:space:]')
    TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
    _log "counterFile (session): $COUNTER_FILE_2 → count=${TOOL_COUNT}"
else
    _log "counterFile not found. Treating count=0 (graceful degradation)."
    TOOL_COUNT=0
fi

_log "tool_count=${TOOL_COUNT}, threshold=${TOOL_THRESHOLD}"

# ── Step 6: 閾値判定 ────────────────────────────────────────────────────────
if [ "$TOOL_COUNT" -gt "$TOOL_THRESHOLD" ] 2>/dev/null; then
    _log "CLEAR CANDIDATE: tool_count(${TOOL_COUNT}) > threshold(${TOOL_THRESHOLD})"

    if [ "$DRY_RUN" = true ]; then
        _log "DRY-RUN: would send clear_command to ${AGENT_ID} (not sent)"
    else
        _log "Sending clear_command to ${AGENT_ID} via inbox_write..."
        bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
            "$AGENT_ID" \
            "auto self-clear: tool count ${TOOL_COUNT} exceeded threshold ${TOOL_THRESHOLD}" \
            "clear_command" \
            "$AGENT_ID"
        _log "clear_command sent."
    fi
else
    _log "SKIP: tool_count(${TOOL_COUNT}) <= threshold(${TOOL_THRESHOLD}). /clear not issued."
fi

_log "=== gunshi_self_clear_check END ==="
exit 0
