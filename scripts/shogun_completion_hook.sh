#!/usr/bin/env bash
# shogun_completion_hook.sh — alert when Shogun misses post-cmd dual verification.
#
# This script is intentionally an alert hook only. It never starts
# implementation-verifier or a Codex arm; Shogun keeps that responsibility.

set -euo pipefail

ROOT_DIR="${SHOGUN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PYTHON="${ROOT_DIR}/.venv/bin/python3"
if [ ! -x "${PYTHON}" ]; then
    PYTHON="python3"
fi

SHOGUN_INBOX="${ROOT_DIR}/queue/inbox/shogun.yaml"
INBOX_WRITE="${ROOT_DIR}/scripts/inbox_write.sh"
NOTIFY_SCRIPT="${ROOT_DIR}/scripts/notify.sh"
COOLDOWN_SECONDS="${SHOGUN_COMPLETION_HOOK_COOLDOWN_SECONDS:-300}"
NOW_OVERRIDE="${SHOGUN_COMPLETION_HOOK_NOW:-}"
CMD_ID_FILTER=""
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: bash scripts/shogun_completion_hook.sh [--cmd-id cmd_NNN] [--cooldown-seconds N] [--dry-run]

Scans queue/inbox/shogun.yaml for cmd_complete messages. If a cmd_complete is
older than the cooldown window and no dual-verification evidence exists, sends
one dual_verification_alert to Shogun inbox.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --cmd-id)
            CMD_ID_FILTER="${2:-}"
            shift 2
            ;;
        --cooldown-seconds)
            COOLDOWN_SECONDS="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! [[ "${COOLDOWN_SECONDS}" =~ ^[0-9]+$ ]]; then
    echo "cooldown seconds must be a non-negative integer: ${COOLDOWN_SECONDS}" >&2
    exit 2
fi

if [ -n "${CMD_ID_FILTER}" ] && ! [[ "${CMD_ID_FILTER}" =~ ^cmd_[0-9]+$ ]]; then
    echo "cmd-id must look like cmd_NNN: ${CMD_ID_FILTER}" >&2
    exit 2
fi

if [ ! -f "${SHOGUN_INBOX}" ]; then
    echo "[shogun_completion_hook] shogun inbox not found: ${SHOGUN_INBOX}" >&2
    exit 0
fi

