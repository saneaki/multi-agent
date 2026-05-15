#!/usr/bin/env python3
"""
shogun_to_karo_parser.py — cmd_716 Phase E (E-1): gate auto-register parser

Scans queue/shogun_to_karo.yaml for cmd entries that declare or imply
judgement gates, and produces candidate gate definitions suitable for
populating dashboard.yaml.gate_registry.

Initial manual confirm boundary (E-1):
  - This parser writes candidates with state="candidate". Promotion to
    action_required (the channel that pings the Lord) is left to a
    separate manual / karo step.
  - --dry-run mode prints candidates without touching files.

Gate sources detected:
  1. Explicit `gates:` field on a cmd entry (preferred) — list of
     {tag, title, detail, severity?, expected_action?} dicts.
  2. Implicit keyword match in `north_star` / `purpose` / `command`
     — looks for phrases indicating lord manual verification.

CLI:
  python3 scripts/shogun_to_karo_parser.py --dry-run
  python3 scripts/shogun_to_karo_parser.py --cmd cmd_716
  python3 scripts/shogun_to_karo_parser.py --apply   # write to gate_registry
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

JST = timezone(timedelta(hours=9))
PROJECT_DIR = Path(__file__).resolve().parent.parent

_SHOGUN_TO_KARO_REL = "queue/shogun_to_karo.yaml"
_DASHBOARD_REL = "dashboard.yaml"

# Implicit gate keywords — phrases that strongly imply the Lord must
# perform a manual verification step.
_IMPLICIT_GATE_PATTERNS = [
    (re.compile(r"manual[\s_-]?verify"), "manual_verify"),
    (re.compile(r"manual[\s_-]?confirm"), "manual_confirm"),
    (re.compile(r"殿\s*(承認|判断|確認)"), "殿_approval"),
    (re.compile(r"deploy\s+(実機|to\s+production)"), "deploy_manual"),
    (re.compile(r"lord[_\s-]?decision"), "lord_decision"),
    (re.compile(r"殿の(手動|実機)"), "殿_manual"),
]


def _iso_jst_now() -> str:
    return datetime.now(JST).isoformat(timespec="seconds")


# ────────────────────────────────────────────────────────────
# cmd block parsing
# ────────────────────────────────────────────────────────────


def parse_cmd_blocks(content: str) -> list:
    """Split queue/shogun_to_karo.yaml content into per-cmd YAML chunks.

    Returns a list of dicts (parsed individually) — robust to mid-file
    parse errors (a single broken cmd does not blank the whole file).
    """
    parts = re.split(r"^(?=- id: cmd_)", content, flags=re.MULTILINE)
    parsed: list = []
    for part in parts:
        if not part.strip():
            continue
        try:
            loaded = yaml.safe_load(part)
        except yaml.YAMLError:
            continue
        if isinstance(loaded, list) and loaded and isinstance(loaded[0], dict):
            parsed.append(loaded[0])
        elif isinstance(loaded, dict):
            parsed.append(loaded)
    return parsed


def load_cmd_blocks(root: str) -> list:
    """Load and parse all cmd blocks from queue/shogun_to_karo.yaml."""
    path = os.path.join(root, _SHOGUN_TO_KARO_REL)
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except OSError:
        return []
    return parse_cmd_blocks(content)


# ────────────────────────────────────────────────────────────
# Gate extraction
# ────────────────────────────────────────────────────────────


def _normalize_explicit_gate(item, cmd_id: str, idx: int) -> "dict | None":
    if not isinstance(item, dict):
        return None
    tag = str(item.get("tag") or "").strip()
    title = str(item.get("title") or "").strip()
    detail = str(item.get("detail") or "").strip()
    if not tag:
        # Auto-generate a stable tag when missing
        slug = re.sub(r"\W+", "-", (title or "gate")).strip("-").lower()
        tag = f"[action-{idx + 1}] [{cmd_id}-{slug}]" if cmd_id else f"[action-{idx + 1}] [{slug}]"
    if not title:
        title = f"{cmd_id or 'cmd'} gate {idx + 1}"
    if not detail:
        detail = f"自動抽出された gate 候補 (source={cmd_id or 'unknown'})"
    severity = str(item.get("severity") or "HIGH").strip().upper()
    expected_action = str(item.get("expected_action") or "殿の手動確認・承認").strip()
    return {
        "tag": tag,
        "title": title,
        "detail": detail,
        "severity": severity,
        "expected_action": expected_action,
        "source": "explicit_gates_field",
    }


def _scan_implicit_keywords(text: str) -> list:
    """Return distinct keyword labels found in text."""
    labels: list = []
    seen: set = set()
    for pattern, label in _IMPLICIT_GATE_PATTERNS:
        if pattern.search(text or "") and label not in seen:
            seen.add(label)
            labels.append(label)
    return labels


def extract_gate_candidates(cmd: dict) -> list:
    """Return gate candidate dicts for a single cmd entry.

    Each candidate dict contains: tag, title, detail, severity,
    expected_action, source, source_cmd_id.
    """
    if not isinstance(cmd, dict):
        return []
    cmd_id = str(cmd.get("id") or "").strip()

    candidates: list = []

    # Source 1: explicit gates: field
    explicit = cmd.get("gates")
    if isinstance(explicit, list):
        for idx, item in enumerate(explicit):
            norm = _normalize_explicit_gate(item, cmd_id, idx)
            if norm:
                norm["source_cmd_id"] = cmd_id
                candidates.append(norm)

    if candidates:
        # When explicit gates exist, prefer them and skip implicit scan
        return candidates

    # Source 2: implicit keyword scan over north_star + purpose + command
    haystack_parts: list = []
    for key in ("north_star", "purpose", "command", "dispatch_note"):
        value = cmd.get(key)
        if isinstance(value, str):
            haystack_parts.append(value)
    haystack = "\n".join(haystack_parts)
    labels = _scan_implicit_keywords(haystack)
    if not labels:
        return []

    purpose = str(cmd.get("purpose") or "").strip()
    title_default = purpose.splitlines()[0] if purpose else f"{cmd_id} gate (auto)"
    for idx, label in enumerate(labels):
        slug = label.replace("_", "-").replace(" ", "-").lower()
        tag = f"[action-1] [{cmd_id}-{slug}]" if cmd_id else f"[action-1] [{slug}]"
        candidates.append({
            "tag": tag,
            "title": title_default[:80],
            "detail": (
                f"暗黙 gate keyword '{label}' を検知。"
                f"殿の手動確認・実機検証が必要と推定される (source_cmd={cmd_id})."
            ),
            "severity": "HIGH",
            "expected_action": "殿による実機/手動確認",
            "source": f"implicit_keyword:{label}",
            "source_cmd_id": cmd_id,
        })
    return candidates


def collect_gate_candidates(cmds: list, cmd_filter: "str | None" = None) -> list:
    """Walk a list of cmd dicts and return all candidates (filtered by cmd_id when set)."""
    all_candidates: list = []
    for cmd in cmds:
        if cmd_filter:
            cid = str(cmd.get("id") or "")
            if cid != cmd_filter:
                continue
        all_candidates.extend(extract_gate_candidates(cmd))
    return all_candidates


# ────────────────────────────────────────────────────────────
# Registry persistence (E-1 manual-confirm boundary)
# ────────────────────────────────────────────────────────────


def _load_dashboard(root: str) -> dict:
    path = os.path.join(root, _DASHBOARD_REL)
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except (yaml.YAMLError, OSError):
        return {}
    return data if isinstance(data, dict) else {}


def _save_dashboard(root: str, data: dict) -> bool:
    path = os.path.join(root, _DASHBOARD_REL)
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        fd, tmp = tempfile.mkstemp(
            prefix=".dashboard.", suffix=".yaml.tmp",
            dir=os.path.dirname(path) or ".",
        )
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False)
            os.replace(tmp, path)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
        return True
    except (OSError, yaml.YAMLError):
        return False


def _registry_has_gate(registry: list, candidate: dict) -> bool:
    """Idempotency: skip when a registry entry already references this tag/gate_id."""
    tag = candidate.get("tag")
    cmd_id = candidate.get("source_cmd_id")
    for existing in registry:
        if not isinstance(existing, dict):
            continue
        if existing.get("tag") == tag and tag:
            return True
        if existing.get("gate_id") == tag and tag:
            return True
        # Composite: same cmd + same source label
        if (cmd_id and existing.get("cmd_id") == cmd_id
                and existing.get("notes") == candidate.get("source")):
            return True
    return False


def apply_candidates_to_registry(root: str, candidates: list) -> list:
    """Append new candidates to dashboard.yaml.gate_registry with state="candidate".

    Returns the list of *newly written* entries (may be empty if all skipped
    as duplicates). state="candidate" preserves the manual-confirm boundary —
    promotion to action_required requires a separate step.
    """
    data = _load_dashboard(root)
    registry = data.get("gate_registry")
    if not isinstance(registry, list):
        registry = []
    now_iso = _iso_jst_now()
    written: list = []
    for cand in candidates:
        if _registry_has_gate(registry, cand):
            continue
        # action_required-shaped entry (uses tag+title+detail+severity+
        # parent_cmd) so it co-exists with legacy issue items.
        entry = {
            "tag": cand.get("tag", ""),
            "title": cand.get("title", ""),
            "detail": cand.get("detail", ""),
            "severity": cand.get("severity", "HIGH"),
            "parent_cmd": cand.get("source_cmd_id", "") or "unknown",
            "gate_id": cand.get("tag", ""),
            "state": "candidate",  # Manual confirm boundary — not yet active
            "expected_action": cand.get("expected_action", "殿の手動確認"),
            "registered_at": now_iso,
            "registered_by": "shogun_to_karo_parser.py",
            "notified_at": None,
            "resolved_at": None,
            "notes": cand.get("source", ""),
            "issue_id": cand.get("tag", ""),
        }
        registry.append(entry)
        written.append(entry)
    if not written:
        return []
    data["gate_registry"] = registry
    if not _save_dashboard(root, data):
        return []
    return written


# ────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────


def _format_candidate_summary(c: dict) -> str:
    return (
        f"  - tag={c.get('tag','?')}\n"
        f"    title={c.get('title','?')}\n"
        f"    severity={c.get('severity','?')}\n"
        f"    source={c.get('source','?')} (cmd={c.get('source_cmd_id','?')})"
    )


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", default=str(PROJECT_DIR),
        help="project root (default: %(default)s)",
    )
    parser.add_argument(
        "--cmd", default=None,
        help="restrict to a single cmd id (e.g. cmd_716)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="print candidates without writing to gate_registry",
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="write candidates to dashboard.yaml.gate_registry (state=candidate)",
    )
    args = parser.parse_args(argv)

    if args.dry_run and args.apply:
        print("ERROR: --dry-run and --apply are mutually exclusive", file=sys.stderr)
        return 2

    cmds = load_cmd_blocks(args.root)
    candidates = collect_gate_candidates(cmds, cmd_filter=args.cmd)

    print(
        f"[shogun_to_karo_parser] scanned {len(cmds)} cmds; "
        f"found {len(candidates)} gate candidate(s)"
    )
    for cand in candidates:
        print(_format_candidate_summary(cand))

    if args.apply:
        written = apply_candidates_to_registry(args.root, candidates)
        print(f"[shogun_to_karo_parser] wrote {len(written)} new registry entry(ies)")
        for w in written:
            print(f"  + {w['tag']} (state=candidate)")
    elif not args.dry_run:
        # Default = dry-run-like behaviour to honour manual-confirm boundary
        print("[shogun_to_karo_parser] manual-confirm boundary: pass --apply to persist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
