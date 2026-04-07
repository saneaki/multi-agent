#!/usr/bin/env python3
"""
n8n_feedback_append.py — n8n feedback-system ワークフローから呼び出されるヘルパー
stdin から JSON を読み込み、queue/inbox/shogun.yaml に feedback エントリを追記する。
呼び出し方: echo '<base64>' | base64 -d | python3 /home/ubuntu/shogun/scripts/n8n_feedback_append.py
"""

import yaml
import json
import os
import sys

SHOGUN_INBOX = '/home/ubuntu/shogun/queue/inbox/shogun.yaml'

def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw)
    except Exception as e:
        print(f'ERROR: failed to parse input JSON: {e}', file=sys.stderr)
        sys.exit(1)

    entry = {
        'id': data.get('id', 'unknown'),
        'timestamp': data.get('timestamp', ''),
        'from': data.get('sender', 'anonymous'),
        'type': 'feedback',
        'read': False,
        'content': '\n'.join([
            f'【種別】{data.get("feedbackType", "")}',
            f'【緊急度】{data.get("urgency", "")}',
            f'【対象】{data.get("project", "")}',
            f'【タイトル】{data.get("title", "")}',
            f'【詳細】{data.get("detail", "")}',
        ])
    }

    try:
        with open(SHOGUN_INBOX, 'r', encoding='utf-8') as f:
            doc = yaml.safe_load(f) or {}
        if 'messages' not in doc or doc['messages'] is None:
            doc['messages'] = []
        doc['messages'].append(entry)

        tmp = SHOGUN_INBOX + '.tmp.' + str(os.getpid())
        with open(tmp, 'w', encoding='utf-8') as f:
            yaml.dump(doc, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
        os.replace(tmp, SHOGUN_INBOX)
        print(f'OK: feedback appended — id={entry["id"]}')
    except Exception as e:
        print(f'ERROR: failed to write shogun.yaml: {e}', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
