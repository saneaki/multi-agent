#!/usr/bin/env bash
# notion_session_log.sh
# Claude Codeセッション活動をNotion DBに記録し、日記タスクに追記する
# Stop hookから呼び出される: bash /home/ubuntu/shogun/scripts/notion_session_log.sh
# 冪等性: 同日付のレコードが既にあればDB追記スキップ、日記も同様

set -euo pipefail

# ============================================================
# 2-1: 環境変数読み込み
# ============================================================
source /home/ubuntu/.n8n-mcp/n8n/.env

NOTION_TOKEN="${NOTION_INTEGRATION_TOKEN}"
ACTIVITY_LOG_DB_ID="${NOTION_ACTIVITY_LOG_DB_ID}"
DIARY_DB_ID="1a4e8d62-e4aa-81f1-8ede-c239ea53299b"
DASHBOARD="/home/ubuntu/shogun/dashboard.md"
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] notion_session_log.sh 開始 (TODAY=${TODAY})"

if [[ -z "${NOTION_TOKEN}" ]]; then
  echo "[ERROR] NOTION_INTEGRATION_TOKEN が未設定" >&2
  exit 1
fi

if [[ -z "${ACTIVITY_LOG_DB_ID}" ]]; then
  echo "[ERROR] NOTION_ACTIVITY_LOG_DB_ID が未設定" >&2
  exit 1
fi

if [[ ! -f "${DASHBOARD}" ]]; then
  echo "[ERROR] dashboard.md が見つかりません: ${DASHBOARD}" >&2
  exit 1
fi

# ============================================================
# 2-2: dashboard.md からデータ抽出
# ============================================================

# ストリーク数: 「ストリーク | 🔥 N日目」のN
STREAK=$(grep -oP 'ストリーク \| 🔥 \K[0-9]+(?=日目)' "${DASHBOARD}" | head -1 || echo "0")

# 完了cmd数: 「今日の完了 | N/M」のN
COMPLETED=$(grep -oP '今日の完了 \| \K[0-9]+(?=/)' "${DASHBOARD}" | head -1 || echo "0")

# 本日の戦果テーブル: 「## ✅ 本日の戦果」セクションの | 行
TODAY_DISPLAY=$(TZ=Asia/Tokyo date +%-m/%-d)
BATTLE_SECTION=$(python3 - <<'PYEOF'
import re, sys

dashboard_path = "/home/ubuntu/shogun/dashboard.md"
with open(dashboard_path, encoding="utf-8") as f:
    content = f.read()

# 「## ✅ 本日の戦果」セクションを抽出 (次のセクション ##まで)
m = re.search(r'## ✅ 本日の戦果.*?\n(.*?)(?=\n## |\Z)', content, re.DOTALL)
if not m:
    print("")
    sys.exit(0)

section = m.group(1)
rows = []
for line in section.split("\n"):
    line = line.strip()
    if line.startswith("|") and not line.startswith("| 時刻") and not line.startswith("|---") and len(line) > 4:
        rows.append(line)

print("\n".join(rows))
PYEOF
)

# プロジェクト一覧: 戦場列のユニーク値
PROJECTS=$(echo "${BATTLE_SECTION}" | python3 - <<'PYEOF'
import sys, re

rows = sys.stdin.read().strip().split("\n")
projects = set()
for row in rows:
    if not row.strip():
        continue
    cols = [c.strip() for c in row.split("|")]
    # | 時刻 | 戦場 | 任務 | 結果 | → cols[2]が戦場
    if len(cols) >= 4:
        proj = cols[2].strip()
        if proj:
            projects.add(proj)

print(",".join(sorted(projects)))
PYEOF
)

# 主要プロジェクト (最初の1つ)
MAIN_PROJECT=$(echo "${PROJECTS}" | cut -d',' -f1 | tr -d ' ')
if [[ -z "${MAIN_PROJECT}" ]]; then
  MAIN_PROJECT="general"
fi

