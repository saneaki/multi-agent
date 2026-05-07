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
# Test override (cmd_659 Scope E): redirect targets without modifying real dashboard
DASHBOARD="${DASHBOARD_ROTATE_MD:-$SCRIPT_DIR/dashboard.md}"
DASHBOARD_YAML="${DASHBOARD_ROTATE_YAML:-$SCRIPT_DIR/dashboard.yaml}"
STREAKS="${DASHBOARD_ROTATE_STREAKS:-$SCRIPT_DIR/saytask/streaks.yaml}"
LOG_PREFIX="[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')]"
DRY_RUN=false

# cmd_659 Scope C-5: flock /var/lock/shogun_dashboard.lock (R6)
# 同 lock を action_required_sync.sh と共有 → race condition ゼロ
LOCK_FILE="${DASHBOARD_ROTATE_LOCK:-/var/lock/shogun_dashboard.lock}"

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

# C-5: acquire flock first (test 環境用に project-local fallback)
if ! ( : > "$LOCK_FILE" ) 2>/dev/null; then
    LOCK_FILE="$SCRIPT_DIR/.shogun_dashboard.lock"
    : > "$LOCK_FILE" 2>/dev/null || die "cannot create lock file: $LOCK_FILE"
fi

exec {LOCK_FD}>"$LOCK_FILE"
trap 'exec {LOCK_FD}>&- 2>/dev/null || true' EXIT

if ! flock --timeout 30 "$LOCK_FD"; then
    die "flock timeout (30s): $LOCK_FILE — another sync/rotate process holding the lock"
fi

log "Lock acquired: $LOCK_FILE"

