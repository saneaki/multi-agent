#!/usr/bin/env python3
# discord_to_ntfy.py — Discord Bot → ntfy 中継スクリプト
#
# [インストール手順]
#   pip install "discord.py>=2.3" httpx
#
# [Discord Bot作成手順]
#   1. https://discord.com/developers/applications にアクセス
#   2. "New Application" → アプリ名入力 → Create
#   3. 左メニュー "Bot" → "Add Bot"
#   4. Token をコピー → config/discord_bot.env の DISCORD_BOT_TOKEN に設定
#   5. Bot → Privileged Gateway Intents → "Message Content Intent" を ON にする
#   6. 左メニュー "OAuth2" → "URL Generator"
#      - Scopes: bot を選択
#      - Bot Permissions: Send Messages, Read Message History, Add Reactions
#      - 生成されたURLでBotをサーバーに招待
#
# [設定ファイル]
#   config/discord_bot.env  : BOT_TOKEN + 許可ユーザーID
#   config/ntfy_auth.env    : ntfy認証 (任意。なければ認証なし)
#
# [起動]
#   bash scripts/start_discord_bot.sh
#   # またはデバッグ用:
#   python3 scripts/discord_to_ntfy.py --dry-run

import argparse
import base64
import os
import sys
from pathlib import Path

import discord
import httpx

SCRIPT_DIR = Path(__file__).resolve().parent.parent
SETTINGS_PATH = SCRIPT_DIR / "config" / "settings.yaml"
DISCORD_BOT_ENV = SCRIPT_DIR / "config" / "discord_bot.env"
NTFY_AUTH_ENV = SCRIPT_DIR / "config" / "ntfy_auth.env"


def load_env_file(path: Path) -> dict:
    """Load key=value pairs from an env file, ignoring comments and blank lines."""
    env = {}
    if not path.exists():
        return env
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, value = line.partition("=")
                env[key.strip()] = value.strip()
    return env


def load_ntfy_topic() -> str:
    """Read ntfy_topic from config/settings.yaml."""
    if not SETTINGS_PATH.exists():
        return "hananoen"
    with open(SETTINGS_PATH, encoding="utf-8") as f:
        for line in f:
            if line.startswith("ntfy_topic:"):
                return line.split(":", 1)[1].strip().strip('"')
    return "hananoen"


def load_ntfy_auth_headers() -> dict:
    """Build ntfy Authorization header. Bearer token preferred, Basic auth fallback."""
    env = load_env_file(NTFY_AUTH_ENV)
    if token := env.get("NTFY_TOKEN"):
        return {"Authorization": f"Bearer {token}"}
    user = env.get("NTFY_USER")
    pwd = env.get("NTFY_PASS")
    if user and pwd:
        creds = base64.b64encode(f"{user}:{pwd}".encode()).decode()
        return {"Authorization": f"Basic {creds}"}
    return {}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Discord Bot → ntfy 中継スクリプト (Shogun input channel)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="ntfyにPOSTせずログ出力のみ (動作確認用)",
    )
    args = parser.parse_args()

    # --- Load bot config ---
    bot_env = load_env_file(DISCORD_BOT_ENV)
    token = bot_env.get("DISCORD_BOT_TOKEN") or os.environ.get("DISCORD_BOT_TOKEN", "")
    if not token or token == "your_bot_token_here":
        print(
            f"[ERROR] DISCORD_BOT_TOKEN が未設定です。{DISCORD_BOT_ENV} を編集してください。",
            file=sys.stderr,
        )
        sys.exit(1)

    allowed_ids_raw = bot_env.get("DISCORD_ALLOWED_USER_IDS") or os.environ.get(
        "DISCORD_ALLOWED_USER_IDS", ""
    )
    allowed_ids = {
        uid.strip()
        for uid in allowed_ids_raw.split(",")
        if uid.strip() and uid.strip() != "your_user_id_here"
    }
    if not allowed_ids:
        print(
            "[WARN] DISCORD_ALLOWED_USER_IDS が未設定です。全DMを拒否します。",
            file=sys.stderr,
        )

    ntfy_topic = load_ntfy_topic()
    ntfy_url = f"https://ntfy.sh/{ntfy_topic}"
    ntfy_auth_headers = load_ntfy_auth_headers()

    auth_mode = "token" if "Authorization" in ntfy_auth_headers else "none"
    print(f"[INFO] ntfy topic : {ntfy_topic}", file=sys.stderr)
    print(f"[INFO] ntfy auth  : {auth_mode}", file=sys.stderr)
    print(f"[INFO] 許可ユーザー: {allowed_ids or '(未設定)'}", file=sys.stderr)
    if args.dry_run:
        print("[INFO] DRY-RUN モード — ntfy への転送をスキップします", file=sys.stderr)

    # --- Discord client setup ---
    intents = discord.Intents.default()
    intents.message_content = True
    intents.dm_messages = True

    client = discord.Client(intents=intents, reconnect=True)

    @client.event
    async def on_ready() -> None:
        print(
            f"[INFO] ログイン完了: {client.user} (id: {client.user.id})",
            file=sys.stderr,
        )

    @client.event
    async def on_message(message: discord.Message) -> None:
        # DMのみ処理（サーバーチャンネルは無視）
        if not isinstance(message.channel, discord.DMChannel):
            return
        # Bot自身のメッセージは無視
        if message.author == client.user:
            return

        user_id = str(message.author.id)
        username = str(message.author)
        body = message.content

        # ホワイトリストチェック
        if allowed_ids and user_id not in allowed_ids:
            print(
                f"[WARN] 未許可ユーザーのDMを無視: {username} ({user_id})",
                file=sys.stderr,
            )
            return

        print(f"[INFO] DM受信 from {username}: {body!r}", file=sys.stderr)

        # ntfy POST
        if args.dry_run:
            print(
                f"[DRY-RUN] POST {ntfy_url} — title='[discord] {username}' body={body!r}",
                file=sys.stderr,
            )
        else:
            try:
                async with httpx.AsyncClient(timeout=10.0) as http:
                    resp = await http.post(
                        ntfy_url,
                        content=body.encode("utf-8"),
                        headers={
                            **ntfy_auth_headers,
                            "Title": f"[discord] {username}",
                            "Tags": "discord",
                            "Markdown": "yes",
                        },
                    )
                resp.raise_for_status()
                print(
                    f"[INFO] ntfy転送完了 (HTTP {resp.status_code})",
                    file=sys.stderr,
                )
            except Exception as exc:
                print(f"[ERROR] ntfy転送失敗: {exc}", file=sys.stderr)
                return

        # ✅ リアクション返却
        try:
            await message.add_reaction("✅")
        except Exception as exc:
            print(f"[WARN] リアクション追加失敗: {exc}", file=sys.stderr)

    client.run(token, reconnect=True)


if __name__ == "__main__":
    main()
