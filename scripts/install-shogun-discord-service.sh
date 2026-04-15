#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/shogun-discord.service"

# ── DI-01: 既存 tmux Bot を先に停止 ──────────────────────────────
echo "=== 既存 Discord Bot 停止 ==="
pkill -f discord_to_ntfy || true
sleep 2
tmux kill-window -t multiagent:shogun-discord 2>/dev/null || true
sleep 1
if pgrep -f discord_to_ntfy > /dev/null; then
  echo "ERROR: discord_to_ntfy プロセスが残存しています。手動で停止してから再実行してください。"
  exit 1
fi
echo "OK: 既存 Bot 停止確認"

# ── service ファイル配置 ──────────────────────────────────────────
echo "=== systemd service インストール ==="
mkdir -p "$SERVICE_DIR"
install -D -m 0644 "$SCRIPT_DIR/shogun-discord.service.template" "$SERVICE_FILE"
echo "Installed: $SERVICE_FILE"

# ── linger 有効化 (ログアウト後も動作) ───────────────────────────
loginctl enable-linger "$(whoami)"
echo "OK: linger enabled for $(whoami)"

# ── daemon-reload + enable + start ───────────────────────────────
systemctl --user daemon-reload
systemctl --user enable --now shogun-discord.service
echo "OK: shogun-discord.service enabled and started"

# ── 起動確認 ─────────────────────────────────────────────────────
sleep 3
echo "=== 起動確認 ==="
systemctl --user status shogun-discord.service --no-pager
pgrep -f discord_to_ntfy && echo "OK: Bot プロセス確認" || echo "WARN: プロセス未検出"
echo ""
echo "ログ確認: tail -20 /home/ubuntu/shogun/logs/discord_bot.log"
