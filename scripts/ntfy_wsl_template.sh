#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ntfy WSL送信テンプレート
# WSL環境からntfyでメッセージを送信するスクリプト雛形。
# [wsl]タグを自動付与し、VPS側リスナーが他環境通知として識別可能にする。
#
# 使い方:
#   1. このファイルをWSL環境にコピー
#   2. NTFY_TOPIC を設定（config/settings.yamlのntfy_topicと同じ値）
#   3. 認証が必要な場合は NTFY_TOKEN を設定
#   4. bash ntfy_wsl_template.sh "メッセージ" ["タイトル"]
# ═══════════════════════════════════════════════════════════════

# --- 設定 ---
# ntfyトピック（VPSのconfig/settings.yaml → ntfy_topic と同じ値を設定）
NTFY_TOPIC="${NTFY_TOPIC:-}"
# ntfy認証トークン（Bearer token。不要な場合は空のまま）
NTFY_TOKEN="${NTFY_TOKEN:-}"

if [ -z "$NTFY_TOPIC" ]; then
    echo "Error: NTFY_TOPIC is not set." >&2
    echo "Set it via environment variable or edit this script." >&2
    exit 1
fi

# --- 環境タグ ---
ENV_TAG="wsl"

# --- 引数 ---
MESSAGE="$1"
TITLE="${2:-}"

if [ -z "$MESSAGE" ]; then
    echo "Usage: $0 \"message\" [\"title\"]" >&2
    exit 1
fi

# メッセージ先頭に環境タグを付与
TAGGED_MESSAGE="[$ENV_TAG] $MESSAGE"

# --- curl ヘッダー構築 ---
CURL_HEADERS=()
CURL_HEADERS+=(-H "Tags: outbound")
CURL_HEADERS+=(-H "Markdown: yes")
if [ -n "$TITLE" ]; then
    CURL_HEADERS+=(-H "Title: $TITLE")
fi

AUTH_ARGS=()
if [ -n "$NTFY_TOKEN" ]; then
    AUTH_ARGS+=(-H "Authorization: Bearer $NTFY_TOKEN")
fi

# --- 送信 ---
curl -s "${AUTH_ARGS[@]}" "${CURL_HEADERS[@]}" -d "$TAGGED_MESSAGE" "https://ntfy.sh/$NTFY_TOPIC" > /dev/null

echo "Sent [$ENV_TAG]: $MESSAGE"
