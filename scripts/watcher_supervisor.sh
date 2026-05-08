#!/usr/bin/env bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox

SUPERVISOR_LOCK="$SCRIPT_DIR/logs/watcher_supervisor.lock"

mode="${1:-daemon}"

log_supervisor() {
    printf '[%s] [watcher_supervisor] %s\n' "$(bash "$SCRIPT_DIR/scripts/jst_now.sh")" "$*"
}

pid_is_alive() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

cleanup_stale_pid_file() {
    local pid_file="$1"
    local pid=""

    [ -f "$pid_file" ] || return 0
    pid="$(head -n 1 "$pid_file" | tr -d '[:space:]' || true)"
    if ! pid_is_alive "$pid"; then
        log_supervisor "removing stale pid file: $pid_file (pid=${pid:-empty})"
        rm -f "$pid_file"
    fi
}

cleanup_stale_lock_file() {
    local lock_file="$1"
    local pid=""

    [ -f "$lock_file" ] || return 0
    pid="$(head -n 1 "$lock_file" | tr -d '[:space:]' || true)"
    if ! pid_is_alive "$pid"; then
        log_supervisor "removing stale lock file: $lock_file (pid=${pid:-empty})"
        rm -f "$lock_file"
    fi
}

cleanup_stale_runtime_files() {
    local pid_file

    for pid_file in "$SCRIPT_DIR"/logs/*.pid; do
        [ -e "$pid_file" ] || continue
        cleanup_stale_pid_file "$pid_file"
    done
    cleanup_stale_lock_file "$SUPERVISOR_LOCK"
}

supervisor_pid_from_lock() {
    local pid=""

    if [ -f "$SUPERVISOR_LOCK" ]; then
        pid="$(head -n 1 "$SUPERVISOR_LOCK" | tr -d '[:space:]' || true)"
    fi
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid"
        return 0
    fi

    pid="$(pgrep -fo "bash /home/ubuntu/shogun/scripts/watcher_supervisor.sh" || true)"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid"
        return 0
    fi

    return 1
}

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

pane_exists() {
    local pane="$1"
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$pane"
}

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="$3"
    local cli

    ensure_inbox_file "$agent"
    if ! pane_exists "$pane"; then
        return 0
    fi

    if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
        return 0
    fi

    cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "codex")
    nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
}

start_cmd_notifier_if_missing() {
    if pgrep -f "scripts/cmd_complete_notifier.sh" >/dev/null 2>&1; then
        return 0
    fi
    log_supervisor "cmd_complete_notifier.sh missing; starting"
    nohup bash scripts/cmd_complete_notifier.sh >> "logs/cmd_complete_notifier.log" 2>&1 &
}

start_shogun_inbox_notifier_if_missing() {
    if pgrep -f "scripts/shogun_inbox_notifier.sh" >/dev/null 2>&1; then
        return 0
    fi
    log_supervisor "shogun_inbox_notifier.sh missing; starting"
    nohup bash scripts/shogun_inbox_notifier.sh >> "logs/shogun_inbox_notifier.log" 2>&1 &
}

start_cmd_squash_pub_hook_if_missing() {
    if pgrep -f "scripts/cmd_squash_pub_hook.sh" >/dev/null 2>&1; then
        return 0
    fi
    nohup bash scripts/cmd_squash_pub_hook.sh >> "logs/cmd_squash_pub_hook.log" 2>&1 &
}

# ウェルカム画面検出: 'Try "' パターン ('bypass permissions' はアクティブプロンプトにも出るため除外)
is_welcome_screen() {
    local pane="$1"
    tmux capture-pane -t "$pane" -p 2>/dev/null | grep -qE 'Try "'
}

# 定期点呼: ウェルカム画面停止エージェントを検出し自動復旧
roll_call_check() {
    local timestamp
    timestamp=$(bash "$SCRIPT_DIR/scripts/jst_now.sh")

    declare -A AGENT_PANES
    AGENT_PANES=(
        [karo]="multiagent:agents.0"
        [ashigaru1]="multiagent:agents.9"
        [ashigaru2]="multiagent:agents.2"
        [ashigaru3]="multiagent:agents.3"
        [ashigaru4]="multiagent:agents.4"
        [ashigaru5]="multiagent:agents.5"
        [ashigaru6]="multiagent:agents.6"
        [ashigaru7]="multiagent:agents.7"
        [gunshi]="multiagent:agents.8"
    )

    for agent in karo ashigaru1 ashigaru2 ashigaru3 ashigaru4 ashigaru5 ashigaru6 ashigaru7 gunshi; do
        local pane="${AGENT_PANES[$agent]}"

        # ペインが存在しない場合はスキップ
        if ! pane_exists "$pane"; then
            continue
        fi

        if is_welcome_screen "$pane"; then
            echo "[ROLL-CALL] [$timestamp] ${agent}: DEAD → sending role name..."
            tmux send-keys -t "$pane" "$agent"
            sleep 0.3
            tmux send-keys -t "$pane" Enter

            # 30秒後に確認
            sleep 30
            if ! is_welcome_screen "$pane"; then
                echo "[ROLL-CALL] [$timestamp] ${agent}: REVIVED"
            else
                echo "[ROLL-CALL] [$timestamp] ${agent}: DEAD (unreachable after retry)"
            fi
        else
            echo "[ROLL-CALL] [$timestamp] ${agent}: ALIVE"
        fi
    done
}

ROLL_CALL_LAST=0

start_daemon() {
    cleanup_stale_runtime_files

    # 多重起動防止: PIDファイルロック
    exec 9>"$SUPERVISOR_LOCK"
    if ! flock -n 9; then
        echo "[$(date)] [watcher_supervisor] Already running (lock: $SUPERVISOR_LOCK). Exiting." >&2
        exit 1
    fi
    printf '%s\n' "$$" > "$SUPERVISOR_LOCK"

    while true; do
        start_watcher_if_missing "shogun" "shogun:main.0" "logs/inbox_watcher_shogun.log"
        start_watcher_if_missing "karo" "multiagent:agents.0" "logs/inbox_watcher_karo.log"
        start_watcher_if_missing "ashigaru1" "multiagent:agents.9" "logs/inbox_watcher_ashigaru1.log"
        start_watcher_if_missing "ashigaru2" "multiagent:agents.2" "logs/inbox_watcher_ashigaru2.log"
        start_watcher_if_missing "ashigaru3" "multiagent:agents.3" "logs/inbox_watcher_ashigaru3.log"
        start_watcher_if_missing "ashigaru4" "multiagent:agents.4" "logs/inbox_watcher_ashigaru4.log"
        start_watcher_if_missing "ashigaru5" "multiagent:agents.5" "logs/inbox_watcher_ashigaru5.log"
        start_watcher_if_missing "ashigaru6" "multiagent:agents.6" "logs/inbox_watcher_ashigaru6.log"
        start_watcher_if_missing "ashigaru7" "multiagent:agents.7" "logs/inbox_watcher_ashigaru7.log"
        start_watcher_if_missing "gunshi" "multiagent:agents.8" "logs/inbox_watcher_gunshi.log"
        start_cmd_notifier_if_missing
        start_shogun_inbox_notifier_if_missing
        start_cmd_squash_pub_hook_if_missing

        # 定期点呼: 5分間隔（300秒）
        _now=$(date +%s)
        if (( _now - ROLL_CALL_LAST >= 300 )); then
            roll_call_check 2>&1 | tee -a "$SCRIPT_DIR/logs/roll_call.log" || true
            ROLL_CALL_LAST=$_now
        fi

        sleep 5
    done
}

restart_daemon() {
    local old_pid current_pid deadline
    old_pid="$(supervisor_pid_from_lock || true)"

    if [ -n "$old_pid" ]; then
        echo "[$(date)] [watcher_supervisor] stopping old supervisor PID=$old_pid"
        kill -TERM "$old_pid"
        deadline=$((SECONDS + 5))
        while kill -0 "$old_pid" 2>/dev/null; do
            if (( SECONDS >= deadline )); then
                echo "[$(date)] [watcher_supervisor] old supervisor PID=$old_pid did not stop within 5s." >&2
                exit 1
            fi
            sleep 0.2
        done
    fi

    nohup bash "$0" daemon >> "logs/watcher_supervisor.log" 2>&1 &
    sleep 1

    current_pid="$(supervisor_pid_from_lock || true)"
    if [ -z "$current_pid" ]; then
        echo "[$(date)] [watcher_supervisor] restart failed: daemon lock not acquired." >&2
        exit 1
    fi

    if [ -n "$old_pid" ] && [ "$current_pid" = "$old_pid" ]; then
        echo "[$(date)] [watcher_supervisor] restart failed: lock still owned by old PID=$old_pid." >&2
        exit 1
    fi

    echo "[$(date)] [watcher_supervisor] restarted successfully (PID=$current_pid)"
}

case "$mode" in
    restart)
        restart_daemon
        ;;
    daemon|"")
        start_daemon
        ;;
    *)
        echo "Usage: $0 [daemon|restart]" >&2
        exit 1
        ;;
esac
