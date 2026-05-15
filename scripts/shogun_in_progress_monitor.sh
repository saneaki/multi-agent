#!/usr/bin/env bash
# shogun_in_progress_monitor.sh — 進行中乖離 1h 監視 (9パターン検出)
# cmd_638 Scope A + cmd_640 Scope B (P7) + cmd_641 Scope A (P8) + cmd_642 Scope A (P9)
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
#   P6: dashboard.md の「最終更新:」が 2h 以上前 → dashboard stale alert
#   P7: GHA daily-notion-sync が success でも upsert 0件 → Notion同期 silent failure
#   P8: tmux pane 末尾に interactive prompt → agent 凍結リスク
#   P9: dashboard.yaml action_required の高優先/提案タグが 24h+ 滞留
#       → daily 8:00 JST ntfy
#
# 重複 alert 抑制: 原則 1h 内同種は再送付しない (alert_key で識別)
#                  P9 は 24h 内同種を抑制
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
export DRY_RUN

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
    # cmd_644 Scope B: P9b also uses 24h dedup (P9c uses auto_cmd_log instead)
    dedup_hours = 24 if alert_key.startswith('P9') else 1
    cutoff = now - timedelta(hours=dedup_hours)
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
            if t >= cutoff:
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

    # D-1: ntfy 6h dedup (D-2: persist, D-3: auto-purge)
    local dedup_dir="${HOME}/.cache/shogun"
    local dedup_file="${dedup_dir}/ntfy_sent.txt"
    local dedup_key
    dedup_key=$(printf '%s' "${content}" | sha256sum | awk '{print $1}')
    local now_epoch
    now_epoch=$(date +%s)
    local cutoff_epoch=$(( now_epoch - 6 * 3600 ))

    mkdir -p "${dedup_dir}"
    # D-3: purge entries older than 6h
    if [[ -f "${dedup_file}" ]]; then
        awk -F'\t' -v c="${cutoff_epoch}" '$1+0 > c' "${dedup_file}" > "${dedup_file}.tmp" \
            && mv "${dedup_file}.tmp" "${dedup_file}" || true
    fi

    # D-1/D-2: skip notify if key was sent within 6h; persist on send
    if ! grep -qF "${dedup_key}" "${dedup_file}" 2>/dev/null; then
        bash "${SCRIPT_DIR}/scripts/notify.sh" \
            "${content}" "⚠️ 進行中見回り検知" "見回り-IP" 2>/dev/null || true
        printf '%s\t%s\n' "${now_epoch}" "${dedup_key}" >> "${dedup_file}"
    fi
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

