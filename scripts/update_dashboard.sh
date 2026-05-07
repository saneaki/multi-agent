#!/bin/bash
# update_dashboard.sh
# queue/tasks/{ashigaru*,gunshi}.yaml から
#   ・🔄 進行中 / 🏯 待機中 のテーブル
#   ・最終更新 行
#   ・📊 運用指標 (logs/cmd_squash_pub_hook.daily.yaml 由来)
# のみを dashboard.md / dashboard.yaml に in-place 部分反映する。
#
# ⚠️ 上書きしないセクション:
#     📋 記載ルール / 🐸 Frog / 🚨 要対応 / ⚠️ 違反検出 /
#     ✅ 本日の戦果 / ✅ 昨日の戦果 / ✅ 一昨日の戦果 / 🛠️ スキル候補
#
# cmd_649: generate_dashboard_md.py 全再生成を撤去し、
#          家老 (Karo) の直接編集セクションを保全する partial-replace 方式に改修。
# Scope A: 部分置換ロジック / Scope B: nested YAML を python3+PyYAML でパース。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DASHBOARD_MD="$REPO_DIR/dashboard.md"
DASHBOARD_YAML="$REPO_DIR/dashboard.yaml"
TASKS_DIR="$REPO_DIR/queue/tasks"
DAILY_YAML="$REPO_DIR/logs/cmd_squash_pub_hook.daily.yaml"

