#!/usr/bin/env bash
# action_required_sync.sh — gunshi_report.yaml の action_required_candidates を
# dashboard.yaml.action_required に idempotent upsert する sync script.
#
# cmd_659 Scope B: Action Required Pipeline
#
# 起動契機: inbox_watcher.sh の report_completed event handler から呼出
#           (polling 禁止 — F004)
#
# 仕様:
#   B-1: event 駆動 (本 script 自体は polling しない)
#   B-2: flock /var/lock/shogun_dashboard.lock (R6 race mitigation)
#   B-3: gunshi_report.yaml schema validate (R3): 不正yamlは abort + log
#   B-4: issue_id stable hash dedup (R2): 一致なら update, 新規なら append
#   B-5: status=resolved → dashboard.yaml.action_required_archive に移動
#   B-6: P0/HIGH 新規追加検出時 notify.sh push + key 分離 P_AR_<severity>_<issue_id>
#
# Usage:
#   bash scripts/action_required_sync.sh [<gunshi_report_path>]
#   default: queue/reports/gunshi_report.yaml
#
# Exit codes:
#   0: success (or no candidates)
#   1: usage / missing files
#   2: flock timeout
#   3: schema validation failure (dashboard.yaml NOT modified — R3)
#   4: yaml write failure (atomic rename fallback)
#   5: renderer failure (dashboard.md may be stale)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUNSHI_REPORT="${1:-${ACTION_REQUIRED_GUNSHI_REPORT:-$SCRIPT_DIR/queue/reports/gunshi_report.yaml}}"
DASHBOARD_YAML="${ACTION_REQUIRED_DASHBOARD_YAML:-$SCRIPT_DIR/dashboard.yaml}"
DASHBOARD_MD="${ACTION_REQUIRED_DASHBOARD_MD:-$SCRIPT_DIR/dashboard.md}"
RENDERER="$SCRIPT_DIR/scripts/generate_dashboard_md.py"
NOTIFY_SCRIPT="${ACTION_REQUIRED_NOTIFY_SCRIPT:-$SCRIPT_DIR/scripts/notify.sh}"

# Lock file: VPS local -> /var/lock (NFS でないため安全)
# Fallback: project-local lock if /var/lock not writable (test 環境用)
LOCK_FILE="${ACTION_REQUIRED_LOCK:-/var/lock/shogun_dashboard.lock}"

LOG_PREFIX="[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')] [action_required_sync]"
log()  { echo "$LOG_PREFIX $*"; }
err()  { echo "$LOG_PREFIX ERROR: $*" >&2; }
warn() { echo "$LOG_PREFIX WARN: $*" >&2; }

# Validate inputs (R3 prerequisite)
if [ ! -f "$GUNSHI_REPORT" ]; then
    err "gunshi_report not found: $GUNSHI_REPORT"
    exit 1
fi
if [ ! -f "$DASHBOARD_YAML" ]; then
    err "dashboard.yaml not found: $DASHBOARD_YAML"
    exit 1
fi
if [ ! -f "$RENDERER" ]; then
    err "renderer not found: $RENDERER"
    exit 1
fi

# B-2: flock /var/lock/shogun_dashboard.lock with timeout
# /var/lock not writable な環境 (test) は project-local lock に fallback
if ! ( : > "$LOCK_FILE" ) 2>/dev/null; then
    LOCK_FILE="$SCRIPT_DIR/.shogun_dashboard.lock"
    : > "$LOCK_FILE" 2>/dev/null || {
        err "cannot create lock file"
        exit 1
    }
fi

exec {LOCK_FD}>"$LOCK_FILE"
trap 'exec {LOCK_FD}>&- 2>/dev/null || true' EXIT

if ! flock --timeout 30 "$LOCK_FD"; then
    err "flock timeout (30s): $LOCK_FILE — another sync/rotate process holding the lock"
    exit 2
fi

log "Lock acquired: $LOCK_FILE"

