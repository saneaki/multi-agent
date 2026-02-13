#!/bin/bash
# SayTask通知 — ntfy.sh経由でスマホにプッシュ通知
# FR-066: ntfy認証対応 (Bearer token / Basic auth)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$SCRIPT_DIR/config/settings.yaml"

# ntfy_auth.sh読み込み
# shellcheck source=../lib/ntfy_auth.sh
source "$SCRIPT_DIR/lib/ntfy_auth.sh"

TOPIC=$(grep 'ntfy_topic:' "$SETTINGS" | awk '{print $2}' | tr -d '"')
if [ -z "$TOPIC" ]; then
  echo "ntfy_topic not configured in settings.yaml" >&2
  exit 1
fi

# 認証引数を取得（設定がなければ空 = 後方互換）
AUTH_ARGS=()
while IFS= read -r line; do
    [ -n "$line" ] && AUTH_ARGS+=("$line")
done < <(ntfy_get_auth_args "$SCRIPT_DIR/config/ntfy_auth.env")

# メッセージとTitle（オプション）
MESSAGE="$1"
TITLE="${2:-}"

# curlヘッダー構築
CURL_HEADERS=()
CURL_HEADERS+=(-H "Tags: outbound")
CURL_HEADERS+=(-H "Markdown: yes")
if [[ -n "$TITLE" ]]; then
  CURL_HEADERS+=(-H "Title: $TITLE")
fi

# shellcheck disable=SC2086
curl -s "${AUTH_ARGS[@]}" "${CURL_HEADERS[@]}" -d "$MESSAGE" "https://ntfy.sh/$TOPIC" > /dev/null
