#!/usr/bin/env bats
# test_shogun_hook.bats — cmd_complete自動報告Hook ユニットテスト
#
# テスト構成:
#   T-SH-001: extract_cmd_id — 正常抽出 (cmd_006)
#   T-SH-002: extract_cmd_id — 内容にcmd_idなし → 空文字
#   T-SH-003: extract_dashboard_section — 正常抽出 (完了cmd)
#   T-SH-004: extract_dashboard_section — 存在しないcmd → フォールバック
#   T-SH-005: extract_dashboard_section — dashboard不在 → フォールバック
#   T-SH-006: construct_report_prompt — プロンプト形式検証
#   T-SH-007: get_unread_info — cmd_complete が specials とは別に返る
#   T-SH-008: get_unread_info — cmd_complete が read:true にマークされる
#   T-SH-009: get_unread_info — cmd_complete 以外の通常メッセージは count に含まれる
#   T-SH-010: handle_cmd_complete — 非shogunエージェントは無視
#   T-SH-011: process_unread — cmd_complete → hook呼び出し
#   T-SH-012: process_unread — 通常メッセージは従来通りnudge送信（回帰テスト）
#   T-SH-013: extract_cmd_id — cmd_milestone型メッセージからcmd_id抽出
#   T-SH-014: construct_report_prompt — cmd_milestone型で中間報告文言
#   T-SH-015: process_unread — cmd_milestone → hook呼び出し（型伝搬確認）

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export HOOK_SCRIPT="$PROJECT_ROOT/scripts/shogun_report_hook.sh"
    export WATCHER_SCRIPT="$PROJECT_ROOT/scripts/inbox_watcher.sh"
    [ -f "$HOOK_SCRIPT" ] || return 1
    [ -f "$WATCHER_SCRIPT" ] || return 1
    python3 -c "import yaml" 2>/dev/null || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/shogun_hook_test.XXXXXX")"
    export TEST_INBOX_DIR="$TEST_TMPDIR/queue/inbox"
    mkdir -p "$TEST_INBOX_DIR"

    # Mock log
    export MOCK_LOG="$TEST_TMPDIR/tmux_calls.log"
    > "$MOCK_LOG"

    # Hook calls log
    export HOOK_LOG="$TEST_TMPDIR/hook_calls.log"
    > "$HOOK_LOG"

    # Create mock pgrep (default: no self-watch)
    export MOCK_PGREP="$TEST_TMPDIR/mock_pgrep"
    cat > "$MOCK_PGREP" << 'MOCK'
#!/bin/bash
exit 1
MOCK
    chmod +x "$MOCK_PGREP"

    # Default mock control
    export MOCK_CAPTURE_PANE=""
    export MOCK_SENDKEYS_RC=0

    # Create sample dashboard.md
    export TEST_DASHBOARD="$TEST_TMPDIR/dashboard.md"
    cat > "$TEST_DASHBOARD" << 'DASHBOARD'
# 戦況報告

## 🔄 進行中

### cmd_008: pdfmerged .exe リビルド — 🔄 進行中

**目的**: .exeビルド

## ✅ 本日の戦果

### cmd_006: pdfmerged GUI ヘルプ追加 — ✅ 完了

**受入基準: 6/6 全達成**

| 基準 | 結果 |
|------|------|
| 各タブに概要説明 | ✅ |
| 主要な操作手順 | ✅ |
| 法律事務所リネーム説明 | ✅ |

### cmd_005: cmd完了時の自動上奏 — ✅ 完了 (5/5)

## ✅ 昨日の戦果

### cmd_003: pdfmerged リネーム機能 — ✅ 完了 (7/7)
DASHBOARD

    # Test harness for hook script functions
    export HOOK_HARNESS="$TEST_TMPDIR/hook_harness.sh"
    cat > "$HOOK_HARNESS" << HARNESS
#!/bin/bash
SCRIPT_DIR="$TEST_TMPDIR"
export __SHOGUN_HOOK_TESTING__=1
source "$HOOK_SCRIPT"
HARNESS
    chmod +x "$HOOK_HARNESS"

    # Test harness for watcher functions (with mock hook script)
    # Create mock shogun_report_hook.sh that logs instead of using tmux
    export TEST_SCRIPTS_DIR="$TEST_TMPDIR/scripts"
    mkdir -p "$TEST_SCRIPTS_DIR"
    cat > "$TEST_SCRIPTS_DIR/shogun_report_hook.sh" << 'MOCK_HOOK'
