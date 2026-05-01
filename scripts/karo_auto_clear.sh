#!/usr/bin/env bash
# karo_auto_clear.sh - cron entrypoint for karo auto /clear when safely idle
#
# Usage:
#   bash scripts/karo_auto_clear.sh [--dry-run]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${ROOT_DIR}/.venv/bin/python3"
if [ ! -x "$PYTHON" ]; then
  PYTHON="python3"
fi

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

LOCK_FILE="/tmp/karo_auto_clear.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[$(bash "$ROOT_DIR/scripts/jst_now.sh" --yaml)] [karo_auto_clear] lock held -> skip (E3 guard)"
  exit 0
fi
echo "$$" > "$LOCK_FILE"

log() {
  echo "[$(bash "$ROOT_DIR/scripts/jst_now.sh" --yaml)] [karo_auto_clear] $*"
}

SETTINGS_YAML="$ROOT_DIR/config/settings.yaml"
INBOX_YAML="$ROOT_DIR/queue/inbox/karo.yaml"
TASKS_DIR="$ROOT_DIR/queue/tasks"

unread_count=$("$PYTHON" - <<PYEOF
import yaml
path = "$INBOX_YAML"
try:
    with open(path, encoding="utf-8") as f:
        d = yaml.safe_load(f) or {}
    msgs = d.get("messages", [])
    print(sum(1 for m in msgs if not m.get("read", True)))
except Exception:
    print(0)
PYEOF
)

active_count=$("$PYTHON" - <<PYEOF
import glob
import os
import yaml
tasks_dir = "$TASKS_DIR"
targets = sorted(glob.glob(os.path.join(tasks_dir, "ashigaru*.yaml")))
targets.append(os.path.join(tasks_dir, "gunshi.yaml"))
active = 0
for path in targets:
    if not os.path.isfile(path):
        continue
    try:
        with open(path, encoding="utf-8") as f:
            d = yaml.safe_load(f) or {}
        status = str(d.get("status", "")).strip().lower()
        if status in ("assigned", "in_progress"):
            active += 1
    except Exception:
        continue
print(active)
PYEOF
)

log "check: unread=${unread_count}, active=${active_count}, dry_run=${DRY_RUN}"

# E2 guard: avoid race right after task assignment writes.
RECENT_WRITE=$(find "$ROOT_DIR/queue/tasks" -name "ashigaru*.yaml" -mmin -1 2>/dev/null | head -1)
if [ -n "$RECENT_WRITE" ]; then
  log "task YAML written within 1min -> skip (E2 guard, file=$RECENT_WRITE)"
  exit 0
fi

if [ "$unread_count" -ne 0 ] || [ "$active_count" -ne 0 ]; then
  log "idle=false -> skip."
  exit 0
fi

# E1 guard: skip while compaction is in progress.
COMPACT_INFO=$(bash "$ROOT_DIR/scripts/compact_observer.sh" karo 2>/dev/null || true)
COMPACT_TRIGGER=$(echo "$COMPACT_INFO" | grep -oE 'TRIGGER=[a-z_]+' | cut -d= -f2 || echo "none")
COMPACT_LAST=$(echo "$COMPACT_INFO" | grep -oE 'LAST=[^ ]+' | cut -d= -f2 || echo "none")
if [ "$COMPACT_TRIGGER" = "pre_compact" ] && [ "$COMPACT_LAST" != "none" ]; then
  LAST_EPOCH=$(date -d "$COMPACT_LAST" +%s 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
  if [ "$ELAPSED" -lt 300 ]; then
    log "compaction in-progress (elapsed=${ELAPSED}s < 300s) -> skip (E1 guard)"
    exit 0
  fi
fi

if bash "$ROOT_DIR/scripts/safe_clear_check.sh" --agent-id karo >/tmp/karo_auto_clear_safe_check.log 2>&1; then
  log "safe_clear_check=PASS"
else
  log "safe_clear_check=FAIL -> skip."
  exit 0
fi

pane_line="$(tmux list-panes -t multiagent:0 -F '#{pane_index} #{@agent_id}' | awk '$2=="karo"{print $1; exit}')"
if [ -z "$pane_line" ]; then
  log "karo pane not found -> skip."
  exit 0
fi
pane_target="multiagent:0.${pane_line}"

PANE_DUMP=$(tmux capture-pane -p -t "$pane_target" 2>/dev/null | tail -5 || echo "")
if ! echo "$PANE_DUMP" | grep -qE '(│ >|^>|claude-code)'; then
  log "karo pane not at active prompt -> skip (E6 guard)"
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  log "dry-run: would send '/clear' to ${pane_target}."
  exit 0
fi

tmux send-keys -t "$pane_target" "/clear" C-m
log "sent '/clear' to ${pane_target}."
