#!/usr/bin/env bash
# safe_window_judge.sh — 役割別 safe window 判定エンジン (cmd_586 Scope A)
#
# north_star: 外部介入なし。家老/軍師が自律的に /clear or /compact を
#             判断できる decision support を提供する。
#
# Usage:
#   bash scripts/safe_window_judge.sh --agent-id <id> \
#        [--context-pct <n>] [--tool-count <n>]
#
# Output (stdout, key=value 形式。呼出元が parse):
#   SAFE_WINDOW_RESULT=true|false
#   RECOMMENDATION=/clear|/compact|wait
#   REASON=<根拠メッセージ>
#
# Exit code: 0 always (fatal arg error のみ 2)
#
# 役割別判定:
#   karo (cmd_578 §3.1):
#     C1: context_pct >= 70
#     C2: actionable_unread == 0  (type in {task_assigned, blocked, escalate})
#     C3: in_progress == 0        (dashboard.md 🔄 行数で代替判定)
#     C4: dispatch_debt == 0      (blocked かつ blocked_by 全 done)
#     C5: karo_idle_for >= 5min   (/tmp/shogun_idle_karo mtime)
#   gunshi (cmd_578 §3.3):
#     G1: context_pct >= 60
#     G2: qc_cycle_boundary        (queue/tasks/gunshi.yaml status=done)
#     G3: next_qc_not_started      (inbox の task_assigned 未読=0)
#     G4: actionable_unread == 0
#   ashigaru*:
#     既存 safe_clear_check.sh に委譲 (non-regression)
#
# 推奨選択ロジック:
#   context_pct >= 85  → /compact (強制、auto-compact 92% 回避)
#   karo: in_progress >= 1 (残り cmd あり) → /compact (文脈保持)
#   karo: 全条件 AND  & in_progress == 0   → /clear
#   gunshi: G1-G4 全成立  → /clear (QC cycle 区切り)
#   gunshi: QC 途中 (G2/G3 未成立)         → /compact のみ
#   上記のいずれも満たさぬ                  → wait

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="${AGENT_ID:-}"
CONTEXT_PCT=""
TOOL_COUNT_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --agent-id)
            AGENT_ID="${2:-}"
            if [ -z "$AGENT_ID" ]; then
                echo "[safe_window_judge] --agent-id requires a value" >&2
                exit 2
            fi
            shift 2
            ;;
        --context-pct)
            CONTEXT_PCT="${2:-}"
            shift 2
            ;;
        --tool-count)
            TOOL_COUNT_ARG="${2:-}"
            shift 2
            ;;
        *)
            echo "[safe_window_judge] Unknown option: $1" >&2
            shift
            ;;
    esac
done

if [ -z "$AGENT_ID" ]; then
    echo "[safe_window_judge] --agent-id is required (or set AGENT_ID env)" >&2
    exit 2
fi

PYTHON="$SCRIPT_DIR/.venv/bin/python3"
[ -x "$PYTHON" ] || PYTHON="python3"

LOG_DIR="$SCRIPT_DIR/logs/safe_window"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="$LOG_DIR/${AGENT_ID}.log"

_log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%S')] [safe_window_judge:${AGENT_ID}] $*"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

_self_notify_karo() {
    # REC が wait 以外のときのみ、karo inbox に compact suggestion を通知。
    # 10分以内の重複通知は /tmp の timestamp で抑止する。
    local result="$1"
    local rec="$2"
    local reason="$3"
    local guard_file="/tmp/safe_window_judge_notify_${AGENT_ID}.ts"
    local now_epoch last_epoch delta

    [ "$AGENT_ID" = "karo" ] || return 0
    [ "$rec" != "wait" ] || return 0

    now_epoch=$(date +%s)
    last_epoch=""
    if [ -f "$guard_file" ]; then
        last_epoch=$(cat "$guard_file" 2>/dev/null || true)
    fi

    if echo "${last_epoch}" | grep -qE '^[0-9]+$'; then
        delta=$(( now_epoch - last_epoch ))
        if [ "$delta" -lt 600 ]; then
            _log "self-notify suppressed (loop guard): delta=${delta}s<600s rec=${rec}"
            return 0
        fi
    fi

    local msg="[safe_window_judge] RESULT=${result} REC=${rec} REASON=${reason} context_pct=${CONTEXT_PCT}"
    if bash "$SCRIPT_DIR/scripts/inbox_write.sh" karo "$msg" compact_suggestion safe_window_judge; then
        echo "$now_epoch" > "$guard_file" 2>/dev/null || true
        _log "self-notify sent: type=compact_suggestion rec=${rec}"
    else
        _log "self-notify failed: type=compact_suggestion rec=${rec}"
    fi
}

