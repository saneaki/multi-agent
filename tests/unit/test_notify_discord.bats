#!/usr/bin/env bats
# notify.sh Discord backend unit tests.

setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/notify_discord_test.XXXXXX")"
    mkdir -p "$TEST_TMPDIR/scripts" "$TEST_TMPDIR/config"
    cp "$PROJECT_ROOT/scripts/notify.sh" "$TEST_TMPDIR/scripts/notify.sh"
    chmod +x "$TEST_TMPDIR/scripts/notify.sh"

    cat > "$TEST_TMPDIR/scripts/discord_notify.py" <<'PY'
#!/usr/bin/env python3
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("--body", required=True)
parser.add_argument("--title", default="")
parser.add_argument("--type", default="")
parser.add_argument("--chunked", action="store_true")
args = parser.parse_args()

with open(os.environ["DISCORD_NOTIFY_TEST_LOG"], "w", encoding="utf-8") as f:
    f.write(f"body={args.body}\n")
    f.write(f"title={args.title}\n")
    f.write(f"type={args.type}\n")
    f.write(f"chunked={args.chunked}\n")
PY
    chmod +x "$TEST_TMPDIR/scripts/discord_notify.py"
    export DISCORD_NOTIFY_TEST_LOG="$TEST_TMPDIR/discord_notify.log"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "notify.sh dispatches body title and type to Discord backend" {
    run bash "$TEST_TMPDIR/scripts/notify.sh" "hello body" "lord title" "cmd_complete"
    [ "$status" -eq 0 ]
    grep -q "body=hello body" "$DISCORD_NOTIFY_TEST_LOG"
    grep -q "title=lord title" "$DISCORD_NOTIFY_TEST_LOG"
    grep -q "type=cmd_complete" "$DISCORD_NOTIFY_TEST_LOG"
}

@test "notify.sh passes --chunked when NOTIFY_CHUNKED is enabled" {
    run env NOTIFY_CHUNKED=1 bash "$TEST_TMPDIR/scripts/notify.sh" "long body" "lord title" "decision"
    [ "$status" -eq 0 ]
    grep -q "chunked=True" "$DISCORD_NOTIFY_TEST_LOG"
}

@test "notify.sh rejects missing body" {
    run bash "$TEST_TMPDIR/scripts/notify.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"body"* ]]
}

@test "notify.sh rejects retired ntfy backend" {
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=ntfy
EOF

    run bash "$TEST_TMPDIR/scripts/notify.sh" "hello"
    [ "$status" -eq 1 ]
    [[ "$output" == *"retired"* ]]
}

@test "notify.sh rejects unknown backend" {
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=email
EOF

    run bash "$TEST_TMPDIR/scripts/notify.sh" "hello"
    [ "$status" -eq 1 ]
    [[ "$output" == *"expected: discord"* ]]
}

# ============================================================
# cmd_683c: inbox_write.sh の cmd_complete/cmd_milestone gate test
#
# 旧 ntfy_topic 依存 gate を Discord backend prerequisite gate へ置換。
# 以下を verify する:
#   1. discord.env 存在 + 既定 backend → gate OPEN (notify.sh 呼出)
#   2. discord.env 不在 → gate CLOSED
#   3. discord.env 存在 + NOTIFY_BACKEND=ntfy (退役) → gate CLOSED
#   4. TARGET != shogun → gate CLOSED
#   5. TYPE != cmd_complete/cmd_milestone → gate CLOSED
# ============================================================

_gate_setup() {
    # NB: setup() で TEST_TMPDIR/scripts/notify.sh はテスト用 stub 済み。
    # ここでは inbox_write.sh 用の最小ツリーを追加し、
    # notify.sh stub を invocation log へ書き換える。
    mkdir -p "$TEST_TMPDIR/queue/inbox"
    cp "$PROJECT_ROOT/scripts/inbox_write.sh" "$TEST_TMPDIR/scripts/inbox_write.sh"
    chmod +x "$TEST_TMPDIR/scripts/inbox_write.sh"

    # venv は python3 -c '...' で yaml dump を行うため必須
    if [ ! -e "$TEST_TMPDIR/.venv" ]; then
        ln -s "$PROJECT_ROOT/.venv" "$TEST_TMPDIR/.venv"
    fi

    # notify.sh stub: 呼出されたら NOTIFY_STUB_LOG に記録するだけ
    export NOTIFY_STUB_LOG="$TEST_TMPDIR/notify_stub.log"
    cat > "$TEST_TMPDIR/scripts/notify.sh" <<'SH'
#!/usr/bin/env bash
{
  echo "called=1"
  echo "body=$1"
  echo "title=$2"
  echo "type=$3"
} > "$NOTIFY_STUB_LOG"
exit 0
SH
    chmod +x "$TEST_TMPDIR/scripts/notify.sh"
}

@test "inbox_write gate: opens when discord.env exists with default backend (cmd_683c)" {
    _gate_setup
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=discord
DISCORD_BOT_TOKEN=dummy
EOF
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" shogun "cmd_999 完了" cmd_complete ashigaru5
    [ "$status" -eq 0 ]
    [ -f "$NOTIFY_STUB_LOG" ]
    grep -q "called=1" "$NOTIFY_STUB_LOG"
    grep -q "type=cmd_complete" "$NOTIFY_STUB_LOG"
}

@test "inbox_write gate: stays closed when discord.env is absent (cmd_683c)" {
    _gate_setup
    # discord.env intentionally not created
    [ ! -f "$TEST_TMPDIR/config/discord.env" ]
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" shogun "cmd_999 完了" cmd_complete ashigaru5
    [ "$status" -eq 0 ]
    [ ! -f "$NOTIFY_STUB_LOG" ]
}

@test "inbox_write gate: stays closed when NOTIFY_BACKEND=ntfy is set (cmd_683c)" {
    _gate_setup
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=ntfy
EOF
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" shogun "cmd_999 完了" cmd_complete ashigaru5
    [ "$status" -eq 0 ]
    [ ! -f "$NOTIFY_STUB_LOG" ]
}

@test "inbox_write gate: does not fire for non-shogun target (cmd_683c)" {
    _gate_setup
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=discord
EOF
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" karo "cmd_999 完了" cmd_complete ashigaru5
    [ "$status" -eq 0 ]
    [ ! -f "$NOTIFY_STUB_LOG" ]
}

@test "inbox_write gate: does not fire for non cmd_complete/cmd_milestone type (cmd_683c)" {
    _gate_setup
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=discord
EOF
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" shogun "report received" report_received ashigaru5
    [ "$status" -eq 0 ]
    [ ! -f "$NOTIFY_STUB_LOG" ]
}

@test "inbox_write gate: opens for cmd_milestone to shogun (cmd_683c)" {
    _gate_setup
    cat > "$TEST_TMPDIR/config/discord.env" <<'EOF'
NOTIFY_BACKEND=discord
EOF
    run bash "$TEST_TMPDIR/scripts/inbox_write.sh" shogun "cmd_999 phase milestone" cmd_milestone ashigaru5
    [ "$status" -eq 0 ]
    [ -f "$NOTIFY_STUB_LOG" ]
    grep -q "type=cmd_milestone" "$NOTIFY_STUB_LOG"
}
