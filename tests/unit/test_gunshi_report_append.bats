#!/usr/bin/env bats

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export APPEND_SCRIPT="$PROJECT_ROOT/scripts/gunshi_report_append.sh"
    export SYNC_SCRIPT="$PROJECT_ROOT/scripts/action_required_sync.sh"
}

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "gunshi_report schema has latest and history after migration" {
    run python3 - "$PROJECT_ROOT/queue/reports/gunshi_report.yaml" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as f:
    docs = list(yaml.safe_load_all(f))
assert len(docs) == 1
d = docs[0]
assert d["worker_id"] == "gunshi"
assert isinstance(d["latest"], dict)
assert isinstance(d["history"], list)
assert d["latest"]["task_id"] == "subtask_726f_gunshi_skill_quality_gate"
for task_id in (
    "subtask_723_gunshi_ac11_completion_qc_reconstructed",
    "subtask_725b_gunshi_shp_model_switch_qc_reconstructed",
    "subtask_727b_gunshi_inbox_watcher_silent_failure_qc",
):
    entry = next((x for x in d["history"] if x.get("task_id") == task_id), None)
    assert entry is not None, task_id
    assert entry.get("reconstructed_from")
    assert entry.get("source_evidence")
    assert entry.get("reconstructed_at")
PY
    [ "$status" -eq 0 ]
}

@test "gunshi_report_append updates latest and preserves prior entries in isolated copy" {
    local report="$TEST_TMPDIR/gunshi_report.yaml"
    cp "$PROJECT_ROOT/queue/reports/gunshi_report.yaml" "$report"

    run bash "$APPEND_SCRIPT" --report "$report" --task-id smoke_test_001 --parent-cmd cmd_smoke --status done --verdict go --note "smoke entry"
    [ "$status" -eq 0 ]

    python3 - "$report" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as f:
    d = yaml.safe_load(f)
assert d["latest"]["task_id"] == "smoke_test_001"
assert any(x.get("task_id") == "subtask_726f_gunshi_skill_quality_gate" for x in d["history"])
assert d["history"][-1]["task_id"] == "subtask_726f_gunshi_skill_quality_gate"
PY
}

@test "action_required_sync reads latest candidates and legacy top-level fallback" {
    local dashboard_yaml="$TEST_TMPDIR/dashboard.yaml"
    local dashboard_md="$TEST_TMPDIR/dashboard.md"
    cp "$PROJECT_ROOT/dashboard.yaml" "$dashboard_yaml"
    cp "$PROJECT_ROOT/dashboard.md" "$dashboard_md"

    local latest_report="$TEST_TMPDIR/latest_report.yaml"
    cat > "$latest_report" <<'YAML'
worker_id: gunshi
latest:
  worker_id: gunshi
  task_id: latest_sync_test
  parent_cmd: cmd_sync
  timestamp: "2026-05-15T15:44:32+09:00"
  status: done
  result:
    action_required_candidates:
      - issue_id: test_latest_candidate
        parent_cmd: cmd_sync
        severity: MEDIUM
        summary: latest schema candidate
        details: latest path
        status: open
history: []
YAML

    run env ACTION_REQUIRED_DASHBOARD_YAML="$dashboard_yaml" ACTION_REQUIRED_DASHBOARD_MD="$dashboard_md" ACTION_REQUIRED_NOTIFY_SCRIPT=/bin/true bash "$SYNC_SCRIPT" "$latest_report"
    [ "$status" -eq 0 ]
    grep -q "test_latest_candidate" "$dashboard_yaml"

    local legacy_report="$TEST_TMPDIR/legacy_report.yaml"
    cat > "$legacy_report" <<'YAML'
worker_id: gunshi
task_id: legacy_sync_test
parent_cmd: cmd_sync
timestamp: "2026-05-15T15:44:32+09:00"
status: done
result:
  action_required_candidates:
    - issue_id: test_legacy_candidate
      parent_cmd: cmd_sync
      severity: INFO
      summary: legacy schema candidate
      details: legacy path
      status: open
YAML

    run env ACTION_REQUIRED_DASHBOARD_YAML="$dashboard_yaml" ACTION_REQUIRED_DASHBOARD_MD="$dashboard_md" ACTION_REQUIRED_NOTIFY_SCRIPT=/bin/true bash "$SYNC_SCRIPT" "$legacy_report"
    [ "$status" -eq 0 ]
    grep -q "test_legacy_candidate" "$dashboard_yaml"
}
