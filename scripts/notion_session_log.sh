#!/usr/bin/env bash
# notion_session_log.sh
# Claude Codeセッション活動をNotion DBに記録し、日記タスクに追記する
# Stop hookから呼び出される: bash /home/ubuntu/shogun/scripts/notion_session_log.sh
# 冪等性: 同日付のレコードが既にあればDB追記スキップ、日記も同様

set -euo pipefail

# ============================================================
# 環境変数読み込み
# ============================================================
source /home/ubuntu/.n8n-mcp/n8n/.env

NOTION_TOKEN="${NOTION_INTEGRATION_TOKEN}"
ACTIVITY_LOG_DB_ID="${NOTION_ACTIVITY_LOG_DB_ID}"
ACTIVITY_LOG_DS_ID="${NOTION_ACTIVITY_LOG_DS_ID}"
DIARY_DS_ID="${NOTION_DIARY_DS_ID}"
DASHBOARD="/home/ubuntu/shogun/dashboard.md"
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2025-09-03"

# 「音声での振り返り」H2ブロックID（固定: 殿の事前調査済み）
VOICE_REVIEW_BLOCK_ID="311e8d62-e4aa-81bf-a823-c89331a5a4ab"

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
# dashboard.md からデータ抽出（修正1: 日付照合で本日分のみ）
# ============================================================

# ストリーク数
STREAK=$(grep -oP 'ストリーク \| 🔥 \K[0-9]+(?=日目)' "${DASHBOARD}" | head -1 2>/dev/null || echo "0")

# 完了cmd数
COMPLETED=$(grep -oP '今日の完了 \| \K[0-9]+(?=/)' "${DASHBOARD}" | head -1 2>/dev/null || echo "0")

# 本日の戦果: TODAY(YYYY-MM-DD)と「本日の戦果（M/D）」の日付を照合して本日分のみ抽出
PARSE_RESULT=$(python3 - <<PYEOF
import re, sys, json
from datetime import datetime

dashboard_path = "${DASHBOARD}"
today_str = "${TODAY}"

with open(dashboard_path, encoding="utf-8") as f:
    content = f.read()

# TODAY を M/D 形式に変換
try:
    dt = datetime.strptime(today_str, "%Y-%m-%d")
    today_md = f"{dt.month}/{dt.day}"  # 例: "2/25"
except Exception:
    today_md = None

# 「## ✅ 本日の戦果（M/D JST）」セクションを全て探す
sections = re.findall(
    r'## ✅ 本日の戦果（(\d+/\d+) JST）\n(.*?)(?=\n## |\Z)',
    content, re.DOTALL
)

rows = []
if sections:
    # 日付が一致するセクションのみ使用（修正1）
    for date_label, section_body in sections:
        if today_md and date_label != today_md:
            continue  # 前日以前のセクションをスキップ
        for line in section_body.split("\n"):
            line = line.strip()
            if (line.startswith("|") and
                not line.startswith("| 時刻") and
                not line.startswith("|---") and
                len(line) > 4):
                rows.append(line)

# プロジェクト別件数とbullet用データを構築
projects_count = {}
bullets = []
summaries = []

for row in rows:
    cols = [c.strip() for c in row.split("|")]
    if len(cols) >= 5:
        time_col = cols[1].strip()
        proj = cols[2].strip()
        task = cols[3].strip()
        if proj and task:
            projects_count[proj] = projects_count.get(proj, 0) + 1
            # bullet: "{時刻} {戦場}: {任務先頭80文字}"
            bullets.append(f"{time_col} {proj}: {task[:80]}")
            summaries.append(task[:60])

# セッション概要: "{N}cmd完了({proj}×{n}, ...)"（修正2）
total = int("${COMPLETED}" or 0)
if projects_count:
    proj_parts = ", ".join(f"{p}×{n}" for p, n in sorted(projects_count.items(), key=lambda x: -x[1])[:4])
    session_summary = f"{total}cmd完了({proj_parts})"
else:
    session_summary = f"{total}cmd完了"

# 詳細: 各cmdの1行（修正2）
detail_lines = bullets[:20]
detail = "\n".join(detail_lines)[:1990]

# 要約: プロジェクト別の主要成果2-3行（修正3）
if projects_count:
    yoyaku_parts = []
    for proj in sorted(projects_count.keys(), key=lambda p: -projects_count[p])[:3]:
        proj_rows = [b for b in bullets if proj in b]
        if proj_rows:
            sample = proj_rows[0].split(": ", 1)[-1][:50] if ": " in proj_rows[0] else proj_rows[0][:50]
            yoyaku_parts.append(f"{proj}: {sample}他{projects_count[proj]}件")
    yoyaku = "。\n".join(yoyaku_parts) + "。" if yoyaku_parts else ""
else:
    yoyaku = f"{total}cmd完了。"

multi_select = [{"name": p} for p in list(projects_count.keys())[:5]]

result = {
    "session_summary": session_summary[:200],
    "detail": detail,
    "yoyaku": yoyaku[:500],
    "multi_select": multi_select,
    "bullets": bullets[:10],
    "projects": list(projects_count.keys())
}
print(json.dumps(result, ensure_ascii=False))
PYEOF
)

