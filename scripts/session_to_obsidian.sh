#!/usr/bin/env bash
# project root に移行 (cron 起動時の cwd 不整合対策)
cd "$(dirname "$0")/.." || exit 1

# session_to_obsidian.sh — Claude Code shogun セッションを Obsidian Vault に書出
# cmd_635 Scope A: jsonl 一次source化 + cmd今日filter + 殿令本文抽出
set -euo pipefail

LOCK_FILE="/tmp/session_to_obsidian.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[session_to_obsidian] lock held -> skip" >&2
  exit 0
fi

DRY_RUN=0
DO_PUSH=0
TARGET_DATE=""
OUTPUT_DIR="${OBSIDIAN_REPO_PATH:-/home/ubuntu/obsidian}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      TARGET_DATE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_DATE" ]]; then
  TARGET_DATE="$(TZ=Asia/Tokyo date +%F)"
fi

if ! [[ "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid --date: $TARGET_DATE" >&2
  exit 1
fi

YEAR="${TARGET_DATE:0:4}"
MONTH="${TARGET_DATE:5:2}"
DAY="${TARGET_DATE:8:2}"

BASE_FOLDER="01_data"
OUT_PATH="${OUTPUT_DIR}/${BASE_FOLDER}/${YEAR}/${MONTH}/${DAY}/shogun-session_${TARGET_DATE}.md"

# Source files
DASHBOARD_YAML="dashboard.yaml"
SHOGUN_TO_KARO="queue/shogun_to_karo.yaml"
KARO_INBOX="queue/inbox/karo.yaml"
JSONL_DIR="${HOME}/.claude/projects/-home-ubuntu-shogun"

[[ -f "$DASHBOARD_YAML" ]] || { echo "Missing source file: $DASHBOARD_YAML" >&2; exit 1; }
[[ -f "$SHOGUN_TO_KARO" ]] || { echo "Missing source file: $SHOGUN_TO_KARO" >&2; exit 1; }
[[ -f "$KARO_INBOX" ]] || { echo "Missing source file: $KARO_INBOX" >&2; exit 1; }
[[ -d "$JSONL_DIR" ]] || { echo "Missing source dir: $JSONL_DIR" >&2; exit 1; }

# Render via Python
RENDERED="$(
  TARGET_DATE="$TARGET_DATE" \
  DASHBOARD_YAML="$DASHBOARD_YAML" \
  SHOGUN_TO_KARO="$SHOGUN_TO_KARO" \
  KARO_INBOX="$KARO_INBOX" \
  JSONL_DIR="$JSONL_DIR" \
  python3 - <<'PYEOF'
import os, re, sys, json, glob, yaml
from datetime import datetime, timezone, timedelta

TARGET_DATE = os.environ['TARGET_DATE']
DASHBOARD_YAML = os.environ['DASHBOARD_YAML']
SHOGUN_TO_KARO = os.environ['SHOGUN_TO_KARO']
KARO_INBOX = os.environ['KARO_INBOX']
JSONL_DIR = os.environ['JSONL_DIR']

JST = timezone(timedelta(hours=9))


def jst_hm(iso):
    if not iso:
        return ''
    try:
        s = iso.replace('Z', '+00:00') if iso.endswith('Z') else iso
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=JST)
        return dt.astimezone(JST).strftime('%H:%M JST')
    except Exception:
        return iso[:16].replace('T', ' ')


def cmd_sort_key(c):
    m = re.match(r'cmd_(\d+)', c)
    return int(m.group(1)) if m else 0


# 1. Parse dashboard.yaml — today section (live state)
dash = {}
try:
    with open(DASHBOARD_YAML) as f:
        dash = yaml.safe_load(f) or {}
except Exception as e:
    print(f"# WARN: dashboard.yaml parse failed: {e}", file=sys.stderr)

today_items = (dash.get('achievements') or {}).get('today') or []
in_progress = dash.get('in_progress') or []


# 2. Collect TODAY-ISSUED cmd_ids only (strict filter per AC4)
#    判定条件: cmd_id が
#    (a) shogun_to_karo.yaml に today JST timestamp で entry 存在 OR
#    (b) karo inbox shogun→karo 殿令 で today JST に「cmd_NNN 発令」と issued
#    過去 cmd の grep 混入は排除する。


# 3. Parse shogun_to_karo.yaml leniently (file may have YAML errors)
sk_db = {}
with open(SHOGUN_TO_KARO) as f:
    text = f.read()
blocks = re.split(r'^- id: ', text, flags=re.MULTILINE)
for blk in blocks[1:]:
    m_id = re.match(r'(cmd_\d+)', blk)
    if not m_id:
        continue
    cmd_id = m_id.group(1)
    info = {'id': cmd_id}
    m_ts = re.search(r'^\s+timestamp: [\'"]?([^\'"\n]+)[\'"]?', blk, re.MULTILINE)
    if m_ts:
        info['timestamp'] = m_ts.group(1).strip()
    m_pp = re.search(r'^\s+purpose: (.+?)$', blk, re.MULTILINE)
    if m_pp:
        info['purpose'] = m_pp.group(1).strip().strip("'\"")
    m_st = re.search(r'^\s+status: (\w+)', blk, re.MULTILINE)
    if m_st:
        info['status'] = m_st.group(1)
    m_rs = re.search(r'^\s+result: (.+?)$', blk, re.MULTILINE)
    if m_rs:
        info['result'] = m_rs.group(1).strip().strip("'\"")
    # command field may be multi-line block scalar (|) or single line
    m_cmd = re.search(r'^\s+command: (?:\|\s*\n((?:^[ \t].*\n)+))', blk, re.MULTILINE)
    if m_cmd:
        info['command'] = '\n'.join(line.strip() for line in m_cmd.group(1).split('\n') if line.strip())
    else:
        m_cmd2 = re.search(r"^\s+command: '((?:[^']|'')*)'", blk, re.MULTILINE | re.DOTALL)
        if m_cmd2:
            info['command'] = m_cmd2.group(1).replace("''", "'").strip()
    sk_db[cmd_id] = info


# 4. Read karo inbox for shogun→karo 殿令 messages today
karo_msgs = []
try:
    with open(KARO_INBOX) as f:
        kd = yaml.safe_load(f) or {}
    for m in kd.get('messages', []) or []:
        ts = str(m.get('timestamp', ''))
        if ts.startswith(TARGET_DATE) and m.get('from') == 'shogun':
            karo_msgs.append(m)
except Exception as e:
    print(f"# WARN: karo.yaml parse failed: {e}", file=sys.stderr)


# Pattern: cmd_NNN [ + cmd_MMM] [即時|別途|並行|並列|追加] 発令
ISSUE_PATTERN = re.compile(
    r'(cmd_\d+(?:\s*[+＋]\s*cmd_\d+)*)\s*(?:を)?\s*(?:即時|別途|並行|並列|追加)?\s*発令'
)


def find_lord_command(cmd_id):
    """Find 殿令 body & timestamp for cmd_id from karo inbox shogun messages.

    Prefer the message that ISSUES this cmd (matches `cmd_NNN ... 発令` pattern).
    """
    issued_msg = None
    for m in karo_msgs:
        c = m.get('content', '') or ''
        head = c[:600]
        for match in ISSUE_PATTERN.finditer(head):
            ids = re.findall(r'cmd_\d+', match.group(0))
            if cmd_id in ids:
                issued_msg = m
                break
        if issued_msg:
            break
    if issued_msg:
        return issued_msg.get('content', '') or '', issued_msg.get('timestamp', '')
    # Fallback: any message that mentions this cmd_id at all
    for m in karo_msgs:
        c = m.get('content', '') or ''
        if cmd_id in c:
            return c, m.get('timestamp', '')
    return None, None


def get_today_issued_cmds():
    """Return cmd_ids issued today via karo inbox 殿令 messages."""
    issued = set()
    for m in karo_msgs:
        c = m.get('content', '') or ''
        head = c[:600]
        for match in ISSUE_PATTERN.finditer(head):
            for cid in re.findall(r'cmd_\d+', match.group(0)):
                issued.add(cid)
    return issued


# 5. Optional jsonl supplement — find shogun pane jsonl
def find_shogun_jsonl():
    """Identify shogun's jsonl by finding the file that reads instructions/shogun.md only."""
    files = sorted(glob.glob(os.path.join(JSONL_DIR, '*.jsonl')),
                   key=os.path.getmtime, reverse=True)[:10]
    candidates = []
    for jf in files:
        try:
            sh = ka = ash = gun = 0
            with open(jf) as f:
                for line in f:
                    if 'instructions/shogun.md' in line: sh += 1
                    if 'instructions/karo.md' in line: ka += 1
                    if 'instructions/ashigaru.md' in line: ash += 1
                    if 'instructions/gunshi.md' in line: gun += 1
            if sh > 0 and ka == 0 and ash == 0 and gun == 0:
                candidates.append((jf, sh))
        except Exception:
            continue
    candidates.sort(key=lambda x: -x[1])
    return candidates[0][0] if candidates else None


SHOGUN_JSONL = find_shogun_jsonl()


def jsonl_completion_time(cmd_id):
    """Find latest timestamp where cmd_id appears in shogun jsonl assistant message today."""
    if not SHOGUN_JSONL:
        return None
    latest = None
    try:
        with open(SHOGUN_JSONL) as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get('type') != 'assistant':
                    continue
                ts = d.get('timestamp', '')
                if not ts.startswith(TARGET_DATE):
                    continue
                m = d.get('message', {}) or {}
                c = m.get('content', '')
                txt = ''
                if isinstance(c, str):
                    txt = c
                elif isinstance(c, list):
                    for it in c:
                        if isinstance(it, dict) and it.get('type') == 'text':
                            txt += it.get('text', '')
                if cmd_id in txt:
                    latest = ts
    except Exception:
        return None
    return latest


# 6. Filter cmds: today-issued ONLY (strict — AC4)
#    (a) shogun_to_karo.yaml entries with today's timestamp, OR
#    (b) cmds issued today via karo inbox 殿令 (cmd_NNN ... 発令 pattern)
today_filtered = set()
for c, info in sk_db.items():
    if info.get('timestamp', '').startswith(TARGET_DATE):
        today_filtered.add(c)

today_filtered |= get_today_issued_cmds()

cmd_list = sorted(today_filtered, key=cmd_sort_key)


# 7. Build per-cmd sections
def get_cmd_meta(cmd_id):
    sk_info = sk_db.get(cmd_id, {})
    if isinstance(sk_info, str):
        sk_info = {'purpose': sk_info}
    elif not isinstance(sk_info, dict):
        sk_info = {}
    issued_iso = sk_info.get('timestamp', '')
    title = sk_info.get('purpose', '')
    lord_cmd = sk_info.get('command', '')

    if not lord_cmd or not issued_iso:
        body, ts = find_lord_command(cmd_id)
        if body:
            if not lord_cmd:
                lord_cmd = body
            if not issued_iso:
                issued_iso = ts

    if not title:
        # First try: extract subject from 殿令 brackets【...】
        if lord_cmd:
            subject_m = re.search(r'【\s*殿令(?:採択)?\s*[:：]\s*(.+?)\s*】', lord_cmd)
            if subject_m:
                subject = subject_m.group(1).strip()
                # Pattern: "cmd_NNN [+ cmd_MMM]... [発令] — <real title>"
                # Strip leading cmd_NNN + 発令/併発令 etc. then take what follows the dash/em-dash.
                after_dash = re.search(r'[—\-–]\s*(.+)$', subject)
                if after_dash:
                    title = after_dash.group(1).strip()
                else:
                    # No dash: strip cmd_NNN refs and 発令 keywords
                    cleaned = re.sub(r'cmd_\d+(?:\s*[+＋]\s*cmd_\d+)*', '', subject)
                    cleaned = re.sub(r'(?:即時|別途|並行|並列|追加|を)?\s*発令', '', cleaned).strip()
                    cleaned = cleaned.strip(' :：—-+＋')
                    if cleaned:
                        title = cleaned

    if not title:
        completion = next(
            (it for it in today_items
             if isinstance(it, dict)
             and cmd_id in (it.get('result') or '') and '完遂' in (it.get('result') or '')),
            None,
        )
        if completion:
            task_text = completion.get('task') or ''
            first_period = re.search(r'[。\n]', task_text)
            title = (task_text[:first_period.start()] if first_period else task_text[:80]).strip()
        else:
            ip = next(
                (it for it in in_progress
                 if isinstance(it, dict) and it.get('cmd') == cmd_id),
                None,
            )
            if ip:
                content = ip.get('content', '') or ''
                first_period = re.search(r'[。\n]', content)
                title = (content[:first_period.start()] if first_period else content[:80]).strip()
            else:
                title = '(タイトル不明)'

    completion_entries = [
        it for it in today_items
        if isinstance(it, dict)
        and cmd_id in (it.get('result') or '') and '完遂' in (it.get('result') or '')
    ]
    if completion_entries:
        completion_entries.sort(key=lambda x: x.get('time', ''), reverse=True)
        completed_time = completion_entries[0].get('time', '')
        if completed_time:
            completed_time = f'{completed_time} JST'
        shogun_summary = completion_entries[0].get('task', '')
    else:
        completed_time = '進行中'
        ip = next(
            (it for it in in_progress
             if isinstance(it, dict) and it.get('cmd') == cmd_id),
            None,
        )
        shogun_summary = (ip.get('content', '') if ip else '') or ''

    return {
        'cmd_id': cmd_id,
        'title': title,
        'issued': jst_hm(issued_iso) if issued_iso else 'unknown',
        'completed': completed_time,
        'lord_command': lord_cmd or '',
        'shogun_summary': shogun_summary or '',
    }


# 8. Output markdown
created = datetime.now(JST).strftime('%Y-%m-%d %H:%M:%S')
out = []
out.append('---')
out.append(f'created: {created}')
out.append('tags: [shogun-session, claude-code]')
out.append(f'cmds: [{", ".join(cmd_list) if cmd_list else ""}]')
out.append(f'session_date: {TARGET_DATE}')
out.append('---')
out.append('')
out.append(f'# {TARGET_DATE} shogun セッション')
out.append('')

if not cmd_list:
    out.append('_本日の発令 cmd は記録されていない。_')
    out.append('')
else:
    for cmd_id in cmd_list:
        meta = get_cmd_meta(cmd_id)
        if isinstance(meta, str):
            meta = {
                'cmd_id': cmd_id,
                'title': meta,
                'issued': 'unknown',
                'completed': '進行中',
                'lord_command': '',
                'shogun_summary': '',
            }
        elif isinstance(meta, dict):
            meta = {
                'cmd_id': meta.get('cmd_id', cmd_id),
                'title': meta.get('title') or meta.get('purpose') or str(meta)[:80],
                'issued': meta.get('issued', 'unknown'),
                'completed': meta.get('completed', '進行中'),
                'lord_command': meta.get('lord_command', ''),
                'shogun_summary': meta.get('shogun_summary', ''),
            }
        else:
            meta = {
                'cmd_id': cmd_id,
                'title': str(meta),
                'issued': 'unknown',
                'completed': '進行中',
                'lord_command': '',
                'shogun_summary': '',
            }
        title = meta['title'][:80] or '(タイトル不明)'
        out.append(f"## {cmd_id}: {title}")
        out.append(f"- 発令: {meta['issued']}")
        out.append(f"- 完遂: {meta['completed']}")
        out.append('')
        out.append('### 殿令')
        body = meta['lord_command'].strip()
        if body:
            snippet = body.replace('\n', ' ').strip()
            snippet = re.sub(r'\s+', ' ', snippet)
            if len(snippet) > 220:
                snippet = snippet[:200] + '…'
            out.append(snippet)
        else:
            out.append('_(殿令本文未記録)_')
        out.append('')
        out.append('### 将軍応答')
        s = meta['shogun_summary'].strip()
        if s:
            s2 = re.sub(r'\s+', ' ', s.replace('\n', ' '))
            if len(s2) > 220:
                s2 = s2[:200] + '…'
            out.append(s2)
        else:
            out.append('_(応答記録なし)_')
        out.append('')
        out.append('---')
        out.append('')

# Append today section summary table from dashboard
if today_items:
    out.append('## 本日の活動タイムライン')
    out.append('')
    out.append('| 時刻 | 戦場 | 結果 | 任務概要 |')
    out.append('|---|---|---|---|')
    for it in today_items:
        if not isinstance(it, dict):
            continue
        time_v = it.get('time', '') or ''
        bf = it.get('battlefield', '') or ''
        rs = it.get('result', '') or ''
        tk = re.sub(r'\s+', ' ', (it.get('task', '') or '').replace('\n', ' '))
        if len(tk) > 100:
            tk = tk[:100] + '…'
        # Escape pipe chars
        tk = tk.replace('|', '\\|')
        bf = bf.replace('|', '\\|')
        rs = rs.replace('|', '\\|')
        out.append(f"| {time_v} | {bf} | {rs} | {tk} |")
    out.append('')

print('\n'.join(out))
PYEOF
)"

