#!/usr/bin/env bash
# detect_compact.sh — agent pane で /compact (self_compact) 実行を検出してログ記録 (cmd_633 Scope B)
#
# Usage: bash scripts/detect_compact.sh <agent_id>
# Example:
#   bash scripts/detect_compact.sh karo
#   bash scripts/detect_compact.sh gunshi
#
# cron:
#   */10 * * * * bash /home/ubuntu/shogun/scripts/detect_compact.sh karo  >> /home/ubuntu/shogun/logs/compact_log/cron.log 2>&1
#   */10 * * * * bash /home/ubuntu/shogun/scripts/detect_compact.sh gunshi >> /home/ubuntu/shogun/logs/compact_log/cron.log 2>&1
#
# 検出方式:
#   1. tmux で agent_id の pane を特定 (@agent_id プロパティ照合)
#   2. tmux capture-pane で直近 200 行を取得
#   3. 以下のマーカーを検出:
#       a) "❯ /compact" (純粋な user 入力痕跡 — Claude Code prompt prefix は ❯)
#       b) "Compacting conversation" (Claude Code が compact 実行時に出す固有表示)
#       c) "[Compaction occurred at"   (session 保存ログマーカー)
#   4. 検出時: logs/compact_log/{agent_id}.log に timestamp + マーカー記録
#   5. 冪等: 同一時刻枠 (1 時間粒度) + 同一マーカーの重複記録は skip
#
# 出力ログ形式:
#   2026-05-02T16:50:00+09:00 karo self_compact detected (markers: user_input,system_message)
#
# auto-compact との違い:
#   - 本 script は self_compact (manual /compact) 検出が主目的
#   - auto-compact は compact_observer.sh + ~/.claude/sessions/compaction-log.txt で別途追跡

set -euo pipefail

ROLE="${1:-}"
if [ -z "$ROLE" ]; then
    echo "Usage: $0 <agent_id>" >&2
    echo "Example: $0 karo" >&2
    exit 2
fi

# script の場所からプロジェクト root を取得
# (compact_observer.sh と同じパターン)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs/compact_log"
LOG_FILE="${LOG_DIR}/${ROLE}.log"
mkdir -p "$LOG_DIR"

_log_stderr() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [detect_compact/${ROLE}] $*" >&2
}

# ── Step 1: tmux pane 特定 ──────────────────────────────────────────────────
PANE_TARGET=$(tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} #{@agent_id}" 2>/dev/null \
    | awk -v role="$ROLE" '$2 == role { print $1 }' | head -1)

if [ -z "$PANE_TARGET" ]; then
    _log_stderr "SKIP: tmux pane for agent_id=${ROLE} not found"
    exit 0
fi

# ── Step 2: pane 履歴取得 ───────────────────────────────────────────────────
CAPTURE=$(tmux capture-pane -t "$PANE_TARGET" -p -S -200 2>/dev/null || true)

if [ -z "$CAPTURE" ]; then
    _log_stderr "SKIP: capture-pane returned empty for ${PANE_TARGET}"
    exit 0
fi

# ── Step 3: マーカー検出 ────────────────────────────────────────────────────
MARKERS=""

# a) user 入力: 行頭 prompt "❯ /compact" (前後空白許容、コメント等が後続しない)
#    Claude Code の prompt は ❯ (U+276F) を使用
if echo "$CAPTURE" | grep -qE '^[[:space:]]*❯[[:space:]]+/compact([[:space:]]|$)'; then
    MARKERS="${MARKERS:+${MARKERS},}user_input"
fi

# b) Claude Code system message: "Compacting conversation" (compact 実行中表示)
if echo "$CAPTURE" | grep -qiE 'Compacting conversation'; then
    MARKERS="${MARKERS:+${MARKERS},}compacting_message"
fi

# c) session 保存ログマーカー: "[Compaction occurred at"
if echo "$CAPTURE" | grep -qE '\[Compaction occurred at'; then
    MARKERS="${MARKERS:+${MARKERS},}session_log"
fi

if [ -z "$MARKERS" ]; then
    # マーカーなし: 何も書かず graceful exit
    exit 0
fi

# ── Step 4: 冪等性チェック (同一時刻枠 + 同一マーカーの重複防止) ─────────────
NOW_JST=$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --yaml 2>/dev/null \
    || date '+%Y-%m-%dT%H:%M:%S+09:00')

# 1 時間粒度のキー (例: 2026-05-02T16)
HOUR_KEY=$(echo "$NOW_JST" | cut -c1-13)

if [ -f "$LOG_FILE" ]; then
    # 同じ時刻枠 (時間単位) + 同じ ROLE + 同じ MARKERS の entry が既にあれば skip
    if grep -qF "${HOUR_KEY}" "$LOG_FILE" 2>/dev/null \
        && grep -qF "markers: ${MARKERS}" "$LOG_FILE" 2>/dev/null; then
        # 厳密判定: 同一行内に両方含まれているか
        if awk -v hk="$HOUR_KEY" -v role="$ROLE" -v m="markers: ${MARKERS}" \
            'index($0, hk) && index($0, role) && index($0, m) { found=1 } END { exit !found }' \
            "$LOG_FILE"; then
            _log_stderr "SKIP: duplicate entry (hour=${HOUR_KEY} markers=${MARKERS})"
            exit 0
        fi
    fi
fi

# ── Step 5: ログ記録 ────────────────────────────────────────────────────────
echo "${NOW_JST} ${ROLE} self_compact detected (markers: ${MARKERS})" >> "$LOG_FILE"
_log_stderr "RECORDED: markers=${MARKERS}"