# Sync via Python: schema validate + upsert + archive + notify-list
SYNC_OUT=$(python3 - "$GUNSHI_REPORT" "$DASHBOARD_YAML" <<'PYEOF'
"""action_required_sync core logic.

Returns notification list as JSON to stdout (one line):
  {"notify": [{"severity": "P0|HIGH", "issue_id": "...", "title": "..."}, ...]}

stderr: human-readable log lines.
exit: 0=ok, 3=schema/parse error, 4=write error.
"""
import os
import sys
import re
import json
import hashlib
import tempfile
import unicodedata
from datetime import datetime, timezone, timedelta

import yaml

JST = timezone(timedelta(hours=9))
gunshi_path, dashboard_path = sys.argv[1], sys.argv[2]

VALID_SEVERITIES = ("P0", "HIGH", "MEDIUM", "INFO")
VALID_STATUSES = ("open", "resolved", "superseded")
SEVERITY_DEFAULT_TAG = {
    "P0":     "[要行動]",
    "HIGH":   "[要判断]",
    "MEDIUM": "[提案]",
    "INFO":   "[情報]",
}


def now_jst_iso() -> str:
    return datetime.now(JST).strftime("%Y-%m-%dT%H:%M:%S+09:00")


def normalize(s) -> str:
    """全角→半角 (NFKC), trim, lowercase, 連続空白 → 1個."""
    if s is None:
        return ""
    s = unicodedata.normalize("NFKC", str(s))
    s = s.strip().lower()
    s = re.sub(r"\s+", " ", s)
    return s


def stable_issue_id(parent_cmd: str, severity: str, summary: str) -> str:
    base = f"{parent_cmd}:{severity}:{normalize(summary)}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()[:16]


def validate_candidate(item: dict, idx: int) -> list[str]:
    errors: list[str] = []
    if not isinstance(item, dict):
        return [f"candidates[{idx}]: not a dict (got {type(item).__name__})"]
    for field in ("issue_id", "parent_cmd", "severity", "summary"):
        v = item.get(field)
        if v is None or (isinstance(v, str) and v.strip() == ""):
            errors.append(f"candidates[{idx}]: missing required field '{field}'")
    sev = item.get("severity")
    if sev is not None and sev not in VALID_SEVERITIES:
        errors.append(
            f"candidates[{idx}]: invalid severity '{sev}' (must be one of {VALID_SEVERITIES})"
        )
    status = item.get("status", "open")
    if status not in VALID_STATUSES:
        errors.append(
            f"candidates[{idx}]: invalid status '{status}' (must be one of {VALID_STATUSES})"
        )
    return errors


# ---- Load gunshi_report.yaml ----
try:
    with open(gunshi_path, "r", encoding="utf-8") as f:
        report = yaml.safe_load(f) or {}
except Exception as e:
    print(f"failed to parse gunshi_report.yaml: {e}", file=sys.stderr)
    sys.exit(3)

result = report.get("result", {}) if isinstance(report.get("result"), dict) else {}
candidates = result.get("action_required_candidates", [])
if candidates is None:
    candidates = []

if not isinstance(candidates, list):
    print(
        f"action_required_candidates must be a list "
        f"(got {type(candidates).__name__})",
        file=sys.stderr,
    )
    sys.exit(3)

# ---- Auto-fill issue_id from parent_cmd+severity+summary if missing ----
for item in candidates:
    if not isinstance(item, dict):
        continue
    if not item.get("issue_id"):
        if item.get("parent_cmd") and item.get("severity") and item.get("summary"):
            item["issue_id"] = stable_issue_id(
                item["parent_cmd"], item["severity"], item["summary"]
            )

# ---- Schema validate (R3): abort on any error, no partial writes ----
all_errors: list[str] = []
for i, cand in enumerate(candidates):
    all_errors.extend(validate_candidate(cand, i))

if all_errors:
    print(f"schema validation failed ({len(all_errors)} errors):", file=sys.stderr)
    for e in all_errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(3)

# ---- Load dashboard.yaml ----
try:
    with open(dashboard_path, "r", encoding="utf-8") as f:
        dashboard = yaml.safe_load(f) or {}
except Exception as e:
    print(f"failed to parse dashboard.yaml: {e}", file=sys.stderr)
    sys.exit(3)

action_required = dashboard.get("action_required") or []
archive = dashboard.get("action_required_archive") or []

if not isinstance(action_required, list):
    print("dashboard.yaml.action_required must be a list", file=sys.stderr)
    sys.exit(3)
if not isinstance(archive, list):
    print("dashboard.yaml.action_required_archive must be a list", file=sys.stderr)
    sys.exit(3)

# Build idx by issue_id (B-4 dedup key)
existing_idx: dict[str, int] = {}
for i, ar in enumerate(action_required):
    if isinstance(ar, dict) and ar.get("issue_id"):
        existing_idx[ar["issue_id"]] = i

# ---- Process candidates ----
notify_list: list[dict] = []
upsert_count = 0
archive_count = 0

for cand in candidates:
    issue_id = cand["issue_id"]
    severity = cand["severity"]
    status = cand.get("status", "open")
    parent_cmd = cand["parent_cmd"]
    summary = cand["summary"]
    details = cand.get("details", "")
    needs_lord = bool(cand.get("needs_lord_decision", False))
    source_ts = cand.get("source_report_ts") or now_jst_iso()
    tag = cand.get("tag") or SEVERITY_DEFAULT_TAG.get(severity, "[情報]")

    entry = {
        "issue_id": issue_id,
        "parent_cmd": parent_cmd,
        "severity": severity,
        "tag": tag,
        "title": summary,
        "detail": details,
        "needs_lord_decision": needs_lord,
        "status": status,
        "source_report_ts": source_ts,
    }

    is_new = issue_id not in existing_idx

    if is_new:
        entry["created_at"] = now_jst_iso()
        if status == "resolved":
            # B-5: New + resolved → directly to archive
            entry["resolved_at"] = now_jst_iso()
            archive.append(entry)
            archive_count += 1
        else:
            action_required.append(entry)
            existing_idx[issue_id] = len(action_required) - 1
            upsert_count += 1
            # B-6: Notify only for newly-appearing P0/HIGH
            if severity in ("P0", "HIGH"):
                notify_list.append({
                    "severity": severity,
                    "issue_id": issue_id,
                    "title": summary,
                })
    else:
        # Existing → update in place (B-4 idempotent upsert)
        prev = action_required[existing_idx[issue_id]]
        # Preserve created_at
        entry["created_at"] = prev.get("created_at", now_jst_iso())
        if status == "resolved":
            # B-5: existing → resolved → move to archive, remove from action_required
            entry["resolved_at"] = now_jst_iso()
            archive.append(entry)
            action_required[existing_idx[issue_id]] = None  # mark for removal
            archive_count += 1
        else:
            action_required[existing_idx[issue_id]] = entry
            upsert_count += 1

# Strip None entries (resolved-from-existing)
action_required = [a for a in action_required if a is not None]

# ---- Atomic write dashboard.yaml (R3 atomic rename) ----
dashboard["action_required"] = action_required
dashboard["action_required_archive"] = archive

dir_path = os.path.dirname(os.path.abspath(dashboard_path)) or "."
tmp_fd, tmp_path = tempfile.mkstemp(
    dir=dir_path, prefix=".dashboard.yaml.", suffix=".tmp"
)
try:
    with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
        yaml.dump(
            dashboard, f,
            allow_unicode=True,
            default_flow_style=False,
            sort_keys=True,
        )
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp_path, dashboard_path)
except Exception as e:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    print(f"failed to write dashboard.yaml: {e}", file=sys.stderr)
    sys.exit(4)

