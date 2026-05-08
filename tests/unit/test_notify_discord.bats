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
args = parser.parse_args()

with open(os.environ["DISCORD_NOTIFY_TEST_LOG"], "w", encoding="utf-8") as f:
    f.write(f"body={args.body}\n")
    f.write(f"title={args.title}\n")
    f.write(f"type={args.type}\n")
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
