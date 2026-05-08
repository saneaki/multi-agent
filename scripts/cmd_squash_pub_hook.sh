#!/usr/bin/env bash
# cmd_squash_pub_hook.sh - dashboard.md の 🏆🏆cmd_NNN COMPLETE を検知して squash + /pub-us 起動
# Refs cmd_539 / cmd_544 (3 安全装置: kill-switch / rate-limit + pending queue / daily metric)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

PIDFILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.pid"
LOCKFILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.lock"
STATE_FILE="$SCRIPT_DIR/logs/squash_pub_notified.txt"
LOG_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.log"
DASHBOARD="$SCRIPT_DIR/dashboard.md"

# cmd_544: 3 安全装置用 state files
KILL_SWITCH_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.disabled"
KILL_SWITCH_DIR="$(dirname "$KILL_SWITCH_FILE")"
RATE_TS_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.rate_limit_at"
RATE_LIMIT_SECONDS="${CMD_SQUASH_PUB_RATE_LIMIT_SECONDS:-1800}"
case "$RATE_LIMIT_SECONDS" in
    ''|*[!0-9]*) RATE_LIMIT_SECONDS=1800 ;;
esac
PENDING_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.pending_cmds"
PENDING_TTL_SECONDS=86400
PENDING_MAX_LINES=500
METRIC_FILE="$SCRIPT_DIR/logs/cmd_squash_pub_hook.daily.yaml"

log() {
    local ts
    ts=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+09:00")
    echo "[$ts] $*" >> "$LOG_FILE"
}

# cmd_544 (1): kill-switch
is_kill_switched() {
    [ -f "$KILL_SWITCH_FILE" ]
}

# cmd_544 (2): rate limit (sug_003 fallback 込)
is_rate_limited_now() {
    local now last elapsed
    now=$(date +%s)
    [ -f "$RATE_TS_FILE" ] || return 1
    last=$(cat "$RATE_TS_FILE" 2>/dev/null || echo 0)
    case "$last" in
        ''|*[!0-9]*)
            log "WARN: RATE_TS_FILE corrupted (value=\"$last\"), treating as 0"
            last=0
            ;;
    esac
    elapsed=$((now - last))
    [ "$elapsed" -lt "$RATE_LIMIT_SECONDS" ]
}

# cmd_544 (2): pending queue (TTL 24h / 上限 500行)
enqueue_pending_cmd() {
    local cmd_id="$1"
    touch "$PENDING_FILE"
    if grep -qE "^${cmd_id}[[:space:]]" "$PENDING_FILE" 2>/dev/null; then
        return 0
    fi
    local line_count
    line_count=$(wc -l < "$PENDING_FILE" 2>/dev/null || echo 0)
    case "$line_count" in ''|*[!0-9]*) line_count=0 ;; esac
    if [ "$line_count" -ge "$PENDING_MAX_LINES" ]; then
        log "WARN: PENDING_FILE exceeded $PENDING_MAX_LINES lines, dropping oldest"
        tail -n $((PENDING_MAX_LINES - 1)) "$PENDING_FILE" > "${PENDING_FILE}.tmp"
        mv "${PENDING_FILE}.tmp" "$PENDING_FILE"
    fi
    printf '%s\t%s\n' "$cmd_id" "$(date +%s)" >> "$PENDING_FILE"
    log "pending: enqueued $cmd_id"
}

drain_pending_cmds() {
    # stdout = 有効な cmd_id 一覧 (caller の $(...) で読む)
    # log 出力は stderr にリダイレクトして stdout 汚染防止
    [ -f "$PENDING_FILE" ] || return 0
    local now
    now=$(date +%s)
    local fresh_file="${PENDING_FILE}.tmp"
    : > "$fresh_file"
    while IFS=$'\t' read -r cmd_id ts; do
        [ -z "$cmd_id" ] && continue
        case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
        local age=$((now - ts))
        if [ "$age" -gt "$PENDING_TTL_SECONDS" ]; then
            log "WARN: pending cmd $cmd_id expired (age=${age}s > TTL=${PENDING_TTL_SECONDS}s), dropped" >&2
            continue
        fi
        echo "$cmd_id"
        printf '%s\t%s\n' "$cmd_id" "$ts" >> "$fresh_file"
    done < "$PENDING_FILE"
    mv "$fresh_file" "$PENDING_FILE"
}

