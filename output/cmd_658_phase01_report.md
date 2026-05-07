# cmd_658 Phase 0-1 完了報告 — ntfy→Discord outbound 切替

**Task**: `subtask_658_phase01_discord_outbound`
**Agent**: ashigaru4 (Opus + Thinking)
**Date**: 2026-05-08 JST
**Parent cmd**: cmd_658 (Discord 移行 — Phase 2 inbound は別タスク)

---

## Executive Summary

Codex 調査報告 (`output/cmd_ntfy_discord_migration_codex_ashigaru_review.md`) の段階的移行戦略に従い、Phase 0 (準備) と Phase 1 (outbound) を完遂した。`scripts/notify.sh` 互換 wrapper と `scripts/discord_notify.py` を新設し、`NOTIFY_BACKEND=discord` をデフォルトに設定。11 個の運用 script から `bash scripts/ntfy.sh` 直接呼出を `bash scripts/notify.sh` 経由に置換。E2E DM 送信テストは PASS、24h dual-stack 観測フェーズへ遷移した。`ntfy_listener.sh` の inbound 経路は無変更でそのまま稼働継続している。

---

## Acceptance Criteria 確認

| ID | Check | 結果 | Evidence |
|---|---|:-:|---|
| P0-1 | `config/discord.env.sample` 作成 (DISCORD_BOT_TOKEN/DISCORD_LORD_DM_CHANNEL_ID 各フィールド) | ✅ | `config/discord.env.sample` (新規, .gitignore allow-listed) |
| P0-2 | `scripts/notify.sh` 新設 (NOTIFY_BACKEND=discord/ntfy 切替、ntfy.sh 互換引数) | ✅ | `scripts/notify.sh` (chmod +x, syntax OK) |
| P0-3 | 引数互換テスト PASS (NOTIFY_BACKEND=ntfy + discord 両方) | ✅ | dry-run + ntfy dispatch trace 確認 (本書 §テスト記録) |
| P1-1 | `scripts/discord_notify.py` 実装 (DM送信 + 429 retry + truncation) | ✅ | `scripts/discord_notify.py` (urllib only, 2000 char truncate, exp backoff) |
| P1-2 | `notify.sh` NOTIFY_BACKEND=discord 切替 + E2E DM 送信確認 | ✅ | `logs/discord_notify.log` で 2 件 delivered 確認 (`channel=1491959535768703097`) |
| P1-3 | `grep -r 'ntfy.sh' scripts/` で全箇所 `notify.sh` に置換確認 | ✅ | 11 scripts / 16 箇所 全置換 (本書 §置換一覧) |
| P1-4 | 24h dual-stack 観測開始 (ntfy inbound 継続 + discord outbound 切替) | ✅ | ntfy_listener.sh プロセス継続稼働 / discord_notify outbound 稼働 |
| D-1 | `output/cmd_658_phase01_report.md` 生成 | ✅ | 本ファイル |

---

## 成果物

### 新規ファイル

| Path | 役割 |
|---|---|
| `config/discord.env.sample` | Discord 統合 env のひな形 (.gitignore allow-listed) |
| `config/discord.env` | 実 token (chmod 600, .gitignore 対象、git 非追跡) |
| `scripts/notify.sh` | ntfy.sh 互換 wrapper。NOTIFY_BACKEND で Discord/ntfy 振分け |
| `scripts/discord_notify.py` | Discord HTTP API (REST) で殿 DM 送信。429 retry + truncation |
| `logs/discord_notify.log` | discord_notify.py 配送ログ (新規生成) |
| `output/cmd_658_phase01_report.md` | 本報告書 |

### 編集ファイル

| Path | 変更内容 |
|---|---|
| `.gitignore` | `!config/discord.env.sample` 追加 (whitelist 方式) |
| `scripts/restart_n8n.sh` | ntfy.sh→notify.sh (2 箇所) |
| `scripts/inbox_write.sh` | ntfy.sh→notify.sh (1 箇所) + ログメッセージ |
| `scripts/gas_run_oauth.sh` | notify_error 内の ntfy.sh→notify.sh |
| `scripts/gas_push_oauth.sh` | notify_error 内の ntfy.sh→notify.sh |
| `scripts/switch_gmail_wf.sh` | 存在チェックも notify.sh に変更 (file existence check + call) |
| `scripts/cmd_complete_notifier.sh` | ntfy.sh→notify.sh + ログラベル |
| `scripts/shogun_in_progress_monitor.sh` | ntfy.sh→notify.sh + コメント |
| `scripts/clasp_age_check.sh` | ntfy.sh→notify.sh (3 箇所) |
| `scripts/shogun_reality_check.sh` | with_ntfy 分岐内の ntfy.sh→notify.sh |
| `scripts/notify_decision.sh` | 存在チェックも notify.sh、ログメッセージ更新 (2 箇所) |
| `scripts/discord_bot_healthcheck.sh` | 直接 curl ntfy POST → notify.sh wrapper 経由に変更 |

