#!/usr/bin/env bash
# cmd_544 17 テストケース実行スクリプト
# KS-1/2/3 + RL-1/2/3 + RL-TTL + DM-1/2/3/4 + S1/S2/S5/S7 + sug_003 + supervisor restart
set -uo pipefail

TEST_ROOT="/tmp/cmd544_test_$$"
mkdir -p "$TEST_ROOT/logs" "$TEST_ROOT/scripts"

# jst_now.sh stub (テスト中は固定日時を返す)
cat > "$TEST_ROOT/scripts/jst_now.sh" <<'EOF'
#!/bin/bash
case "${1:-}" in
    --yaml) echo "2026-04-18T12:00:00+09:00" ;;
    --date) echo "2026-04-18" ;;
    *) echo "2026-04-18 12:00" ;;
esac
EOF
chmod +x "$TEST_ROOT/scripts/jst_now.sh"

# Source hook script functions (test guard で main loop skip)
export SCRIPT_DIR="$TEST_ROOT"
export CMD_SQUASH_PUB_HOOK_TEST=1
# 先に SCRIPT_DIR を固定するため, hook source 前に DASHBOARD 等を明示
# hook 側で SCRIPT_DIR 再計算されるので、source 前にファイル準備
echo "" > "$TEST_ROOT/dashboard.md"
touch "$TEST_ROOT/logs/squash_pub_notified.txt"

# shellcheck disable=SC1091
# hook script は BASH_SOURCE で SCRIPT_DIR を決めるので、symlink 経由で /tmp に置く
cp /home/ubuntu/shogun/scripts/cmd_squash_pub_hook.sh "$TEST_ROOT/scripts/cmd_squash_pub_hook.sh"

# shellcheck source=/dev/null
source "$TEST_ROOT/scripts/cmd_squash_pub_hook.sh"

# テスト結果カウンタ
PASS=0
FAIL=0
RESULTS=()

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
        RESULTS+=("PASS $name")
    else
        FAIL=$((FAIL + 1))
        RESULTS+=("FAIL $name (expected=$expected actual=$actual)")
    fi
}

reset_state() {
    rm -f "$KILL_SWITCH_FILE" "$RATE_TS_FILE" "$PENDING_FILE" "$METRIC_FILE"
    : > "$STATE_FILE"
}

# ================================================================
# KS-1: kill-switch 無し
# ================================================================
reset_state
if ! is_kill_switched; then rc=0; else rc=1; fi
assert_eq "KS-1 (no kill-switch)" "0" "$rc"

# ================================================================
# KS-2: kill-switch ON
# ================================================================
reset_state
touch "$KILL_SWITCH_FILE"
if is_kill_switched; then rc=0; else rc=1; fi
assert_eq "KS-2 (kill-switch ON)" "0" "$rc"

# KS-3: 再有効化
rm -f "$KILL_SWITCH_FILE"
if ! is_kill_switched; then rc=0; else rc=1; fi
assert_eq "KS-3 (kill-switch removed)" "0" "$rc"

# ================================================================
# RL-1: 窓内抑止
# ================================================================
reset_state
date +%s > "$RATE_TS_FILE"
if is_rate_limited_now; then rc=0; else rc=1; fi
assert_eq "RL-1 (window active)" "0" "$rc"

# ================================================================
# RL-2: 窓明け
# ================================================================
reset_state
echo $(($(date +%s) - 1900)) > "$RATE_TS_FILE"  # 30分超
if ! is_rate_limited_now; then rc=0; else rc=1; fi
assert_eq "RL-2 (window expired)" "0" "$rc"

# ================================================================
# RL-3: 重複抑止
# ================================================================
reset_state
enqueue_pending_cmd "cmd_997" >/dev/null 2>&1
enqueue_pending_cmd "cmd_997" >/dev/null 2>&1
actual_count=$(grep -c "^cmd_997" "$PENDING_FILE")
assert_eq "RL-3 (duplicate suppression)" "1" "$actual_count"

# ================================================================
# RL-TTL: TTL 超過破棄
# ================================================================
reset_state
printf 'cmd_old\t%s\n' "$(($(date +%s) - 90000))" > "$PENDING_FILE"  # 25h前
drained=$(drain_pending_cmds)
line_count=$(wc -l < "$PENDING_FILE" | tr -d ' ')
assert_eq "RL-TTL (expired drop)" "0" "$line_count"
[ -z "$drained" ] && drc=0 || drc=1
assert_eq "RL-TTL (nothing drained)" "0" "$drc"

