# Discord Bot セットアップガイド

## 概要

Discord DM → `queue/external_inbox.yaml` 直接書込 Gateway (`discord_gateway.py`) の運用手順。
cmd_658 Phase 2 より systemd user service + healthcheck による自動管理体制。

## インストール

### 初回セットアップ

```bash
bash /home/ubuntu/shogun/scripts/install-shogun-discord-service.sh
```

**注意**: 既存 tmux Bot が稼働中の場合、install script が自動停止します。

### cron 登録 (healthcheck)

```bash
(crontab -l 2>/dev/null | grep -v discord_bot_healthcheck; \
 echo "*/5 * * * * /home/ubuntu/shogun/scripts/discord_bot_healthcheck.sh >> /home/ubuntu/shogun/logs/discord_bot_health.log 2>&1") \
| crontab -
```

## 日常操作

| 操作 | コマンド |
|------|---------|
| 状態確認 | `systemctl --user status shogun-discord` |
| 再起動 | `systemctl --user restart shogun-discord` |
| 停止 | `systemctl --user stop shogun-discord` |
| ログ確認 | `tail -f /home/ubuntu/shogun/logs/discord_bot.log` |
| エラーログ | `tail -f /home/ubuntu/shogun/logs/discord_bot_error.log` |
| journal | `journalctl --user -t shogun-discord -f` |

## healthcheck 仕様

- 5分ごとに cron で実行
- `systemctl --user is-active shogun-discord` で service 確認
- 停止検出時: Discord 通知 + `systemctl --user restart` 自動復旧
- 15分 cooldown で重複通知を抑制
- ログ: `/home/ubuntu/shogun/logs/discord_bot_health.log`

## トラブルシューティング

### Bot が起動しない

```bash
# 1. service 状態確認
systemctl --user status shogun-discord --no-pager

# 2. ログ確認
tail -50 /home/ubuntu/shogun/logs/discord_bot_error.log

# 3. token 設定確認
cat /home/ubuntu/shogun/config/discord_bot.env | grep DISCORD_BOT_TOKEN

# 4. 手動起動テスト
/home/ubuntu/shogun/.venv/discord-bot/bin/python3 \
  /home/ubuntu/shogun/scripts/discord_gateway.py
```

### 2重起動が疑われる場合 (DI-01)

```bash
# プロセス数確認 (1つのみが正常)
pgrep -af discord_gateway.py

# tmux window 確認
tmux list-windows -t multiagent

# 既存プロセス全停止
pkill -f discord_gateway.py || true
tmux kill-window -t multiagent:shogun-discord 2>/dev/null || true
systemctl --user start shogun-discord
```

### healthcheck cron が動作しない

```bash
# cron 登録確認
crontab -l | grep discord

# 手動実行テスト
bash /home/ubuntu/shogun/scripts/discord_bot_healthcheck.sh

# systemctl --user のcron動作確認
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
systemctl --user status shogun-discord
```
