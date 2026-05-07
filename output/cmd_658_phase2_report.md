# cmd_658 Phase 2: Discord Inbound Gateway 実装レポート

- **task_id**: subtask_658_phase2_inbound_gateway
- **parent_cmd**: cmd_658
- **assignee**: ashigaru4 (Opus+T)
- **status**: completed
- **completed_at**: 2026-05-08 03:56 JST
- **previous phase**: Phase 0-1 (outbound) → completed (cmd_658_phase01_report.md)

## 1. 殿御裁可

> 24h dual 観測不要。Phase 1 outbound と独立経路ゆえ即時実施。

→ Phase 1 と並走可能ゆえ Phase 2 を即時実装。dual-stack 観測 (P2-5) は Phase 3 削除前の最終 gate として将来実施。

## 2. 実装内容 (Acceptance Criteria 対応)

### P2-1: scripts/discord_gateway.py (旧 discord_to_ntfy.py 置換)

- discord.py 2.7.1 + PyYAML 6.0.3 で実装
- DM のみ処理 (`discord.DMChannel`) / 自身メッセージ無視 / `DISCORD_ALLOWED_USER_IDS` allowlist チェック
- **atomic 書込**: `fcntl.flock(LOCK_EX)` + `tempfile.mkstemp` + `os.fsync` + `os.replace` で半端書込ゼロ
- **lock 場所**: `queue/external_inbox.yaml.lock` (専用 lock file)
- **truncate**: 本文 4000 字上限 (Discord 2000 字 + 添付メタ余裕)
- **ack reaction**: 受信 → yaml 書込成功 → inbox_write → ✅ reaction (best-effort)
- **--dry-run** / **--self-test** フラグ実装 (Discord 接続せずパス検証可)

### P2-2: queue/external_inbox.yaml schema 確定 (ntfy_inbox.yaml 互換)

```yaml
inbox:
  - id: <discord_message_id_str>          # ntfy 互換 (id field)
    message: <body>                        # ntfy 互換
    timestamp: <ISO+09:00 JST>             # ntfy 互換
    status: pending                        # ntfy 互換 (pending|delegated_to_karo|processed)
    # Discord 固有 (追加)
    discord_message_id: <str>
    channel_id: <str>
    user_id: <str>
    username: <str>
    received_at: <ISO+09:00 JST>
```

ntfy_inbox.yaml の既存利用側 (`status` で進捗追跡) と同じシェイプを採用。Phase 3 で
ntfy_inbox.yaml を削除した際、既存ロジックの `inbox` キー走査は変更不要。

### P2-3: systemd unit + healthcheck rename

- **shogun-discord.service** (`~/.config/systemd/user/`):
  - Description を Phase 2 内容に更新
  - `EnvironmentFile=` を `discord_bot.env`（旧）+ `discord.env`（cmd_658）両方読込に拡張、両方 `-` で optional 化
  - `ExecStart=` を `discord_gateway.py` に切替
  - `StandardOutput/Error` を `logs/discord_gateway.{log,_error.log}` に変更
- **healthcheck rename**: `discord_bot_healthcheck.sh` → `discord_gateway_healthcheck.sh`
  - `git mv` でリネーム履歴保持
  - `pgrep -f discord_to_ntfy` → `pgrep -f discord_gateway` に変更
  - `STATE_FILE=/tmp/discord_gateway_health.state` に変更
  - 通知文言 / cron entry / log path も同期更新
- **crontab 更新**: `*/5 * * * * .../discord_gateway_healthcheck.sh >> .../discord_gateway_health.log`

### P2-4: E2E (DM → yaml → inbox_write → ack reaction)