# ===== 9パターン検出ロジック (Python 一括実行) =====
RESULTS=$("${PYTHON}" - <<'PYEOF'
import os, re, glob, yaml, json, subprocess, hashlib
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

# ===== cmd_644 Scope B: Auto-Remediation helpers =====
DRY_RUN_FLAG = (os.environ.get('DRY_RUN') == 'yes')

def auto_cmd_log_today_count(pattern):
    """Count today's auto-cmd dispatches for a pattern (B-1 rate limit)."""
    log_path = os.path.join(ROOT, 'queue/auto_cmd_log.yaml')
    if not os.path.exists(log_path):
        return 0
    try:
        with open(log_path) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return 0
    entries = data.get('auto_cmds') or []
    today = now_jst().date()
    count = 0
    for e in entries:
        if not isinstance(e, dict) or e.get('pattern') != pattern:
            continue
        ts = parse_ts(e.get('dispatched_at') or '')
        if ts and ts.astimezone(JST).date() == today:
            count += 1
    return count

def auto_cmd_log_within_hours(pattern, key, hours):
    """Check if (pattern,key) was logged within the last N hours (B-2 P9c dedup)."""
    log_path = os.path.join(ROOT, 'queue/auto_cmd_log.yaml')
    if not os.path.exists(log_path):
        return False
    try:
        with open(log_path) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        return False
    entries = data.get('auto_cmds') or []
    cutoff = now_jst() - timedelta(hours=hours)
    for e in entries:
        if not isinstance(e, dict):
            continue
        if e.get('pattern') != pattern:
            continue
        if (e.get('key') or '') != key:
            continue
        ts = parse_ts(e.get('dispatched_at') or '')
        if ts and ts.astimezone(JST) >= cutoff:
            return True
    return False

def has_pending_auto_cmd(pattern, key):
    """Check shogun_to_karo.yaml for an existing pending auto cmd matching (pattern,key)."""
    s2k = os.path.join(ROOT, 'queue/shogun_to_karo.yaml')
    if not os.path.exists(s2k):
        return False
    try:
        content = open(s2k, encoding='utf-8', errors='replace').read()
    except Exception:
        return False
    parts = re.split(r'^(?=- id: cmd_)', content, flags=re.MULTILINE)
    for part in parts:
        if not part.strip() or 'auto: true' not in part:
            continue
        m_pat = re.search(r'^\s*auto_pattern:\s*(\S+)', part, re.MULTILINE)
        m_key = re.search(r'^\s*auto_key:\s*(\S+)', part, re.MULTILINE)
        m_st  = re.search(r'^\s*status:\s*(\S+)', part, re.MULTILINE)
        if not (m_pat and m_st):
            continue
        if m_pat.group(1).strip("'\"") != pattern:
            continue
        if m_st.group(1).strip("'\"") != 'pending':
            continue
        if key and (not m_key or m_key.group(1).strip("'\"") != key):
            continue
        return True
    return False

def append_auto_cmd_log(pattern, cmd_id, key, purpose):
    """Append entry to queue/auto_cmd_log.yaml."""
    log_path = os.path.join(ROOT, 'queue/auto_cmd_log.yaml')
    try:
        if os.path.exists(log_path):
            with open(log_path) as f:
                data = yaml.safe_load(f) or {}
        else:
            data = {}
    except Exception:
        data = {}
    if not isinstance(data.get('auto_cmds'), list):
        data['auto_cmds'] = []
    data['auto_cmds'].append({
        'cmd_id': cmd_id,
        'pattern': pattern,
        'key': key,
        'dispatched_at': now_jst().isoformat(timespec='seconds'),
        'purpose': purpose,
    })
    with open(log_path, 'w', encoding='utf-8') as f:
        yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False)

def append_auto_cmd_to_shogun_to_karo(cmd_id, pattern, key, purpose, command, priority='high'):
    """Append auto cmd block to queue/shogun_to_karo.yaml (text-mode append)."""
    s2k = os.path.join(ROOT, 'queue/shogun_to_karo.yaml')
    timestamp = now_jst().isoformat(timespec='seconds')
    purpose_esc = purpose.replace('"', '\\"')
    indented_cmd = '\n'.join('    ' + ln for ln in command.split('\n'))
    block = (
        f"- id: {cmd_id}\n"
        f"  auto: true\n"
        f"  auto_pattern: {pattern}\n"
        f"  auto_key: {key}\n"
        f"  timestamp: '{timestamp}'\n"
        f"  purpose: \"{purpose_esc}\"\n"
        f"  command: |\n"
        f"{indented_cmd}\n"
        f"  project: shogun\n"
        f"  priority: {priority}\n"
        f"  status: pending\n"
    )
    with open(s2k, 'a', encoding='utf-8') as f:
        f.write(block)

