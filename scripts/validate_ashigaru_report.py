#!/usr/bin/env python3
"""
validate_ashigaru_report.py — ashigaru report YAML shift-left validator (P1.3).

cmd_573 Scope C / subtask_573c.
V005 (SO-01 report schema) / V006 (SO-03 timestamp) / V008 (YAML strictness) を予防する。

Usage:
  python3 scripts/validate_ashigaru_report.py --report-file queue/reports/ashigaru5_report.yaml
  python3 scripts/validate_ashigaru_report.py --worker 5
  python3 scripts/validate_ashigaru_report.py --all
  python3 scripts/validate_ashigaru_report.py --report-file <path> --bypass "reason text >= 10 chars"

Exit codes:
  0 = PASS / WARN only / bypass 承認 / warn_only_phase 有効時の downgrade
  2 = FAIL (CRITICAL/HIGH 違反あり、bypass なし、warn_only 無効時)
  1 = script 内部エラー (schema 未発見、file 未発見、未知 CLI 引数 等)

Canonical rule source reference: memory/canonical_rule_sources.md §2
Related:
  - config/schemas/ashigaru_report_schema.yaml (schema 本体)
  - scripts/validate_karo_task.py             (P1.2 姉妹実装)
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

import yaml

# ---------- Paths ----------
REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "config" / "schemas" / "ashigaru_report_schema.yaml"
REPORTS_DIR = REPO_ROOT / "queue" / "reports"
BYPASS_LOG_PATH = REPO_ROOT / "config" / "bypass_log.yaml"
JST_NOW = REPO_ROOT / "scripts" / "jst_now.sh"

REPORT_FILE_RE = re.compile(r"^ashigaru([1-8])_report\.yaml$")


# ---------- Result containers ----------
@dataclass
class Violation:
    report_file: str
    field_name: str
    severity: str
    reason: str

    def line(self) -> str:
        return f"  [{self.severity:<5}] {self.field_name:<28} — {self.reason}"


@dataclass
class ReportResult:
    report_file: str
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


def load_report(path: Path) -> dict[str, Any]:
    """
    Load a single report YAML. On YAML parse error surface it as a synthetic
    entry with '__parse_error__' so the caller can render it as CRITICAL
    instead of aborting the run (V008 対策)。
    """
    if not path.exists():
        return {"__parse_error__": f"file not found: {path}"}
    try:
        with path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not isinstance(data, dict):
            return {"__parse_error__": "top-level YAML is not a mapping"}
        return data
    except yaml.YAMLError as e:
        first_line = str(e).splitlines()[0] if str(e) else "yaml error"
        return {"__parse_error__": first_line}


def discover_reports() -> list[Path]:
    if not REPORTS_DIR.exists():
        print(f"ERROR: reports dir not found: {REPORTS_DIR}", file=sys.stderr)
        sys.exit(1)
    found = sorted(
        p for p in REPORTS_DIR.iterdir() if p.is_file() and REPORT_FILE_RE.match(p.name)
    )
    return found


def resolve_worker_path(worker: int) -> Path:
    return REPORTS_DIR / f"ashigaru{worker}_report.yaml"


# ---------- Field validator ----------
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
    report_file: str,
    severity_missing: str,
    severity_invalid: str,
) -> list[Violation]:
    name = spec["name"]
    viols: list[Violation] = []

    if name not in entry or entry[name] in (None, ""):
        viols.append(
            Violation(report_file, name, severity_missing, f"field '{name}' missing or empty")
        )
        return viols

    value = entry[name]
    expected_type = spec.get("type", "string")

    if not _type_matches(value, expected_type):
        viols.append(
            Violation(
                report_file,
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
                    report_file,
                    name,
                    severity_invalid,
                    f"string length {len(value)} < min_length {min_len}",
                )
            )
        pattern = spec.get("pattern")
        if pattern and not re.match(pattern, value):
            viols.append(
                Violation(
                    report_file,
                    name,
                    severity_invalid,
                    f"value '{value[:60]}' does not match pattern '{pattern}'",
                )
            )

    if expected_type == "list":
        min_items = spec.get("min_items")
        if min_items is not None and len(value) < min_items:
            viols.append(
                Violation(
                    report_file,
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
                    report_file,
                    name,
                    severity_invalid,
                    f"value '{value}' not in allowed {allowed}",
                )
            )

    return viols


# ---------- SKIP detection (CLAUDE.md Test Rules #1) ----------
def _iter_skip_candidates(node: Any) -> Iterable[tuple[str, Any]]:
    """
    Walk a dict/list recursively and yield (path, value) for every string
    value whose key is 'status' or 'result' (heuristic — matches the shapes
    observed in existing ashigaru reports).
    """
    if isinstance(node, dict):
        for k, v in node.items():
            if isinstance(v, str) and k in ("status", "result", "met"):
                yield (str(k), v)
            yield from _iter_skip_candidates(v)
    elif isinstance(node, list):
        for item in node:
            yield from _iter_skip_candidates(item)


def detect_skip_fail(entry: dict[str, Any], schema: dict[str, Any]) -> list[Violation]:
    cfg = schema.get("skip_detection", {})
    if not cfg.get("enabled", False):
        return []
    severity = cfg.get("severity", "HIGH")
    forbidden_ci = {str(v).lower() for v in cfg.get("forbidden_values_ci", [])}
    report_file = entry.get("__source_file__", "<unknown>")

    viols: list[Violation] = []
    # Focus on acceptance_criteria (top-level and inside result.*) plus
    # result.verification. These are the observed homes for AC status values.
    targets: list[Any] = []
    for key in ("acceptance_criteria", "verification"):
        if key in entry:
            targets.append(entry[key])
    if isinstance(entry.get("result"), dict):
        for key in ("acceptance_criteria", "verification"):
            if key in entry["result"]:
                targets.append(entry["result"][key])

    seen_positions: set[str] = set()
    for t in targets:
        for path, val in _iter_skip_candidates(t):
            lowered = val.strip().lower()
            if lowered in forbidden_ci:
                key = f"{path}={lowered}"
                if key in seen_positions:
                    continue
                seen_positions.add(key)
                viols.append(
                    Violation(
                        report_file,
                        "skip_detection",
                        severity,
                        f"SKIP 値検出 ({path}='{val}') — CLAUDE.md Test Rules #1 違反 (SKIP=FAIL)",
                    )
                )
    return viols


# ---------- Core validation ----------
def validate_entry(entry: dict[str, Any], schema: dict[str, Any], report_file: str) -> ReportResult:
    result = ReportResult(report_file=report_file)

    if "__parse_error__" in entry:
        result.violations.append(
            Violation(
                report_file,
                "(parse)",
                "CRITICAL",
                f"YAML parse error: {entry['__parse_error__']}",
            )
        )
        return result

    entry = {**entry, "__source_file__": report_file}

    for spec in schema.get("required_fields", []):
        result.violations.extend(
            _validate_single_field(
                entry, spec, report_file, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    for spec in schema.get("recommended_fields", []):
        result.violations.extend(
            _validate_single_field(
                entry, spec, report_file, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    for spec in schema.get("conditional_fields", []):
        when = spec.get("required_when", {})
        trigger_field = when.get("field")
        trigger_val = when.get("equals")
        if trigger_field and entry.get(trigger_field) == trigger_val:
            result.violations.extend(
                _validate_single_field(
                    entry, spec, report_file, spec["severity_missing"], spec["severity_invalid"]
                )
            )

    for spec in schema.get("optional_fields", []):
        if spec["name"] not in entry:
            continue
        result.violations.extend(
            _validate_single_field(
                entry, spec, report_file, spec["severity_missing"], spec["severity_invalid"]
            )
        )

    result.violations.extend(detect_skip_fail(entry, schema))

    return result


# ---------- Output helpers ----------
def _jst_now() -> str:
    try:
        out = subprocess.run(
            ["bash", str(JST_NOW), "--yaml"], capture_output=True, text=True, check=True
        )
        return out.stdout.strip()
    except Exception:
        from datetime import datetime, timedelta, timezone

        jst = timezone(timedelta(hours=9))
        return datetime.now(tz=jst).strftime("%Y-%m-%dT%H:%M:%S+09:00")


def format_result(result: ReportResult) -> str:
    if not result.violations:
        status = "PASS"
    elif result.blocks:
        status = "FAIL"
    else:
        status = "WARN"
    head = f"[{status}] {result.report_file}  worst={result.worst_severity}"
    if not result.violations:
        return head
    lines = [head]
    for v in result.violations:
        lines.append(v.line())
    return "\n".join(lines)


def record_bypass(
    report_file: str,
    reason: str,
    violations: list[Violation],
    user: str,
) -> None:
    BYPASS_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

    entry = {
        "timestamp": _jst_now(),
        "report_file": report_file,
        "bypassed_by": user,
        "reason": reason,
        "original_severity": (
            max(
                violations,
                key=lambda v: {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1}.get(v.severity, 0),
            ).severity
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
def _collect_targets(args: argparse.Namespace) -> list[Path]:
    if args.report_file:
        return [Path(args.report_file).resolve()]
    if args.worker:
        return [resolve_worker_path(args.worker)]
    return discover_reports()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="ashigaru report YAML validator (cmd_573 Scope C / P1.3)"
    )
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--report-file", help="validate a single report YAML by path")
    g.add_argument("--worker", type=int, choices=range(1, 9), help="worker number 1..8")
    g.add_argument("--all", action="store_true", help="validate every ashigaru{N}_report.yaml")
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
    parser.add_argument(
        "--no-warn-only",
        action="store_true",
        help="force hard-block regardless of schema.warn_only_phase (promotion drill)",
    )
    args = parser.parse_args()

    schema = load_schema()
    targets = _collect_targets(args)

    if not targets:
        print("ERROR: no targets resolved.", file=sys.stderr)
        return 1

    results: list[ReportResult] = []
    for path in targets:
        entry = load_report(path)
        rel = str(path.relative_to(REPO_ROOT)) if REPO_ROOT in path.parents else str(path)
        results.append(validate_entry(entry, schema, rel))

    bypass_requested = bool(args.bypass)
    if bypass_requested:
        min_len = schema.get("bypass_policy", {}).get("min_reason_length", 10)
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
        print(format_result(r))

    # Bypass takes priority over warn_only (explicit intent > soft phase).
    if bypass_requested and blocking:
        for r in blocking:
            record_bypass(r.report_file, args.bypass, r.violations, args.user)
        print(
            f"\n[BYPASS] {len(blocking)} report(s) audited to "
            f"{BYPASS_LOG_PATH.relative_to(REPO_ROOT)} (reason='{args.bypass}')"
        )
        return 0

    warn_only = schema.get("warn_only_phase", {}) or {}
    warn_only_active = bool(warn_only.get("enabled", False)) and not args.no_warn_only

    if blocking:
        if warn_only_active:
            print(
                f"\n[RESULT] WARN-ONLY — {len(blocking)} blocking report(s) observed. "
                f"warn_only_phase active until {warn_only.get('promotion_date', '?')} "
                f"(exit_override={warn_only.get('exit_override', 0)}).",
                file=sys.stderr,
            )
            return int(warn_only.get("exit_override", 0))
        print(
            f"\n[RESULT] FAIL — {len(blocking)} blocking report(s) (CRITICAL/HIGH). "
            f"Re-run with --bypass \"reason\" if intentional.",
            file=sys.stderr,
        )
        return 2

    warn = [r for r in results if r.violations and not r.blocks]
    if warn:
        print(f"\n[RESULT] PASS with {len(warn)} warning report(s) (MEDIUM/LOW).")
    else:
        suffix = "y" if len(results) == 1 else "ies"
        print(f"\n[RESULT] PASS — {len(results)} entr{suffix} clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
