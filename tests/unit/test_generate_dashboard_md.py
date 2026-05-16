"""
Unit tests for generate_dashboard_md.py — cmd_731 β-2
AC-7: L019/L020/Step1.5 実測値生成 + VIOLATION marker 対応
AC-8: METRICS marker 対応 + partial mode 更新
"""
from __future__ import annotations

import datetime
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest
import yaml

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../scripts"))

import generate_dashboard_md as gdm


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _make_dashboard_yaml(tmp_path: Path, data: dict) -> Path:
    p = tmp_path / "dashboard.yaml"
    with open(p, "w", encoding="utf-8") as f:
        yaml.dump(data, f, allow_unicode=True)
    return p


def _make_dashboard_md(tmp_path: Path, content: str) -> Path:
    p = tmp_path / "dashboard.md"
    p.write_text(content, encoding="utf-8")
    return p


MINIMAL_MD_WITH_ALL_MARKERS = """\
# 📊 戦況報告
<!-- ACTION_REQUIRED:START -->
## 🚨 要対応
| タグ | 項目 | 詳細 |
|---|---|---|
| （まだなし） | | |

<!-- ACTION_REQUIRED:END -->
<!-- OBSERVATION_QUEUE:START -->
## ⏳ 時間経過待ち / 観察継続
| タグ | 項目 | 詳細 |
|---|---|---|
| （まだなし） | | |

<!-- OBSERVATION_QUEUE:END -->
<!-- VIOLATION:START -->
## ⚠️ 違反検出 (last 24h)
| tag | count | last_seen | recommended_action |
|---|---|---|---|
| L019-skip | 0 | — | — |
| L020-stale | 0 | — | — |
| Step1.5-skip | ? | — | shogun_session_start.sh 実行 |

<!-- VIOLATION:END -->
<!-- METRICS:START -->
## 📊 運用指標
| 日付(JST) | 成功 | 失敗(cron) | karo auto-compact | gunshi auto-compact | safe_window発動 | karo self_clear | gunshi self_clear | karo self_compact | gunshi self_compact |
|---|---|---|---|---|---|---|---|---|---|
| 2026-05-08 | 43 | 0 | 5 | 0 | 110 | 55 | 117 | 0 | 0 |

<!-- METRICS:END -->
"""

MINIMAL_YAML_DATA = {
    "metadata": {"last_updated": "2026-05-16 10:00 JST"},
    "action_required": [],
    "observation_queue": [],
    "metrics": [
        {
            "date": "2026-05-08",
            "success": 43, "failure": 0,
            "karo_compact": 5, "gunshi_compact": 0,
            "safe_window": 110,
            "karo_self_clear": 55, "gunshi_self_clear": 117,
            "karo_self_compact": 0, "gunshi_self_compact": 0,
        }
    ],
}


# ---------------------------------------------------------------------------
# AC-7: L020 ISO/JST format handling
# ---------------------------------------------------------------------------

class TestCollectViolationsL020:

    def _run(self, last_updated: str, now_jst: datetime.datetime):
        """Run collect_violations with mocked now_jst."""
        with patch("generate_dashboard_md.datetime") as mock_dt:
            mock_dt.datetime.now.return_value = now_jst - datetime.timedelta(hours=9)
            mock_dt.datetime.strptime.side_effect = datetime.datetime.strptime
            mock_dt.timedelta = datetime.timedelta
            # subprocess.run for L019 — mock it to return empty
            with patch("generate_dashboard_md.subprocess.run") as mock_run:
                mock_run.return_value.returncode = 0
                mock_run.return_value.stdout = ""
                rows = gdm.collect_violations(Path("."), last_updated)
        return {tag: (count, last_seen, action) for tag, count, last_seen, action in rows}

    def test_l020_jst_format_fresh(self):
        """JST format (YYYY-MM-DD HH:MM JST) — fresh dashboard → count=0."""
        now_jst = datetime.datetime(2026, 5, 16, 11, 0)  # 11:00 JST
        last_updated = "2026-05-16 10:30 JST"           # 30 min ago in JST
        rows = self._run(last_updated, now_jst)
        assert rows["L020-stale"][0] == "0"

    def test_l020_jst_format_stale(self):
        """JST format — stale dashboard (>4h) → count=1."""
        now_jst = datetime.datetime(2026, 5, 16, 16, 0)  # 16:00 JST
        last_updated = "2026-05-16 10:00 JST"            # 6h ago
        rows = self._run(last_updated, now_jst)
        assert rows["L020-stale"][0] == "1"
        assert rows["L020-stale"][1] == "2026-05-16 10:00"

    def test_l020_iso_format_fresh(self):
        """ISO format (YYYY-MM-DDTHH:MM:SS+09:00) — fresh → count=0."""
        now_jst = datetime.datetime(2026, 5, 16, 11, 0)
        last_updated = "2026-05-16T10:30:00+09:00"
        rows = self._run(last_updated, now_jst)
        assert rows["L020-stale"][0] == "0"

    def test_l020_iso_format_stale(self):
        """ISO format — stale (>4h) → count=1."""
        now_jst = datetime.datetime(2026, 5, 16, 16, 0)
        last_updated = "2026-05-16T10:01:56+09:00"
        rows = self._run(last_updated, now_jst)
        assert rows["L020-stale"][0] == "1"

    def test_l020_invalid_format_returns_dash(self):
        """Unparseable last_updated → '—' (no crash)."""
        now_jst = datetime.datetime(2026, 5, 16, 12, 0)
        rows = self._run("INVALID_DATE", now_jst)
        assert rows["L020-stale"][0] == "—"

    def test_l020_boundary_exactly_4h(self):
        """Exactly 240 min → NOT stale (> 240 required)."""
        now_jst = datetime.datetime(2026, 5, 16, 14, 0)
        last_updated = "2026-05-16 10:00 JST"  # exactly 240 min
        rows = self._run(last_updated, now_jst)
        assert rows["L020-stale"][0] == "0"


