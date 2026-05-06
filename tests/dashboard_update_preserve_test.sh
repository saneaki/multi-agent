#!/bin/bash
# tests/dashboard_update_preserve_test.sh
# cmd_649 Scope C: update_dashboard.sh が ✅戦果 / 🚨要対応 / 🐸Frog 等の
# 「家老の手書きセクション」を保持しつつ、🔄進行中 / 🏯待機中 / 最終更新 / 📊運用指標
# のみを部分置換することを検証する。
#
# Usage: bash tests/dashboard_update_preserve_test.sh
# Exit: 0=PASS / non-zero=FAIL
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$REPO_DIR/dashboard.md"
DASHBOARD_YAML="$REPO_DIR/dashboard.yaml"
SCRIPT="$REPO_DIR/scripts/update_dashboard.sh"

# Test sentinels — should survive update_dashboard.sh
SENTINEL_BATTLE="🏆 cmd_TEST_649 partial-replace test sentinel — DO NOT REMOVE 🏆"
SENTINEL_ACTION="[TEST-649] dashboard preserve test sentinel — DO NOT REMOVE"
SENTINEL_FROG="TEST-649-FROG-SENTINEL-DO-NOT-REMOVE"

PASS=0
FAIL=0
FAIL_DETAILS=()

assert_contains() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$DASHBOARD"; then
    PASS=$((PASS+1))
    echo "  PASS  $label"
  else
    FAIL=$((FAIL+1))
    FAIL_DETAILS+=("$label : '$needle' not found in dashboard.md")
    echo "  FAIL  $label"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2"
  if grep -qF -- "$needle" "$DASHBOARD"; then
    FAIL=$((FAIL+1))
    FAIL_DETAILS+=("$label : '$needle' unexpectedly found in dashboard.md")
    echo "  FAIL  $label"
  else
    PASS=$((PASS+1))
    echo "  PASS  $label"
  fi
}

# 0. preflight
[ -x "$SCRIPT" ] || { echo "SKIP: $SCRIPT not executable"; exit 2; }
[ -f "$DASHBOARD" ] || { echo "SKIP: $DASHBOARD missing"; exit 2; }

# 1. backup originals
BACKUP_MD=$(mktemp)
BACKUP_YAML=$(mktemp)
cp "$DASHBOARD" "$BACKUP_MD"
cp "$DASHBOARD_YAML" "$BACKUP_YAML"
trap 'cp "$BACKUP_MD" "$DASHBOARD"; cp "$BACKUP_YAML" "$DASHBOARD_YAML"; rm -f "$BACKUP_MD" "$BACKUP_YAML"' EXIT

echo "=== Phase 1: inject sentinels ==="
# inject sentinels into preservable sections
python3 - "$DASHBOARD" "$SENTINEL_BATTLE" "$SENTINEL_ACTION" "$SENTINEL_FROG" <<'PYEOF'
import re, sys
path, sb, sa, sf = sys.argv[1:5]
content = open(path).read()

# Insert into ✅本日の戦果 (after the table header line ending in "|---")
content = re.sub(
    r"(## ✅ 本日の戦果.*?\n\| 時刻 \| 戦場 \| 任務 \| 結果 \|\n\|---\|---\|---\|---\|\n)",
    r"\1| 99:99 | TEST | " + sb + r" | ✅ |\n",
    content, count=1, flags=re.DOTALL,
)
# Insert into 🚨 要対応 (after table header)
content = re.sub(
    r"(## 🚨 要対応.*?\n\| タグ \| 項目 \| 詳細 \|\n\|---\|---\|---\|\n)",
    r"\1| [TEST-649] | " + sa + r" | sentinel detail |\n",
    content, count=1, flags=re.DOTALL,
)
# Insert into 🐸 Frog (replace 今日のFrog cell)
content = re.sub(
    r"(\| 今日のFrog \| )([^|]*)(\|)",
    lambda m: m.group(1) + sf + " " + m.group(3),
    content, count=1,
)
open(path, "w").write(content)
PYEOF

# verify sentinels are present
assert_contains "sentinel_battle injected" "$SENTINEL_BATTLE"
assert_contains "sentinel_action injected" "$SENTINEL_ACTION"
assert_contains "sentinel_frog injected"  "$SENTINEL_FROG"

