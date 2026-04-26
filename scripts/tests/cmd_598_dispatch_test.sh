#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/ubuntu/shogun"
DASHBOARD="$ROOT/dashboard.yaml"
STATE_FILE="$ROOT/logs/gunshi_qc_dispatched_cmds.txt"
KARO_INBOX="$ROOT/queue/inbox/karo.yaml"
INBOX_SCRIPT="$ROOT/scripts/inbox_write.sh"

PYTHON_BIN="$ROOT/.venv/bin/python3"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="python3"
fi

TMP_DIR="$(mktemp -d)"
BACKUP_DASHBOARD="$TMP_DIR/dashboard.yaml.bak"
BACKUP_STATE="$TMP_DIR/gunshi_qc_dispatched_cmds.txt.bak"
BACKUP_KARO_INBOX="$TMP_DIR/karo.yaml.bak"

cleanup() {
  if [ -f "$BACKUP_DASHBOARD" ]; then
    cp "$BACKUP_DASHBOARD" "$DASHBOARD"
  fi
  if [ -f "$BACKUP_STATE" ]; then
    cp "$BACKUP_STATE" "$STATE_FILE"
  fi
  if [ -f "$BACKUP_KARO_INBOX" ]; then
    cp "$BACKUP_KARO_INBOX" "$KARO_INBOX"
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

cp "$DASHBOARD" "$BACKUP_DASHBOARD"
cp "$STATE_FILE" "$BACKUP_STATE"
cp "$KARO_INBOX" "$BACKUP_KARO_INBOX"

# fixture_setup
"$PYTHON_BIN" - "$DASHBOARD" <<'PYEOF'
import sys
import yaml

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

achievements = data.setdefault("achievements", {})
today = achievements.setdefault("today", [])
if not isinstance(today, list):
    today = []
    achievements["today"] = today

fixture = {
    "time": "19:00",
    "result": "✅ ends完了",
    "task": "cmd_t595完遂(ash): テスト fixture",
    "battlefield": "test",
}

def same_entry(item):
    if not isinstance(item, dict):
        return False
    return (
        str(item.get("time", "")) == fixture["time"]
        and str(item.get("result", "")) == fixture["result"]
        and str(item.get("task", "")) == fixture["task"]
        and str(item.get("battlefield", "")) == fixture["battlefield"]
    )

if not any(same_entry(item) for item in today):
    today.append(fixture)

with open(path, "w", encoding="utf-8") as f:
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
PYEOF

# state file から cmd_t595 を除去して未dispatch状態を再現
if [ -f "$STATE_FILE" ]; then
  grep -vxF 'cmd_t595' "$STATE_FILE" > "$TMP_DIR/state.filtered" || true
  cp "$TMP_DIR/state.filtered" "$STATE_FILE"
fi

echo "PASS: fixture_setup"

count_trigger_msgs() {
  "$PYTHON_BIN" - "$KARO_INBOX" <<'PYEOF'
import sys
import yaml

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
msgs = data.get("messages", [])
count = 0
for msg in msgs:
    if not isinstance(msg, dict):
        continue
    if str(msg.get("type", "")) != "cmd_complete_qc_trigger":
        continue
    content = str(msg.get("content", ""))
    sender = str(msg.get("from", ""))
    if "cmd_t595" in content and sender == "cmd_complete_notifier":
        count += 1
print(count)
PYEOF
}

run_dispatch_once() {
  SCRIPT_DIR="$ROOT" INBOX_SCRIPT="$INBOX_SCRIPT" "$PYTHON_BIN" - <<'PYEOF'
import os
import re
import subprocess
import sys

import yaml

script_dir = os.environ["SCRIPT_DIR"]
dashboard_yaml = os.path.join(script_dir, "dashboard.yaml")
state_file = os.path.join(script_dir, "logs/gunshi_qc_dispatched_cmds.txt")
gunshi_task_file = os.path.join(script_dir, "queue/tasks/gunshi.yaml")
inbox_script = os.environ["INBOX_SCRIPT"]

try:
    with open(dashboard_yaml, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f"[gunshi_dispatch] dashboard.yaml load failed: {e}", file=sys.stderr)
    sys.exit(0)

dispatched = set()
if os.path.exists(state_file):
    with open(state_file, encoding="utf-8") as f:
        dispatched = {line.strip() for line in f if line.strip()}

today_items = data.get("achievements", {}).get("today", [])
if not isinstance(today_items, list):
    today_items = []

for item in today_items:
    if not isinstance(item, dict):
        continue
    result = str(item.get("result", ""))
    task_text = str(item.get("task", ""))

    if "ends完了" not in result:
        continue
    m = re.search(r"(cmd_[A-Za-z0-9]+)完遂", task_text)
    if not m:
        continue
    cmd_id = m.group(1)

    if cmd_id in dispatched:
        continue

    gunshi_active = False
    if os.path.exists(gunshi_task_file):
        try:
            with open(gunshi_task_file, encoding="utf-8") as f:
                gunshi_task = yaml.safe_load(f) or {}
            if (
                gunshi_task.get("parent_cmd") == cmd_id
                and gunshi_task.get("status") in ("assigned", "in_progress")
            ):
                gunshi_active = True
        except Exception as e:
            print(f"[gunshi_dispatch] gunshi task read failed: {e}", file=sys.stderr)

    if gunshi_active:
        with open(state_file, "a", encoding="utf-8") as f:
            f.write(cmd_id + "\n")
        dispatched.add(cmd_id)
        continue

    msg = (
        f"{cmd_id} 完遂検知 (dashboard.yaml: ends完了)。"
        "gunshi QC dispatch 要否を確認し、未dispatchなら発令せよ (cmd_598 自動トリガー)。"
    )
    subprocess.run(
        ["bash", inbox_script, "karo", msg, "cmd_complete_qc_trigger", "cmd_complete_notifier"],
        check=False,
    )
    with open(state_file, "a", encoding="utf-8") as f:
        f.write(cmd_id + "\n")
    dispatched.add(cmd_id)
PYEOF
}

before_count="$(count_trigger_msgs)"
run_dispatch_once
after_first_count="$(count_trigger_msgs)"

if [ "$after_first_count" -ne $((before_count + 1)) ]; then
  echo "FAIL: dispatch did not fire exactly once (before=$before_count after_first=$after_first_count)" >&2
  exit 1
fi

if ! grep -qxF 'cmd_t595' "$STATE_FILE"; then
  echo "FAIL: cmd_t595 not persisted to state file after first run" >&2
  exit 1
fi

echo "PASS: dispatch fired (cmd_t595)"

run_dispatch_once
after_second_count="$(count_trigger_msgs)"
if [ "$after_second_count" -ne "$after_first_count" ]; then
  echo "FAIL: idempotent check failed (after_first=$after_first_count after_second=$after_second_count)" >&2
  exit 1
fi

echo "PASS: idempotent skip (2回目)"

echo "PASS: fixture_teardown"
