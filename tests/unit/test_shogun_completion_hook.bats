#!/usr/bin/env bats
# Unit tests for shogun_completion_hook.sh.

setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/shogun_completion_hook.XXXXXX")"
    mkdir -p "$TEST_TMPDIR/scripts" "$TEST_TMPDIR/queue/inbox" "$TEST_TMPDIR/config"
    cp "$PROJECT_ROOT/scripts/shogun_completion_hook.sh" "$TEST_TMPDIR/scripts/shogun_completion_hook.sh"
    cp "$PROJECT_ROOT/scripts/inbox_write.sh" "$TEST_TMPDIR/scripts/inbox_write.sh"
    chmod +x "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" "$TEST_TMPDIR/scripts/inbox_write.sh"
    ln -s "$PROJECT_ROOT/.venv" "$TEST_TMPDIR/.venv"

    export NOTIFY_STUB_LOG="$TEST_TMPDIR/notify.log"
    cat > "$TEST_TMPDIR/scripts/notify.sh" <<'SH'
#!/usr/bin/env bash
{
  echo "body=$1"
  echo "title=$2"
  echo "type=$3"
} >> "$NOTIFY_STUB_LOG"
exit 0
SH
    chmod +x "$TEST_TMPDIR/scripts/notify.sh"

    export SHOGUN_ROOT="$TEST_TMPDIR"
    export SHOGUN_COMPLETION_HOOK_NOW="2026-05-16T00:10:00+00:00"
    export SHOGUN_COMPLETION_HOOK_COOLDOWN_SECONDS=300
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

alert_count() {
    "$TEST_TMPDIR/.venv/bin/python3" - "$TEST_TMPDIR/queue/inbox/shogun.yaml" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
messages = data.get("messages") or []
print(sum(1 for m in messages if m.get("type") == "dual_verification_alert"))
PY
}

write_inbox() {
    cat > "$TEST_TMPDIR/queue/inbox/shogun.yaml"
}

@test "alert generation: old cmd_complete without dual verification creates one alert" {
    write_inbox <<'YAML'
messages:
- id: msg_complete
  from: karo
  timestamp: '2026-05-16T00:00:00+00:00'
  type: cmd_complete
  content: 'cmd_999 完了 — test'
  read: true
YAML

    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    grep -q "alert sent: cmd_999" <<<"$output"
    grep -q "DUAL_VERIFICATION_MISSING:cmd_999" "$TEST_TMPDIR/queue/inbox/shogun.yaml"
    grep -q "type=dual_verification_alert" "$NOTIFY_STUB_LOG"
    [ "$(alert_count)" -eq 1 ]
}

@test "dedup: repeated runs keep one alert per cmd" {
    write_inbox <<'YAML'
messages:
- id: msg_complete
  from: karo
  timestamp: '2026-05-16T00:00:00+00:00'
  type: cmd_complete
  content: 'cmd_999 完了 — test'
  read: true
YAML

    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    grep -q "dedup skip: cmd_999" <<<"$output"
    [ "$(alert_count)" -eq 1 ]
}

@test "cooldown: recent cmd_complete does not alert before cooldown expires" {
    write_inbox <<'YAML'
messages:
- id: msg_complete
  from: karo
  timestamp: '2026-05-16T00:08:30+00:00'
  type: cmd_complete
  content: 'cmd_999 完了 — test'
  read: true
YAML

    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    grep -q "cooldown skip: cmd_999" <<<"$output"
    [ "$(alert_count)" -eq 0 ]
}

@test "evidence: dual_verification_started marker suppresses alert" {
    write_inbox <<'YAML'
messages:
- id: msg_complete
  from: karo
  timestamp: '2026-05-16T00:00:00+00:00'
  type: cmd_complete
  content: 'cmd_999 完了 — test'
  read: true
- id: msg_started
  from: shogun
  timestamp: '2026-05-16T00:01:00+00:00'
  type: dual_verification_started
  content: 'cmd_999 dual-verification started: implementation-verifier(run_in_background=true) + Codex arm(effort=xhigh)'
  read: true
YAML

    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    grep -q "evidence skip: cmd_999" <<<"$output"
    [ "$(alert_count)" -eq 0 ]
}

@test "evidence: cmd_complete text itself is not counted as Codex proof" {
    write_inbox <<'YAML'
messages:
- id: msg_complete
  from: karo
  timestamp: '2026-05-16T00:00:00+00:00'
  type: cmd_complete
  content: 'cmd_999 完了 — 事前Codex検証済み'
  read: true
- id: msg_impl
  from: implementation-verifier
  timestamp: '2026-05-16T00:02:00+00:00'
  type: report_completed
  content: 'cmd_999 implementation verification started'
  read: true
YAML

    run bash "$TEST_TMPDIR/scripts/shogun_completion_hook.sh" --cmd-id cmd_999
    [ "$status" -eq 0 ]
    grep -q "alert sent: cmd_999" <<<"$output"
    [ "$(alert_count)" -eq 1 ]
}
