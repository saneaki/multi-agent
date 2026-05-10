#!/usr/bin/env python3
"""
discord_gateway.py — Discord DM inbound gateway (cmd_658 Phase 2)

旧 scripts/discord_to_ntfy.py の置換。Discord DM を受信し、
中継 (ntfy) を介さず queue/external_inbox.yaml に直接 atomic 書込し、
inbox_write.sh で shogun に discord_received イベントを通知する。

[Pipeline]
  Discord DM → on_message → allowlist filter
              → external_inbox.yaml に atomic + flock 書込
              → inbox_write.sh shogun "discord_received: ..." discord_received discord_gateway
              → ✅ ack reaction (best-effort)

[Config]
  config/discord.env:
    DISCORD_BOT_TOKEN          : Bot Token (required)
    DISCORD_ALLOWED_USER_IDS   : 許可ユーザー ID (comma-separated; required for filtering)

  config/discord_bot.env をフォールバックで読込 (旧 discord_to_ntfy.py 互換)。

[YAML schema] (ntfy_inbox.yaml 互換シェイプ + Discord 固有フィールド)
  inbox:
    - id: <discord_message_id_str>   # ntfy 互換
      message: <body>                 # ntfy 互換
      timestamp: <ISO+09:00>           # ntfy 互換
      status: pending                  # ntfy 互換 (pending|delegated_to_karo|processed)
      # Discord 固有
      discord_message_id: <str>
      channel_id: <str>
      user_id: <str>
      username: <str>
      received_at: <ISO+09:00>
"""

from __future__ import annotations

import argparse
import fcntl
import logging
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

import discord
import yaml

PROJECT_DIR = Path(__file__).resolve().parent.parent
DISCORD_ENV = PROJECT_DIR / "config" / "discord.env"
DISCORD_BOT_ENV = PROJECT_DIR / "config" / "discord_bot.env"
EXTERNAL_INBOX = PROJECT_DIR / "queue" / "external_inbox.yaml"
INBOX_WRITE_SH = PROJECT_DIR / "scripts" / "inbox_write.sh"
LOG_FILE = PROJECT_DIR / "logs" / "discord_gateway.log"

JST = timezone(timedelta(hours=9))
MESSAGE_TRUNCATE = 4000  # external_inbox 保存時の本文上限
SHOGUN_INBOX_SUMMARY_TRUNCATE = 1900  # Discord 2000文字制限と inbox_write 4096 byte 制限の手前


def setup_logger() -> logging.Logger:
    logger = logging.getLogger("discord_gateway")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    )
    logger.addHandler(handler)
    stream = logging.StreamHandler(sys.stderr)
    stream.setFormatter(
        logging.Formatter("[%(levelname)s] %(message)s")
    )
    logger.addHandler(stream)
    return logger


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.exists():
        return env
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def load_config() -> dict[str, str]:
    """Merge discord_bot.env (legacy) and discord.env (cmd_658)."""
    cfg: dict[str, str] = {}
    cfg.update(load_env_file(DISCORD_BOT_ENV))
    cfg.update(load_env_file(DISCORD_ENV))
    for key in ("DISCORD_BOT_TOKEN", "DISCORD_ALLOWED_USER_IDS"):
        if not cfg.get(key):
            cfg[key] = os.environ.get(key, "")
    return cfg


def parse_allowed_ids(raw: str) -> set[str]:
    return {
        uid.strip()
        for uid in (raw or "").split(",")
        if uid.strip() and uid.strip() != "your_user_id_here"
    }


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 13] + "…(truncated)"


def jst_now_iso() -> str:
    return datetime.now(JST).isoformat(timespec="seconds")


def append_inbox_atomic(entry: dict, logger: logging.Logger) -> bool:
    """
    queue/external_inbox.yaml に atomic 追記。
    fcntl.flock でクリティカルセクションを保護し、tempfile + os.replace で
    途中断時の半端書込を防ぐ。
    """
    EXTERNAL_INBOX.parent.mkdir(parents=True, exist_ok=True)
    lock_path = EXTERNAL_INBOX.with_suffix(EXTERNAL_INBOX.suffix + ".lock")
    try:
        with open(lock_path, "w") as lock_f:
            try:
                fcntl.flock(lock_f.fileno(), fcntl.LOCK_EX)
            except OSError as exc:
                logger.error("flock failed: %s", exc)
                return False
            try:
                if EXTERNAL_INBOX.exists():
                    with open(EXTERNAL_INBOX, encoding="utf-8") as f:
                        data = yaml.safe_load(f) or {}
                else:
                    data = {}
                if not isinstance(data, dict):
                    data = {}
                inbox = data.get("inbox")
                if not isinstance(inbox, list):
                    inbox = []
                inbox.append(entry)
                data["inbox"] = inbox
                tmp_fd, tmp_path = tempfile.mkstemp(
                    prefix=".external_inbox.",
                    suffix=".tmp",
                    dir=str(EXTERNAL_INBOX.parent),
                )
                try:
                    with os.fdopen(tmp_fd, "w", encoding="utf-8") as tmp_f:
                        yaml.safe_dump(
                            data,
                            tmp_f,
                            allow_unicode=True,
                            default_flow_style=False,
                            sort_keys=False,
                        )
                        tmp_f.flush()
                        os.fsync(tmp_f.fileno())
                    os.replace(tmp_path, EXTERNAL_INBOX)
                except Exception:
                    try:
                        os.unlink(tmp_path)
                    except FileNotFoundError:
                        pass
                    raise
                return True
            finally:
                fcntl.flock(lock_f.fileno(), fcntl.LOCK_UN)
    except Exception as exc:
        logger.error("append_inbox_atomic failed: %s", exc)
        return False