_emit() {
    # $1=SAFE_WINDOW_RESULT(true|false), $2=RECOMMENDATION(/clear|/compact|wait), $3=REASON
    _self_notify_karo "$1" "$2" "$3"
    echo "SAFE_WINDOW_RESULT=$1"
    echo "RECOMMENDATION=$2"
    echo "REASON=$3"
    _log "RESULT=$1 REC=$2 REASON=$3"
    _log "=== END ==="
    exit 0
}

_log "=== START agent=${AGENT_ID} context_pct=${CONTEXT_PCT:-unset} tool_count=${TOOL_COUNT_ARG:-unset} ==="

# ── Role 判定 ────────────────────────────────────────────────────────────────
case "$AGENT_ID" in
    karo)      ROLE="karo" ;;
    gunshi)    ROLE="gunshi" ;;
    ashigaru*) ROLE="ashigaru" ;;
    shogun)
        _emit "false" "wait" "shogun: auto-clear forbidden (F001)"
        ;;
    *)
        _emit "false" "wait" "unknown agent_id: ${AGENT_ID}"
        ;;
esac
_log "role=${ROLE}"

# ── ashigaru: 既存 safe_clear_check.sh に委譲 (non-regression) ───────────────
if [ "$ROLE" = "ashigaru" ]; then
    SCC_ARGS=(--agent-id "$AGENT_ID" --dry-run)
    [ -n "$TOOL_COUNT_ARG" ] && SCC_ARGS+=(--tool-count "$TOOL_COUNT_ARG")
    SCC_RC=0
    SCC_OUT=$(bash "$SCRIPT_DIR/scripts/safe_clear_check.sh" "${SCC_ARGS[@]}" 2>&1) || SCC_RC=$?
    _log "delegated to safe_clear_check.sh rc=${SCC_RC}"
    if [ "$SCC_RC" -eq 0 ]; then
        _emit "true" "/clear" "ashigaru: safe_clear_check APPROVE (non-regression)"
    else
        REASON=$(echo "$SCC_OUT" | grep -E "SKIP:" | tail -1 | sed 's/.*SKIP: /SKIP: /' || echo "SKIP")
        _emit "false" "wait" "ashigaru: safe_clear_check SKIP — ${REASON}"
    fi
fi

# ── context_pct の解釈 (karo/gunshi 用) ──────────────────────────────────────
if [ -z "$CONTEXT_PCT" ]; then
    # --context-pct 未指定時は最も保守的な 0% として扱う (wait 推奨)
    _emit "false" "wait" "${ROLE}: --context-pct 未指定 (保守的に wait)"
fi

# context_pct が整数か確認
if ! echo "$CONTEXT_PCT" | grep -qE '^[0-9]+$'; then
    _emit "false" "wait" "${ROLE}: --context-pct 非数値 (${CONTEXT_PCT})"
fi

# ── 共通ヘルパ: actionable_unread 集計 ───────────────────────────────────────
_actionable_unread() {
    # $1=agent_id
    # type in {task_assigned, blocked, escalate} かつ read=false の件数
    local inbox="$SCRIPT_DIR/queue/inbox/$1.yaml"
    if [ ! -f "$inbox" ]; then
        echo "0"
        return
    fi
    "$PYTHON" - "$inbox" <<'PYEOF' 2>/dev/null || echo "0"
import sys, yaml
ACTIONABLE = {"task_assigned", "blocked", "escalate"}
try:
    with open(sys.argv[1]) as f:
        d = yaml.safe_load(f) or {}
    msgs = d.get("messages", []) or []
    n = sum(1 for m in msgs
            if not m.get("read", True)
            and m.get("type") in ACTIONABLE)
    print(n)
except Exception:
    print(0)
PYEOF
}

