#!/usr/bin/env python3
"""Unit tests for scripts/discord_notify.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = PROJECT_ROOT / "scripts" / "discord_notify.py"


spec = importlib.util.spec_from_file_location("discord_notify", MODULE_PATH)
assert spec and spec.loader
discord_notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(discord_notify)


class DiscordNotifyFormattingTest(unittest.TestCase):
    def test_default_long_message_is_truncated_for_backward_compatibility(self) -> None:
        content = discord_notify.format_messages(
            "x" * 5000,
            "Long title",
            "approval",
            chunked=False,
        )

        self.assertEqual(len(content), 1)
        self.assertLessEqual(len(content[0]), discord_notify.MESSAGE_MAX)
        self.assertIn("(truncated)", content[0])

    def test_chunked_long_message_keeps_title_tag_and_all_parts(self) -> None:
        body = "\n".join([f"line-{i:03d} " + ("x" * 90) for i in range(80)])
        content = discord_notify.format_messages(
            body,
            "Lord approval",
            "decision",
            chunked=True,
        )

        self.assertGreaterEqual(len(content), 4)
        self.assertLessEqual(len(content), 6)
        for index, part in enumerate(content, start=1):
            self.assertLessEqual(len(part), discord_notify.MESSAGE_MAX)
            self.assertIn("**Lord approval**", part)
            self.assertIn("_(decision)_", part)
            self.assertIn(f"Part {index}/{len(content)}", part)
            self.assertNotIn("(truncated)", part)
        self.assertIn("line-000", content[0])
        self.assertIn("line-079", content[-1])

    def test_chunked_short_message_stays_one_part(self) -> None:
        content = discord_notify.format_messages(
            "short message",
            "Title",
            "notice",
            chunked=True,
        )

        self.assertEqual(len(content), 1)
        self.assertIn("Part 1/1", content[0])
        self.assertIn("short message", content[0])


if __name__ == "__main__":
    unittest.main()
