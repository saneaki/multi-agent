#!/bin/bash
# update_dashboard.sh
# queue/tasks/ashigaru*.yaml から🔄進行中・🏯待機中セクションを自動生成してdashboard.mdを更新する
# ✅戦果・🚨要対応・🐸Frog等のセクションは一切上書きしない

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DASHBOARD="$REPO_DIR/dashboard.md"
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
      echo "| ${cmd_id} | ${title} | ${agent_name}作業中 | ${status} |" >> "$TMP_IN_PROG"
      ;;
    done|completed|idle|canceled)
      echo "| ${agent_name} | 待機 | ${task_id}完了: ${title} |" >> "$TMP_STANDBY"
      ;;
  esac
done

# 空の場合はデフォルト行を追加
if [ ! -s "$TMP_IN_PROG" ]; then
  echo "| — | 進行中なし | — | — |" > "$TMP_IN_PROG"
fi
if [ ! -s "$TMP_STANDBY" ]; then
  echo "| — | 待機なし | — |" > "$TMP_STANDBY"
fi

# awk でダッシュボードを更新（🔄と🏯セクションのみ置換）
TMP_DASH=$(mktemp)
trap 'rm -f "$TMP_IN_PROG" "$TMP_STANDBY" "$TMP_DASH"' EXIT

LANG=en_US.UTF-8 awk \
  -v in_prog_file="$TMP_IN_PROG" \
  -v standby_file="$TMP_STANDBY" \
  '
  BEGIN { skip = 0 }

  /^## 🔄 進行中/ {
    print
    print ""
    print "| cmd | 内容 | 担当 | 状態 |"
    print "|-----|------|------|------|"
    while ((getline line < in_prog_file) > 0) print line
    close(in_prog_file)
    skip = 1
    next
  }

  /^## 🏯 待機中/ {
    skip = 0
    print ""
    print
    print ""
    print "| 構成員 | 状態 | 最終タスク |"
    print "|------|------|-----------|"
    while ((getline line < standby_file) > 0) print line
    close(standby_file)
    skip = 1
    next
  }

  /^## ✅ 本日の戦果/ {
    skip = 0
    print ""
    print
    next
  }

  skip { next }
  { print }
  ' "$DASHBOARD" > "$TMP_DASH"

mv "$TMP_DASH" "$DASHBOARD"

# タイムスタンプ更新（2行目）
sed -i "2s/.*/最終更新: ${TIMESTAMP} JST/" "$DASHBOARD"

# 🚨要対応セクションのタグに連番付与（冪等: 既存[tag-N]を剥がして再付番）
python3 -c "
import re, sys
KNOWN_TAGS = {'info', 'action', 'decision', 'proposal'}
path = '$DASHBOARD'
with open(path, encoding='utf-8') as f:
    content = f.read()
m = re.search(r'(## 🚨 要対応.*?)(?=\n## |\Z)', content, re.DOTALL)
if not m:
    sys.exit(0)
counters = {}
def repl(mo):
    tag = mo.group(2).lower()
    if tag not in KNOWN_TAGS:
        return mo.group(0)
    counters[tag] = counters.get(tag, 0) + 1
    return mo.group(1) + '[' + tag + '-' + str(counters[tag]) + ']' + mo.group(3)
new_sec = re.sub(r'(?m)^(\| )\[([a-zA-Z]+)(?:-\d+)?\]( \|)', repl, m.group(1))
if new_sec == m.group(1):
    sys.exit(0)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content[:m.start()] + new_sec + content[m.end():])
" || echo "[WARN] tag renumber failed (non-fatal)"

# 📊将軍コンテキスト使用率セクション更新
COUNTER_FILE="${HOME}/.claude/tool_call_counter/shogun.json"
if [ -f "$COUNTER_FILE" ]; then
    CONTEXT_PCT=$("${REPO_DIR}/.venv/bin/python3" -c "
import json
try:
    with open('$COUNTER_FILE') as f:
        data = json.load(f)
    pct = data.get('context_pct') or data.get('usage_pct') or data.get('percent') or 0
    print(int(float(pct)))
except Exception:
    print(0)
" 2>/dev/null || echo "0")
    if [ "$CONTEXT_PCT" -ge 80 ]; then
        CONTEXT_ICON="🔴"
    elif [ "$CONTEXT_PCT" -ge 70 ]; then
        CONTEXT_ICON="🟡"
    else
        CONTEXT_ICON="🟢"
    fi
    CONTEXT_LINE="${CONTEXT_ICON} 将軍コンテキスト使用率: ${CONTEXT_PCT}%"
else
    CONTEXT_LINE="⚪ 将軍コンテキスト使用率: 計測データなし"
fi

# 📊セクションがあれば更新、なければ🐸セクションの前に挿入
if grep -q "^## 📊 将軍コンテキスト" "$DASHBOARD"; then
    python3 -c "
import re
path = '$DASHBOARD'
with open(path, encoding='utf-8') as f:
    content = f.read()
new_content = re.sub(
    r'(## 📊 将軍コンテキスト.*?\n)([^\n].*?\n)',
    r'\g<1>$CONTEXT_LINE\n',
    content
)
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)
" 2>/dev/null || true
fi

# 📊 運用指標セクション更新 (logs/cmd_squash_pub_hook.daily.yaml 動的 parse)
TODAY=$(bash "$SCRIPT_DIR/jst_now.sh" --date 2>/dev/null || date +%Y-%m-%d)
DAILY_YAML="$REPO_DIR/logs/cmd_squash_pub_hook.daily.yaml"
python3 -c "
import sys, os, re
dashboard = '$DASHBOARD'
daily_yaml = '$DAILY_YAML'
today = '$TODAY'

data = {}
if os.path.exists(daily_yaml):
    try:
        import yaml
        with open(daily_yaml) as f:
            data = yaml.safe_load(f) or {}
    except Exception:
        pass

header = '## 📊 運用指標\n\n| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 |\n|-----------|------------|------|------|----------------|'
if not data:
    row = '| データなし | - | - | - | - |'
else:
    date_jst = str(data.get('date_jst', '-'))
    label = date_jst if date_jst == today else date_jst + '(old)'
    row = '| {} | {} | {} | {} | {} |'.format(
        label, data.get('attempt_total', '-'),
        data.get('success_total', '-'), data.get('failure_total', '-'),
        str(data.get('kill_count', 0))
    )

new_section = header + '\n' + row + '\n'
with open(dashboard, encoding='utf-8') as f:
    content = f.read()
if '## 📊 運用指標' in content:
    content = re.sub(r'## 📊 運用指標.*?(?=\n## |\Z)', new_section, content, flags=re.DOTALL)
else:
    content = content.replace('\n## 🔄 進行中', '\n' + new_section + '\n## 🔄 進行中', 1)
with open(dashboard, 'w', encoding='utf-8') as f:
    f.write(content)
" 2>/dev/null || echo "[WARN] metric section update failed (non-fatal)"

echo "dashboard.md updated ($(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null || date))"
