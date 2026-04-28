#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/gas_push_sa.log"
: > "$LOG_FILE"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $*"
  exit 1
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] [--project-dir DIR] [--sa-json PATH]

Options:
  --dry-run          Build payload only; do not call updateContent.
  --project-dir DIR  GAS project directory (default: /home/ubuntu/gas-mail-manager)
  --sa-json PATH     Service account key JSON (default: /home/ubuntu/.gcp/sa.json)
USAGE
}

DRY_RUN=0
PROJECT_DIR="/home/ubuntu/gas-mail-manager"
SA_JSON="/home/ubuntu/.gcp/sa.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --project-dir)
      PROJECT_DIR="${2:-}"
      [[ -n "$PROJECT_DIR" ]] || die "--project-dir requires a value"
      shift 2
      ;;
    --sa-json)
      SA_JSON="${2:-}"
      [[ -n "$SA_JSON" ]] || die "--sa-json requires a value"
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

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v openssl >/dev/null 2>&1 || die "openssl is required"

[[ -d "$PROJECT_DIR" ]] || die "Project directory not found: $PROJECT_DIR"
[[ -f "$PROJECT_DIR/.clasp.json" ]] || die ".clasp.json not found in $PROJECT_DIR"
[[ -f "$PROJECT_DIR/appsscript.json" ]] || die "appsscript.json not found in $PROJECT_DIR"
[[ -f "$SA_JSON" ]] || die "SA JSON not found: $SA_JSON"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Starting gas push via Service Account"
log "project_dir=$PROJECT_DIR dry_run=$DRY_RUN sa_json=$SA_JSON"

SCRIPT_ID="$(python3 - "$PROJECT_DIR/.clasp.json" <<'PY'
import json,sys
with open(sys.argv[1], encoding='utf-8') as f:
    data=json.load(f)
sid=data.get('scriptId','').strip()
if not sid:
    raise SystemExit('scriptId missing in .clasp.json')
print(sid)
PY
)"

KEY_FILE="$TMP_DIR/sa_key.pem"
SA_EMAIL="$(python3 - "$SA_JSON" "$KEY_FILE" <<'PY'
import json,sys
sa_path,key_out=sys.argv[1],sys.argv[2]
with open(sa_path, encoding='utf-8') as f:
    data=json.load(f)
for k in ('client_email','private_key'):
    if not data.get(k):
        raise SystemExit(f'{k} missing in SA JSON')
with open(key_out,'w',encoding='utf-8') as out:
    out.write(data['private_key'])
print(data['client_email'])
PY
)"
chmod 600 "$KEY_FILE"

ACCESS_TOKEN="$(python3 - "$SA_EMAIL" "$KEY_FILE" <<'PY'
import base64, json, os, subprocess, sys, time
sa_email, key_file = sys.argv[1], sys.argv[2]

def b64url(b: bytes) -> bytes:
    return base64.urlsafe_b64encode(b).rstrip(b'=')

header = b64url(json.dumps({"alg":"RS256","typ":"JWT"}, separators=(",",":")).encode())
now = int(time.time())
claim = {
    "iss": sa_email,
    "scope": "https://www.googleapis.com/auth/script.projects https://www.googleapis.com/auth/cloud-platform",
    "aud": "https://oauth2.googleapis.com/token",
    "iat": now,
    "exp": now + 3600,
}
payload = b64url(json.dumps(claim, separators=(",",":")).encode())
unsigned = header + b'.' + payload
p = subprocess.run(
    ["openssl","dgst","-sha256","-sign",key_file],
    input=unsigned,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
)
signature = b64url(p.stdout)
jwt = unsigned + b'.' + signature

resp = subprocess.run(
    ["curl","-sS","-X","POST","https://oauth2.googleapis.com/token",
     "-H","Content-Type: application/x-www-form-urlencoded",
     "--data-urlencode","grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer",
     "--data-urlencode",f"assertion={jwt.decode()}"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
)
obj = json.loads(resp.stdout.decode())
if 'access_token' not in obj:
    raise SystemExit('Failed to acquire access_token: ' + resp.stdout.decode())
print(obj['access_token'])
PY
)"

GET_URL="https://script.googleapis.com/v1/projects/${SCRIPT_ID}/content"
log "Fetching current project content"
curl -sS -H "Authorization: Bearer ${ACCESS_TOKEN}" "$GET_URL" > "$TMP_DIR/get_content.json"

PAYLOAD_PATH="$TMP_DIR/update_payload.json"
python3 - "$PROJECT_DIR" "$TMP_DIR/get_content.json" "$PAYLOAD_PATH" <<'PY'
import json
import pathlib
import sys

project_dir = pathlib.Path(sys.argv[1])
get_content_path = pathlib.Path(sys.argv[2])
payload_path = pathlib.Path(sys.argv[3])

with get_content_path.open(encoding='utf-8') as f:
    current = json.load(f)

if "files" not in current or not isinstance(current["files"], list):
    raise SystemExit("projects.getContent response missing files[]")

local_files = {}
manifest_path = project_dir / "appsscript.json"
local_files["appsscript"] = {
    "name": "appsscript",
    "type": "JSON",
    "source": manifest_path.read_text(encoding='utf-8')
}

ext_map = {
    ".gs": "SERVER_JS",
    ".js": "SERVER_JS",
    ".ts": "SERVER_JS",
    ".html": "HTML",
    ".json": "JSON",
}

for path in sorted((project_dir / "src").rglob("*")):
    if not path.is_file():
        continue
    ext = path.suffix.lower()
    if ext not in ext_map:
        continue
    rel = path.relative_to(project_dir / "src")
    stem = str(rel.with_suffix("")).replace("/", "_")
    if not stem:
        continue
    local_files[stem] = {
        "name": stem,
        "type": ext_map[ext],
        "source": path.read_text(encoding='utf-8')
    }

merged = []
seen = set()
for f in current["files"]:
    name = f.get("name")
    if name in local_files:
        merged.append(local_files[name])
        seen.add(name)
    else:
        merged.append(f)
for name, f in local_files.items():
    if name not in seen:
        merged.append(f)

with payload_path.open("w", encoding="utf-8") as out:
    json.dump({"files": merged}, out, ensure_ascii=False, indent=2)
PY

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry-run mode: payload generated only"
  log "payload_path=$PAYLOAD_PATH"
  exit 0
fi

UPDATE_URL="https://script.googleapis.com/v1/projects/${SCRIPT_ID}/content"
log "Pushing updateContent"
HTTP_CODE="$(curl -sS -o "$TMP_DIR/update_response.json" -w '%{http_code}' \
  -X PUT "$UPDATE_URL" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data-binary @"$PAYLOAD_PATH")"

if [[ "$HTTP_CODE" != "200" ]]; then
  log "updateContent failed with HTTP $HTTP_CODE"
  cat "$TMP_DIR/update_response.json" | tee -a "$LOG_FILE"
  die "Apps Script updateContent failed"
fi

log "updateContent succeeded"
cat "$TMP_DIR/update_response.json" >> "$LOG_FILE"
log "Completed successfully"
