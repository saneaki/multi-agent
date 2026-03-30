#!/usr/bin/env bats
# test_ir1_editable_files.bats — IR-1 editable_files whitelist hook tests
#
# Tests the PostToolUse IR-1 hook that enforces editable_files whitelist
# for ashigaru agents. Uses env var overrides for testability.
#
# Test matrix:
#   T-IR1-001: Non-ashigaru agent (karo) is exempt
#   T-IR1-002: Non-ashigaru agent (gunshi) is exempt
#   T-IR1-003: Non-ashigaru agent (shogun) is exempt
#   T-IR1-004: Unknown agent (empty) is exempt
#   T-IR1-005: Ashigaru editing file in editable_files whitelist → allowed
#   T-IR1-006: Ashigaru editing file NOT in whitelist → violation logged
#   T-IR1-007: Ashigaru editing own report YAML → implicitly allowed
#   T-IR1-008: Ashigaru editing own task YAML → implicitly allowed
#   T-IR1-009: editable_files field missing → warning, no block
#   T-IR1-010: Glob pattern matching works (e.g., scripts/hooks/*.sh)
#   T-IR1-011: Empty file_path in input → skip (exit 0)
#   T-IR1-012: Task YAML file missing → warning, no block

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/scripts/hooks/ir1_editable_files_check.sh"

