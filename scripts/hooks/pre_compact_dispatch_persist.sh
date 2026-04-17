#!/usr/bin/env bash
# ============================================================
# PreCompact Hook: Persist Karo's dispatch debt (Issue #32 durable fix)
# Called by Claude Code PreCompact hook (settings.json) — cmd_535 Phase 4
#
# Input:  AGENT_ID (env) or $1
# Action: karo のみ発動。queue/tasks/*.yaml から status=blocked タスクを集計し
#         queue/tasks/karo_pending.yaml に durable 書込 + snapshot ref + log
# Output: exit 0 (compact 継続 — 阻止しない)
# ============================================================

set -euo pipefail

SHOGUN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="$SHOGUN_ROOT/.venv/bin/python3"
TASKS_DIR="$SHOGUN_ROOT/queue/tasks"
SNAPSHOT_FILE="$SHOGUN_ROOT/queue/snapshots/karo_snapshot.yaml"
PENDING_FILE="$TASKS_DIR/karo_pending.yaml"
LOG_DIR="$SHOGUN_ROOT/logs"
LOG_FILE="$LOG_DIR/dispatch_debt.log"

AGENT_ID="${AGENT_ID:-${1:-}}"

# tmux からの自己識別フォールバック
if [ -z "$AGENT_ID" ] && [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
fi

# karo 以外は無動作
if [ "$AGENT_ID" != "karo" ]; then
    exit 0
fi

TIMESTAMP=$(bash "$SHOGUN_ROOT/scripts/jst_now.sh" --yaml 2>/dev/null || date -Iseconds)

mkdir -p "$LOG_DIR" "$TASKS_DIR"

# ── Step 1: queue/tasks/*.yaml から status=blocked タスクを集計 ──
DEBT_YAML=$("$PYTHON" <<PYEOF 2>/dev/null || echo ""
import glob
import os
import yaml

tasks_dir = "$TASKS_DIR"
debt = []

def _collect(entry, default_file=""):
    if not isinstance(entry, dict):
        return
    status = entry.get('status')
    if status != 'blocked':
        return
    tid = entry.get('task_id') or entry.get('subtask_id') or entry.get('id') or ''
    if not tid:
        return
    parent = (
        entry.get('parent_cmd') or entry.get('cmd_id') or
        entry.get('parent') or ''
    )
    blocked_by = entry.get('blocked_by') or entry.get('depends_on') or []
    if isinstance(blocked_by, str):
        blocked_by = [blocked_by]
    created = (
        entry.get('created_at') or entry.get('assigned_at') or
        entry.get('issued_at') or ''
    )
    debt.append({
        'subtask_id': str(tid),
        'parent_cmd': str(parent) if parent else '',
        'blocked_by': list(blocked_by),
        'created_at': str(created) if created else '',
        'source_file': os.path.basename(default_file),
    })

for path in sorted(glob.glob(os.path.join(tasks_dir, "*.yaml"))):
    if os.path.basename(path) == 'karo_pending.yaml':
        continue
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except Exception:
        continue
    if data is None:
        continue
    # Top-level entry
    if isinstance(data, dict):
        _collect(data, path)
        # Nested subtasks list
        for key in ('subtasks', 'tasks'):
            sub = data.get(key)
            if isinstance(sub, list):
                for item in sub:
                    _collect(item, path)
    elif isinstance(data, list):
        for item in data:
            _collect(item, path)

print(yaml.safe_dump({'debt': debt}, allow_unicode=True, default_flow_style=False, sort_keys=False).rstrip())
PYEOF
)

DEBT_COUNT=$(echo "$DEBT_YAML" | grep -c '^- subtask_id:' || true)
DEBT_COUNT="${DEBT_COUNT:-0}"

# ── Step 2: queue/tasks/karo_pending.yaml に書込 ──
{
    echo "# dispatch debt durable — PreCompact hook (cmd_535 Phase 4)"
    echo "timestamp: \"${TIMESTAMP}\""
    echo "pre_compact_marker: true"
    echo "debt_count: ${DEBT_COUNT}"
    if [ "$DEBT_COUNT" -gt 0 ]; then
        echo "$DEBT_YAML"
    else
        echo "debt: []"
    fi
} > "${PENDING_FILE}.tmp"

mv "${PENDING_FILE}.tmp" "$PENDING_FILE"

# ── Step 3: karo snapshot に参照追記 (YAML 壊さないよう flag append) ──
if [ -f "$SNAPSHOT_FILE" ]; then
    if ! grep -q 'karo_pending_ref:' "$SNAPSHOT_FILE" 2>/dev/null; then
        printf "\nkaro_pending_ref: %q\npre_compact_persisted_at: %q\n" \
            "queue/tasks/karo_pending.yaml" "$TIMESTAMP" >> "$SNAPSHOT_FILE"
    else
        # 既存 ref を更新
        "$PYTHON" <<PYEOF 2>/dev/null || true
import yaml
path = "$SNAPSHOT_FILE"
try:
    with open(path) as f:
        d = yaml.safe_load(f) or {}
    d['karo_pending_ref'] = 'queue/tasks/karo_pending.yaml'
    d['pre_compact_persisted_at'] = "$TIMESTAMP"
    with open(path, 'w') as f:
        yaml.safe_dump(d, f, allow_unicode=True, default_flow_style=False)
except Exception:
    pass
PYEOF
    fi
fi

# ── Step 4: logs/dispatch_debt.log に append ──
echo "${TIMESTAMP}|${DEBT_COUNT} tasks saved" >> "$LOG_FILE"

# stderr に実行ログ (stdout は compact を阻害しないため sparing に)
echo "[pre_compact_dispatch_persist] karo debt persisted: ${DEBT_COUNT} blocked task(s) → ${PENDING_FILE}" >&2

exit 0
