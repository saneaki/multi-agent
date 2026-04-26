#!/usr/bin/env bash
# cmd_kpi_observer.sh — 完遂 cmd の KPI を観測し dashboard 運用指標に書込む (cmd_593 Scope C / AC5)
#
# Usage: bash scripts/cmd_kpi_observer.sh [--dry-run]
# cron:  0 9 * * * bash /home/ubuntu/shogun/scripts/cmd_kpi_observer.sh >> /home/ubuntu/shogun/logs/kpi_observer.log 2>&1
#
# 収集 KPI (今日, JST):
#   1. /pub-us 起動回数      (logs/cmd_squash_pub_hook.log: "claude -p '/pub-us")
#   2. /pub-us 成功 / 失敗 / kill-switch (現状ログに明示パターンなし → 0 default)
#   3. karo auto-compact     (compact_observer.sh karo: AGENT_TODAY)
#   4. gunshi auto-compact   (compact_observer.sh gunshi: AGENT_TODAY)
#   5. safe_window_judge 発動 (logs/safe_window/{karo,gunshi}.log の START 件数合計)
#   6. karo_self_clear_check 発動 (logs/safe_clear/karo.log の START 件数, 報告用; dashboard 列なし)
#
# 出力先:
#   dashboard.md ## 📊 運用指標 セクションに今日の日付行を追記または更新

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="${SCRIPT_DIR}/dashboard.md"
PUB_LOG="${SCRIPT_DIR}/logs/cmd_squash_pub_hook.log"
SAFE_WINDOW_DIR="${SCRIPT_DIR}/logs/safe_window"
SAFE_CLEAR_DIR="${SCRIPT_DIR}/logs/safe_clear"
COMPACT_OBSERVER="${SCRIPT_DIR}/scripts/compact_observer.sh"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
    esac
done

_log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [cmd_kpi_observer] $*"
}

_log "=== START (dry_run=${DRY_RUN}) ==="

TODAY="$(bash "${SCRIPT_DIR}/scripts/jst_now.sh" --date)"

