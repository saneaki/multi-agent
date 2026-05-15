"""
Unit tests for gate_suppression.py — cmd_716 Phase B + Phase C
AC: B-1 (classification), B-2 (suppression), B-5 (regression),
    C-1/C-2 (P6 event ledger), C-3 (PoC detection rate)
"""
import os
import sys
import tempfile
import textwrap
import time

import pytest
import yaml

# Ensure gate_suppression can be imported from scripts/lib
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../scripts/lib"))
from gate_suppression import (
    GateStatus,
    all_uncommitted_are_gate_runtime,
    classify_event_kind,
    event_ledger_detection_rate,
    get_gate_status,
    has_pending_dashboard_events,
    has_unresolved_dashboard_events,
    is_gate_runtime_file,
    load_event_ledger,
    save_event_ledger,
    should_suppress_p5,
    should_suppress_stall,
    should_suppress_uncommitted,
    unresolved_events,
    update_event_ledger,
)


# ────────────────────────────────────────────────────────────
# Fixtures
# ────────────────────────────────────────────────────────────

@pytest.fixture()
def tmproot(tmp_path):
    """Minimal project root with required directories."""
    (tmp_path / "queue").mkdir()
    (tmp_path / "queue" / "tasks").mkdir()
    (tmp_path / "queue" / "reports").mkdir()
    (tmp_path / "queue" / "inbox").mkdir()
    return tmp_path


def write_yaml(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, allow_unicode=True)


def make_dashboard_with_gates(tmp_path, gate_tags, in_progress=None):
    """Write dashboard.yaml with the specified gate tags and in_progress entries."""
    action_required = [
        {
            "tag": tag,
            "title": f"gate {i}",
            "severity": "HIGH",
            "created_at": "2026-05-12T07:50:00+09:00",
            "detail": "test",
        }
        for i, tag in enumerate(gate_tags)
    ]
    data = {
        "action_required": action_required,
        "in_progress": in_progress or [],
    }
    write_yaml(tmp_path / "dashboard.yaml", data)


# ────────────────────────────────────────────────────────────
# B-1: Alert classification
# ────────────────────────────────────────────────────────────

