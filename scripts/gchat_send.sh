#!/bin/bash
# GChat Webhook送信ラッパー (429レート制限対策: sleep 5)
# Usage: bash scripts/gchat_send.sh "$MESSAGE"
source /home/ubuntu/shogun/.env
curl -s -X POST -H 'Content-Type: application/json' \
  -d "{\"text\": \"$(echo "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])')\"}" \
  "$GCHAT_WEBHOOK_URL"
sleep 5