# === Skill Entry FIFO Trim ===
trim_skill_entries() {
    local SKILL_HISTORY="$SCRIPT_DIR/memory/skill_history.md"
    local MAX_ENTRIES=5

    # Count skill entries in 🛠️ section only (match both header variants)
    local SKILL_LINES
    SKILL_LINES=$(sed -n '/^## 🛠️/,/^## /p' "$DASHBOARD" | grep -c '^| \*\*' 2>/dev/null; true)
    SKILL_LINES=$(printf '%s' "$SKILL_LINES" | head -1 | tr -cd '0-9')
    SKILL_LINES=${SKILL_LINES:-0}

    if [[ "$SKILL_LINES" -le "$MAX_ENTRIES" ]]; then
        log "スキル欄: ${SKILL_LINES}件 (上限${MAX_ENTRIES}件以内) — トリム不要"
        return 0
    fi

    local EXCESS=$(( SKILL_LINES - MAX_ENTRIES ))
    log "スキル欄: ${SKILL_LINES}件 (超過${EXCESS}件) — トリム開始"

    # Ensure skill_history.md exists
    if [[ ! -f "$SKILL_HISTORY" ]]; then
        mkdir -p "$(dirname "$SKILL_HISTORY")"
        cat > "$SKILL_HISTORY" <<'HEREDOC'
# スキル履歴アーカイブ

dashboard.md 🛠️スキル欄から溢れた全エントリ。最新順（上が新しい）。

## アーカイブ済みエントリ

| スキル名 | 出典 |
|----------|------|
HEREDOC
    fi

    # Get the line range of the skill section in dashboard
    local SECTION_START SECTION_END
    SECTION_START=$(grep -n '^## 🛠️' "$DASHBOARD" | head -1 | cut -d: -f1)
    SECTION_END=$(awk -v start="$SECTION_START" 'NR>start && /^## /{print NR; exit}' "$DASHBOARD")
    if [[ -z "$SECTION_END" ]]; then
        SECTION_END=$(wc -l < "$DASHBOARD")
    fi

    # Get oldest entries (last $EXCESS skill lines in the section)
    local OLDEST_ENTRIES
    OLDEST_ENTRIES=$(sed -n "${SECTION_START},${SECTION_END}p" "$DASHBOARD" \
        | grep '^| \*\*' | tail -n "$EXCESS")

    # Add to archive (after the table header row) — idempotent: skip already-archived entries
    local ARCHIVE_TMP
    ARCHIVE_TMP=$(mktemp "${SKILL_HISTORY}.tmp.XXXXXX")

    # Filter out entries already present in skill_history.md
    local NEW_ENTRIES=""
    while IFS= read -r entry_line; do
        local skill_name
        skill_name=$(echo "$entry_line" | grep -o '^\| \*\*[^*]*\*\*' | sed 's/^| \*\*//;s/\*\*//')
        if [[ -n "$skill_name" ]] && grep -qF "**${skill_name}**" "$SKILL_HISTORY" 2>/dev/null; then
            log "スキル重複スキップ: $skill_name (既にアーカイブ済み)"
        else
            NEW_ENTRIES="${NEW_ENTRIES}${entry_line}"$'\n'
        fi
    done <<< "$OLDEST_ENTRIES"

    if [[ -z "${NEW_ENTRIES// }" ]]; then
        log "新規アーカイブ対象なし (全件重複) — skill_history.md 書込みスキップ"
        mv "$ARCHIVE_TMP" /dev/null 2>/dev/null || true
        rm -f "$ARCHIVE_TMP"
    else
        local HEADER_DONE=false
        while IFS= read -r line; do
            echo "$line" >> "$ARCHIVE_TMP"
            if ! $HEADER_DONE && [[ "$line" =~ ^\|----------|------\| ]]; then
                HEADER_DONE=true
                printf '%s' "$NEW_ENTRIES" >> "$ARCHIVE_TMP"
            fi
        done < "$SKILL_HISTORY"
        mv "$ARCHIVE_TMP" "$SKILL_HISTORY"
    fi

    # Remove oldest entries from dashboard.md (bottom up within skill section)
    for i in $(seq 1 "$EXCESS"); do
        local LAST_LINE
        LAST_LINE=$(sed -n "${SECTION_START},${SECTION_END}p" "$DASHBOARD" \
            | grep -n '^| \*\*' | tail -1 | cut -d: -f1)
        if [[ -n "$LAST_LINE" ]]; then
            local ABS_LINE=$((SECTION_START + LAST_LINE - 1))
            sed -i "${ABS_LINE}d" "$DASHBOARD"
            # Recalculate section end after deletion
            SECTION_END=$((SECTION_END - 1))
        fi
    done

    # Update the "他N件" reference count
    local CURRENT_ARCHIVE_COUNT
    CURRENT_ARCHIVE_COUNT=$(grep -c '^| \*\*' "$SKILL_HISTORY" || echo "0")
    local EXTRA_SKILLS=17  # ~/.claude/skills/ 参照分
    local TOTAL_ARCHIVE=$((CURRENT_ARCHIVE_COUNT + EXTRA_SKILLS))
    sed -i "s/他[0-9]*件 → /他${TOTAL_ARCHIVE}件 → /" "$DASHBOARD"

    log "スキル欄トリム完了: ${EXCESS}件をアーカイブに移動 (残${MAX_ENTRIES}件)"
}

# Validate dashboard exists
[[ -f "$DASHBOARD" ]] || die "dashboard.md not found: $DASHBOARD"

# Get current JST date
TODAY_JST=$(TZ='Asia/Tokyo' date +"%Y-%m-%d")
TODAY_MD=$(TZ='Asia/Tokyo' date +"%-m/%-d")

# Extract current date from dashboard.yaml metadata.last_updated
CURRENT_MD=$(python3 -c "
import yaml, re, sys
try:
    d = yaml.safe_load(open('$DASHBOARD_YAML'))
    lu = (d.get('metadata') or {}).get('last_updated', '')
    m = re.match(r'(\d{4})-(\d{2})-(\d{2})', lu)
    print(f'{int(m.group(2))}/{int(m.group(3))}') if m else sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null || echo "")

if [[ -z "$CURRENT_MD" ]]; then
    die "dashboard.yaml の metadata.last_updated から日付を取得できなかった"
fi

log "Current dashboard date: $CURRENT_MD, Today JST: $TODAY_MD"

# Idempotency check
if [[ "$TODAY_MD" == "$CURRENT_MD" ]]; then
    log "日付一致 — ローテーション不要"
    trim_skill_entries
    exit 0
