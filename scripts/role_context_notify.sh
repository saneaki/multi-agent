#!/usr/bin/env bash
# role_context_notify.sh — Role別コンテキスト使用率監視・通知スクリプト
#
# Usage:
#   bash scripts/role_context_notify.sh <agent_id>
#
# 仕様:
#   - counterファイル: ~/.claude/tool_call_counter/<agent_id>.json
#   - context使用率 > 80% のときのみ判定
#   - C1-C4 充足時のみ compact_suggestion を inbox_write で投函
#   - 冪等性: 直近1時間に同種メッセージ(type=compact_suggestion, from=role_context_notify)があれば再送しない
#   - counterファイルがない場合は graceful exit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$SCRIPT_DIR/.venv/bin/python3"

AGENT_ID="${1:-}"
if [ -z "$AGENT_ID" ]; then
    echo "Usage: role_context_notify.sh <agent_id>" >&2
    exit 2
fi

case "$AGENT_ID" in
    karo|gunshi|ashigaru1|ashigaru2|ashigaru3|ashigaru4|ashigaru5|ashigaru6|ashigaru7) ;;
    shogun)
        # shogunは専用スクリプト(shogun_context_notify.sh)を継続利用
        exit 0
        ;;
    *)
        echo "Unsupported agent_id: $AGENT_ID" >&2
        exit 2
        ;;
esac

COUNTER_FILE="${HOME}/.claude/tool_call_counter/${AGENT_ID}.json"
INBOX_YAML="${SCRIPT_DIR}/queue/inbox/${AGENT_ID}.yaml"
TASK_YAML="${SCRIPT_DIR}/queue/tasks/${AGENT_ID}.yaml"
TASKS_DIR="${SCRIPT_DIR}/queue/tasks"
SHOGUN_TO_KARO="${SCRIPT_DIR}/queue/shogun_to_karo.yaml"
THRESHOLD=80

# counterファイルが存在しない場合はgraceful exit
if [ ! -f "$COUNTER_FILE" ]; then
    exit 0
fi

if [ ! -x "$PYTHON" ]; then
    PYTHON="python3"
fi

# context使用率取得 (context_pct / usage_pct / percent)
CONTEXT_PCT=$("$PYTHON" -c "
import json
try:
    with open('$COUNTER_FILE') as f:
        data = json.load(f)
    pct = data.get('context_pct') or data.get('usage_pct') or data.get('percent') or 0
    print(int(float(pct)))
except Exception:
    print(0)
" 2>/dev/null)
CONTEXT_PCT="${CONTEXT_PCT:-0}"

if [ "$CONTEXT_PCT" -le "$THRESHOLD" ]; then
    exit 0
fi

# C1: inbox unread = 0
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

if [ "${UNREAD_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    exit 0
fi

# C2: task status idle/done/completed
if [ ! -f "$TASK_YAML" ]; then
    exit 0
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

case "$TASK_STATUS" in
    idle|done|completed) ;;
    *) exit 0 ;;
esac

# C3: dispatch_debt=0 (karo only)
if [ "$AGENT_ID" = "karo" ]; then
    DEBT_COUNT=$("$PYTHON" <<PYEOF 2>/dev/null || echo "0"
import glob
import os
import yaml

debt = 0
for fpath in glob.glob(os.path.join('$TASKS_DIR', '*.yaml')):
    try:
        with open(fpath, encoding='utf-8', errors='replace') as f:
            d = yaml.safe_load(f) or {}
    except Exception:
        continue

    if d.get('status') != 'blocked':
        continue

    blocked_by = d.get('blocked_by', [])
    if not blocked_by:
        continue
    if isinstance(blocked_by, str):
        blocked_by = [blocked_by]

    all_done = True
    for dep_id in blocked_by:
        dep_file = os.path.join('$TASKS_DIR', f'{dep_id}.yaml')
        if not os.path.isfile(dep_file):
            all_done = False
            break
        try:
            with open(dep_file, encoding='utf-8', errors='replace') as f2:
                dep = yaml.safe_load(f2) or {}
        except Exception:
            all_done = False
            break
        if dep.get('status') not in ('done', 'completed', 'idle'):
            all_done = False
            break

    if all_done:
        debt += 1

print(debt)
PYEOF
    )

    if [ "${DEBT_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        exit 0
    fi
fi

# C4: no preserve_across_stages cmd in progress
if [ -f "$SHOGUN_TO_KARO" ]; then
    PRESERVE_COUNT=$("$PYTHON" <<PYEOF 2>/dev/null || echo "0"
import re

try:
    with open('$SHOGUN_TO_KARO', encoding='utf-8', errors='replace') as f:
        content = f.read()
except Exception:
    print(0)
    raise SystemExit(0)

blocks = re.split(r'(?m)^(?=- (?:cmd_id|id): cmd_\\d+)', content)
preserve = 0

for block in blocks:
    m = re.match(r'- (?:cmd_id|id): (cmd_\\d+)', block)
    if not m:
        continue
    status_m = re.search(r'(?m)^  status:\\s*["\\']?([A-Za-z_]+)["\\']?', block)
    if not status_m or status_m.group(1) != 'in_progress':
        continue
    policy_m = re.search(r'(?m)^  context_policy:\\s*["\\']?([A-Za-z_]+)["\\']?', block)
    policy = policy_m.group(1) if policy_m else 'clear_between'
    if policy == 'preserve_across_stages':
        preserve += 1

print(preserve)
PYEOF
    )

    if [ "${PRESERVE_COUNT:-0}" -gt 0 ] 2>/dev/null; then
        exit 0
    fi
fi

# 冪等性チェック: 直近1時間で同種メッセージ済みなら再送しない
ALREADY_SENT=$("$PYTHON" -c "
import yaml
from datetime import datetime, timedelta, timezone

try:
    with open('$INBOX_YAML') as f:
        data = yaml.safe_load(f) or {}
except FileNotFoundError:
    print('no')
    raise SystemExit(0)
except Exception:
    print('no')
    raise SystemExit(0)

msgs = data.get('messages', []) if isinstance(data, dict) else []
now = datetime.now(timezone.utc)
one_hour_ago = now - timedelta(hours=1)

for msg in msgs:
    if msg.get('type') != 'compact_suggestion':
        continue
    if msg.get('from') != 'role_context_notify':
        continue
    ts_raw = str(msg.get('timestamp', ''))
    if not ts_raw:
        continue
    try:
        ts = datetime.fromisoformat(ts_raw.replace('Z', '+00:00'))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
    except Exception:
        continue
    if ts >= one_hour_ago:
        print('yes')
        break
else:
    print('no')
" 2>/dev/null)

if [ "$ALREADY_SENT" = "yes" ]; then
    exit 0
fi

CONTENT="🧹 context ${CONTEXT_PCT}%（閾値 ${THRESHOLD}%）到達。/clear可能条件(C1-C4)充足につき clear タイミング提案。"
bash "${SCRIPT_DIR}/scripts/inbox_write.sh" "$AGENT_ID" "$CONTENT" compact_suggestion role_context_notify
