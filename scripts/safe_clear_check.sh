#!/usr/bin/env bash
# safe_clear_check.sh — 全 Role 共通 /clear 安全判定スクリプト (cmd_535 Phase 2)
#
# Usage: bash scripts/safe_clear_check.sh [OPTIONS]
#   --agent-id   <id>  : shogun/karo/gunshi/ashigaru{N} (または AGENT_ID 環境変数)
#   --tool-count <n>   : 現在の tool 使用数 (省略時=0)
#   --dry-run          : clear_command 送信せず判定結果のみ表示
#
# 共通4条件(全 Role AND):
#   C1: inbox=0    — queue/inbox/{agent_id}.yaml の read:false エントリ数=0
#   C2: in_progress=0 — queue/tasks/{agent_id}.yaml の status が idle or done
#   C3: dispatch_debt=0 (karo のみ) — status:blocked かつ blocked_by 全 done の未解放タスクなし
#   C4: context_policy=clear_between — preserve_across_stages cmd が進行中でない
#
# Role 別追加条件:
#   shogun:   常に SKIP (F001: auto-clear 禁止)
#   karo:     tool_count > 50
#   gunshi:   tool_count > 30
#   ashigaru: tool_count > 30
#
# 出力: APPROVE (exit 0) / SKIP(reason) (exit 1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="${AGENT_ID:-}"
DRY_RUN=false
TOOL_COUNT_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --agent-id)
            AGENT_ID="${2:-}"
            if [ -z "$AGENT_ID" ]; then
                echo "[safe_clear_check] --agent-id requires a value" >&2
                exit 2
            fi
            shift 2
            ;;
        --tool-count)
            TOOL_COUNT_ARG="${2:-}"
            if [ -z "$TOOL_COUNT_ARG" ]; then
                echo "[safe_clear_check] --tool-count requires a value" >&2
                exit 2
            fi
            shift 2
            ;;
        --dry-run) DRY_RUN=true; shift ;;
        *)
            echo "[safe_clear_check] Unknown option: $1" >&2
            shift
            ;;
    esac
done

if [ -z "$AGENT_ID" ]; then
    echo "[safe_clear_check] --agent-id is required (or set AGENT_ID env)" >&2
    exit 2
fi

# Role 判定
ROLE=""
case "$AGENT_ID" in
    shogun)    ROLE="shogun" ;;
    karo)      ROLE="karo" ;;
    gunshi)    ROLE="gunshi" ;;
    ashigaru*) ROLE="ashigaru" ;;
    *)
        echo "[safe_clear_check] Unknown agent_id: $AGENT_ID" >&2
        exit 2
        ;;
esac

# Role 別 tool_count 閾値
case "$ROLE" in
    karo)             TOOL_THRESHOLD=50 ;;
    gunshi|ashigaru)  TOOL_THRESHOLD=30 ;;
    shogun)           TOOL_THRESHOLD=0 ;;
esac

LOG_FILE="/tmp/self_clear_${AGENT_ID}.log"
PYTHON="$SCRIPT_DIR/.venv/bin/python3"
INBOX_YAML="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
TASK_YAML="$SCRIPT_DIR/queue/tasks/${AGENT_ID}.yaml"
TASKS_DIR="$SCRIPT_DIR/queue/tasks"
SHOGUN_TO_KARO="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
SNAPSHOT_YAML="$SCRIPT_DIR/queue/snapshots/${AGENT_ID}_snapshot.yaml"

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [safe_clear_check:${AGENT_ID}] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

_skip() {
    _log "SKIP: $*"
    _log "=== safe_clear_check END (SKIP) ==="
    exit 1
}

_approve() {
    _log "APPROVE: /clear is safe."
    _log "=== safe_clear_check END (APPROVE) ==="
    exit 0
}

_log "=== safe_clear_check START (agent=${AGENT_ID} role=${ROLE} dry_run=${DRY_RUN}) ==="

# ── shogun: F001 により常に SKIP ─────────────────────────────────────────────
if [ "$ROLE" = "shogun" ]; then
    _skip "shogun_auto_clear_forbidden (F001: auto-clear disabled for shogun)"
fi

# ── C1: inbox read:false チェック ────────────────────────────────────────────
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
    _log "C1: inbox YAML not found — treating as 0 unread (fail-safe)."
fi

_log "C1: unread_inbox_count=${UNREAD_COUNT}"
if [ "${UNREAD_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    _skip "C1 NG: ${UNREAD_COUNT} unread inbox message(s)"
fi

# ── C2: task status チェック ─────────────────────────────────────────────────
if [ ! -f "$TASK_YAML" ]; then
    _log "C2: task YAML not found — SKIP (fail-safe)."
    _skip "C2 NG: task YAML not found"
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

_log "C2: task_status=${TASK_STATUS}"
case "$TASK_STATUS" in
    idle|done|completed) ;;
    *)
        _skip "C2 NG: task status='${TASK_STATUS}' (not idle/done)"
        ;;