class TestGetGateStatus:
    def test_no_dashboard_file(self, tmproot):
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is False
        assert gs.gate_ids == []

    def test_no_action_required(self, tmproot):
        write_yaml(tmproot / "dashboard.yaml", {"action_required": []})
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is False

    def test_single_high_gate(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is True
        assert len(gs.gate_ids) == 1
        assert "cmd_712" in gs.cmd_ids

    def test_info_item_not_counted_as_gate(self, tmproot):
        write_yaml(tmproot / "dashboard.yaml", {
            "action_required": [
                {
                    "tag": "[情報] [yomitoku-origin-correction]",
                    "title": "info item",
                    "severity": "INFO",
                    "created_at": "2026-05-13T10:25:00+09:00",
                    "detail": "test",
                }
            ]
        })
        gs = get_gate_status(str(tmproot))
        # INFO items don't count as judgement gates
        assert gs.has_open_gate is False

    def test_multiple_gates(self, tmproot):
        make_dashboard_with_gates(tmproot, [
            "[action-1] [cmd_712-phase-a-manual-verify]",
            "[action-2] [cmd_709-clasp-run-reauth]",
            "[action-6] [cmd_725-cli-recovery-manual-gate]",
        ])
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is True
        assert len(gs.gate_ids) == 3
        assert "cmd_712" in gs.cmd_ids
        assert "cmd_709" in gs.cmd_ids


# ────────────────────────────────────────────────────────────
# B-1: is_gate_runtime_file classification
# ────────────────────────────────────────────────────────────

class TestIsGateRuntimeFile:
    @pytest.mark.parametrize("path", [
        "queue/reports/ashigaru2_report.yaml",
        "queue/inbox/karo.yaml",
        "queue/tasks/ashigaru3.yaml",
        "queue/suggestions.yaml",
        "queue/external_inbox.yaml",
        "queue/alert_state.yaml",
        "memory/global_context.md",
        "scripts/shc.sh",
        "dashboard.yaml",
    ])
    def test_runtime_file_classified_as_gate_runtime(self, path):
        assert is_gate_runtime_file(path) is True

    @pytest.mark.parametrize("path", [
        "scripts/discord_notify.py",
        "scripts/notify.sh",
        "tests/unit/test_gate_suppression.py",
        "docs/dashboard_schema.json",
        "scripts/shogun_in_progress_monitor.sh",
        "scripts/lib/gate_suppression.py",
    ])
    def test_source_file_classified_as_non_runtime(self, path):
        assert is_gate_runtime_file(path) is False

    def test_nested_memory_file(self):
        assert is_gate_runtime_file("memory/skill_history.md") is True

    def test_non_yaml_queue_file(self):
        # Only .yaml files in queue/ subdirs count
        assert is_gate_runtime_file("queue/some_script.sh") is False


# ────────────────────────────────────────────────────────────
# B-2: P5 suppression (殿手作業滞留)
# ────────────────────────────────────────────────────────────

class TestShouldSuppressP5:
    def _make_inbox(self, tmproot, messages):
        write_yaml(tmproot / "queue" / "inbox" / "shogun.yaml", {"messages": messages})

    def test_suppressed_when_gate_open_and_only_monitor_alerts(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        self._make_inbox(tmproot, [
            {"read": False, "type": "in_progress_monitor_alert",
             "content": "⚠️ test alert", "timestamp": "2026-05-15T01:00:00+09:00"},
        ])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_p5(str(tmproot), gs) is True

    def test_not_suppressed_when_new_action_required(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        self._make_inbox(tmproot, [
            {"read": False, "type": "action_required",
             "content": "new decision needed", "timestamp": "2026-05-15T01:00:00+09:00"},
        ])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_p5(str(tmproot), gs) is False

    def test_not_suppressed_when_no_gate(self, tmproot):
        write_yaml(tmproot / "dashboard.yaml", {"action_required": []})
        self._make_inbox(tmproot, [
            {"read": False, "type": "in_progress_monitor_alert",
             "content": "test", "timestamp": "2026-05-15T01:00:00+09:00"},
        ])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_p5(str(tmproot), gs) is False

    def test_not_suppressed_when_cmd_complete_unread(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        self._make_inbox(tmproot, [
            {"read": False, "type": "cmd_complete",
             "content": "cmd_727 complete", "timestamp": "2026-05-15T01:00:00+09:00"},
        ])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_p5(str(tmproot), gs) is False

    def test_suppressed_with_reality_check_alert(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-2] [cmd_709-clasp-run-reauth]"])
        self._make_inbox(tmproot, [
            {"read": False, "type": "reality_check_alert",
             "content": "⚠️ UNCOMMITTED", "timestamp": "2026-05-15T01:00:00+09:00"},
        ])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_p5(str(tmproot), gs) is True


# ────────────────────────────────────────────────────────────
# B-2: 見回り-1 suppression (dashboard stall)
# ────────────────────────────────────────────────────────────

class TestShouldSuppressStall:
    def test_suppressed_when_all_in_progress_have_gates(self, tmproot):
        make_dashboard_with_gates(
            tmproot,
            ["[action-1] [cmd_712-phase-a-manual-verify]"],
            in_progress=[{"cmd": "cmd_712", "assignee": "殿/家老"}],
        )
        gs = get_gate_status(str(tmproot))
        assert should_suppress_stall(str(tmproot), gs) is True

    def test_not_suppressed_when_some_cmds_lack_gates(self, tmproot):
        make_dashboard_with_gates(
            tmproot,
            ["[action-1] [cmd_712-phase-a-manual-verify]"],
            in_progress=[
                {"cmd": "cmd_712", "assignee": "殿/家老"},
                {"cmd": "cmd_716", "assignee": "足軽2号(Sonnet)"},  # no gate
            ],
        )
        gs = get_gate_status(str(tmproot))
        assert should_suppress_stall(str(tmproot), gs) is False

    def test_not_suppressed_when_no_gate(self, tmproot):
        write_yaml(tmproot / "dashboard.yaml", {
            "action_required": [],
            "in_progress": [{"cmd": "cmd_716", "assignee": "足軽2号(Sonnet)"}],
        })
        gs = get_gate_status(str(tmproot))
        assert should_suppress_stall(str(tmproot), gs) is False

    def test_not_suppressed_when_in_progress_empty(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        gs = get_gate_status(str(tmproot))
        assert should_suppress_stall(str(tmproot), gs) is False


# ────────────────────────────────────────────────────────────
# B-2: 見回り-6 suppression (uncommitted)
# ────────────────────────────────────────────────────────────

class TestShouldSuppressUncommitted:
    def test_suppressed_when_only_runtime_files(self, tmproot):
        """Simulate all-runtime uncommitted state using monkeypatch."""
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        gs = get_gate_status(str(tmproot))
        # Monkeypatch subprocess result
        import gate_suppression as _gs
        original = _gs.subprocess.run

        class FakeResult:
            stdout = (
                " M queue/reports/ashigaru2_report.yaml\n"
                " M queue/inbox/karo.yaml\n"
                " M memory/global_context.md\n"
            )
            returncode = 0

        _gs.subprocess.run = lambda *a, **kw: FakeResult()
        try:
            result = should_suppress_uncommitted(str(tmproot), gs)
        finally:
            _gs.subprocess.run = original
        assert result is True

    def test_not_suppressed_when_source_files_modified(self, tmproot):
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        gs = get_gate_status(str(tmproot))
        import gate_suppression as _gs
        original = _gs.subprocess.run

        class FakeResult:
            stdout = (
                " M queue/reports/ashigaru2_report.yaml\n"
                " M scripts/discord_notify.py\n"  # source file — no suppress
            )
            returncode = 0

        _gs.subprocess.run = lambda *a, **kw: FakeResult()
        try:
            result = should_suppress_uncommitted(str(tmproot), gs)
        finally:
            _gs.subprocess.run = original
        assert result is False

    def test_not_suppressed_when_no_gate(self, tmproot):
        write_yaml(tmproot / "dashboard.yaml", {"action_required": []})
        gs = get_gate_status(str(tmproot))
        assert should_suppress_uncommitted(str(tmproot), gs) is False


# ────────────────────────────────────────────────────────────
# B-2: system alert regression — NEVER suppress GHA/daemon
# ────────────────────────────────────────────────────────────

class TestSystemAlertRegression:
    def test_gha_files_are_not_gate_runtime(self):
        """GHA-related paths must never be classified as gate runtime."""
        assert is_gate_runtime_file(".github/workflows/daily-notion-sync.yml") is False
        assert is_gate_runtime_file("scripts/repo_health_check.sh") is False
        assert is_gate_runtime_file("scripts/gha_failure_check.sh") is False

    def test_daemon_scripts_are_not_gate_runtime(self):
        assert is_gate_runtime_file("scripts/discord_gateway.py") is False
        assert is_gate_runtime_file("scripts/shogun_in_progress_monitor.sh") is False
        assert is_gate_runtime_file("scripts/shogun_reality_check.sh") is False

    def test_get_gate_status_is_safe_on_corrupt_yaml(self, tmproot):
        """gate_suppression must not crash on malformed dashboard.yaml."""
        (tmproot / "dashboard.yaml").write_text("{ not valid yaml: [", encoding="utf-8")
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is False


# ────────────────────────────────────────────────────────────
# B-3: P6 event-driven (basic mtime check)
# ────────────────────────────────────────────────────────────

class TestHasPendingDashboardEvents:
    def test_no_events_when_dashboard_is_newest(self, tmproot, tmp_path):
        import time
        # Create task and report files
        task = tmproot / "queue" / "tasks" / "ashigaru2.yaml"
        write_yaml(task, {"task_id": "t1"})
        time.sleep(0.05)
        # dashboard.md is newer
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:08 JST\n", encoding="utf-8")
        assert has_pending_dashboard_events(str(tmproot)) is False

    def test_events_when_task_newer_than_dashboard(self, tmproot):
        import time
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:08 JST\n", encoding="utf-8")
        time.sleep(0.05)
        # task updated after dashboard
        task = tmproot / "queue" / "tasks" / "ashigaru2.yaml"
        write_yaml(task, {"task_id": "t1"})
        assert has_pending_dashboard_events(str(tmproot)) is True

    def test_no_events_when_no_source_files(self, tmproot):
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:08 JST\n", encoding="utf-8")
        # No task/report files
        assert has_pending_dashboard_events(str(tmproot)) is False


# ────────────────────────────────────────────────────────────
# C-1: event_kind classification
# ────────────────────────────────────────────────────────────

class TestClassifyEventKind:
    @pytest.mark.parametrize("path,expected", [
        ("queue/tasks/ashigaru5.yaml", "task_status_change"),
        ("queue/tasks/gunshi.yaml", "task_status_change"),
        ("queue/reports/gunshi_report.yaml", "qc_completed"),
        ("queue/reports/ashigaru2_report.yaml", "report_appended"),
        ("queue/reports/karo_report.yaml", "report_appended"),
        ("queue/shogun_to_karo.yaml", "cmd_dispatched"),
        ("scripts/something.py", "unknown"),
        ("dashboard.yaml", "unknown"),
    ])
    def test_classification(self, path, expected):
        assert classify_event_kind(path) == expected


# ────────────────────────────────────────────────────────────
# C-1/C-2: P6 event ledger lifecycle
# ────────────────────────────────────────────────────────────

class TestEventLedger:
    def _setup_state_skeleton(self, tmproot):
        (tmproot / "queue").mkdir(exist_ok=True)
        state_path = tmproot / "queue" / "alert_state.yaml"
        state_path.write_text(
            "gates: {}\nnotifications: {}\ndashboard_events: []\n",
            encoding="utf-8",
        )
        return state_path

    def test_load_event_ledger_creates_defaults_when_missing(self, tmproot):
        state = load_event_ledger(str(tmproot))
        assert state["gates"] == {}
        assert state["notifications"] == {}
        assert state["dashboard_events"] == []

    def test_load_event_ledger_preserves_existing_gates(self, tmproot):
        self._setup_state_skeleton(tmproot)
        state_path = tmproot / "queue" / "alert_state.yaml"
        state_path.write_text(
            "gates:\n"
            "  gate_cmd_716_test:\n"
            "    state: open\n"
            "    first_seen_at: '2026-05-15T15:00:00+09:00'\n"
            "notifications: {}\n"
            "dashboard_events: []\n",
            encoding="utf-8",
        )
        state = load_event_ledger(str(tmproot))
        assert "gate_cmd_716_test" in state["gates"]
        assert state["gates"]["gate_cmd_716_test"]["state"] == "open"

    def test_save_event_ledger_round_trip(self, tmproot):
        self._setup_state_skeleton(tmproot)
        state = load_event_ledger(str(tmproot))
        state["dashboard_events"].append({
            "event_kind": "task_status_change",
            "source_id": "queue/tasks/ashigaru5.yaml",
            "source_mtime": "2026-05-15T16:00:00+09:00",
            "first_seen_at": "2026-05-15T16:00:01+09:00",
            "resolved_at": None,
        })
        assert save_event_ledger(str(tmproot), state) is True
        reloaded = load_event_ledger(str(tmproot))
        assert len(reloaded["dashboard_events"]) == 1
        assert reloaded["dashboard_events"][0]["source_id"] == "queue/tasks/ashigaru5.yaml"

    def test_update_ledger_records_newer_task(self, tmproot):
        self._setup_state_skeleton(tmproot)
        # dashboard.md first
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        # task newer than dashboard
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        state = update_event_ledger(str(tmproot))
        pending = unresolved_events(state)
        assert len(pending) == 1
        ev = pending[0]
        assert ev["event_kind"] == "task_status_change"
        assert ev["source_id"] == "queue/tasks/ashigaru5.yaml"
        assert ev["resolved_at"] is None
        assert ev["first_seen_at"]  # set
        assert ev["source_mtime"]  # set

    def test_update_ledger_ignores_older_source(self, tmproot):
        self._setup_state_skeleton(tmproot)
        # task first
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        time.sleep(0.05)
        # dashboard newer than task
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:30 JST\n", encoding="utf-8")
        state = update_event_ledger(str(tmproot))
        assert unresolved_events(state) == []

    def test_event_resolves_when_dashboard_catches_up(self, tmproot):
        self._setup_state_skeleton(tmproot)
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        task_path = tmproot / "queue" / "tasks" / "ashigaru5.yaml"
        write_yaml(task_path, {"task_id": "t1"})

        state = update_event_ledger(str(tmproot))
        assert len(unresolved_events(state)) == 1

        # Simulate dashboard regen: make dashboard newer than task
        time.sleep(0.05)
        dash.write_text("最終更新: 2026-05-15 15:30 JST\n", encoding="utf-8")
        state2 = update_event_ledger(str(tmproot))
        assert unresolved_events(state2) == []
        # The ledger keeps resolved entry for audit
        all_events = state2["dashboard_events"]
        assert len(all_events) == 1
        assert all_events[0]["resolved_at"] is not None

    def test_event_reopens_when_source_changes_again(self, tmproot):
        self._setup_state_skeleton(tmproot)
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        task_path = tmproot / "queue" / "tasks" / "ashigaru5.yaml"
        write_yaml(task_path, {"task_id": "t1"})
        update_event_ledger(str(tmproot))
        # Resolve
        time.sleep(0.05)
        dash.write_text("最終更新: 2026-05-15 15:30 JST\n", encoding="utf-8")
        state_resolved = update_event_ledger(str(tmproot))
        assert unresolved_events(state_resolved) == []
        # New change → reopen
        time.sleep(0.05)
        write_yaml(task_path, {"task_id": "t1", "status": "done"})
        state_reopen = update_event_ledger(str(tmproot))
        pending = unresolved_events(state_reopen)
        assert len(pending) == 1
        assert pending[0]["source_id"] == "queue/tasks/ashigaru5.yaml"

    def test_has_unresolved_returns_bool(self, tmproot):
        self._setup_state_skeleton(tmproot)
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        # No newer files
        assert has_unresolved_dashboard_events(str(tmproot)) is False
        time.sleep(0.05)
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        assert has_unresolved_dashboard_events(str(tmproot)) is True

    def test_ledger_persists_across_calls(self, tmproot):
        self._setup_state_skeleton(tmproot)
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        update_event_ledger(str(tmproot))
        # Reload from disk
        state2 = load_event_ledger(str(tmproot))
        assert len(state2["dashboard_events"]) == 1

    def test_ledger_does_not_touch_gates_section(self, tmproot):
        self._setup_state_skeleton(tmproot)
        state_path = tmproot / "queue" / "alert_state.yaml"
        state_path.write_text(
            "gates:\n"
            "  gate_cmd_716_test:\n"
            "    state: open\n"
            "    first_seen_at: '2026-05-15T15:00:00+09:00'\n"
            "notifications:\n"
            "  some_key: some_value\n"
            "dashboard_events: []\n",
            encoding="utf-8",
        )
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        update_event_ledger(str(tmproot))
        reloaded = load_event_ledger(str(tmproot))
        # Phase A/B state must be intact
        assert "gate_cmd_716_test" in reloaded["gates"]
        assert reloaded["gates"]["gate_cmd_716_test"]["state"] == "open"
        assert reloaded["notifications"]["some_key"] == "some_value"


# ────────────────────────────────────────────────────────────
# C-3: PoC gate detection rate (>=95%)
# ────────────────────────────────────────────────────────────

class TestEventLedgerDetectionRate:
    def _seed_changes(self, tmproot, n_files):
        """Create dashboard.md first, then n_files newer task/report files."""
        (tmproot / "queue" / "tasks").mkdir(parents=True, exist_ok=True)
        (tmproot / "queue" / "reports").mkdir(parents=True, exist_ok=True)
        (tmproot / "queue").mkdir(exist_ok=True)
        (tmproot / "queue" / "alert_state.yaml").write_text(
            "gates: {}\nnotifications: {}\ndashboard_events: []\n",
            encoding="utf-8",
        )
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        expected = []
        for i in range(n_files):
            if i % 3 == 0:
                p = tmproot / "queue" / "tasks" / f"ashigaru{i}.yaml"
            elif i % 3 == 1:
                p = tmproot / "queue" / "reports" / f"ashigaru{i}_report.yaml"
            else:
                p = tmproot / "queue" / "shogun_to_karo.yaml"
            write_yaml(p, {"task_id": f"t{i}"})
            expected.append(str(p.relative_to(tmproot)).replace("\\", "/"))
        # dedup (shogun_to_karo.yaml appears multiple times)
        expected_unique = list(dict.fromkeys(expected))
        return expected_unique

    def test_detection_rate_meets_95pct_on_fixture(self, tmproot):
        expected = self._seed_changes(tmproot, 20)
        rate = event_ledger_detection_rate(str(tmproot), expected)
        assert rate >= 0.95, f"detection rate {rate:.2%} below 95% target"

    def test_detection_rate_full_match_when_all_changed(self, tmproot):
        expected = self._seed_changes(tmproot, 6)
        rate = event_ledger_detection_rate(str(tmproot), expected)
        assert rate == 1.0

    def test_detection_rate_zero_when_dashboard_newer(self, tmproot):
        # task first
        (tmproot / "queue" / "tasks").mkdir(parents=True, exist_ok=True)
        (tmproot / "queue").mkdir(exist_ok=True)
        (tmproot / "queue" / "alert_state.yaml").write_text(
            "gates: {}\nnotifications: {}\ndashboard_events: []\n",
            encoding="utf-8",
        )
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        time.sleep(0.05)
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:30 JST\n", encoding="utf-8")
        rate = event_ledger_detection_rate(
            str(tmproot), ["queue/tasks/ashigaru5.yaml"],
        )
        assert rate == 0.0


# ────────────────────────────────────────────────────────────
# C-3: system alert must not be suppressed by event ledger
# ────────────────────────────────────────────────────────────

class TestEventLedgerSystemSafety:
    def test_has_unresolved_safe_on_missing_state(self, tmproot):
        # No queue/alert_state.yaml, no dashboard.md → must not crash
        result = has_unresolved_dashboard_events(str(tmproot))
        assert result is False

    def test_has_unresolved_safe_on_corrupt_state(self, tmproot):
        (tmproot / "queue").mkdir(exist_ok=True)
        (tmproot / "queue" / "alert_state.yaml").write_text(
            "{ not valid yaml: [",
            encoding="utf-8",
        )
        dash = tmproot / "dashboard.md"
        dash.write_text("最終更新: 2026-05-15 15:00 JST\n", encoding="utf-8")
        time.sleep(0.05)
        write_yaml(tmproot / "queue" / "tasks" / "ashigaru5.yaml", {"task_id": "t1"})
        # corrupt state file is auto-recovered; ledger should still detect event
        assert has_unresolved_dashboard_events(str(tmproot)) is True

    def test_phase_a_b_functions_still_work(self, tmproot):
        """Regression: Phase A/B suppression and classification untouched."""
        make_dashboard_with_gates(tmproot, ["[action-1] [cmd_712-phase-a-manual-verify]"])
        gs = get_gate_status(str(tmproot))
        assert gs.has_open_gate is True
        assert is_gate_runtime_file("queue/reports/ashigaru5_report.yaml") is True
        assert is_gate_runtime_file("scripts/discord_notify.py") is False