print(
    f"sync ok: candidates={len(candidates)}, upsert={upsert_count}, archived={archive_count}",
    file=sys.stderr,
)

# Emit notify list as JSON on stdout (one line, parsed by caller)
print(json.dumps({"notify": notify_list}, ensure_ascii=False))
PYEOF
)
PY_RC=$?

if [ "$PY_RC" -ne 0 ]; then
    err "python sync failed (rc=$PY_RC) — dashboard.yaml NOT modified"
    exit "$PY_RC"
fi

# B-6: dispatch P0/HIGH new-appearance notifications
# AUTO_CMD escalation key namespace: P_AR_<severity>_<issue_id>
# (separate from cmd_644 Scope B P9b/P9c keys to avoid collision)
NOTIFY_JSON=$(printf '%s' "$SYNC_OUT" | tail -n 1)
NOTIFY_COUNT=$(printf '%s' "$NOTIFY_JSON" \
    | python3 -c 'import sys,json; print(len((json.loads(sys.stdin.read() or "{}").get("notify") or [])))' 2>/dev/null \
    || echo 0)

if [ "${NOTIFY_COUNT:-0}" -gt 0 ]; then
    log "Dispatching $NOTIFY_COUNT P0/HIGH notification(s)"
    export NOTIFY_SCRIPT
    printf '%s' "$NOTIFY_JSON" | python3 -c '
import sys, json, subprocess, os

NOTIFY = os.environ.get("NOTIFY_SCRIPT")
data = json.loads(sys.stdin.read() or "{}")
for item in (data.get("notify") or []):
    sev = item["severity"]
    iid = item["issue_id"]
    title = item["title"]
    body = f"\U0001F6A8 {sev} {title}"
    title_str = f"action_required {sev}"
    # AUTO_CMD escalation key (key-separated namespace)
    extra = f"P_AR_{sev}_{iid}"
    try:
        subprocess.run(
            [NOTIFY, body, title_str, extra],
            check=False, capture_output=True, timeout=15,
        )
        print(f"notify sent: P_AR_{sev}_{iid}", file=sys.stderr)
    except Exception as e:
        print(f"WARN: notify failed for {iid}: {e}", file=sys.stderr)
' 2>&1 | sed "s|^|$LOG_PREFIX |"
fi

# Render dashboard.md (Scope C delegate)
log "Rendering dashboard.md..."
if ! python3 "$RENDERER" --input "$DASHBOARD_YAML" --output "$DASHBOARD_MD" 2>&1 | sed "s|^|$LOG_PREFIX renderer: |"; then
    err "renderer failed (dashboard.md may be stale)"
    exit 5
fi

log "sync + render complete."
exit 0