# ---------------------------------------------------------------------------
# AC-7: L019 git log analysis
# ---------------------------------------------------------------------------

class TestCollectViolationsL019:

    def test_l019_uses_git_log(self):
        """L019 calls git log on shogun inbox, returns commit count as string."""
        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = "fix: inbox update\nfeat: add message\n"
            with patch("generate_dashboard_md.datetime") as mock_dt:
                mock_dt.datetime.now.return_value = datetime.datetime(2026, 5, 16, 2, 0)
                mock_dt.datetime.strptime.side_effect = datetime.datetime.strptime
                mock_dt.timedelta = datetime.timedelta
                rows = gdm.collect_violations(Path("."), "2026-05-16 10:00 JST")
        row_map = {tag: count for tag, count, _, _ in rows}
        assert row_map["L019-skip"] == "2"

    def test_l019_git_failure_returns_question_mark(self):
        """If git fails, L019 returns '?' (no crash)."""
        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.side_effect = Exception("git not found")
            with patch("generate_dashboard_md.datetime") as mock_dt:
                mock_dt.datetime.now.return_value = datetime.datetime(2026, 5, 16, 2, 0)
                mock_dt.datetime.strptime.side_effect = datetime.datetime.strptime
                mock_dt.timedelta = datetime.timedelta
                rows = gdm.collect_violations(Path("."), "2026-05-16 10:00 JST")
        row_map = {tag: count for tag, count, _, _ in rows}
        assert row_map["L019-skip"] == "?"

    def test_l019_empty_git_returns_zero(self):
        """No commits in last 24h → '0'."""
        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""
            with patch("generate_dashboard_md.datetime") as mock_dt:
                mock_dt.datetime.now.return_value = datetime.datetime(2026, 5, 16, 2, 0)
                mock_dt.datetime.strptime.side_effect = datetime.datetime.strptime
                mock_dt.timedelta = datetime.timedelta
                rows = gdm.collect_violations(Path("."), "2026-05-16 10:00 JST")
        row_map = {tag: count for tag, count, _, _ in rows}
        assert row_map["L019-skip"] == "0"


# ---------------------------------------------------------------------------
# AC-8: render_metrics_section
# ---------------------------------------------------------------------------

class TestRenderMetricsSection:

    def test_renders_table_headers(self):
        result = gdm.render_metrics_section([])
        assert "## 📊 運用指標" in result
        assert "日付(JST)" in result
        assert "成功" in result
        assert "karo auto-compact" in result

    def test_renders_metrics_rows(self):
        metrics = [
            {
                "date": "2026-05-15",
                "success": 22, "failure": 0,
                "karo_compact": 1, "gunshi_compact": 0,
                "safe_window": 5,
                "karo_self_clear": 3, "gunshi_self_clear": 2,
                "karo_self_compact": 0, "gunshi_self_compact": 0,
            }
        ]
        result = gdm.render_metrics_section(metrics)
        assert "2026-05-15" in result
        assert "22" in result
        assert "| 2026-05-15 |" in result

    def test_renders_multiple_rows(self):
        metrics = [
            {"date": f"2026-05-{d:02d}", "success": d, "failure": 0,
             "karo_compact": 0, "gunshi_compact": 0, "safe_window": 0,
             "karo_self_clear": 0, "gunshi_self_clear": 0,
             "karo_self_compact": 0, "gunshi_self_compact": 0}
            for d in range(10, 17)
        ]
        result = gdm.render_metrics_section(metrics)
        assert "2026-05-10" in result
        assert "2026-05-16" in result

    def test_empty_metrics(self):
        result = gdm.render_metrics_section([])
        assert "## 📊 運用指標" in result
        # Should not crash with empty list

    def test_returns_string(self):
        result = gdm.render_metrics_section([])
        assert isinstance(result, str)


# ---------------------------------------------------------------------------
# AC-7: render_violation_section
# ---------------------------------------------------------------------------

