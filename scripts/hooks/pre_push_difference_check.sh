#!/usr/bin/env bash
# ============================================================
# pre-push hook: difference.md更新チェック
# shogunリポジトリ専用。difference.mdの生成日が当日(JST)でなければpushを拒否する。
# ============================================================

set -euo pipefail

SHOGUN_ROOT="$(git rev-parse --show-toplevel)"

# shogunリポジトリ以外では発動しない
REPO_NAME=$(basename "$SHOGUN_ROOT")
if [ "$REPO_NAME" != "shogun" ] && [ "$REPO_NAME" != "multi-agent" ]; then
    exit 0
fi

DIFF_FILE="${SHOGUN_ROOT}/difference.md"
JST_NOW_SCRIPT="${SHOGUN_ROOT}/scripts/jst_now.sh"

# difference.mdが存在しない場合はスキップ
if [ ! -f "$DIFF_FILE" ]; then
    exit 0
fi

# jst_now.shが存在しない場合はスキップ
if [ ! -f "$JST_NOW_SCRIPT" ]; then
    exit 0
fi

TODAY=$(bash "$JST_NOW_SCRIPT" --date 2>/dev/null || date -u +"%Y-%m-%d")

# difference.mdからGenerated日付を抽出
# フォーマット例: "Generated: 2026-03-31" または "<!-- Generated: 2026-03-31 -->"
GENERATED_DATE=$(grep -m1 "Generated" "$DIFF_FILE" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1 || echo "")

if [ -z "$GENERATED_DATE" ]; then
    echo "⚠️ [pre-push] difference.mdのGenerated日付を抽出できませんでした。pushを続行します。" >&2
    exit 0
fi

if [ "$GENERATED_DATE" != "$TODAY" ]; then
    echo "❌ [pre-push] difference.mdが未更新です！" >&2
    echo "   Generated: ${GENERATED_DATE} (today: ${TODAY})" >&2
    echo "   shogunリポジトリのpush前に /pub-uc を実行してdifference.mdを更新してください。" >&2
    exit 1
fi

echo "✅ [pre-push] difference.md更新確認OK (${TODAY})" >&2
exit 0
