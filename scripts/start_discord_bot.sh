#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# DEPRECATED: このスクリプトは cmd_497 (2026-04-15) より非推奨。
# 通常運用は systemd user service (shogun-discord.service) を使用すること:
#   systemctl --user status shogun-discord   # 状態確認
#   systemctl --user restart shogun-discord  # 再起動
#   systemctl --user stop shogun-discord     # 停止
# このスクリプトは緊急時手動デバッグ用として残す。
# 再インストール: bash scripts/install-shogun-discord-service.sh
# ─────────────────────────────────────────────────────────────────
# start_discord_bot.sh — Discord Bot → ntfy 中継スクリプト起動
#
# [使い方]
#   bash scripts/start_discord_bot.sh          # 通常起動 (tmux pane で常駐)
#   bash scripts/start_discord_bot.sh --dry-run # DRY-RUN (ntfy転送なし、動作確認用)
#
# [前提条件]
#   1. config/discord_bot.env に DISCORD_BOT_TOKEN と DISCORD_ALLOWED_USER_IDS を設定済み
#   2. pip install "discord.py>=2.3" httpx
#   3. tmux セッション "multiagent" が起動中であること

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOT_ENV="$SCRIPT_DIR/config/discord_bot.env"
BOT_SCRIPT="$SCRIPT_DIR/scripts/discord_to_ntfy.py"
TMUX_SESSION="multiagent"
TMUX_WINDOW="shogun-discord"
DRY_RUN="${1:-}"

# --- 設定ファイル確認 ---
if [ ! -f "$BOT_ENV" ]; then
    echo "[ERROR] $BOT_ENV が見つかりません。" >&2
    echo "        cp config/discord_bot.env.sample config/discord_bot.env して編集してください。" >&2
    exit 1
fi

# BOT_TOKENが設定済みか確認
# shellcheck disable=SC1090
source "$BOT_ENV"
if [ -z "${DISCORD_BOT_TOKEN:-}" ] || [ "${DISCORD_BOT_TOKEN}" = "your_bot_token_here" ]; then
    echo "[ERROR] DISCORD_BOT_TOKEN が未設定です。" >&2
    echo "        $BOT_ENV を編集して Bot Token を設定してください。" >&2
    echo "" >&2
    echo "  [Discord Bot Token 取得手順]" >&2
    echo "  1. https://discord.com/developers/applications にアクセス" >&2
    echo "  2. New Application → Bot → Token をコピー" >&2
    echo "  3. $BOT_ENV の DISCORD_BOT_TOKEN= に貼り付け" >&2
    exit 1
fi

# DRY_RUN引数処理
BOT_ARGS=()
if [ "$DRY_RUN" = "--dry-run" ]; then
    BOT_ARGS+=("--dry-run")
    echo "[INFO] DRY-RUNモードで起動します（ntfy転送なし）"
fi

# --- tmux pane 確認・作成 ---
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "[ERROR] tmux セッション '$TMUX_SESSION' が見つかりません。" >&2
    echo "        先に tmux セッションを起動してください。" >&2
    exit 1
fi

# 既存の shogun-discord window があれば閉じる
if tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -q "^${TMUX_WINDOW}$"; then
    echo "[INFO] 既存の '$TMUX_WINDOW' window を終了します..."
    tmux kill-window -t "$TMUX_SESSION:$TMUX_WINDOW"
fi

# 新しい window で Bot を起動
echo "[INFO] tmux window '$TMUX_WINDOW' で Discord Bot を起動します..."
VENV_PYTHON="$SCRIPT_DIR/.venv/discord-bot/bin/python3"
if [ ! -x "$VENV_PYTHON" ]; then
    VENV_PYTHON="python3"
fi

tmux new-window -d -t "$TMUX_SESSION" -n "$TMUX_WINDOW" \
    "$VENV_PYTHON $BOT_SCRIPT ${BOT_ARGS[*]:-}; echo '[Bot terminated] Press Enter to close'; read"

echo "[INFO] Discord Bot 起動完了。"
echo "       確認: tmux attach -t $TMUX_SESSION && 'w' でウィンドウ一覧確認"
echo "       停止: tmux kill-window -t $TMUX_SESSION:$TMUX_WINDOW"
