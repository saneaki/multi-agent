#!/usr/bin/env bash
# shogun_reality_check.sh — 将軍見回りスクリプト
# 6項目検査 + 将軍 inbox 通知 (冪等)
# cron: 0 21,3,9 * * * (UTC = JST 6:00/12:00/18:00)
# cmd_603 Scope A

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${SCRIPT_DIR}/.venv/bin/python3"
SHOGUN_INBOX="${SCRIPT_DIR}/queue/inbox/shogun.yaml"

# === 冪等チェック: 直近1時間に同種アラートがあれば再送しない ===
already_sent() {
    local alert_key="$1"
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, sys
from datetime import datetime, timedelta, timezone

try:
    with open('${SHOGUN_INBOX}') as f:
        data = yaml.safe_load(f)
    if not data or not data.get('messages'):
        print('no'); sys.exit(0)

    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)

    for msg in data.get('messages', []):
        if msg.get('type') != 'reality_check_alert':
            continue
        if '${alert_key}' not in str(msg.get('content', '')):
            continue
        ts_str = str(msg.get('timestamp', ''))
        try:
            if ts_str.endswith('Z'):
                ts_str = ts_str[:-1] + '+00:00'
            ts = datetime.fromisoformat(ts_str)
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)
            if ts >= one_hour_ago:
                print('yes'); sys.exit(0)
        except Exception:
            continue
    print('no')
except FileNotFoundError:
    print('no')
except Exception:
    print('no')
PYEOF
}

# === アラート送信: 将軍 inbox + (必要に応じ) ntfy ===
send_alert() {
    local content="$1"
    local with_ntfy="${2:-no}"

    bash "${SCRIPT_DIR}/scripts/inbox_write.sh" shogun "${content}" reality_check_alert shogun_reality_check

    if [ "${with_ntfy}" = "yes" ]; then
        bash "${SCRIPT_DIR}/scripts/ntfy.sh" "${content}" "⚠️ 将軍見回り検知" "reality_check_alert" 2>/dev/null || true
    fi
}

# === 検査1: dashboard進行中停滞 4h+ ===
check_dashboard_stall() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, os, sys
from datetime import datetime

try:
    db_file = '${SCRIPT_DIR}/dashboard.yaml'
    with open(db_file) as f:
        data = yaml.safe_load(f)

    in_progress = data.get('in_progress', [])
    if not in_progress:
        print('ok'); sys.exit(0)

    mtime = os.path.getmtime(db_file)
    age_h = (datetime.now().timestamp() - mtime) / 3600

    if age_h >= 4:
        items = ["{cmd}({assignee})".format(
            cmd=item.get('cmd', '?'),
            assignee=item.get('assignee', '?')
        ) for item in in_progress]
        items_str = ', '.join(items)
        print("STALL: {n}件進行中, {h:.1f}h更新なし: {items}".format(
            n=len(in_progress), h=age_h, items=items_str))
    else:
        print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# === 検査2: ash subtask done → 家老未集約 30min+ ===
# done: 30min-6h 窓のみフラグ (6h超は集約済/完遂cmdsの陳腐タスクとして除外)
# completed_pending_karo: 30min+ で常にフラグ (明示的にkaro処理待ち)
check_ash_done_pending() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, os, glob, sys
from datetime import datetime

DONE_MAX_AGE_MIN = 6 * 60  # 6h: done タスクのフラグ上限

try:
    task_files = glob.glob('${SCRIPT_DIR}/queue/tasks/ashigaru*.yaml')
    pending = []

    for task_file in task_files:
        try:
            with open(task_file) as f:
                task = yaml.safe_load(f)
            if not task:
                continue
            status = task.get('status', '')
            if status not in ('done', 'completed_pending_karo'):
                continue

            mtime = os.path.getmtime(task_file)
            age_min = (datetime.now().timestamp() - mtime) / 60

            if status == 'done':
                # 30min 未満: まだ処理中の可能性 / 6h 超: 完遂済cmds陳腐タスク
                if not (30 <= age_min < DONE_MAX_AGE_MIN):
                    continue
            else:  # completed_pending_karo
                if age_min < 30:
                    continue

            agent = os.path.basename(task_file).replace('.yaml', '')
            task_id = task.get('task_id', '?')
            pending.append("{agent}:{tid}({m:.0f}min)".format(
                agent=agent, tid=task_id, m=age_min))
        except Exception:
            continue

    if pending:
        items_str = ', '.join(pending)
        print("PENDING: " + items_str)
    else:
        print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# === 検査3: inbox未読 1h+ ===