def trigger_auto_remediation(pattern, key, purpose, command, brief):
    """B-1/B-2: dispatch an auto cmd if rate/dedup checks allow. Returns True if dispatched."""
    # B-1 rate limit (P6: 3/day)
    if pattern == 'P6':
        today_count = auto_cmd_log_today_count('P6')
        if today_count >= 3:
            out(f'{pattern}-RATE_LIMITED',
                f"P6 auto cmd 1日3回制限到達 (today_count={today_count}, skip)")
            return False
    # B-2 P9c 168h dedup
    if pattern == 'P9c':
        if auto_cmd_log_within_hours('P9c', key, 168):
            return False
    # Pending duplicate guard (shared)
    if has_pending_auto_cmd(pattern, key):
        return False

    cmd_id = f"cmd_auto_{int(now_jst().timestamp())}_{pattern.lower()}"

    if DRY_RUN_FLAG:
        out(f'AUTO_CMD_{pattern}',
            f"[DRY-RUN] auto cmd dispatch candidate: id={cmd_id} key={key} purpose={purpose}")
        return True

    append_auto_cmd_to_shogun_to_karo(cmd_id, pattern, key, purpose, command)
    append_auto_cmd_log(pattern, cmd_id, key, purpose)
    msg = f"【Auto-Remediation】{cmd_id}: {brief} (pattern={pattern}, key={key})"
    try:
        subprocess.run(
            ['bash', os.path.join(ROOT, 'scripts/inbox_write.sh'),
             'karo', msg, 'task_assigned', 'system'],
            check=False, timeout=15)
    except Exception:
        pass
    out(f'AUTO_CMD_{pattern}',
        f"auto cmd dispatched: id={cmd_id} key={key} purpose={purpose}")
    return True

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

    last_updated = d.get('metadata', {}).get('last_updated')
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
            unread_action.append((mtype, age_min))

    if unread_action:
        # Phase B gate suppression: suppress if gate open AND all unread are monitor reminders
        try:
            import sys as _sys
            _sys.path.insert(0, os.path.join(ROOT, 'scripts/lib'))
            from gate_suppression import get_gate_status, should_suppress_p5
            gate_status = get_gate_status(ROOT)
            if should_suppress_p5(ROOT, gate_status):
                return  # suppressed: gate open, unread are monitor reminders only
        except Exception:
            pass  # suppression unavailable — proceed with alert
        sample = ', '.join(f"{mtype}({age_min:.0f}min)" for mtype, age_min in unread_action[:3])
        more = f" (他{len(unread_action)-3}件)" if len(unread_action) > 3 else ""
        out('P5-殿手作業滞留',
            f"shogun inbox 未処理 {len(unread_action)}件: {sample}{more}")

# ---------- Pattern 6: dashboard.md last_updated 鮮度 ----------
def check_pattern_6():
    """Phase B: fire P6 only when pending dashboard events exist (mtime-based).

    Full event ledger approach (Phase C). Current implementation:
    - Parse dashboard.md last_updated timestamp
    - Suppress if no task/report/dispatch files are newer than dashboard.md
    - Alert only when actual updates are pending (reduces false positives)

    Phase C boundary: full event-kind ledger with state tracking deferred.
    """
    dashboard_path = os.path.join(ROOT, 'dashboard.md')
    if not os.path.exists(dashboard_path):
        return

    last_updated_str = None
    with open(dashboard_path, encoding='utf-8') as f:
        for line in f:
            m = re.search(r'最終更新:\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+JST', line)
            if m:
                last_updated_str = m.group(1)
                break

    if not last_updated_str:
        return

    try:
        last_updated = datetime.strptime(last_updated_str, '%Y-%m-%d %H:%M').replace(tzinfo=JST)
    except ValueError:
        return

    elapsed_minutes = (now_jst() - last_updated).total_seconds() / 60

    if elapsed_minutes > 120:
        # Phase C: prefer event-ledger; fall back to Phase B mtime check
        has_events = True  # default to alert if suppression library missing
        ledger_summary = ""
        try:
            import sys as _sys
            _sys.path.insert(0, os.path.join(ROOT, 'scripts/lib'))
            from gate_suppression import (
                has_unresolved_dashboard_events,
                update_event_ledger,
                unresolved_events,
            )
            state = update_event_ledger(ROOT)
            pending = unresolved_events(state)
            has_events = len(pending) > 0
            if pending:
                # Build a compact summary like
                #   "task_status_change×3, report_appended×2, ..."
                counts = {}
                for ev in pending:
                    k = ev.get('event_kind') or 'unknown'
                    counts[k] = counts.get(k, 0) + 1
                ledger_summary = (
                    " event_ledger=" +
                    ", ".join(f"{k}×{v}" for k, v in counts.items())
                )
            _ = has_unresolved_dashboard_events  # reserved for direct use
        except Exception:
            has_events = True

        if not has_events:
            return  # no pending updates → suppress P6 (Phase C event ledger)

        out('P6-dashboard鮮度stale',
            f"dashboard.md 最終更新から {int(elapsed_minutes)}分経過 "
            f"(last_updated={last_updated_str} JST).{ledger_summary} "
            f"rotate 失敗 / karo 更新漏れを確認せよ。")

    # cmd_644 Scope B (B-1): 4h 超過で auto cmd 自動発令 (rate limit 1日3回)
    if elapsed_minutes > 240:
        trigger_auto_remediation(
            pattern='P6',
            key='dashboard_refresh',
            purpose=f"dashboard 鮮度低下 ({int(elapsed_minutes)}分) による自動 cmd",
            command=(
                "dashboard.md を再生成し last_updated を更新せよ。\n"
                "queue/dispatch_log.yaml + queue/tasks/*.yaml を集計し進行中欄を反映、\n"
                "rotation バグ・field 名不一致が無いか scripts/dashboard_validator.py で検証せよ。"
            ),
            brief=f"dashboard 4h+ stale ({int(elapsed_minutes)}min)",
        )

