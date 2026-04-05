#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# cmd_complete_notifier.sh — dashboard.md 変更検知 → ntfy自動通知
#
# 概要:
#   dashboard.md の「本日の戦果」セクションの🏆完了行を監視し、
#   新しく追加された cmd 完了時に殿のスマートフォンへ ntfy 通知を送る。
#
# 動作:
#   - inotifywait で dashboard.md を常時監視
#   - 変更検知時: 🏆マーカーを含む完了行のみ抽出（セマンティックゲート）
#   - 未通知 cmd ID を state file（logs/ntfy_notified_cmds.txt）で管理
#   - 未通知のものだけ ntfy 送信（重複防止）
#
# 🏆セマンティッ���ゲート設計 (cmd_444/cmd_445):
#   dashboard.mdには2種類の✅行が書かれる:
#     1) 軍師QC PASS行: 「✅ QC PASS」（🏆なし） — QC完了時点
#     2) 家老🏆完了行: 「🏆cmd_NNN完了」（🏆あり） — 全完了判定後
#   notifierは🏆を含む行のみをトリガーにすることで、
#   QC完了前の早期通知を防止する。
#   🏆は家老がStep 11.7 Step3で書く = QC PASS確認+完了判定後。
#
# 起動: watcher_supervisor.sh から nohup で起動される
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PIDFILE="/home/ubuntu/shogun/logs/cmd_complete_notifier.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (PID $(cat "$PIDFILE")). Exiting." >&2
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

DASHBOARD="$SCRIPT_DIR/dashboard.md"
STATE_FILE="$SCRIPT_DIR/logs/ntfy_notified_cmds.txt"
LOG_FILE="$SCRIPT_DIR/logs/cmd_complete_notifier.log"

# state file 初期化
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# dashboard.md から完了行を抽出し、未通知 cmd を ntfy 送信
check_and_notify() {
    if [ ! -f "$DASHBOARD" ]; then
        return 0
    fi

    # 完了行パターン: | HH:MM | ... 🏆cmd_NNN完了 ... | ✅ ... |
    # 🏆フィルタ: 軍師QC PASS行(🏆なし)を除外し、家老🏆完了行のみトリガー
    while IFS= read -r line; do
        # cmd番号を抽出
        cmd_id=$(echo "$line" | grep -oP 'cmd_\d+' | head -1 || true)
        if [ -z "$cmd_id" ]; then
            continue
        fi

        # 既に通知済みか確認
        if grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            continue
        fi

        # 完了概要を抽出（3列目: cmd_NNN以降のテキスト）
        summary=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/✅.*//' | sed 's/^ *//; s/ *$//' | head -c 60 || true)

        # ntfy 送信
        log "Sending ntfy for $cmd_id: $summary"
        if bash "$SCRIPT_DIR/scripts/ntfy.sh" "✅ ${cmd_id} 完了 — ${summary}" "家老より" "cmd_complete" >> "$LOG_FILE" 2>&1; then
            echo "$cmd_id" >> "$STATE_FILE"
            log "ntfy sent: $cmd_id"
        else
            log "ntfy FAILED for $cmd_id"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep '🏆' | grep -P 'cmd_\d+' | grep '✅' || true)
}

log "cmd_complete_notifier started. Watching: $DASHBOARD"

# 起動時に既存の完了行を state file に記録（起動直後の大量通知を防止）
if [ -f "$DASHBOARD" ]; then
    while IFS= read -r line; do
        cmd_id=$(echo "$line" | grep -oP 'cmd_\d+' | head -1 || true)
        if [ -n "$cmd_id" ] && ! grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            echo "$cmd_id" >> "$STATE_FILE"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep '🏆' | grep -P 'cmd_\d+' | grep '✅' || true)
    log "Initial state loaded: $(wc -l < "$STATE_FILE") cmd IDs registered"
fi

# inotifywait チェック
if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotifywait not found. Cannot watch dashboard.md"
    exit 1
fi

# メインループ: dashboard.md を監視
while true; do
    # タイムアウト付きで変更を待つ（Fallback: 60秒ごとにポーリング）
    if inotifywait -q -t 60 -e modify,close_write,moved_to "$DASHBOARD" >> "$LOG_FILE" 2>&1; then
        log "dashboard.md changed, checking for new completions"
        check_and_notify
    else
        # タイムアウト（rc=2）またはエラー（rc=1）: ポーリングとして check
        check_and_notify
    fi
done
