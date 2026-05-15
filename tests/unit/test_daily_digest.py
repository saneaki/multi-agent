"""
Unit tests for cmd_716 Phase E:
  - scripts/lib/daily_digest.py (build_digest, send_digest, liveness)
  - scripts/shogun_to_karo_parser.py (gate auto-register, manual-confirm boundary)

AC mapping:
  E-1: TestGateAutoRegister (parser + dry-run + apply)
  E-2: TestBuildDigest (zero / N items, body always built)
  E-3: TestDigestFormat (format spec compliance)
  E-4: TestDigestLiveness (sender down detection, never-suppress prefix)
  E-5: this file (SKIP=0)
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml

# scripts/lib for daily_digest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../scripts/lib"))
# scripts/ for shogun_to_karo_parser
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../scripts"))

from daily_digest import (  # noqa: E402
    DigestPayload,
    build_digest,
    check_digest_liveness,
    get_digest_liveness,
    is_digest_sender_down_alert,
    record_digest_attempt,
    send_digest,
)
from shogun_to_karo_parser import (  # noqa: E402
    apply_candidates_to_registry,
    collect_gate_candidates,
    extract_gate_candidates,
    load_cmd_blocks,
    parse_cmd_blocks,
)

JST = timezone(timedelta(hours=9))


# ────────────────────────────────────────────────────────────
# Shared fixtures
# ────────────────────────────────────────────────────────────


@pytest.fixture()
def tmproot(tmp_path):
    (tmp_path / "queue").mkdir()
    (tmp_path / "queue" / "tasks").mkdir()
    (tmp_path / "queue" / "reports").mkdir()
    (tmp_path / "queue" / "inbox").mkdir()
    return tmp_path


def write_dashboard(root: Path, *, in_progress=None, gate_registry=None):
    data = {
        "in_progress": in_progress or [],
    }
    if gate_registry is not None:
        data["gate_registry"] = gate_registry
    with open(root / "dashboard.yaml", "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, allow_unicode=True)


def write_alert_state(root: Path, payload: dict):
    with open(root / "queue" / "alert_state.yaml", "w", encoding="utf-8") as f:
        yaml.safe_dump(payload, f, allow_unicode=True)


def _jst_iso(delta_hours: float = 0.0) -> str:
    return (
        datetime.now(JST) - timedelta(hours=delta_hours)
    ).isoformat(timespec="seconds")


# ────────────────────────────────────────────────────────────
# E-2: build_digest — zero and N items
# ────────────────────────────────────────────────────────────


class TestBuildDigest:
    def test_zero_items_yields_zero_body(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        payload = build_digest(str(tmproot))
        assert isinstance(payload, DigestPayload)
        assert payload.count == 0
        assert payload.cmd_ids == ()
        assert payload.oldest_stall_days == 0
        assert "行動中 0件" in payload.body
        assert "滞留なし" in payload.body
        assert "dashboard" in payload.body

    def test_missing_dashboard_still_builds_zero(self, tmproot):
        # dashboard.yaml absent — should not crash
        payload = build_digest(str(tmproot))
        assert payload.count == 0
        assert "行動中 0件" in payload.body

    def test_three_items_with_cmd_ids(self, tmproot):
        write_dashboard(tmproot, in_progress=[
            {"cmd": "cmd_716", "content": "Phase E", "assignee": "ashigaru5",
             "status": "🔄", "promoted_at": _jst_iso(48)},
            {"cmd": "cmd_728", "content": "Lord approval", "assignee": "ashigaru5",
             "status": "🔄", "promoted_at": _jst_iso(24)},
            {"cmd": "cmd_729", "content": "Gunshi append-only", "assignee": "gunshi",
             "status": "🔄", "promoted_at": _jst_iso(12)},
        ])
        payload = build_digest(str(tmproot))
        assert payload.count == 3
        assert "cmd_716" in payload.cmd_ids
        assert "cmd_728" in payload.cmd_ids
        assert "cmd_729" in payload.cmd_ids
        # 48h ~= 2 days
        assert payload.oldest_stall_days >= 2

    def test_in_progress_without_cmd_field_uses_content(self, tmproot):
        write_dashboard(tmproot, in_progress=[
            {"cmd": "", "content": "work on cmd_999 phase X",
             "assignee": "ashigaru1", "status": "🔄"},
        ])
        payload = build_digest(str(tmproot))
        assert payload.count == 1
        assert payload.cmd_ids == ("cmd_999",)


# ────────────────────────────────────────────────────────────
# E-3: format spec compliance
# ────────────────────────────────────────────────────────────


class TestDigestFormat:
    def test_zero_format_exact_match(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        payload = build_digest(str(tmproot))
        assert payload.body == "行動中 0件 | 滞留なし | 詳細 dashboard 参照"

    def test_n_format_includes_count_ids_oldest_stall(self, tmproot):
        write_dashboard(tmproot, in_progress=[
            {"cmd": "cmd_716", "content": "x", "assignee": "ashigaru5",
             "status": "🔄", "promoted_at": _jst_iso(72)},
        ])
        payload = build_digest(str(tmproot))
        assert "行動中 1 件" in payload.body
        assert "cmd_716" in payload.body
        assert "最古滞留" in payload.body
        assert "詳細 dashboard 参照" in payload.body
        # 72h = 3 days
        assert "3 日" in payload.body

    def test_n_format_uses_pipe_separators(self, tmproot):
        write_dashboard(tmproot, in_progress=[
            {"cmd": "cmd_a", "content": "x", "assignee": "ashigaru1",
             "status": "🔄", "promoted_at": _jst_iso(24)},
        ])
        payload = build_digest(str(tmproot))
        # E-3 requires three pipe-separated sections
        assert payload.body.count("|") == 2


# ────────────────────────────────────────────────────────────
# E-4: liveness — sender down detection
# ────────────────────────────────────────────────────────────


class TestDigestLiveness:
    def test_no_state_means_sender_down(self, tmproot):
        # No alert_state.yaml at all → no successful send → is_down=True
        status = check_digest_liveness(str(tmproot))
        assert status["is_down"] is True
        assert status["last_success_at"] is None
        assert status["hours_since_last"] == float("inf")

    def test_recent_success_not_down(self, tmproot):
        record_digest_attempt(str(tmproot), success=True)
        status = check_digest_liveness(str(tmproot))
        assert status["is_down"] is False
        assert status["consecutive_failures"] == 0
        assert status["hours_since_last"] < 1

    def test_stale_success_is_down(self, tmproot):
        # Manually plant an old success
        old_iso = _jst_iso(48)
        write_alert_state(tmproot, {
            "gates": {},
            "notifications": {},
            "dashboard_events": [],
            "digest_liveness": {
                "last_success_at": old_iso,
                "last_attempt_at": old_iso,
                "consecutive_failures": 0,
            },
        })
        status = check_digest_liveness(str(tmproot))
        assert status["is_down"] is True
        assert status["hours_since_last"] >= 26

    def test_grace_window_respected(self, tmproot):
        recent_iso = _jst_iso(20)
        write_alert_state(tmproot, {
            "gates": {},
            "notifications": {},
            "dashboard_events": [],
            "digest_liveness": {
                "last_success_at": recent_iso,
                "last_attempt_at": recent_iso,
                "consecutive_failures": 0,
            },
        })
        status = check_digest_liveness(str(tmproot))
        assert status["is_down"] is False

    def test_failure_increments_consecutive_failures(self, tmproot):
        record_digest_attempt(str(tmproot), success=False)
        record_digest_attempt(str(tmproot), success=False)
        liveness = get_digest_liveness(str(tmproot))
        assert liveness["consecutive_failures"] == 2

    def test_success_resets_consecutive_failures(self, tmproot):
        record_digest_attempt(str(tmproot), success=False)
        record_digest_attempt(str(tmproot), success=False)
        record_digest_attempt(str(tmproot), success=True)
        liveness = get_digest_liveness(str(tmproot))
        assert liveness["consecutive_failures"] == 0

    def test_alert_key_prefix_never_suppress(self):
        assert is_digest_sender_down_alert("P_DIGEST_SENDER_DOWN") is True
        assert is_digest_sender_down_alert("P_DIGEST_SENDER_DOWN_x") is True
        assert is_digest_sender_down_alert("P9_xx") is False
        assert is_digest_sender_down_alert("P_GATE_ZOMBIE_xx") is False

    def test_alert_state_top_level_keys_preserved(self, tmproot):
        write_alert_state(tmproot, {
            "gates": {"existing_gate": {"state": "open"}},
            "notifications": {"foo": "bar"},
            "dashboard_events": [{"event_kind": "x", "source_id": "y"}],
        })
        record_digest_attempt(str(tmproot), success=True)
        with open(tmproot / "queue" / "alert_state.yaml", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        assert "existing_gate" in data["gates"]
        assert data["notifications"] == {"foo": "bar"}
        assert data["dashboard_events"][0]["event_kind"] == "x"
        assert "digest_liveness" in data


# ────────────────────────────────────────────────────────────
# send_digest — dry-run / runner injection
# ────────────────────────────────────────────────────────────


class TestSendDigest:
    def test_dry_run_does_not_touch_liveness(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        ok = send_digest(str(tmproot), dry_run=True)
        assert ok is True
        # No liveness recorded in dry-run
        liveness = get_digest_liveness(str(tmproot))
        assert liveness == {}

    def test_runner_success_records_success(self, tmproot):
        write_dashboard(tmproot, in_progress=[])

        def runner(body, title, mtype):
            assert "行動中 0件" in body
            assert mtype == "daily_digest"
            return True

        ok = send_digest(str(tmproot), notify_runner=runner)
        assert ok is True
        liveness = get_digest_liveness(str(tmproot))
        assert liveness.get("last_success_at")
        assert liveness.get("consecutive_failures") == 0

    def test_runner_failure_records_failure(self, tmproot):
        write_dashboard(tmproot, in_progress=[])

        def runner(body, title, mtype):
            return False

        ok = send_digest(str(tmproot), notify_runner=runner)
        assert ok is False
        liveness = get_digest_liveness(str(tmproot))
        assert liveness.get("consecutive_failures") == 1
        assert liveness.get("last_attempt_at")
        # last_success_at not set because runner returned False
        assert not liveness.get("last_success_at")


# ────────────────────────────────────────────────────────────
# E-1: gate auto-register parser
# ────────────────────────────────────────────────────────────


class TestParseCmdBlocks:
    def test_parses_multiple_cmds(self):
        content = (
            "- id: cmd_111\n"
            "  status: pending\n"
            "  purpose: foo\n"
            "- id: cmd_112\n"
            "  status: dispatched\n"
            "  purpose: bar\n"
        )
        cmds = parse_cmd_blocks(content)
        assert len(cmds) == 2
        assert cmds[0]["id"] == "cmd_111"
        assert cmds[1]["id"] == "cmd_112"

    def test_robust_to_broken_block(self):
        # Second block is malformed YAML; parser must keep the first
        content = (
            "- id: cmd_111\n"
            "  status: pending\n"
            "- id: cmd_112\n"
            "  status: pending\n"
            "  command: |\n"
            "    [malformed yaml] : : :\n"
            "      this is still ok in pipe block\n"
        )
        cmds = parse_cmd_blocks(content)
        # At minimum cmd_111 survives
        ids = [c.get("id") for c in cmds]
        assert "cmd_111" in ids


class TestExtractGateCandidates:
    def test_no_gates_returns_empty(self):
        cmd = {
            "id": "cmd_001",
            "purpose": "Refactor logging",
            "command": "Add structured logger",
            "north_star": "Better observability",
        }
        assert extract_gate_candidates(cmd) == []

    def test_explicit_gates_field(self):
        cmd = {
            "id": "cmd_712",
            "gates": [
                {
                    "tag": "[action-1] [cmd_712-phase-a-manual-verify]",
                    "title": "Web App Phase A deploy",
                    "detail": "殿 Apps Script deploy 実機確認",
                    "severity": "HIGH",
                    "expected_action": "殿の実機検証",
                }
            ],
        }
        candidates = extract_gate_candidates(cmd)
        assert len(candidates) == 1
        assert candidates[0]["source"] == "explicit_gates_field"
        assert candidates[0]["source_cmd_id"] == "cmd_712"
        assert candidates[0]["severity"] == "HIGH"

    def test_implicit_keyword_in_north_star(self):
        cmd = {
            "id": "cmd_900",
            "north_star": "deploy 実機 で殿の承認を受ける",
            "purpose": "Deploy preview",
            "command": "build & push",
        }
        candidates = extract_gate_candidates(cmd)
        assert len(candidates) >= 1
        assert any(c["source"].startswith("implicit_keyword:") for c in candidates)
        assert candidates[0]["source_cmd_id"] == "cmd_900"

    def test_implicit_keyword_in_command(self):
        cmd = {
            "id": "cmd_901",
            "north_star": "improve test coverage",
            "purpose": "n/a",
            "command": "After tests pass, do a manual_verify with Lord",
        }
        candidates = extract_gate_candidates(cmd)
        assert len(candidates) >= 1
        assert candidates[0]["source"].startswith("implicit_keyword:")

    def test_explicit_overrides_implicit(self):
        cmd = {
            "id": "cmd_902",
            "command": "After release, manual_verify needed",
            "gates": [
                {"tag": "[action-1] [explicit]", "title": "explicit", "detail": "x"}
            ],
        }
        candidates = extract_gate_candidates(cmd)
        assert all(c["source"] == "explicit_gates_field" for c in candidates)
        assert len(candidates) == 1

    def test_non_dict_input_safe(self):
        assert extract_gate_candidates(None) == []
        assert extract_gate_candidates(["not", "a", "dict"]) == []


class TestGateAutoRegisterApply:
    def test_dry_run_via_collect_does_not_touch_dashboard(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        # No dashboard.yaml gate_registry written by collect_gate_candidates
        cmds = [
            {"id": "cmd_777", "gates": [
                {"tag": "[action-1] [cmd_777-x]", "title": "x", "detail": "d"}
            ]},
        ]
        candidates = collect_gate_candidates(cmds)
        assert len(candidates) == 1
        with open(tmproot / "dashboard.yaml", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        assert data.get("gate_registry") is None

    def test_apply_writes_state_candidate(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        candidates = [{
            "tag": "[action-1] [cmd_888-test]",
            "title": "Test gate",
            "detail": "test detail",
            "severity": "HIGH",
            "expected_action": "殿確認",
            "source": "explicit_gates_field",
            "source_cmd_id": "cmd_888",
        }]
        written = apply_candidates_to_registry(str(tmproot), candidates)
        assert len(written) == 1
        with open(tmproot / "dashboard.yaml", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        registry = data.get("gate_registry") or []
        assert len(registry) == 1
        entry = registry[0]
        assert entry["state"] == "candidate"  # manual-confirm boundary
        assert entry["registered_by"] == "shogun_to_karo_parser.py"
        assert entry["notified_at"] is None  # not yet promoted to action_required
        assert entry["parent_cmd"] == "cmd_888"

    def test_apply_is_idempotent_by_tag(self, tmproot):
        write_dashboard(tmproot, in_progress=[])
        candidates = [{
            "tag": "[action-1] [cmd_888-test]",
            "title": "Test gate",
            "detail": "test detail",
            "severity": "HIGH",
            "expected_action": "殿確認",
            "source": "explicit_gates_field",
            "source_cmd_id": "cmd_888",
        }]
        apply_candidates_to_registry(str(tmproot), candidates)
        second = apply_candidates_to_registry(str(tmproot), candidates)
        assert second == []  # nothing new written
        with open(tmproot / "dashboard.yaml", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        assert len(data["gate_registry"]) == 1

    def test_apply_preserves_existing_registry(self, tmproot):
        write_dashboard(tmproot, in_progress=[], gate_registry=[{
            "gate_id": "pre-existing",
            "tag": "pre-existing",
            "title": "pre",
            "detail": "pre",
            "state": "open",
            "expected_action": "x",
            "registered_at": _jst_iso(0),
        }])
        candidates = [{
            "tag": "[action-1] [cmd_888-new]",
            "title": "new gate",
            "detail": "d",
            "severity": "HIGH",
            "expected_action": "殿確認",
            "source": "explicit_gates_field",
            "source_cmd_id": "cmd_888",
        }]
        apply_candidates_to_registry(str(tmproot), candidates)
        with open(tmproot / "dashboard.yaml", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        registry = data["gate_registry"]
        tags = {r.get("tag") for r in registry}
        assert "pre-existing" in tags
        assert "[action-1] [cmd_888-new]" in tags

    def test_load_cmd_blocks_returns_empty_when_missing(self, tmproot):
        assert load_cmd_blocks(str(tmproot)) == []
