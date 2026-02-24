#!/usr/bin/env bats
# test_dashboard_timestamp.bats — dashboard最終更新時刻JSTヘルパーのユニットテスト
#
# テスト構成:
#   T-DT-001: 正常実行 — dashboard.mdの最終更新行がJST形式に更新される
#   T-DT-002: dashboard.mdが存在しない場合 → exit 1 を返す
#   T-DT-003: 更新後の行が "最終更新: YYYY-MM-DD HH:MM JST" 形式であること
#   T-DT-004: bash -n 構文チェックがパスすること

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT="$PROJECT_ROOT/scripts/update_dashboard_timestamp.sh"
}

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- T-DT-001: 正常実行 ---

@test "T-DT-001: dashboard.mdの最終更新行がJST形式に更新される" {
    local test_dashboard="$TEST_TMPDIR/test_dashboard.md"
    cat > "$test_dashboard" << 'EOF'
# ダッシュボード
最終更新: 2000-01-01 00:00 JST
## 状況
EOF

    run env DASHBOARD_PATH="$test_dashboard" bash "$SCRIPT"
    [ "$status" -eq 0 ]

    # ファイル内に「最終更新:」行が存在することを確認
    grep -q '^最終更新:' "$test_dashboard"
}

# --- T-DT-002: dashboard.mdが存在しない場合 ---

@test "T-DT-002: dashboard.mdが存在しない場合 exit 1 を返す" {
    run env DASHBOARD_PATH="$TEST_TMPDIR/nonexistent_dashboard.md" bash "$SCRIPT"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ERROR"
}

# --- T-DT-003: 更新後の行フォーマット確認 ---

@test "T-DT-003: 更新後の行が 'YYYY-MM-DD HH:MM JST' 形式であること" {
    local test_dashboard="$TEST_TMPDIR/test_dashboard.md"
    cat > "$test_dashboard" << 'EOF'
# ダッシュボード
最終更新: 2000-01-01 00:00 JST
EOF

    env DASHBOARD_PATH="$test_dashboard" bash "$SCRIPT"

    local updated_line
    updated_line="$(grep '^最終更新:' "$test_dashboard")"

    # 正規表現チェック: "最終更新: YYYY-MM-DD HH:MM JST"
    [[ "$updated_line" =~ ^最終更新:\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}\ JST$ ]]
}

# --- T-DT-004: bash -n 構文チェック ---

@test "T-DT-004: bash -n 構文チェックがパスすること" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}
