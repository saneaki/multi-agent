#!/usr/bin/env bash
# session_start_checklist.sh — 足軽起動時に実行。inbox未読とtask YAML不整合を検出する。
# Usage: bash scripts/session_start_checklist.sh <agent_id>

AGENT_ID="${1:-}"
if [ -z "$AGENT_ID" ]; then
    echo "[CHECKLIST] AGENT_ID required" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX="$REPO_DIR/queue/inbox/${AGENT_ID}.yaml"
TASK="$REPO_DIR/queue/tasks/${AGENT_ID}.yaml"

PYTHON="${REPO_DIR}/.venv/bin/python3"
[ -x "$PYTHON" ] || PYTHON="python3"

echo "=== session_start_checklist: $AGENT_ID ==="

# inbox 未読確認
if [ -f "$INBOX" ]; then
    unread=$("$PYTHON" -c "
import yaml
msgs = yaml.safe_load(open('$INBOX')).get('messages', [])
unread = [m for m in msgs if not m.get('read', True)]
print(len(unread))
for m in unread:
    print(f'  [{m.get(\"from\",\"?\")}/{m.get(\"type\",\"?\")}] {m.get(\"content\",\"\")[:80]}')
" 2>/dev/null || echo 0)
    first_line=$(echo "$unread" | head -1)
    if [ "$first_line" -gt 0 ] 2>/dev/null; then
        echo "[WARN] inbox未読 ${first_line}件 — 先に処理せよ"
        echo "$unread" | tail -n +2
    else
        echo "[OK] inbox全件既読"
    fi
else
    echo "[OK] inboxなし"
fi

# task YAML確認
if [ -f "$TASK" ]; then
    task_info=$("$PYTHON" -c "
import yaml
d = yaml.safe_load(open('$TASK'))
print(d.get('status',''))
print(d.get('task_id',''))
" 2>/dev/null)
    status=$(echo "$task_info" | head -1)
    task_id=$(echo "$task_info" | tail -1)
    echo "[INFO] task: $task_id status: $status"
    if [ "$status" = "assigned" ] || [ "$status" = "in_progress" ]; then
        echo "[ACTION] タスクYAMLを読んで作業を開始せよ"
    elif [ "$status" = "completed_pending_karo" ]; then
        echo "[INFO] 家老確認待ち — 次タスク割当を待機"
    fi
else
    echo "[OK] taskなし (待機状態)"
fi
