#!/usr/bin/env bash
# update_dashboard_timestamp.sh — dashboard.mdの「最終更新:」行をJST現在時刻に書き換える
# PostToolUse hookから呼ばれる場合: stdinのJSONからfile_pathを判定し、dashboard.mdのみ処理
# 手動実行も可: stdin が空なら無条件で実行
# 環境変数: DASHBOARD_PATH — 指定があればそのパスを使用（テスト用）

set -euo pipefail

# stdinからJSONを読み取る（hook経由の場合）
INPUT=$(cat 2>/dev/null || true)

# file_path判定: hook経由ならdashboard.mdか確認、手動実行なら無条件実行
if [ -n "$INPUT" ]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
    if [ -n "$FILE_PATH" ] && [[ "$FILE_PATH" != *"dashboard.md"* ]]; then
        exit 0
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# dashboard.mdのパス決定
DASHBOARD="${DASHBOARD_PATH:-"$SCRIPT_DIR/../dashboard.md"}"

# dashboard.mdの存在確認
if [ ! -f "$DASHBOARD" ]; then
    echo "ERROR: dashboard.md が見つかりません: $DASHBOARD" >&2
    exit 1
fi

# JST現在時刻を取得
JST_NOW="$(bash "$SCRIPT_DIR/jst_now.sh")"

# 「最終更新:」行を書き換え (macOS BSD sed / GNU sed 両対応)
if sed --version >/dev/null 2>&1; then
    sed -i "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"
else
    sed -i '' "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"
fi

echo "更新完了: 最終更新: $JST_NOW" >&2