# セッション概要テキスト
if [[ "${COMPLETED}" -gt 0 && -n "${MAIN_PROJECT}" ]]; then
  SESSION_SUMMARY="${COMPLETED}cmd完了、${MAIN_PROJECT}中心"
else
  SESSION_SUMMARY="セッション終了"
fi

# 詳細: 戦果テーブル行を改行で連結 (2000文字制限)
DETAIL=$(echo "${BATTLE_SECTION}" | head -20 | tr '\n' ' ' | cut -c1-1900)

echo "[INFO] ストリーク=${STREAK}, 完了cmd=${COMPLETED}, プロジェクト=${PROJECTS}"
echo "[INFO] セッション概要: ${SESSION_SUMMARY}"

# ============================================================
# 2-3: 冪等性チェック (Notion DB検索)
# ============================================================

EXISTING=$(curl -s -X POST \
  "${NOTION_API}/databases/${ACTIVITY_LOG_DB_ID}/query" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: ${NOTION_VERSION}" \
  -d "{
    \"filter\": {
      \"property\": \"日付\",
      \"date\": { \"equals\": \"${TODAY}\" }
    }
  }")

EXISTING_COUNT=$(echo "${EXISTING}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data.get('results', [])))
" 2>/dev/null || echo "0")

# ============================================================
# 2-4: Notion DBレコード作成 (冪等性: 既存ならスキップ)
# ============================================================

if [[ "${EXISTING_COUNT}" -gt 0 ]]; then
  echo "[INFO] ${TODAY} の活動ログは既に記録済み。DB追記スキップ。"
else
  echo "[INFO] Notion DBにレコード作成中..."

  # プロジェクトのmulti_select配列を構築
  MULTI_SELECT_JSON=$(echo "${PROJECTS}" | python3 - <<'PYEOF'
import sys, json
projects_str = sys.stdin.read().strip()
if not projects_str:
    print("[]")
    sys.exit(0)
projects = [p.strip() for p in projects_str.split(",") if p.strip()]
result = [{"name": p} for p in projects[:5]]  # 最大5件
print(json.dumps(result))
PYEOF
)

  CREATE_RESP=$(curl -s -X POST \
    "${NOTION_API}/pages" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "$(python3 - <<PYEOF
import json

db_id = "${ACTIVITY_LOG_DB_ID}"
summary = """${SESSION_SUMMARY}"""
today = "${TODAY}"
completed = int("${COMPLETED}" or 0)
streak = int("${STREAK}" or 0)
detail = """${DETAIL}"""
multi_select = ${MULTI_SELECT_JSON}

payload = {
    "parent": {"database_id": db_id},
    "properties": {
        "セッション概要": {
            "title": [{"type": "text", "text": {"content": summary[:200]}}]
        },
        "日付": {
            "date": {"start": today}
        },
        "完了cmd数": {
            "number": completed
        },
        "ストリーク": {
            "number": streak
        },
        "プロジェクト": {
            "multi_select": multi_select
        },
        "詳細": {
            "rich_text": [{"type": "text", "text": {"content": detail[:2000]}}]
        }
    }
}
print(json.dumps(payload))
PYEOF
)")

  CREATED_ID=$(echo "${CREATE_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'page':
    print(data.get('id', ''))
else:
    print('ERROR: ' + str(data.get('message', 'unknown')), file=sys.stderr)
    print('')
" 2>&1)

  if [[ "${CREATED_ID}" == ERROR:* ]]; then
    echo "[ERROR] Notion DBレコード作成失敗: ${CREATED_ID}" >&2
  elif [[ -n "${CREATED_ID}" ]]; then
    echo "[SUCCESS] Notion DBレコード作成完了: ${CREATED_ID}"
  else
    echo "[ERROR] Notion DBレコード作成: 不明なエラー" >&2
  fi
fi

# ============================================================
# 2-5: 日記タスク検索
# ============================================================

echo "[INFO] 日記タスク検索: ${TODAY}日記"

DIARY_QUERY=$(curl -s -X POST \
  "${NOTION_API}/databases/${DIARY_DB_ID}/query" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: ${NOTION_VERSION}" \
  -d "{
    \"filter\": {
      \"property\": \"名前\",
      \"title\": { \"contains\": \"${TODAY}\" }
    }
  }")

DIARY_PAGE_ID=$(echo "${DIARY_QUERY}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if results:
    print(results[0].get('id', ''))
else:
    print('')
" 2>/dev/null || echo "")

if [[ -z "${DIARY_PAGE_ID}" ]]; then
  echo "[INFO] ${TODAY}の日記タスクが見つかりません。日記追記スキップ。"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] notion_session_log.sh 完了"
  exit 0
fi

echo "[INFO] 日記タスク発見: ${DIARY_PAGE_ID}"

# ============================================================
# 2-6: 日記タスクのブロック確認 (冪等性チェック)
# ============================================================

BLOCKS=$(curl -s -X GET \
  "${NOTION_API}/blocks/${DIARY_PAGE_ID}/children" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Notion-Version: ${NOTION_VERSION}")

HAS_CC_SECTION=$(echo "${BLOCKS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
for block in results:
    block_type = block.get('type', '')
    if block_type in ('heading_2', 'heading_1', 'heading_3'):
        texts = block.get(block_type, {}).get('rich_text', [])
        text = ''.join(t.get('plain_text', '') for t in texts)
        if 'Claude Code活動' in text:
            print('true')
            sys.exit(0)
print('false')
" 2>/dev/null || echo "false")

# ============================================================
# 2-7: 日記タスクへの追記
# ============================================================

if [[ "${HAS_CC_SECTION}" == "true" ]]; then
  echo "[INFO] 日記に「Claude Code活動」セクションが既に存在。追記スキップ。"
else
  echo "[INFO] 日記に「Claude Code活動」セクション追記中..."

  # 戦果テーブルから各cmdのbullet listを構築
  BULLETS_JSON=$(echo "${BATTLE_SECTION}" | python3 - <<'PYEOF'
import sys, json, re

rows = sys.stdin.read().strip().split("\n")
bullets = []
for row in rows:
    if not row.strip():
        continue
    cols = [c.strip() for c in row.split("|")]
    # | 時刻 | 戦場 | 任務 | 結果 |
    if len(cols) >= 5:
        proj = cols[2].strip()
        task = cols[3].strip()
        if proj and task:
            text = f"{proj}: {task[:100]}"
            bullets.append({
                "object": "block",
                "type": "bulleted_list_item",
                "bulleted_list_item": {
                    "rich_text": [{"type": "text", "text": {"content": text}}]
                }
            })

# 最大10件
print(json.dumps(bullets[:10]))
PYEOF
)

  APPEND_BLOCKS=$(python3 - <<PYEOF
import json

completed = "${COMPLETED}"
streak = "${STREAK}"
bullets = ${BULLETS_JSON}

blocks = [
    {
        "object": "block",
        "type": "heading_2",
        "heading_2": {
            "rich_text": [{"type": "text", "text": {"content": "Claude Code活動 🤖"}}]
        }
    },
    {
        "object": "block",
        "type": "paragraph",
        "paragraph": {
            "rich_text": [{"type": "text", "text": {
                "content": f"完了: {completed}cmd / ストリーク: 🔥{streak}日目"
            }}]
        }
    }
]
blocks.extend(bullets)

print(json.dumps({"children": blocks}))
PYEOF
)

  APPEND_RESP=$(curl -s -X PATCH \
    "${NOTION_API}/blocks/${DIARY_PAGE_ID}/children" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "${APPEND_BLOCKS}")

  APPEND_STATUS=$(echo "${APPEND_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'list':
    print('success')
else:
    print('error: ' + str(data.get('message', 'unknown')))
" 2>/dev/null || echo "error: parse failed")

  if [[ "${APPEND_STATUS}" == "success" ]]; then
    echo "[SUCCESS] 日記への Claude Code活動セクション追記完了"
  else
    echo "[ERROR] 日記追記失敗: ${APPEND_STATUS}" >&2
  fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] notion_session_log.sh 完了"
