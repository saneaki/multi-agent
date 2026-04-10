#!/usr/bin/env bash
# ============================================================
# QC Auto Check: Automated T2 rule validation for Gunshi QC
#
# Usage:
#   bash scripts/qc_auto_check.sh <ashigaru_id> <task_id>
#
# Example:
#   bash scripts/qc_auto_check.sh ashigaru1 subtask_350a
#
# Output: YAML-formatted check results to stdout
# ============================================================

set -euo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
ASHIGARU_ID="${1:-}"
TASK_ID="${2:-}"

if [ -z "$ASHIGARU_ID" ] || [ -z "$TASK_ID" ]; then
    echo "Usage: qc_auto_check.sh <ashigaru_id> <task_id>" >&2
    exit 1
fi

REPORT_FILE="${SHOGUN_ROOT}/queue/reports/${ASHIGARU_ID}_report.yaml"
SNAPSHOT_FILE="${SHOGUN_ROOT}/queue/snapshots/${ASHIGARU_ID}_snapshot.yaml"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
RESULTS=""

# Helper: add check result
add_result() {
    local id="$1"
    local result="$2"
    local detail="$3"
    RESULTS="${RESULTS}  - id: ${id}
    result: ${result}
    detail: \"${detail}\"
"
    if [ "$result" = "pass" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$result" = "warn" ]; then
        WARN_COUNT=$((WARN_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# --- SO-01: Required fields in report YAML ---
if [ ! -f "$REPORT_FILE" ]; then
    add_result "SO-01" "fail" "Report file not found: ${REPORT_FILE}"
else
    MISSING=""
    for field in worker_id task_id parent_cmd status timestamp; do
        if ! grep -q "^${field}:" "$REPORT_FILE" 2>/dev/null; then
            MISSING="${MISSING}${field} "
        fi
    done
    # Check nested fields
    if ! grep -q "^result:" "$REPORT_FILE" 2>/dev/null; then
        MISSING="${MISSING}result "
    fi
    if ! grep -q "skill_candidate:" "$REPORT_FILE" 2>/dev/null; then
        MISSING="${MISSING}skill_candidate "
    fi

    if [ -z "$MISSING" ]; then
        add_result "SO-01" "pass" "All required fields present"
    else
        add_result "SO-01" "fail" "Missing fields: ${MISSING}"
    fi
fi

# --- SO-03: JST timestamp format ---
if [ -f "$REPORT_FILE" ]; then
    TIMESTAMP_LINE=$(grep "^timestamp:" "$REPORT_FILE" 2>/dev/null || echo "")
    if [ -z "$TIMESTAMP_LINE" ]; then
        add_result "SO-03" "fail" "No timestamp field found"
    elif echo "$TIMESTAMP_LINE" | grep -q "+09:00"; then
        add_result "SO-03" "pass" "Timestamp is JST format (+09:00)"
    else
        add_result "SO-03" "fail" "Timestamp not in JST format: ${TIMESTAMP_LINE}"
    fi
else
    add_result "SO-03" "fail" "Report file not found"
fi

# --- SO-06: report_to is gunshi ---
TASK_FILE="${SHOGUN_ROOT}/queue/tasks/${ASHIGARU_ID}.yaml"
if [ -f "$TASK_FILE" ]; then
    REPORT_TO=$(grep "report_to:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/.*report_to: *//' | tr -d '"' | tr -d "'" | xargs)
    if [ "$REPORT_TO" = "gunshi" ]; then
        add_result "SO-06" "pass" "report_to is gunshi"
    else
        add_result "SO-06" "fail" "report_to is '${REPORT_TO}', expected 'gunshi'"
    fi
else
    add_result "SO-06" "fail" "Task file not found: ${TASK_FILE}"
fi

# --- SO-19: 🚨 Completed cmd residual check ---
# 履歴:
#  cmd_473: parent_cmd を task YAML のみから読んでいた。task YAML が上書きされた場合に silent fail。
#          多段フォールバック追加 (task→report→task_id推論)。
#  cmd_475 A1: 実 schema は `cmd_id:` を使用することが判明。cmd_id をprimary sourceに追加。
#              これにより task_id 推論フォールバックは通常不要となる (safety netとして残存)。
PARENT_CMD=""
PARENT_CMD_SOURCE=""

# (a) task YAML — parent_cmd または cmd_id (cmd_id が実schema)
if [ -f "$TASK_FILE" ]; then
    PARENT_CMD=$(grep "^parent_cmd:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/.*parent_cmd: *//' | tr -d '"' | tr -d "'" | xargs || true)
    if [ -n "$PARENT_CMD" ]; then
        PARENT_CMD_SOURCE="task_yaml_parent_cmd"
    else
        PARENT_CMD=$(grep "^cmd_id:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/.*cmd_id: *//' | tr -d '"' | tr -d "'" | xargs || true)
        if [ -n "$PARENT_CMD" ]; then
            PARENT_CMD_SOURCE="task_yaml_cmd_id"
        fi
    fi
fi

# (b) report YAML — parent_cmd または cmd_id (task YAML上書き時のフォールバック)
if [ -z "$PARENT_CMD" ] && [ -f "$REPORT_FILE" ]; then
    PARENT_CMD=$(grep "^parent_cmd:" "$REPORT_FILE" 2>/dev/null | head -1 | sed 's/.*parent_cmd: *//' | tr -d '"' | tr -d "'" | xargs || true)
    if [ -n "$PARENT_CMD" ]; then
        PARENT_CMD_SOURCE="report_yaml_parent_cmd"
    else
        PARENT_CMD=$(grep "^cmd_id:" "$REPORT_FILE" 2>/dev/null | head -1 | sed 's/.*cmd_id: *//' | tr -d '"' | tr -d "'" | xargs || true)
        if [ -n "$PARENT_CMD" ]; then
            PARENT_CMD_SOURCE="report_yaml_cmd_id"
        fi
    fi
fi

# (c) safety net: task_id 接頭辞からの推論 (subtask_473_xxx -> cmd_473)
# cmd_475 A1 以降、(a)(b) で通常カバーされるため到達することは稀。
if [ -z "$PARENT_CMD" ]; then
    PARENT_CMD=$(echo "$TASK_ID" | sed -nE 's/^subtask_([0-9]+).*/cmd_\1/p' | head -1 | xargs || true)
    if [ -n "$PARENT_CMD" ]; then
        PARENT_CMD_SOURCE="task_id_inference"
    fi
fi

DASHBOARD_FILE="${SHOGUN_ROOT}/dashboard.md"
if [ -z "$PARENT_CMD" ]; then
    # (d) explicit warning to prohibit silent fail
    add_result "SO-19" "warn" "PARENT_CMD could not be determined from task/report YAML or task_id — SO-19 skipped"
elif [ ! -f "$DASHBOARD_FILE" ]; then
    add_result "SO-19" "warn" "Dashboard file not found — SO-19 skipped for ${PARENT_CMD} (source: ${PARENT_CMD_SOURCE})"
else
    IN_SECTION=false
    SO19_MATCHES=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "^## 🚨"; then
            IN_SECTION=true
            continue
        fi
        if $IN_SECTION && echo "$line" | grep -q "^## "; then
            break
        fi
        if $IN_SECTION && echo "$line" | grep -qi "$PARENT_CMD"; then
            SO19_MATCHES="${SO19_MATCHES}${line} "
        fi
    done < "$DASHBOARD_FILE"
    if [ -n "$SO19_MATCHES" ]; then
        add_result "SO-19" "warn" "🚨 section has items referencing ${PARENT_CMD} — ensure SO-19 cleanup at cmd completion (source: ${PARENT_CMD_SOURCE})"
    else
        add_result "SO-19" "pass" "No 🚨 residual items for ${PARENT_CMD} (source: ${PARENT_CMD_SOURCE})"
    fi
fi

# --- SO-12: Snapshot cleared ---
if [ -f "$SNAPSHOT_FILE" ]; then
    add_result "SO-12" "fail" "Snapshot file still exists (not cleared): ${SNAPSHOT_FILE}"
else
    add_result "SO-12" "pass" "Snapshot cleared (file does not exist)"
fi

# --- check_schema_required_fields: per-field SO-01 WARN output ---
check_schema_required_fields() {
    local report_file="$1"
    local violations=0
    for field in worker_id parent_cmd timestamp result; do
        if ! grep -q "^${field}:" "$report_file" 2>/dev/null; then
            echo "WARN: SO-01 schema violation — missing field: ${field}" >&2
            violations=$((violations + 1))
        fi
    done
    return $violations
}

if [ -f "$REPORT_FILE" ]; then
    check_schema_required_fields "$REPORT_FILE" || true
fi

# --- Output ---
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo "checks:"
echo "$RESULTS"
echo "summary: \"${TOTAL} checks: ${PASS_COUNT} pass, ${FAIL_COUNT} fail, ${WARN_COUNT} warn\""
