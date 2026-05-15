#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# DEPRECATED: このスクリプトは cmd_497 (2026-04-15) で systemd user service
# (shogun-discord.service) に移行済。さらに cmd_683 Phase3 (2026-05-15) で
# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) が削除されたため、ここから起動
# しても動作しない。dead reference 起動を防ぐため deprecation メッセージを
# 出して即時失敗のみ行う。cmd_683d で本体ロジックを除去。
#
# 通常運用は systemd user service:
#   systemctl --user status   shogun-discord    # 状態確認
#   systemctl --user restart  shogun-discord    # 再起動
#   systemctl --user stop     shogun-discord    # 停止
#   journalctl --user -u shogun-discord -f      # ログ追跡
#
# 再インストール:
#   bash scripts/install-shogun-discord-service.sh
#
# 現行 Bot 本体: scripts/discord_gateway.py (systemd 配下で常駐)
# 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) は cmd_683 Phase3 で削除済
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

cat >&2 <<'EOF'
[DEPRECATED] scripts/start_discord_bot.sh は使用不可。
  - cmd_497 (2026-04-15): systemd user service (shogun-discord.service) に移行
  - cmd_683 Phase3 (2026-05-15): 旧 BOT_SCRIPT (scripts/discord_to_ntfy.py) 削除済
  - cmd_683d (2026-05-15): 本スクリプト本体ロジック撤去 (dead reference 解消)

通常運用コマンド:
  systemctl --user status   shogun-discord
  systemctl --user restart  shogun-discord
  systemctl --user stop     shogun-discord
  journalctl --user -u shogun-discord -f

再インストール:
  bash scripts/install-shogun-discord-service.sh

現行 Bot 本体は scripts/discord_gateway.py (systemd 配下) です。
緊急時手動デバッグは systemd を停止してから直接起動してください:
  systemctl --user stop shogun-discord
  .venv/discord-bot/bin/python3 scripts/discord_gateway.py
EOF

exit 2