mapfile -t DUE_CMDS < <("${PYTHON}" - "${SHOGUN_INBOX}" "${CMD_ID_FILTER}" "${NOW_OVERRIDE}" "${COOLDOWN_SECONDS}" <<'PY'
import re
import sys
from datetime import datetime, timezone

import yaml

inbox_path, cmd_filter, now_raw, cooldown_raw = sys.argv[1:5]
cooldown_seconds = int(cooldown_raw)


def parse_ts(raw):
    text = str(raw or "").strip()
    if not text:
        return None
    text = text.replace(" JST", "+09:00")
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        try:
            parsed = datetime.strptime(text, "%Y-%m-%dT%H:%M:%S")
        except ValueError:
            try:
                parsed = datetime.strptime(text, "%Y-%m-%d %H:%M")
            except ValueError:
                return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def text_of(message, key):
    return str(message.get(key, "") or "")


def contains_cmd(message, cmd_id):
    return cmd_id in text_of(message, "content")


def has_started_marker(message, cmd_id, completed_at):
    if message.get("type") != "dual_verification_started":
        return False
    if not contains_cmd(message, cmd_id):
        return False
    ts = parse_ts(message.get("timestamp"))
    if ts is None or ts < completed_at:
        return False
    content = text_of(message, "content").lower()
    return "implementation-verifier" in content and "codex" in content


def evidence_sets(messages, cmd_id, completed_at, completion_idx):
    impl = set()
    codex = set()
    for idx, message in enumerate(messages):
        if idx == completion_idx:
            continue
        if not contains_cmd(message, cmd_id):
            continue
        ts = parse_ts(message.get("timestamp"))
        if ts is None or ts < completed_at:
            continue
        sender = text_of(message, "from").lower()
        msg_type = text_of(message, "type").lower()
        content = text_of(message, "content").lower()

        if (
            sender == "implementation-verifier"
            or msg_type in {"implementation_verification_started", "implementation_verification_report"}
            or "implementation-verifier" in content
        ):
            impl.add(idx)

        if (
            "codex" in sender
            or msg_type.startswith("codex_")
            or "codex arm" in content
            or "codex検証" in content
            or "codex再検証" in content
        ):
            codex.add(idx)
    return impl, codex


def dual_verification_seen(messages, cmd_id, completed_at, completion_idx):
    for message in messages:
        if has_started_marker(message, cmd_id, completed_at):
            return True
    impl, codex = evidence_sets(messages, cmd_id, completed_at, completion_idx)
    return any(i != j for i in impl for j in codex)


def alert_already_sent(messages, cmd_id):
    needle = f"DUAL_VERIFICATION_MISSING:{cmd_id}"
    for message in messages:
        if message.get("type") != "dual_verification_alert":
            continue
        if needle in text_of(message, "content"):
            return True
    return False


try:
    with open(inbox_path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except FileNotFoundError:
    sys.exit(0)

messages = data.get("messages") or []
if not isinstance(messages, list):
    sys.exit(0)

now = parse_ts(now_raw) if now_raw else datetime.now(timezone.utc)
if now is None:
    now = datetime.now(timezone.utc)

cmd_completions = {}
for idx, message in enumerate(messages):
    if message.get("type") != "cmd_complete":
        continue
    content = text_of(message, "content")
    match = re.search(r"cmd_\d+", content)
    if not match:
        continue
    cmd_id = match.group(0)
    if cmd_filter and cmd_id != cmd_filter:
        continue
    ts = parse_ts(message.get("timestamp"))
    if ts is None:
        continue
    current = cmd_completions.get(cmd_id)
    if current is None or ts > current[0]:
        cmd_completions[cmd_id] = (ts, idx)

for cmd_id, (completed_at, completion_idx) in sorted(cmd_completions.items(), key=lambda item: item[1][0]):
    age = (now - completed_at).total_seconds()
    if age < cooldown_seconds:
        print(
            f"[shogun_completion_hook] cooldown skip: {cmd_id} age={int(age)}s < {cooldown_seconds}s",
            file=sys.stderr,
        )
        continue
    if alert_already_sent(messages, cmd_id):
        print(f"[shogun_completion_hook] dedup skip: {cmd_id} already alerted", file=sys.stderr)
        continue
    if dual_verification_seen(messages, cmd_id, completed_at, completion_idx):
        print(f"[shogun_completion_hook] evidence skip: {cmd_id} dual verification seen", file=sys.stderr)
        continue
    print(cmd_id)
PY
)

if [ "${#DUE_CMDS[@]}" -eq 0 ]; then
    echo "[shogun_completion_hook] no alerts due"
    exit 0
fi

for cmd_id in "${DUE_CMDS[@]}"; do
    [ -n "${cmd_id}" ] || continue
    message="⚠️ [DUAL_VERIFICATION_MISSING:${cmd_id}] ${cmd_id} cmd_complete受信後、dual-verification起動証跡が未確認。将軍は implementation-verifier(run_in_background=true) + Codex arm(effort=xhigh) を将軍自ら起動し、dual_verification_started 証跡を記録されたし。このhookはalertのみで自動起動しない。"

    if [ "${DRY_RUN}" = "1" ]; then
        echo "[shogun_completion_hook] DRY-RUN alert: ${message}"
        continue
    fi

    bash "${INBOX_WRITE}" shogun "${message}" dual_verification_alert shogun_completion_hook
    if [ -f "${NOTIFY_SCRIPT}" ]; then
        bash "${NOTIFY_SCRIPT}" "${message}" "⚠️ ${cmd_id} dual-verification未起動" dual_verification_alert >/dev/null 2>&1 || true
    fi
    echo "[shogun_completion_hook] alert sent: ${cmd_id}"
done
