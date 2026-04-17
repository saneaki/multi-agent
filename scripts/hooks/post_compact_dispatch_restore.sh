#!/usr/bin/env bash
# ============================================================
# PostCompact Hook: Restore Karo's dispatch debt (Issue #32 durable fix)
# Invoked via SessionStart hook (settings.json) — cmd_535 Phase 4
#
# Input:  AGENT_ID (env) or $1
# Action: karo のみ発動。karo_pending.yaml の pre_compact_marker=true を検知し、
#         debt の各 subtask について blocked_by が全 done なら status=blocked→assigned 昇格。
#         昇格件数を karo inbox に dispatch_resume として通知。最後に marker=false。
# Output: exit 0 (session 続行 — ブロックしない)
# ============================================================

set -euo pipefail

SHOGUN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="$SHOGUN_ROOT/.venv/bin/python3"
TASKS_DIR="$SHOGUN_ROOT/queue/tasks"
PENDING_FILE="$TASKS_DIR/karo_pending.yaml"
LOG_DIR="$SHOGUN_ROOT/logs"
LOG_FILE="$LOG_DIR/dispatch_debt.log"

AGENT_ID="${AGENT_ID:-${1:-}}"

# tmux フォールバック (karo 以外にヒットしないので安全)
if [ -z "$AGENT_ID" ] && [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
fi

# karo 以外は無動作 (exit 0 — SessionStart を阻害しない)
if [ "$AGENT_ID" != "karo" ]; then
    exit 0
fi

# pending file がなければ復元不要
if [ ! -f "$PENDING_FILE" ]; then
    exit 0
fi

TIMESTAMP=$(bash "$SHOGUN_ROOT/scripts/jst_now.sh" --yaml 2>/dev/null || date -Iseconds)

mkdir -p "$LOG_DIR"

# ── Step 1-3: marker 確認 + debt iterate + 昇格判定 ──
PROMOTED_COUNT=$("$PYTHON" <<PYEOF 2>/dev/null || echo "0"
import glob
import os
import yaml

pending_path = "$PENDING_FILE"
tasks_dir = "$TASKS_DIR"

try:
    with open(pending_path) as f:
        pending = yaml.safe_load(f) or {}
except Exception:
    print(0)
    raise SystemExit(0)

if not pending.get('pre_compact_marker'):
    # marker がない/false なら何もしない
    print(0)
    raise SystemExit(0)

debt = pending.get('debt', []) or []

# 全タスクファイルの status マップを作成 (blocked_by 解決用)
status_map = {}
for path in sorted(glob.glob(os.path.join(tasks_dir, "*.yaml"))):
    if os.path.basename(path) == 'karo_pending.yaml':
        continue
    try:
        with open(path) as f:
            d = yaml.safe_load(f)
    except Exception:
        continue
    if isinstance(d, dict):
        tid = d.get('task_id') or d.get('subtask_id') or d.get('id')
        if tid:
            status_map[str(tid)] = d.get('status', '')
        for key in ('subtasks', 'tasks'):
            for item in d.get(key, []) or []:
                if isinstance(item, dict):
                    tid2 = item.get('task_id') or item.get('subtask_id') or item.get('id')
                    if tid2:
                        status_map[str(tid2)] = item.get('status', '')
    elif isinstance(d, list):
        for item in d:
            if isinstance(item, dict):
                tid = item.get('task_id') or item.get('subtask_id') or item.get('id')
                if tid:
                    status_map[str(tid)] = item.get('status', '')

# debt 各エントリについて blocked_by が全て done か判定
promoted = []
for entry in debt:
    tid = entry.get('subtask_id', '')
    blocked_by = entry.get('blocked_by', []) or []
    if not blocked_by:
        # blocked_by が空なら即昇格可
        promoted.append(tid)
        continue
    all_done = all(status_map.get(str(b), '') in ('done', 'completed') for b in blocked_by)
    if all_done:
        promoted.append(tid)

# 実際にファイル上の status を blocked → assigned に昇格
promoted_actually = []
for tid in promoted:
    # subtask_id に一致するタスクファイルを探す
    # 1) queue/tasks/{tid}.yaml
    # 2) queue/tasks/*.yaml 内に task_id が一致する top-level entry
    candidate = os.path.join(tasks_dir, f"{tid}.yaml")
    if os.path.isfile(candidate):
        try:
            with open(candidate) as f:
                d = yaml.safe_load(f) or {}
            if d.get('status') == 'blocked':
                d['status'] = 'assigned'
                d['promoted_at'] = "$TIMESTAMP"
                with open(candidate, 'w') as f:
                    yaml.safe_dump(d, f, allow_unicode=True, default_flow_style=False)
                promoted_actually.append(tid)
        except Exception:
            pass
    else:
        # Top-level entry walk
        for path in sorted(glob.glob(os.path.join(tasks_dir, "*.yaml"))):
            try:
                with open(path) as f:
                    d = yaml.safe_load(f)
            except Exception:
                continue
            changed = False
            if isinstance(d, dict):
                tid_cur = d.get('task_id') or d.get('subtask_id') or d.get('id')
                if str(tid_cur) == tid and d.get('status') == 'blocked':
                    d['status'] = 'assigned'
                    d['promoted_at'] = "$TIMESTAMP"
                    changed = True
                # 入れ子も確認
                for key in ('subtasks', 'tasks'):
                    for item in d.get(key, []) or []:
                        if isinstance(item, dict):
                            tid2 = item.get('task_id') or item.get('subtask_id') or item.get('id')
                            if str(tid2) == tid and item.get('status') == 'blocked':
                                item['status'] = 'assigned'
                                item['promoted_at'] = "$TIMESTAMP"
                                changed = True
            if changed:
                try:
                    with open(path, 'w') as f:
                        yaml.safe_dump(d, f, allow_unicode=True, default_flow_style=False)
                    promoted_actually.append(tid)
                except Exception:
                    pass
                break

# karo_pending.yaml の marker を false に、resolved を追記
pending['pre_compact_marker'] = False
pending['resolved_at'] = "$TIMESTAMP"
pending['promoted'] = promoted_actually
try:
    with open(pending_path, 'w') as f:
        yaml.safe_dump(pending, f, allow_unicode=True, default_flow_style=False)
except Exception:
    pass

print(len(promoted_actually))
PYEOF
)

PROMOTED_COUNT="${PROMOTED_COUNT:-0}"
PROMOTED_COUNT="${PROMOTED_COUNT//[$'\n\r ']/}"

# ── Step 4: karo inbox に dispatch_resume msg 投入 ──
# marker なしで早期 exit した場合は promote 件数 0 でも通知不要
# marker あり → 件数に関わらず復帰通知 (0件でも dispatch 確認を促す)
MARKER_WAS_TRUE=$("$PYTHON" <<PYEOF 2>/dev/null || echo "false"
import yaml
try:
    with open("$PENDING_FILE") as f:
        d = yaml.safe_load(f) or {}
    # 今回の実行でマーカーを false に書換済み → resolved_at の有無で判別
    print("true" if d.get('resolved_at') == "$TIMESTAMP" else "false")
except Exception:
    print("false")
PYEOF
)
MARKER_WAS_TRUE="${MARKER_WAS_TRUE//[$'\n\r ']/}"

if [ "$MARKER_WAS_TRUE" = "true" ]; then
    MSG="compact後復帰。${PROMOTED_COUNT}件の blocked→assigned 昇格あり。タスク確認せよ"
    bash "$SHOGUN_ROOT/scripts/inbox_write.sh" karo "$MSG" dispatch_resume system >&2 || \
        echo "[post_compact_dispatch_restore] WARN: inbox_write failed (continuing)" >&2

    echo "${TIMESTAMP}|restored ${PROMOTED_COUNT} tasks (blocked→assigned)" >> "$LOG_FILE"
    echo "[post_compact_dispatch_restore] karo debt restored: ${PROMOTED_COUNT} task(s) promoted → inbox notified" >&2
fi

exit 0