fi

log "日付不一致を検出: $CURRENT_MD → $TODAY_MD ローテーション開始"

if $DRY_RUN; then
    log "[DRY-RUN] dashboard.yaml achievements をローテーション予定:"
    log "  today → yesterday（${CURRENT_MD} JST）"
    log "  yesterday → day_before"
    log "  today ← 空リスト（${TODAY_MD} JST）"
    log "  frog/completed_today → リセット"
    exit 0
fi

# dashboard.yaml achievements rotation + dashboard.md 再生成
python3 - "$DASHBOARD_YAML" "$TODAY_JST" "$CURRENT_MD" "$STREAKS" <<'PYEOF'
import yaml, sys, subprocess, os
from pathlib import Path

dashboard_yaml, today_jst, current_md, streaks_path = sys.argv[1:5]

with open(dashboard_yaml) as f:
    d = yaml.safe_load(f) or {}

ach = d.get('achievements', {})

# Count today's completed items
today_items = ach.get('today', [])
if isinstance(today_items, list):
    items_list = today_items
else:
    items_list = today_items.get('items', []) if isinstance(today_items, dict) else []
completed_count = len(items_list)

# Read streak info
streak_info = ''
if os.path.exists(streaks_path):
    try:
        st = yaml.safe_load(open(streaks_path)) or {}
        current_streak = (st.get('streak') or {}).get('current', 0)
        if current_streak:
            streak_info = f' 🔥ストリーク{current_streak}日目'
    except Exception:
        pass

yesterday_header = f'{current_md} JST — {completed_count}cmd完了{streak_info}'

# Rotate: day_before ← yesterday, yesterday ← today, today ← []
ach['day_before'] = ach.get('yesterday', {'header': '', 'items': []})
ach['yesterday'] = {'header': yesterday_header, 'items': items_list}
ach['today'] = []

# Reset frog
frog = d.get('frog', {})
frog['today'] = None
frog['status'] = '🐸 未撃破'
frog['completed_today'] = 0
d['frog'] = frog
d['achievements'] = ach

with open(dashboard_yaml, 'w') as f:
    yaml.dump(d, f, allow_unicode=True, default_flow_style=False)

# Regenerate dashboard.md (cmd_659 Scope C: auto-mode → partial when markers exist)
import os as _os
renderer = _os.environ.get('DASHBOARD_ROTATE_RENDERER',
                            str(Path(__file__).resolve().parent / 'scripts' / 'generate_dashboard_md.py'))
# Heuristic fallback: __file__ is "<stdin>" when run via heredoc, so try repo path
if not _os.path.exists(renderer):
    renderer = _os.environ.get('DASHBOARD_ROTATE_RENDERER',
                                _os.path.join(_os.path.dirname(_os.path.abspath(dashboard_yaml)),
                                              'scripts', 'generate_dashboard_md.py'))
dashboard_md_path = _os.environ.get('DASHBOARD_ROTATE_MD',
                                     str(Path(dashboard_yaml).parent / 'dashboard.md'))
# fallback: derive from yaml path if env unset
if not _os.path.exists(renderer):
    # try the upstream repo location
    candidate = '/home/ubuntu/shogun/scripts/generate_dashboard_md.py'
    if _os.path.exists(candidate):
        renderer = candidate
subprocess.run(
    ['python3', renderer, '--input', dashboard_yaml, '--output', dashboard_md_path],
    check=True,
)
print(f'achievements rotated: {current_md} → {today_jst} ({completed_count}件)')
PYEOF

# Update streaks.yaml if it exists
if [[ -f "$STREAKS" ]]; then
    sed -i "s/last_date:.*/last_date: \"$TODAY_JST\"/" "$STREAKS"
    sed -i "s/^\(  *\)frog:.*/\1frog: \"\"/" "$STREAKS"
    sed -i "s/^\(  *\)completed:.*/\1completed: 0/" "$STREAKS"
    log "streaks.yaml更新: last_date=$TODAY_JST, frog='', completed=0"
fi

log "ローテーション完了: $CURRENT_MD → $TODAY_MD"

trim_skill_entries