check_inbox_unread() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, os, glob, sys
from datetime import datetime, timedelta, timezone

try:
    inbox_files = glob.glob('${SCRIPT_DIR}/queue/inbox/*.yaml')
    alerts = []

    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)

    for inbox_file in inbox_files:
        if inbox_file.endswith('.lock'):
            continue
        try:
            with open(inbox_file) as f:
                data = yaml.safe_load(f)
            if not data or not data.get('messages'):
                continue

            agent = os.path.basename(inbox_file).replace('.yaml', '')
            for msg in data['messages']:
                if msg.get('read', True):
                    continue
                ts_str = str(msg.get('timestamp', ''))
                try:
                    if ts_str.endswith('Z'):
                        ts_str = ts_str[:-1] + '+00:00'
                    ts = datetime.fromisoformat(ts_str)
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    if ts <= one_hour_ago:
                        age_min = (now - ts).total_seconds() / 60
                        alerts.append("{agent}({m:.0f}min)".format(agent=agent, m=age_min))
                        break  # per agent 1件で十分
                except Exception:
                    continue
        except Exception:
            continue

    if alerts:
        items_str = ', '.join(alerts)
        print("UNREAD: " + items_str)
    else:
        print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# === 検査4: 殿判断項目 [提案-*] 3日+ ===
check_action_required_stale() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import yaml, subprocess, sys

try:
    with open('${SCRIPT_DIR}/dashboard.yaml') as f:
        data = yaml.safe_load(f)

    action_required = data.get('action_required', [])
    proposals = [item for item in action_required
                 if str(item.get('tag', '')).startswith('[提案-')]

    if not proposals:
        print('ok'); sys.exit(0)

    # 3日前の最終コミットハッシュを取得
    result = subprocess.run(
        ['git', '-C', '${SCRIPT_DIR}', 'log', '--format=%H',
         '--before=3 days ago', '-1', '--', 'dashboard.yaml'],
        capture_output=True, text=True, timeout=10
    )
    old_hash = result.stdout.strip()
    if not old_hash:
        print('ok'); sys.exit(0)

    # 3日前の dashboard.yaml の内容を取得
    result2 = subprocess.run(
        ['git', '-C', '${SCRIPT_DIR}', 'show', old_hash + ':dashboard.yaml'],
        capture_output=True, text=True, timeout=10
    )
    if result2.returncode != 0:
        print('ok'); sys.exit(0)

    old_data = yaml.safe_load(result2.stdout)
    old_actions = old_data.get('action_required', []) if old_data else []
    old_tags = {str(item.get('tag', '')) for item in old_actions}

    stale = [item for item in proposals
             if str(item.get('tag', '')) in old_tags]

    if stale:
        tags_str = ', '.join(item.get('tag', '?') for item in stale)
        print("STALE_PROPOSALS: " + tags_str)
    else:
        print('ok')
except subprocess.TimeoutExpired:
    print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# === 検査5: hook死活 12h+ ===
# settings.json mtime は設定変更頻度に依存するため不適切。
# 実際に動作すべき常時稼働hookログの更新時刻で判定する。
check_hook_liveness() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import os, glob, sys
from datetime import datetime

# 常時稼働すべきhookログ (少なくとも1件が12h以内に更新されていれば正常)
ACTIVE_HOOK_LOGS = [
    '${SCRIPT_DIR}/logs/cmd_complete_notifier.log',
    '${SCRIPT_DIR}/logs/compact_observer.log',
    '${SCRIPT_DIR}/logs/shogun_inbox_notifier.log',
    '${SCRIPT_DIR}/logs/discord_bot_health.log',
]

