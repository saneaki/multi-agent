#!/usr/bin/env bash
# Append a Gunshi QC entry to queue/reports/gunshi_report.yaml.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$SCRIPT_DIR/queue/reports/gunshi_report.yaml"
if [ -z "${PYTHON_BIN:-}" ] && [ -x "$SCRIPT_DIR/.venv/bin/python3" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python3"
fi
PYTHON_BIN="${PYTHON_BIN:-python3}"
ENTRY_FILE=""
TASK_ID=""
PARENT_CMD=""
STATUS="done"
VERDICT="go"
NOTE=""

usage() {
    cat <<'EOF'
Usage:
  bash scripts/gunshi_report_append.sh [--report PATH] --entry ENTRY.yaml
  bash scripts/gunshi_report_append.sh [--report PATH] --task-id ID [--parent-cmd CMD] [--status STATUS] [--verdict VERDICT] [--note TEXT]
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --report) REPORT="$2"; shift 2 ;;
        --entry) ENTRY_FILE="$2"; shift 2 ;;
        --task-id) TASK_ID="$2"; shift 2 ;;
        --parent-cmd) PARENT_CMD="$2"; shift 2 ;;
        --status) STATUS="$2"; shift 2 ;;
        --verdict) VERDICT="$2"; shift 2 ;;
        --note) NOTE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [ -z "$ENTRY_FILE" ] && [ -z "$TASK_ID" ]; then
    echo "missing --entry or --task-id" >&2
    usage >&2
    exit 1
fi

if [ ! -f "$REPORT" ]; then
    echo "report not found: $REPORT" >&2
    exit 1
fi

LOCK_FILE="${REPORT}.lock"
LOCK_DIR=""
if command -v flock >/dev/null 2>&1; then
    exec {LOCK_FD}>"$LOCK_FILE"
    flock --timeout 30 "$LOCK_FD"
else
    LOCK_DIR="${LOCK_FILE}.d"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "lock unavailable: $LOCK_DIR" >&2
        exit 2
    fi
fi

ENTRY_TMP=""
cleanup() {
    if [ -n "$ENTRY_TMP" ] && [ -f "$ENTRY_TMP" ]; then
        rm -f "$ENTRY_TMP"
    fi
    if [ -n "$LOCK_DIR" ] && [ -d "$LOCK_DIR" ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ -z "$ENTRY_FILE" ]; then
    ENTRY_TMP="$(mktemp)"
    TS="$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml)"
    cat > "$ENTRY_TMP" <<EOF
worker_id: gunshi
task_id: ${TASK_ID}
parent_cmd: ${PARENT_CMD:-null}
timestamp: "${TS}"
status: ${STATUS}
trigger: append_helper
note: |
  ${NOTE:-appended by gunshi_report_append.sh}
result:
  type: quality_check
  verdict: ${VERDICT}
  action_required_candidates: []
skill_candidate:
  found: false
  reason: "append helper smoke/default entry"
EOF
    ENTRY_FILE="$ENTRY_TMP"
fi

"$PYTHON_BIN" - "$REPORT" "$ENTRY_FILE" <<'PY'
import os
import sys
import tempfile
from pathlib import Path

import yaml

report_path = Path(sys.argv[1])
entry_path = Path(sys.argv[2])

docs = [doc for doc in yaml.safe_load_all(report_path.read_text(encoding="utf-8")) if doc]
if not docs:
    report = {"worker_id": "gunshi", "latest": None, "history": []}
elif len(docs) == 1 and isinstance(docs[0], dict) and "latest" in docs[0] and "history" in docs[0]:
    report = docs[0]
else:
    latest = docs[-1]
    history = docs[:-1]
    report = {"worker_id": "gunshi", "latest": latest, "history": history}

if not isinstance(report.get("history"), list):
    raise SystemExit("history must be a list")

entry_docs = [doc for doc in yaml.safe_load_all(entry_path.read_text(encoding="utf-8")) if doc]
if len(entry_docs) != 1 or not isinstance(entry_docs[0], dict):
    raise SystemExit("entry must contain exactly one YAML mapping")
entry = entry_docs[0]
if entry.get("worker_id") != "gunshi":
    entry["worker_id"] = "gunshi"
if not entry.get("task_id"):
    raise SystemExit("entry.task_id is required")

current_latest = report.get("latest")
if isinstance(current_latest, dict) and current_latest.get("task_id"):
    if not report["history"] or report["history"][-1].get("task_id") != current_latest.get("task_id"):
        report["history"].append(current_latest)
report["latest"] = entry
report["worker_id"] = "gunshi"

fd, tmp_name = tempfile.mkstemp(
    dir=str(report_path.parent),
    prefix=f".{report_path.name}.",
    suffix=".tmp",
)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        yaml.safe_dump(report, f, allow_unicode=True, sort_keys=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp_name, report_path)
except Exception:
    try:
        os.unlink(tmp_name)
    except FileNotFoundError:
        pass
    raise

print(f"appended: {entry['task_id']} history={len(report['history'])}")
PY