---

## 設計判断

### 1. notify.sh wrapper のシンプル化
旧 `ntfy.sh` の引数仕様 `body / title / type` をそのまま継承。NOTIFY_BACKEND が `discord` の場合は `python3 scripts/discord_notify.py --body --title --type` に展開、`ntfy` の場合は `bash scripts/ntfy.sh "$@"` に委譲。引数フォーマットを 1:1 維持することで 11 scripts の引数渡しを変更不要にした。

### 2. discord_notify.py は urllib のみ依存
`discord.py` / `httpx` / `requests` は使わず Python 標準ライブラリ `urllib.request` のみで実装。理由:
- discord.py は gateway 接続が必須でスタンドアロン CLI には過剰。
- 外部依存を最小化することで CI / VPS 双方で `apt`/`pip` 追加なしに動作。
- 429 retry / Retry-After 解釈は手動実装で十分対応可能。

### 3. config/discord.env と既存 discord_bot.env の並存
既存 `config/discord_bot.env` (DM relay 用) は無変更。新 `config/discord.env` を追加。`load_config()` は両方を読み discord.env が優先される merge 方式。Phase 2 で `discord_gateway.py` 実装時に統合検討する。

### 4. open_dm_channel フォールバック
`DISCORD_LORD_DM_CHANNEL_ID` が空でも `DISCORD_LORD_USER_ID` または `DISCORD_ALLOWED_USER_IDS` の最初の値から `POST /users/@me/channels` で動的に DM チャネル ID を取得。env 設定の柔軟性を確保。

### 5. best-effort exit code
discord_notify.py は最終失敗時も exit 0 を返す。理由: 旧 ntfy.sh も最終失敗で 0 を返しており、cron / 監視 script 側で失敗時継続前提。失敗時はログ (`logs/discord_notify.log`) に記録して可観測性を担保。

### 6. discord_bot_healthcheck.sh の通知経路統一
旧 healthcheck は curl 直叩きで ntfy POST だった。Phase 1 では notify.sh 経由に変更。これにより Discord bot が落ちている時でも、healthcheck 通知自体は **discord_notify.py が独立 HTTP REST クライアント** であるため Discord 経由で殿に届く (ゲートウェイプロセス discord_to_ntfy とは別経路)。

---

## テスト記録

### P0-3 引数互換テスト

**Test 1**: `NOTIFY_BACKEND=discord` dry-run
```
入力: --body "Phase0テスト notify.sh→discord 経路" --title "karo" --type "test"
出力 (54 chars):
  **karo**
  [vps] Phase0テスト notify.sh→discord 経路
  _(test)_
判定: PASS
```

**Test 2**: `NOTIFY_BACKEND=ntfy` dispatch trace
```
bash -x で notify.sh のフロー追跡:
  + BACKEND=ntfy
  + bash /home/ubuntu/shogun/scripts/ntfy.sh 'Phase0 ntfy fallback test' karo test
  + exit 0
判定: PASS (引数 1:1 で ntfy.sh に委譲)
```

**Test 3**: 不正 NOTIFY_BACKEND → exit 1
```
NOTIFY_BACKEND=foobar → "[notify.sh] ERROR: unknown NOTIFY_BACKEND=foobar" exit=1
判定: PASS
```

**Test 4**: body 空 → exit 1
```
NOTIFY_BACKEND=discord bash notify.sh "" → "body ($1) is required" exit=1
判定: PASS
```

**Test 5**: 自動 cmd_complete タグ検出
```
入力: --body "🏆 cmd_658 完了 — Phase01"
出力タグ: _(cmd_complete)_
判定: PASS (旧 ntfy.sh と同等の auto-detect ロジック)
```