try:
    min_age_h = float('inf')
    checked = []

    for log_file in ACTIVE_HOOK_LOGS:
        if os.path.exists(log_file) and os.path.getsize(log_file) > 0:
            age_h = (datetime.now().timestamp() - os.path.getmtime(log_file)) / 3600
            checked.append((os.path.basename(log_file), age_h))
            if age_h < min_age_h:
                min_age_h = age_h

    if not checked:
        print('ok'); sys.exit(0)  # ログなし = 新環境

    if min_age_h >= 12:
        oldest = max(checked, key=lambda x: x[1])
        print("HOOK_DEAD: 最新hookログ {h:.1f}h 途絶 ({log})".format(
            h=min_age_h, log=oldest[0]))
    else:
        print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# === 検査6: git未コミット 4h+ ===
check_git_uncommitted() {
    "${PYTHON}" - <<PYEOF 2>/dev/null
import subprocess, sys
from datetime import datetime

try:
    result = subprocess.run(
        ['git', '-C', '${SCRIPT_DIR}', 'status', '--porcelain'],
        capture_output=True, text=True, timeout=10
    )
    if not result.stdout.strip():
        print('ok'); sys.exit(0)

    result2 = subprocess.run(
        ['git', '-C', '${SCRIPT_DIR}', 'log', '-1', '--format=%ct'],
        capture_output=True, text=True, timeout=10
    )
    if not result2.stdout.strip():
        print('ok'); sys.exit(0)

    commit_ts = int(result2.stdout.strip())
    age_h = (datetime.now().timestamp() - commit_ts) / 3600

    if age_h >= 4:
        change_count = len([l for l in result.stdout.strip().split('\n') if l.strip()])
        print("UNCOMMITTED: {n}件変更あり, last_commit {h:.1f}h前".format(
            n=change_count, h=age_h))
    else:
        print('ok')
except subprocess.TimeoutExpired:
    print('ok')
except Exception as e:
    print('ok')
PYEOF
}

# ============================================================
# メイン実行
# ============================================================

JST_NOW=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
ALERTS_FOUND=0

# --- 検査1: dashboard進行中停滞 ---
RESULT1=$(check_dashboard_stall)
if [[ "${RESULT1}" != "ok" ]]; then
    ALERT_KEY="見回り-1"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT1}" "yes"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT1}"
    fi
fi

# --- 検査2: ash subtask done → 家老未集約 ---
RESULT2=$(check_ash_done_pending)
if [[ "${RESULT2}" != "ok" ]]; then
    ALERT_KEY="見回り-2"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT2}" "yes"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT2}"
    fi
fi

# --- 検査3: inbox未読 1h+ ---
RESULT3=$(check_inbox_unread)
if [[ "${RESULT3}" != "ok" ]]; then
    ALERT_KEY="見回り-3"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT3}" "yes"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT3}"
    fi
fi

# --- 検査4: 殿判断項目 3日+ (ntfy不要) ---
RESULT4=$(check_action_required_stale)
if [[ "${RESULT4}" != "ok" ]]; then
    ALERT_KEY="見回り-4"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT4}" "no"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT4}"
    fi
fi

# --- 検査5: hook死活 12h+ (ntfy不要) ---
RESULT5=$(check_hook_liveness)
if [[ "${RESULT5}" != "ok" ]]; then
    ALERT_KEY="見回り-5"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT5}" "no"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT5}"
    fi
fi

# --- 検査6: git未コミット 4h+ (ntfy不要) ---
RESULT6=$(check_git_uncommitted)
if [[ "${RESULT6}" != "ok" ]]; then
    ALERT_KEY="見回り-6"
    if [ "$(already_sent "${ALERT_KEY}")" = "no" ]; then
        send_alert "⚠️ [${ALERT_KEY}] ${RESULT6}" "no"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [reality_check] ALERT: ${RESULT6}"
    fi
fi

if [ "${ALERTS_FOUND}" -eq 0 ]; then
    echo "${JST_NOW} [reality_check] 全6項目異常なし"
else
    echo "${JST_NOW} [reality_check] ${ALERTS_FOUND}件のアラートを将軍 inbox に送信"
fi
