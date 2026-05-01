#!/usr/bin/env python3
"""Round-trip test: verify dashboard.yaml content is correctly reflected in dashboard.md.

Detects silent failures in the YAML→MD generation chain
(scripts/generate_dashboard_md.py).

Usage:
  python3 scripts/test_dashboard_roundtrip.py [--yaml PATH] [--md PATH] [--strict]

Exit codes:
  0 — all checks pass
  1 — at least one check failed (or input files missing)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any, Callable

import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_YAML = REPO_ROOT / "dashboard.yaml"
DEFAULT_MD = REPO_ROOT / "dashboard.md"

EMPTY_PLACEHOLDER = "（まだなし）"


def section_items(section: Any) -> list[dict[str, Any]]:
    """Accept legacy list format or current {header, items} dict format."""
    if isinstance(section, list):
        return [r for r in section if isinstance(r, dict)]
    if isinstance(section, dict):
        items = section.get("items", [])
        if isinstance(items, list):
            return [r for r in items if isinstance(r, dict)]
    return []


def count_data_rows(md_text: str, section_marker: str) -> int:
    """Count non-placeholder data rows in the table directly under section_marker.

    Excludes the markdown table header row, separator row, and the
    `（まだなし）` placeholder row used for empty sections.
    """
    in_section = False
    header_seen = False
    sep_seen = False
    count = 0

    for line in md_text.split("\n"):
        if section_marker in line:
            in_section = True
            continue
        if not in_section:
            continue
        if line.startswith("## "):
            break
        if not line.startswith("|"):
            continue

        if not header_seen:
            header_seen = True
            continue
        if not sep_seen:
            sep_seen = True
            continue
        if EMPTY_PLACEHOLDER in line:
            continue
        count += 1

    return count


def find_section(md_text: str, section_marker: str) -> str:
    """Return the substring of md_text starting at section_marker until the next `## `."""
    start = md_text.find(section_marker)
    if start == -1:
        return ""
    next_section = md_text.find("\n## ", start + 1)
    return md_text[start:next_section] if next_section != -1 else md_text[start:]


def report(name: str, ok: bool, detail: str = "") -> bool:
    if ok:
        print(f"PASS: {name}")
    else:
        print(f"FAIL: {name} — {detail}")
    return ok


def check_in_progress_count(yaml_data: dict, md_text: str) -> bool:
    in_progress = yaml_data.get("in_progress") or []
    yaml_count = len([e for e in in_progress if isinstance(e, dict)])
    md_count = count_data_rows(md_text, "## 🔄 進行中")
    return report(
        "in_progress count",
        yaml_count == md_count,
        f"yaml={yaml_count} md={md_count}",
    )


def check_in_progress_assignees(yaml_data: dict, md_text: str) -> bool:
    missing: list[str] = []
    for entry in yaml_data.get("in_progress") or []:
        if not isinstance(entry, dict):
            continue
        assignee = str(entry.get("assignee", "")).strip()
        if not assignee:
            continue
        if assignee not in md_text:
            missing.append(assignee)
    return report(
        "in_progress assignees",
        not missing,
        f"missing={missing}",
    )


def check_today_achievements_count(yaml_data: dict, md_text: str) -> bool:
    today = yaml_data.get("achievements", {}).get("today")
    yaml_count = len(section_items(today))
    md_count = count_data_rows(md_text, "## ✅ 本日の戦果")
    return report(
        "today achievements count",
        yaml_count == md_count,
        f"yaml={yaml_count} md={md_count}",
    )


def check_last_updated(yaml_data: dict, md_text: str) -> bool:
    last_updated = str(yaml_data.get("metadata", {}).get("last_updated", "")).strip()
    if not last_updated:
        return report("metadata.last_updated", False, "missing in yaml")
    return report(
        "metadata.last_updated",
        last_updated in md_text,
        f"value '{last_updated}' not found in md",
    )


def check_frog_status(yaml_data: dict, md_text: str) -> bool:
    status = str(yaml_data.get("frog", {}).get("status", "")).strip()
    if not status:
        return report("frog.status", False, "missing in yaml")
    section_text = find_section(md_text, "## 🐸")
    if not section_text:
        return report("frog.status", False, "🐸 section not found in md")
    return report(
        "frog.status",
        status in section_text,
        f"value '{status}' not found in 🐸 section",
    )


Check = Callable[[dict, str], bool]
CHECKS: list[tuple[str, Check]] = [
    ("in_progress count", check_in_progress_count),
    ("in_progress assignees", check_in_progress_assignees),
    ("today achievements count", check_today_achievements_count),
    ("metadata.last_updated", check_last_updated),
    ("frog.status", check_frog_status),
]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Dashboard round-trip test (yaml→md sync verification)",
    )
    parser.add_argument("--yaml", default=str(DEFAULT_YAML), help="dashboard.yaml path")
    parser.add_argument("--md", default=str(DEFAULT_MD), help="dashboard.md path")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="(reserved) escalate warnings to failures",
    )
    args = parser.parse_args()

    yaml_path = Path(args.yaml)
    md_path = Path(args.md)

    if not yaml_path.exists():
        print(f"FAIL: yaml not found at {yaml_path}", file=sys.stderr)
        sys.exit(1)
    if not md_path.exists():
        print(f"FAIL: md not found at {md_path}", file=sys.stderr)
        sys.exit(1)

    with yaml_path.open("r", encoding="utf-8") as f:
        yaml_data = yaml.safe_load(f) or {}
    md_text = md_path.read_text(encoding="utf-8")

    failed = 0
    for _name, fn in CHECKS:
        if not fn(yaml_data, md_text):
            failed += 1

    total = len(CHECKS)
    if failed == 0:
        print(f"\n{total} checks: ALL PASS")
        sys.exit(0)
    print(f"\n{total} checks: {failed} FAIL", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