# cmd_544 (3): daily metric (3 指標 YAML / JST 日次リセット)
_metric_create() {
    local current_jst="$1"
    local ts_yaml
    ts_yaml=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+09:00")
    cat > "$METRIC_FILE" <<YAML
date_jst: "$current_jst"
attempt_total: 0
success_total: 0
failure_total: 0
updated_at: "$ts_yaml"
YAML
}

metric_init_if_needed() {
    local current_jst="$1"
    [ -f "$METRIC_FILE" ] || { _metric_create "$current_jst"; return 0; }
    local stored_jst
    stored_jst=$(awk -F': ' '/^date_jst:/ {gsub(/"/,"",$2); print $2}' "$METRIC_FILE" 2>/dev/null)
    if [ "$stored_jst" != "$current_jst" ]; then
        log "metric: JST date changed ($stored_jst -> $current_jst), reset counters"
        _metric_create "$current_jst"
    fi
}

_metric_bump() {
    local key="$1"
    local current_jst
    current_jst=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --date 2>/dev/null || date +%Y-%m-%d)
    metric_init_if_needed "$current_jst"
    local stored_value
    stored_value=$(awk -F': ' "/^${key}:/ {gsub(/\"/,\"\",\$2); print \$2}" "$METRIC_FILE" 2>/dev/null)
    case "$stored_value" in ''|*[!0-9]*) stored_value=0 ;; esac
    local new_value=$((stored_value + 1))
    local ts_yaml
    ts_yaml=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+09:00")
    sed -i "s/^${key}:.*/${key}: ${new_value}/" "$METRIC_FILE"
    sed -i "s|^updated_at:.*|updated_at: \"${ts_yaml}\"|" "$METRIC_FILE"
}

metric_inc_attempt() { _metric_bump attempt_total; }
metric_inc_success() { _metric_bump success_total; }
metric_inc_failure() { _metric_bump failure_total; }

# 戦果テーブル抽出
extract_cmd_id() {
    echo "$1" | awk -F'|' '{print $4}' | grep -oE 'cmd_[0-9]+' | head -1
}

get_complete_lines() {
    [ -f "$DASHBOARD" ] || return 0
    grep -E '^\| [0-9]{2}:[0-9]{2} \|' "$DASHBOARD" || true
}

# invoke_pub_us: 戻り値規約 0=成功 / 1=失敗 / 2=kill-switch
invoke_pub_us() {
    local amend_flag="$1"
    # G4-A: claude 経路ガード
    if is_kill_switched; then
        log "KILL-SWITCH: publish blocked (claude path)"
        return 2
    fi
    metric_inc_attempt
    if command -v claude >/dev/null 2>&1; then
        nohup claude -p "/pub-us ${amend_flag}" >> "$SCRIPT_DIR/logs/pub_us_hook.log" 2>&1 &
        local claude_pid=$!
        log "claude -p '/pub-us ${amend_flag}' invoked (PID $claude_pid)"
        # fire-and-forget: 起動成功 = metric success
        metric_inc_success
        return 0
    fi
    log "WARN: claude CLI not found -- fallback to plain push"
    # G4-B: plain push 経路ガード (再評価)
    if is_kill_switched; then
        log "KILL-SWITCH: fallback push blocked"
        return 2
    fi
    if git push origin main >> "$LOG_FILE" 2>&1; then
        metric_inc_success
        return 0
    else
        log "ERROR: plain push failed"
        metric_inc_failure
        return 1
    fi
}

