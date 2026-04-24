#!/usr/bin/env bash
# SO-24 Verification Before Report — three-point check
# Usage: bash scripts/so24_verify.sh --ashigaru N --task-id <task_id>
# Output: PASS (3/3) / PARTIAL (2/3) / FAIL (0-1/3)
#
# Three checks:
#   1. inbox:    karo inbox has task_completed from ashigaru{N}
#   2. artifact: queue/reports/ashigaru{N}_report.yaml exists, status: done
#   3. content:  a task_completed message from ashigaru{N} references the task_id in content

set -euo pipefail

ASHIGARU_N=""
TASK_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ashigaru) ASHIGARU_N="$2"; shift 2 ;;
    --task-id)  TASK_ID="$2";    shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ASHIGARU_N" || -z "$TASK_ID" ]]; then
  echo "Usage: $0 --ashigaru N --task-id <task_id>" >&2
  exit 1
fi

AGENT_ID="ashigaru${ASHIGARU_N}"
INBOX_FILE="queue/inbox/karo.yaml"
REPORT_FILE="queue/reports/${AGENT_ID}_report.yaml"

PASS=0
DETAILS=()

# Check 1: inbox check — karo inbox has task_completed from ashigaru{N}
echo "[1] inbox check: ${AGENT_ID} → karo (type: task_completed)"
INBOX_COUNT=$(python3 - <<PYEOF
import yaml, sys
try:
    with open("${INBOX_FILE}") as f:
        data = yaml.safe_load(f)
    msgs = [m for m in data.get("messages", [])
            if m.get("from") == "${AGENT_ID}" and m.get("type") == "task_completed"]
    print(len(msgs))
except Exception as e:
    print(0)
PYEOF
)

if [[ "$INBOX_COUNT" -gt 0 ]]; then
  echo "    ✅ PASS — ${INBOX_COUNT} task_completed message(s) from ${AGENT_ID}"
  PASS=$((PASS + 1))
else
  echo "    ❌ FAIL — no task_completed from ${AGENT_ID} in karo inbox"
  DETAILS+=("inbox: no task_completed from ${AGENT_ID}")
fi

# Check 2: artifact check — report YAML exists and status: done
echo "[2] artifact check: ${REPORT_FILE}"
if [[ -f "$REPORT_FILE" ]]; then
  STATUS=$(grep "^status:" "$REPORT_FILE" | head -1 | sed 's/^status: *//' | tr -d '"')
  if [[ "$STATUS" == "done" ]]; then
    echo "    ✅ PASS — report exists, status: done"
    PASS=$((PASS + 1))
  else
    echo "    ❌ FAIL — report status is '${STATUS}' (expected: done)"
    DETAILS+=("artifact: status '${STATUS}' != 'done'")
  fi
else
  echo "    ❌ FAIL — report not found: ${REPORT_FILE}"
  DETAILS+=("artifact: ${REPORT_FILE} not found")
fi

# Check 3: content check — task_completed message references task_id in content
echo "[3] content check: task_completed message references '${TASK_ID}'"
CONTENT_COUNT=$(python3 - <<PYEOF
import yaml, sys
try:
    with open("${INBOX_FILE}") as f:
        data = yaml.safe_load(f)
    msgs = [m for m in data.get("messages", [])
            if m.get("from") == "${AGENT_ID}"
            and m.get("type") == "task_completed"
            and "${TASK_ID}" in str(m.get("content", ""))]
    print(len(msgs))
except Exception as e:
    print(0)
PYEOF
)

if [[ "$CONTENT_COUNT" -gt 0 ]]; then
  echo "    ✅ PASS — completion message references '${TASK_ID}'"
  PASS=$((PASS + 1))
else
  echo "    ❌ FAIL — no task_completed from ${AGENT_ID} mentions '${TASK_ID}'"
  DETAILS+=("content: no message from ${AGENT_ID} references '${TASK_ID}'")
fi

# Summary
echo ""
TOTAL=3
if [[ $PASS -eq 3 ]]; then
  VERDICT="PASS"
elif [[ $PASS -ge 2 ]]; then
  VERDICT="PARTIAL"
else
  VERDICT="FAIL"
fi

echo "=== SO-24 Verification: ${VERDICT} (${PASS}/${TOTAL}) ==="
if [[ ${#DETAILS[@]} -gt 0 ]]; then
  echo "Failures:"
  for d in "${DETAILS[@]}"; do
    echo "  - $d"
  done
fi

[[ "$VERDICT" == "PASS" ]]
