#!/usr/bin/env bash
# karo_self_clear_check.sh — 家老の自己 /clear 判定スクリプト (cmd_531 Phase 3)
#
# Usage: bash scripts/karo_self_clear_check.sh [--dry-run] [--tool-count N]
#
# 判定条件(全 AND が必要。1つでも NG → SKIP with reason log):
#   cond_1: shogun_to_karo.yaml に status=in_progress の cmd がゼロ
#   cond_2: 全 queue/tasks/ashigaru*.yaml + gunshi.yaml が status=idle
#   cond_3: queue/inbox/karo.yaml に read:false エントリがゼロ
#   cond_4: 進行中 cmd に context_policy=preserve_across_stages なし (defense-in-depth)
#   cond_5: tool_count > 50 (家老は足軽より高閾値)
#
# 全 PASS → bash scripts/inbox_write.sh karo "auto self-clear: ..." clear_command karo
# NG → SKIP + reason log (stdout + /tmp/self_clear_karo.log)
#
# exit code: 0=正常終了 (SKIP 含む), 1=引数エラー

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="karo"
DRY_RUN=false
TOOL_COUNT_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --tool-count)
            TOOL_COUNT_ARG="${2:-}"
            if [ -z "$TOOL_COUNT_ARG" ]; then
                echo "[karo_self_clear_check] --tool-count requires a value" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "[karo_self_clear_check] Unknown option: $1" >&2
            shift
            ;;
    esac
done

LOG_FILE="/tmp/self_clear_karo.log"
TOOL_THRESHOLD=50
PYTHON="$SCRIPT_DIR/.venv/bin/python3"
TASKS_DIR="$SCRIPT_DIR/queue/tasks"
INBOX_YAML="$SCRIPT_DIR/queue/inbox/karo.yaml"
SHOGUN_TO_KARO="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
SNAPSHOT_YAML="$SCRIPT_DIR/queue/snapshots/karo_snapshot.yaml"

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [karo_self_clear_check] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

_skip() {
    _log "SKIP: $*"
    _log "=== karo_self_clear_check END (SKIP) ==="
    exit 0
}

_log "=== karo_self_clear_check START (dry_run=${DRY_RUN}) ==="

# ── cond_1 & cond_4: shogun_to_karo.yaml の in_progress + context_policy スキャン ──
# yaml.safe_load は大規模ファイルのパースエラーに弱いため regex ベースで抽出する
if [ ! -f "$SHOGUN_TO_KARO" ]; then
    _log "shogun_to_karo.yaml not found — treating as no in_progress cmds."
    IN_PROGRESS_COUNT=0
    PRESERVE_CMDS=""
