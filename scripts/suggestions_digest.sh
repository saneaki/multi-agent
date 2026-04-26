#!/usr/bin/env bash
# suggestions_digest.sh — pending suggestions を家老 inbox + dashboard に通知
# Usage: bash scripts/suggestions_digest.sh [--dry-run]
# cron: 5 9 * * * bash /home/ubuntu/shogun/scripts/suggestions_digest.sh >> /home/ubuntu/shogun/logs/suggestions_digest.log 2>&1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUGGESTIONS_YAML="$SCRIPT_DIR/queue/suggestions.yaml"
DRY_RUN=false

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

NOW="$(bash "$SCRIPT_DIR/scripts/jst_now.sh" 2>/dev/null || date '+%Y-%m-%d %H:%M JST')"
echo "[$NOW] suggestions_digest.sh 開始 (dry_run=$DRY_RUN)"

if [[ ! -f "$SUGGESTIONS_YAML" ]]; then
    echo "[$NOW] ERROR: $SUGGESTIONS_YAML が見当たらぬ" >&2
    exit 1
fi

# PyYAML でステータス別カウント + high pending リスト取得
read -r TOTAL_PENDING HIGH_PENDING MEDIUM_PENDING HIGH_TITLES <<< "$(python3 - "$SUGGESTIONS_YAML" <<'PYEOF'
import sys, yaml

with open(sys.argv[1], encoding="utf-8") as f:
    data = yaml.safe_load(f)

items = data.get("suggestions") or data if isinstance(data, list) else []
if isinstance(data, dict) and "suggestions" in data:
    items = data["suggestions"]

pending = [s for s in items if isinstance(s, dict) and s.get("status") == "pending"]
high = [s for s in pending if s.get("priority") == "high"]
medium = [s for s in pending if s.get("priority") == "medium"]

high_titles = "|".join(
    (s.get("title") or s.get("content", "")[:40].replace("\n", " "))[:40]
    for s in high[:5]
)

print(len(pending), len(high), len(medium), high_titles)
PYEOF
)"

echo "[$NOW] pending=${TOTAL_PENDING} high=${HIGH_PENDING} medium=${MEDIUM_PENDING}"

if [[ "$TOTAL_PENDING" -eq 0 ]]; then
    echo "[$NOW] pending=0。inbox通知不要。終了。"
    exit 0
fi

# pending >= 1 かつ high or medium がある場合のみ inbox 通知
if [[ "$HIGH_PENDING" -gt 0 || "$MEDIUM_PENDING" -gt 0 ]]; then
    MSG="suggestions pending: ${TOTAL_PENDING}件 (high=${HIGH_PENDING}/medium=${MEDIUM_PENDING}) 確認されたし"
    if [[ "$HIGH_PENDING" -gt 0 && -n "$HIGH_TITLES" ]]; then
        # タイトルをパイプ区切りから読みやすい形式へ
        SAMPLE="$(echo "$HIGH_TITLES" | tr '|' '\n' | head -3 | awk '{print "  - "$0}' | tr '\n' ' ')"
        MSG="${MSG} [high例: ${SAMPLE}]"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[$NOW] [DRY-RUN] inbox_write karo: ${MSG}"
    else
        bash "$SCRIPT_DIR/scripts/inbox_write.sh" karo "$MSG" digest suggestions_digest
        echo "[$NOW] karo inbox へ通知完了。"
    fi
else
    echo "[$NOW] pending=${TOTAL_PENDING}件だが high/medium なし。low のみゆえ通知なし。"
fi

echo "[$NOW] suggestions_digest.sh 完了。"