# ── 共通ヘルパ: dispatch_debt 集計 (karo only) ───────────────────────────────
_dispatch_debt() {
    local tasks_dir="$SCRIPT_DIR/queue/tasks"
    "$PYTHON" - "$tasks_dir" <<'PYEOF' 2>/dev/null || echo "0"
import sys, os, glob, yaml
tasks_dir = sys.argv[1]
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
    pass
print(debt)
PYEOF
}

# ── 共通ヘルパ: dashboard.md 🔄 in_progress 行数 (karo C3) ───────────────────
_dashboard_in_progress() {
    local dash="$SCRIPT_DIR/dashboard.md"
    if [ ! -f "$dash" ]; then
        echo "0"
        return
    fi
    "$PYTHON" - "$dash" <<'PYEOF' 2>/dev/null || echo "0"
import sys, re
with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
    content = f.read()
# "## 🔄 進行中" から次の "## " までを抽出
m = re.search(r'##\s*🔄[^\n]*\n(.*?)(?=^##\s)', content, re.DOTALL | re.MULTILINE)
if not m:
    print(0)
else:
    section = m.group(1)
    # "| cmd_XXX |" で始まる行を数える (ヘッダ/区切りは除外)
    count = sum(1 for line in section.splitlines()
                if re.match(r'^\|\s*cmd_\d+\s*\|', line))
    print(count)
PYEOF
}

# ── 共通ヘルパ: karo idle 時間 (秒) (C5) ─────────────────────────────────────
_karo_idle_secs() {
    local flag="/tmp/shogun_idle_karo"
    if [ ! -f "$flag" ]; then
        # idle flag が無い = stop_hook 未発火 = 作業中扱い
        echo "0"
        return
    fi
    local now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$flag" 2>/dev/null || echo "$now")
    echo $(( now - mtime ))
}

# ── karo: C1-C5 判定 ─────────────────────────────────────────────────────────
if [ "$ROLE" = "karo" ]; then
    FAIL=""

    # C1: context_pct >= 70
    if [ "$CONTEXT_PCT" -lt 70 ]; then
        FAIL="${FAIL}C1(context=${CONTEXT_PCT}%<70) "
    fi

    # C2: actionable_unread == 0
    C2_UNREAD=$(_actionable_unread "karo")
    if [ "${C2_UNREAD:-0}" -ne 0 ] 2>/dev/null; then
        FAIL="${FAIL}C2(actionable_unread=${C2_UNREAD}) "
    fi

    # C3: in_progress == 0 (dashboard.md 代替判定 — karo C2 logic 修正)
    C3_INPROG=$(_dashboard_in_progress)
    if [ "${C3_INPROG:-0}" -ne 0 ] 2>/dev/null; then
        FAIL="${FAIL}C3(in_progress=${C3_INPROG}) "
    fi

    # C4: dispatch_debt == 0
    C4_DEBT=$(_dispatch_debt)
    if [ "${C4_DEBT:-0}" -ne 0 ] 2>/dev/null; then
        FAIL="${FAIL}C4(dispatch_debt=${C4_DEBT}) "
    fi

    # C5: karo_idle_for >= 300 秒
    C5_IDLE=$(_karo_idle_secs)
    if [ "${C5_IDLE:-0}" -lt 300 ] 2>/dev/null; then
        FAIL="${FAIL}C5(idle=${C5_IDLE}s<300s) "
    fi

    _log "karo C1=${CONTEXT_PCT}%, C2=${C2_UNREAD}, C3=${C3_INPROG}, C4=${C4_DEBT}, C5=${C5_IDLE}s"

    # 推奨選択
    if [ "$CONTEXT_PCT" -ge 85 ]; then
        _emit "false" "/compact" "karo: context_pct=${CONTEXT_PCT}%>=85 強制 /compact (auto-compact 回避)"
    fi

    if [ -z "$FAIL" ]; then
        # 全 PASS → in_progress は C3 で 0 確認済のため /clear
        _emit "true" "/clear" "karo: C1-C5 全成立 (context=${CONTEXT_PCT}% unread=${C2_UNREAD} in_progress=${C3_INPROG} debt=${C4_DEBT} idle=${C5_IDLE}s)"
    fi

    # 一部条件 fail — in_progress が 1+ なら /compact 推奨
    if [ "${C3_INPROG:-0}" -ge 1 ] 2>/dev/null && [ "$CONTEXT_PCT" -ge 70 ]; then
        _emit "false" "/compact" "karo: in_progress=${C3_INPROG} (進行中 cmd 保持) + context=${CONTEXT_PCT}%>=70 → /compact 推奨 [fail: ${FAIL}]"
    fi

    _emit "false" "wait" "karo: 条件未充足 → wait [fail: ${FAIL}]"
