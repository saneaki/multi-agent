#!/usr/bin/env bash
# notion_session_log.sh
# Claude Codeセッション活動をNotion DBに記録し、日記タスクに追記する
# Stop hookから呼び出される: bash /home/ubuntu/shogun/scripts/notion_session_log.sh
# 冪等性: 同日付のレコードが既にあればDB追記スキップ、日記も同様

set -euo pipefail

# ============================================================
# flock排他制御（多重起動防止）
# ============================================================
LOCKFILE="/tmp/notion_session_log.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Already running, skipping"; exit 0; }

# ============================================================
# 環境変数読み込み
# ============================================================
source /home/ubuntu/.n8n-mcp/n8n/.env

NOTION_TOKEN="${NOTION_INTEGRATION_TOKEN}"
ACTIVITY_LOG_DB_ID="${NOTION_ACTIVITY_LOG_DB_ID}"
ACTIVITY_LOG_DS_ID="${NOTION_ACTIVITY_LOG_DS_ID}"
DIARY_DS_ID="${NOTION_DIARY_DS_ID}"
DIARY_DB_ID="${NOTION_DIARY_DB_ID:-1a4e8d62-e4aa-81f1-8ede-c239ea53299b}"
DASHBOARD="/home/ubuntu/shogun/dashboard.md"
TODAY=$(TZ=Asia/Tokyo date +%Y-%m-%d)
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

VOICE_REVIEW_BLOCK_ID=""  # 動的検索で設定（機能C）

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
COMPLETED=$(grep -oP '今日の完了 \| \K[0-9]+' "${DASHBOARD}" | head -1 2>/dev/null || echo "0")