setup() {
    TEST_TMP="$(mktemp -d)"
    mkdir -p "$TEST_TMP/queue/tasks"
    mkdir -p "$TEST_TMP/queue/reports"
    mkdir -p "$TEST_TMP/scripts"

    # Mock log_violation.sh — logs arguments to file
    cat > "$TEST_TMP/scripts/log_violation.sh" << 'MOCK'
#!/bin/bash
echo "$@" >> "$__IR1_SHOGUN_ROOT/violation_calls.log"
MOCK
    chmod +x "$TEST_TMP/scripts/log_violation.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# Helper: create task YAML with editable_files
create_task_yaml() {
    local agent_id="$1"
    shift
    local yaml_file="$TEST_TMP/queue/tasks/${agent_id}.yaml"

    cat > "$yaml_file" << YAML
task:
  task_id: test_task
  status: assigned
YAML

    if [ "$#" -gt 0 ]; then
        echo "  editable_files:" >> "$yaml_file"
        for pattern in "$@"; do
            echo "    - \"$pattern\"" >> "$yaml_file"
        done
    fi
}

# Helper: run hook with test overrides
run_hook() {
    local json="$1"
    local agent_id="${2:-ashigaru1}"
    __IR1_AGENT_ID="$agent_id" \
    __IR1_SHOGUN_ROOT="$TEST_TMP" \
    __IR1_LOG_SCRIPT="$TEST_TMP/scripts/log_violation.sh" \
    run bash "$HOOK_SCRIPT" <<< "$json"
}

# Helper: build tool input JSON
make_input() {
    local file_path="$1"
    echo "{\"tool_input\":{\"file_path\":\"$file_path\"}}"
}

@test "T-IR1-001: karo agent is exempt from editable_files check" {
    run_hook "$(make_input "$TEST_TMP/dashboard.md")" "karo"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-002: gunshi agent is exempt from editable_files check" {
    run_hook "$(make_input "$TEST_TMP/queue/tasks/ashigaru1.yaml")" "gunshi"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-003: shogun agent is exempt from editable_files check" {
    run_hook "$(make_input "$TEST_TMP/CLAUDE.md")" "shogun"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-004: unknown agent (empty) is exempt" {
    run_hook "$(make_input "$TEST_TMP/some_file.md")" ""
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-005: ashigaru editing file in editable_files whitelist is allowed" {
    create_task_yaml "ashigaru1" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/scripts/hooks/ir1_check.sh")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-006: ashigaru editing file NOT in whitelist triggers violation" {
    create_task_yaml "ashigaru1" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/dashboard.md")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "IR-1" "$TEST_TMP/violation_calls.log"
    grep -q "ashigaru1" "$TEST_TMP/violation_calls.log"
    grep -q "dashboard.md" "$TEST_TMP/violation_calls.log"
}

@test "T-IR1-007: ashigaru editing own report YAML is implicitly allowed" {
    create_task_yaml "ashigaru3" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/queue/reports/ashigaru3_report.yaml")" "ashigaru3"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-008: ashigaru editing own task YAML is implicitly allowed" {
    create_task_yaml "ashigaru5" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/queue/tasks/ashigaru5.yaml")" "ashigaru5"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-009: editable_files field missing logs warning but does not block" {
    create_task_yaml "ashigaru1"
    run_hook "$(make_input "$TEST_TMP/some_random_file.md")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-010: glob pattern matching works for nested paths" {
    create_task_yaml "ashigaru2" "tests/unit/*.bats" "scripts/*.sh"
    run_hook "$(make_input "$TEST_TMP/tests/unit/test_ir1.bats")" "ashigaru2"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-011: empty file_path in input skips check" {
    create_task_yaml "ashigaru1" "scripts/*.sh"
    run_hook '{"tool_input":{"file_path":""}}' "ashigaru1"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-012: task YAML file missing logs warning but does not block" {
    # Do NOT create task YAML
    run_hook "$(make_input "$TEST_TMP/some_file.md")" "ashigaru7"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-013: ashigaru editing own inbox YAML is implicitly allowed" {
    create_task_yaml "ashigaru2" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/queue/inbox/ashigaru2.yaml")" "ashigaru2"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-014: ashigaru editing OTHER agent inbox YAML triggers violation" {
    create_task_yaml "ashigaru1" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/queue/inbox/ashigaru3.yaml")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "IR-1" "$TEST_TMP/violation_calls.log"
}

@test "T-IR1-015: ashigaru editing skill SKILL.md is implicitly allowed" {
    create_task_yaml "ashigaru3" "scripts/hooks/*.sh"
    run_hook "$(make_input "/home/ubuntu/.claude/skills/shogun-n8n-filesystem-v2-binary/SKILL.md")" "ashigaru3"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-016: ashigaru editing non-SKILL.md in skills dir triggers violation" {
    create_task_yaml "ashigaru1" "scripts/hooks/*.sh"
    run_hook "$(make_input "/home/ubuntu/.claude/skills/some-skill/README.md")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "IR-1" "$TEST_TMP/violation_calls.log"
}

@test "T-IR1-017: target_path in task YAML allows editing that file" {
    local agent_id="ashigaru4"
    local yaml_file="$TEST_TMP/queue/tasks/${agent_id}.yaml"
    cat > "$yaml_file" << YAML
task:
  task_id: test_task_tp
  status: assigned
  target_path: "context/some_project.md"
  editable_files:
    - "scripts/*.sh"
YAML
    run_hook "$(make_input "$TEST_TMP/context/some_project.md")" "$agent_id"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-018: target_path directory allows editing files under it" {
    local agent_id="ashigaru6"
    local yaml_file="$TEST_TMP/queue/tasks/${agent_id}.yaml"
    mkdir -p "$TEST_TMP/projects/myproject"
    cat > "$yaml_file" << YAML
task:
  task_id: test_task_dir
  status: assigned
  target_path: "$TEST_TMP/projects/myproject"
  editable_files:
    - "scripts/*.sh"
YAML
    run_hook "$(make_input "$TEST_TMP/projects/myproject/main.py")" "$agent_id"
    [ "$status" -eq 0 ]
    [ ! -f "$TEST_TMP/violation_calls.log" ]
}

@test "T-IR1-020: violation log includes cmd_id from task YAML" {
    local agent_id="ashigaru1"
    local yaml_file="$TEST_TMP/queue/tasks/${agent_id}.yaml"
    cat > "$yaml_file" << YAML
task:
  task_id: subtask_381a
  parent_cmd: cmd_381
  status: assigned
  editable_files:
    - "scripts/hooks/*.sh"
YAML
    run_hook "$(make_input "$TEST_TMP/dashboard.md")" "$agent_id"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "cmd_381/subtask_381a" "$TEST_TMP/violation_calls.log"
}

@test "T-IR1-021: violation log shows unknown when task YAML has no parent_cmd or task_id" {
    local agent_id="ashigaru2"
    local yaml_file="$TEST_TMP/queue/tasks/${agent_id}.yaml"
    cat > "$yaml_file" << YAML
task:
  status: assigned
  editable_files:
    - "scripts/hooks/*.sh"
YAML
    run_hook "$(make_input "$TEST_TMP/dashboard.md")" "$agent_id"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "unknown" "$TEST_TMP/violation_calls.log"
}

@test "T-IR1-022: log_violation.sh accepts cmd_id as 4th argument" {
    # Direct test: log_violation.sh with 4 args writes to daily log with cmd_id column
    run bash "$SCRIPT_DIR/scripts/log_violation.sh" "IR-1" "ashigaru1" "test detail" "cmd_381/subtask_381a"
    [ "$status" -eq 0 ]
    [[ "$output" == *"violation logged"* ]]
}

@test "T-IR1-023: log_violation.sh without cmd_id still works (backward compat)" {
    # Backward compatibility: 3 args still accepted
    run bash "$SCRIPT_DIR/scripts/log_violation.sh" "IR-1" "ashigaru1" "test detail no cmd"
    [ "$status" -eq 0 ]
    [[ "$output" == *"violation logged"* ]]
}

@test "T-IR1-019: existing block targets still trigger violation" {
    create_task_yaml "ashigaru1" "scripts/hooks/*.sh"
    run_hook "$(make_input "$TEST_TMP/instructions/shogun.md")" "ashigaru1"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMP/violation_calls.log" ]
    grep -q "IR-1" "$TEST_TMP/violation_calls.log"
}
