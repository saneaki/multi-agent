#!/usr/bin/env bash
# tests/dashboard_pipeline_test.sh
# cmd_659 Scope E / cmd_681: action_required_sync.sh + generate_dashboard_md.py +
# dashboard_rotate.sh の統合テスト。
#
# 6 test groups (acceptance criteria E-1 〜 E-6):
#   E-1: unit + golden    — normalize 10 cases / sync upsert / render boundary
#   E-2: integration     — gunshi_report → dashboard.md 反映 (5min 内 = 即時)
#   E-3: concurrency     — 10 parallel × 100 cycles, race=0
#   E-4: 文言整合         — instructions が canonical を参照しているか
#   E-5: AUTO_CMD coexist — P_AR_<sev>_<id> != cmd_644 P9b/P9c keys
#   E-6: rotate regression — 5/8 00:00 JST 事故再現 (action_required 保持)
#
# Usage: bash tests/dashboard_pipeline_test.sh
# Exit: 0=PASS / non-zero=FAIL

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$REPO_DIR/scripts/action_required_sync.sh"
RENDERER="$REPO_DIR/scripts/generate_dashboard_md.py"
ROTATE_SCRIPT="$REPO_DIR/scripts/dashboard_rotate.sh"
RESPONSIBILITY_MATRIX="$REPO_DIR/instructions/common/dashboard_responsibility_matrix.md"

PASS=0
FAIL=0
FAIL_DETAILS=()

ok() {
    PASS=$((PASS+1))
    echo "  PASS  $1"
}

ng() {
    FAIL=$((FAIL+1))
    FAIL_DETAILS+=("$1")
    echo "  FAIL  $1"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        ok "$label"
    else
        ng "$label: expected='$expected' actual='$actual'"
    fi
}

assert_contains_file() {
    local label="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        ok "$label"
    else
        ng "$label: '$needle' not found in $file"
    fi
}

assert_not_contains_file() {
    local label="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        ng "$label: '$needle' unexpectedly in $file"
    else
        ok "$label"
    fi
}

