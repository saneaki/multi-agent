#!/usr/bin/env bash
# shogun_in_progress_monitor.sh — 進行中乖離 1h 監視 (5パターン検出)
# cmd_638 Scope A
#
# 検出対象:
#   P1: shogun_to_karo.yaml に status=pending かつ inbox/karo.yaml に shogun→karo
#       read=True 送信あり、かつ task YAML 該当 cmd_id 不在 → 家老 dispatch 漏れ
#   P2: dashboard.yaml.in_progress 空 + task YAML status=assigned/in_progress 存在
#       → dashboard 鮮度乖離
#   P3: task YAML status=assigned/in_progress + promoted_at 経過時間 > 60分
#       → ash 滞留 (tmux pane idle 相当)
#   P4: dashboard last_updated > 90分前 → 進行中 stale
#   P5: shogun inbox に未処理 action_required > 30分 → 殿手作業滞留
#
# 重複 alert 抑制: 1h 内同種は再送付しない (alert_key で識別)
#
# Usage:
#   bash scripts/shogun_in_progress_monitor.sh           # 本番モード (inbox + ntfy 投函)
#   bash scripts/shogun_in_progress_monitor.sh --dry-run # 検出結果のみ stdout 表示

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCRIPT_DIR
PYTHON="${SCRIPT_DIR}/.venv/bin/python3"
SHOGUN_INBOX="${SCRIPT_DIR}/queue/inbox/shogun.yaml"

DRY_RUN="no"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN="yes"; shift ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

JST_NOW=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')
ALERTS_FOUND=0

# 1h 内同 key で送信済みかチェック (冪等)
already_sent() {
    local alert_key="$1"
    "${PYTHON}" - "${SHOGUN_INBOX}" "${alert_key}" <<'PYEOF' 2>/dev/null
import yaml, sys
from datetime import datetime, timedelta, timezone

inbox_path = sys.argv[1]
alert_key = sys.argv[2]

try:
    with open(inbox_path) as f:
        data = yaml.safe_load(f) or {}
    msgs = data.get('messages') or []
    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)
    for m in msgs:
        if m.get('type') != 'in_progress_monitor_alert':
            continue
        if alert_key not in str(m.get('content', '')):
            continue
        ts = str(m.get('timestamp', ''))
        try:
            if ts.endswith('Z'):
                ts = ts[:-1] + '+00:00'
            t = datetime.fromisoformat(ts)
            if t.tzinfo is None:
                t = t.replace(tzinfo=timezone.utc)
            if t >= one_hour_ago:
                print('yes'); sys.exit(0)
        except ValueError:
            continue
    print('no')
except FileNotFoundError:
    print('no')
except Exception:
    print('no')
PYEOF
}

send_alert() {
    local content="$1"
    bash "${SCRIPT_DIR}/scripts/inbox_write.sh" \
        shogun "${content}" in_progress_monitor_alert shogun_in_progress_monitor
    bash "${SCRIPT_DIR}/scripts/ntfy.sh" \
        "${content}" "⚠️ 進行中見回り検知" "見回り-IP" 2>/dev/null || true
}

handle_alert() {
    local key="$1"
    local message="$2"
    local full="⚠️ [${key}] ${message}"

    if [ "${DRY_RUN}" = "yes" ]; then
        echo "[DRY-RUN] DETECT [${key}]: ${message}"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        return
    fi

    if [ "$(already_sent "${key}")" = "no" ]; then
        send_alert "${full}"
        ALERTS_FOUND=$((ALERTS_FOUND + 1))
        echo "${JST_NOW} [in_progress_monitor] ALERT [${key}]: ${message}"
    fi
}

