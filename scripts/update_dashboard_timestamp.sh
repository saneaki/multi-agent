#!/usr/bin/env bash
# update_dashboard_timestamp.sh — dashboard.mdの「最終更新:」行をJST現在時刻に書き換える
# 使用方法: bash scripts/update_dashboard_timestamp.sh
# 環境変数: DASHBOARD_PATH — 指定があればそのパスを使用（テスト用）

set -euo pipefail

# PostToolUse hook compatibility: stdinのツール結果JSONを消費する
cat > /dev/null 2>&1 || true

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

# 「最終更新:」行を書き換え
sed -i "s|^最終更新:.*|最終更新: $JST_NOW|" "$DASHBOARD"

echo "更新完了: 最終更新: $JST_NOW"