SESSION_SUMMARY=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['session_summary'])" 2>/dev/null || echo "${COMPLETED}cmd完了")
DETAIL=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['detail'])" 2>/dev/null || echo "")
YOYAKU=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['yoyaku'])" 2>/dev/null || echo "")
MULTI_SELECT_JSON=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['multi_select']))" 2>/dev/null || echo "[]")
BULLETS_JSON=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d['bullets']))" 2>/dev/null || echo "[]")
PROJECTS=$(echo "${PARSE_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d['projects']))" 2>/dev/null || echo "")

echo "[INFO] ストリーク=${STREAK}, 完了cmd=${COMPLETED}, プロジェクト=${PROJECTS}"
echo "[INFO] セッション概要: ${SESSION_SUMMARY}"

# PARSE_RESULTをtempファイルに書き出し（heredoc内json.loadsの\nエスケープ問題を回避）
PARSE_RESULT_FILE=$(mktemp /tmp/notion_parse_result.XXXXXX.json)
printf '%s' "${PARSE_RESULT}" > "${PARSE_RESULT_FILE}"
trap 'rm -f "${PARSE_RESULT_FILE}"' EXIT

# ============================================================
# 冪等性チェック (Notion DB検索)
# ============================================================

EXISTING=$(curl -s -X POST \
  "${NOTION_API}/data_sources/${ACTIVITY_LOG_DS_ID}/query" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: ${NOTION_VERSION}" \
  -d "{\"filter\": {\"property\": \"日付\", \"date\": {\"equals\": \"${TODAY}\"}}}")

EXISTING_COUNT=$(echo "${EXISTING}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(len(data.get('results', [])))
" 2>/dev/null || echo "0")

# ============================================================
# Notion DBレコード作成 or 既存URL取得
# ============================================================

ACTIVITY_LOG_URL=""

if [[ "${EXISTING_COUNT}" -gt 0 ]]; then
  # 既存レコードをPATCHで上書き更新（修正: スキップ→UPDATE）
  EXISTING_PAGE_ID=$(echo "${EXISTING}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
print(results[0].get('id', '') if results else '')
" 2>/dev/null || echo "")

  ACTIVITY_LOG_URL=$(echo "${EXISTING_PAGE_ID}" | python3 -c "
import sys
pid = sys.stdin.read().strip().replace('-', '')
print(f'https://www.notion.so/{pid}' if pid else '')
")

  echo "[INFO] ${TODAY} の活動ログを更新中 (ID: ${EXISTING_PAGE_ID})..."

  UPDATE_PAYLOAD=$(python3 - <<PYEOF
import json
with open("${PARSE_RESULT_FILE}") as _f:
    data = json.load(_f)
session_summary = data["session_summary"]
detail = data["detail"]
yoyaku = data["yoyaku"]
multi_select = data["multi_select"]
today = "${TODAY}"
completed = int("${COMPLETED}" or 0)
streak = int("${STREAK}" or 0)

payload = {
    "properties": {
        "セッション概要": {
            "title": [{"type": "text", "text": {"content": session_summary[:200]}}]
        },
        "日付": {"date": {"start": today}},
        "完了cmd数": {"number": completed},
        "ストリーク": {"number": streak},
        "プロジェクト": {"multi_select": multi_select},
        "詳細": {
            "rich_text": [{"type": "text", "text": {"content": detail[:2000]}}]
        },
        "要約": {
            "rich_text": [{"type": "text", "text": {"content": yoyaku[:500]}}]
        }
    }
}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
)

  UPDATE_RESP=$(curl -s -X PATCH \
    "${NOTION_API}/pages/${EXISTING_PAGE_ID}" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "${UPDATE_PAYLOAD}")

  UPDATE_STATUS=$(echo "${UPDATE_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'page':
    print('success')
else:
    print('error: ' + str(data.get('message', 'unknown')))
" 2>/dev/null || echo "error: parse failed")

  if [[ "${UPDATE_STATUS}" == "success" ]]; then
    echo "[SUCCESS] ${TODAY} の活動ログを更新しました。"
  else
    echo "[ERROR] 活動ログ更新失敗: ${UPDATE_STATUS}" >&2
  fi
else
  echo "[INFO] Notion DBにレコード作成中..."

  CREATE_PAYLOAD=$(python3 - <<PYEOF
import json

db_id = "${ACTIVITY_LOG_DB_ID}"
with open("${PARSE_RESULT_FILE}") as _f:
    data = json.load(_f)
session_summary = data["session_summary"]
detail = data["detail"]
yoyaku = data["yoyaku"]
multi_select = data["multi_select"]
today = "${TODAY}"
completed = int("${COMPLETED}" or 0)
streak = int("${STREAK}" or 0)

payload = {
    "parent": {"database_id": db_id},
    "properties": {
        "セッション概要": {
            "title": [{"type": "text", "text": {"content": session_summary[:200]}}]
        },
        "日付": {"date": {"start": today}},
        "完了cmd数": {"number": completed},
        "ストリーク": {"number": streak},
        "プロジェクト": {"multi_select": multi_select},
        "詳細": {
            "rich_text": [{"type": "text", "text": {"content": detail[:2000]}}]
        },
        "要約": {
            "rich_text": [{"type": "text", "text": {"content": yoyaku[:500]}}]
        }
    }
}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
)

  CREATE_RESP=$(curl -s -X POST \
    "${NOTION_API}/pages" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "${CREATE_PAYLOAD}")

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
    ACTIVITY_LOG_URL=$(echo "${CREATE_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
page_id = data.get('id', '').replace('-', '')
print(f'https://www.notion.so/{page_id}')
" 2>/dev/null || echo "")
  else
    echo "[ERROR] Notion DBレコード作成: 不明なエラー" >&2
  fi
fi

echo "[INFO] 活動ログURL: ${ACTIVITY_LOG_URL}"

# ============================================================
# 日記タスク検索
# ============================================================

echo "[INFO] 日記タスク検索: ${TODAY}日記"

DIARY_QUERY=$(curl -s -X POST \
  "${NOTION_API}/data_sources/${DIARY_DS_ID}/query" \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: ${NOTION_VERSION}" \
  -d "{\"filter\": {\"property\": \"タスク名\", \"title\": {\"contains\": \"${TODAY}\"}}}")

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
# 日記タスクのブロック確認 (冪等性チェック)
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
# 日記タスクへの追記（修正4: トグル形式、修正5: 挿入位置、修正6: リンク）
# ============================================================

if [[ "${HAS_CC_SECTION}" == "true" ]]; then
  echo "[INFO] 日記に「Claude Code活動」セクションが既に存在。追記スキップ。"
else
  echo "[INFO] 日記に「Claude Code活動」セクション追記中..."

  # トグルH2 + 子ブロック構築（修正4）
  APPEND_PAYLOAD=$(python3 - <<PYEOF
import json

completed = "${COMPLETED}"
streak = "${STREAK}"
bullets_raw = ${BULLETS_JSON}
activity_log_url = "${ACTIVITY_LOG_URL}"
voice_review_block_id = "${VOICE_REVIEW_BLOCK_ID}"

# 子ブロック: paragraph(完了/ストリーク) + paragraph(リンク) + bullet_list
children = [
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

# 活動ログリンク（修正6）
if activity_log_url:
    children.append({
        "object": "block",
        "type": "paragraph",
        "paragraph": {
            "rich_text": [{
                "type": "text",
                "text": {
                    "content": "📊 活動ログ詳細",
                    "link": {"url": activity_log_url}
                }
            }]
        }
    })

# bullet list (各cmd)
for bullet_text in bullets_raw:
    children.append({
        "object": "block",
        "type": "bulleted_list_item",
        "bulleted_list_item": {
            "rich_text": [{"type": "text", "text": {"content": str(bullet_text)[:200]}}]
        }
    })

# トグルH2ブロック（修正4: is_toggleable + children）
toggle_block = {
    "object": "block",
    "type": "heading_2",
    "heading_2": {
        "rich_text": [{"type": "text", "text": {"content": "Claude Code活動 🤖"}}],
        "is_toggleable": True,
        "children": children
    }
}

# 挿入位置: 「音声での振り返り」H2の直後（修正5）
payload = {
    "children": [toggle_block],
    "after": voice_review_block_id
}

print(json.dumps(payload, ensure_ascii=False))
PYEOF
)

  APPEND_RESP=$(curl -s -X PATCH \
    "${NOTION_API}/blocks/${DIARY_PAGE_ID}/children" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "${APPEND_PAYLOAD}")

  APPEND_STATUS=$(echo "${APPEND_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'list':
    print('success')
else:
    print('error: ' + str(data.get('message', 'unknown')))
" 2>/dev/null || echo "error: parse failed")

  if [[ "${APPEND_STATUS}" == "success" ]]; then
    echo "[SUCCESS] 日記へのClaude Code活動トグルセクション追記完了"
  else
    echo "[ERROR] 日記追記失敗: ${APPEND_STATUS}" >&2
    echo "[DEBUG] レスポンス: ${APPEND_RESP}" >&2
  fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] notion_session_log.sh 完了"
