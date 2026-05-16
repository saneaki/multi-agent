"""
Unit tests for status_check_rules.py — cmd_731 β-1
AC-1: check_dashboard_senka_empty
AC-2: check_frog_unset
AC-3: check_metrics_stale
AC-4: check_ash_done_pending (DONE_MAX_AGE_MIN removed)
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
import yaml

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../scripts/lib"))

from status_check_rules import (
    check_ash_done_pending,
    check_dashboard_senka_empty,
    check_frog_unset,
    check_metrics_stale,
)

JST = timezone(timedelta(hours=9))


def _write_yaml(path: str, data: object) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True)


def _make_root(tmp_path, dashboard_data=None, task_files=None) -> str:
    root = str(tmp_path)
    dashboard = dashboard_data if dashboard_data is not None else {}
    _write_yaml(os.path.join(root, "dashboard.yaml"), dashboard)
    if task_files:
        for filename, data in task_files.items():
            _write_yaml(os.path.join(root, "queue", "tasks", filename), data)
    return root


# ---------------------------------------------------------------------------
# AC-1: check_dashboard_senka_empty
# ---------------------------------------------------------------------------

class TestCheckDashboardSenkaEmpty:
    def test_ok_when_items_present_list(self, tmp_path):
        root = _make_root(tmp_path, {
            "achievements": {"today": [{"task": "cmd_100", "result": "done"}]}
        })
        assert check_dashboard_senka_empty(root) == "ok"

    def test_ok_when_items_present_dict_format(self, tmp_path):
        root = _make_root(tmp_path, {
            "achievements": {"today": {"header": "5/16", "items": [{"task": "cmd_X"}]}}
        })
        assert check_dashboard_senka_empty(root) == "ok"

    def test_ok_when_empty_but_hour_before_12(self, tmp_path):
        root = _make_root(tmp_path, {"achievements": {"today": []}})
        mock_now = datetime(2026, 5, 16, 11, 59, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            assert check_dashboard_senka_empty(root) == "ok"

    def test_pending_when_empty_and_after_12(self, tmp_path):
        root = _make_root(tmp_path, {"achievements": {"today": []}})
        mock_now = datetime(2026, 5, 16, 15, 30, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            result = check_dashboard_senka_empty(root)
        assert result.startswith("PENDING:")
        assert "戦果" in result

    def test_pending_when_dict_format_empty_items(self, tmp_path):
        root = _make_root(tmp_path, {
            "achievements": {"today": {"header": "5/16", "items": []}}
        })
        mock_now = datetime(2026, 5, 16, 14, 0, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            result = check_dashboard_senka_empty(root)
        assert result.startswith("PENDING:")

    def test_ok_when_achievements_missing(self, tmp_path):
        root = _make_root(tmp_path, {})
        mock_now = datetime(2026, 5, 16, 9, 0, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            assert check_dashboard_senka_empty(root) == "ok"


# ---------------------------------------------------------------------------
# AC-2: check_frog_unset
# ---------------------------------------------------------------------------

class TestCheckFrogUnset:
    def test_ok_when_frog_set(self, tmp_path):
        root = _make_root(tmp_path, {"frog": {"today": "frog_task_X"}})
        assert check_frog_unset(root) == "ok"

    def test_ok_when_null_but_before_18(self, tmp_path):
        root = _make_root(tmp_path, {"frog": {"today": None}})
        mock_now = datetime(2026, 5, 16, 17, 59, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            assert check_frog_unset(root) == "ok"

    def test_pending_when_null_and_after_18(self, tmp_path):
        root = _make_root(tmp_path, {"frog": {"today": None}})
        mock_now = datetime(2026, 5, 16, 20, 0, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            assert check_frog_unset(root) == "PENDING: frog 未設定"

    def test_pending_when_frog_section_missing_and_after_18(self, tmp_path):
        # frog section absent → today is None → counts as unset
        root = _make_root(tmp_path, {})
        mock_now = datetime(2026, 5, 16, 23, 0, 0, tzinfo=JST)
        with patch("status_check_rules._jst_now", return_value=mock_now):
            assert check_frog_unset(root) == "PENDING: frog 未設定"

    def test_ok_when_frog_today_is_string(self, tmp_path):
        root = _make_root(tmp_path, {"frog": {"today": "some task"}})
        assert check_frog_unset(root) == "ok"


# ---------------------------------------------------------------------------
# AC-3: check_metrics_stale
# ---------------------------------------------------------------------------

class TestCheckMetricsStale:
    def test_ok_when_metrics_empty(self, tmp_path):
        root = _make_root(tmp_path, {"metrics": []})
        assert check_metrics_stale(root) == "ok"

    def test_ok_when_metrics_missing(self, tmp_path):
        root = _make_root(tmp_path, {})
        assert check_metrics_stale(root) == "ok"

    def test_ok_when_recent_within_36h(self, tmp_path):
        now_jst = datetime.now(JST)
        # 20h ago (well within 36h)
        recent_date = (now_jst - timedelta(hours=20)).strftime("%Y-%m-%d")
        root = _make_root(tmp_path, {"metrics": [{"date": recent_date, "success": 5}]})
        result = check_metrics_stale(root)
        assert result == "ok"

    def test_pending_when_stale_over_36h(self, tmp_path):
        # Use a hardcoded old date guaranteed to be > 36h ago
        old_date = "2020-01-01"
        root = _make_root(tmp_path, {"metrics": [{"date": old_date, "success": 0}]})
        result = check_metrics_stale(root)
        assert result.startswith("PENDING:")
        assert "stale" in result

    def test_ok_with_date_jst_field(self, tmp_path):
        now_jst = datetime.now(JST)
        recent_date = (now_jst - timedelta(hours=10)).strftime("%Y-%m-%d")
        root = _make_root(tmp_path, {"metrics": [{"date_jst": recent_date, "success": 3}]})
        assert check_metrics_stale(root) == "ok"

    def test_uses_last_metric_entry(self, tmp_path):
        # First entry is stale, last is recent → should be ok
        now_jst = datetime.now(JST)
        old_date = "2020-01-01"
        recent_date = (now_jst - timedelta(hours=5)).strftime("%Y-%m-%d")
        root = _make_root(tmp_path, {
            "metrics": [
                {"date": old_date, "success": 0},
                {"date": recent_date, "success": 10},
            ]
        })
        assert check_metrics_stale(root) == "ok"


# ---------------------------------------------------------------------------
# AC-4: check_ash_done_pending (DONE_MAX_AGE_MIN removed)
# ---------------------------------------------------------------------------

class TestCheckAshDonePending:
    def test_ok_when_no_done_tasks(self, tmp_path):
        root = _make_root(tmp_path, {}, {
            "ashigaru1.yaml": {"task_id": "task_A", "status": "assigned"}
        })
        assert check_ash_done_pending(root) == "ok"

    def test_ok_when_done_recent_under_30min(self, tmp_path):
        root = _make_root(tmp_path, {}, {
            "ashigaru1.yaml": {"task_id": "task_B", "status": "done"}
        })
        # mtime is just set (< 30 min)
        assert check_ash_done_pending(root) == "ok"

    def test_pending_when_done_over_30min(self, tmp_path):
        root = _make_root(tmp_path, {}, {
            "ashigaru1.yaml": {"task_id": "task_C", "status": "done"}
        })
        task_file = os.path.join(root, "queue", "tasks", "ashigaru1.yaml")
        old_time = datetime.now().timestamp() - 45 * 60
        os.utime(task_file, (old_time, old_time))
        result = check_ash_done_pending(root)
        assert result.startswith("PENDING:")
        assert "ashigaru1" in result

    def test_pending_when_done_over_old_max_360min(self, tmp_path):
        """done >= 360min must still be PENDING after DONE_MAX_AGE_MIN removal."""
        root = _make_root(tmp_path, {}, {
            "ashigaru2.yaml": {"task_id": "task_D", "status": "done"}
        })
        task_file = os.path.join(root, "queue", "tasks", "ashigaru2.yaml")
        old_time = datetime.now().timestamp() - 7 * 60 * 60  # 420 min > old 360 limit
        os.utime(task_file, (old_time, old_time))
        result = check_ash_done_pending(root)
        assert result.startswith("PENDING:")
        assert "ashigaru2" in result

    def test_pending_when_completed_pending_karo_over_30min(self, tmp_path):
        root = _make_root(tmp_path, {}, {
            "ashigaru3.yaml": {"task_id": "task_E", "status": "completed_pending_karo"}
        })
        task_file = os.path.join(root, "queue", "tasks", "ashigaru3.yaml")
        old_time = datetime.now().timestamp() - 35 * 60
        os.utime(task_file, (old_time, old_time))
        result = check_ash_done_pending(root)
        assert result.startswith("PENDING:")
        assert "ashigaru3" in result

    def test_ok_when_completed_pending_karo_under_30min(self, tmp_path):
        root = _make_root(tmp_path, {}, {
            "ashigaru4.yaml": {"task_id": "task_F", "status": "completed_pending_karo"}
        })
        assert check_ash_done_pending(root) == "ok"