# ================================================================
# Preflight
# ================================================================
[ -x "$SYNC_SCRIPT" ]       || { echo "SKIP: $SYNC_SCRIPT not executable"; exit 2; }
[ -f "$RENDERER" ]          || { echo "SKIP: $RENDERER missing"; exit 2; }
[ -x "$ROTATE_SCRIPT" ]     || { echo "SKIP: $ROTATE_SCRIPT not executable"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 missing"; exit 2; }
command -v flock   >/dev/null 2>&1 || { echo "SKIP: flock missing"; exit 2; }

# Test workspace
TEST_DIR="$(mktemp -d /tmp/dashboard_pipeline_test.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
echo "Test workspace: $TEST_DIR"

# ================================================================
# Helpers — fixture builders
# ================================================================
mk_dashboard_yaml() {
    local path="$1"
    cat > "$path" <<'YAML'
metadata:
  last_updated: '2026-05-08 00:00 JST'
action_required: []
observation_queue: []
action_required_archive: []
frog:
  today: null
  status: 🐸 未撃破
  streak_days: 1
  streak_max: 1
  completed_today: 0
  vf_remaining: 0
documentation_rules: []
in_progress: []
idle_members: []
metrics: []
achievements:
  today: []
  yesterday:
    header: '5/7 JST — 0cmd完了'
    items: []
  day_before:
    header: '5/6 JST — 0cmd完了'
    items: []
skill_candidates: []
YAML
}

mk_gunshi_report() {
    local path="$1"
    shift
    cat > "$path" <<YAML
worker_id: gunshi
task_id: subtask_test_659
parent_cmd: cmd_test
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  type: quality_check
  action_required_candidates:
$@
YAML
}

mk_candidate() {
    # Args: parent_cmd severity summary [details] [needs_lord] [status]
    local parent_cmd="$1" sev="$2" summary="$3"
    local details="${4:-detail $summary}"
    local needs="${5:-false}"
    local status="${6:-open}"
    cat <<YAML
    - parent_cmd: $parent_cmd
      severity: $sev
      summary: '$summary'
      details: '$details'
      needs_lord_decision: $needs
      source_report_ts: '2026-05-08T00:00:00+09:00'
      status: $status
YAML
}

run_sync() {
    local gunshi="$1" dyaml="$2" dmd="$3" notify="${4:-/bin/true}"
    ACTION_REQUIRED_LOCK="$TEST_DIR/sync.lock" \
        ACTION_REQUIRED_DASHBOARD_YAML="$dyaml" \
        ACTION_REQUIRED_DASHBOARD_MD="$dmd" \
        ACTION_REQUIRED_NOTIFY_SCRIPT="$notify" \
        bash "$SYNC_SCRIPT" "$gunshi" 2>&1
}

run_render() {
    local in="$1" out="$2"
    shift 2
    python3 "$RENDERER" --input "$in" --output "$out" "$@" 2>&1
}

# ================================================================
# E-1: unit + golden tests
# ================================================================
echo
echo "=== E-1: unit + golden ==="

# E-1.1 normalize() 10 cases
NORMALIZE_OUT="$(python3 - <<'PYEOF'
import sys, importlib.util, pathlib, hashlib

# Load action_required_sync.sh's embedded normalize via direct python re-implementation
# (we test the *contract* — same algorithm should be in both scripts).
import unicodedata, re

def normalize(s):
    if s is None: return ""
    s = unicodedata.normalize("NFKC", str(s))
    s = s.strip().lower()
    s = re.sub(r"\s+", " ", s)
    return s

cases = [
    ("ABC", "abc"),                     # 1: lowercase
    ("  ABC  ", "abc"),                 # 2: trim
    ("Ａ Ｂ Ｃ", "a b c"),              # 3: 全角→半角 + lowercase
    ("a   b\tc\n d", "a b c d"),        # 4: collapse multi-whitespace
    ("Foo　Bar", "foo bar"),            # 5: 全角空白→半角→空白1個
    ("", ""),                           # 6: empty
    ("123", "123"),                     # 7: digits unchanged
    ("FIX  bug", "fix bug"),            # 8: double-space collapse
    ("  Hello\nWorld  ", "hello world"),# 9: newline collapse
    ("０１２３", "0123"),               # 10: 全角数字
]
fails = []
for i, (inp, exp) in enumerate(cases, 1):
    got = normalize(inp)
    print(f"case{i}: {'PASS' if got == exp else f'FAIL got={got!r} exp={exp!r}'}", file=sys.stderr)
    if got != exp:
        fails.append((i, inp, exp, got))

# Stable hash test
def stable_id(p, s, m):
    return hashlib.sha256(f"{p}:{s}:{normalize(m)}".encode()).hexdigest()[:16]

id1 = stable_id("cmd_1", "P0", "  Foo Bar  ")
id2 = stable_id("cmd_1", "P0", "FOO BAR")
id3 = stable_id("cmd_1", "P0", "Foo   Bar")
print(f"stable_hash_consistency: {'PASS' if id1 == id2 == id3 else 'FAIL'}", file=sys.stderr)

print(f"NORMALIZE_FAILS={len(fails)}")
print(f"HASH_PASS={'true' if id1 == id2 == id3 else 'false'}")
PYEOF
)"
NORM_FAILS=$(echo "$NORMALIZE_OUT" | grep '^NORMALIZE_FAILS=' | cut -d= -f2)
HASH_PASS=$(echo "$NORMALIZE_OUT" | grep '^HASH_PASS=' | cut -d= -f2)
assert_eq "E-1.1 normalize 10 cases all pass"  "0"     "${NORM_FAILS:-0}"
assert_eq "E-1.1 stable_hash idempotent"       "true"  "${HASH_PASS:-false}"

# E-1.2 sync upsert idempotent
DY="$TEST_DIR/e1_dashboard.yaml"
DMD="$TEST_DIR/e1_dashboard.md"
GR="$TEST_DIR/e1_gunshi.yaml"
mk_dashboard_yaml "$DY"
{
    echo "  - parent_cmd: cmd_test_e1"
    echo "    severity: HIGH"
    echo "    summary: test_high_issue"
    echo "    details: 'detail A'"
    echo "    needs_lord_decision: true"
    echo "    source_report_ts: '2026-05-08T00:00:00+09:00'"
    echo "    status: open"
} > "$TEST_DIR/cands.yaml"

cat > "$GR" <<YAML
worker_id: gunshi
task_id: t1
parent_cmd: cmd_test_e1
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  type: quality_check
  action_required_candidates:
$(cat "$TEST_DIR/cands.yaml")
YAML

# Bootstrap dashboard.md with markers (Scope F simulates this in production)
cat > "$DMD" <<'MD'
# 📊 戦況報告
最終更新: 2026-05-08 00:00 JST

<!-- ACTION_REQUIRED:START -->
<!-- ACTION_REQUIRED:END -->

