#!/usr/bin/env bash
# artifact_register.sh — cmd 完了時の成果物 Drive アップロード + Notion 登録
#
# 使い方:
#   bash scripts/artifact_register.sh \
#     --cmd-id cmd_509 \
#     --project shogun \
#     --date 2026-04-16 \
#     --files "scripts/artifact_register.sh,tests/test_artifact_register.sh" \
#     [--dry-run]
#
# 設計書: projects/artifact-standardization/design.md §5.2

# ============================================================
# 0. 設定
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"  # cmd_507 修正内容を踏まえ固定

# ============================================================
# 1. 環境変数読み込み
# ============================================================
ENV_FILE="/home/ubuntu/.n8n-mcp/n8n/.env"
if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source <(grep -v '^#' "${ENV_FILE}" | grep '=')
    set +a
fi

# ============================================================
# 2. 引数パース
# ============================================================
CMD_ID=""
PROJECT=""
DATE=""
FILES_CSV=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cmd-id)   CMD_ID="$2";   shift 2 ;;
        --project)  PROJECT="$2";  shift 2 ;;
        --date)     DATE="$2";     shift 2 ;;
        --files)    FILES_CSV="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true;  shift ;;
        *)
            echo "[ERROR] 不明な引数: $1" >&2
            echo "使い方: $0 --cmd-id <id> --project <proj> --date <YYYY-MM-DD> --files <csv> [--dry-run]" >&2
            exit 1
            ;;
    esac
done

# 必須パラメータ検証
if [[ -z "${CMD_ID}" || -z "${PROJECT}" || -z "${DATE}" || -z "${FILES_CSV}" ]]; then
    echo "[ERROR] 必須パラメータが不足しています。" >&2
    echo "使い方: $0 --cmd-id <id> --project <proj> --date <YYYY-MM-DD> --files <csv> [--dry-run]" >&2
    exit 1
fi

# ============================================================
# 3. 設定値の確認・デフォルト値
# ============================================================
NOTION_TOKEN="${NOTION_INTEGRATION_TOKEN:-${NOTION_BEARER_TOKEN:-}}"
ARTIFACTS_DB_ID="${NOTION_ARTIFACTS_DB_ID:-}"
WEBHOOK_URL="${N8N_DRIVE_UPLOAD_WEBHOOK_URL:-}"
ROOT_FOLDER_ID="${GOOGLE_DRIVE_OUTPUT_FOLDER_ID:-}"

if [[ -z "${WEBHOOK_URL}" ]] && [[ -f "${SCRIPT_DIR}/scripts/drive_upload_webhook_url.txt" ]]; then
    WEBHOOK_URL=$(cat "${SCRIPT_DIR}/scripts/drive_upload_webhook_url.txt" 2>/dev/null || echo "")
fi

SUBFOLDER_NAME="${CMD_ID}_${PROJECT}_${DATE}"

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] artifact_register.sh 起動"
    echo "[DRY-RUN] cmd-id: ${CMD_ID}"
    echo "[DRY-RUN] project: ${PROJECT}"
    echo "[DRY-RUN] date: ${DATE}"
    echo "[DRY-RUN] files: ${FILES_CSV}"
    echo "[DRY-RUN] subfolder: ${SUBFOLDER_NAME}"
    echo "[DRY-RUN] webhook_url: ${WEBHOOK_URL}"
    echo "[DRY-RUN] root_folder_id: ${ROOT_FOLDER_ID}"
    echo "[DRY-RUN] notion_db_id: ${ARTIFACTS_DB_ID}"
fi

# ============================================================
# 4. Drive サブフォルダ create-or-find (冪等)
# ============================================================
# 注: 直接 Drive API を呼ぶには OAuth token が必要。
#     環境に credentials がない場合はルートフォルダにフォールバック。