esac

# ── C3: dispatch_debt チェック (karo のみ) ────────────────────────────────────
if [ "$ROLE" = "karo" ]; then
    DEBT_COUNT=$("$PYTHON" <<PYEOF 2>/dev/null || echo "0"
import yaml, os, glob, sys

tasks_dir = "$TASKS_DIR"
debt = 0
try:
    for fpath in glob.glob(os.path.join(tasks_dir, "*.yaml")):
        with open(fpath, encoding="utf-8", errors="replace") as f:
            d = yaml.safe_load(f) or {}
        if d.get("status") != "blocked":
            continue
        blocked_by = d.get("blocked_by", [])
        if not blocked_by:
            continue
        if isinstance(blocked_by, str):
            blocked_by = [blocked_by]
        all_done = True
        for dep_id in blocked_by:
            dep_file = os.path.join(tasks_dir, f"{dep_id}.yaml")
            if not os.path.isfile(dep_file):
                all_done = False
                break
            with open(dep_file, encoding="utf-8", errors="replace") as f2:
                dep = yaml.safe_load(f2) or {}
            if dep.get("status") not in ("done", "completed", "idle"):
                all_done = False
                break
        if all_done:
            debt += 1
except Exception:
    sys.exit(0)
print(debt)
PYEOF
    )
    _log "C3: dispatch_debt_count=${DEBT_COUNT}"
    if [ "${DEBT_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        _skip "C3 NG: ${DEBT_COUNT} dispatch debt(s) — blocked tasks with all blocked_by done"
    fi
fi

# ── C4: context_policy=clear_between チェック ────────────────────────────────
PRESERVE_CMDS=""
if [ ! -f "$SHOGUN_TO_KARO" ]; then
    _log "C4: shogun_to_karo.yaml not found — treating as no in_progress cmds."
else
    SCAN_OUTPUT=$("$PYTHON" <<PYEOF 2>/dev/null || echo "IN_PROGRESS_COUNT=0
IN_PROGRESS_LIST=
PRESERVE_LIST="
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
    IN_PROGRESS_COUNT=$(echo "$SCAN_OUTPUT" | grep '^IN_PROGRESS_COUNT=' | cut -d= -f2 || echo "0")
    IN_PROGRESS_LIST=$(echo "$SCAN_OUTPUT" | grep '^IN_PROGRESS_LIST=' | cut -d= -f2- || echo "")
    PRESERVE_CMDS=$(echo "$SCAN_OUTPUT" | grep '^PRESERVE_LIST=' | cut -d= -f2- || echo "")
    IN_PROGRESS_COUNT="${IN_PROGRESS_COUNT:-0}"
    _log "C4: in_progress=${IN_PROGRESS_COUNT} list=[${IN_PROGRESS_LIST:-}]"
fi

if [ -n "${PRESERVE_CMDS:-}" ]; then
    _skip "C4 NG: preserve_across_stages cmd(s) detected [${PRESERVE_CMDS}]"
fi
_log "C4: no preserve_across_stages cmd in progress."

# ── tool_count 取得 ───────────────────────────────────────────────────────────
TOOL_COUNT=0
if [ -n "$TOOL_COUNT_ARG" ]; then
    TOOL_COUNT="$TOOL_COUNT_ARG"
    _log "tool_count from --tool-count arg: ${TOOL_COUNT}"
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
        _log "tool_count from snapshot: ${TOOL_COUNT}"
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
        _log "tool_count from counter(agent): ${TOOL_COUNT}"
    elif [ -f "$COUNTER_FILE_2" ]; then
        RAW=$(cat "$COUNTER_FILE_2" 2>/dev/null | tr -d '[:space:]')
        TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
        _log "tool_count from counter(session): ${TOOL_COUNT}"
    else
        _log "tool_count: no counter file found. Treating as 0."
    fi
fi

_log "tool_count=${TOOL_COUNT}, threshold=${TOOL_THRESHOLD} (role=${ROLE})"
if [ "${TOOL_COUNT:-0}" -le "$TOOL_THRESHOLD" ] 2>/dev/null; then
    _skip "tool_count_below: tool_count(${TOOL_COUNT}) <= threshold(${TOOL_THRESHOLD})"
fi

# ── 全 PASS → APPROVE ────────────────────────────────────────────────────────
_log "ALL CONDITIONS PASSED. (tool_count=${TOOL_COUNT} > ${TOOL_THRESHOLD})"

if [ "$DRY_RUN" = true ]; then
    _log "DRY-RUN: would send clear_command to ${AGENT_ID} (not sent)."
    _approve
fi

bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
    "$AGENT_ID" \
    "auto self-clear: tool count ${TOOL_COUNT} exceeded threshold ${TOOL_THRESHOLD}" \
    "clear_command" \
    "$AGENT_ID"
_log "clear_command sent to ${AGENT_ID}."
_approve
