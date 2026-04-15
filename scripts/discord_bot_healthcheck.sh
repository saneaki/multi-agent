#!/usr/bin/env bash
# Discord Bot 死活監視スクリプト
# cron で 5分ごとに実行: */5 * * * * /home/ubuntu/shogun/scripts/discord_bot_healthcheck.sh >> /home/ubuntu/shogun/logs/discord_bot_health.log 2>&1

set -uo pipefail

# ── DI-02: cron 向け環境変数設定 (systemctl --user に必須) ─────────
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# ── DI-06: PATH 拡張 ─────────────────────────────────────────────
export PATH="/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:$PATH"

# ── 設定 ─────────────────────────────────────────────────────────
SHOGUN_DIR="/home/ubuntu/shogun"
STATE_FILE="/tmp/discord_bot_health.state"
COOLDOWN_SEC=900  # 15分 重複通知抑制

# ── DI-05: ntfy topic を settings.yaml から動的取得 ──────────────
NTFY_TOPIC=$(grep '^ntfy_topic:' "${SHOGUN_DIR}/config/settings.yaml" \
    | awk -F: '{print $2}' | tr -d ' "' | head -1)
NTFY_TOPIC="${NTFY_TOPIC:-hananoen}"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"

# ── 死活確認 ─────────────────────────────────────────────────────
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

if pgrep -f discord_to_ntfy > /dev/null 2>&1; then
    echo "[${TIMESTAMP}] OK: discord_to_ntfy running"
    # Bot 正常稼働中 → state ファイル削除(cooldown リセット)
    rm -f "${STATE_FILE}"
    exit 0
fi

echo "[${TIMESTAMP}] WARN: discord_to_ntfy not found"

# ── cooldown チェック (重複通知抑制) ─────────────────────────────
if [ -f "${STATE_FILE}" ]; then
    LAST_NOTIFY=$(cat "${STATE_FILE}" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST_NOTIFY ))
    if [ "${ELAPSED}" -lt "${COOLDOWN_SEC}" ]; then
        echo "[${TIMESTAMP}] INFO: cooldown中 (${ELAPSED}s / ${COOLDOWN_SEC}s). 通知スキップ"
        # 復旧試行のみ実施 (通知なし)
        systemctl --user restart shogun-discord.service 2>/dev/null || true
        exit 0
    fi
fi

# ── ntfy 通知 ─────────────────────────────────────────────────────
echo "[${TIMESTAMP}] ALERT: Bot停止検出。ntfy通知+自動復旧試行"
curl -s \
    -H "Title: Discord Bot 停止検出" \
    -H "Tags: warning,robot" \
    -H "Priority: high" \
    -d "discord_to_ntfy プロセスが停止しています。systemd による自動復旧を試みます。" \
    "${NTFY_URL}" > /dev/null 2>&1 || true

# cooldown state 更新
date +%s > "${STATE_FILE}"

# ── systemd による自動復旧試行 ────────────────────────────────────
systemctl --user restart shogun-discord.service 2>/dev/null && \
    echo "[${TIMESTAMP}] OK: systemctl restart 成功" || \
    echo "[${TIMESTAMP}] ERROR: systemctl restart 失敗"

exit 0
