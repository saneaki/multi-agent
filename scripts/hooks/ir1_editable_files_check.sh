#!/usr/bin/env bash
# ============================================================
# IR-1 PostToolUse Hook: editable_files whitelist check
#
# Called by Claude Code PostToolUse for Edit/Write operations.
# Reads the ashigaru's task YAML to determine allowed files.
#
# Non-ashigaru agents (karo, gunshi, shogun) are exempt.
#
# Stdin: JSON from Claude Code with tool_input.file_path
#
# Test overrides (env vars):
#   __IR1_AGENT_ID    — mock agent identity (skips tmux)
#   __IR1_SHOGUN_ROOT — override project root path
#   __IR1_LOG_SCRIPT  — override log_violation.sh path
# ============================================================

set -euo pipefail

SHOGUN_ROOT="${__IR1_SHOGUN_ROOT:-/home/ubuntu/shogun}"

# Read stdin JSON (from Claude Code PostToolUse)
INPUT=$(cat 2>/dev/null || true)

# Extract file_path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Get agent ID (with test override)
if [ -n "${__IR1_AGENT_ID:-}" ]; then
    AGENT_ID="$__IR1_AGENT_ID"
elif [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
else
    AGENT_ID=""
fi

# Skip if not ashigaru (karo, gunshi, shogun, unknown are exempt)
if [[ ! "$AGENT_ID" =~ ^ashigaru[0-9]+$ ]]; then
    exit 0
fi

# Implicit allowlist: own report YAML and own task YAML
REPORT_YAML="${SHOGUN_ROOT}/queue/reports/${AGENT_ID}_report.yaml"
TASK_YAML="${SHOGUN_ROOT}/queue/tasks/${AGENT_ID}.yaml"

if [ "$FILE_PATH" = "$REPORT_YAML" ] || [ "$FILE_PATH" = "$TASK_YAML" ]; then
    exit 0
fi

# Read editable_files from task YAML
if [ ! -f "$TASK_YAML" ]; then
    echo "WARNING: Task YAML not found for ${AGENT_ID}, skipping editable_files check" >&2
    exit 0
fi

EDITABLE_RESULT=$(python3 -c "
import yaml, sys, os, fnmatch

task_yaml = sys.argv[1]
file_path = sys.argv[2]
shogun_root = sys.argv[3]

with open(task_yaml) as f:
    data = yaml.safe_load(f)

task = data.get('task', {})
editable = task.get('editable_files', None)

if editable is None:
    print('MISSING')
    sys.exit(0)

# Resolve file_path to absolute
file_path = os.path.abspath(file_path)

for pattern in editable:
    pattern = pattern.strip()
    if not pattern:
        continue
    # Make relative patterns absolute from shogun root
    if not os.path.isabs(pattern):
        abs_pattern = os.path.join(shogun_root, pattern)
    else:
        abs_pattern = pattern
    if fnmatch.fnmatch(file_path, abs_pattern):
        print('MATCH')
        sys.exit(0)

print('NO_MATCH')
" "$TASK_YAML" "$FILE_PATH" "$SHOGUN_ROOT" 2>/dev/null || echo "ERROR")

case "$EDITABLE_RESULT" in
    MATCH)
        exit 0
        ;;
    MISSING)
        echo "WARNING: editable_files not set in task YAML for ${AGENT_ID}" >&2
        exit 0
        ;;
    ERROR)
        echo "WARNING: Failed to parse editable_files for ${AGENT_ID}" >&2
        exit 0
        ;;
    NO_MATCH)
        LOG_SCRIPT="${__IR1_LOG_SCRIPT:-${SHOGUN_ROOT}/scripts/log_violation.sh}"
        bash "$LOG_SCRIPT" IR-1 "$AGENT_ID" "IR-1: ${AGENT_ID} editing file not in editable_files whitelist: ${FILE_PATH}"
        echo "IR-1 VIOLATION: ${AGENT_ID} edited ${FILE_PATH} (not in editable_files whitelist)" >&2
        exit 0
        ;;
esac