# squash_and_pub: kill-switch 冒頭ガード + 戻り値で state/pending 分岐
squash_and_pub() {
    local cmd_id="$1"
    # kill-switch 冒頭ガード (squash 自体抑止)
    if is_kill_switched; then
        log "KILL-SWITCH: squash_and_pub skipped for $cmd_id"
        return 0
    fi
    log "squash_and_pub start: $cmd_id"

    # S1: unpushed commits を grep (E6: word boundary \b)
    local commits
    commits=$(git log origin/main..HEAD --grep="Refs ${cmd_id}\b" --oneline 2>/dev/null || true)
    local count=0
    if [ -n "$commits" ]; then
        count=$(printf '%s\n' "$commits" | grep -c '^' 2>/dev/null || echo 0)
    fi

    if [ "$count" -eq 0 ]; then
        log "SKIP: no unpushed commits for $cmd_id"
        echo "$cmd_id" >> "$STATE_FILE"
        return 0
    fi

    local amend_flag=""
    if [ "$count" -eq 1 ]; then
        log "1 commit for $cmd_id -- /pub-us only (no squash)"
        amend_flag=""
    else
        log "$count commits for $cmd_id -- squash + /pub-us --amend"
        local orig_head
        orig_head=$(git rev-parse HEAD)

        # S2: soft reset -> squash commit, rollback on failure
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
        amend_flag="--amend"
    fi

    # invoke_pub_us 戻り値分岐 (B案: 0=state登録 / 1=pending / 2=何もしない)
    local rc=0
    invoke_pub_us "$amend_flag" || rc=$?
    case "$rc" in
        0)
            date +%s > "$RATE_TS_FILE"
            echo "$cmd_id" >> "$STATE_FILE"
            log "squash_and_pub done: $cmd_id"
            bash "$SCRIPT_DIR/scripts/update_dashboard.sh" >/dev/null 2>&1 || log "update_dashboard.sh call failed (non-fatal; cwd=$(pwd); script=$SCRIPT_DIR/scripts/update_dashboard.sh)"
            return 0
            ;;
        1)
            log "pub_us failed for $cmd_id, enqueuing pending"
            enqueue_pending_cmd "$cmd_id"
            return 1
            ;;
        2)
            log "KILL-SWITCH active, $cmd_id not state-registered (will retry after unblock)"
            return 2
            ;;
        *)
            log "ERROR: unknown invoke_pub_us rc=$rc for $cmd_id"
            return 1
            ;;
    esac
}

# _run_check: kill-switch 早期return + drain pending 統合
_run_check() {
    if is_kill_switched; then
        log "KILL-SWITCH: _run_check skipped"
        return 0
    fi
    [ -f "$DASHBOARD" ] || return 0

    # rate-limit 分岐: 窓内なら enqueue のみ
    if is_rate_limited_now; then
        log "rate-limit: window active, enqueue only (no publish)"
        while IFS= read -r line; do
            local cmd_id_rl
            cmd_id_rl=$(extract_cmd_id "$line") || continue
            [ -z "$cmd_id_rl" ] && continue
            grep -qxF "$cmd_id_rl" "$STATE_FILE" 2>/dev/null && continue
            enqueue_pending_cmd "$cmd_id_rl"
        done < <(get_complete_lines)
        return 0
    fi

    # 窓明け: pending drain + 新規統合処理
    local pending_ids=""
    pending_ids=$(drain_pending_cmds || true)
    local all_ids=""
    if [ -n "$pending_ids" ]; then
        all_ids="$pending_ids"$'\n'
    fi
    while IFS= read -r line; do
        local cmd_id
        cmd_id=$(extract_cmd_id "$line") || continue
        [ -z "$cmd_id" ] && continue
        all_ids="${all_ids}${cmd_id}"$'\n'
    done < <(get_complete_lines)

    # 重複除外して処理
    local processed=""
    while IFS= read -r cmd_id; do
        [ -z "$cmd_id" ] && continue
        if is_kill_switched; then
            log "KILL-SWITCH: _run_check loop aborted"
            return 0
        fi
        case "$processed" in *"|${cmd_id}|"*) continue ;; esac
        processed="${processed}|${cmd_id}|"
        grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null && continue
        squash_and_pub "$cmd_id" || true
    done <<< "$all_ids"
}

# check_and_squash: kill-switch lock取得前ガード + flock
check_and_squash() {
    if is_kill_switched; then
        log "KILL-SWITCH: check_and_squash skipped (lock not acquired)"
        return 0
    fi
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

# Test harness hook: skip main execution when sourced by test suite
if [ "${CMD_SQUASH_PUB_HOOK_TEST:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# PID singleton
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

mkdir -p "$SCRIPT_DIR/logs"
touch "$STATE_FILE"

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
    # wake-up 直後 kill-switch 短絡
    if is_kill_switched; then
        log "KILL-SWITCH: watch loop paused (5s sleep)"
        sleep 5
        continue
    fi
    # inotify 監視: DASHBOARD + KILL_SWITCH_DIR (flag の即応) + logs/ の自己ループ除外
    inotifywait -q -t 60 -e modify,close_write,create,delete \
        --exclude '\.daily\.yaml$|\.rate_limit_at$|\.pending_cmds$|\.log$|\.pid$|\.lock$|squash_pub_notified\.txt$|\.tmp$' \
        "$DASHBOARD" "$KILL_SWITCH_DIR" >> "$LOG_FILE" 2>&1 || true
    check_and_squash
done
