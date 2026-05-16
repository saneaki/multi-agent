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
#
# テスト用 env vars (本番では設定不要):
#   SHOGUN_NOTIFIER_PIDFILE  — PIDFILE パスを上書き
#   SHOGUN_SCRIPT_DIR        — SCRIPT_DIR を上書き (ログ/state/dashboard パスに影響)
#   SKIP_MAIN_LOOP           — 1 に設定すると watch ループをスキップして終了
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# B5-3: 二重起動防止 (flock 優先、macOS 等 flock 不在時は mkdir lock にフォールバック)
PIDFILE="${SHOGUN_NOTIFIER_PIDFILE:-/home/ubuntu/shogun/logs/shogun_inbox_notifier.pid}"
mkdir -p "$(dirname "$PIDFILE")"
if command -v flock &>/dev/null; then
    exec 200>"$PIDFILE"
    if ! flock -n 200; then
        echo "Already running. Exiting." >&2
        exit 0
    fi
    echo $$ >&200
    trap 'rm -f "$PIDFILE"' EXIT
else
    _LOCKDIR="${PIDFILE}.lock"
    if ! mkdir "$_LOCKDIR" 2>/dev/null; then
        echo "Already running. Exiting." >&2
        exit 0
    fi
    echo $$ > "$PIDFILE"
    trap 'rm -f "$PIDFILE"; rmdir "$_LOCKDIR" 2>/dev/null || true' EXIT
fi

SCRIPT_DIR="${SHOGUN_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$SCRIPT_DIR"

DASHBOARD="$SCRIPT_DIR/dashboard.md"
STATE_FILE="$SCRIPT_DIR/logs/shogun_inbox_notified.txt"
LOG_FILE="$SCRIPT_DIR/logs/shogun_inbox_notifier.log"

mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

# B5-1: tee を排除し LOG_FILE へ 1 回だけ書き込む
#   旧: echo "..." | tee -a "$LOG_FILE"  → tee + nohup redirect で二重書込み
#   新: echo "..." >> "$LOG_FILE"        → 直接書込みのみ
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

check_and_notify() {
    if [ ! -f "$DASHBOARD" ]; then
        return 0
    fi

    while IFS= read -r line; do
        # 戦果テーブル行の3列目(任務列)から cmd_NNN を抽出
        cmd_id=$(echo "$line" | awk -F'|' '{print $4}' | grep -oE 'cmd_[0-9]+' | head -1 || true)
        if [ -z "$cmd_id" ]; then
            continue
        fi

        # dedup チェック
        if grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            continue
        fi

        # 完了概要を抽出 (3列目のテキスト)
        summary=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^ *//; s/ *$//')
        summary="${summary:0:80}"

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
    done < <(grep -E '^\| [0-9]{2}:[0-9]{2} \|' "$DASHBOARD" || true)
}

log "shogun_inbox_notifier started (🏆🏆 trigger). Watching: $DASHBOARD"

# 起動時 dedup: 既存戦果テーブル行を state に登録して再通知防止
if [ -f "$DASHBOARD" ]; then
    while IFS= read -r line; do
        cmd_id=$(echo "$line" | awk -F'|' '{print $4}' | grep -oE 'cmd_[0-9]+' | head -1 || true)
        if [ -n "$cmd_id" ] && ! grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            echo "$cmd_id" >> "$STATE_FILE"
        fi
    done < <(grep -E '^\| [0-9]{2}:[0-9]{2} \|' "$DASHBOARD" || true)
    log "Initial state loaded: $(wc -l < "$STATE_FILE") cmd IDs registered (no re-notification)"
fi

if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotifywait not found. Cannot watch dashboard.md"
    exit 1
fi

# テスト用: SKIP_MAIN_LOOP=1 で watch ループをスキップ
if [ "${SKIP_MAIN_LOOP:-0}" -eq 1 ]; then
    log "SKIP_MAIN_LOOP=1: exiting before watch loop (test mode)"
    exit 0
fi

while true; do
    # B5-2: modify を除外し close_write/moved_to のみ監視
    #   modify は close_write と重複して二重発火する可能性があるため除外
    if inotifywait -q -t 60 -e close_write,moved_to "$DASHBOARD" >> "$LOG_FILE" 2>&1; then
        log "dashboard.md changed, checking for new cmd completions"
        check_and_notify
    else
        check_and_notify
    fi
done