**Test 6**: 2000 char 切り詰め
```
入力: --body "a"*2200
出力: 2000 char で末尾 "…(truncated)" 付加
判定: PASS
```

### P1-2 E2E DM 送信

```
$ bash scripts/notify.sh "【Phase1 E2Eテスト】notify.sh→discord_notify.py→Discord DM 経路確認 ash4より" "ash4_test" "test"
exit=0
$ tail -1 logs/discord_notify.log
2026-05-08 01:24:52,072 [INFO] delivered tag=test title='ash4_test' body_len=65 channel=1491959535768703097
```
**判定**: PASS (殿の Discord DM に到達確認)

### P1-4 dual-stack 観測

| 観測項目 | 状態 | 値 |
|---|---|---|
| ntfy_listener.sh プロセス | 稼働中 | PID 2404126, 2404185 |
| queue/ntfy_inbox.yaml | 既存 | 2026-05-07 07:04 最終更新 |
| discord_to_ntfy (旧 relay) | **停止中** | プロセス無 (Codex 報告と一致 — Phase 2 で再構築) |
| discord_notify.py (新 outbound) | 稼働確認 | 2 件 delivered |

---

## 既知の制約・リスク

1. **ntfy_listener.sh の inbound silent fail (継続)**: Codex 調査報告通り、ntfy_inbox.yaml の更新が稀。Phase 1 の outbound 切替には影響しないが、inbound は Phase 2 (`discord_gateway.py`) で根本対処予定。

2. **discord_to_ntfy.py プロセス停止**: 旧 Discord→ntfy リレーが現在停止中。Phase 1 outbound には影響なし (discord_notify.py は独立 REST クライアント)。inbound 経由で殿が Discord DM を送っても shogun に届かない状態 — Phase 2 で `discord_gateway.py` が直接 YAML mailbox 書込みする設計に置き換え予定。

3. **Token 二重管理**: `config/discord.env` と `config/discord_bot.env` に同じ `DISCORD_BOT_TOKEN` が存在。Phase 2 で統合 (どちらか一方に集約) 検討。

4. **ntfy.sh の保持**: ntfy.sh / lib/ntfy_auth.sh はまだ削除していない (Phase 3 で削除)。NOTIFY_BACKEND=ntfy fallback 経路として保持。

---

## 24h dual-stack 観測計画

- **観測開始**: 2026-05-08 01:27 JST
- **終了予定**: 2026-05-09 01:27 JST 以降
- **観測項目**:
  1. discord_notify.py 配送成功率 (`logs/discord_notify.log` の `delivered` カウント vs `failed`/`429`)
  2. 11 scripts の通知発火状況 (cron + on-demand)
  3. ntfy_listener.sh プロセス継続稼働 (regression なし)
  4. logs/discord_notify.log のエラーパターン
- **完了条件**: 24h で重大エラーなし → Phase 2 (inbound gateway) へ移行可

非同期観察。家老が別件処理する間に 24h 自然経過させる方針。

---

## Phase 2 への引継ぎメモ

- `scripts/discord_gateway.py` の新設 (Codex 提案: `discord_to_ntfy.py` 置換)
  - DM 受信 → `queue/external_inbox.yaml` (or 互換のため `queue/ntfy_inbox.yaml`) に直接 atomic write
  - `inbox_write.sh shogun ... discord_received discord_gateway` で shogun を起こす
  - allowlist (`DISCORD_ALLOWED_USER_IDS`) は既存パターン継承
- `shogun-discord.service.template` を gateway 用に更新
- `discord_bot_healthcheck.sh` の pgrep target を `discord_to_ntfy` → `discord_gateway` に変更
- `lib/ntfy_auth.sh` / `config/ntfy_auth.env*` は Phase 3 で削除
- Android `NtfyService.kt` は Phase 4 で別判断 (殿の運用方針による)

---

## 完了サマリ (殿向け)

- ✅ Phase 0 完了: env sample / wrapper / 互換テスト
- ✅ Phase 1 完了: discord_notify.py / NOTIFY_BACKEND=discord / 11 scripts 置換 / E2E DM 送信成功
- ✅ 24h dual-stack 観測開始
- 🟡 Phase 2 (inbound gateway) は別タスクで継続予定

ash4 これにて任務完了でござる。
