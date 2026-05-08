#!/usr/bin/env python3
"""Generate dashboard.md from dashboard.yaml (SoT).

Modes (cmd_659 Scope C):
  - "partial" (default when markers exist in output md):
      Replace only the content between managed boundaries:
      <!-- ACTION_REQUIRED:START --> ... <!-- ACTION_REQUIRED:END -->
      <!-- OBSERVATION_QUEUE:START --> ... <!-- OBSERVATION_QUEUE:END -->
      Outside-boundary sections are copied verbatim from the existing md
      (touch-禁止 — protects achievements/frog/skill 等の直編集領域).
  - "full" (legacy, used when no markers / fresh init):
      Regenerate the entire dashboard.md from dashboard.yaml.
      Used by Scope F for the initial markered template injection.

Severity sort + badge prefix (R5):
  P0 → HIGH → MEDIUM → INFO → 提案/情報 (legacy tag entries last)
  badges: 🔥 P0 / ⚠️ HIGH / 📌 MEDIUM / ℹ️ INFO

Atomic write (R3):
  tempfile + fsync + os.rename. validation 失敗時は前回 md を保持。
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

import yaml


TABLE_4_EMPTY_ROW = "| （まだなし） | | | |"
IN_PROGRESS_REQUIRED_FIELDS = {"cmd", "content", "status", "assignee"}
IN_PROGRESS_KNOWN_FIELDS = IN_PROGRESS_REQUIRED_FIELDS | {"agent"}
ACHIEVEMENTS_REQUIRED_FIELDS = {"time", "battlefield", "task", "result"}

# Boundary markers (cmd_659 Scope C / R1)
ACTION_REQUIRED_START = "<!-- ACTION_REQUIRED:START -->"
ACTION_REQUIRED_END = "<!-- ACTION_REQUIRED:END -->"
OBSERVATION_QUEUE_START = "<!-- OBSERVATION_QUEUE:START -->"
OBSERVATION_QUEUE_END = "<!-- OBSERVATION_QUEUE:END -->"

# Severity ordering (R5)
SEVERITY_ORDER = {"P0": 0, "HIGH": 1, "MEDIUM": 2, "INFO": 3}
SEVERITY_BADGE = {
    "P0": "🔥 P0",
    "HIGH": "⚠️ HIGH",
    "MEDIUM": "📌 MEDIUM",
    "INFO": "ℹ️ INFO",
}
VALID_SEVERITIES = ("P0", "HIGH", "MEDIUM", "INFO")


def md_cell(value: Any) -> str:
    if value is None:
        return ""
    text = str(value)
    return text.replace("|", "\\|").replace("\n", "<br>")


def render_table(headers: list[str], rows: list[list[Any]], empty_row: str | None = None) -> list[str]:
    lines = [
        "| " + " | ".join(headers) + " |",
        "|" + "|".join("-" * (len(h) if len(h) > 2 else 3) for h in headers) + "|",
    ]

    if not rows:
        if empty_row:
            lines.append(empty_row)
        return lines

    for row in rows:
        lines.append("| " + " | ".join(md_cell(col) for col in row) + " |")
    return lines


def format_today_label(last_updated: str) -> str:
    # expected: YYYY-MM-DD HH:MM JST
    try:
        date_part = last_updated.split()[0]
        _, m, d = date_part.split("-")
        return f"{int(m)}/{int(d)} JST"
    except Exception:
        return "本日"


def parse_archive_header(header: str) -> tuple[str, str]:
    if not header:
        return "", ""
    if " — " in header:
        left, right = header.split(" — ", 1)
        return left.strip(), right.strip()
    return header.strip(), ""


def maybe_name_with_model(name: str, model: str) -> str:
    if not model:
        return name
    if "(" in name and ")" in name:
        return name
    return f"{name}({model})"


def _section_items(section: Any) -> list[dict[str, Any]]:
    """Accept either legacy list format or current {header, items} dict format."""
    if isinstance(section, list):
        return [r for r in section if isinstance(r, dict)]
    if isinstance(section, dict):
        items = section.get("items", [])
        if isinstance(items, list):
            return [r for r in items if isinstance(r, dict)]
    return []


def validate_in_progress(entries: Any) -> None:
    if not isinstance(entries, list):
        return

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        cmd = entry.get("cmd", "")
        for field in IN_PROGRESS_REQUIRED_FIELDS:
            if field not in entry:
                print(
                    f"WARNING: [schema] in_progress entry missing required field: '{field}' (cmd={cmd})",
                    file=sys.stderr,
                )
        if "agent" in entry:
            print(
                f"WARNING: [schema] 'agent' should be 'assignee' in in_progress entry (cmd={cmd})",
                file=sys.stderr,
            )
        for field in entry:
            if field not in IN_PROGRESS_KNOWN_FIELDS:
                print(
                    f"WARNING: [schema] unknown field '{field}' in in_progress entry",
                    file=sys.stderr,
                )


def validate_achievements(entries: Any, section_name: str) -> None:
    for entry in _section_items(entries):
        for field in ACHIEVEMENTS_REQUIRED_FIELDS:
            if field not in entry:
                print(
                    f"WARNING: [schema] {section_name} achievement entry missing: '{field}'",
                    file=sys.stderr,
                )


def _get_clasp_badge(
    token_path: str = "/home/ubuntu/.clasprc.json",
    warn_days: int = 25,
    critical_days: int = 28,
) -> str:
    path = Path(token_path)
    if not path.exists():
        return "clasp: ❓ (token未設定)"
    mtime = datetime.datetime.fromtimestamp(path.stat().st_mtime)
    days = (datetime.datetime.now() - mtime).days
    updated = mtime.strftime("%Y-%m-%d")
    if days >= critical_days:
        return f"clasp: 🔴 {days}日 ⚠ re-login 必要"
    if days >= warn_days:
        return f"clasp: 🟡 {days}日 ({updated}更新)"
    return f"clasp: 🟢 {days}日 ({updated}更新)"


def collect_violations(base_dir: Path, last_updated: str) -> list[tuple[str, str, str, str]]:
    """Collect violation rows: (tag, count, last_seen, recommended_action)."""
    rows: list[tuple[str, str, str, str]] = []

    # L019-skip: count shogun replies without cross-source check — static 0 (git-log analysis not yet automated)
    rows.append(("L019-skip", "0", "—", "—"))

    # L020-stale: dashboard staleness violation — stale if last_updated > 4h ago
    stale_last_seen = "—"
    stale_action = "—"
    try:
        date_part = last_updated.split()[0]  # "YYYY-MM-DD"
        time_part = last_updated.split()[1] if len(last_updated.split()) > 1 else "00:00"
        lu_dt = datetime.datetime.strptime(f"{date_part} {time_part}", "%Y-%m-%d %H:%M")
        elapsed_min = (datetime.datetime.now() - lu_dt).total_seconds() / 60
        if elapsed_min > 240:
            stale_last_seen = f"{date_part} {time_part}"
            stale_action = "dashboard 再生成"
            rows.append(("L020-stale", "1", stale_last_seen, stale_action))
        else:
            rows.append(("L020-stale", "0", "—", "—"))
    except Exception:
        rows.append(("L020-stale", "—", "—", "—"))

    # Step1.5-skip: shogun_session_start.sh 未実行検出 — not yet automated
    rows.append(("Step1.5-skip", "—", "—", "shogun_session_start.sh 実行"))

    return rows


def violation_section(last_updated: str) -> list[str]:
    """Generate the '⚠️ 違反検出 (last 24h)' section."""
    lines = ["## ⚠️ 違反検出 (last 24h)", ""]
    rows = collect_violations(Path("."), last_updated)
    lines.extend(render_table(
        ["tag", "count", "last_seen", "recommended_action"],
        list(rows),
    ))
    lines.append("")
    return lines


def _action_required_sort_key(entry: dict[str, Any]) -> tuple[int, str]:
    """Sort by severity (P0 first), then created_at (oldest first within severity).

    Legacy entries without severity rank after all severity-tagged entries
    (using order index 99 to push them down).
    """
    sev = entry.get("severity")
    sev_idx = SEVERITY_ORDER.get(sev, 99)
    created = entry.get("created_at", "9999-99-99")
    return (sev_idx, str(created))


def render_action_required_section(action_required: list[dict[str, Any]]) -> str:
    """Render the🚨 section markdown (header + table) for boundary replacement.

    Severity sort + badge prefix (R5). Legacy entries (no severity) keep their tag.
    """
    lines: list[str] = []
    lines.append("## 🚨 要対応 - 殿のご判断をお待ちしております")
    lines.append("")

    sorted_items = sorted(
        [r for r in action_required if isinstance(r, dict)],
        key=_action_required_sort_key,
    )

    rows: list[list[str]] = []
    for r in sorted_items:
        sev = r.get("severity")
        if sev in VALID_SEVERITIES:
            tag_cell = f"{SEVERITY_BADGE[sev]} {r.get('tag', '')}".strip()
        else:
            # Legacy entry — preserve tag as-is
            tag_cell = r.get("tag", "")
        rows.append([
            tag_cell,
            r.get("title", ""),
            r.get("detail", ""),
        ])

    lines.extend(render_table(["タグ", "項目", "詳細"], rows, TABLE_4_EMPTY_ROW))
    lines.append("")
    return "\n".join(lines)


def render_observation_queue_section(observation_queue: list[dict[str, Any]]) -> str:
    """Render time-waiting / continued-observation dashboard items."""
    lines: list[str] = []
    lines.append("## ⏳ 時間経過待ち / 観察継続")
    lines.append("")

    sorted_items = sorted(
        [r for r in observation_queue if isinstance(r, dict)],
        key=_action_required_sort_key,
    )

    rows: list[list[str]] = []
    for r in sorted_items:
        sev = r.get("severity")
        if sev in VALID_SEVERITIES:
            tag_cell = f"{SEVERITY_BADGE[sev]} {r.get('tag', '')}".strip()
        else:
            tag_cell = r.get("tag", "")
        rows.append([
            tag_cell,
            r.get("title", ""),
            r.get("detail", ""),
        ])

    lines.extend(render_table(["タグ", "項目", "詳細"], rows, TABLE_4_EMPTY_ROW))
    lines.append("")
    return "\n".join(lines)


def partial_replace(
    existing_md: str,
    start_marker: str,
    end_marker: str,
    new_content: str,
) -> str | None:
    """Replace content between start and end markers (markers themselves preserved).

    Returns the modified md, or None if either marker is missing (safe fallback —
    R3: validation 失敗時は前回 md を保持).
    """
    s = existing_md.find(start_marker)
    if s == -1:
        return None
    e = existing_md.find(end_marker, s + len(start_marker))
    if e == -1:
        return None

    head = existing_md[: s + len(start_marker)]
    tail = existing_md[e:]
    # new_content gets surrounded by newlines so it stays on its own block
    return head + "\n" + new_content.rstrip("\n") + "\n" + tail


def ensure_or_replace_observation_queue(existing_md: str, new_content: str) -> str | None:
    """Replace observation queue if markers exist, otherwise insert after ACTION_REQUIRED."""
    replaced = partial_replace(
        existing_md,
        OBSERVATION_QUEUE_START,
        OBSERVATION_QUEUE_END,
        new_content,
    )
    if replaced is not None:
        return replaced

    action_end_pos = existing_md.find(ACTION_REQUIRED_END)
    if action_end_pos == -1:
        return None

    insert_pos = action_end_pos + len(ACTION_REQUIRED_END)
    block = (
        "\n\n"
        f"{OBSERVATION_QUEUE_START}\n"
        f"{new_content.rstrip()}\n"
        f"{OBSERVATION_QUEUE_END}"
    )
    return existing_md[:insert_pos] + block + existing_md[insert_pos:]


def validate_dashboard_yaml(data: dict[str, Any]) -> list[str]:
    """Schema validation (R3): return list of errors (empty = ok)."""
    errors: list[str] = []
    ar = data.get("action_required") or []
    if not isinstance(ar, list):
        errors.append("action_required must be a list")
    oq = data.get("observation_queue") or []
    if not isinstance(oq, list):
        errors.append("observation_queue must be a list")

    for section_name, items in (("action_required", ar), ("observation_queue", oq)):
        if not isinstance(items, list):
            continue
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                errors.append(f"{section_name}[{i}]: not a dict")
                continue
            # New-format entries must have severity in valid set
            sev = item.get("severity")
            if sev is not None and sev not in VALID_SEVERITIES:
                errors.append(
                    f"{section_name}[{i}]: invalid severity '{sev}'"
                )
    return errors


def write_atomic(output_path: Path, content: str) -> None:
    """Atomic write: tempfile + fsync + os.rename (R3 atomic rename)."""
    dir_path = str(output_path.parent) if output_path.parent.as_posix() else "."
    tmp_fd, tmp_name = tempfile.mkstemp(
        dir=dir_path,
        prefix=f".{output_path.name}.",
        suffix=".tmp",
    )
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_name, str(output_path))
    except Exception:
        try:
            os.unlink(tmp_name)
        except Exception:
            pass
        raise


def generate_markdown(data: dict[str, Any]) -> str:
    meta = data.get("metadata", {})
    last_updated = meta.get("last_updated", "")

    try:
        with Path("config/settings.yaml").open("r", encoding="utf-8") as _f:
            _cfg = yaml.safe_load(_f) or {}
        _clasp_cfg = _cfg.get("clasp", {})
    except Exception:
        _clasp_cfg = {}
    clasp_badge = _get_clasp_badge(
        token_path=_clasp_cfg.get("token_path", "/home/ubuntu/.clasprc.json"),
        warn_days=int(_clasp_cfg.get("warn_days", 25)),
        critical_days=int(_clasp_cfg.get("critical_days", 28)),
    )

    lines: list[str] = []
    lines.append("# 📊 戦況報告")
    lines.append(f"最終更新: {last_updated}")
    lines.append(clasp_badge)
    lines.append("")

    lines.append("## 📋 記載ルール (Self-Documentation)")
    lines.append("> **更新者必読**: このセクションのルールを遵守して dashboard を更新すること。")
    lines.append("")
    doc_rows = [
        [r.get("category", ""), r.get("rule_summary", ""), r.get("rationale", "")]
        for r in data.get("documentation_rules", [])
    ]
    lines.extend(render_table(["分類", "ルール概要", "根拠"], doc_rows))
    lines.append("")

    frog = data.get("frog", {})
    lines.append("## 🐸 Frog / ストリーク")
    lines.append("")
    today_frog = frog.get("today") if frog.get("today") not in (None, "") else "未設定"
    vf_remaining = frog.get("vf_remaining", 0)
    frog_rows = [
        ["今日のFrog", today_frog],
        ["Frog状態", frog.get("status", "")],
        [
            "ストリーク",
            f"🔥 {frog.get('streak_days', 0)}日目継続中 (最長: {frog.get('streak_max', 0)}日)",
        ],
        ["今日の完了", frog.get("completed_today", 0)],
        ["VFタスク残り", f"{vf_remaining}件（うち今日期限: 0件）"],
    ]
    lines.extend(render_table(["項目", "値"], frog_rows))
    lines.append("")

    # cmd_659 Scope C: action_required section is renderer-managed (boundary protected)
    lines.append(ACTION_REQUIRED_START)
    lines.append(render_action_required_section(data.get("action_required") or []))
    lines.append(ACTION_REQUIRED_END)
    lines.append("")

    lines.append("## 🔄 進行中 - 只今、戦闘中でござる")
    lines.append("")
    in_progress_rows = [
        [r.get("cmd", ""), r.get("content", ""), r.get("assignee", ""), r.get("status", "")]
        for r in data.get("in_progress", [])
    ]
    lines.extend(render_table(["cmd", "内容", "担当", "状態"], in_progress_rows, TABLE_4_EMPTY_ROW))
    lines.append("")

    lines.append("## 🏯 待機中の構成員")
    lines.append("")
    idle_rows = [
        [
            maybe_name_with_model(r.get("name", ""), r.get("model", "")),
            r.get("status", ""),
            r.get("last_task", ""),
        ]
        for r in data.get("idle_members", [])
    ]
    lines.extend(render_table(["構成員", "状態", "最終タスク"], idle_rows))
    lines.append("")

    achievements = data.get("achievements", {})
    today_label = format_today_label(last_updated)
    lines.append(f"## ✅ 本日の戦果（{today_label}）")
    lines.append("")
    def _today_task_cell(r: dict) -> str:
        task = r.get("task", "")
        result = r.get("result", "")
        if "ends完了" in result:
            import re as _re
            m = _re.search(r"(cmd_\d+)完遂", task)
            if m:
                return f"🏆🏆{m.group(1)} COMPLETE — {task}"
        return task

    today_rows = [
        [r.get("time", ""), r.get("battlefield", ""), _today_task_cell(r), r.get("result", "")]
        for r in _section_items(achievements.get("today", {}))
    ]
    lines.extend(render_table(["時刻", "戦場", "任務", "結果"], today_rows, TABLE_4_EMPTY_ROW))
    lines.append("")

    yesterday = achievements.get("yesterday", {})
    y_date, y_suffix = parse_archive_header(yesterday.get("header", ""))
    y_title = f"## ✅ 昨日の戦果（{y_date}）"
    if y_suffix:
        y_title += f"— {y_suffix}"
    lines.append(y_title)
    lines.append("")
    yesterday_rows = [
        [r.get("time", ""), r.get("battlefield", ""), r.get("task", ""), r.get("result", "")]
        for r in _section_items(yesterday)
    ]
    lines.extend(render_table(["時刻", "戦場", "任務", "結果"], yesterday_rows, TABLE_4_EMPTY_ROW))
    lines.append("")

    day_before = achievements.get("day_before", {})
    db_date, db_suffix = parse_archive_header(day_before.get("header", ""))
    db_title = f"## ✅ 一昨日の戦果（{db_date}）"
    if db_suffix:
        db_title += f"— {db_suffix}"
    lines.append(db_title)
    lines.append("")
    day_before_rows = [
        [r.get("time", ""), r.get("battlefield", ""), r.get("task", ""), r.get("result", "")]
        for r in _section_items(day_before)
    ]
    lines.extend(render_table(["時刻", "戦場", "任務", "結果"], day_before_rows, TABLE_4_EMPTY_ROW))
    lines.append("")

    lines.append("## 🛠️ スキル候補（承認待ち）")
    lines.append("")
    lines.append("承認待ち候補を全件表示。✅実装済みは `memory/skill_history.md` にアーカイブ済み。")
    lines.append("")
    skill_rows = [
        [f"**{r.get('name', '')}**", f"{r.get('source', '')}: {r.get('summary', '')}", r.get("status", "")]
        for r in data.get("skill_candidates", [])
    ]
    lines.extend(render_table(["スキル名", "発見元", "概要"], skill_rows, "| （まだなし） | | |"))
    lines.append("")

    lines.append(OBSERVATION_QUEUE_START)
    lines.append(render_observation_queue_section(data.get("observation_queue") or []))
    lines.append(OBSERVATION_QUEUE_END)
    lines.append("")

    lines.extend(violation_section(last_updated))

    lines.append("## 📊 運用指標")
    lines.append("")
    metrics_rows = [
        [
            r.get("date", ""),
            r.get("success", ""),
            r.get("failure", ""),
            r.get("karo_compact", ""),
            r.get("gunshi_compact", ""),
            r.get("safe_window", ""),
            r.get("karo_self_clear", ""),
            r.get("gunshi_self_clear", ""),
            r.get("karo_self_compact", ""),
            r.get("gunshi_self_compact", ""),
        ]
        for r in data.get("metrics", [])
    ]
    lines.extend(
        render_table(
            [
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
            ],
            metrics_rows,
        )
    )
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate dashboard.md from dashboard.yaml")
    parser.add_argument("--input", default="dashboard.yaml", help="Input YAML path")
    parser.add_argument("--output", default="dashboard.md", help="Output Markdown path")
    parser.add_argument(
        "--mode",
        choices=("auto", "partial", "full"),
        default="auto",
        help="auto (default): partial if markers exist in output md; full otherwise. "
             "partial: replace managed ACTION_REQUIRED/OBSERVATION_QUEUE boundary content (R1+R3 safe). "
             "full: legacy full regeneration (used by Scope F initial injection).",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    # Load yaml
    try:
        with input_path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except Exception as exc:
        print(f"ERROR: failed to parse {input_path}: {exc}", file=sys.stderr)
        # R3: validation 失敗時は md を変更しない
        sys.exit(3)

    # R3 schema validate (action_required only — other sections are legacy/lenient)
    schema_errors = validate_dashboard_yaml(data)
    if schema_errors:
        print(
            f"ERROR: dashboard.yaml schema validation failed "
            f"({len(schema_errors)} errors):",
            file=sys.stderr,
        )
        for e in schema_errors:
            print(f"  - {e}", file=sys.stderr)
        # Persist last_render_error for observability (best-effort)
        try:
            data_copy = dict(data)
            data_copy["last_render_error"] = {
                "errors": schema_errors,
                "timestamp": datetime.datetime.now(
                    datetime.timezone(datetime.timedelta(hours=9))
                ).strftime("%Y-%m-%dT%H:%M:%S+09:00"),
            }
            # We deliberately don't write back to yaml — caller decides
        except Exception:
            pass
        sys.exit(3)

    # Lenient warnings (legacy)
    validate_in_progress(data.get("in_progress", []))
    achievements = data.get("achievements", {})
    validate_achievements(achievements.get("today", {}), "today")
    validate_achievements(achievements.get("yesterday", {}), "yesterday")
    validate_achievements(achievements.get("day_before", {}), "day_before")

    # Determine effective mode
    mode = args.mode
    existing_md = ""
    if output_path.exists():
        try:
            existing_md = output_path.read_text(encoding="utf-8")
        except Exception:
            existing_md = ""

    has_action_markers = (
        ACTION_REQUIRED_START in existing_md
        and ACTION_REQUIRED_END in existing_md
    )

    if mode == "auto":
        mode = "partial" if has_action_markers else "full"

    if mode == "partial":
        if not has_action_markers:
            print(
                f"ERROR: --mode=partial requires both '{ACTION_REQUIRED_START}' and "
                f"'{ACTION_REQUIRED_END}' markers in {output_path}. "
                f"dashboard.md not modified (safe fallback). "
                f"Run with --mode=full to bootstrap.",
                file=sys.stderr,
            )
            sys.exit(3)
        action_required_md = render_action_required_section(
            data.get("action_required") or []
        )
        new_md = partial_replace(
            existing_md, ACTION_REQUIRED_START, ACTION_REQUIRED_END, action_required_md
        )
        if new_md is None:
            print(
                "ERROR: marker boundary replacement failed; md not modified.",
                file=sys.stderr,
            )
            sys.exit(3)

        observation_md = render_observation_queue_section(
            data.get("observation_queue") or []
        )
        new_md = ensure_or_replace_observation_queue(new_md, observation_md)
        if new_md is None:
            print(
                "ERROR: observation_queue boundary replacement failed; md not modified.",
                file=sys.stderr,
            )
            sys.exit(3)
        # Idempotent: skip write if unchanged
        if new_md == existing_md:
            print(
                "[generate_dashboard_md] partial: no change (idempotent skip)",
                file=sys.stderr,
            )
            return
        write_atomic(output_path, new_md)
        print(
            f"[generate_dashboard_md] partial replace complete: {output_path}",
            file=sys.stderr,
        )
    else:
        # full mode: regenerate everything from yaml
        markdown = generate_markdown(data)
        write_atomic(output_path, markdown)
        print(
            f"[generate_dashboard_md] full regeneration complete: {output_path}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