# ---------- Pattern 7: GHA daily-notion-sync upsert 0件 ----------
def check_pattern_7():
    """GHA daily-notion-sync が success でも upsert 件数 0件なら Notion 同期 silent failure を疑い alert"""
    try:
        run_info = subprocess.run(
            ['gh', 'run', 'list',
             '--workflow=daily-notion-sync.yml',
             '--repo=saneaki/obsidian',
             '--limit=1',
             '--json', 'status,conclusion,databaseId'],
            capture_output=True, text=True, timeout=30)
        if run_info.returncode != 0 or not run_info.stdout.strip():
            return
        runs = json.loads(run_info.stdout)
        if not runs:
            return
        run = runs[0]
        if run.get('status') != 'completed':
            return
        if run.get('conclusion') != 'success':
            return
        run_id = run.get('databaseId')
        if not run_id:
            return
        log_result = subprocess.run(
            ['gh', 'run', 'view', str(run_id),
             '--repo=saneaki/obsidian', '--log'],
            capture_output=True, text=True, timeout=60)
        if log_result.returncode != 0:
            return
        log = log_result.stdout
        upsert_count = log.count('[UPDATE]') + log.count('[CREATE]')
        if upsert_count == 0:
            out('P7-GHA-upsert-0件',
                f"daily-notion-sync success but 0 Notion entries updated "
                f"(run_id={run_id}). Notion同期 silent failure を疑え。")
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return
    except Exception:
        return

# ---------- Pattern 8: tmux interactive prompt 検出 ----------
def check_pattern_8():
    """Claude Code などの interactive prompt で agent pane が入力待ちになる状態を検出"""
    panes = [
        ('multiagent:0.0', 'karo'),
        ('multiagent:0.1', 'ashigaru1'),
        ('multiagent:0.2', 'ashigaru2'),
        ('multiagent:0.3', 'ashigaru3'),
        ('multiagent:0.4', 'ashigaru4'),
        ('multiagent:0.5', 'ashigaru5'),
        ('multiagent:0.6', 'ashigaru6'),
        ('multiagent:0.7', 'ashigaru7'),
        ('multiagent:0.8', 'gunshi'),
    ]

    yn_prompt_re = re.compile(r'(\[[Yy]/[Nn]\]|\([Yy]/[Nn]\)|\[[Yy]/n\]|\([Yy]/n\)|\[y/[Nn]\]|\(y/[Nn]\))')
    # question_re: ❯ カーソル待機や通常 ? を含む行と区別するため、Claude Code 固有フレーズに限定
    question_prompt_re = re.compile(r'(How is Claude doing|Do you want to proceed|Would you like to|Are you sure|Confirm\?)\s*$')

    for pane, fallback_agent in panes:
        try:
            # -S 0 でスクロールバックを除外し live state のみ取得
            captured = subprocess.run(
                ['tmux', 'capture-pane', '-t', pane, '-p', '-S', '0'],
                capture_output=True, text=True, timeout=5)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue
        except Exception:
            continue
        if captured.returncode != 0:
            continue

        lines = captured.stdout.splitlines()[-15:]
        # 末尾行のみで Y/n prompt を判定 (C-2)
        last_lines = lines[-3:] if lines else []
        last_text = '\n'.join(last_lines)
        numbered_streak = 0
        numbered_choice_detected = False
        for line in lines:
            if re.search(r'^\s*\d+\.', line):
                numbered_streak += 1
                if numbered_streak >= 2:
                    numbered_choice_detected = True
            else:
                numbered_streak = 0

        prompt_detected = (
            any(question_prompt_re.search(line) for line in last_lines)
            or bool(yn_prompt_re.search(last_text))
            or 'Choose option' in last_text
            or numbered_choice_detected
        )
        if not prompt_detected:
            continue

        agent = fallback_agent
        try:
            agent_info = subprocess.run(
                ['tmux', 'display-message', '-t', pane, '-p', '#{@agent_id}'],
                capture_output=True, text=True, timeout=5)
            candidate = agent_info.stdout.strip()
            if agent_info.returncode == 0 and candidate:
                agent = candidate
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        except Exception:
            pass

        pane_id = pane.replace(':', '_').replace('.', '_')
        out(f'P8_{pane_id}',
            f"interactive_prompt_detected: pane={pane} agent={agent}")

