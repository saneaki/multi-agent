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
  # title: フィールドを優先、なければ purpose: を使用（Python使用でUnicode安全切り捨て）
  title=$(grep "^title:" "$yaml_file" 2>/dev/null | sed 's/^title:[[:space:]]*//' | tr -d '"' | sed 's/^[|>]//' | python3 -c "import sys; s=sys.stdin.read().strip(); print(s[:50])" 2>/dev/null || true)
  if [ -z "$title" ]; then
    title=$(grep "^purpose:" "$yaml_file" 2>/dev/null | sed 's/^purpose:[[:space:]]*//' | tr -d '"' | sed 's/^[|>]//' | python3 -c "import sys; s=sys.stdin.read().strip(); print(s[:50])" 2>/dev/null || true)
  fi

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

echo "dashboard.md updated ($(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null || date))"