find_or_create_drive_subfolder() {
    local subfolder_name="$1"
    local parent_id="$2"

    if [[ -z "${parent_id}" ]]; then
        echo "${parent_id}"
        return 0
    fi

    # Python で Drive API 呼び出し（credentials がない場合は "" を返す）
    local folder_id
    folder_id=$(python3 - "${subfolder_name}" "${parent_id}" <<'PYEOF' 2>/dev/null
import sys, json, os, urllib.request, urllib.error

subfolder_name = sys.argv[1]
parent_id = sys.argv[2]

# credentials の検索 (application default credentials)
import subprocess
try:
    result = subprocess.run(
        ['gcloud', 'auth', 'print-access-token'],
        capture_output=True, text=True, timeout=5
    )
    token = result.stdout.strip()
    if not token:
        sys.exit(0)
except Exception:
    sys.exit(0)

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# 既存フォルダ検索
search_url = (
    "https://www.googleapis.com/drive/v3/files"
    f"?q=name+%3D+%27{urllib.parse.quote(subfolder_name)}%27"
    f"+and+%27{parent_id}%27+in+parents"
    "+and+mimeType+%3D+%27application%2Fvnd.google-apps.folder%27"
    "+and+trashed+%3D+false"
    "&fields=files(id,name)"
)
import urllib.parse
req = urllib.request.Request(search_url, headers={"Authorization": f"Bearer {token}"})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
    files = data.get("files", [])
    if files:
        print(files[0]["id"])
        sys.exit(0)
except Exception:
    sys.exit(0)

# 新規フォルダ作成
create_url = "https://www.googleapis.com/drive/v3/files"
payload = {
    "name": subfolder_name,
    "mimeType": "application/vnd.google-apps.folder",
    "parents": [parent_id]
}
req = urllib.request.Request(
    create_url,
    data=json.dumps(payload).encode('utf-8'),
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    method="POST"
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
    print(data.get("id", ""))
except Exception:
    pass
PYEOF
    )

    echo "${folder_id}"
}

TARGET_FOLDER_ID="${ROOT_FOLDER_ID}"

if [[ "${DRY_RUN}" == "false" ]]; then
    subfolder_id=$(find_or_create_drive_subfolder "${SUBFOLDER_NAME}" "${ROOT_FOLDER_ID}")
    if [[ -n "${subfolder_id}" ]]; then
        TARGET_FOLDER_ID="${subfolder_id}"
        echo "[INFO] Drive サブフォルダ使用: ${SUBFOLDER_NAME} (${TARGET_FOLDER_ID})"
    else
        echo "[WARN] Drive サブフォルダ作成不可。ルートフォルダにフォールバック: ${ROOT_FOLDER_ID}"
    fi
fi

# ============================================================
# 5. ファイル処理 (Drive + Notion)
# ============================================================
IFS=',' read -ra FILES_ARRAY <<< "${FILES_CSV}"

UPLOADED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0
NOTION_CREATED=0
NOTION_SKIPPED=0
NOTION_ERROR=0

process_files() {
    local webhook_url="$1"
    local folder_id="$2"
    local notion_token="$3"
    local db_id="$4"

    python3 - "${webhook_url}" "${folder_id}" "${notion_token}" \
      "${db_id}" "${CMD_ID}" "${PROJECT}" "${DATE}" \
      "${DRY_RUN}" "${SCRIPT_DIR}" <<PYEOF
import sys, json, base64, os, re, time, urllib.request, urllib.error

webhook_url  = sys.argv[1]
folder_id    = sys.argv[2]
notion_token = sys.argv[3]
db_id        = sys.argv[4]
cmd_id       = sys.argv[5]
project      = sys.argv[6]
date         = sys.argv[7]
dry_run      = sys.argv[8].lower() == "true"
script_dir   = sys.argv[9]
api_base     = "https://api.notion.com/v1"
notion_ver   = "2022-06-28"

files_csv = """${FILES_CSV}"""
files_list = [f.strip() for f in files_csv.split(',') if f.strip()]

uploaded   = 0
skipped    = 0
error      = 0
n_created  = 0
n_skipped  = 0
n_error    = 0

def notion_request(method, url, data=None, retries=3):
    headers = {
        "Authorization": f"Bearer {notion_token}",
        "Content-Type": "application/json",
        "Notion-Version": notion_ver
    }
    body = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            resp_body = json.loads(e.read().decode('utf-8'))
            # 5xx → exponential backoff
            if e.code >= 500 and attempt < retries - 1:
                wait = 2 ** attempt
                print(f"[WARN] Notion {e.code} エラー。{wait}s後リトライ ({attempt+1}/{retries})", flush=True)
                time.sleep(wait)
                continue
            return resp_body
        except Exception as ex:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            return {"error": str(ex)}
    return {"error": "max retries exceeded"}

for rel_path in files_list:
    filepath = os.path.join(script_dir, rel_path) if not os.path.isabs(rel_path) else rel_path
    filename = os.path.basename(filepath)

    if not os.path.isfile(filepath):
        print(f"[WARN] ファイル不存在、スキップ: {rel_path}", flush=True)
        skipped += 1
        continue

    print(f"[INFO] 処理中: {filename}", flush=True)

    # ---- Drive アップロード ----
    web_view_link = ""
    if dry_run:
        print(f"[DRY-RUN] Drive アップロードをスキップ: {filename}", flush=True)
        uploaded += 1
    elif not webhook_url:
        print(f"[WARN] webhook URL未設定。Drive アップロードをスキップ: {filename}", flush=True)
        skipped += 1
        continue
    else:
        try:
            with open(filepath, 'rb') as f:
                content_b64 = base64.b64encode(f.read()).decode('ascii')
        except Exception as e:
            print(f"[ERROR] ファイル読込失敗: {filename}: {e}", flush=True)
            error += 1
            continue

        ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
        mime_map = {'drawio': 'application/xml', 'sh': 'text/x-shellscript', 'py': 'text/x-python'}
        mime_type = mime_map.get(ext, 'text/plain')

        payload = {
            "filename": filename,
            "content_base64": content_b64,
            "mime_type": mime_type
        }
        if folder_id:
            payload["folder_id"] = folder_id

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
            if file_id:
                print(f"[INFO] Drive アップロード完了: {filename} (action: {result.get('action', '?')})", flush=True)
                uploaded += 1
            else:
                print(f"[ERROR] Drive アップロード失敗 (file_id未取得): {filename}", flush=True)
                error += 1
                continue
        except Exception as e:
            print(f"[ERROR] Drive アップロード例外: {filename}: {e}", flush=True)
            error += 1
            continue

    # ---- Notion 登録 (冪等) ----
    if dry_run:
        print(f"[DRY-RUN] Notion 登録をスキップ: {filename}", flush=True)
        n_created += 1
        continue

    if not notion_token or not db_id:
        print(f"[WARN] Notion 設定未完了。登録スキップ: {filename}", flush=True)
        n_skipped += 1
        continue

    # 冪等性チェック
    query_resp = notion_request("POST", f"{api_base}/databases/{db_id}/query", {
        "filter": {"property": "ファイル名", "title": {"equals": filename}}
    })
    if query_resp.get("results"):
        print(f"[INFO] Notion 既存レコードあり、スキップ: {filename}", flush=True)
        n_skipped += 1
        continue

    # ファイル種別
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
    file_type = ext if ext in ("md", "drawio", "sh", "py") else "other"

    properties = {
        "ファイル名": {"title": [{"text": {"content": filename}}]},
        "cmd番号":   {"rich_text": [{"text": {"content": cmd_id}}]},
        "日付":      {"date": {"start": date}},
        "ファイル種別": {"select": {"name": file_type}},
        "プロジェクト": {"select": {"name": project}}
    }
    if web_view_link:
        properties["Driveリンク"] = {"url": web_view_link}

    create_resp = notion_request("POST", f"{api_base}/pages", {
        "parent": {"database_id": db_id},
        "properties": properties
    })
    if create_resp.get("object") == "page":
        print(f"[INFO] Notion 成果物DBレコード作成: {filename}", flush=True)
        n_created += 1
    else:
        print(f"[ERROR] Notion レコード作成失敗: {filename}: {create_resp.get('message', create_resp)}", flush=True)
        n_error += 1

print(f"[SUMMARY] Drive: {uploaded}件アップロード, {skipped}件スキップ, {error}件エラー", flush=True)
print(f"[SUMMARY] Notion: {n_created}件作成, {n_skipped}件スキップ, {n_error}件エラー", flush=True)
PYEOF
}

if [[ -z "${WEBHOOK_URL}" ]] && [[ "${DRY_RUN}" == "false" ]]; then
    echo "[WARN] Drive Webhook URL未設定。Drive アップロードをスキップします。"
fi

if [[ -z "${NOTION_TOKEN}" ]] && [[ "${DRY_RUN}" == "false" ]]; then
    echo "[WARN] NOTION_INTEGRATION_TOKEN未設定。Notion 登録をスキップします。"
fi

if [[ -z "${ARTIFACTS_DB_ID}" ]] && [[ "${DRY_RUN}" == "false" ]]; then
    echo "[WARN] NOTION_ARTIFACTS_DB_ID未設定。Notion 登録をスキップします。"
fi

process_files \
    "${WEBHOOK_URL}" \
    "${TARGET_FOLDER_ID}" \
    "${NOTION_TOKEN}" \
    "${ARTIFACTS_DB_ID}"

echo "[INFO] artifact_register.sh 完了 (cmd-id: ${CMD_ID}, dry-run: ${DRY_RUN})"
