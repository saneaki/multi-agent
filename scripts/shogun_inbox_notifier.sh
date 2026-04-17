#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shogun_inbox_notifier.sh — dashboard.md 🏆🏆 検知 → shogun inbox 自動通知
#
# 概要:
#   cmd_complete_notifier.sh と同じ 🏆🏆 トリガーを監視し、
#   cmd 完了時に queue/inbox/shogun.yaml へ cmd_complete メッセージを自動投函。
#   karo が手動 inbox_write を忘れた場合の二重安全網(Fix B: cmd_538)。
#
# 動作:
#   - inotifywait で dashboard.md を常時監視
#   - 🏆🏆cmd_NNN COMPLETE 行検知時:
#       - cmd_NNN を抽出
#       - bash scripts/inbox_write.sh shogun "cmd_NNN 完了" cmd_complete karo
#       - logs/shogun_inbox_notified.txt で cmd_NNN dedup
#
# 起動: watcher_supervisor.sh から nohup で起動される
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PIDFILE="/home/ubuntu/shogun/logs/shogun_inbox_notifier.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (PID $(cat "$PIDFILE")). Exiting." >&2
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

DASHBOARD="$SCRIPT_DIR/dashboard.md"
STATE_FILE="$SCRIPT_DIR/logs/shogun_inbox_notified.txt"
LOG_FILE="$SCRIPT_DIR/logs/shogun_inbox_notifier.log"

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_and_notify() {
    if [ ! -f "$DASHBOARD" ]; then
        return 0
    fi

    while IFS= read -r line; do
        cmd_id=$(echo "$line" | grep -oP 'cmd_\d+' | head -1 || true)
        if [ -z "$cmd_id" ]; then
            continue
        fi

        # dedup チェック
        if grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            continue
        fi

        # 完了概要を抽出 (3列目のテキスト)
        summary=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^ *//; s/ *$//' | head -c 80 || true)

        log "Sending shogun inbox for $cmd_id: $summary"
        if bash "$SCRIPT_DIR/scripts/inbox_write.sh" \
            "shogun" \
            "${cmd_id} 完了 — ${summary}" \
            "cmd_complete" \
            "karo" >> "$LOG_FILE" 2>&1; then
            echo "$cmd_id" >> "$STATE_FILE"
            log "shogun inbox sent: $cmd_id"
        else
            log "shogun inbox FAILED for $cmd_id"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep '🏆🏆' | grep -P 'cmd_\d+' || true)
}

log "shogun_inbox_notifier started (🏆🏆 trigger). Watching: $DASHBOARD"

# 起動時 dedup: 既存 🏆🏆 行を state に登録して再通知防止
if [ -f "$DASHBOARD" ]; then
    while IFS= read -r line; do
        cmd_id=$(echo "$line" | grep -oP 'cmd_\d+' | head -1 || true)
        if [ -n "$cmd_id" ] && ! grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            echo "$cmd_id" >> "$STATE_FILE"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep '🏆🏆' | grep -P 'cmd_\d+' || true)
    log "Initial state loaded: $(wc -l < "$STATE_FILE") cmd IDs registered (no re-notification)"
fi

if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotifywait not found. Cannot watch dashboard.md"
    exit 1
fi

while true; do
    if inotifywait -q -t 60 -e modify,close_write,moved_to "$DASHBOARD" >> "$LOG_FILE" 2>&1; then
        log "dashboard.md changed, checking for new cmd completions"
        check_and_notify
    else
        check_and_notify
    fi
done