# JST timestamp (YYYY-MM-DD HH:MM)
TIMESTAMP=$(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' || date "+%Y-%m-%d %H:%M")

python3 - "$REPO_DIR" "$TIMESTAMP" "$DASHBOARD_MD" "$DASHBOARD_YAML" "$TASKS_DIR" "$DAILY_YAML" <<'PYEOF'
"""Partial-replace updater for dashboard.md / dashboard.yaml (cmd_649)."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml

repo_dir = Path(sys.argv[1])
timestamp = sys.argv[2]
dashboard_md = Path(sys.argv[3])
dashboard_yaml = Path(sys.argv[4])
tasks_dir = Path(sys.argv[5])
daily_yaml = Path(sys.argv[6])

AGENT_NAME = {
    "ashigaru1": "足軽1号(Sonnet)",
    "ashigaru2": "足軽2号(Sonnet)",
    "ashigaru3": "足軽3号(Sonnet)",
    "ashigaru4": "足軽4号(Opus+T)",
    "ashigaru5": "足軽5号(Opus+T)",
    "ashigaru6": "足軽6号(Codex)",
    "ashigaru7": "足軽7号(Codex)",
    "gunshi": "軍師(Opus+T)",
}

ACTIVE_STATUSES = {"assigned", "in_progress", "working"}
IDLE_STATUSES = {"done", "completed", "idle", "canceled"}


def _inner(data: Any) -> dict[str, Any]:
    """Return the task body whether YAML is nested ({task: {...}}) or flat."""
    if not isinstance(data, dict):
        return {}
    inner = data.get("task", data)
    return inner if isinstance(inner, dict) else {}


def _field(data: Any, key: str, default: str = "") -> str:
    inner = _inner(data)
    val = inner.get(key, default)
    if val is None:
        return default
    return str(val).strip()


def _title(data: Any) -> str:
    inner = _inner(data)
    for key in ("title", "purpose"):
        v = inner.get(key)
        if v and str(v).strip():
            return str(v).strip().split("\n")[0][:80]
    desc = inner.get("description")
    if desc and str(desc).strip():
        return str(desc).strip().split("\n")[0][:80]
    fallback = inner.get("task_type") or inner.get("task_id") or ""
    return str(fallback)[:80]


def collect_tasks() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    in_progress: list[dict[str, str]] = []
    idle_members: list[dict[str, str]] = []

    yaml_files = sorted(tasks_dir.glob("ashigaru*.yaml"))
    gunshi_path = tasks_dir / "gunshi.yaml"
    if gunshi_path.exists():
        yaml_files.append(gunshi_path)

    for yaml_file in yaml_files:
        try:
            data = yaml.safe_load(yaml_file.read_text()) or {}
        except yaml.YAMLError as e:
            print(f"[WARN] failed to parse {yaml_file.name}: {e}", file=sys.stderr)
            continue

        task_id = _field(data, "task_id")
        cmd_id = _field(data, "cmd_id") or _field(data, "parent_cmd")
        status = _field(data, "status").lower()
        assigned_to = _field(data, "assigned_to") or yaml_file.stem
        title = _title(data)
        agent_name = AGENT_NAME.get(assigned_to, assigned_to)

        if status in ACTIVE_STATUSES:
            in_progress.append(
                {
                    "cmd": cmd_id,
                    "content": title,
                    "assignee": agent_name,
                    "status": "🔄 作業中",
                }
            )
        elif status in IDLE_STATUSES:
            last_task = f"{task_id}完了: {title}" if task_id else "—"
            idle_members.append(
                {
                    "name": agent_name,
                    "model": "",
                    "status": "待機",
                    "last_task": last_task,
                }
            )

    return in_progress, idle_members


def _md_cell(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("|", "\\|").replace("\n", "<br>")


def render_in_progress(rows: list[dict[str, str]]) -> str:
    lines = ["## 🔄 進行中 - 只今、戦闘中でござる", ""]
    lines.append("| cmd | 内容 | 担当 | 状態 |")
    lines.append("|---|---|---|---|")
    if not rows:
        lines.append("| （まだなし） | | | |")
    else:
        for r in rows:
            lines.append(
                "| {} | {} | {} | {} |".format(
                    _md_cell(r.get("cmd", "")),
                    _md_cell(r.get("content", "")),
                    _md_cell(r.get("assignee", "")),
                    _md_cell(r.get("status", "")),
                )
            )
    lines.append("")
    return "\n".join(lines) + "\n"


def render_idle(rows: list[dict[str, str]]) -> str:
    lines = ["## 🏯 待機中の構成員", ""]
    lines.append("| 構成員 | 状態 | 最終タスク |")
    lines.append("|---|---|-----|")
    if not rows:
        lines.append("| —  | 待機なし | — |")
    else:
        for r in rows:
            name = r.get("name", "")
            model = r.get("model", "")
            if model and "(" not in name:
                name = f"{name}({model})"
            lines.append(
                "| {} | {} | {} |".format(
                    _md_cell(name),
                    _md_cell(r.get("status", "")),
                    _md_cell(r.get("last_task", "")),
                )
            )
    lines.append("")
    return "\n".join(lines) + "\n"


METRIC_HEADERS = [
    "日付(JST)",
    "成功",
    "失敗(cron)",
    "karo auto-compact",
    "gunshi auto-compact",
    "safe_window発動",
    "karo self_clear",
    "gunshi self_clear",
    "karo self_compact",
    "gunshi self_compact",
]
METRIC_KEYS = [
    "date",
    "success",
    "failure",
    "karo_compact",
    "gunshi_compact",
    "safe_window",
    "karo_self_clear",
    "gunshi_self_clear",
    "karo_self_compact",
    "gunshi_self_compact",
]


def render_metrics(metrics: list[dict[str, Any]]) -> str:
    lines = ["## 📊 運用指標", ""]
    lines.append("| " + " | ".join(METRIC_HEADERS) + " |")
    lines.append(
        "|" + "|".join("-" * (len(h) if len(h) > 2 else 3) for h in METRIC_HEADERS) + "|"
    )
    if not metrics:
        lines.append("| （まだなし） |" + " |" * (len(METRIC_HEADERS) - 1))
    else:
        for r in metrics:
            cells = [_md_cell(r.get(k, "")) for k in METRIC_KEYS]
            lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    return "\n".join(lines) + "\n"


def replace_section(content: str, header_pattern: str, replacement: str) -> str:
    """Replace a `## ` section in markdown with `replacement` (must include trailing
    blank line). Section ends just before the next `## ` heading or EOF."""
    m = re.search(header_pattern, content, re.MULTILINE)
    if not m:
        # Section missing — append at end (defensive: shouldn't happen)
        sep = "" if content.endswith("\n") else "\n"
        return content + sep + replacement
    start = m.start()
    nm = re.search(r"^## ", content[m.end():], re.MULTILINE)
    end = m.end() + nm.start() if nm else len(content)
    return content[:start] + replacement + content[end:]


def update_dashboard_yaml(
    in_progress: list[dict[str, str]],
    idle_members: list[dict[str, str]],
) -> list[dict[str, Any]]:
    """Update dashboard.yaml with in_progress / idle_members / metadata.last_updated /
    metrics. Return the metrics list (sorted, last 7 days) for dashboard.md sync."""
    try:
        d = yaml.safe_load(dashboard_yaml.read_text()) or {}
    except (yaml.YAMLError, FileNotFoundError) as e:
        print(f"[WARN] dashboard.yaml read failed: {e}", file=sys.stderr)
        d = {}

    d["in_progress"] = in_progress or []
    d["idle_members"] = idle_members or [
        {"name": "—", "model": "", "status": "待機なし", "last_task": "—"}
    ]
    d.setdefault("metadata", {})["last_updated"] = f"{timestamp} JST"

    if daily_yaml.exists():
        try:
            daily = yaml.safe_load(daily_yaml.read_text()) or {}
            date_jst = str(daily.get("date_jst", "")).split()[0]
            if date_jst:
                metrics = d.get("metrics") or []
                row = next(
                    (m for m in metrics if str(m.get("date", "")) == date_jst), None
                )
                if row is None:
                    row = {
                        "date": date_jst,
                        "success": 0,
                        "failure": 0,
                        "karo_compact": "-",
                        "gunshi_compact": "-",
                        "safe_window": "-",
                    }
                    metrics.append(row)
                row.pop("pub_us", None)
                row.pop("kill_switch", None)
                row["success"] = int(daily.get("success_total", 0) or 0)
                row["failure"] = int(daily.get("failure_total", 0) or 0)
                d["metrics"] = sorted(metrics, key=lambda m: str(m.get("date", "")))[
                    -7:
                ]
        except (yaml.YAMLError, ValueError, TypeError) as e:
            print(f"[WARN] metrics update failed: {e}", file=sys.stderr)

    with dashboard_yaml.open("w") as f:
        yaml.dump(d, f, allow_unicode=True, default_flow_style=False)

    return d.get("metrics") or []


def main() -> None:
    in_progress, idle_members = collect_tasks()
    metrics = update_dashboard_yaml(in_progress, idle_members)

    if not dashboard_md.exists():
        print(f"[ERROR] {dashboard_md} not found", file=sys.stderr)
        sys.exit(1)

    content = dashboard_md.read_text()

    # 1) "最終更新: ..." line (1st occurrence near top)
    content = re.sub(
        r"^最終更新:.*$",
        f"最終更新: {timestamp} JST",
        content,
        count=1,
        flags=re.MULTILINE,
    )

    # 2) Section replacements
    content = replace_section(
        content, r"^## 🔄 進行中.*$", render_in_progress(in_progress)
    )
    content = replace_section(
        content, r"^## 🏯 待機中.*$", render_idle(idle_members)
    )
    content = replace_section(
        content, r"^## 📊 運用指標.*$", render_metrics(metrics)
    )

    dashboard_md.write_text(content)
    print(
        "dashboard partial-update done: in_progress={}, idle={}, metrics_rows={}".format(
            len(in_progress), len(idle_members), len(metrics)
        )
    )


if __name__ == "__main__":
    main()
PYEOF

echo "dashboard.md updated ($(bash "$SCRIPT_DIR/jst_now.sh" 2>/dev/null || date))"