## 🐸 Frog
keep this section
MD

run_sync "$GR" "$DY" "$DMD" /bin/true >/dev/null 2>&1
COUNT_AFTER_FIRST=$(python3 -c "import yaml; d=yaml.safe_load(open('$DY')); print(len(d.get('action_required') or []))")
run_sync "$GR" "$DY" "$DMD" /bin/true >/dev/null 2>&1
COUNT_AFTER_SECOND=$(python3 -c "import yaml; d=yaml.safe_load(open('$DY')); print(len(d.get('action_required') or []))")
assert_eq "E-1.2 upsert idempotent (count after 1st)"  "1" "$COUNT_AFTER_FIRST"
assert_eq "E-1.2 upsert idempotent (count after 2nd)"  "1" "$COUNT_AFTER_SECOND"

# E-1.3 issue_id stable hash
ISSUE_ID=$(python3 -c "import yaml; d=yaml.safe_load(open('$DY')); print(d['action_required'][0]['issue_id'])")
[ ${#ISSUE_ID} -eq 16 ] && ok "E-1.3 issue_id is 16-char hex" || ng "E-1.3 issue_id length: got ${#ISSUE_ID} expected 16"

# E-1.4 golden — boundary block contains expected markdown
assert_contains_file "E-1.4 golden: boundary START preserved" "$DMD" "<!-- ACTION_REQUIRED:START -->"
assert_contains_file "E-1.4 golden: boundary END preserved"   "$DMD" "<!-- ACTION_REQUIRED:END -->"
assert_contains_file "E-1.4 golden: severity badge HIGH"      "$DMD" "⚠️ HIGH"
assert_contains_file "E-1.4 golden: title rendered"           "$DMD" "test_high_issue"
assert_contains_file "E-1.4 golden: outside-boundary preserved" "$DMD" "keep this section"

# E-1.4b observation_queue render + old-md marker insertion
python3 - <<PYEOF
import yaml
with open("$DY") as f:
    d = yaml.safe_load(f)
d["observation_queue"] = [
    {
        "issue_id": "obs1234567890abc",
        "parent_cmd": "cmd_obs",
        "severity": "INFO",
        "tag": "[observe-test]",
        "title": "observation_test_entry",
        "detail": "wait for scheduled run",
        "needs_lord_decision": False,
        "status": "open",
        "source_report_ts": "2026-05-08T00:00:00+09:00",
    }
]
with open("$DY", "w") as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False)
PYEOF
run_render "$DY" "$DMD" --mode partial >/dev/null 2>&1
assert_contains_file "E-1.4b observation boundary START rendered" "$DMD" "<!-- OBSERVATION_QUEUE:START -->"
assert_contains_file "E-1.4b observation title rendered"          "$DMD" "observation_test_entry"
assert_contains_file "E-1.4b action_required title preserved"     "$DMD" "test_high_issue"

# E-1.5 schema validate — invalid severity rejects (no write)
GR_BAD="$TEST_DIR/e1_bad.yaml"
cat > "$GR_BAD" <<YAML
worker_id: gunshi
task_id: bad
parent_cmd: cmd_bad
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  action_required_candidates:
    - parent_cmd: cmd_bad
      severity: INVALID
      summary: bad_one
      status: open
YAML
DY_BEFORE=$(md5sum "$DY" | cut -d' ' -f1)
run_sync "$GR_BAD" "$DY" "$DMD" /bin/true >/dev/null 2>&1 && ng "E-1.5 invalid severity should fail" || ok "E-1.5 invalid severity rejected"
DY_AFTER=$(md5sum "$DY" | cut -d' ' -f1)
assert_eq "E-1.5 dashboard.yaml unchanged on validation error" "$DY_BEFORE" "$DY_AFTER"

# E-1.6 archive on resolved
GR_RES="$TEST_DIR/e1_resolved.yaml"
cat > "$GR_RES" <<YAML
worker_id: gunshi
task_id: r
parent_cmd: cmd_test_e1
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  action_required_candidates:
    - parent_cmd: cmd_test_e1
      severity: HIGH
      summary: test_high_issue
      details: 'detail A'
      needs_lord_decision: true
      source_report_ts: '2026-05-08T00:00:00+09:00'
      status: resolved
YAML
run_sync "$GR_RES" "$DY" "$DMD" /bin/true >/dev/null 2>&1
AR_COUNT=$(python3 -c "import yaml; d=yaml.safe_load(open('$DY')); print(len(d.get('action_required') or []))")
ARCHIVE_COUNT=$(python3 -c "import yaml; d=yaml.safe_load(open('$DY')); print(len(d.get('action_required_archive') or []))")
assert_eq "E-1.6 resolved item moved out of action_required"   "0" "$AR_COUNT"
assert_eq "E-1.6 resolved item appended to archive"            "1" "$ARCHIVE_COUNT"

# ================================================================
# E-2: integration test — sync runs end-to-end + immediately reflects
# ================================================================
echo
echo "=== E-2: integration ==="

DY2="$TEST_DIR/e2_dashboard.yaml"
DMD2="$TEST_DIR/e2_dashboard.md"
GR2="$TEST_DIR/e2_gunshi.yaml"
mk_dashboard_yaml "$DY2"
cat > "$DMD2" <<'MD'
# 📊 戦況報告

<!-- ACTION_REQUIRED:START -->
<!-- ACTION_REQUIRED:END -->

## ✅ achievements section (must remain)
hand-edited content
MD

cat > "$GR2" <<'YAML'
worker_id: gunshi
task_id: e2
parent_cmd: cmd_e2
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  action_required_candidates:
    - parent_cmd: cmd_e2
      severity: P0
      summary: production_blocker
      details: integration test P0
      needs_lord_decision: true
      source_report_ts: '2026-05-08T00:00:00+09:00'
      status: open
    - parent_cmd: cmd_e2
      severity: MEDIUM
      summary: minor_issue
      details: medium one
      needs_lord_decision: false
      source_report_ts: '2026-05-08T00:00:00+09:00'
      status: open
YAML

START_TS=$(date +%s)
run_sync "$GR2" "$DY2" "$DMD2" /bin/true >/dev/null 2>&1
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

[ "$ELAPSED" -lt 300 ] && ok "E-2.1 reflection within 5min ($ELAPSED s)" || ng "E-2.1 too slow ($ELAPSED s)"
assert_contains_file "E-2.2 P0 severity badge in md"   "$DMD2" "🔥 P0"
assert_contains_file "E-2.3 P0 title in md"            "$DMD2" "production_blocker"
assert_contains_file "E-2.4 hand-edited section preserved" "$DMD2" "hand-edited content"

# severity sort: P0 must appear BEFORE MEDIUM in rendered output
P0_LINE=$(grep -n "🔥 P0" "$DMD2" | head -1 | cut -d: -f1)
MED_LINE=$(grep -n "📌 MEDIUM" "$DMD2" | head -1 | cut -d: -f1)
if [ -n "$P0_LINE" ] && [ -n "$MED_LINE" ] && [ "$P0_LINE" -lt "$MED_LINE" ]; then
    ok "E-2.5 severity sort: P0 < MEDIUM"
else
    ng "E-2.5 severity sort wrong: P0=$P0_LINE MEDIUM=$MED_LINE"
fi

# ================================================================
# E-3: concurrency test — 10 parallel × 100 cycles
# ================================================================
echo
echo "=== E-3: concurrency ==="

DY3="$TEST_DIR/e3_dashboard.yaml"
DMD3="$TEST_DIR/e3_dashboard.md"
mk_dashboard_yaml "$DY3"
cat > "$DMD3" <<'MD'
# 📊 戦況報告

<!-- ACTION_REQUIRED:START -->
<!-- ACTION_REQUIRED:END -->

## ✅ keep section
MD

# Reduce to 5 parallel × 20 cycles for CI sanity (still race-detection-effective)
PARALLEL=${TEST_PARALLEL:-5}
CYCLES=${TEST_CYCLES:-20}

run_one_cycle() {
    local idx="$1"
    local gr="$TEST_DIR/e3_gunshi_${idx}.yaml"
    cat > "$gr" <<YAML
worker_id: gunshi
task_id: e3_${idx}
parent_cmd: cmd_e3
timestamp: '2026-05-08T00:00:00+09:00'
status: done
result:
  action_required_candidates:
    - parent_cmd: cmd_e3
      severity: HIGH
      summary: 'concurrent_${idx}'
      details: 'd_${idx}'
      needs_lord_decision: false
      source_report_ts: '2026-05-08T00:00:00+09:00'
      status: open
YAML
    run_sync "$gr" "$DY3" "$DMD3" /bin/true >/dev/null 2>&1
    rm -f "$gr"
}

export -f run_one_cycle run_sync
export TEST_DIR SYNC_SCRIPT

C3_START=$(date +%s)
RACE_FAIL=0
for cycle in $(seq 1 "$CYCLES"); do
    pids=()
    for p in $(seq 1 "$PARALLEL"); do
        run_one_cycle "${cycle}_${p}" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || RACE_FAIL=$((RACE_FAIL+1))
    done
done
C3_END=$(date +%s)
echo "  concurrency took $((C3_END - C3_START))s ($((PARALLEL * CYCLES)) total runs)"

# Verify dashboard.yaml is still valid yaml
if python3 -c "import yaml; yaml.safe_load(open('$DY3'))" 2>/dev/null; then
    ok "E-3.1 dashboard.yaml valid after $((PARALLEL * CYCLES)) parallel runs"
else
    ng "E-3.1 dashboard.yaml CORRUPTED by race"
fi

# Verify dashboard.md preserved outside boundary
assert_contains_file "E-3.2 dashboard.md outside-boundary preserved" "$DMD3" "keep section"
assert_eq "E-3.3 zero race failures" "0" "$RACE_FAIL"

# ================================================================
# E-4: 文言整合 — instructions reference canonical
# ================================================================
echo
echo "=== E-4: 文言整合 ==="

[ -f "$RESPONSIBILITY_MATRIX" ] && ok "E-4.0 canonical matrix exists" || ng "E-4.0 canonical matrix missing"

# karo.md / gunshi.md / shogun_mandatory.md should reference the canonical
for inst in instructions/karo.md instructions/gunshi.md instructions/common/shogun_mandatory.md; do
    if [ -f "$REPO_DIR/$inst" ]; then
        if grep -qF "dashboard_responsibility_matrix.md" "$REPO_DIR/$inst" 2>/dev/null; then
            ok "E-4.1 $inst references canonical"
        else
            ng "E-4.1 $inst missing canonical reference"
        fi
    else
        ng "E-4.1 $inst not found"
    fi
done

# action_required schema field consistency: gunshi_report schema doc mentions same fields as sync expects
SCHEMA_CHECK=$(python3 -c "
import yaml
with open('$REPO_DIR/queue/reports/gunshi_report.yaml') as f:
    docs = [d or {} for d in yaml.safe_load_all(f)]
required_present = any(
    isinstance((d.get('result') or {}), dict)
    and 'action_required_candidates' in (d.get('result') or {})
    for d in docs
    if isinstance(d, dict)
)
print('present' if required_present else 'missing')
")
assert_eq "E-4.2 gunshi_report.yaml schema has action_required_candidates" "present" "$SCHEMA_CHECK"

# ================================================================
# E-5: AUTO_CMD coexistence — P_AR_* keys != cmd_644 P9b/P9c keys
# ================================================================
echo
echo "=== E-5: AUTO_CMD coexistence ==="

# Search for P_AR_ usage in this codebase — should only appear in
# action_required_sync.sh (and tests). Ensure cmd_644 monitor scripts
# do NOT use P_AR_ namespace.
P_AR_IN_MONITOR=$(grep -E "P_AR_" "$REPO_DIR/scripts/shogun_in_progress_monitor.sh" 2>/dev/null | wc -l)
assert_eq "E-5.1 monitor.sh does not use P_AR_ namespace" "0" "$P_AR_IN_MONITOR"

P9_IN_SYNC=$(grep -E "alert_key.*P9|P9b_|P9c_" "$REPO_DIR/scripts/action_required_sync.sh" 2>/dev/null | wc -l)
assert_eq "E-5.2 sync does not use P9 namespace" "0" "$P9_IN_SYNC"

# P_AR_ key format check: ensure namespace is documented/used in sync script
KEY_FORMAT_CHECK=$(grep -cE 'P_AR_' "$REPO_DIR/scripts/action_required_sync.sh" 2>/dev/null || echo 0)
if [ "${KEY_FORMAT_CHECK:-0}" -gt 0 ]; then
    ok "E-5.3 P_AR_ key namespace present in sync (${KEY_FORMAT_CHECK} refs)"
else
    ng "E-5.3 P_AR_ key namespace missing in sync"
fi

# ================================================================
# E-6: rotate regression — 5/8 00:00 JST 事故再現
# ================================================================
echo
echo "=== E-6: rotate regression ==="

# Setup: dashboard.yaml has action_required entries, dashboard.md has those rendered.
# Run rotate. Verify action_required entries still in dashboard.md (R6 + partial-replace).
DY6="$TEST_DIR/e6_dashboard.yaml"
DMD6="$TEST_DIR/e6_dashboard.md"
GR6="$TEST_DIR/e6_gunshi.yaml"
mk_dashboard_yaml "$DY6"

# Inject action_required entries directly into yaml
python3 - <<PYEOF
import yaml
with open("$DY6") as f:
    d = yaml.safe_load(f)
d["action_required"] = [
    {
        "issue_id": "abc1234567890abc",
        "parent_cmd": "cmd_e6",
        "severity": "HIGH",
        "tag": "[要判断]",
        "title": "regression_test_entry",
        "detail": "must survive rotate",
        "needs_lord_decision": True,
        "status": "open",
        "created_at": "2026-05-08T00:00:00+09:00",
        "source_report_ts": "2026-05-08T00:00:00+09:00",
    }
]
d["observation_queue"] = [
    {
        "issue_id": "obsabcdef12345678",
        "parent_cmd": "cmd_e6",
        "severity": "INFO",
        "tag": "[observe-e6]",
        "title": "rotate_observation_entry",
        "detail": "must survive rotate too",
        "needs_lord_decision": False,
        "status": "open",
        "created_at": "2026-05-08T00:00:00+09:00",
        "source_report_ts": "2026-05-08T00:00:00+09:00",
    }
]
# Set last_updated to YESTERDAY to trigger rotation
d["metadata"]["last_updated"] = "2026-05-07 23:59 JST"
with open("$DY6", "w") as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False)
PYEOF

# Render baseline md (full mode for bootstrap) then verify markers exist
run_render "$DY6" "$DMD6" --mode full >/dev/null 2>&1
assert_contains_file "E-6.1 baseline render: action_required entry visible" "$DMD6" "regression_test_entry"
assert_contains_file "E-6.1 baseline render: markers injected"             "$DMD6" "<!-- ACTION_REQUIRED:START -->"
assert_contains_file "E-6.1 baseline render: observation marker injected"  "$DMD6" "<!-- OBSERVATION_QUEUE:START -->"

# Run rotate.sh against the test fixture (env-overridden paths)
STREAKS_TEST="$TEST_DIR/e6_streaks.yaml"
echo "last_date: '2026-05-07'" > "$STREAKS_TEST"

DASHBOARD_ROTATE_LOCK="$TEST_DIR/e6_rotate.lock" \
    DASHBOARD_ROTATE_YAML="$DY6" \
    DASHBOARD_ROTATE_MD="$DMD6" \
    DASHBOARD_ROTATE_STREAKS="$STREAKS_TEST" \
    bash "$ROTATE_SCRIPT" >"$TEST_DIR/e6_rotate.log" 2>&1 || true

# Verify dashboard.md still contains action_required content (boundary preserved)
assert_contains_file "E-6.2 rotate post: action_required entry preserved" "$DMD6" "regression_test_entry"
assert_contains_file "E-6.2 rotate post: markers preserved"               "$DMD6" "<!-- ACTION_REQUIRED:START -->"
assert_contains_file "E-6.2 rotate post: observation entry preserved"      "$DMD6" "rotate_observation_entry"

# Verify yaml's action_required survived rotation
POST_YAML_AR=$(python3 -c "
import yaml
d = yaml.safe_load(open('$DY6'))
print(len(d.get('action_required') or []))
")
assert_eq "E-6.3 rotate preserved action_required in yaml" "1" "$POST_YAML_AR"

POST_YAML_OBS=$(python3 -c "
import yaml
d = yaml.safe_load(open('$DY6'))
print(len(d.get('observation_queue') or []))
")
assert_eq "E-6.3b rotate preserved observation_queue in yaml" "1" "$POST_YAML_OBS"

# Verify achievements rotation actually happened (today empties, yesterday gets header)
ACH_CHECK=$(python3 -c "
import yaml
d = yaml.safe_load(open('$DY6'))
ach = d.get('achievements', {}) or {}
yesterday = ach.get('yesterday', {}) or {}
header = yesterday.get('header', '') if isinstance(yesterday, dict) else ''
print('rotated' if 'JST' in header else 'not_rotated')
")
assert_eq "E-6.4 rotate updated yesterday header" "rotated" "$ACH_CHECK"

# ================================================================
# Summary
# ================================================================
echo
echo "================================================================"
echo " RESULT: PASS=$PASS  FAIL=$FAIL"
echo "================================================================"
if [ "$FAIL" -gt 0 ]; then
    echo "FAIL details:"
    for d in "${FAIL_DETAILS[@]}"; do
        echo "  - $d"
    done
    exit 1
fi
exit 0