class TestRenderViolationSection:

    def test_renders_header(self):
        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""
            result = gdm.render_violation_section("2026-05-16 10:00 JST")
        assert "## ⚠️ 違反検出 (last 24h)" in result
        assert "L019-skip" in result
        assert "L020-stale" in result
        assert "Step1.5-skip" in result

    def test_returns_string(self):
        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""
            result = gdm.render_violation_section("2026-05-16 10:00 JST")
        assert isinstance(result, str)


# ---------------------------------------------------------------------------
# AC-8: partial mode updates VIOLATION and METRICS sections
# ---------------------------------------------------------------------------

class TestPartialModeViolationMetricsUpdate:

    def _run_partial(self, tmp_path: Path, md_content: str, yaml_data: dict) -> str:
        """Run generate_dashboard_md in partial mode and return resulting md."""
        md_path = _make_dashboard_md(tmp_path, md_content)
        yaml_path = _make_dashboard_yaml(tmp_path, yaml_data)

        with patch("generate_dashboard_md.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = ""
            import sys as _sys
            old_argv = _sys.argv
            _sys.argv = [
                "generate_dashboard_md.py",
                "--input", str(yaml_path),
                "--output", str(md_path),
                "--mode", "partial",
            ]
            try:
                gdm.main()
            except SystemExit:
                pass
            finally:
                _sys.argv = old_argv

        return md_path.read_text(encoding="utf-8")

    def test_partial_updates_metrics_section(self, tmp_path):
        """partial mode updates METRICS section when markers exist."""
        yaml_data = {
            **MINIMAL_YAML_DATA,
            "metrics": [
                {
                    "date": "2026-05-15",
                    "success": 22, "failure": 1,
                    "karo_compact": 2, "gunshi_compact": 0,
                    "safe_window": 3,
                    "karo_self_clear": 1, "gunshi_self_clear": 0,
                    "karo_self_compact": 0, "gunshi_self_compact": 0,
                }
            ],
        }
        result = self._run_partial(tmp_path, MINIMAL_MD_WITH_ALL_MARKERS, yaml_data)
        assert "2026-05-15" in result
        assert "22" in result

    def test_partial_updates_violation_section(self, tmp_path):
        """partial mode updates VIOLATION section when markers exist."""
        yaml_data = {
            **MINIMAL_YAML_DATA,
            "metadata": {"last_updated": "2026-05-16 10:00 JST"},
        }
        result = self._run_partial(tmp_path, MINIMAL_MD_WITH_ALL_MARKERS, yaml_data)
        assert "<!-- VIOLATION:START -->" in result
        assert "<!-- VIOLATION:END -->" in result
        assert "L019-skip" in result
        assert "L020-stale" in result

    def test_partial_preserves_action_required_and_obs_queue(self, tmp_path):
        """partial mode must not destroy other managed sections."""
        md_with_ar = MINIMAL_MD_WITH_ALL_MARKERS.replace(
            "| （まだなし） | | |",
            "| ⚠️ HIGH [action-1] [test] | Test item | Test detail |",
        )
        result = self._run_partial(tmp_path, md_with_ar, MINIMAL_YAML_DATA)
        assert "<!-- ACTION_REQUIRED:START -->" in result
        assert "<!-- OBSERVATION_QUEUE:START -->" in result

    def test_partial_no_violation_markers_skips_gracefully(self, tmp_path):
        """partial mode without VIOLATION markers does not fail or insert violation."""
        md_no_violation = MINIMAL_MD_WITH_ALL_MARKERS.replace(
            "<!-- VIOLATION:START -->", ""
        ).replace("<!-- VIOLATION:END -->", "")
        result = self._run_partial(tmp_path, md_no_violation, MINIMAL_YAML_DATA)
        # Should not crash and should not introduce stray markers
        assert "<!-- METRICS:START -->" in result

    def test_partial_no_metrics_markers_skips_gracefully(self, tmp_path):
        """partial mode without METRICS markers does not fail."""
        md_no_metrics = MINIMAL_MD_WITH_ALL_MARKERS.replace(
            "<!-- METRICS:START -->", ""
        ).replace("<!-- METRICS:END -->", "")
        result = self._run_partial(tmp_path, md_no_metrics, MINIMAL_YAML_DATA)
        assert "<!-- VIOLATION:START -->" in result


# ---------------------------------------------------------------------------
# AC-7/8: marker constants exist and are correct
# ---------------------------------------------------------------------------

class TestMarkerConstants:

    def test_violation_markers_defined(self):
        assert gdm.VIOLATION_START == "<!-- VIOLATION:START -->"
        assert gdm.VIOLATION_END == "<!-- VIOLATION:END -->"

    def test_metrics_markers_defined(self):
        assert gdm.METRICS_START == "<!-- METRICS:START -->"
        assert gdm.METRICS_END == "<!-- METRICS:END -->"

    def test_all_existing_markers_still_defined(self):
        assert gdm.ACTION_REQUIRED_START
        assert gdm.ACTION_REQUIRED_END
        assert gdm.OBSERVATION_QUEUE_START
        assert gdm.OBSERVATION_QUEUE_END
