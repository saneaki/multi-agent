#!/usr/bin/env bash
# scripts/karo_cmd_complete_audit.sh
# AC-5: shogun inbox への cmd_complete 未送付 cmd を検出する
#
# Usage: bash karo_cmd_complete_audit.sh [--repo-root PATH] [--min-cmd-num N] [--quiet]
# Exit:  0=PASS (all done cmds have cmd_complete or no target cmds)
#        1=FAIL (done cmd(s) missing cmd_complete in shogun inbox)
#
# --repo-root PATH    : リポジトリルート (デフォルト: スクリプトの ../.)
# --min-cmd-num N     : 監査対象の最小 cmd 番号 (デフォルト: 700)
# --quiet             : ログ出力を抑制

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIN_CMD_NUM=700
QUIET=0

_VENV_PYTHON="$REPO_ROOT/.venv/bin/python3"
PYTHON="${_VENV_PYTHON}"
[[ -x "$PYTHON" ]] || PYTHON="python3"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-root) REPO_ROOT="$2"; shift 2 ;;
        --min-cmd-num) MIN_CMD_NUM="$2"; shift 2 ;;
        --quiet) QUIET=1; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

SHOGUN_TO_KARO="${REPO_ROOT}/queue/shogun_to_karo.yaml"
SHOGUN_INBOX="${REPO_ROOT}/queue/inbox/shogun.yaml"

log() { [[ $QUIET -eq 0 ]] && echo "[karo_cmd_complete_audit] $*" >&2; }

if [[ ! -f "$SHOGUN_TO_KARO" ]]; then
    log "WARNING: shogun_to_karo.yaml not found — skip"
    exit 0
fi

"$PYTHON" - "$SHOGUN_TO_KARO" "$SHOGUN_INBOX" "$MIN_CMD_NUM" "$QUIET" <<'PYEOF'
import sys, re, os

try:
    import yaml
except ImportError:
    print("[karo_cmd_complete_audit] ERROR: pyyaml not installed", file=sys.stderr)
    sys.exit(2)

shogun_to_karo_path = sys.argv[1]
shogun_inbox_path   = sys.argv[2]
min_cmd_num         = int(sys.argv[3])
quiet               = sys.argv[4] == "1"

def log(msg):
    if not quiet:
        print(f"[karo_cmd_complete_audit] {msg}", file=sys.stderr)

# Load shogun_to_karo.yaml (top-level list of cmd dicts)
with open(shogun_to_karo_path) as f:
    cmds = yaml.safe_load(f)

if not isinstance(cmds, list):
    log("WARNING: shogun_to_karo.yaml is not a list — skip")
    sys.exit(0)

# Collect done cmd IDs above min_cmd_num
done_ids = []
for cmd in cmds:
    if not isinstance(cmd, dict):
        continue
    if cmd.get("status") != "done":
        continue
    raw_id = str(cmd.get("id") or cmd.get("cmd_id") or "")
    m = re.match(r'cmd_(\d+)', raw_id)
    if not m:
        continue
    if int(m.group(1)) >= min_cmd_num:
        done_ids.append(raw_id)

if not done_ids:
    log(f"No done cmds >= cmd_{min_cmd_num} found — PASS")
    sys.exit(0)

# Load shogun inbox and collect cmd_ids mentioned in cmd_complete messages
inbox_acknowledged = set()
if os.path.exists(shogun_inbox_path):
    with open(shogun_inbox_path) as f:
        inbox = yaml.safe_load(f)
    if isinstance(inbox, dict):
        messages = inbox.get("messages", [])
    elif isinstance(inbox, list):
        messages = inbox
    else:
        messages = []
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        if msg.get("type") == "cmd_complete":
            content = str(msg.get("content", ""))
            for m in re.findall(r'cmd_\d+', content):
                inbox_acknowledged.add(m)

# Audit
missing = []
for cmd_id in done_ids:
    if cmd_id in inbox_acknowledged:
        log(f"OK: {cmd_id} — cmd_complete found in shogun inbox")
    else:
        log(f"MISSING: {cmd_id} — done but no cmd_complete in shogun inbox")
        missing.append(cmd_id)

if missing:
    log(f"FAIL: {len(missing)} cmd(s) missing cmd_complete: {', '.join(missing)}")
    sys.exit(1)
else:
    log(f"PASS: all {len(done_ids)} done cmd(s) have cmd_complete")
    sys.exit(0)
PYEOF