| ステップ | 確認手段 | 結果 |
|---------|---------|------|
| Discord ログイン | `journalctl --user-unit shogun-discord` + log | ✅ `logged in as shogun#7465 (id=1491955796622311536) allowlist={'495636202943152139'}` |
| atomic yaml 書込 | `--self-test` 実行 → external_inbox.yaml entry 確認 | ✅ entry 1 件追加 → 削除でクリーンアップ |
| inbox_write shogun 連動 | self-test 後 `queue/inbox/shogun.yaml` 確認 | ✅ `type: discord_received, from: discord_gateway` で着信 |
| ack reaction | 殿の実 DM 1 通で目視確認 (manual_verification_required) | ⏳ 殿への要請を Phase 2 完了報告に同梱 |
| systemd 自動起動 | `systemctl --user status` | ✅ `active (running)` |
| healthcheck OK | 手動実行 | ✅ `OK: discord_gateway running` |

### P2-5: 24-48h dual-stack 観測

殿御裁可で **Phase 2 では実施不要**。ntfy_listener は Phase 3 削除まで並走 (現状 5/1 以降 silent fail のため
inbound 経路としては実質 discord 単独だが、Phase 3 で確実に削除する gate として残置)。

## 3. ファイル変更一覧

| 種別 | パス | 内容 |
|------|------|------|
| 新規 | `scripts/discord_gateway.py` | 本体 (286 行、self-test 同梱) |
| 新規 | `queue/external_inbox.yaml` | 空 inbox 初期化 (`inbox: []`) |
| 新規 | `output/cmd_658_phase2_report.md` | 本レポート |
| rename | `scripts/discord_bot_healthcheck.sh` → `scripts/discord_gateway_healthcheck.sh` | 内容も Phase 2 向け更新 |
| 更新 | `~/.config/systemd/user/shogun-discord.service` | Description + ExecStart + EnvFile 拡張 |
| 更新 | crontab (user) | healthcheck path + log path |
| 更新 | `.gitignore` | discord_gateway.py / discord_gateway_healthcheck.sh / output/cmd_658_phase2_report.md whitelist |

## 4. 後続作業 (Phase 3 → Phase 4)

| Phase | 作業 | 想定 |
|-------|------|------|
| P3-1 | instructions/shogun.md 等の `ntfy_inbox.yaml` → `external_inbox.yaml` rename | Sonnet+T |
| P3-2 | ntfy server-side 完全削除 (ntfy_listener.sh / ntfy.sh / lib/ntfy_auth.sh / 各 yaml/log) | Sonnet+T |
| P3-3 | tests/unit/test_ntfy_*.bats を Discord 版に置換 | Sonnet+T |
| P3-4 | docs (DISCORD_BOT_SETUP.md / notification_channels.md / automate.md / feedback-system-guide.md) を Discord 中心化 | Sonnet+T |
| P3-5 | config/settings.yaml の `ntfy_topic` 削除 | Sonnet+T |
| P4 | Android NtfyService.kt 廃止判断 (a/b/c) → 殿要相談 | Opus+T or Sonnet+T |

`scripts/discord_to_ntfy.py` は Phase 3 で削除する (本 Phase では消さず残置 — 後方互換 + 監査ログ用途)。

## 5. 殿への要請

Phase 2 が active な間、Discord DM を 1 通お送りいただきたく候。
- 期待挙動: Bot が ✅ reaction を即座に付与
- 自動効果: `queue/external_inbox.yaml` に entry 追加 + `queue/inbox/shogun.yaml` に
  `type: discord_received` で着信
- 失敗時の自動ログ: `logs/discord_gateway.log` / `logs/discord_gateway_error.log`

## 6. 安全装置サマリ

- `fcntl.flock` で yaml 書込並列レース防止 (RACE-001 対策)
- `tempfile.mkstemp` + `os.fsync` + `os.replace` で半端書込ゼロ
- DM allowlist 厳格 (空なら全 reject)
- best-effort exit (notify_shogun 失敗でも process は継続稼働)
- secret は `discord.env` (chmod 600 + .gitignore)
- 自身メッセージ ignore (loop 防止)

---
*Generated 2026-05-08 03:56 JST by ashigaru4 (Opus+T) on cmd_658 Phase 2.*
