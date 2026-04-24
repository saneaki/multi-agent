#!/usr/bin/env python3
"""
validate_karo_task.py — shogun_to_karo.yaml shift-left validator.

Usage:
  python3 scripts/validate_karo_task.py --cmd-id cmd_573
  python3 scripts/validate_karo_task.py --all
  python3 scripts/validate_karo_task.py --cmd-id cmd_573 --bypass "Phase 0 移行中で north_star 未整備"

Exit codes:
  0 = PASS (CRITICAL/HIGH 違反なし、または bypass 承認済み)
  2 = FAIL (CRITICAL/HIGH 違反あり、bypass なし)
  1 = script 内部エラー

Created: 2026-04-24 (cmd_573 Scope B / subtask_573b, ashigaru5)
Canonical rule source reference: memory/canonical_rule_sources.md §2
Related: config/schemas/shogun_to_karo_schema.yaml
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

# ---------- Paths ----------
REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "config" / "schemas" / "shogun_to_karo_schema.yaml"
TARGET_PATH = REPO_ROOT / "queue" / "shogun_to_karo.yaml"
BYPASS_LOG_PATH = REPO_ROOT / "config" / "bypass_log.yaml"
JST_NOW = REPO_ROOT / "scripts" / "jst_now.sh"


# ---------- Result containers ----------
@dataclass
class Violation:
    cmd_id: str
    field_name: str
    severity: str
    reason: str

    def line(self) -> str:
        return f"  [{self.severity:<5}] {self.field_name:<22} — {self.reason}"


@dataclass
class CmdResult:
    cmd_id: str
    violations: list[Violation] = field(default_factory=list)

    @property
    def worst_severity(self) -> str:
        order = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}
        if not self.violations:
            return "PASS"
        return max(self.violations, key=lambda v: order.get(v.severity, 0)).severity

    @property
    def blocks(self) -> bool:
        return any(v.severity in ("CRITICAL", "HIGH") for v in self.violations)


# ---------- Loaders ----------
def load_schema() -> dict[str, Any]:
    if not SCHEMA_PATH.exists():
        print(f"ERROR: schema not found: {SCHEMA_PATH}", file=sys.stderr)
        sys.exit(1)
    with SCHEMA_PATH.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


ENTRY_ANCHOR_RE = re.compile(r"^- id: (cmd_\d+)\s*$", re.MULTILINE)


def load_entries() -> list[dict[str, Any] | dict[str, str]]:
    """
    Load entries from shogun_to_karo.yaml.

    The file is ~1.7MB with 374 entries and occasionally contains pre-existing
    malformed YAML (e.g. cmd_359 has an unterminated single-quoted string).
    A single yaml.safe_load on the whole file aborts on the first bad entry,
    so we split on the `^- id: cmd_N` anchor and parse each chunk independently.
    Parse failures become a synthetic entry with key '__parse_error__' so the
    caller can surface them as CRITICAL violations instead of aborting the run.
    """
    if not TARGET_PATH.exists():
        print(f"ERROR: target not found: {TARGET_PATH}", file=sys.stderr)
        sys.exit(1)

    text = TARGET_PATH.read_text(encoding="utf-8")
    anchors = list(ENTRY_ANCHOR_RE.finditer(text))
    if not anchors:
        print("ERROR: no cmd entries found (anchor '- id: cmd_N' missing).", file=sys.stderr)
        sys.exit(1)

    entries: list[dict[str, Any]] = []
    for i, m in enumerate(anchors):
        start = m.start()
        end = anchors[i + 1].start() if i + 1 < len(anchors) else len(text)
        chunk = text[start:end]
        cmd_id = m.group(1)
        try:
            parsed = yaml.safe_load(chunk)
            if isinstance(parsed, list) and parsed and isinstance(parsed[0], dict):
                entries.append(parsed[0])
            else:
                entries.append(
                    {"id": cmd_id, "__parse_error__": "chunk did not parse to dict"}
                )
        except yaml.YAMLError as e:
            entries.append({"id": cmd_id, "__parse_error__": str(e).splitlines()[0]})
    return entries


# ---------- Field validators ----------
def _cmd_number(cmd_id: str) -> int | None:
    m = re.match(r"^cmd_(\d+)$", cmd_id or "")
    return int(m.group(1)) if m else None


def _type_matches(value: Any, expected: str) -> bool:
    if expected == "string":
        return isinstance(value, str)
    if expected == "list":
        return isinstance(value, list)
    if expected == "dict":
        return isinstance(value, dict)
    if expected == "enum":
        return isinstance(value, str)
    return True


def _validate_single_field(
    entry: dict[str, Any],
    spec: dict[str, Any],
    severity_missing: str,
    severity_invalid: str,
) -> list[Violation]:
    cmd_id = entry.get("id", "<unknown>")
    name = spec["name"]
    viols: list[Violation] = []

    if name not in entry or entry[name] in (None, ""):
        viols.append(
            Violation(cmd_id, name, severity_missing, f"field '{name}' missing or empty")
        )
        return viols

    value = entry[name]
    expected_type = spec.get("type", "string")

    if not _type_matches(value, expected_type):
        viols.append(
            Violation(
                cmd_id,
                name,
                severity_invalid,
                f"expected {expected_type}, got {type(value).__name__}",
            )
        )
        return viols

    if expected_type == "string":
        min_len = spec.get("min_length")
        if min_len is not None and len(value) < min_len:
            viols.append(
                Violation(
                    cmd_id,
                    name,
                    severity_invalid,
                    f"string length {len(value)} < min_length {min_len}",
                )
            )
        pattern = spec.get("pattern")
        if pattern and not re.match(pattern, value):
            viols.append(
                Violation(
                    cmd_id,
                    name,
                    severity_invalid,
                    f"value '{value[:40]}' does not match pattern '{pattern}'",
                )
            )

    if expected_type == "list":
        min_items = spec.get("min_items")
        if min_items is not None and len(value) < min_items:
            viols.append(
                Violation(
                    cmd_id,
                    name,
                    severity_invalid,
                    f"list length {len(value)} < min_items {min_items}",
                )
            )

    if expected_type == "enum":
        allowed = spec.get("allowed", [])
        if value not in allowed:
            viols.append(
                Violation(
                    cmd_id,
                    name,
                    severity_invalid,
                    f"value '{value}' not in allowed {allowed}",
                )
            )

    return viols


# ---------- Core validation ----------
def validate_entry(entry: dict[str, Any], schema: dict[str, Any]) -> CmdResult:
    cmd_id = entry.get("id", "<unknown>")
    result = CmdResult(cmd_id=cmd_id)

    if "__parse_error__" in entry:
        result.violations.append(
            Violation(
                cmd_id,
                "(parse)",
                "CRITICAL",
                f"YAML parse error: {entry['__parse_error__']}",
            )
        )
        return result

    for spec in schema.get("required_fields", []):
        result.violations.extend(
            _validate_single_field(
                entry, spec, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    cmd_num = _cmd_number(cmd_id)
    for spec in schema.get("recommended_fields", []):
        applies_from_raw = spec.get("applies_from")
        if applies_from_raw and cmd_num is not None:
            applies_from_num = _cmd_number(applies_from_raw) or 0
            if cmd_num < applies_from_num:
                continue
        result.violations.extend(
            _validate_single_field(
                entry, spec, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    for spec in schema.get("conditional_fields", []):
        when = spec.get("required_when", {})
        trigger_field = when.get("field")
        trigger_val = when.get("equals")
        if trigger_field and entry.get(trigger_field) == trigger_val:
            result.violations.extend(
                _validate_single_field(
                    entry, spec, spec["severity_missing"], spec["severity_invalid"]
                )
            )

    for spec in schema.get("optional_fields", []):
        if spec["name"] not in entry:
            continue
        result.violations.extend(
            _validate_single_field(
                entry, spec, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    return result


# ---------- Output helpers ----------
def _jst_now() -> str:
    try:
        out = subprocess.run(
            ["bash", str(JST_NOW), "--yaml"], capture_output=True, text=True, check=True
        )
        return out.stdout.strip()
    except Exception:
        from datetime import datetime, timezone, timedelta

        jst = timezone(timedelta(hours=9))
        return datetime.now(tz=jst).strftime("%Y-%m-%dT%H:%M:%S+09:00")


def format_result(result: CmdResult, tier_def: dict[str, Any]) -> str:
    status = "PASS" if not result.violations else ("FAIL" if result.blocks else "WARN")
    head = f"[{status}] {result.cmd_id}  worst={result.worst_severity}"
    if not result.violations:
        return head
    lines = [head]
    for v in result.violations:
        lines.append(v.line())
    return "\n".join(lines)


def record_bypass(
    cmd_id: str,
    reason: str,
    violations: list[Violation],
    user: str,
) -> None:
    BYPASS_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

    entry = {
        "timestamp": _jst_now(),
        "cmd_id": cmd_id,
        "bypassed_by": user,
        "reason": reason,
        "original_severity": (
            max(violations, key=lambda v: {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}.get(v.severity, 0)).severity
            if violations
            else "PASS"
        ),
        "violations": [
            {"field": v.field_name, "severity": v.severity, "reason": v.reason}
            for v in violations
        ],
    }

    existing: list[dict[str, Any]] = []
    if BYPASS_LOG_PATH.exists():
        with BYPASS_LOG_PATH.open("r", encoding="utf-8") as f:
            loaded = yaml.safe_load(f)
            if isinstance(loaded, list):
                existing = loaded
    existing.append(entry)

    with BYPASS_LOG_PATH.open("w", encoding="utf-8") as f:
        yaml.safe_dump(
            existing,
            f,
            allow_unicode=True,
            sort_keys=False,
            default_flow_style=False,
        )


# ---------- CLI ----------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="shogun_to_karo.yaml shift-left validator (cmd_573 Scope B)"
    )
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--cmd-id", help="validate a single cmd entry (e.g. cmd_573)")
    g.add_argument("--all", action="store_true", help="validate every entry")
    parser.add_argument(
        "--bypass",
        metavar="REASON",
        help="bypass CRITICAL/HIGH blocks with audited reason (>=10 chars)",
    )
    parser.add_argument(
        "--user",
        default=os.environ.get("USER", "unknown"),
        help="bypass attribution (default: $USER)",
    )
    parser.add_argument(
        "--quiet", action="store_true", help="suppress PASS output in --all mode"
    )
    args = parser.parse_args()

    schema = load_schema()
    tier_def = schema.get("severity_tier_behavior", {})
    entries = load_entries()

    if args.cmd_id:
        matches = [e for e in entries if e.get("id") == args.cmd_id]
        if not matches:
            print(f"ERROR: cmd_id not found: {args.cmd_id}", file=sys.stderr)
            return 1
        targets = matches
    else:
        targets = entries

    results = [validate_entry(e, schema) for e in targets]

    bypass_requested = bool(args.bypass)
    if bypass_requested:
        bypass_cfg = schema.get("bypass_policy", {})
        min_len = bypass_cfg.get("min_reason_length", 10)
        if len(args.bypass) < min_len:
            print(
                f"ERROR: --bypass reason must be >= {min_len} chars (got {len(args.bypass)}).",
                file=sys.stderr,
            )
            return 1

    blocking = [r for r in results if r.blocks]

    for r in results:
        if args.quiet and not r.violations:
            continue
        print(format_result(r, tier_def))

    if bypass_requested and blocking:
        for r in blocking:
            record_bypass(r.cmd_id, args.bypass, r.violations, args.user)
        print(
            f"\n[BYPASS] {len(blocking)} entr{'y' if len(blocking)==1 else 'ies'} "
            f"audited to {BYPASS_LOG_PATH.relative_to(REPO_ROOT)} (reason='{args.bypass}')"
        )
        return 0

    if blocking:
        print(
            f"\n[RESULT] FAIL — {len(blocking)} blocking entries (CRITICAL/HIGH). "
            f"Re-run with --bypass \"reason\" if intentional.",
            file=sys.stderr,
        )
        return 2

    warn = [r for r in results if r.violations and not r.blocks]
    if warn:
        print(f"\n[RESULT] PASS with {len(warn)} warning entries (MEDIUM/LOW).")
    else:
        print(f"\n[RESULT] PASS — {len(results)} entr{'y' if len(results)==1 else 'ies'} clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
