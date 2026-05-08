#!/usr/bin/env bash
# ============================================================================
# cmd_690: GitHub Actions failure API polling monitor
#
# 役割:
#   config/gha_monitor_targets.yaml の 9 repo を gh API で確認し、
#   active workflow + 直近30日 + schedule/push event の失敗だけを red 判定する。
#
# 出力:
#   JSON to stdout. --output <path> 指定時は同じ JSON をファイルにも保存する。
# ============================================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
CONFIG="$SHOGUN_ROOT/config/gha_monitor_targets.yaml"
OUTPUT=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config)
            CONFIG="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            echo "usage: $0 [--config path] [--output path]" >&2
            exit 2
            ;;
    esac
done

if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found" >&2
    exit 127
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found" >&2
    exit 127
fi

if [ ! -f "$CONFIG" ]; then
    echo "config not found: $CONFIG" >&2
    exit 1
fi

CONFIG_ENV="$CONFIG" OUTPUT_ENV="$OUTPUT" python3 <<'PYEOF'
import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

config_path = Path(os.environ["CONFIG_ENV"])
output_path = os.environ.get("OUTPUT_ENV", "")


def run_gh_api(path: str) -> tuple[int, object, str]:
    cmd = ["gh", "api", path]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
    except subprocess.TimeoutExpired:
        return 124, None, "gh api timeout"
    if proc.returncode != 0:
        return proc.returncode, None, (proc.stderr or proc.stdout).strip()[:500]
    try:
        return 0, json.loads(proc.stdout), ""
    except json.JSONDecodeError as exc:
        return 1, None, f"invalid gh api JSON: {exc}"


def iso_z(value: dt.datetime) -> str:
    return value.replace(microsecond=0, tzinfo=dt.timezone.utc).isoformat().replace("+00:00", "Z")


def run_url(repo: str, run_id: object) -> str:
    return f"https://github.com/{repo}/actions/runs/{run_id}"


def workflow_url(repo: str, workflow_id: object) -> str:
    return f"https://github.com/{repo}/actions/workflows/{workflow_id}"


cfg = yaml.safe_load(config_path.read_text()) or {}
defaults = cfg.get("defaults") or {}
targets = cfg.get("targets") or []
lookback_days = int(defaults.get("lookback_days", 30))
primary_events = set(defaults.get("primary_events") or ["schedule", "push"])
manual_events = set(defaults.get("manual_events") or ["workflow_dispatch"])
red_conclusions = set(defaults.get("red_conclusions") or ["failure", "timed_out", "action_required"])

now = dt.datetime.now(dt.timezone.utc)
since = now - dt.timedelta(days=lookback_days)
created_query = f">={since.date().isoformat()}"

results = []
summary = {"green": 0, "yellow": 0, "red": 0, "error": 0}

for target in targets:
    name = target.get("name") or target.get("repo", "").split("/")[-1]
    repo = target["repo"]
    result = {
        "name": name,
        "repo": repo,
        "status": "green",
        "active_workflow_count": 0,
        "primary_event_count": 0,
        "manual_event_count": 0,
        "primary_failure_count": 0,
        "manual_failure_count": 0,
        "latest_primary_run": None,
        "latest_primary_failure": None,
        "latest_manual_failure": None,
        "ignored_runs": {
            "inactive_workflow": 0,
            "outside_lookback": 0,
            "non_primary_event": 0,
        },
        "errors": [],
    }

    rc, workflows_doc, err = run_gh_api(f"/repos/{repo}/actions/workflows?per_page=100")
    if rc != 0:
        result["status"] = "error"
        result["errors"].append(err or f"workflow API failed rc={rc}")
        results.append(result)
        summary["error"] += 1
        continue

    workflows = workflows_doc.get("workflows", []) if isinstance(workflows_doc, dict) else []
    active_workflow_ids = {
        wf.get("id")
        for wf in workflows
        if wf.get("state") == "active" and wf.get("id") is not None
    }
    result["active_workflow_count"] = len(active_workflow_ids)

    rc, runs_doc, err = run_gh_api(
        f"/repos/{repo}/actions/runs?per_page=100&created={created_query}"
    )
    if rc != 0:
        result["status"] = "error"
        result["errors"].append(err or f"runs API failed rc={rc}")
        results.append(result)
        summary["error"] += 1
        continue

    runs = runs_doc.get("workflow_runs", []) if isinstance(runs_doc, dict) else []
    for run in runs:
        workflow_id = run.get("workflow_id")
        event = run.get("event") or ""
        conclusion = run.get("conclusion") or ""
        created_at = run.get("created_at") or ""
        html_url = run.get("html_url") or run_url(repo, run.get("id"))

        if workflow_id not in active_workflow_ids:
            result["ignored_runs"]["inactive_workflow"] += 1
            continue

        try:
            created_dt = dt.datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        except Exception:
            created_dt = now
        if created_dt < since:
            result["ignored_runs"]["outside_lookback"] += 1
            continue

        run_summary = {
            "id": run.get("id"),
            "name": run.get("name"),
            "workflow_id": workflow_id,
            "event": event,
            "conclusion": conclusion,
            "created_at": created_at,
            "url": html_url,
        }

        if event in primary_events:
            result["primary_event_count"] += 1
            if result["latest_primary_run"] is None:
                result["latest_primary_run"] = run_summary
            if conclusion in red_conclusions:
                result["primary_failure_count"] += 1
                if result["latest_primary_failure"] is None:
                    result["latest_primary_failure"] = run_summary
        elif event in manual_events:
            result["manual_event_count"] += 1
            if conclusion in red_conclusions:
                result["manual_failure_count"] += 1
                if result["latest_manual_failure"] is None:
                    result["latest_manual_failure"] = run_summary
        else:
            result["ignored_runs"]["non_primary_event"] += 1

    latest_primary = result.get("latest_primary_run") or {}
    if latest_primary.get("conclusion") in red_conclusions:
        result["status"] = "red"
    elif result["manual_failure_count"] > 0:
        result["status"] = "yellow"
    else:
        result["status"] = "green"

    summary[result["status"]] = summary.get(result["status"], 0) + 1
    results.append(result)

doc = {
    "timestamp_utc": iso_z(now),
    "lookback_days": lookback_days,
    "created_filter": created_query,
    "primary_events": sorted(primary_events),
    "manual_events": sorted(manual_events),
    "red_conclusions": sorted(red_conclusions),
    "summary": summary,
    "results": results,
}

text = json.dumps(doc, ensure_ascii=False, indent=2)
if output_path:
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text + "\n")
print(text)
PYEOF