# ================================================================
# DM-1: attempt カウント増加
# ================================================================
reset_state
metric_inc_attempt >/dev/null 2>&1
before=$(awk '/^attempt_total:/ {print $2}' "$METRIC_FILE")
metric_inc_attempt >/dev/null 2>&1
after=$(awk '/^attempt_total:/ {print $2}' "$METRIC_FILE")
assert_eq "DM-1 (attempt +1)" "$((before + 1))" "$after"

# ================================================================
# DM-2: success カウント増加
# ================================================================
reset_state
metric_inc_success >/dev/null 2>&1
success=$(awk '/^success_total:/ {print $2}' "$METRIC_FILE")
assert_eq "DM-2 (success=1)" "1" "$success"

# ================================================================
# DM-3: failure カウント増加
# ================================================================
reset_state
metric_inc_failure >/dev/null 2>&1
failure=$(awk '/^failure_total:/ {print $2}' "$METRIC_FILE")
assert_eq "DM-3 (failure=1)" "1" "$failure"

# ================================================================
# DM-4: JST 日次切替
# ================================================================
reset_state
metric_inc_attempt >/dev/null 2>&1
sed -i 's/^date_jst: ".*"/date_jst: "2026-04-17"/' "$METRIC_FILE"  # 前日に偽装
metric_inc_attempt >/dev/null 2>&1
current_jst=$(awk -F': ' '/^date_jst:/ {gsub(/"/,"",$2); print $2}' "$METRIC_FILE")
assert_eq "DM-4 (JST reset date)" "2026-04-18" "$current_jst"
new_attempt=$(awk '/^attempt_total:/ {print $2}' "$METRIC_FILE")
assert_eq "DM-4 (counter reset to 1)" "1" "$new_attempt"

# ================================================================
# sug_003-1: RATE_TS_FILE 破損 fallback
# ================================================================
reset_state
echo "garbage" > "$RATE_TS_FILE"
if ! is_rate_limited_now 2>/dev/null; then rc=0; else rc=1; fi
assert_eq "sug_003-1 (RATE_TS corrupted → 0)" "0" "$rc"

# ================================================================
# sug_003-2: daily.yaml 数値破損 fallback
# ================================================================
reset_state
metric_inc_attempt >/dev/null 2>&1
sed -i 's/^attempt_total: .*/attempt_total: not_a_number/' "$METRIC_FILE"
metric_inc_attempt >/dev/null 2>&1
new_val=$(awk '/^attempt_total:/ {print $2}' "$METRIC_FILE")
assert_eq "sug_003-2 (metric non-numeric → reset+1)" "1" "$new_val"

# ================================================================
# S1 (非退行): 未push 0件の SKIP 扱い
# ================================================================
# S1 は実 git log を使うため、関数単体ではなく動作確認のみ
# (本物の git log origin/main..HEAD で確認は Step 13 後に integration test)
RESULTS+=("INFO S1 (S1 grep logic) — 既存コード非改修、integration test 要")

# ================================================================
# S2 (非退行): squash commit 失敗 rollback
# ================================================================
# S2 は git 操作、integration test 必要
RESULTS+=("INFO S2 (rollback logic) — 既存コード非改修、integration test 要")

# ================================================================
# S5 (非退行): flock
# ================================================================
# S5 は既存 check_and_squash flock ロジック、非改修
RESULTS+=("INFO S5 (flock) — 既存コード非改修")

# ================================================================
# S7 (非退行): 起動時 bulk-push 防止
# ================================================================
# S7 は main execution の startup registration、non-test 時のみ実行
RESULTS+=("INFO S7 (startup dedup) — main execution only")

# ================================================================
# 戻り値規約: invoke_pub_us kill-switch → return 2
# ================================================================
reset_state
touch "$KILL_SWITCH_FILE"
set +e
invoke_pub_us "" >/dev/null 2>&1
rc=$?
set -e
assert_eq "戻り値 invoke_pub_us rc=2 (KS)" "2" "$rc"

# ================================================================
# 戻り値規約: squash_and_pub kill-switch → return 0
# ================================================================
reset_state
touch "$KILL_SWITCH_FILE"
set +e
squash_and_pub "cmd_999" >/dev/null 2>&1
rc=$?
set -e
assert_eq "戻り値 squash_and_pub rc=0 (KS)" "0" "$rc"

# ================================================================
# 結果集計
# ================================================================
echo ""
echo "===== cmd_544 Test Results ====="
for r in "${RESULTS[@]}"; do
    echo "$r"
done
echo ""
echo "PASS: $PASS / FAIL: $FAIL"
echo "================================"

# cleanup
rm -rf "$TEST_ROOT"

[ "$FAIL" -eq 0 ]