def check_pattern_9():
    """dashboard.yaml action_required の高優先・滞留 24h+ 項目を daily 8:00 に通知"""
    now = now_jst()

    # 時刻ゲート: 本番は 8:00 JST のみ。dry-run では検証のため常時実行。
    if os.environ.get('DRY_RUN') != 'yes' and now.hour != 8:
        return

    dash_path = os.path.join(ROOT, 'dashboard.yaml')
    if not os.path.exists(dash_path):
        return

    try:
        with open(dash_path) as f:
            d = yaml.safe_load(f) or {}
    except Exception:
        return

    items = d.get('action_required') or []
    if not isinstance(items, list):
        return

    for item in items:
        if not isinstance(item, dict):
            continue

        tag = str(item.get('tag') or '').strip()
        title = str(item.get('title') or '').strip()
        priority = str(item.get('priority') or '').strip().lower()
        created_at = parse_ts(item.get('created_at') or '')
        if created_at is None:
            continue

        target_tag = bool(re.search(r'\[(提案|action)-\d+\]', tag))
        high_priority = priority == 'high'
        if not (target_tag or high_priority):
            continue

        elapsed = now - created_at.astimezone(JST)
        hours = int(elapsed.total_seconds() // 3600)
        if hours < 24:
            continue

        days = hours // 24
        remaining_h = hours % 24
        tag_key = hashlib.sha256(f'{tag}:{title}'.encode('utf-8')).hexdigest()[:16]
        alert_key = f'P9_{tag_key}'
        out(alert_key,
            f"【要対応 滞留{days}日{remaining_h}時間】{tag} {title} "
            f"— dashboard 要対応欄を確認されたし")

        # cmd_644 Scope B (B-2): P9b 72h SLA — ntfy 直通 + shogun inbox 記録
        if hours >= 72:
            p9b_key = f'P9b_{tag_key}'
            out(p9b_key,
                f"🚨 SLA 72h超過: {tag} {title} (滞留{days}日{remaining_h}時間) "
                f"— 殿の判断を要請")

        # cmd_644 Scope B (B-2): P9c 7日 SLA — 家老 inbox に判断資料生成 cmd を dispatch (168h dedup)
        if hours >= 168:
            trigger_auto_remediation(
                pattern='P9c',
                key=tag_key,
                purpose=f"P9c 7日SLA: {tag} {title} 判断資料整備",
                command=(
                    f"action_required {tag} {title} が 7日以上滞留している。\n"
                    f"判断材料 (現状/選択肢/推奨/影響) を整理し殿に提示する。\n"
                    f"output/cmd_auto_decision_prep_{tag_key}.md として作成せよ。"
                ),
                brief=f"7d SLA action_required: {tag}",
            )

check_pattern_1()
check_pattern_2()
check_pattern_3()
check_pattern_4()
check_pattern_5()
check_pattern_6()
check_pattern_7()
check_pattern_8()
check_pattern_9()

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
    echo "${JST_NOW} [in_progress_monitor] 全9パターン異常なし"
else
    echo "${JST_NOW} [in_progress_monitor] ${ALERTS_FOUND}件のアラートを将軍 inbox に送信"
fi

exit 0
