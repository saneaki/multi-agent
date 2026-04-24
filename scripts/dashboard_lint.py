#!/usr/bin/env python3
import re
import sys
from collections import defaultdict

DASHBOARD_PATH = "/home/ubuntu/shogun/dashboard.md"
TARGET_SECTIONS = ("本日の戦果", "昨日の戦果", "一昨日の戦果")


def parse_table_rows(lines):
    in_target_section = False
    for lineno, line in enumerate(lines, start=1):
        section_match = re.match(r"^##\s+✅\s+(.+?)（", line)
        if section_match:
            in_target_section = any(name in section_match.group(1) for name in TARGET_SECTIONS)
            continue
        if not in_target_section:
            continue
        if line.startswith("## "):
            in_target_section = False
            continue
        if not line.startswith("|"):
            continue
        if re.match(r"^\|\s*-+\s*\|", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        if cells[0] == "時刻" and cells[1] == "戦場" and cells[2] == "任務":
            continue
        yield lineno, line.rstrip("\n"), cells


def lint_dashboard():
    try:
        with open(DASHBOARD_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except OSError as e:
        print(f"[LINT] WARN: Rule IO: {DASHBOARD_PATH} → {e}", file=sys.stderr)
        print("[LINT] 1 warning(s) found")
        sys.exit(0)

    warnings = []
    cmd_occurrences = defaultdict(list)

    parsed_rows = list(parse_table_rows(lines))
    for lineno, raw_line, cells in parsed_rows:
        mission = cells[2]

        for cmd_id in sorted(set(re.findall(r"cmd_\d+", raw_line))):
            cmd_occurrences[cmd_id].append((lineno, raw_line))

        if re.search(r"Scope [A-Z]", mission):
            warnings.append((2, raw_line, "subtask行検出 (Scope [A-Z])"))

        if re.search(r"発令\s*$", mission):
            warnings.append((3, raw_line, "発令のみ行の可能性"))

        if re.search(r"(shogun|将軍)", mission, flags=re.IGNORECASE) and not re.search(
            r"cmd_\d+", mission
        ):
            warnings.append((4, raw_line, "将軍/shogun単独行"))

    for cmd_id, rows in cmd_occurrences.items():
        if len(rows) > 1:
            for lineno, raw_line in rows:
                warnings.append((1, raw_line, f"{cmd_id} が複数行に重複 (line {lineno})"))

    warnings.sort(key=lambda x: (x[0], x[1]))
    for rule_no, row_text, reason in warnings:
        print(f"[LINT] WARN: Rule {rule_no}: {row_text} → {reason}", file=sys.stderr)

    print(f"[LINT] {len(warnings)} warning(s) found")
    sys.exit(0)


if __name__ == "__main__":
    lint_dashboard()
