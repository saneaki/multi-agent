#!/usr/bin/env bash
# gas_run_oauth.sh — Execute Apps Script function via OAuth refresh_token (.clasprc.json)
set -euo pipefail

LOG_FILE="/tmp/gas_run_oauth.log"
: > "$LOG_FILE"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG_FILE"
}

notify_error() {
  local message="$1"
  bash scripts/notify.sh "$message" gas_oauth_error || true
}

die() {
  log "ERROR: $*"
  exit 1
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [FUNCTION_NAME] [--script-id ID] [--clasprc PATH] [--project-dir DIR]

Arguments:
  FUNCTION_NAME       GAS function name to execute (default: main)

Options:
  --script-id ID      Apps Script scriptId (overrides .clasp.json)
  --clasprc PATH      Path to .clasprc.json (default: /home/ubuntu/.clasprc.json)
  --project-dir DIR   GAS project directory for .clasp.json lookup (default: /home/ubuntu/gas-mail-manager)
USAGE
}

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

FUNCTION_NAME="main"
SCRIPT_ID=""
CLASPRC="/home/ubuntu/.clasprc.json"
PROJECT_DIR="/home/ubuntu/gas-mail-manager"

if [[ $# -gt 0 && "$1" != --* ]]; then
  FUNCTION_NAME="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --script-id)
      SCRIPT_ID="${2:-}"
      [[ -n "$SCRIPT_ID" ]] || die "--script-id requires a value"
      shift 2
      ;;
    --clasprc)
      CLASPRC="${2:-}"
      [[ -n "$CLASPRC" ]] || die "--clasprc requires a value"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="${2:-}"
      [[ -n "$PROJECT_DIR" ]] || die "--project-dir requires a value"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -f "$CLASPRC" ]] || die ".clasprc.json not found: $CLASPRC"

if [[ -z "$SCRIPT_ID" ]]; then
  [[ -f "$PROJECT_DIR/.clasp.json" ]] || die ".clasp.json not found in $PROJECT_DIR (or pass --script-id)"
  SCRIPT_ID="$(python3 - "$PROJECT_DIR/.clasp.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)
sid = data.get('scriptId', '').strip()
if not sid:
    raise SystemExit('scriptId missing in .clasp.json')
print(sid)
PY
)"
fi

TOKEN_FIELDS="$(python3 - "$CLASPRC" <<'PY'
import json, sys

with open(sys.argv[1], encoding='utf-8') as f:
    data = json.load(f)

tokens = data.get('tokens', {})
if not isinstance(tokens, dict):
    raise SystemExit('tokens field is not a dict in .clasprc.json')

creds = tokens.get('default', {})
if not creds:
    raise SystemExit('tokens.default not found in .clasprc.json')

for k in ('client_id', 'client_secret', 'refresh_token'):
    if not creds.get(k):
        raise SystemExit(f'{k} missing in tokens.default')
print(creds['client_id'])
print(creds['client_secret'])
print(creds['refresh_token'])
PY
)"

CLIENT_ID="$(echo "$TOKEN_FIELDS" | sed -n '1p')"
CLIENT_SECRET="$(echo "$TOKEN_FIELDS" | sed -n '2p')"
REFRESH_TOKEN="$(echo "$TOKEN_FIELDS" | sed -n '3p')"

TMP_DIR="$(mktemp -d)"
TMP_BODY="$TMP_DIR/run_response.json"
TOKEN_BODY="$TMP_DIR/token_response.json"
trap 'rm -rf "$TMP_DIR"' EXIT

TOKEN_HTTP_CODE="$(curl -sS -o "$TOKEN_BODY" -w '%{http_code}' \
  -X POST 'https://oauth2.googleapis.com/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=refresh_token' \
  --data-urlencode "refresh_token=${REFRESH_TOKEN}" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}")"

if [[ "$TOKEN_HTTP_CODE" =~ ^4[0-9][0-9]$ ]]; then
  log "token refresh failed with HTTP $TOKEN_HTTP_CODE"
  cat "$TOKEN_BODY" | tee -a "$LOG_FILE"
  notify_error "gas_run: token refresh 失敗 — 復旧: clasp re-login"
  die "Failed to acquire access_token"
fi

ACCESS_TOKEN="$(python3 - "$TOKEN_BODY" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    obj = json.load(f)
if 'access_token' not in obj:
    raise SystemExit('access_token missing in token response')
print(obj['access_token'])
PY
)" || {
  log "token response parse failed"
  cat "$TOKEN_BODY" | tee -a "$LOG_FILE"
  notify_error "gas_run: token refresh 失敗 — 復旧: clasp re-login"
  die "Failed to parse access_token"
}

RUN_URL="https://script.googleapis.com/v1/scripts/${SCRIPT_ID}:run"
REQUEST_BODY="$(python3 - "$FUNCTION_NAME" <<'PY'
import json, sys
print(json.dumps({"function": sys.argv[1], "devMode": True}, ensure_ascii=False))
PY
)"

log "Calling Apps Script API :run"
log "script_id=$SCRIPT_ID function=$FUNCTION_NAME"

HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w '%{http_code}' \
  -X POST "$RUN_URL" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data "$REQUEST_BODY")"

log "HTTP response code: $HTTP_CODE"
cat "$TMP_BODY" | tee -a "$LOG_FILE" >/dev/null

if [[ "$HTTP_CODE" == "200" ]]; then
  log "run succeeded"
  exit 0
fi

if [[ "$HTTP_CODE" == "403" ]]; then
  log "ERROR: script.scriptapp scope が必要。clasp re-login で scope 追加を殿に依頼してください。"
  notify_error "gas_run: 403 scope不足 — 復旧: clasp login --scope script.scriptapp で re-login 必要"
  exit 1
fi

if [[ "$HTTP_CODE" == "404" ]]; then
  log "ERROR: scriptId が不正かスクリプト未デプロイ。"
  notify_error "gas_run: 404 scriptId不正 — 復旧: config/settings.yaml の scriptId を確認"
  exit 1
fi

log "ERROR: run failed (HTTP $HTTP_CODE)"
exit 1
