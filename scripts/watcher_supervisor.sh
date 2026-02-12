#!/usr/bin/env bash
#
# watcher_supervisor.sh
# 全 inbox_watcher プロセスの生存を定期監視し、クラッシュ時に自動再起動する supervisor
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="/tmp/watcher_registry.txt"
MANIFEST_FILE="$SCRIPT_DIR/logs/watcher_manifest.txt"
CHECK_INTERVAL=30

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

spawn_watcher() {
    local agent_id="$1" pane_target="$2" cli_type="$3" env_vars="${4:-}"
    local cmd="bash $SCRIPT_DIR/scripts/inbox_watcher.sh $agent_id $pane_target $cli_type"
    if [ -n "$env_vars" ]; then
        cmd="env $env_vars $cmd"
    fi
    nohup $cmd >> "$SCRIPT_DIR/logs/inbox_watcher_${agent_id}.log" 2>&1 &
    local new_pid=$!
    disown
    echo "$new_pid"
}

init_registry() {
    log "[INIT] Initializing watcher registry..."
    > "$REGISTRY"
    if [ ! -f "$MANIFEST_FILE" ]; then
        log "[WARN] Manifest file not found. Falling back to pgrep-based detection."
        init_registry_fallback
        return
    fi
    local watcher_count=0 spawn_count=0
    while IFS='|' read -r agent_id pane_target cli_type env_vars; do
        agent_id=$(echo "$agent_id" | tr -d '\r')
        pane_target=$(echo "$pane_target" | tr -d '\r')
        cli_type=$(echo "$cli_type" | tr -d '\r')
        env_vars=$(echo "$env_vars" | tr -d '\r')
        [ -z "$agent_id" ] && continue
        [[ "$agent_id" =~ ^# ]] && continue
        local existing_pid=$(pgrep -f "inbox_watcher.sh $agent_id " 2>/dev/null | head -1 || echo "")
        if [ -n "$existing_pid" ]; then
            echo "$existing_pid $agent_id $pane_target $cli_type $env_vars" >> "$REGISTRY"
            watcher_count=$((watcher_count + 1))
        else
            log "[SPAWN] $agent_id watcher spawned (was missing at startup)"
            local new_pid=$(spawn_watcher "$agent_id" "$pane_target" "$cli_type" "$env_vars")
            echo "$new_pid $agent_id $pane_target $cli_type $env_vars" >> "$REGISTRY"
            spawn_count=$((spawn_count + 1))
        fi
    done < "$MANIFEST_FILE"
    local total_count=$((watcher_count + spawn_count))
    if [ "$spawn_count" -gt 0 ]; then
        log "[INIT] Registered $watcher_count existing, spawned $spawn_count new watcher(s)"
    else
        log "[INIT] Registered $total_count watcher(s)"
    fi
}

init_registry_fallback() {
    pgrep -a -f "inbox_watcher.sh" 2>/dev/null | grep -v "watcher_supervisor" | while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $1}')
        local agent_id=$(echo "$line" | awk '{print $4}')
        local pane_target=$(echo "$line" | awk '{print $5}')
        local cli_type=$(echo "$line" | awk '{print $6}')
        if [ -n "$agent_id" ] && [ -n "$pane_target" ] && [ -n "$cli_type" ]; then
            echo "$pid $agent_id $pane_target $cli_type" >> "$REGISTRY"
        fi
    done
    local watcher_count=$(wc -l < "$REGISTRY" 2>/dev/null || echo 0)
    if [ "$watcher_count" -eq 0 ]; then
        log "[WARN] No inbox_watcher processes found at startup."
    else
        log "[INIT] Registered $watcher_count watcher(s) (fallback mode)"
    fi
}

monitor_loop() {
    log "[MONITOR] Starting monitoring loop (interval: ${CHECK_INTERVAL}s)"
    while true; do
        sleep "$CHECK_INTERVAL"
        [ ! -s "$REGISTRY" ] && continue
        local temp_registry="${REGISTRY}.tmp"
        > "$temp_registry"
        while IFS= read -r entry; do
            local pid=$(echo "$entry" | awk '{print $1}')
            local agent_id=$(echo "$entry" | awk '{print $2}')
            local pane_target=$(echo "$entry" | awk '{print $3}')
            local cli_type=$(echo "$entry" | awk '{print $4}')
            local env_vars=$(echo "$entry" | awk '{$1=$2=$3=$4=""; print $0}' | sed 's/^ *//')
            if kill -0 "$pid" 2>/dev/null; then
                echo "$pid $agent_id $pane_target $cli_type $env_vars" >> "$temp_registry"
            else
                log "[RESTART] $agent_id watcher restarted (was PID $pid)"
                local new_pid=$(spawn_watcher "$agent_id" "$pane_target" "$cli_type" "$env_vars")
                echo "$new_pid $agent_id $pane_target $cli_type $env_vars" >> "$temp_registry"
            fi
        done < "$REGISTRY"
        mv "$temp_registry" "$REGISTRY"
    done
}

main() {
    log "[START] watcher_supervisor starting..."
    init_registry
    monitor_loop
}

main