else
    SCAN_OUTPUT=$("$PYTHON" <<PYEOF
import re

with open("$SHOGUN_TO_KARO") as f:
    content = f.read()

# cmd ブロック境界: 行頭 "- cmd_id:" または "- id: cmd_"
blocks = re.split(r'(?m)^(?=- (?:cmd_id|id): cmd_\d+)', content)

in_progress = []
preserve = []
for block in blocks:
    m = re.match(r'- (?:cmd_id|id): (cmd_\d+)', block)
    if not m:
        continue
    cmd_id = m.group(1)
    # インデント2スペースの status フィールド
    status_m = re.search(r'(?m)^  status:\s*["\']?([A-Za-z_]+)["\']?', block)
    if not status_m:
        continue
    status = status_m.group(1)
    if status != 'in_progress':
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

_log "cond_1: in_progress cmd count=${IN_PROGRESS_COUNT} (list=[${IN_PROGRESS_LIST:-}])"
if [ "$IN_PROGRESS_COUNT" -gt 0 ] 2>/dev/null; then
    _skip "cond_1 NG: ${IN_PROGRESS_COUNT} in_progress cmd(s) in shogun_to_karo.yaml [${IN_PROGRESS_LIST}]"
fi

# ── cond_2: 全 ashigaru*.yaml + gunshi.yaml が status=idle ──
ACTIVE_AGENTS=""
for tf in "$TASKS_DIR"/ashigaru*.yaml "$TASKS_DIR/gunshi.yaml"; do
    [ -f "$tf" ] || continue
    STATUS=$("$PYTHON" -c "
import yaml, sys
try:
    with open('$tf') as f:
        d = yaml.safe_load(f) or {}
    print(d.get('status', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")
    if [ "$STATUS" != "idle" ]; then
        ACTIVE_AGENTS="${ACTIVE_AGENTS}$(basename "$tf" .yaml)=${STATUS} "
    fi
done

if [ -n "$ACTIVE_AGENTS" ]; then
    _log "cond_2: active agents detected: ${ACTIVE_AGENTS}"
    _skip "cond_2 NG: non-idle agents [${ACTIVE_AGENTS}]"
fi
_log "cond_2: all ashigaru + gunshi are idle."

# ── cond_3: karo.yaml inbox の未読エントリ ──
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
fi

_log "cond_3: unread_inbox_count=${UNREAD_COUNT}"
if [ "$UNREAD_COUNT" -gt 0 ] 2>/dev/null; then
    _skip "cond_3 NG: ${UNREAD_COUNT} unread inbox message(s) in karo.yaml"
fi

# ── cond_4: preserve_across_stages chk (cond_1 通過時の保険) ──
if [ -n "$PRESERVE_CMDS" ]; then
    _skip "cond_4 NG: preserve_across_stages cmd(s) detected [${PRESERVE_CMDS}]"
fi
_log "cond_4: no preserve_across_stages cmd in progress."

# ── cond_5: tool_count 取得と閾値判定 ──
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
    if [ "$SNAP_COUNT" -gt 0 ] 2>/dev/null; then
        TOOL_COUNT="$SNAP_COUNT"
        _log "tool_count from karo_snapshot.yaml: ${TOOL_COUNT}"
    fi
fi

if [ "$TOOL_COUNT" -eq 0 ] 2>/dev/null; then
    # Fallback: agent-specific counter or shared session counter
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
        _log "tool_count from ${COUNTER_FILE_1}: ${TOOL_COUNT}"
    elif [ -f "$COUNTER_FILE_2" ]; then
        RAW=$(cat "$COUNTER_FILE_2" 2>/dev/null | tr -d '[:space:]')
        TOOL_COUNT=$(echo "$RAW" | grep -E '^[0-9]+$' || echo "0")
        _log "tool_count from ${COUNTER_FILE_2}: ${TOOL_COUNT}"
    else
        _log "tool_count: no counter file found. Treating as 0 (graceful degradation)."
    fi
fi

_log "cond_5: tool_count=${TOOL_COUNT}, threshold=${TOOL_THRESHOLD}"
if [ "$TOOL_COUNT" -le "$TOOL_THRESHOLD" ] 2>/dev/null; then
    _skip "cond_5 NG: tool_count(${TOOL_COUNT}) <= threshold(${TOOL_THRESHOLD})"
fi

# ── 全 PASS → safe_window_judge.sh 連携 → context_advisory or clear_command ──
_log "ALL CONDITIONS PASSED."

SAFE_WINDOW_JUDGE="$SCRIPT_DIR/scripts/safe_window_judge.sh"
if [ -f "$SAFE_WINDOW_JUDGE" ]; then
    # safe_window_judge.sh 実装済 → SAFE_WINDOW_RESULT=true|false を parse
    JUDGE_OUTPUT=$(bash "$SAFE_WINDOW_JUDGE" --agent-id karo 2>/dev/null || echo "SAFE_WINDOW_RESULT=false")
    SAFE_WINDOW_RESULT=$(echo "$JUDGE_OUTPUT" | grep -oE 'SAFE_WINDOW_RESULT=(true|false)' | head -1 | cut -d= -f2 || echo "false")
    case "$SAFE_WINDOW_RESULT" in
        true) JUDGE_VERDICT="APPROVE" ;;
        *) JUDGE_VERDICT="SKIP" ;;
    esac
    _log "safe_window_judge verdict: ${JUDGE_OUTPUT:-SKIP}"

    if [ "$JUDGE_VERDICT" = "APPROVE" ]; then
        JUDGE_PCT=$(echo "$JUDGE_OUTPUT" | grep -oE 'context_pct=[0-9]+' | cut -d= -f2 || echo "")
        JUDGE_RECOMMEND=$(echo "$JUDGE_OUTPUT" | grep -oE 'RECOMMENDATION=(/clear|/compact)' | head -1 | cut -d= -f2 | sed 's|^/||' || echo "clear")

        # dedup: 30min 以内に context_advisory 送信済みなら skip
        DEDUP_MARKER="/tmp/karo_context_advisory_last_sent"
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
            ADV_MSG="safe window 到達。${PCT_PART}推奨: /${RECOMMEND}。全条件PASS(cond_1-5)。"
            if [ "$DRY_RUN" = true ]; then
                _log "DRY-RUN: would send context_advisory: ${ADV_MSG}"
            else
                bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
                    "$AGENT_ID" "$ADV_MSG" "context_advisory" "karo_self_judge"
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

_log "=== karo_self_clear_check END ==="
exit 0
