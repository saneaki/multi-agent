#!/usr/bin/env python3
from __future__ import annotations
import glob
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
import yaml

DONE_MAX_AGE_MIN = 6 * 60
ACTIVE_HOOK_LOGS = [
    "logs/cmd_complete_notifier.log",
    "logs/compact_observer.log",
    "logs/shogun_inbox_notifier.log",
    "logs/discord_bot_health.log",
]

def _load_yaml(path: str):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if data is None:
        data = {}
    return data

def check_dashboard_stall(root: str) -> str:
    db_file = os.path.join(root, "dashboard.yaml")
    data = _load_yaml(db_file)
    in_progress = data.get("in_progress", [])
    if not in_progress:
        return "ok"
    age_h = (datetime.now().timestamp() - os.path.getmtime(db_file)) / 3600
    if age_h < 4:
        return "ok"
    items = ["{cmd}({assignee})".format(cmd=item.get("cmd", "?"), assignee=item.get("assignee", "?")) for item in in_progress]
    return "STALL: {n}件進行中, {h:.1f}h更新なし: {items}".format(n=len(in_progress), h=age_h, items=", ".join(items))

def check_ash_done_pending(root: str) -> str:
    task_files = glob.glob(os.path.join(root, "queue/tasks/ashigaru*.yaml"))
    pending = []
    for task_file in task_files:
        task = _load_yaml(task_file)
        status = task.get("status", "")
        if status not in ("done", "completed_pending_karo"):
            continue
        age_min = (datetime.now().timestamp() - os.path.getmtime(task_file)) / 60
        if status == "done":
            if not (30 <= age_min < DONE_MAX_AGE_MIN):
                continue
        else:
            if age_min < 30:
                continue
        agent = os.path.basename(task_file).replace(".yaml", "")
        task_id = task.get("task_id", "?")
        pending.append("{agent}:{tid}({m:.0f}min)".format(agent=agent, tid=task_id, m=age_min))
    return "PENDING: " + ", ".join(pending) if pending else "ok"

def check_inbox_unread(root: str) -> str:
    inbox_files = glob.glob(os.path.join(root, "queue/inbox/*.yaml"))
    alerts = []
    now = datetime.now(timezone.utc)
    one_hour_ago = now - timedelta(hours=1)
    for inbox_file in inbox_files:
        if inbox_file.endswith(".lock"):
            continue
        data = _load_yaml(inbox_file)
        messages = data.get("messages", [])
        if not messages:
            continue
        agent = os.path.basename(inbox_file).replace(".yaml", "")
        for msg in messages:
            if msg.get("read", True):
                continue
            ts_str = str(msg.get("timestamp", ""))
            try:
                if ts_str.endswith("Z"):
                    ts_str = ts_str[:-1] + "+00:00"
                ts = datetime.fromisoformat(ts_str)
                if ts.tzinfo is None:
                    ts = ts.replace(tzinfo=timezone.utc)
                if ts <= one_hour_ago:
                    age_min = (now - ts).total_seconds() / 60
                    alerts.append("{agent}({m:.0f}min)".format(agent=agent, m=age_min))
                    break
            except ValueError:
                continue
    return "UNREAD: " + ", ".join(alerts) if alerts else "ok"

def check_action_required_stale(root: str) -> str:
    data = _load_yaml(os.path.join(root, "dashboard.yaml"))
    action_required = data.get("action_required", [])
    proposals = [i for i in action_required if str(i.get("tag", "")).startswith("[提案-")]
    if not proposals:
        return "ok"
    result = subprocess.run(["git", "-C", root, "log", "--format=%H", "--before=3 days ago", "-1", "--", "dashboard.yaml"], capture_output=True, text=True, timeout=10, check=False)
    old_hash = result.stdout.strip()
    if not old_hash:
        return "ok"
    result2 = subprocess.run(["git", "-C", root, "show", old_hash + ":dashboard.yaml"], capture_output=True, text=True, timeout=10, check=False)
    if result2.returncode != 0:
        return "ok"
    old_data = yaml.safe_load(result2.stdout)
    if old_data is None:
        old_data = {}
    old_tags = {str(item.get("tag", "")) for item in old_data.get("action_required", [])}
    stale = [item for item in proposals if str(item.get("tag", "")) in old_tags]
    return "STALE_PROPOSALS: " + ", ".join(item.get("tag", "?") for item in stale) if stale else "ok"

def check_hook_liveness(root: str) -> str:
    min_age_h = float("inf")
    checked = []
    for rel in ACTIVE_HOOK_LOGS:
        log_file = os.path.join(root, rel)
        if os.path.exists(log_file) and os.path.getsize(log_file) > 0:
            age_h = (datetime.now().timestamp() - os.path.getmtime(log_file)) / 3600
            checked.append((os.path.basename(log_file), age_h))
            if age_h < min_age_h:
                min_age_h = age_h
    if not checked:
        return "ok"
    if min_age_h >= 12:
        freshest = min(checked, key=lambda x: x[1])
        return "HOOK_DEAD: 最新hookログ {h:.1f}h 途絶 ({log})".format(h=min_age_h, log=freshest[0])
    return "ok"

def check_git_uncommitted(root: str) -> str:
    result = subprocess.run(["git", "-C", root, "status", "--porcelain"], capture_output=True, text=True, timeout=10, check=False)
    if not result.stdout.strip():
        return "ok"
    result2 = subprocess.run(["git", "-C", root, "log", "-1", "--format=%ct"], capture_output=True, text=True, timeout=10, check=False)
    if not result2.stdout.strip():
        return "ok"
    commit_ts = int(result2.stdout.strip())
    age_h = (datetime.now().timestamp() - commit_ts) / 3600
    if age_h >= 4:
        change_count = len([l for l in result.stdout.strip().split("\n") if l.strip()])
        return "UNCOMMITTED: {n}件変更あり, last_commit {h:.1f}h前".format(n=change_count, h=age_h)
    return "ok"

CHECKS = {
    "check_dashboard_stall": check_dashboard_stall,
    "check_ash_done_pending": check_ash_done_pending,
    "check_inbox_unread": check_inbox_unread,
    "check_action_required_stale": check_action_required_stale,
    "check_hook_liveness": check_hook_liveness,
    "check_git_uncommitted": check_git_uncommitted,
}

def main() -> int:
    if len(sys.argv) < 3:
        print("error: usage status_check_rules.py <check_name> <project_root>")
        return 2
    check_name = sys.argv[1]
    root = sys.argv[2]
    fn = CHECKS.get(check_name)
    if fn is None:
        print(f"error: unknown check {check_name}")
        return 2
    try:
        print(fn(root))
        return 0
    except yaml.YAMLError as e:
        print(f"error: yaml_error: {check_name}: {e}")
        return 1
    except FileNotFoundError as e:
        print(f"error: file_not_found: {check_name}: {e}")
        return 1
    except OSError as e:
        print(f"error: os_error: {check_name}: {e}")
        return 1
    except subprocess.TimeoutExpired as e:
        print(f"error: subprocess_timeout: {check_name}: {e}")
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
