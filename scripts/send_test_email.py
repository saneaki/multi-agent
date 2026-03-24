#!/usr/bin/env python3
"""Gmail WF テストメール送信スクリプト.

Usage:
    python3 scripts/send_test_email.py
    python3 scripts/send_test_email.py --subject "カスタム件名"
    python3 scripts/send_test_email.py --body "カスタム本文"

環境変数 (.env):
    GMAIL_TEST_SENDER   - 送信元Gmailアドレス
    GMAIL_APP_PASSWORD   - Google App Password (スペースなし16文字)
    GMAIL_TEST_RECIPIENT - 送信先 (Gmail Trigger監視対象)
"""

import argparse
import os
import smtplib
import sys
from datetime import datetime, timezone, timedelta
from email.mime.text import MIMEText
from pathlib import Path

ENV_PATH = Path("/home/ubuntu/.n8n-mcp/n8n/.env")
JST = timezone(timedelta(hours=9))


def load_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


def send_test_email(subject: str, body: str) -> bool:
    env = load_env(ENV_PATH)
    sender = env.get("GMAIL_TEST_SENDER", "")
    password = env.get("GMAIL_APP_PASSWORD", "")
    recipient = env.get("GMAIL_TEST_RECIPIENT", "")

    if not all([sender, password, recipient]):
        print("ERROR: GMAIL_TEST_SENDER, GMAIL_APP_PASSWORD, GMAIL_TEST_RECIPIENT required in .env")
        return False

    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = recipient

    try:
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(sender, password)
            server.sendmail(sender, [recipient], msg.as_string())
        print(f"OK: sent from {sender} to {recipient}")
        print(f"Subject: {subject}")
        return True
    except smtplib.SMTPAuthenticationError as e:
        print(f"AUTH ERROR: {e}")
        print("Check: App Password correct? 2FA enabled? Less secure apps?")
        return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Gmail WF test email sender")
    now = datetime.now(JST).strftime("%Y-%m-%d %H:%M JST")
    parser.add_argument("--subject", default=f"[TEST] WF自動テスト {now}")
    parser.add_argument("--body", default=f"これはGmail WF自動テスト用メールです。\n送信時刻: {now}\n\n自動生成 - shogun system")
    args = parser.parse_args()

    ok = send_test_email(args.subject, args.body)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