# Redact secrets
RENDERED="$(printf '%s' "$RENDERED" | sed -E \
  -e 's/(NOTION_INTEGRATION_TOKEN|GEMINI_API_KEY2|GEMINI_API_KEY|NOTION_API_KEY)=[A-Za-z0-9_.-]+/\1=[REDACTED]/g' \
  -e 's/(secret|password|token)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_.-]{20,}/\1=[REDACTED]/Ig' \
  -e 's/(Bearer[[:space:]]+)[A-Za-z0-9_.-]{20,}/\1[REDACTED]/g' \
  -e 's/(refresh_token|access_token)["[:space:]]*[:=][[:space:]]*"[A-Za-z0-9_.-]{20,}"/\1=[REDACTED]/Ig')"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s\n' "$RENDERED"
  exit 0
fi

mkdir -p "$(dirname "$OUT_PATH")"
printf '%s\n' "$RENDERED" > "$OUT_PATH"
echo "Wrote: $OUT_PATH"

if [[ "$DO_PUSH" -eq 1 ]]; then
  if ! cd "$OUTPUT_DIR"; then
    echo "Failed to cd to obsidian repo: $OUTPUT_DIR" >&2
    exit 1
  fi

  # Ensure on main branch and up-to-date before committing (prevents non-fast-forward)
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "Warning: obsidian repo on branch '${CURRENT_BRANCH}', switching to main" >&2
    git checkout main 2>/dev/null || { echo "git checkout main failed" >&2; exit 1; }
  fi
  git pull --rebase origin main 2>/dev/null || echo "Warning: git pull --rebase failed, continuing" >&2

  if ! git add "$OUT_PATH"; then
    echo "git add failed: $OUT_PATH" >&2
    exit 1
  fi

  if ! git commit -m "session: ${TARGET_DATE} shogun log"; then
    echo "git commit failed" >&2
    exit 1
  fi

  if ! git push origin main; then
    echo "git push failed" >&2
    exit 1
  fi

  echo "Pushed to origin/main"
fi

exit 0
