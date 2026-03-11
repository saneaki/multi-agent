#!/usr/bin/env bash
# dashboard_rotate.sh — JST日付変更時にダッシュボードの戦果セクションを自動ローテーション
# cron: 0 15 * * * (UTC 15:00 = JST 00:00)
#
# 仕様 (karo.md L549-554準拠):
#   1. 「本日の戦果（M/D JST）」のM/Dと現在JST日付を比較
#   2. 不一致の場合:
#      a. 本日→昨日にリネーム（完了数サマリ付き）
#      b. 既存の昨日を削除（2世代前を消す）
#      c. 新しい空の本日セクションを作成
#      d. Frog/ストリーク: Frog欄を「未設定」にリセット
#      e. 「今日の完了」を0にリセット
#   3. 冪等性: 日付一致時は変更なし

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$SCRIPT_DIR/dashboard.md"
STREAKS="$SCRIPT_DIR/saytask/streaks.yaml"
LOG_PREFIX="[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')]"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

log() {
    echo "$LOG_PREFIX $1"
}

die() {
    log "ERROR: $1" >&2
    exit 1
}

# Validate dashboard exists
[[ -f "$DASHBOARD" ]] || die "dashboard.md not found: $DASHBOARD"

# Get current JST date
TODAY_JST=$(TZ='Asia/Tokyo' date +"%Y-%m-%d")
TODAY_MD=$(TZ='Asia/Tokyo' date +"%-m/%-d")

# Extract current date from 「本日の戦果（M/D JST）」
CURRENT_MD=$(grep -oP '## ✅ 本日の戦果（\K[0-9]+/[0-9]+' "$DASHBOARD" || echo "")

if [[ -z "$CURRENT_MD" ]]; then
    die "「本日の戦果」セクションが見つからない"
fi

log "Current dashboard date: $CURRENT_MD, Today JST: $TODAY_MD"

# Idempotency check
if [[ "$TODAY_MD" == "$CURRENT_MD" ]]; then
    log "日付一致 — ローテーション不要"
    exit 0
fi

log "日付不一致を検出: $CURRENT_MD → $TODAY_MD ローテーション開始"

# Count completed items in current 「本日の戦果」
# Count rows in the table (lines starting with |, excluding header rows)
COMPLETED_COUNT=0
IN_TODAY=false
while IFS= read -r line; do
    if [[ "$line" =~ ^"## ✅ 本日の戦果" ]]; then
        IN_TODAY=true
        continue
    fi
    if $IN_TODAY && [[ "$line" =~ ^"## " ]]; then
        break
    fi
    if $IN_TODAY && [[ "$line" =~ ^\|[[:space:]][0-9] ]]; then
        COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
    fi
done < "$DASHBOARD"

log "本日の戦果エントリ数: $COMPLETED_COUNT"

if $DRY_RUN; then
    log "[DRY-RUN] 以下の変更を実行予定:"
    log "  1. 「本日の戦果（$CURRENT_MD JST）」→「昨日の戦果（$CURRENT_MD JST）— ${COMPLETED_COUNT}cmd完了」"
    log "  2. 既存「昨日の戦果」セクション削除"
    log "  3. 新規「本日の戦果（$TODAY_MD JST）」セクション作成"
    log "  4. Frog欄 → 未設定、Frog状態 → 🐸 未撃破"
    log "  5. 今日の完了 → 0"
    log "  6. streaks.yaml: today.completed → 0, today.frog → \"\""
    exit 0
fi

# Create temp file for atomic write
TMPFILE=$(mktemp "${DASHBOARD}.tmp.XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT

# Process dashboard.md
# Strategy: read line by line, transform sections
SKIP_YESTERDAY=false
WROTE_NEW_TODAY=false

while IFS= read -r line; do
    # Skip old 「昨日の戦果」 section entirely
    if [[ "$line" =~ ^"## ✅ 昨日の戦果" ]]; then
        SKIP_YESTERDAY=true
        continue
    fi
    if $SKIP_YESTERDAY && [[ "$line" =~ ^"## " ]]; then
        SKIP_YESTERDAY=false
        # Fall through to process this line normally
    elif $SKIP_YESTERDAY; then
        continue
    fi

    # Rename 「本日の戦果」 → 「昨日の戦果」
    if [[ "$line" =~ ^"## ✅ 本日の戦果" ]]; then
        # First write the new empty 「本日の戦果」
        echo "## ✅ 本日の戦果（${TODAY_MD} JST）" >> "$TMPFILE"
        echo "" >> "$TMPFILE"
        echo "| 時刻 | 戦場 | 任務 | 結果 |" >> "$TMPFILE"
        echo "|------|------|------|------|" >> "$TMPFILE"
        echo "| （まだなし） | | | |" >> "$TMPFILE"
        echo "" >> "$TMPFILE"
        WROTE_NEW_TODAY=true

        # Then write renamed section as 「昨日の戦果」
        # Determine streak info for summary
        STREAK_INFO=""
        if [[ -f "$STREAKS" ]]; then
            CURRENT_STREAK=$(grep -A1 'streak:' "$STREAKS" | grep 'current:' | awk '{print $2}' || echo "?")
            STREAK_INFO=" 🔥ストリーク${CURRENT_STREAK}日目"
        fi
        echo "## ✅ 昨日の戦果（${CURRENT_MD} JST）— ${COMPLETED_COUNT}cmd完了${STREAK_INFO}" >> "$TMPFILE"
        continue
    fi

    # Update Frog section
    if [[ "$line" =~ "| 今日のFrog |" ]]; then
        echo "| 今日のFrog | 未設定 |" >> "$TMPFILE"
        continue
    fi
    if [[ "$line" =~ "| Frog状態 |" ]]; then
        echo "| Frog状態 | 🐸 未撃破 |" >> "$TMPFILE"
        continue
    fi
    if [[ "$line" =~ "| 今日の完了 |" ]]; then
        echo "| 今日の完了 | 0 |" >> "$TMPFILE"
        continue
    fi

    echo "$line" >> "$TMPFILE"
done < "$DASHBOARD"

# Atomic replace
mv "$TMPFILE" "$DASHBOARD"
trap - EXIT

# Update streaks.yaml if it exists
if [[ -f "$STREAKS" ]]; then
    # Update last_date and reset today counters
    sed -i "s/last_date:.*/last_date: \"$TODAY_JST\"/" "$STREAKS"
    sed -i "s/^\(  *\)frog:.*/\1frog: \"\"/" "$STREAKS"
    sed -i "s/^\(  *\)completed:.*/\1completed: 0/" "$STREAKS"
    log "streaks.yaml更新: last_date=$TODAY_JST, frog='', completed=0"
fi

# Update dashboard timestamp
sed -i "s/^最終更新:.*/最終更新: $(TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M') JST/" "$DASHBOARD"

log "ローテーション完了: $CURRENT_MD → $TODAY_MD"