#!/bin/bash
echo "HOOK_CALLED: content=$1 pane=$2 dashboard=$3" >> "${HOOK_LOG:-/dev/null}"
MOCK_HOOK
    chmod +x "$TEST_SCRIPTS_DIR/shogun_report_hook.sh"

    export WATCHER_HARNESS="$TEST_TMPDIR/watcher_harness.sh"
    cat > "$WATCHER_HARNESS" << HARNESS
#!/bin/bash
AGENT_ID="shogun"
PANE_TARGET="multiagent:0.1"
CLI_TYPE="claude"
INBOX="$TEST_INBOX_DIR/shogun.yaml"
LOCKFILE="\${INBOX}.lock"
SCRIPT_DIR="$TEST_TMPDIR"

tmux() {
    echo "tmux \$*" >> "$MOCK_LOG"
    if echo "\$*" | grep -q "capture-pane"; then
        echo "\${MOCK_CAPTURE_PANE:-}"
        return 0
    fi
    if echo "\$*" | grep -q "send-keys"; then
        return \${MOCK_SENDKEYS_RC:-0}
    fi
    return 0
}
timeout() { shift; "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
sleep() { :; }
export -f tmux timeout pgrep sleep

export __INBOX_WATCHER_TESTING__=1
source "$WATCHER_SCRIPT"
HARNESS
    chmod +x "$WATCHER_HARNESS"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# T-SH-001: extract_cmd_id — 正常抽出
# =============================================================================

@test "T-SH-001: extract_cmd_id extracts cmd_006 from completion message" {
    run bash -c "source '$HOOK_HARNESS' && extract_cmd_id 'cmd_006完了。達成基準6/6。全タスク完了。'"
    [ "$status" -eq 0 ]
    [ "$output" = "cmd_006" ]
}

# =============================================================================
# T-SH-002: extract_cmd_id — cmd_idなし
# =============================================================================

@test "T-SH-002: extract_cmd_id returns empty when no cmd_id in content" {
    run bash -c "source '$HOOK_HARNESS' && extract_cmd_id 'ただのメッセージです'"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# =============================================================================
# T-SH-003: extract_dashboard_section — 正常抽出
# =============================================================================

@test "T-SH-003: extract_dashboard_section extracts correct cmd section" {
    run bash -c "source '$HOOK_HARNESS' && extract_dashboard_section 'cmd_006' '$TEST_DASHBOARD'"
    [ "$status" -eq 0 ]

    # Contains the cmd_006 header
    echo "$output" | grep -q "cmd_006"
    # Contains acceptance criteria
    echo "$output" | grep -q "6/6"
    # Does NOT contain cmd_005 content
    ! echo "$output" | grep -q "cmd_005"
}

# =============================================================================
# T-SH-004: extract_dashboard_section — 存在しないcmd
# =============================================================================

@test "T-SH-004: extract_dashboard_section returns fallback for unknown cmd" {
    run bash -c "source '$HOOK_HARNESS' && extract_dashboard_section 'cmd_999' '$TEST_DASHBOARD'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "cmd_999の情報がdashboardに見つかりません"
}

# =============================================================================
# T-SH-005: extract_dashboard_section — dashboard不在
# =============================================================================

@test "T-SH-005: extract_dashboard_section handles missing dashboard" {
    run bash -c "source '$HOOK_HARNESS' && extract_dashboard_section 'cmd_006' '/nonexistent/dashboard.md'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "dashboardに見つかりません"
}

# =============================================================================
# T-SH-006: construct_report_prompt — プロンプト形式検証
# =============================================================================

@test "T-SH-006: construct_report_prompt formats prompt correctly" {
    run bash -c "source '$HOOK_HARNESS' && construct_report_prompt 'cmd_006' 'テスト戦果内容'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "【Hook自動注入】cmd_006完了"
    echo "$output" | grep -q "テスト戦果内容"
}

# =============================================================================
# T-SH-007: get_unread_info — cmd_complete が別途返る
# =============================================================================

@test "T-SH-007: get_unread_info returns cmd_completes separately from specials" {
    # Create inbox with cmd_complete + normal message
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'karo', 'timestamp': '2026-02-10T10:00:00',
     'type': 'cmd_complete', 'content': 'cmd_006完了。6/6達成。', 'read': False},
    {'id': 'msg_002', 'from': 'karo', 'timestamp': '2026-02-10T10:01:00',
     'type': 'task_assigned', 'content': '新しいタスク', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    run bash -c "source '$WATCHER_HARNESS' && get_unread_info"
    [ "$status" -eq 0 ]

    # Parse JSON output
    python3 << EOF
import json, sys

data = json.loads('''$output''')

# cmd_completes should contain 1 entry
assert len(data.get('cmd_completes', [])) == 1, f"Expected 1 cmd_complete, got {len(data.get('cmd_completes', []))}"
assert 'cmd_006' in data['cmd_completes'][0]['content'], "cmd_006 not in cmd_complete content"

# specials should be empty (no clear_command or model_switch)
assert len(data.get('specials', [])) == 0, f"Expected 0 specials, got {len(data.get('specials', []))}"

# normal count should be 1 (task_assigned only)
assert data['count'] == 1, f"Expected count=1, got {data['count']}"

print('T-SH-007: PASS')
EOF
}

# =============================================================================
# T-SH-008: get_unread_info — cmd_complete が read:true にマークされる
# =============================================================================

@test "T-SH-008: get_unread_info marks cmd_complete as read in inbox file" {
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'karo', 'timestamp': '2026-02-10T10:00:00',
     'type': 'cmd_complete', 'content': 'cmd_006完了', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    run bash -c "source '$WATCHER_HARNESS' && get_unread_info"
    [ "$status" -eq 0 ]

    # Verify the inbox file was updated with read: true
    python3 << EOF
import yaml

with open('$TEST_INBOX_DIR/shogun.yaml') as f:
    data = yaml.safe_load(f)

msg = data['messages'][0]
assert msg['read'] == True, f"Expected read=True, got {msg['read']}"

print('T-SH-008: PASS')
EOF
}

# =============================================================================
# T-SH-009: get_unread_info — 通常メッセージは count に含まれる
# =============================================================================

@test "T-SH-009: get_unread_info counts normal messages correctly alongside cmd_complete" {
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'karo', 'type': 'cmd_complete',
     'timestamp': '2026-02-10T10:00:00', 'content': 'cmd_006完了', 'read': False},
    {'id': 'msg_002', 'from': 'karo', 'type': 'clear_command',
     'timestamp': '2026-02-10T10:01:00', 'content': '/clear', 'read': False},
    {'id': 'msg_003', 'from': 'ashigaru1', 'type': 'report_received',
     'timestamp': '2026-02-10T10:02:00', 'content': '報告あり', 'read': False},
    {'id': 'msg_004', 'from': 'ashigaru2', 'type': 'wake_up',
     'timestamp': '2026-02-10T10:03:00', 'content': 'テスト', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    run bash -c "source '$WATCHER_HARNESS' && get_unread_info"
    [ "$status" -eq 0 ]

    python3 << EOF
import json

data = json.loads('''$output''')

# 1 cmd_complete, 1 clear_command special, 2 normal (report_received + wake_up)
assert data['count'] == 2, f"Expected normal count=2, got {data['count']}"
assert len(data['specials']) == 1, f"Expected 1 special, got {len(data['specials'])}"
assert len(data['cmd_completes']) == 1, f"Expected 1 cmd_complete, got {len(data['cmd_completes'])}"

print('T-SH-009: PASS')
EOF
}

# =============================================================================
# T-SH-010: handle_cmd_complete — 非shogunエージェントは無視
# =============================================================================

@test "T-SH-010: handle_cmd_complete ignores non-shogun agents" {
    # Create harness with AGENT_ID=ashigaru1
    local NON_SHOGUN_HARNESS="$TEST_TMPDIR/non_shogun_harness.sh"
    cat > "$NON_SHOGUN_HARNESS" << HARNESS
#!/bin/bash
AGENT_ID="ashigaru1"
PANE_TARGET="multiagent:0.2"
CLI_TYPE="claude"
INBOX="$TEST_INBOX_DIR/ashigaru1.yaml"
LOCKFILE="\${INBOX}.lock"
SCRIPT_DIR="$TEST_TMPDIR"

tmux() { echo "tmux \$*" >> "$MOCK_LOG"; return 0; }
timeout() { shift; "\$@"; }
pgrep() { "$MOCK_PGREP" "\$@"; }
sleep() { :; }
export -f tmux timeout pgrep sleep

export __INBOX_WATCHER_TESTING__=1
source "$WATCHER_SCRIPT"
HARNESS
    chmod +x "$NON_SHOGUN_HARNESS"

    > "$HOOK_LOG"
    run bash -c "source '$NON_SHOGUN_HARNESS' && handle_cmd_complete 'cmd_006完了'"
    [ "$status" -eq 0 ]

    # Hook should NOT have been called
    [ ! -s "$HOOK_LOG" ]
    # Warning should be in stderr
    echo "$output" | grep -q "non-shogun"
}

# =============================================================================
# T-SH-011: process_unread — cmd_complete → hook呼び出し
# =============================================================================

@test "T-SH-011: process_unread triggers hook for cmd_complete messages" {
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'karo', 'timestamp': '2026-02-10T10:00:00',
     'type': 'cmd_complete', 'content': 'cmd_006完了。6/6達成。', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    > "$HOOK_LOG"
    run bash -c "source '$WATCHER_HARNESS' && process_unread"
    [ "$status" -eq 0 ]

    # Hook script should have been called
    [ -s "$HOOK_LOG" ]
    grep -q "HOOK_CALLED" "$HOOK_LOG"
    grep -q "cmd_006" "$HOOK_LOG"
}

# =============================================================================
# T-SH-012: process_unread — 通常メッセージは従来通りnudge送信（回帰テスト）
# =============================================================================

@test "T-SH-012: process_unread sends normal nudge for non-cmd_complete messages (regression)" {
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'ashigaru1', 'timestamp': '2026-02-10T10:00:00',
     'type': 'report_received', 'content': '足軽1号報告あり', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    > "$HOOK_LOG"
    run bash -c "source '$WATCHER_HARNESS' && process_unread"
    [ "$status" -eq 0 ]

    # Hook should NOT be called for normal messages
    ! grep -q "HOOK_CALLED" "$HOOK_LOG"

    # Normal nudge should have been sent via send-keys
    grep -q "send-keys.*inbox1" "$MOCK_LOG"
}

# =============================================================================
# T-SH-013: extract_cmd_id — cmd_milestone型メッセージからcmd_id抽出
# =============================================================================

@test "T-SH-013: extract_cmd_id extracts cmd_011 from milestone message" {
    run bash -c "source '$HOOK_HARNESS' && extract_cmd_id 'cmd_011 Phase1完了。設計案を殿に提示し承認を得られたし。'"
    [ "$status" -eq 0 ]
    [ "$output" = "cmd_011" ]
}

# =============================================================================
# T-SH-014: construct_report_prompt — cmd_milestone型で中間報告文言
# =============================================================================

@test "T-SH-014: construct_report_prompt uses milestone wording for cmd_milestone type" {
    run bash -c "source '$HOOK_HARNESS' && construct_report_prompt 'cmd_011' 'Phase1設計完了' 'cmd_milestone'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "【Hook自動注入】cmd_011中間報告"
    echo "$output" | grep -q "判断を仰げ"
    # Must NOT contain "完了。以下の戦果" (that's cmd_complete wording)
    ! echo "$output" | grep -q "以下の戦果を殿に報告せよ"
}

# =============================================================================
# T-SH-015: process_unread — cmd_milestone → hook呼び出し（型伝搬確認）
# =============================================================================

@test "T-SH-015: process_unread triggers hook for cmd_milestone messages" {
    python3 << EOF
import yaml

data = {'messages': [
    {'id': 'msg_001', 'from': 'karo', 'timestamp': '2026-02-10T12:30:00',
     'type': 'cmd_milestone', 'content': 'cmd_011 Phase1完了。設計案を殿に提示し承認を得られたし。', 'read': False}
]}

with open('$TEST_INBOX_DIR/shogun.yaml', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
EOF

    > "$HOOK_LOG"

    # Update mock hook to also capture the msg_type (4th argument)
    cat > "$TEST_SCRIPTS_DIR/shogun_report_hook.sh" << 'MOCK_HOOK'
#!/bin/bash
echo "HOOK_CALLED: content=$1 pane=$2 dashboard=$3 msg_type=$4" >> "${HOOK_LOG:-/dev/null}"
MOCK_HOOK
    chmod +x "$TEST_SCRIPTS_DIR/shogun_report_hook.sh"

    run bash -c "source '$WATCHER_HARNESS' && process_unread"
    [ "$status" -eq 0 ]

    # Hook script should have been called with cmd_milestone type
    [ -s "$HOOK_LOG" ]
    grep -q "HOOK_CALLED" "$HOOK_LOG"
    grep -q "cmd_011" "$HOOK_LOG"
    grep -q "msg_type=cmd_milestone" "$HOOK_LOG"
}
