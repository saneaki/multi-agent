#!/usr/bin/env bash
# cmd_squash_pub_hook.sh - dashboard.md の 🏆🏆cmd_NNN COMPLETE を検知して squash + /pub-us 起動
# Refs cmd_539
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

PIDFILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.pid"
LOCKFILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.lock"
STATE_FILE="$SCRIPT_DIR/logs/squash_pub_notified.txt"
LOG_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.log"
DASHBOARD="$SCRIPT_DIR/dashboard.md"

# PID singleton
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

mkdir -p "$SCRIPT_DIR/logs"
touch "$STATE_FILE"

log() {
    local ts
    ts=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+09:00")
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

# E6: word boundary で誤マッチ防止
extract_cmd_id() {
    echo "$1" | grep -oE '🏆🏆cmd_[0-9]+' | head -1 | sed 's/🏆🏆//'
}

get_complete_lines() {
    [ -f "$DASHBOARD" ] || return 0
    grep -E '🏆🏆cmd_[0-9]+' "$DASHBOARD" || true
}

invoke_pub_us() {
    local amend_flag="$1"
    if command -v claude >/dev/null 2>&1; then
        nohup claude -p "/pub-us ${amend_flag}" >> "$SCRIPT_DIR/logs/pub_us_hook.log" 2>&1 &
        log "claude -p '/pub-us ${amend_flag}' invoked (PID $!)"
    else
        log "WARN: claude CLI not found — fallback to plain push"
        git push origin main >> "$LOG_FILE" 2>&1 || log "ERROR: plain push failed"
    fi
}

squash_and_pub() {
    local cmd_id="$1"
    log "squash_and_pub start: $cmd_id"

    # S1: unpushed commits を grep (E6: word boundary \b)
    local commits
    commits=$(git log origin/main..HEAD --grep="Refs ${cmd_id}\b" --oneline 2>/dev/null || true)
    local count
    count=$(echo "$commits" | grep -c . 2>/dev/null || echo 0)

    if [ "$count" -eq 0 ]; then
        log "SKIP: no unpushed commits for $cmd_id"
        echo "$cmd_id" >> "$STATE_FILE"
        return 0
    fi

    if [ "$count" -eq 1 ]; then
        log "1 commit for $cmd_id — /pub-us only (no squash)"
        invoke_pub_us ""
    else
        log "$count commits for $cmd_id — squash + /pub-us --amend"
        local orig_head
        orig_head=$(git rev-parse HEAD)

        # S2: soft reset → squash commit, rollback on failure
        if ! git reset --soft "HEAD~${count}"; then
            log "ERROR: soft reset failed, rollback"
            git reset --hard "$orig_head"
            return 1
        fi

        local commit_msg
        commit_msg="feat(${cmd_id}): squashed ${count} commits

${commits}

Refs ${cmd_id}"

        if ! git commit -m "$commit_msg"; then
            log "ERROR: squash commit failed, rollback"
            git reset --hard "$orig_head"
            return 1
        fi
        invoke_pub_us "--amend"
    fi

    echo "$cmd_id" >> "$STATE_FILE"
    log "squash_and_pub done: $cmd_id"
}

_run_check() {
    [ -f "$DASHBOARD" ] || return 0
    while IFS= read -r line; do
        local cmd_id
        cmd_id=$(extract_cmd_id "$line") || continue
        [ -z "$cmd_id" ] && continue
        grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null && continue
        squash_and_pub "$cmd_id"
    done < <(get_complete_lines)
}

check_and_squash() {
    # S5: flock で並列 race 防止 (E1 対応)
    if command -v flock >/dev/null 2>&1; then
        (
            flock -x -w 60 200 || { log "flock timeout"; exit 1; }
            _run_check
        ) 200>"$LOCKFILE"
    else
        # macOS fallback: mkdir mutex
        local _ld="${LOCKFILE}.d"
        local _i=0
        while ! mkdir "$_ld" 2>/dev/null; do
            sleep 0.1
            _i=$((_i + 1))
            [ "$_i" -ge 600 ] && { log "lock timeout (mkdir)"; return 1; }
        done
        trap 'rmdir "$_ld" 2>/dev/null; rm -f "$PIDFILE"' EXIT
        _run_check
        rmdir "$_ld" 2>/dev/null || true
    fi
}

# S7: 起動時 bulk-push 防止 — 既存 COMPLETE 行は state 登録のみ
log "startup: registering existing COMPLETE entries (no push)"
while IFS= read -r line; do
    local_id=$(extract_cmd_id "$line") || true
    if [ -n "${local_id:-}" ]; then
        grep -qxF "$local_id" "$STATE_FILE" 2>/dev/null || echo "$local_id" >> "$STATE_FILE"
    fi
done < <(get_complete_lines)
log "startup dedup done"

log "watch loop start: $DASHBOARD"
while true; do
    inotifywait -q -t 60 -e modify,close_write "$DASHBOARD" >> "$LOG_FILE" 2>&1 || true
    check_and_squash
done