def notify_shogun(summary: str, logger: logging.Logger) -> bool:
    """inbox_write.sh shogun "discord_received: ..." discord_received discord_gateway."""
    if not INBOX_WRITE_SH.exists():
        logger.error("inbox_write.sh not found at %s", INBOX_WRITE_SH)
        return False
    try:
        result = subprocess.run(
            [
                "bash",
                str(INBOX_WRITE_SH),
                "shogun",
                f"discord_received: {summary}",
                "discord_received",
                "discord_gateway",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            logger.error(
                "inbox_write rc=%s stdout=%s stderr=%s",
                result.returncode,
                result.stdout.strip(),
                result.stderr.strip(),
            )
            return False
        return True
    except subprocess.TimeoutExpired:
        logger.error("inbox_write timed out")
        return False
    except Exception as exc:
        logger.error("notify_shogun failed: %s", exc)
        return False


def build_entry(message: discord.Message) -> dict:
    body = truncate(message.content or "", MESSAGE_TRUNCATE)
    received = jst_now_iso()
    discord_msg_id = str(message.id)
    return {
        # ntfy_inbox.yaml 互換
        "id": discord_msg_id,
        "message": body,
        "timestamp": received,
        "status": "pending",
        # Discord 固有
        "discord_message_id": discord_msg_id,
        "channel_id": str(message.channel.id),
        "user_id": str(message.author.id),
        "username": str(message.author),
        "received_at": received,
    }


def run_bot(token: str, allowed_ids: set[str], logger: logging.Logger, *, dry_run: bool) -> None:
    intents = discord.Intents.default()
    intents.message_content = True
    intents.dm_messages = True

    client = discord.Client(intents=intents, reconnect=True)

    @client.event
    async def on_ready() -> None:
        user = client.user
        logger.info("logged in as %s (id=%s) allowlist=%s", user, user.id if user else "?", allowed_ids or "(empty)")

    @client.event
    async def on_message(message: discord.Message) -> None:
        if not isinstance(message.channel, discord.DMChannel):
            return
        if client.user and message.author.id == client.user.id:
            return

        user_id = str(message.author.id)
        username = str(message.author)
        body = message.content or ""

        if allowed_ids and user_id not in allowed_ids:
            logger.warning("DM rejected (not in allowlist): %s (%s)", username, user_id)
            return

        logger.info("DM received from %s: %r", username, body[:200])

        entry = build_entry(message)

        if dry_run:
            logger.info("[DRY-RUN] entry=%s", entry)
            return

        if not append_inbox_atomic(entry, logger):
            logger.error("yaml append failed; skipping ack for msg=%s", entry["id"])
            return

        summary = f"{username} | {body[:SHOGUN_INBOX_SUMMARY_TRUNCATE]}"
        if not notify_shogun(summary, logger):
            logger.warning("inbox_write to shogun failed; ack still attempted")

        try:
            await message.add_reaction("✅")
        except Exception as exc:
            logger.warning("ack reaction failed: %s", exc)

    client.run(token, reconnect=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run", action="store_true", help="開始ログ・受信ログのみ、yaml/inbox は書込まない"
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Discord 接続せず append_inbox_atomic + notify_shogun のみテスト",
    )
    args = parser.parse_args()

    logger = setup_logger()
    cfg = load_config()
    token = cfg.get("DISCORD_BOT_TOKEN", "")
    if not token or token == "your_bot_token_here":
        logger.error("DISCORD_BOT_TOKEN not configured (config/discord.env)")
        return 1

    allowed_ids = parse_allowed_ids(cfg.get("DISCORD_ALLOWED_USER_IDS", ""))
    if not allowed_ids:
        logger.warning("DISCORD_ALLOWED_USER_IDS empty — all DMs will be rejected")

    if args.self_test:
        now = jst_now_iso()
        synthetic = {
            "id": f"selftest_{int(datetime.now().timestamp())}",
            "message": "self-test entry from discord_gateway --self-test",
            "timestamp": now,
            "status": "pending",
            "discord_message_id": f"selftest_{int(datetime.now().timestamp())}",
            "channel_id": "0",
            "user_id": "0",
            "username": "selftest",
            "received_at": now,
        }
        if not append_inbox_atomic(synthetic, logger):
            return 1
        notify_shogun("self-test from discord_gateway", logger)
        logger.info("self-test ok")
        return 0

    run_bot(token, allowed_ids, logger, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
