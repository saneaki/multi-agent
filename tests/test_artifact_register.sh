#!/usr/bin/env bash
# test_artifact_register.sh — artifact_register.sh 単体テスト (3件)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SCRIPT_DIR}/scripts/artifact_register.sh"

PASS=0
FAIL=0

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local output
    output=$("$@" 2>&1)
    local actual_exit=$?
    if [[ "${actual_exit}" -eq "${expected_exit}" ]]; then
        echo "[PASS] ${name}"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] ${name}: exit=${actual_exit} (expected ${expected_exit})"
        echo "       output: ${output}" | head -5
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
# TC-1: --dry-run で正常終了 (exit 0)
# ============================================================
run_test "test_dry_run_success" 0 \
    bash "${SCRIPT}" \
        --cmd-id cmd_test \
        --project test \
        --date "2026-04-16" \
        --files "${SCRIPT}" \
        --dry-run

# ============================================================
# TC-2: 存在しないファイル指定時に skip される (abort しない / exit 0)
# ============================================================
run_test "test_file_not_found_skip" 0 \
    bash "${SCRIPT}" \
        --cmd-id cmd_test \
        --project test \
        --date "2026-04-16" \
        --files "/nonexistent/path/file_does_not_exist.md" \
        --dry-run

# ============================================================
# TC-3: 必須パラメータ欠如で usage エラー (exit 1)
# ============================================================
run_test "test_required_params_missing" 1 \
    bash "${SCRIPT}" \
        --cmd-id cmd_test

# ============================================================
# TC-4: --help で Usage を表示し exit 0
# ============================================================
run_test "test_help_flag_long"  0 bash "${SCRIPT}" --help
run_test "test_help_flag_short" 0 bash "${SCRIPT}" -h

# ============================================================
# TC-5: --help 出力に主要オプションが含まれる
# ============================================================
help_output=$(bash "${SCRIPT}" --help 2>&1)
if echo "${help_output}" | grep -q -- "--cmd-id" \
    && echo "${help_output}" | grep -q -- "--project" \
    && echo "${help_output}" | grep -q -- "--date" \
    && echo "${help_output}" | grep -q -- "--files" \
    && echo "${help_output}" | grep -q -- "--dry-run"; then
    echo "[PASS] test_help_contents"
    PASS=$((PASS + 1))
else
    echo "[FAIL] test_help_contents: missing expected options"
    FAIL=$((FAIL + 1))
fi

# ============================================================
# 結果
# ============================================================
echo ""
echo "=========================="
echo "Result: ${PASS} passed, ${FAIL} failed"
echo "=========================="

[[ "${FAIL}" -eq 0 ]]
