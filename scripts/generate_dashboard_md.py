#!/usr/bin/env python3
"""Generate dashboard.md from dashboard.yaml (SoT)."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


TABLE_4_EMPTY_ROW = "| （まだなし） | | | |"


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


def generate_markdown(data: dict[str, Any]) -> str:
    meta = data.get("metadata", {})
    last_updated = meta.get("last_updated", "")

    lines: list[str] = []
    lines.append("# 📊 戦況報告")
    lines.append(f"最終更新: {last_updated}")
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

    lines.append("## 🚨 要対応 - 殿のご判断をお待ちしております")
    lines.append("")
    action_rows = [
        [r.get("tag", ""), r.get("title", ""), r.get("detail", "")]
        for r in data.get("action_required", [])
    ]
    lines.extend(render_table(["タグ", "項目", "詳細"], action_rows, TABLE_4_EMPTY_ROW))
    lines.append("")

    lines.append("## 📊 運用指標")
    lines.append("")
    metrics_rows = [
        [
            r.get("date", ""),
            r.get("pub_us", ""),
            r.get("success", ""),
            r.get("failure", ""),
            r.get("kill_switch", ""),
            r.get("karo_compact", ""),
            r.get("gunshi_compact", ""),
            r.get("safe_window", ""),
        ]
        for r in data.get("metrics", [])
    ]
    lines.extend(
        render_table(
            [
                "日付(JST)",
                "/pub-us起動",
                "成功",
                "失敗",
                "kill-switch発動",
                "karo auto-compact",
                "gunshi auto-compact",
                "safe_window発動",
            ],
            metrics_rows,
        )
    )
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
    today_rows = [
        [r.get("time", ""), r.get("battlefield", ""), r.get("task", ""), r.get("result", "")]
        for r in achievements.get("today", [])
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
        for r in yesterday.get("items", [])
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
        for r in day_before.get("items", [])
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

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate dashboard.md from dashboard.yaml")
    parser.add_argument("--input", default="dashboard.yaml", help="Input YAML path")
    parser.add_argument("--output", default="dashboard.md", help="Output Markdown path")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    with input_path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    markdown = generate_markdown(data)
    output_path.write_text(markdown, encoding="utf-8")


if __name__ == "__main__":
    main()