# 本日の戦果: TODAY(YYYY-MM-DD)と「本日の戦果（M/D）」の日付を照合して本日分のみ抽出
PARSE_RESULT=$(python3 - <<PYEOF
import re, sys, json
from datetime import datetime

dashboard_path = "${DASHBOARD}"
today_str = "${TODAY}"

with open(dashboard_path, encoding="utf-8", errors="replace") as f:
    content = f.read()

# TODAY を M/D 形式に変換
try:
    dt = datetime.strptime(today_str, "%Y-%m-%d")
    today_md = f"{dt.month}/{dt.day}"  # 例: "2/25"
except Exception:
    today_md = None

# 「## ✅ ...（M/D JST）...」セクションを全て探す（本日/昨日/一昨日等すべて対象）
sections = re.findall(
    r'## ✅ [^\n（]*（(\d+/\d+) JST）[^\n]*\n(.*?)(?=\n## |\Z)',
    content, re.DOTALL
)

rows = []
if sections:
    # TODAYと完全一致するセクションを探す
    matched_sections = [(d, b) for d, b in sections if today_md and d == today_md]

    # 一致なし → 警告のみ（誤データ書込み防止のため空データで返す）
    if not matched_sections and today_md and sections:
        available = [d for d, _ in sections]
        print(f"[WARN] TODAY({today_md})に一致する戦果セクションが見つかりません。利用可能: {available}。空データで続行。", file=sys.stderr)

    for date_label, section_body in matched_sections:
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
        result = cols[4].strip() if len(cols) > 4 else ""
        if proj and task:
            projects_count[proj] = projects_count.get(proj, 0) + 1
            # 結果列を含むbullet形式
            if result:
                bullets.append(f"{time_col} {proj}: {task[:100]} → {result[:80]}")
            else:
                bullets.append(f"{time_col} {proj}: {task[:150]}")
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
    "bullets": bullets[:50],
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
UPLOADED_FILES_TMPFILE=""
trap 'rm -f "${PARSE_RESULT_FILE}" "${UPLOADED_FILES_TMPFILE}"' EXIT

# ============================================================
# ローカルステートキャッシュ読み込み
# ============================================================
STATE_FILE="/tmp/notion_session_log_state_${TODAY}.json"
CACHED_PAGE_ID=""

if [[ -f "${STATE_FILE}" ]]; then
  CACHED_PAGE_ID=$(python3 -c "
import json, sys
try:
    with open('${STATE_FILE}') as f:
        d = json.load(f)
    pid = d.get('page_id', '')
    print(pid if pid else '')
except Exception:
    print('')
" 2>/dev/null || echo "")
  if [[ -n "${CACHED_PAGE_ID}" ]]; then
    echo "[INFO] ステートキャッシュヒット (page_id: ${CACHED_PAGE_ID})"
  fi
fi

# ============================================================
# Notion DBレコード作成 or 既存URL取得
# ============================================================

ACTIVITY_LOG_URL=""
ACTIVITY_LOG_PAGE_ID=""

# UPDATE_PAYLOADを共通化（PATCH用）
_build_update_payload() {
  local page_id="${1}"
  python3 - <<PYEOF
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
}

# ---------- キャッシュヒット: Notion APIクエリをスキップしてPATCHへ ----------
if [[ -n "${CACHED_PAGE_ID}" ]]; then
  ACTIVITY_LOG_PAGE_ID="${CACHED_PAGE_ID}"
  ACTIVITY_LOG_URL=$(python3 -c "
pid = '${CACHED_PAGE_ID}'.replace('-', '')
print(f'https://www.notion.so/{pid}' if pid else '')
")
  echo "[INFO] ${TODAY} の活動ログをキャッシュ経由で更新中 (ID: ${CACHED_PAGE_ID})..."

  UPDATE_PAYLOAD=$(_build_update_payload "${CACHED_PAGE_ID}")
  UPDATE_RESP=$(curl -s -X PATCH \
    "${NOTION_API}/pages/${CACHED_PAGE_ID}" \
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
    echo "[SUCCESS] ${TODAY} の活動ログをキャッシュ経由で更新しました。"
    # ステートのupdated_atを更新
    python3 -c "
import json
with open('${STATE_FILE}') as f:
    d = json.load(f)
import datetime
d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
with open('${STATE_FILE}', 'w') as f:
    json.dump(d, f)
" 2>/dev/null || true
  else
    echo "[WARN] キャッシュ経由PATCH失敗 (${UPDATE_STATUS})。キャッシュをクリアして通常フローへフォールバック。" >&2
    CACHED_PAGE_ID=""
    ACTIVITY_LOG_PAGE_ID=""
    ACTIVITY_LOG_URL=""
    rm -f "${STATE_FILE}" 2>/dev/null || true
  fi
fi

# ---------- キャッシュミス or キャッシュPATCH失敗: 通常フロー ----------
if [[ -z "${CACHED_PAGE_ID}" ]]; then

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
  ACTIVITY_LOG_PAGE_ID="${EXISTING_PAGE_ID}"

  echo "[INFO] ${TODAY} の活動ログを更新中 (ID: ${EXISTING_PAGE_ID})..."

  UPDATE_PAYLOAD=$(_build_update_payload "${EXISTING_PAGE_ID}")

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
    # ステートファイルに保存（後続セッションはキャッシュヒットする）
    python3 -c "
import json, datetime
with open('${STATE_FILE}', 'w') as f:
    json.dump({'page_id': '${EXISTING_PAGE_ID}', 'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat()}, f)
" 2>/dev/null || true
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
    ACTIVITY_LOG_PAGE_ID="${CREATED_ID}"
    ACTIVITY_LOG_URL=$(echo "${CREATE_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
page_id = data.get('id', '').replace('-', '')
print(f'https://www.notion.so/{page_id}')
" 2>/dev/null || echo "")
    # ステートファイルに保存（後続セッションはキャッシュヒットする）
    python3 -c "
import json, datetime
with open('${STATE_FILE}', 'w') as f:
    json.dump({'page_id': '${CREATED_ID}', 'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat()}, f)
" 2>/dev/null || true
    echo "[INFO] ステートファイル保存: ${STATE_FILE}"
  else
    echo "[ERROR] Notion DBレコード作成: 不明なエラー" >&2
  fi
fi

fi  # end キャッシュミス or キャッシュPATCH失敗フロー

echo "[INFO] 活動ログURL: ${ACTIVITY_LOG_URL}"

# ============================================================
# 機能A: output/ → Drive アップロード
# ============================================================

UPLOAD_STATE_FILE="/home/ubuntu/shogun/.upload_state.json"
UPLOADED_FILES_TMPFILE=$(mktemp /tmp/notion_uploaded_files.XXXXXX.json)
echo "[]" > "${UPLOADED_FILES_TMPFILE}"

upload_output_files() {
  local webhook_url="${N8N_DRIVE_UPLOAD_WEBHOOK_URL:-}"
  local folder_id="${GOOGLE_DRIVE_OUTPUT_FOLDER_ID:-}"
  local webhook_txt="/home/ubuntu/shogun/scripts/drive_upload_webhook_url.txt"

  if [[ -z "${webhook_url}" ]] && [[ -f "${webhook_txt}" ]]; then
    webhook_url=$(cat "${webhook_txt}" 2>/dev/null || echo "")
  fi

  if [[ -z "${webhook_url}" ]]; then
    echo "[WARN] Drive Webhook URL未設定。Drive アップロードをスキップ。"
    return 0
  fi

  echo "[INFO] 成果物 → Drive アップロード開始 (webhook: ${webhook_url})"

  python3 - "${UPLOAD_STATE_FILE}" "${webhook_url}" "${folder_id}" \
    "/home/ubuntu/shogun/output" "${TODAY}" "${UPLOADED_FILES_TMPFILE}" <<'PYEOF'
import sys, json, base64, urllib.request, urllib.error, os, glob

state_file = sys.argv[1]
webhook_url = sys.argv[2]
folder_id = sys.argv[3]
output_dir = sys.argv[4]
today = sys.argv[5]
uploaded_file = sys.argv[6]

state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except Exception:
        state = {}

# Multi-directory scan configuration
project_root = os.path.dirname(output_dir)  # /home/ubuntu/shogun
scan_configs = [
    (output_dir, ['**/*.md', '**/*.drawio'], 'output'),
    (os.path.join(project_root, 'context'), ['**/*.md'], 'context'),
    (os.path.join(project_root, 'instructions'), ['**/*.md'], 'instructions'),
    (os.path.join(project_root, 'scripts'), ['**/*.sh', '**/*.py'], 'scripts'),
]
skills_dir = '/home/ubuntu/.claude/skills'
if os.path.isdir(skills_dir):
    scan_configs.append((skills_dir, ['**/*.md'], 'skills'))

file_entries = []  # (filepath, category, scan_dir)
for scan_dir, patterns, category in scan_configs:
    if not os.path.isdir(scan_dir):
        continue
    for pattern in patterns:
        for fp in glob.glob(os.path.join(scan_dir, pattern), recursive=True):
            file_entries.append((fp, category, scan_dir))
file_entries = sorted(set(file_entries), key=lambda x: x[0])

uploaded = []
skip_count = 0
error_count = 0
upload_count = 0

for filepath, category, source_dir in file_entries:
    filename = os.path.basename(filepath)
    rel_path = os.path.relpath(filepath, source_dir)
    state_key = filename if category == 'output' else f"{category}/{rel_path}"
    if category == 'output':
        display_name = filename
    elif '/' in rel_path:
        display_name = rel_path.replace('/', '_')
    else:
        display_name = filename
    if state_key in state:
        skip_count += 1
        continue
    try:
        with open(filepath, 'rb') as f:
            content_b64 = base64.b64encode(f.read()).decode('ascii')
    except Exception as e:
        print(f"[ERROR] ファイル読込失敗: {display_name}: {e}", flush=True)
        error_count += 1
        continue

    ext = filename.rsplit('.', 1)[-1] if '.' in filename else ''
    mime_map = {'drawio': 'application/xml', 'sh': 'text/x-shellscript', 'py': 'text/x-python'}
    mime_type = mime_map.get(ext, 'text/plain')
    payload = {
        "filename": display_name,
        "content_base64": content_b64,
        "mime_type": mime_type,
        "folder_id": folder_id
    }
    try:
        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode('utf-8'))
        file_id = result.get('file_id', result.get('id', ''))
        web_view_link = result.get('web_view_link', result.get('webViewLink', ''))
    except Exception as e:
        print(f"[ERROR] アップロード失敗: {display_name}: {e}", flush=True)
        error_count += 1
        continue

    if file_id:
        state[state_key] = {"date": today, "file_id": file_id, "web_view_link": web_view_link}
        uploaded.append({
            "filename": display_name,
            "filepath": filepath,
            "file_id": file_id,
            "web_view_link": web_view_link,
            "category": category
        })
        upload_count += 1
        print(f"[INFO] アップロード完了: {display_name}", flush=True)
    else:
        print(f"[ERROR] アップロード失敗（file_id取得不可）: {display_name}", flush=True)
        error_count += 1

if upload_count > 0:
    with open(state_file, 'w') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

with open(uploaded_file, 'w') as f:
    json.dump(uploaded, f, ensure_ascii=False)

print(f"[INFO] アップロード: {upload_count}件完了, {skip_count}件スキップ, {error_count}件エラー", flush=True)
PYEOF
}

# ============================================================
# 機能B: Notion 成果物DB記録
# ============================================================

record_artifacts_to_notion() {
  local artifacts_db_id="${NOTION_ARTIFACTS_DB_ID:-}"
  if [[ -z "${artifacts_db_id}" ]]; then
    echo "[WARN] NOTION_ARTIFACTS_DB_ID未設定。成果物DB記録をスキップ。"
    return 0
  fi

  local uploaded_count
  uploaded_count=$(python3 -c "import json; d=json.load(open('${UPLOADED_FILES_TMPFILE}')); print(len(d))" 2>/dev/null || echo "0")
  if [[ "${uploaded_count}" -eq 0 ]]; then
    echo "[INFO] アップロード済みファイルなし。成果物DB記録スキップ。"
    return 0
  fi

  echo "[INFO] Notion 成果物DB記録開始 (${uploaded_count}件)..."

  python3 - "${UPLOADED_FILES_TMPFILE}" "${NOTION_TOKEN}" "${NOTION_API}" \
    "2022-06-28" "${artifacts_db_id}" "${TODAY}" "${ACTIVITY_LOG_PAGE_ID}" <<'PYEOF'
import sys, json, re, urllib.request, urllib.error

uploaded_file = sys.argv[1]
token = sys.argv[2]
api_base = sys.argv[3]
api_version = sys.argv[4]
db_id = sys.argv[5]
today = sys.argv[6]
activity_log_page_id = sys.argv[7] if len(sys.argv) > 7 else ""

with open(uploaded_file) as f:
    uploaded = json.load(f)

def notion_request(method, url, data=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Notion-Version": api_version
    }
    body = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

created = 0
skipped = 0
errors = 0

for item in uploaded:
    filename = item["filename"]
    web_view_link = item.get("web_view_link", "")

    query_resp = notion_request("POST", f"{api_base}/databases/{db_id}/query", {
        "filter": {"property": "ファイル名", "title": {"equals": filename}}
    })
    if query_resp.get("results"):
        existing_page = query_resp["results"][0]
        existing_page_id = existing_page.get("id", "")
        existing_relation = existing_page.get("properties", {}).get("活動ログ", {}).get("relation", [])
        if activity_log_page_id and not existing_relation:
            patch_resp = notion_request("PATCH", f"{api_base}/pages/{existing_page_id}", {
                "properties": {"活動ログ": {"relation": [{"id": activity_log_page_id}]}}
            })
            if patch_resp.get("object") == "page":
                print(f"[INFO] 既存レコードにリレーション追加: {filename}")
            else:
                print(f"[WARN] 既存レコードリレーション追加失敗: {filename}: {patch_resp.get('message', patch_resp)}", file=sys.stderr)
        else:
            print(f"[INFO] スキップ（既存・リレーション設定済み）: {filename}")
        skipped += 1
        continue

    cmd_match = re.search(r'cmd_\d+', filename)
    cmd_num = cmd_match.group(0) if cmd_match else ""

    filepath = item.get("filepath", "")
    category = item.get("category", "output")
    parts = filepath.split("/")
    project = ""
    if category == "output":
        try:
            output_idx = next(i for i, p in enumerate(parts) if p == "output")
            if output_idx + 1 < len(parts) - 1:
                project = parts[output_idx + 1]
        except StopIteration:
            pass
    else:
        project = category

    ext = filename.rsplit(".", 1)[-1] if "." in filename else "other"
    file_type = ext if ext in ("md", "drawio", "sh", "py") else "other"

    properties = {
        "ファイル名": {"title": [{"text": {"content": filename}}]},
        "cmd番号": {"rich_text": [{"text": {"content": cmd_num}}]},
        "日付": {"date": {"start": today}},
        "ファイル種別": {"select": {"name": file_type}}
    }
    if project:
        properties["プロジェクト"] = {"select": {"name": project}}
    if web_view_link:
        properties["Driveリンク"] = {"url": web_view_link}
    if activity_log_page_id:
        properties["活動ログ"] = {"relation": [{"id": activity_log_page_id}]}

    create_resp = notion_request("POST", f"{api_base}/pages", {
        "parent": {"database_id": db_id},
        "properties": properties
    })

    if create_resp.get("object") == "page":
        print(f"[INFO] 成果物DBレコード作成: {filename}")
        created += 1
    else:
        print(f"[ERROR] レコード作成失敗: {filename}: {create_resp.get('message', create_resp)}", file=sys.stderr)
        errors += 1

print(f"[INFO] 成果物DB記録: {created}件作成, {skipped}件スキップ, {errors}件エラー")
PYEOF
}

upload_output_files
record_artifacts_to_notion

# ============================================================
# 日記タスク検索
# ============================================================

echo "[INFO] 日記タスク検索: ${TODAY}日記"

DIARY_QUERY=$(curl -s -X POST \
  "${NOTION_API}/databases/${DIARY_DB_ID}/query" \
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

# フォールバック: 1日前の日付でも検索（日記ページ作成日ずれ対応）
if [[ -z "${DIARY_PAGE_ID}" ]]; then
  YESTERDAY=$(TZ=Asia/Tokyo date -d "${TODAY} -1 day" +%Y-%m-%d)
  echo "[WARN] ${TODAY}の日記が見つからず。フォールバック: ${YESTERDAY}日記を検索"
  DIARY_QUERY_FB=$(curl -s -X POST \
    "${NOTION_API}/databases/${DIARY_DB_ID}/query" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Notion-Version: ${NOTION_VERSION}" \
    -d "{\"filter\": {\"property\": \"タスク名\", \"title\": {\"contains\": \"${YESTERDAY}\"}}}")
  DIARY_PAGE_ID=$(echo "${DIARY_QUERY_FB}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
if results:
    print(results[0].get('id', ''))
else:
    print('')
" 2>/dev/null || echo "")
fi

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

# 機能C: VOICE_REVIEW_BLOCK_ID 動的検索
VOICE_REVIEW_BLOCK_ID=$(echo "${BLOCKS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
for block in results:
    block_type = block.get('type', '')
    if block_type in ('heading_2', 'heading_1', 'heading_3'):
        texts = block.get(block_type, {}).get('rich_text', [])
        text = ''.join(t.get('plain_text', '') for t in texts)
        if '音声での振り返り' in text:
            print(block.get('id', ''))
            sys.exit(0)
print('')
" 2>/dev/null || echo "")

if [[ -n "${VOICE_REVIEW_BLOCK_ID}" ]]; then
  echo "[INFO] 「音声での振り返り」ブロックID取得: ${VOICE_REVIEW_BLOCK_ID}"
else
  echo "[INFO] 「音声での振り返り」ブロックが見つからない。ページ末尾に追記。"
fi

CC_BLOCK_ID=$(echo "${BLOCKS}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = data.get('results', [])
for block in results:
    block_type = block.get('type', '')
    if block_type in ('heading_2', 'heading_1', 'heading_3'):
        texts = block.get(block_type, {}).get('rich_text', [])
        text = ''.join(t.get('plain_text', '') for t in texts)
        if 'Claude Code活動' in text:
            print(block.get('id', ''))
            sys.exit(0)
print('')
" 2>/dev/null || echo "")

# ============================================================
# 日記タスクへの追記（修正4: トグル形式、修正5: 挿入位置、修正6: リンク）
# ============================================================

if [[ -n "${CC_BLOCK_ID}" ]]; then
  echo "[INFO] 既存「Claude Code活動」セクション削除中 (block_id: ${CC_BLOCK_ID})..."
  DELETE_RESP=$(curl -s -X DELETE \
    "${NOTION_API}/blocks/${CC_BLOCK_ID}" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}")
  DELETE_STATUS=$(echo "${DELETE_RESP}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('object') == 'block':
    print('success')
else:
    print('error: ' + str(data.get('message', 'unknown')))
" 2>/dev/null || echo "error: parse failed")
  if [[ "${DELETE_STATUS}" == "success" ]]; then
    echo "[INFO] 既存セクション削除完了"
  else
    echo "[WARN] 既存セクション削除失敗: ${DELETE_STATUS}" >&2
  fi
fi

echo "[INFO] 日記に「Claude Code活動」セクション追記中..."

# トグルH2 + 子ブロック構築（修正4, 修正7: heredoc single-quote + env vars でサロゲート回避）
APPEND_PAYLOAD=$(COMPLETED="${COMPLETED}" STREAK="${STREAK}" \
  ACTIVITY_LOG_URL="${ACTIVITY_LOG_URL}" \
  VOICE_REVIEW_BLOCK_ID="${VOICE_REVIEW_BLOCK_ID}" \
  python3 - "${PARSE_RESULT_FILE}" <<'PYEOF'
import json, sys, os

parse_result_file = sys.argv[1]
with open(parse_result_file) as _f:
    _data = json.load(_f)
bullets_raw = _data.get("bullets", [])

completed = os.environ.get("COMPLETED", "0")
streak = os.environ.get("STREAK", "0")
activity_log_url = os.environ.get("ACTIVITY_LOG_URL", "")
voice_review_block_id = os.environ.get("VOICE_REVIEW_BLOCK_ID", "")

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
            "rich_text": [{"type": "text", "text": {"content": str(bullet_text)[:300]}}]
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
# VOICE_REVIEW_BLOCK_IDが空の場合はafterを省略してページ末尾に追記
payload = {"children": [toggle_block]}
if voice_review_block_id:
    payload["after"] = voice_review_block_id

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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] notion_session_log.sh 完了"
