#!/bin/bash
# update_dashboard.sh
# queue/tasks/ashigaru*.yaml から🔄進行中・🏯待機中セクションを自動生成してdashboard.mdを更新する
# ✅戦果・🚨要対応・🐸Frog等のセクションは一切上書きしない

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DASHBOARD="$REPO_DIR/dashboard.md"
DASHBOARD_YAML="$REPO_DIR/dashboard.yaml"
TASKS_DIR="$REPO_DIR/queue/tasks"

# JST timestamp
TIMESTAMP=$(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' || date "+%Y-%m-%d %H:%M")

# 構成員名変換
ashigaru_name() {
  case "$1" in
    ashigaru1) echo "足軽1号(Sonnet)" ;;
    ashigaru2) echo "足軽2号(Sonnet)" ;;
    ashigaru3) echo "足軽3号(Sonnet)" ;;
    ashigaru4) echo "足軽4号(Opus+T)" ;;
    ashigaru5) echo "足軽5号(Opus+T)" ;;
    ashigaru6) echo "足軽6号(Codex)" ;;
    ashigaru7) echo "足軽7号(Codex)" ;;
    gunshi)    echo "軍師(Opus+T)" ;;
    *) echo "$1" ;;
  esac
}

# YAML から task title を python3+PyYAML で取得
# 優先順位: title > purpose > task.description1行目 > task_type
# YAML パースエラー時は regex フォールバック
get_task_title() {
  local yaml_file="$1"
  python3 -c "
import yaml, sys, re

yaml_file = '$yaml_file'

# まず PyYAML でパース試行
d = None
try:
    d = yaml.safe_load(open(yaml_file))
except Exception:
    d = None

if isinstance(d, dict):
    for key in ['title', 'purpose']:
        v = d.get(key, '')
        if v and str(v).strip():
            print(str(v).strip()[:50]); sys.exit(0)
    task = d.get('task', {})
    if isinstance(task, dict):
        desc = task.get('description', '')
        if desc and str(desc).strip():
            line = str(desc).strip().split('\n')[0]
            print(line[:50]); sys.exit(0)
    print(d.get('task_type', '')); sys.exit(0)

# フォールバック: 正規表現でトップレベル title/purpose を抽出
try:
    content = open(yaml_file).read()
    for key in ['title', 'purpose']:
        m = re.search(r'^' + key + r':\s*[\"\']*(.+?)[\"\']?\s*$', content, re.MULTILINE)
        if m:
            print(m.group(1).strip()[:50]); sys.exit(0)
except Exception:
    pass
sys.exit(0)
" 2>/dev/null || echo ""
}

# tmpファイル
TMP_IN_PROG=$(mktemp)
TMP_STANDBY=$(mktemp)
trap 'rm -f "$TMP_IN_PROG" "$TMP_STANDBY"' EXIT

# 各ashigaru*.yaml + gunshi.yamlを処理
for yaml_file in "$TASKS_DIR"/ashigaru*.yaml "$TASKS_DIR"/gunshi.yaml; do
  [ -f "$yaml_file" ] || continue

  task_id=$(grep "^task_id:" "$yaml_file" 2>/dev/null | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
  cmd_id=$(grep "^cmd_id:" "$yaml_file" 2>/dev/null   | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
  status=$(grep "^status:" "$yaml_file" 2>/dev/null   | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
  assigned_to=$(grep "^assigned_to:" "$yaml_file" 2>/dev/null | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
  # python3+PyYAML で title 取得: title > purpose > task.description1行目 > task_type
  title=$(get_task_title "$yaml_file")

  agent_name=$(ashigaru_name "$assigned_to")

  case "$status" in
    assigned|in_progress|working)
      printf '%s\t%s\t%s\n' "${cmd_id:-}" "${title:-}" "${agent_name:-}" >> "$TMP_IN_PROG"
      ;;
    done|completed|idle|canceled)
      printf '%s\t%s\t%s\n' "${agent_name:-}" "${task_id:-}" "${title:-}" >> "$TMP_STANDBY"
      ;;
  esac
done

# dashboard.yaml 更新 (in_progress / idle_members / metrics) + dashboard.md 再生成
python3 - "$TMP_IN_PROG" "$TMP_STANDBY" "$DASHBOARD_YAML" "$TIMESTAMP" <<'PYEOF'
import yaml, sys, subprocess
from pathlib import Path

tmp_in_prog, tmp_standby, dashboard_yaml, timestamp = sys.argv[1:5]
daily_yaml = str(Path(dashboard_yaml).parent / 'logs' / 'cmd_squash_pub_hook.daily.yaml')

in_progress = []
for line in Path(tmp_in_prog).read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split('\t')
    if len(parts) >= 3:
        cmd_id, title, agent_name = parts[0].strip(), parts[1].strip(), parts[2].strip()
        if cmd_id or title:
            in_progress.append({'cmd': cmd_id, 'content': title, 'assignee': agent_name, 'status': '🔄 作業中'})

idle_members = []
for line in Path(tmp_standby).read_text().splitlines():
    if not line.strip():
        continue
    parts = line.split('\t')
    if len(parts) >= 3:
        agent_name, task_id, title = parts[0].strip(), parts[1].strip(), parts[2].strip()
        idle_members.append({'name': agent_name, 'model': '', 'status': '待機', 'last_task': f'{task_id}完了: {title}'})

with open(dashboard_yaml) as f:
    d = yaml.safe_load(f) or {}

d['in_progress'] = in_progress or [{'cmd': '—', 'content': '進行中なし', 'assignee': '—', 'status': '—'}]
d['idle_members'] = idle_members or [{'name': '—', 'model': '', 'status': '待機なし', 'last_task': '—'}]
d['metadata']['last_updated'] = f'{timestamp} JST'

import os
if os.path.exists(daily_yaml):
    try:
        daily = yaml.safe_load(open(daily_yaml)) or {}
        date_jst = str(daily.get('date_jst', '')).split()[0]
        if date_jst:
            metrics = d.get('metrics', [])
            row = next((m for m in metrics if str(m.get('date', '')) == date_jst), None)
            if row is None:
                row = {'date': date_jst, 'success': 0, 'failure': 0,
                       'karo_compact': '-', 'gunshi_compact': '-', 'safe_window': '-'}
                metrics.append(row)
            row.pop('pub_us', None)
            row.pop('kill_switch', None)
            row['success'] = int(daily.get('success_total', 0) or 0)
            row['failure'] = int(daily.get('failure_total', 0) or 0)
            d['metrics'] = sorted(metrics, key=lambda m: str(m.get('date', '')))[-7:]
    except Exception as e:
        print(f'[WARN] metrics update failed: {e}', file=sys.stderr)

with open(dashboard_yaml, 'w') as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False)

subprocess.run(['python3', 'scripts/generate_dashboard_md.py'], check=True,
               cwd=str(Path(dashboard_yaml).parent))
print('dashboard.yaml updated + dashboard.md regenerated')
PYEOF

echo "dashboard.md updated ($(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null || date))"
