#!/usr/bin/env bash
# self_clear_check.sh — 足軽の自己 /clear 判定スクリプト
#
# Usage: bash scripts/self_clear_check.sh <agent_id> [--dry-run]
#
# 動作:
#   1. queue/tasks/{agent_id}.yaml を読み status 確認
#   2. status=assigned/in_progress → skip (clear しない)
#   3. status=done/idle → tool count 閾値を確認
#   4. 閾値超なら self inbox_write (clear_command) で /clear を配信
#   5. 判定ログを /tmp/self_clear_{agent_id}.log に記録
#
# exit code: 0=正常終了, 1=エラー

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="${1:-}"
DRY_RUN=false

# 引数パース
shift || true
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "[self_clear_check] Unknown option: $arg" >&2 ;;
    esac
done

if [ -z "$AGENT_ID" ]; then
    echo "Usage: $0 <agent_id> [--dry-run]" >&2
    exit 1
fi

LOG_FILE="/tmp/self_clear_${AGENT_ID}.log"
TOOL_THRESHOLD=30

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [self_clear_check:${AGENT_ID}] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

_log "=== self_clear_check START (dry_run=${DRY_RUN}) ==="

# ── Step 1: task YAML から status を取得 ──────────────────────────────────
TASK_YAML="$SCRIPT_DIR/queue/tasks/${AGENT_ID}.yaml"
if [ ! -f "$TASK_YAML" ]; then
    _log "SKIP: task YAML not found: $TASK_YAML"
    exit 0
fi

# Python で YAML parse (bash-native では Unicode/複雑な YAML が壊れるリスクあり)
STATUS=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import yaml, sys
with open('$TASK_YAML') as f:
    data = yaml.safe_load(f) or {}
# Handle both wrapper structure {'task': {...}} and flat {'status': '...'}
if 'task' in data:
    data = data['task']
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
        _log "Task is ${STATUS} — proceeding to tool count check."
        ;;
    *)
        _log "SKIP: unknown status '${STATUS}'. Treating as active. /clear not issued."
        exit 0
        ;;
esac

# ── Step 3: tool call counter を取得 ─────────────────────────────────────
# 優先順: ~/.claude/tool_call_counter/{agent_id}.json → /tmp/claude-tool-count-{sessionId}
TOOL_COUNT=0

# 候補1: task YAML で指定されたパス(将来対応)
COUNTER_FILE_1="$HOME/.claude/tool_call_counter/${AGENT_ID}.json"
# 候補2: suggest-compact.js が実際に使うパス
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_ID_SAFE="${SESSION_ID//[^a-zA-Z0-9_-]/}"
SESSION_ID_SAFE="${SESSION_ID_SAFE:-default}"
COUNTER_FILE_2="/tmp/claude-tool-count-${SESSION_ID_SAFE}"

if [ -f "$COUNTER_FILE_1" ]; then
    # JSON形式: {"count": N}
    RAW=$("$SCRIPT_DIR/.venv/bin/python3" -c "
import json
with open('$COUNTER_FILE_1') as f:
    d = json.load(f)
print(d.get('count', 0))
" 2>/dev/null || echo "0")
    TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
    _log "counterFile (agent-specific): $COUNTER_FILE_1 → count=${TOOL_COUNT}"
elif [ -f "$COUNTER_FILE_2" ]; then
    # プレーンテキスト: N
    RAW=$(cat "$COUNTER_FILE_2" 2>/dev/null | tr -d '[:space:]')
    TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
    _log "counterFile (session): $COUNTER_FILE_2 → count=${TOOL_COUNT}"
else
    _log "counterFile not found. Treating count=0 (graceful degradation)."
    TOOL_COUNT=0
fi

_log "tool_count=${TOOL_COUNT}, threshold=${TOOL_THRESHOLD}"

# ── Step 4: 閾値判定 ────────────────────────────────────────────────────────
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

_log "=== self_clear_check END ==="
exit 0
