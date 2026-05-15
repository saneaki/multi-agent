#!/usr/bin/env python3
"""
daily_digest.py — cmd_716 Phase E: daily 8:00 JST 行動中 digest builder + sender

Phase E goal (E-2/E-3):
  - Build a daily digest that summarises in_progress cmds, separate from alerts.
  - Even with 0 in_progress items, generate "行動中 0件 | 滞留なし | 詳細 dashboard 参照".
  - Sender liveness is recorded in queue/alert_state.yaml under digest_liveness.

Format (E-3):
  "行動中 N 件 (cmd_xxx, cmd_yyy) | 最古滞留 N 日 | 詳細 dashboard 参照"
  When N == 0: "行動中 0件 | 滞留なし | 詳細 dashboard 参照"

CLI:
  python3 scripts/lib/daily_digest.py            # build + send (best-effort)
  python3 scripts/lib/daily_digest.py --dry-run  # build only, print body
  python3 scripts/lib/daily_digest.py --body-only # echo body to stdout
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

JST = timezone(timedelta(hours=9))
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent

_ALERT_STATE_REL = "queue/alert_state.yaml"
_DASHBOARD_REL = "dashboard.yaml"
_DIGEST_TITLE = "🌅 朝の行動中 digest (8:00 JST)"
_DIGEST_TYPE = "daily_digest"
_LIVENESS_GRACE_HOURS = 26  # expect digest every 24h; allow 2h grace before declaring sender down


@dataclass(frozen=True)
class DigestPayload:
    count: int
    cmd_ids: tuple
    oldest_stall_days: int
    body: str


def _iso_jst_now() -> str:
    return datetime.now(JST).isoformat(timespec="seconds")


def _parse_iso(value) -> "datetime | None":
    if not value:
        return None
    s = str(value).strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        t = datetime.fromisoformat(s)
        if t.tzinfo is None:
            t = t.replace(tzinfo=JST)
        return t
    except (ValueError, TypeError):
        return None


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


def _normalize_in_progress(dash: dict) -> list:
    items = dash.get("in_progress") or []
    if not isinstance(items, list):
        return []
    cleaned: list = []
    for item in items:
        if not isinstance(item, dict):
            continue
        cleaned.append(item)
    return cleaned


def _extract_cmd_id(item: dict) -> str:
    """Best-effort cmd_id extraction from an in_progress entry."""
    cmd = str(item.get("cmd") or "").strip()
    if cmd:
        return cmd
    content = str(item.get("content") or "")
    import re
    m = re.search(r"\bcmd_\w+", content)
    if m:
        return m.group(0)
    return ""


def _stall_age_days(item: dict, now: datetime) -> int:
    """Return age in whole days for an in_progress item; 0 when unknown."""
    candidates = (
        item.get("promoted_at"),
        item.get("started_at"),
        item.get("created_at"),
        item.get("dispatched_at"),
    )
    for raw in candidates:
        t = _parse_iso(raw)
        if t is None:
            continue
        delta = now - t.astimezone(JST)
        return max(0, int(delta.total_seconds() // 86400))
    return 0


def build_digest(root: str) -> DigestPayload:
    """Build a digest payload from dashboard.yaml in_progress entries.

    Always succeeds: zero-item state produces a "行動中 0件" body.
    """
    dash = _load_dashboard(root)
    items = _normalize_in_progress(dash)
    now = datetime.now(JST)

    cmd_ids: list = []
    seen_cmds: set = set()
    oldest = 0
    for item in items:
        cid = _extract_cmd_id(item)
        if cid and cid not in seen_cmds:
            seen_cmds.add(cid)
            cmd_ids.append(cid)
        age = _stall_age_days(item, now)
        if age > oldest:
            oldest = age

    count = len(items)
    body = _format_body(count, cmd_ids, oldest)
    return DigestPayload(
        count=count,
        cmd_ids=tuple(cmd_ids),
        oldest_stall_days=oldest,
        body=body,
    )


def _format_body(count: int, cmd_ids: list, oldest_stall_days: int) -> str:
    if count == 0:
        return "行動中 0件 | 滞留なし | 詳細 dashboard 参照"
    ids_part = ", ".join(cmd_ids) if cmd_ids else "(cmd id 不明)"
    return (
        f"行動中 {count} 件 ({ids_part}) | "
        f"最古滞留 {oldest_stall_days} 日 | 詳細 dashboard 参照"
    )


# ────────────────────────────────────────────────────────────
# Sender liveness (E-4)
# ────────────────────────────────────────────────────────────


def _alert_state_path(root: str) -> str:
    return os.path.join(root, _ALERT_STATE_REL)


def _load_alert_state(root: str) -> dict:
    path = _alert_state_path(root)
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
    except (yaml.YAMLError, OSError):
        return {}
    return data if isinstance(data, dict) else {}


def _save_alert_state(root: str, data: dict) -> bool:
    import tempfile
    path = _alert_state_path(root)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fd, tmp = tempfile.mkstemp(
            prefix=".alert_state.", suffix=".yaml.tmp",
            dir=os.path.dirname(path),
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


def record_digest_attempt(root: str, success: bool) -> bool:
    """Record an attempt timestamp in alert_state.yaml.digest_liveness.

    Successful sends update last_success_at + last_attempt_at.
    Failures only update last_attempt_at and increment consecutive_failures.
    Returns True on persistence success.
    """
    state = _load_alert_state(root)
    now_iso = _iso_jst_now()
    liveness = state.get("digest_liveness")
    if not isinstance(liveness, dict):
        liveness = {}
    liveness["last_attempt_at"] = now_iso
    if success:
        liveness["last_success_at"] = now_iso
        liveness["consecutive_failures"] = 0
    else:
        liveness["consecutive_failures"] = int(liveness.get("consecutive_failures") or 0) + 1
    state["digest_liveness"] = liveness
    # Preserve required top-level keys
    if not isinstance(state.get("gates"), dict):
        state["gates"] = state.get("gates") or {}
    if not isinstance(state.get("notifications"), dict):
        state["notifications"] = state.get("notifications") or {}
    if not isinstance(state.get("dashboard_events"), list):
        state["dashboard_events"] = state.get("dashboard_events") or []
    return _save_alert_state(root, state)


def get_digest_liveness(root: str) -> dict:
    """Return digest_liveness dict (may be empty)."""
    state = _load_alert_state(root)
    liveness = state.get("digest_liveness")
    if not isinstance(liveness, dict):
        return {}
    return liveness


def check_digest_liveness(root: str, grace_hours: float = _LIVENESS_GRACE_HOURS) -> dict:
    """Return {is_down: bool, hours_since_last: float, last_success_at: str|None,
    consecutive_failures: int}.

    is_down=True when no successful send has been recorded yet, or the
    most recent success is older than grace_hours.
    """
    liveness = get_digest_liveness(root)
    last_success = _parse_iso(liveness.get("last_success_at") or "")
    consecutive_failures = int(liveness.get("consecutive_failures") or 0)

    if last_success is None:
        return {
            "is_down": True,
            "hours_since_last": float("inf"),
            "last_success_at": None,
            "consecutive_failures": consecutive_failures,
        }
    delta = datetime.now(JST) - last_success.astimezone(JST)
    hours = delta.total_seconds() / 3600.0
    return {
        "is_down": hours > grace_hours,
        "hours_since_last": hours,
        "last_success_at": last_success.isoformat(timespec="seconds"),
        "consecutive_failures": consecutive_failures,
    }


def is_digest_sender_down_alert(alert_key: str) -> bool:
    """Return True when alert_key represents the digest-sender-down alert
    (system_failure category — NEVER suppress)."""
    return str(alert_key).startswith("P_DIGEST_SENDER_DOWN")


# ────────────────────────────────────────────────────────────
# Sender (best-effort wrapper around scripts/discord_notify.py)
# ────────────────────────────────────────────────────────────


def _discord_notify_path(root: str) -> str:
    return os.path.join(root, "scripts", "discord_notify.py")


def send_digest(
    root: str,
    payload: "DigestPayload | None" = None,
    *,
    dry_run: bool = False,
    notify_runner=None,
) -> bool:
    """Send the digest via discord_notify.py and record liveness.

    notify_runner is an injectable callable(body, title, type) -> bool used
    in tests; the default uses subprocess.run().
    """
    if payload is None:
        payload = build_digest(root)

    if dry_run:
        # Don't touch liveness in dry-run mode
        return True

    def _default_runner(body: str, title: str, msg_type: str) -> bool:
        cmd = [
            "python3",
            _discord_notify_path(root),
            "--body", body,
            "--title", title,
            "--type", msg_type,
        ]
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=30, check=False,
            )
        except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
            return False
        return result.returncode == 0

    runner = notify_runner or _default_runner
    success = bool(runner(payload.body, _DIGEST_TITLE, _DIGEST_TYPE))
    record_digest_attempt(root, success=success)
    return success


# ────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", default=str(PROJECT_DIR),
        help="project root (default: %(default)s)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="build digest and print to stdout without sending",
    )
    parser.add_argument(
        "--body-only", action="store_true",
        help="print only the digest body (no title/diagnostics)",
    )
    args = parser.parse_args(argv)

    payload = build_digest(args.root)

    if args.body_only:
        print(payload.body)
        return 0

    if args.dry_run:
        print(f"[daily_digest] DRY-RUN — count={payload.count} oldest_stall_days={payload.oldest_stall_days}")
        print(f"[daily_digest] cmd_ids={list(payload.cmd_ids)}")
        print("--- body ---")
        print(payload.body)
        return 0

    ok = send_digest(args.root, payload, dry_run=False)
    if not ok:
        print(
            f"[daily_digest] WARN: send failed; liveness updated. body={payload.body!r}",
            file=sys.stderr,
        )
        return 1
    print(f"[daily_digest] sent: {payload.body}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
