# 通知チャネル仕様書

Shogun マルチエージェントシステムの外部通知チャネル仕様。
殿（Lord）とShogun間の双方向通信を担う。

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────┐
│                    殿（Lord）                         │
│                                                     │
│   スマホ ntfy アプリ    Discord DM                    │
│        │                   │                        │
└────────┼───────────────────┼────────────────────────┘
         │                   │
    ┌────▼────┐        ┌─────▼──────────────┐
    │ ntfy.sh │        │ discord_to_ntfy.py │
    │ (直接)  │        │ (Bot → ntfy中継)    │
    └────┬────┘        └─────┬──────────────┘
         │                   │
    ┌────▼───────────────────▼────┐
    │   ntfy.sh サーバー           │
    │   topic: hananoen           │
    └────────────┬────────────────┘
                 │
    ┌────────────▼────────────────┐
    │   ntfy_listener.sh          │
    │   (VPS常駐・ストリーミング)   │
    └────────────┬────────────────┘
                 │
    ┌────────────▼────────────────┐
    │   queue/ntfy_inbox.yaml     │
    │   (status: pending)         │
    └────────────┬────────────────┘
                 │
    ┌────────────▼────────────────┐
    │   Shogun が処理              │
    │   → ntfy.sh で返信          │
    └─────────────────────────────┘
```

## チャネル1: ntfy（プライマリ）

### 概要

ntfy.sh を利用したHTTPベースのプッシュ通知チャネル。
スマホアプリから直接メッセージ送信が可能。

### 送信フロー（殿 → Shogun）

1. 殿がスマホの ntfy アプリでメッセージ送信
2. ntfy.sh サーバーが受信
3. `ntfy_listener.sh` がストリーミング接続でメッセージ検出
4. `queue/ntfy_inbox.yaml` に `status: pending` で書込み
5. `queue/inbox/shogun.yaml` に `type: ntfy_received` で通知
6. Shogun が ntfy_inbox.yaml を読み、処理後 `status: processed` に更新

### 返信フロー（Shogun → 殿）

1. Shogun が `bash scripts/ntfy.sh "メッセージ"` を実行
2. ntfy.sh サーバー経由でスマホにプッシュ通知

### 設定ファイル

| ファイル | 用途 |
|---------|------|
| `config/settings.yaml` | `ntfy_topic: hananoen` — トピック名 |
| `config/ntfy_auth.env` | ntfy認証情報（Bearer token or Basic auth） |
| `lib/ntfy_auth.sh` | 認証ヘルパーライブラリ |

### スクリプト

| スクリプト | 役割 |
|-----------|------|
| `scripts/ntfy.sh` | Shogun → 殿への送信。`[vps]` タグ自動付与。`cmd_complete` タグ自動検出 |
| `scripts/ntfy_listener.sh` | 殿 → Shogun の受信。ntfy ストリーミングAPI使用（ポーリングではない） |

### ntfy.sh の引数

```bash
bash scripts/ntfy.sh "メッセージ本文" "タイトル(任意)" "追加タグ(任意)"
```

- 第1引数: メッセージ本文（自動で `[vps]` プレフィックス付与）
- 第2引数: タイトル（省略可）
- 第3引数: 追加タグ（省略可。`cmd_complete` は自動検出）

### ホスト制限

`ntfy_listener.sh` は `srv1121380`（VPS）でのみ稼働。
他ホスト（WSL2等）では二重応答防止のため自動終了。

## チャネル2: Discord（セカンダリ）

### 概要

Discord Bot を介した中継チャネル。
殿のDiscord DMをntfyに転送し、既存パイプラインに統合。

### 送信フロー（殿 → Shogun）

1. 殿が Discord で Bot（shogun#7465）に DM 送信
2. `discord_to_ntfy.py` が DM を検出
3. ntfy.sh サーバーに HTTP POST（Title: `[discord] ユーザー名`）
4. 以降は ntfy チャネルと同じフロー
5. Bot が ✅ リアクションを返却

### 返信フロー（Shogun → 殿）

現状は**一方通行**。Shogun → 殿 の返信は ntfy 経由のみ。
将来的に Discord API を使った双方向化が可能（未実装）。

### 設定ファイル

| ファイル | 用途 |
|---------|------|
| `config/discord_bot.env` | Bot Token + 許可ユーザーID（**git追跡外**） |
| `config/discord_bot.env.sample` | サンプルファイル（git追跡対象） |

### discord_bot.env の設定項目

```bash
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_ALLOWED_USER_IDS=123456789012345678
```

- `DISCORD_BOT_TOKEN`: Discord Developer Portal で取得した Bot Token
- `DISCORD_ALLOWED_USER_IDS`: 許可する Discord User ID（カンマ区切りで複数可）

### スクリプト

| スクリプト | 役割 |
|-----------|------|
| `scripts/discord_to_ntfy.py` | Discord Bot 本体。DM受信 → ntfy POST |
| `scripts/start_discord_bot.sh` | 起動スクリプト。tmux window `shogun-discord` で常駐 |

### 依存関係

```bash
# venv: .venv/discord-bot/
pip install "discord.py>=2.3" httpx
```

venv パス: `/home/ubuntu/shogun/.venv/discord-bot/`

### 起動・停止

```bash
# 起動
bash scripts/start_discord_bot.sh

# DRY-RUN（ntfy転送なし、動作確認用）
bash scripts/start_discord_bot.sh --dry-run

# 停止
tmux kill-window -t multiagent:shogun-discord
```

### セキュリティ

- DM のみ処理（サーバーテキストチャンネルは無視）
- ホワイトリスト外ユーザーの DM はログ出力のみで無視
- Bot Token は環境変数/env ファイルで管理（ハードコード禁止）
- `config/discord_bot.env` は `.gitignore` で追跡除外

### Discord Bot 作成手順

1. https://discord.com/developers/applications にアクセス
2. New Application → アプリ名入力 → Create
3. 左メニュー Bot → Token をコピー
4. Bot → Privileged Gateway Intents → Message Content Intent を ON
5. OAuth2 → URL Generator → Scopes: bot → Permissions: Send Messages, Read Message History, Add Reactions
6. 生成 URL でサーバーに招待

## 併用構成

ntfy と Discord は独立して動作し、併用可能。

| 入力チャネル | 出力先 | Shogun側の処理 |
|-------------|--------|---------------|
| ntfy アプリ | ntfy_inbox.yaml | 直接処理 |
| Discord DM | ntfy → ntfy_inbox.yaml | ntfy 経由で同一処理 |

Shogun は入力元を区別せず、`ntfy_inbox.yaml` の `status: pending` エントリを統一的に処理する。
Discord 経由のメッセージは ntfy の Title に `[discord]` プレフィックスが付与されるため、ログで識別可能。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| ntfy メッセージが届かない | ntfy_listener.sh が停止 | `ps aux \| grep ntfy_listener` で確認。停止なら再起動 |
| Discord DM が届かない | Bot が停止 | `tmux list-windows -t multiagent` で `shogun-discord` 確認 |
| Discord Bot 起動失敗 | Token 未設定 | `config/discord_bot.env` の `DISCORD_BOT_TOKEN` を確認 |
| Discord DM を送っても ✅ がつかない | ホワイトリスト外 | `DISCORD_ALLOWED_USER_IDS` に User ID を追加 |
| pip install 失敗 | PEP 668 制限 | venv 使用: `.venv/discord-bot/bin/pip install` |
| ntfy 認証エラー | Token 期限切れ | `config/ntfy_auth.env` の Token を更新 |
