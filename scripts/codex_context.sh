#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# codex_context.sh — Codex pane の context残量(%)を返す
#
# Usage:
#   bash scripts/codex_context.sh <agent_id>
#   bash scripts/codex_context.sh ashigaru5
#
# Output (stdout):
#   "47%"        — Codex pane で active session の場合 (input / window)
#   ""           — Codex 以外 / rollout 未検出 / idle / エラー
#
# Design (cmd_667):
#   1. agent_id から tmux pane を逆引き
#   2. pane の @agent_cli == codex か確認 (それ以外は空文字)
#   3. pane_pid 配下から codex プロセス + 子孫の PID を取得
#   4. /proc/{pid}/fd/ をスキャンして open 中の rollout-*.jsonl を取得
#      (codex が actually 書き込んでいるファイルのみ → 誤判定回避)
#   5. 最後の "type":"token_count" イベントから input_tokens / model_context_window を計算
#
# Note:
#   - tmux pane-border-format の #() に埋め込み、status-interval (15s) で自動更新
#   - 失敗時は静かに空文字を返し、表示を壊さない
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

AGENT_ID="${1:-}"

# 引数なし → 空文字
[[ -z "$AGENT_ID" ]] && exit 0

# tmux 不在チェック (テスト環境)
command -v tmux >/dev/null 2>&1 || exit 0

# tmux pane を agent_id で逆引き
PANE_LINE=$(tmux list-panes -a -F '#{@agent_id} #{@agent_cli} #{pane_pid}' 2>/dev/null \
    | awk -v a="$AGENT_ID" '$1 == a {print; exit}')

[[ -z "$PANE_LINE" ]] && exit 0

CLI=$(echo "$PANE_LINE" | awk '{print $2}')
PANE_PID=$(echo "$PANE_LINE" | awk '{print $3}')

# Codex pane でなければ空文字
[[ "$CLI" != "codex" ]] && exit 0
[[ -z "$PANE_PID" ]] && exit 0

# pane_pid 配下から codex プロセスを探索 (node /codex が直接の子)
CODEX_PID=$(pgrep -P "$PANE_PID" -f 'codex' 2>/dev/null | head -1)
[[ -z "$CODEX_PID" ]] && exit 0

# codex プロセスの子孫を再帰列挙 (rollout file は通常 codex バイナリが開く)
collect_descendants() {
    local pid="$1"
    echo "$pid"
    local children
    children=$(pgrep -P "$pid" 2>/dev/null)
    for c in $children; do
        collect_descendants "$c"
    done
}

# /proc/{pid}/fd/ をスキャンして open rollout を取得
ROLLOUT=""
for pid in $(collect_descendants "$CODEX_PID"); do
    found=$(ls -l "/proc/$pid/fd/" 2>/dev/null \
        | grep -oE '/[^ ]*rollout-[^ ]*\.jsonl' | head -1)
    if [[ -n "$found" ]]; then
        ROLLOUT="$found"
        break
    fi
done

# rollout file 未検出 (idle session) → 空文字
[[ -z "$ROLLOUT" || ! -f "$ROLLOUT" ]] && exit 0

# python3 で最後の token_count イベントを読み取り
PYTHON_BIN="${PROJECT_ROOT:-/home/ubuntu/shogun}/.venv/bin/python3"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

"$PYTHON_BIN" - "$ROLLOUT" <<'PYEOF' 2>/dev/null
import os
import sys
import json

rollout = sys.argv[1]

try:
    file_size = os.path.getsize(rollout)
    chunk = 256 * 1024
    with open(rollout, 'rb') as fh:
        if file_size > chunk:
            fh.seek(file_size - chunk, 0)
            # 部分読みで先頭行が壊れる可能性 → 最初の改行までスキップ
            fh.readline()
        data = fh.read().decode('utf-8', errors='ignore')

    last_event = None
    for line in data.splitlines():
        if '"type":"token_count"' in line:
            last_event = line
    if not last_event:
        sys.exit(0)

    obj = json.loads(last_event)
    info = obj['payload']['info']
    last = info.get('last_token_usage') or info.get('total_token_usage', {})
    used = last.get('input_tokens', 0)
    win = info.get('model_context_window', 0)
    if win <= 0 or used < 0:
        sys.exit(0)
    pct_used = round(used / win * 100)
    if pct_used > 999:
        pct_used = 999
    # tmux pane-border-format での自然な並び (Codex 47%) のため先頭に空白を出す
    print(f" {pct_used}%")
except Exception:
    sys.exit(0)
PYEOF
