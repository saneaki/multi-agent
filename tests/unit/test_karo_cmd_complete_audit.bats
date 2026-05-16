#!/usr/bin/env bats
# test_karo_cmd_complete_audit.bats — karo_cmd_complete_audit.sh ユニットテスト
#
# テスト構成:
#   T-KCA-001: bash -n 構文チェック
#   T-KCA-002: missing — done cmd に cmd_complete なし → exit 1
#   T-KCA-003: sent   — done cmd に cmd_complete あり → exit 0
#   T-KCA-004: not_done — in_progress cmd に cmd_complete なし → exit 0 (対象外)

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT="$PROJECT_ROOT/scripts/karo_cmd_complete_audit.sh"
}

setup() {
    export TMPDIR_TEST="$(mktemp -d)"
    mkdir -p "$TMPDIR_TEST/queue/inbox" "$TMPDIR_TEST/queue/tasks"
}

teardown() {
    rm -rf "$TMPDIR_TEST"
}

# ────────────────────────────────────────────────────────────
# T-KCA-001: 構文チェック
# ────────────────────────────────────────────────────────────
@test "T-KCA-001: bash -n 構文チェック" {
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────────────────────
# T-KCA-002: missing — done cmd に cmd_complete なし → exit 1
# ────────────────────────────────────────────────────────────
@test "T-KCA-002: done cmd に cmd_complete なし → exit 1 (FAIL)" {
    # shogun_to_karo: cmd_700 が done
    cat > "$TMPDIR_TEST/queue/shogun_to_karo.yaml" <<'YAML'
- id: cmd_700
  status: done
  purpose: テスト用 done cmd
YAML

    # shogun inbox: cmd_complete メッセージなし
    cat > "$TMPDIR_TEST/queue/inbox/shogun.yaml" <<'YAML'
messages:
- id: msg_001
  type: report_completed
  content: "別の報告"
  read: true
YAML

    run bash "$SCRIPT" --repo-root "$TMPDIR_TEST" --min-cmd-num 700 --quiet
    [ "$status" -eq 1 ]
}

# ────────────────────────────────────────────────────────────
# T-KCA-003: sent — done cmd に cmd_complete あり → exit 0 (PASS)
# ────────────────────────────────────────────────────────────
@test "T-KCA-003: done cmd に cmd_complete あり → exit 0 (PASS)" {
    # shogun_to_karo: cmd_701 が done
    cat > "$TMPDIR_TEST/queue/shogun_to_karo.yaml" <<'YAML'
- id: cmd_701
  status: done
  purpose: テスト用 done cmd with complete
YAML

    # shogun inbox: cmd_complete メッセージあり
    cat > "$TMPDIR_TEST/queue/inbox/shogun.yaml" <<'YAML'
messages:
- id: msg_002
  type: cmd_complete
  content: "cmd_701 完了 — テスト完遂"
  read: true
YAML

    run bash "$SCRIPT" --repo-root "$TMPDIR_TEST" --min-cmd-num 700 --quiet
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────────────────────
# T-KCA-004: not_done — in_progress cmd は監査対象外 → exit 0
# ────────────────────────────────────────────────────────────
@test "T-KCA-004: in_progress cmd はスキップ → exit 0 (PASS)" {
    # shogun_to_karo: cmd_702 が in_progress (done でない)
    cat > "$TMPDIR_TEST/queue/shogun_to_karo.yaml" <<'YAML'
- id: cmd_702
  status: in_progress
  purpose: テスト用 in_progress cmd
YAML

    # shogun inbox: cmd_complete なし
    cat > "$TMPDIR_TEST/queue/inbox/shogun.yaml" <<'YAML'
messages: []
YAML

    run bash "$SCRIPT" --repo-root "$TMPDIR_TEST" --min-cmd-num 700 --quiet
    [ "$status" -eq 0 ]
}
