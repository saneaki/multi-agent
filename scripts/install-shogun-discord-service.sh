#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/shogun-discord.service"

# ── DI-01: 既存 Bot を先に停止 ──────────────────────────────────
# cmd_683 Phase3 で旧 discord_to_ntfy.py は削除済。現行 Bot は scripts/discord_gateway.py
# を systemd user service (shogun-discord.service) 配下で常駐運用する。本 install
# スクリプトを再実行する際は systemd を先に停止し、残存 tmux window や手動起動の
# discord_gateway プロセスを念のため掃除する。
echo "=== 既存 Discord Bot 停止 ==="
systemctl --user stop shogun-discord.service 2>/dev/null || true
pkill -f scripts/discord_gateway.py || true
sleep 2
tmux kill-window -t multiagent:shogun-discord 2>/dev/null || true
sleep 1
if pgrep -f scripts/discord_gateway.py > /dev/null; then
  echo "ERROR: discord_gateway プロセスが残存しています。手動で停止してから再実行してください。"
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
pgrep -f scripts/discord_gateway.py && echo "OK: Bot プロセス確認" || echo "WARN: プロセス未検出"
echo ""
echo "ログ確認: tail -20 /home/ubuntu/shogun/logs/discord_bot.log"
