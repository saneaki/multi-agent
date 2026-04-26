#!/usr/bin/env bash
# shogun_context_notify.sh — 将軍コンテキスト使用率監視・通知スクリプト
#
# 仕様:
#   - context使用率 > 70% AND shogun_to_karo.yaml にin_progressなし
#     → queue/inbox/shogun.yaml に type=compact_suggestion を1件投入
#   - 冪等性: 直近1時間内に同種メッセージがあれば再送しない
#   - 自動/clearは絶対しない(殿承認前提)
#   - counterファイルが存在しない場合はgraceful exit(エラーなし)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

COUNTER_FILE="${HOME}/.claude/tool_call_counter/shogun.json"
SHOGUN_INBOX="${SCRIPT_DIR}/queue/inbox/shogun.yaml"
CMD_QUEUE="${SCRIPT_DIR}/queue/shogun_to_karo.yaml"
THRESHOLD=70

# counterファイルが存在しない場合はgraceful exit
if [ ! -f "$COUNTER_FILE" ]; then
    exit 0
fi

# context使用率を取得 (context_pct / usage_pct / percent フィールドを順に試みる)
CONTEXT_PCT=$("${SCRIPT_DIR}/.venv/bin/python3" -c "
import json, sys
try:
    with open('$COUNTER_FILE') as f:
        data = json.load(f)
    pct = data.get('context_pct') or data.get('usage_pct') or data.get('percent') or 0
    print(int(float(pct)))
except Exception:
    print(0)
" 2>/dev/null)

CONTEXT_PCT="${CONTEXT_PCT:-0}"

# 閾値以下なら何もしない
if [ "$CONTEXT_PCT" -le "$THRESHOLD" ]; then
    exit 0
fi

# 鮮度チェック: last_updated が 30分超古い場合はスキップ (/clear後のstaleデータ防止)
STALE=$("${SCRIPT_DIR}/.venv/bin/python3" -c "
import json
from datetime import datetime, timedelta, timezone
try:
    with open('$COUNTER_FILE') as f:
        data = json.load(f)
    last = data.get('last_updated', '')
    if not last:
        print('yes')
    else:
        ts = datetime.fromisoformat(last)
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        age = (datetime.now(timezone.utc) - ts).total_seconds()
        print('yes' if age > 1800 else 'no')
except Exception:
    print('no')
" 2>/dev/null)

if [ "${STALE:-no}" = "yes" ]; then
    exit 0
fi

# shogun_to_karo.yaml にin_progress cmdがあるか確認
HAS_IN_PROGRESS=$("${SCRIPT_DIR}/.venv/bin/python3" -c "
import yaml, sys
try:
    with open('$CMD_QUEUE') as f:
        data = yaml.safe_load(f)
    if not data:
        print('no')
        sys.exit(0)
    cmds = data if isinstance(data, list) else data.get('commands', [])
    if not isinstance(cmds, list):
        print('no')
        sys.exit(0)
    for cmd in cmds:
        if isinstance(cmd, dict) and cmd.get('status') == 'in_progress':
            print('yes')
            sys.exit(0)
    print('no')
except Exception:
    print('no')
" 2>/dev/null)

# in_progress cmdがあれば通知しない(殿が作業中)
if [ "${HAS_IN_PROGRESS}" = "yes" ]; then
    exit 0
fi

# 冪等性チェック: 直近1時間にcompact_suggestionがあれば再送しない
ALREADY_SENT=$("${SCRIPT_DIR}/.venv/bin/python3" -c "
import yaml, sys
from datetime import datetime, timedelta, timezone

try:
    with open('$SHOGUN_INBOX') as f:
        data = yaml.safe_load(f)
    if not data or not data.get('messages'):
        print('no')
        sys.exit(0)

    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)

    for msg in data.get('messages', []):
        if msg.get('type') != 'compact_suggestion':
            continue
        ts_str = str(msg.get('timestamp', ''))
        try:
            if ts_str.endswith('Z'):
                ts_str = ts_str[:-1] + '+00:00'
            ts = datetime.fromisoformat(ts_str)
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if ts >= one_hour_ago:
                print('yes')
                sys.exit(0)
        except Exception:
            continue
    print('no')
except FileNotFoundError:
    print('no')
except Exception:
    print('no')
" 2>/dev/null)

if [ "${ALREADY_SENT}" = "yes" ]; then
    exit 0
fi

# compact_suggestion メッセージを投入(提案型のみ — 自動/clear禁止)
CONTENT="🧹 殿、/clear のタイミングかと存じます。context ${CONTEXT_PCT}% + cmd idle"
bash "${SCRIPT_DIR}/scripts/inbox_write.sh" shogun "${CONTENT}" compact_suggestion shogun_context_notify
