#!/usr/bin/env bash
# ============================================================
# PreCompact Hook: Save agent context snapshot before compaction
# Called by Claude Code PreCompact hook (settings.json)
# Always exits 0 — must never block compaction
# ============================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
SNAPSHOT_DIR="${SHOGUN_ROOT}/queue/snapshots"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

mkdir -p "$SNAPSHOT_DIR"

# --- Identify agent ---
AGENT_ID="unknown"
if [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "unknown")
fi

# Skip if not in tmux (VSCode mode)
if [ "$AGENT_ID" = "unknown" ] || [ -z "$AGENT_ID" ]; then
    exit 0
fi

SNAPSHOT_FILE="${SNAPSHOT_DIR}/${AGENT_ID}_snapshot.yaml"

# --- Read current task YAML ---
TASK_ID=""
PARENT_CMD=""
TASK_STATUS=""
TASK_DESC=""

# Determine task file path
case "$AGENT_ID" in
    karo)
        TASK_FILE="${SHOGUN_ROOT}/queue/shogun_to_karo.yaml"
        ;;
    gunshi)
        TASK_FILE="${SHOGUN_ROOT}/queue/tasks/gunshi.yaml"
        ;;
    shogun)
        TASK_FILE="${SHOGUN_ROOT}/queue/shogun_to_karo.yaml"
        ;;
    ashigaru*)
        TASK_FILE="${SHOGUN_ROOT}/queue/tasks/${AGENT_ID}.yaml"
        ;;
    *)
        TASK_FILE=""
        ;;
esac

if [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ]; then
    TASK_ID=$(python3 -c "
import yaml, sys
try:
    with open('$TASK_FILE') as f:
        d = yaml.safe_load(f) or {}
    # ashigaru/gunshi: direct task_id
    if 'task_id' in d:
        print(d.get('task_id', ''))
    # karo/shogun: find active cmd
    elif isinstance(d, list):
        for item in d:
            if isinstance(item, dict) and item.get('status') in ('in_progress', 'assigned', 'active'):
                print(item.get('id', item.get('task_id', '')))
                break
    elif isinstance(d, dict):
        for k, v in d.items():
            if isinstance(v, dict) and v.get('status') in ('in_progress', 'assigned', 'active'):
                print(v.get('id', k))
                break
except Exception:
    pass
" 2>/dev/null || echo "")

    PARENT_CMD=$(python3 -c "
import yaml
try:
    with open('$TASK_FILE') as f:
        d = yaml.safe_load(f) or {}
    print(d.get('parent_cmd', ''))
except Exception:
    pass
" 2>/dev/null || echo "")

    TASK_STATUS=$(python3 -c "
import yaml
try:
    with open('$TASK_FILE') as f:
        d = yaml.safe_load(f) or {}
    print(d.get('status', ''))
except Exception:
    pass
" 2>/dev/null || echo "")

    TASK_DESC=$(python3 -c "
import yaml
try:
    with open('$TASK_FILE') as f:
        d = yaml.safe_load(f) or {}
    desc = d.get('description', d.get('purpose', d.get('command', '')))
    print(str(desc)[:80])
except Exception:
    pass
" 2>/dev/null || echo "")
fi

# --- Uncommitted files ---
UNCOMMITTED=$(cd "$SHOGUN_ROOT" && git diff --name-only 2>/dev/null | head -20 || echo "")

# --- Preserve existing agent_context (written by agent proactively) ---
EXISTING_CONTEXT=""
if [ -f "$SNAPSHOT_FILE" ]; then
    EXISTING_CONTEXT=$(python3 -c "
import yaml, json
try:
    with open('$SNAPSHOT_FILE') as f:
        d = yaml.safe_load(f) or {}
    ctx = d.get('agent_context', {})
    if ctx:
        print(yaml.dump(ctx, default_flow_style=False, allow_unicode=True).rstrip())
except Exception:
    pass
" 2>/dev/null || echo "")
fi

# --- Write snapshot YAML ---
{
    echo "agent_id: ${AGENT_ID}"
    echo "snapshot_at: \"${TIMESTAMP}\""
    echo "trigger: pre_compact"
    echo "task:"
    echo "  task_id: \"${TASK_ID}\""
    echo "  parent_cmd: \"${PARENT_CMD}\""
    echo "  status: \"${TASK_STATUS}\""
    echo "  description: \"${TASK_DESC}\""
    if [ -n "$UNCOMMITTED" ]; then
        echo "uncommitted_files:"
        echo "$UNCOMMITTED" | while IFS= read -r line; do
            [ -n "$line" ] && echo "  - \"${line}\""
        done
    else
        echo "uncommitted_files: []"
    fi
    echo "agent_context:"
    if [ -n "$EXISTING_CONTEXT" ]; then
        echo "$EXISTING_CONTEXT" | sed 's/^/  /'
    else
        echo "  approach: \"\""
        echo "  progress: []"
        echo "  decisions: []"
        echo "  blockers: []"
    fi
} > "${SNAPSHOT_FILE}.tmp"

mv "${SNAPSHOT_FILE}.tmp" "$SNAPSHOT_FILE"

exit 0