# ===== 5パターン検出ロジック (Python 一括実行) =====
RESULTS=$("${PYTHON}" - <<'PYEOF'
import os, re, glob, yaml
from datetime import datetime, timedelta, timezone

ROOT = os.environ['SCRIPT_DIR']
JST = timezone(timedelta(hours=9))
RESULTS = []

def out(key, msg):
    RESULTS.append(f"{key}|{msg}")

def parse_ts(ts_str):
    """ISO timestamp → aware datetime (assume JST if naive)."""
    s = str(ts_str).strip()
    if s.endswith('Z'):
        s = s[:-1] + '+00:00'
    try:
        t = datetime.fromisoformat(s)
        if t.tzinfo is None:
            t = t.replace(tzinfo=JST)
        return t
    except (ValueError, TypeError):
        return None

def now_jst():
    return datetime.now(JST)

# ---------- Pattern 1: 家老 dispatch 漏れ ----------
def check_pattern_1():
    s2k_path = os.path.join(ROOT, 'queue/shogun_to_karo.yaml')
    if not os.path.exists(s2k_path):
        return

    # 全文 regex 抽出 (parser エラーに強い)
    content = open(s2k_path, encoding='utf-8', errors='replace').read()
    parts = re.split(r'^(?=- id: cmd_)', content, flags=re.MULTILINE)

    pending_cmds = []
    for part in parts:
        if not part.strip():
            continue
        m_id = re.search(r'^- id: (cmd_\d+)', part, re.MULTILINE)
        m_st = re.search(r'^  status: (\S+)', part, re.MULTILINE)
        if m_id and m_st:
            cmd_id = m_id.group(1)
            status = m_st.group(1).rstrip(',').strip("'\"")
            if status == 'pending':
                pending_cmds.append(cmd_id)
    if not pending_cmds:
        return

    # karo inbox: shogun→karo read=True 送信から cmd 抽出
    karo_inbox = os.path.join(ROOT, 'queue/inbox/karo.yaml')
    sent_cmds = set()
    if os.path.exists(karo_inbox):
        try:
            with open(karo_inbox) as f:
                data = yaml.safe_load(f) or {}
            for m in (data.get('messages') or []):
                if m.get('from') != 'shogun':
                    continue
                if not m.get('read', False):
                    continue
                for cmd in re.findall(r'cmd_\d+', str(m.get('content', ''))):
                    sent_cmds.add(cmd)
        except Exception:
            pass

    # 全 task YAML から cmd_ref / parent_cmd を収集
    task_cmds = set()
    for tf in glob.glob(os.path.join(ROOT, 'queue/tasks/*.yaml')):
        try:
            with open(tf) as f:
                td = yaml.safe_load(f) or {}
            for k in ('cmd_ref', 'parent_cmd', 'cmd_id'):
                v = td.get(k)
                if v:
                    task_cmds.add(str(v))
        except Exception:
            continue

    leak = [c for c in pending_cmds if c in sent_cmds and c not in task_cmds]
    if leak:
        out('P1-家老処理漏れ',
            f"shogun→karo 送信済み + task YAML 不在: {', '.join(leak[:5])}"
            + (f" (他{len(leak)-5}件)" if len(leak) > 5 else ""))

# ---------- Pattern 2: dashboard 鮮度乖離 ----------
def check_pattern_2():
    dash_path = os.path.join(ROOT, 'dashboard.yaml')
    if not os.path.exists(dash_path):
        return
    try:
        with open(dash_path) as f:
            d = yaml.safe_load(f) or {}
    except Exception:
        return
    in_progress = d.get('in_progress') or []

    # 「進行中」と判定される dashboard エントリの有無
    has_active_dash = False
    for item in in_progress:
        st = (item.get('status') or '').strip()
        # 完了/待機系を除外、それ以外は active 扱い
        if st and not any(k in st for k in ('完了', '待機', 'idle', '✅')):
            has_active_dash = True
            break

    # task YAML から実進行中を抽出 (ashigaru/gunshi)
    active_tasks = []
    pattern = os.path.join(ROOT, 'queue/tasks/*.yaml')
    for tf in glob.glob(pattern):
        name = os.path.basename(tf).replace('.yaml', '')
        if not (name.startswith('ashigaru') or name == 'gunshi'):
            continue
        try:
            with open(tf) as f:
                td = yaml.safe_load(f) or {}
            if td.get('status') in ('assigned', 'in_progress'):
                active_tasks.append(f"{name}:{td.get('task_id', '?')}")
        except Exception:
            continue

    if active_tasks and not has_active_dash:
        sample = ', '.join(active_tasks[:3])
        more = f" (他{len(active_tasks)-3}件)" if len(active_tasks) > 3 else ""
        out('P2-dashboard鮮度乖離',
            f"task active({len(active_tasks)}件)あり、dashboard 反映なし: {sample}{more}")

# ---------- Pattern 3: ash 滞留 ----------
def check_pattern_3():
    now = now_jst()
    stalls = []
    for tf in glob.glob(os.path.join(ROOT, 'queue/tasks/ashigaru*.yaml')):
        try:
            with open(tf) as f:
                td = yaml.safe_load(f) or {}
            if td.get('status') not in ('assigned', 'in_progress'):
                continue

            promoted = td.get('promoted_at') or td.get('created_at')
            t = parse_ts(promoted) if promoted else None
            if t:
                age_min = (now - t).total_seconds() / 60
            else:
                # fallback: file mtime
                age_min = (datetime.now().timestamp() - os.path.getmtime(tf)) / 60

            if age_min > 60:
                # mtime 経過時間も idle 補強指標として確認
                file_idle_min = (datetime.now().timestamp() - os.path.getmtime(tf)) / 60
                agent = os.path.basename(tf).replace('.yaml', '')
                tid = td.get('task_id', '?')
                # promoted_at > 60min かつ ファイル更新も > 30min なら滞留と判定
                if file_idle_min > 30:
                    stalls.append(f"{agent}:{tid}({age_min:.0f}min,idle={file_idle_min:.0f}min)")
        except Exception:
            continue

    if stalls:
        sample = ', '.join(stalls[:5])
        more = f" (他{len(stalls)-5}件)" if len(stalls) > 5 else ""
        out('P3-ash滞留', f"{len(stalls)}件 60min超: {sample}{more}")

# ---------- Pattern 4: 進行中 stale ----------
def check_pattern_4():
    dash_path = os.path.join(ROOT, 'dashboard.yaml')
    if not os.path.exists(dash_path):
        return
    try:
        with open(dash_path) as f:
            d = yaml.safe_load(f) or {}
    except Exception:
        return
    in_progress = d.get('in_progress') or []
    if not in_progress:
        return  # P2 が拾う

    last_updated = d.get('last_updated')
    age_min = None
    if last_updated:
        # "2026-05-02 18:20 JST" 形式
        s = str(last_updated).replace(' JST', '').strip()
        try:
            t = datetime.strptime(s, '%Y-%m-%d %H:%M').replace(tzinfo=JST)
            age_min = (now_jst() - t).total_seconds() / 60
        except ValueError:
            age_min = None
    if age_min is None:
        # fallback: file mtime
        age_min = (datetime.now().timestamp() - os.path.getmtime(dash_path)) / 60

    if age_min > 90:
        items = [f"{i.get('cmd', '?')}({i.get('assignee', '?')})"
                 for i in in_progress[:3]]
        out('P4-進行中stale',
            f"dashboard last_updated {age_min:.0f}min 前: {', '.join(items)}")

# ---------- Pattern 5: 殿手作業滞留 ----------
def check_pattern_5():
    shogun_inbox = os.path.join(ROOT, 'queue/inbox/shogun.yaml')
    if not os.path.exists(shogun_inbox):
        return
    try:
        with open(shogun_inbox) as f:
            d = yaml.safe_load(f) or {}
    except Exception:
        return
    msgs = d.get('messages') or []
    now = now_jst()
    unread_action = []

    for m in msgs:
        if m.get('read', False):
            continue
        mtype = m.get('type', '')
        # 殿の手作業を要する種別
        if mtype not in ('action_required', 'decision_required',
                         'reality_check_alert', 'in_progress_monitor_alert'):
            continue
        t = parse_ts(m.get('timestamp', ''))
        if t is None:
            continue
        # JST に揃える
        if t.tzinfo != JST:
            t = t.astimezone(JST)
        age_min = (now - t).total_seconds() / 60
        if age_min > 30:
            unread_action.append(f"{mtype}({age_min:.0f}min)")

    if unread_action:
        sample = ', '.join(unread_action[:3])
        more = f" (他{len(unread_action)-3}件)" if len(unread_action) > 3 else ""
        out('P5-殿手作業滞留',
            f"shogun inbox 未処理 {len(unread_action)}件: {sample}{more}")

check_pattern_1()
check_pattern_2()
check_pattern_3()
check_pattern_4()
check_pattern_5()

for r in RESULTS:
    print(r)
PYEOF
)

# 結果をハンドルする
if [ -n "${RESULTS}" ]; then
    while IFS='|' read -r key msg; do
        [ -z "${key}" ] && continue
        handle_alert "${key}" "${msg}"
    done <<< "${RESULTS}"
fi

if [ "${DRY_RUN}" = "yes" ]; then
    echo "${JST_NOW} [in_progress_monitor] DRY-RUN: ${ALERTS_FOUND}件検出"
elif [ "${ALERTS_FOUND}" -eq 0 ]; then
    echo "${JST_NOW} [in_progress_monitor] 全5パターン異常なし"
else
    echo "${JST_NOW} [in_progress_monitor] ${ALERTS_FOUND}件のアラートを将軍 inbox に送信"
fi

exit 0
