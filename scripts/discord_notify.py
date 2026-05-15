#!/usr/bin/env python3
"""
discord_notify.py — Discord 経由で殿に DM 送信 (cmd_658 Phase 1 outbound)

旧 scripts/ntfy.sh の互換代替。NOTIFY_BACKEND=discord 時に
notify.sh から呼び出される。

[Usage]
  python3 scripts/discord_notify.py --body "<body>" [--title "<title>"] \\
      [--type "<type_or_tag>"] [--priority normal|high|urgent] [--chunked]

[Config]
  config/discord.env:
    DISCORD_BOT_TOKEN          : Bot Token (required)
    DISCORD_LORD_DM_CHANNEL_ID : 殿の DM チャネル ID (preferred)
    DISCORD_LORD_USER_ID       : 殿の User ID (channel ID 未設定時に open_dm)

  config/discord_bot.env をフォールバックで読込 (token / allowed_user_ids)。

[Behavior]
  - Body 先頭に "[vps] " を付加 (旧 ntfy.sh と互換)
  - デフォルトでは 2000 文字超過時に安全に切り詰め (後方互換)
  - --chunked 指定時は約 1800 文字ごとに Part N/M 付きで分割送信
  - HTTP 429 受領時は Retry-After に従い指数バックオフで最大 3 回リトライ
  - 最終的に失敗しても exit 0 (best-effort) — 監視は logs/discord_notify.log で
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
DISCORD_ENV = PROJECT_DIR / "config" / "discord.env"
DISCORD_BOT_ENV = PROJECT_DIR / "config" / "discord_bot.env"
LOG_FILE = PROJECT_DIR / "logs" / "discord_notify.log"

DISCORD_API = "https://discord.com/api/v10"
MESSAGE_MAX = 2000
CHUNK_TARGET = 1800
MAX_RETRIES = 3
DEFAULT_TIMEOUT = 10.0


def setup_logger() -> logging.Logger:
    logger = logging.getLogger("discord_notify")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    handler.setFormatter(
        logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    )
    logger.addHandler(handler)
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
            value = value.strip().strip('"').strip("'")
            env[key.strip()] = value
    return env


def load_config() -> dict[str, str]:
    """Discord 設定を discord.env と discord_bot.env からマージして返す."""
    cfg: dict[str, str] = {}
    cfg.update(load_env_file(DISCORD_BOT_ENV))
    cfg.update(load_env_file(DISCORD_ENV))
    for key in (
        "DISCORD_BOT_TOKEN",
        "DISCORD_LORD_DM_CHANNEL_ID",
        "DISCORD_LORD_USER_ID",
        "DISCORD_ALLOWED_USER_IDS",
    ):
        if not cfg.get(key):
            cfg[key] = os.environ.get(key, "")
    return cfg


def detect_extra_tag(body: str, explicit: str) -> str:
    """ntfy.sh 互換: 明示指定が無い場合 cmd_complete を auto-detect."""
    if explicit:
        return explicit
    cmd_done = re.search(r"cmd_\d+(完了|完遂)", body) is not None
    cmd_predict = re.search(r"cmd_\d+(完了|完遂)(予定|見込)", body) is not None
    trophy_cmd = re.search(r"🏆.*cmd_\d+", body) is not None
    if (cmd_done and not cmd_predict) or trophy_cmd:
        return "cmd_complete"
    return ""


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    suffix = "…(truncated)"
    return text[: limit - len(suffix)] + suffix


def split_body_chunks(body: str, limit: int = CHUNK_TARGET) -> list[str]:
    """Split body into readable chunks without dropping content."""
    if limit <= 0:
        raise ValueError("chunk limit must be positive")
    if len(body) <= limit:
        return [body]

    chunks: list[str] = []
    remaining = body
    while len(remaining) > limit:
        split_at = remaining.rfind("\n", 0, limit + 1)
        if split_at < max(1, int(limit * 0.6)):
            split_at = remaining.rfind(" ", 0, limit + 1)
        if split_at < max(1, int(limit * 0.6)):
            split_at = limit
        chunks.append(remaining[:split_at].rstrip())
        remaining = remaining[split_at:].lstrip()
    chunks.append(remaining)
    return chunks


def format_message(body: str, title: str, tag: str) -> str:
    body_with_env = f"[vps] {body}"
    parts: list[str] = []
    if title:
        parts.append(f"**{title}**")
    parts.append(body_with_env)
    if tag:
        parts.append(f"_({tag})_")
    return truncate("\n".join(parts), MESSAGE_MAX)


def format_chunked_messages(body: str, title: str, tag: str) -> list[str]:
    """Format long body as Discord-safe Part N/M messages."""
    chunks = split_body_chunks(body, CHUNK_TARGET)
    while True:
        total = len(chunks)
        prefix_template = f"[vps] Part {total}/{total}\n"
        overhead_parts: list[str] = []
        if title:
            overhead_parts.append(f"**{title}**")
        overhead_parts.append(prefix_template)
        if tag:
            overhead_parts.append(f"_({tag})_")
        overhead = len("\n".join(overhead_parts))
        effective_limit = min(CHUNK_TARGET, MESSAGE_MAX - overhead - 1)
        if effective_limit <= 0:
            raise ValueError("title/tag overhead leaves no room for message body")
        next_chunks = split_body_chunks(body, effective_limit)
        if len(next_chunks) == total:
            chunks = next_chunks
            break
        chunks = next_chunks

    total = len(chunks)
    messages: list[str] = []
    for index, chunk in enumerate(chunks, start=1):
        body_with_part = f"Part {index}/{total}\n{chunk}"
        content = format_message(body_with_part, title, tag)
        if len(content) > MESSAGE_MAX:
            raise ValueError(f"chunk {index}/{total} exceeds Discord limit")
        messages.append(content)
    return messages


def format_messages(body: str, title: str, tag: str, *, chunked: bool) -> list[str]:
    if chunked:
        return format_chunked_messages(body, title, tag)
    return [format_message(body, title, tag)]


def http_request(
    url: str,
    *,
    method: str,
    token: str,
    payload: dict | None = None,
    timeout: float = DEFAULT_TIMEOUT,
) -> tuple[int, dict, dict]:
    """Return (status, headers_dict, body_json_or_empty)."""
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Authorization": f"Bot {token}",
        "User-Agent": "shogun-notify (cmd_658 Phase1, +https://example.local)",
        "Content-Type": "application/json",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            body_json = json.loads(raw) if raw else {}
            return resp.status, dict(resp.headers), body_json
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        try:
            body_json = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            body_json = {"raw": raw}
        return exc.code, dict(exc.headers or {}), body_json


def open_dm_channel(token: str, user_id: str, logger: logging.Logger) -> str | None:
    """User ID から DM チャネル ID を取得 (キャッシュなし、毎回呼出)."""
    status, _, body = http_request(
        f"{DISCORD_API}/users/@me/channels",
        method="POST",
        token=token,
        payload={"recipient_id": str(user_id)},
    )
    if status != 200:
        logger.error("open_dm_channel failed status=%s body=%s", status, body)
        return None
    return body.get("id")


def send_message_with_retry(
    token: str,
    channel_id: str,
    content: str,
    logger: logging.Logger,
) -> bool:
    url = f"{DISCORD_API}/channels/{channel_id}/messages"
    backoff = 1.0
    for attempt in range(1, MAX_RETRIES + 1):
        status, headers, body = http_request(
            url, method="POST", token=token, payload={"content": content}
        )
        if 200 <= status < 300:
            return True
        if status == 429:
            retry_after_hdr = headers.get("Retry-After") or headers.get("retry-after")
            try:
                wait_s = float(retry_after_hdr) if retry_after_hdr else backoff
            except ValueError:
                wait_s = backoff
            wait_s = min(max(wait_s, 0.5), 30.0)
            logger.warning(
                "429 received attempt=%s wait=%.1fs body=%s", attempt, wait_s, body
            )
            time.sleep(wait_s)
            backoff *= 2
            continue
        if 500 <= status < 600 and attempt < MAX_RETRIES:
            logger.warning(
                "5xx received attempt=%s status=%s wait=%.1fs", attempt, status, backoff
            )
            time.sleep(backoff)
            backoff *= 2
            continue
        logger.error("send_message failed status=%s body=%s", status, body)
        return False
    logger.error("send_message exhausted retries (max=%s)", MAX_RETRIES)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", required=True, help="message body (required)")
    parser.add_argument("--title", default="", help="title prefix (optional)")
    parser.add_argument(
        "--type", default="", help="extra tag / type marker (optional)"
    )
    parser.add_argument(
        "--priority",
        default="normal",
        choices=("normal", "high", "urgent"),
        help="(reserved for future Discord embed coloring)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="format-only test, no API call"
    )
    parser.add_argument(
        "--chunked",
        action="store_true",
        help="split long messages into Discord-safe Part N/M chunks",
    )
    args = parser.parse_args()

    logger = setup_logger()
    cfg = load_config()
    token = cfg.get("DISCORD_BOT_TOKEN", "")
    if not token or token == "your_bot_token_here":
        logger.error("DISCORD_BOT_TOKEN not configured (config/discord.env)")
        print(
            "[discord_notify] ERROR: DISCORD_BOT_TOKEN not configured", file=sys.stderr
        )
        return 1

    tag = detect_extra_tag(args.body, args.type)
    contents = format_messages(args.body, args.title, tag, chunked=args.chunked)

    if args.dry_run:
        print(
            f"[discord_notify] DRY-RUN — formatted {len(contents)} part(s):"
        )
        for index, content in enumerate(contents, start=1):
            print(f"--- part {index}/{len(contents)} ({len(content)} chars) ---")
            print(content)
        return 0

    channel_id = cfg.get("DISCORD_LORD_DM_CHANNEL_ID", "").strip()
    if not channel_id:
        user_id = cfg.get("DISCORD_LORD_USER_ID", "").strip()
        if not user_id:
            ids_raw = cfg.get("DISCORD_ALLOWED_USER_IDS", "").strip()
            user_id = ids_raw.split(",")[0].strip() if ids_raw else ""
        if not user_id or user_id == "your_user_id_here":
            logger.error("no DM target: DISCORD_LORD_DM_CHANNEL_ID and USER_ID empty")
            print(
                "[discord_notify] ERROR: no DM target configured", file=sys.stderr
            )
            return 1
        channel_id = open_dm_channel(token, user_id, logger) or ""
        if not channel_id:
            print(
                "[discord_notify] ERROR: failed to open DM channel", file=sys.stderr
            )
            return 1

    for index, content in enumerate(contents, start=1):
        ok = send_message_with_retry(token, channel_id, content, logger)
        if ok:
            logger.info(
                "delivered part=%s/%s tag=%s title=%r body_len=%s channel=%s",
                index,
                len(contents),
                tag,
                args.title,
                len(args.body),
                channel_id,
            )
    return 0  # best-effort: do not propagate failure to callers


if __name__ == "__main__":
    sys.exit(main())