# ── KPI 1: /pub-us 起動回数 (today) ──────────────────────────────────────────
PUB_US_INVOKE=0
if [ -f "$PUB_LOG" ]; then
    PUB_US_INVOKE=$(grep -c "^\[${TODAY}.*claude -p '/pub-us" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
fi
PUB_US_INVOKE=${PUB_US_INVOKE:-0}

# ── KPI 2: /pub-us 成功 / 失敗 / kill-switch (today) ─────────────────────────
# 現状ログに明示パターンが無いため 0 default。将来パターン整備後に拡張する。
PUB_US_SUCCESS=0
PUB_US_FAIL=0
PUB_US_KILL=0
if [ -f "$PUB_LOG" ]; then
    PUB_US_SUCCESS=$(grep -c "^\[${TODAY}.*\(success\|成功\|completed\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
    PUB_US_FAIL=$(grep -c "^\[${TODAY}.*\(failed\|失敗\|error\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
    PUB_US_KILL=$(grep -c "^\[${TODAY}.*\(kill-switch\|kill_switch\)" "$PUB_LOG" 2>/dev/null | tr -d '\n' || true)
fi
PUB_US_SUCCESS=${PUB_US_SUCCESS:-0}
PUB_US_FAIL=${PUB_US_FAIL:-0}
PUB_US_KILL=${PUB_US_KILL:-0}

# ── KPI 3-4: karo / gunshi auto-compact (today) ─────────────────────────────
KARO_COMPACT=0
GUNSHI_COMPACT=0
if [ -x "$COMPACT_OBSERVER" ] || [ -f "$COMPACT_OBSERVER" ]; then
    KARO_OUT=$(bash "$COMPACT_OBSERVER" karo 2>/dev/null | grep -m1 "^ROLE=" || true)
    GUNSHI_OUT=$(bash "$COMPACT_OBSERVER" gunshi 2>/dev/null | grep -m1 "^ROLE=" || true)
    KARO_COMPACT=$(echo "$KARO_OUT" | grep -oE 'AGENT_TODAY=[0-9]+' | cut -d= -f2 | tr -d '\n' || true)
    GUNSHI_COMPACT=$(echo "$GUNSHI_OUT" | grep -oE 'AGENT_TODAY=[0-9]+' | cut -d= -f2 | tr -d '\n' || true)
fi
KARO_COMPACT=${KARO_COMPACT:-0}
GUNSHI_COMPACT=${GUNSHI_COMPACT:-0}

# ── KPI 5: safe_window_judge 発動回数 (today, karo+gunshi) ──────────────────
SAFE_WINDOW_COUNT=0
for log in "${SAFE_WINDOW_DIR}/karo.log" "${SAFE_WINDOW_DIR}/gunshi.log"; do
    [ -f "$log" ] || continue
    count=$(grep -c "^\[${TODAY}.*=== START" "$log" 2>/dev/null | tr -d '\n' || true)
    SAFE_WINDOW_COUNT=$((SAFE_WINDOW_COUNT + ${count:-0}))
done

# ── KPI 6: karo_self_clear_check 発動回数 (today, 報告用) ───────────────────
SELF_CLEAR_COUNT=0
if [ -f "${SAFE_CLEAR_DIR}/karo.log" ]; then
    SELF_CLEAR_COUNT=$(grep -c "^\[${TODAY}.*safe_clear_check START" "${SAFE_CLEAR_DIR}/karo.log" 2>/dev/null | tr -d '\n' || true)
fi
SELF_CLEAR_COUNT=${SELF_CLEAR_COUNT:-0}

_log "KPI: pub_us_invoke=${PUB_US_INVOKE} success=${PUB_US_SUCCESS} fail=${PUB_US_FAIL} kill=${PUB_US_KILL}"
_log "KPI: karo_compact=${KARO_COMPACT} gunshi_compact=${GUNSHI_COMPACT} safe_window=${SAFE_WINDOW_COUNT} self_clear=${SELF_CLEAR_COUNT}"

# ── dashboard 行を生成 ──────────────────────────────────────────────────────
NEW_ROW="| ${TODAY} | ${PUB_US_INVOKE} | ${PUB_US_SUCCESS} | ${PUB_US_FAIL} | ${PUB_US_KILL} | ${KARO_COMPACT} | ${GUNSHI_COMPACT} | ${SAFE_WINDOW_COUNT} |"

if [ "$DRY_RUN" -eq 1 ]; then
    _log "DRY RUN — would append/update row:"
    echo "$NEW_ROW"
    _log "=== END (dry_run) ==="
    exit 0
fi

# ── dashboard.md に append または update ────────────────────────────────────
if [ ! -f "$DASHBOARD" ]; then
    _log "ERROR: dashboard not found at $DASHBOARD"
    exit 1
fi

# 既存の今日の行があれば置換、なければ運用指標セクションに append
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

python3 - "$DASHBOARD" "$TODAY" "$NEW_ROW" "$TMP_FILE" <<'PY'
import sys, re, pathlib

dashboard, today, new_row, out_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = pathlib.Path(dashboard).read_text(encoding="utf-8")
lines = text.splitlines(keepends=False)

in_section = False
table_end_idx = None
target_idx = None
section_header_re = re.compile(r"^##\s")

for i, line in enumerate(lines):
    if line.startswith("## 📊 運用指標"):
        in_section = True
        continue
    if in_section and section_header_re.match(line):
        # 次のセクションに到達 → table_end は直前の non-empty 行
        break
    if in_section:
        if line.startswith(f"| {today} "):
            target_idx = i
        if line.startswith("| ") and not line.startswith("|--"):
            table_end_idx = i

if target_idx is not None:
    lines[target_idx] = new_row
elif table_end_idx is not None:
    lines.insert(table_end_idx + 1, new_row)
else:
    sys.stderr.write("ERROR: 📊 運用指標 section / table not found\n")
    sys.exit(2)

pathlib.Path(out_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

mv "$TMP_FILE" "$DASHBOARD"
trap - EXIT

_log "dashboard updated with row: $NEW_ROW"
_log "=== END ==="