fi

# ── gunshi: G1-G4 判定 ───────────────────────────────────────────────────────
if [ "$ROLE" = "gunshi" ]; then
    FAIL=""

    # G1: context_pct >= 60
    if [ "$CONTEXT_PCT" -lt 60 ]; then
        FAIL="${FAIL}G1(context=${CONTEXT_PCT}%<60) "
    fi

    # G2: qc_cycle_boundary (queue/tasks/gunshi.yaml status=done)
    GUNSHI_TASK="$SCRIPT_DIR/queue/tasks/gunshi.yaml"
    G2_STATUS="missing"
    if [ -f "$GUNSHI_TASK" ]; then
        G2_STATUS=$("$PYTHON" -c "
import yaml
try:
    with open('$GUNSHI_TASK') as f:
        d = yaml.safe_load(f) or {}
    print(d.get('status', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")
    fi
    case "$G2_STATUS" in
        done|completed|idle) ;;
        *) FAIL="${FAIL}G2(task_status=${G2_STATUS}) " ;;
    esac

    # G3: next_qc_not_started (inbox type=task_assigned read=false が 0)
    G3_PENDING=$("$PYTHON" - "$SCRIPT_DIR/queue/inbox/gunshi.yaml" <<'PYEOF' 2>/dev/null || echo "0"
import sys, os, yaml
path = sys.argv[1]
if not os.path.exists(path):
    print(0); sys.exit(0)
try:
    with open(path) as f:
        d = yaml.safe_load(f) or {}
    msgs = d.get("messages", []) or []
    n = sum(1 for m in msgs
            if not m.get("read", True)
            and m.get("type") == "task_assigned")
    print(n)
except Exception:
    print(0)
PYEOF
)
    if [ "${G3_PENDING:-0}" -ne 0 ] 2>/dev/null; then
        FAIL="${FAIL}G3(pending_qc=${G3_PENDING}) "
    fi

    # G4: actionable_unread == 0
    G4_UNREAD=$(_actionable_unread "gunshi")
    if [ "${G4_UNREAD:-0}" -ne 0 ] 2>/dev/null; then
        FAIL="${FAIL}G4(actionable_unread=${G4_UNREAD}) "
    fi

    _log "gunshi G1=${CONTEXT_PCT}%, G2=${G2_STATUS}, G3=${G3_PENDING}, G4=${G4_UNREAD}"

    # 推奨選択
    if [ "$CONTEXT_PCT" -ge 85 ]; then
        _emit "false" "/compact" "gunshi: context_pct=${CONTEXT_PCT}%>=85 強制 /compact"
    fi

    if [ -z "$FAIL" ]; then
        _emit "true" "/clear" "gunshi: G1-G4 全成立 (QC cycle 区切り) (context=${CONTEXT_PCT}% status=${G2_STATUS} pending=${G3_PENDING} unread=${G4_UNREAD})"
    fi

    # G2/G3 が NG → QC 途中 → /compact のみ可 (文脈保持)
    case "$FAIL" in
        *G2*|*G3*)
            if [ "$CONTEXT_PCT" -ge 60 ]; then
                _emit "false" "/compact" "gunshi: QC 途中 (${FAIL}) かつ context=${CONTEXT_PCT}%>=60 → /compact のみ可"
            fi
            ;;
    esac

    _emit "false" "wait" "gunshi: 条件未充足 → wait [fail: ${FAIL}]"
fi

# ここまで来ることはない
_emit "false" "wait" "unreachable: role=${ROLE}"
