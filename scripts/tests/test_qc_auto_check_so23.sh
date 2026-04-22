#!/usr/bin/env bash
# ============================================================
# SO-23 Regression Test: qc_auto_check.sh
#
# Purpose:
#   Verify scripts/qc_auto_check.sh emits the correct SO-23
#   disposition for each fixture in tests/qc_auto_check/.
#
# Expected vs actual matching rules (aligned to cmd_557 Scope1):
#   expected: pass  → SO-23 block present, result == pass
#   expected: warn  → SO-23 block present, result == warn
#   expected: fail  → SO-23 block present AND
#                     ( result == fail
#                       OR result == warn with "FAIL" in detail )
#                     (Scope1 uses warn-level with "FAIL" keyword for
#                      empty array; the user-visible semantic is FAIL.)
#   expected: skip  → SO-23 block NOT present (non-n8n + exempt →
#                     qc_auto_check.sh intentionally skips SO-23)
#
# Exit:
#   0  all fixtures produced the expected SO-23 disposition
#   1  at least one fixture diverged
#   2  harness setup error (missing script/fixture directory etc.)
# ============================================================
set -eo pipefail

SHOGUN_ROOT="/home/ubuntu/shogun"
FIXTURE_DIR="${SHOGUN_ROOT}/tests/qc_auto_check"
QC_SCRIPT="${SHOGUN_ROOT}/scripts/qc_auto_check.sh"
TEMP_ID="__so23_fixture_test"
TASK_FILE="${SHOGUN_ROOT}/queue/tasks/${TEMP_ID}.yaml"
REPORT_FILE="${SHOGUN_ROOT}/queue/reports/${TEMP_ID}_report.yaml"

cleanup() {
    rm -f "$TASK_FILE" "$REPORT_FILE"
}
trap cleanup EXIT INT TERM

if [ ! -f "$QC_SCRIPT" ]; then
    echo "ERROR: qc_auto_check.sh not found at $QC_SCRIPT" >&2
    exit 2
fi
if [ ! -d "$FIXTURE_DIR" ]; then
    echo "ERROR: Fixture directory not found at $FIXTURE_DIR" >&2
    exit 2
fi

shopt -s nullglob
FIXTURES=("${FIXTURE_DIR}"/fixture_*.yaml)
shopt -u nullglob
if [ ${#FIXTURES[@]} -eq 0 ]; then
    echo "ERROR: No fixture_*.yaml files in $FIXTURE_DIR" >&2
    exit 2
fi

echo "SO-23 regression: ${#FIXTURES[@]} fixtures"
echo "=============================================="

PASS=0
FAIL=0
FAIL_IDS=""

for fixture in "${FIXTURES[@]}"; do
    fid=$(basename "$fixture" .yaml)

    expected=$(python3 - "$fixture" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f) or {}
print(d.get("expected", "missing"))
PYEOF
)

    python3 - "$fixture" "$TEMP_ID" > "$TASK_FILE" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    fx = yaml.safe_load(f) or {}
temp_id = sys.argv[2]
task = dict(fx.get("task") or {})
task.setdefault("task_id", "subtask_so23test")
task.setdefault("parent_cmd", "cmd_557")
task.setdefault("assigned_to", temp_id)
task.setdefault("report_to", "gunshi")
task.setdefault("status", "done")
sys.stdout.write(yaml.safe_dump(task, sort_keys=False, allow_unicode=True))
PYEOF

    python3 - "$fixture" "$TEMP_ID" > "$REPORT_FILE" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    fx = yaml.safe_load(f) or {}
temp_id = sys.argv[2]
report = dict(fx.get("report") or {})
report.setdefault("worker_id", temp_id)
report.setdefault("task_id", "subtask_so23test")
report.setdefault("parent_cmd", "cmd_557")
report.setdefault("status", "done")
report.setdefault("timestamp", "2026-04-22T00:00:00+09:00")
report.setdefault("result", {"status": "PASS"})
report.setdefault("skill_candidate", {"found": False})
sys.stdout.write(yaml.safe_dump(report, sort_keys=False, allow_unicode=True))
PYEOF

    output=$(bash "$QC_SCRIPT" "$TEMP_ID" subtask_so23test 2>/dev/null || true)

    parsed=$(printf '%s' "$output" | python3 -c '
import sys, yaml
raw = sys.stdin.read()
try:
    data = yaml.safe_load(raw) or {}
except Exception:
    print("PARSE_ERROR||")
    sys.exit(0)
checks = data.get("checks") or []
for c in checks:
    if c.get("id") == "SO-23":
        result = c.get("result", "missing")
        detail = c.get("detail", "")
        print("%s||%s" % (result, detail))
        break
else:
    print("NOT_FOUND||")
')

    result="${parsed%%||*}"
    detail="${parsed#*||}"

    matched="no"
    case "$expected" in
        pass)
            [ "$result" = "pass" ] && matched="yes"
            ;;
        warn)
            [ "$result" = "warn" ] && matched="yes"
            ;;
        fail)
            if [ "$result" = "fail" ]; then
                matched="yes"
            elif [ "$result" = "warn" ] && printf '%s' "$detail" | grep -q "FAIL"; then
                matched="yes"
            fi
            ;;
        skip)
            [ "$result" = "NOT_FOUND" ] && matched="yes"
            ;;
        *)
            matched="no"
            ;;
    esac

    if [ "$matched" = "yes" ]; then
        echo "[PASS] $fid  expected=$expected actual(result=$result)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $fid  expected=$expected actual(result=$result detail=${detail:0:80})"
        FAIL=$((FAIL + 1))
        FAIL_IDS="${FAIL_IDS}${fid} "
    fi

    rm -f "$TASK_FILE" "$REPORT_FILE"
done

echo "=============================================="
echo "summary: ${PASS} pass, ${FAIL} fail"

if [ "$FAIL" -gt 0 ]; then
    echo "failed fixtures: ${FAIL_IDS}"
    exit 1
fi
exit 0