echo ""
echo "=== Phase 2: run update_dashboard.sh ==="
if ! bash "$SCRIPT" >/tmp/cmd_649_test_run.log 2>&1; then
  echo "  FAIL  update_dashboard.sh exited non-zero"
  cat /tmp/cmd_649_test_run.log
  exit 1
fi
echo "  ran successfully"
cat /tmp/cmd_649_test_run.log

echo ""
echo "=== Phase 3: AC A-2 — sentinels preserved ==="
assert_contains "AC_A2_battle"  "$SENTINEL_BATTLE"
assert_contains "AC_A2_action"  "$SENTINEL_ACTION"
assert_contains "AC_A2_frog"    "$SENTINEL_FROG"

echo ""
echo "=== Phase 4: AC A-3 — last_updated refreshed ==="
NOW=$(bash "$REPO_DIR/scripts/jst_now.sh" 2>/dev/null | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' || date "+%Y-%m-%d %H:%M")
assert_contains "AC_A3_last_updated" "最終更新: $NOW JST"

echo ""
echo "=== Phase 5: AC A-1 — generate_dashboard_md.py NOT invoked ==="
# strip shell comments + python comments before grepping for actual invocation patterns
NONCOMMENT=$(sed -E 's/^[[:space:]]*#.*$//; s/[[:space:]]+#.*$//' "$SCRIPT")
if echo "$NONCOMMENT" | grep -qE "(subprocess\.run.*generate_dashboard|python3[[:space:]]+(scripts/)?generate_dashboard_md\.py|bash[[:space:]]+(scripts/)?generate_dashboard_md\.py)"; then
  FAIL=$((FAIL+1))
  FAIL_DETAILS+=("AC_A1: update_dashboard.sh still invokes generate_dashboard_md.py")
  echo "  FAIL  AC_A1_no_generate_call"
else
  PASS=$((PASS+1))
  echo "  PASS  AC_A1_no_generate_call"
fi

echo ""
echo "=== Phase 6: AC B-1/B-2 — nested YAML parsed ==="
# 🔄 progress section should reflect at least one task or empty placeholder
if grep -qE "^## 🔄 進行中" "$DASHBOARD"; then
  PASS=$((PASS+1))
  echo "  PASS  AC_B1_in_progress_section_present"
else
  FAIL=$((FAIL+1))
  FAIL_DETAILS+=("AC_B1: 🔄 進行中 section missing")
  echo "  FAIL  AC_B1_in_progress_section_present"
fi

# Verify dashboard.yaml in_progress reflects nested YAML (ashigaru4 is in_progress)
if python3 -c "
import yaml
d = yaml.safe_load(open('$DASHBOARD_YAML'))
ip = d.get('in_progress', [])
# Should have at least one entry (ashigaru4 cmd_649)
exit(0 if isinstance(ip, list) and len(ip) >= 1 else 1)
"; then
  PASS=$((PASS+1))
  echo "  PASS  AC_B2_yaml_in_progress_populated"
else
  FAIL=$((FAIL+1))
  FAIL_DETAILS+=("AC_B2: dashboard.yaml in_progress not populated from nested YAML")
  echo "  FAIL  AC_B2_yaml_in_progress_populated"
fi

echo ""
echo "=== Phase 7: AC C-2 — section structure intact ==="
for header in "## 📋 記載ルール" "## 🐸 Frog" "## 🚨 要対応" "## ⚠️ 違反検出" \
              "## 📊 運用指標" "## 🔄 進行中" "## 🏯 待機中" "## ✅ 本日の戦果" \
              "## 🛠️ スキル候補"; do
  if grep -q "^${header}" "$DASHBOARD"; then
    PASS=$((PASS+1))
    echo "  PASS  section_present: $header"
  else
    FAIL=$((FAIL+1))
    FAIL_DETAILS+=("section missing: $header")
    echo "  FAIL  section_present: $header"
  fi
done

echo ""
echo "=== Summary ==="
echo "PASS=$PASS  FAIL=$FAIL"
if [ $FAIL -gt 0 ]; then
  echo "Failure details:"
  for d in "${FAIL_DETAILS[@]}"; do echo "  - $d"; done
  exit 1
fi
echo "ALL TESTS PASSED"
exit 0
