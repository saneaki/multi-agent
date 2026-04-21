#!/usr/bin/env bash
# statusline_with_counter.sh — statusLine hook: context表示 + counter_file更新
#
# 役割:
#   - stdin: Claude Code statusLine hook JSON
#   - stdout: ステータスバー表示文字列 (既存 statusline.sh 互換)
#   - counter_file: ~/.claude/tool_call_counter/<agent_id>.json
#     context_pct / total_input_tokens / context_window_size を atomic write
#     count / alpha 等の既存フィールドは保持 (counter_increment.sh が管理)
#   - Graceful degradation: いかなる失敗でも exit 0

# --- stdin 読み取り ---
INPUT="$(cat)"

# --- AGENT_ID 決定 ---
AGENT_ID="${AGENT_ID:-}"
if [ -z "$AGENT_ID" ] && [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID="$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)"
fi
AGENT_ID="${AGENT_ID:-unknown}"

# --- counter_file atomic write (Python3 via env var) ---
STATUSLINE_INPUT="$INPUT" \
COUNTER_DIR="${HOME}/.claude/tool_call_counter" \
python3 - "$AGENT_ID" <<'PYEOF' 2>/dev/null || true
import json, os, sys, tempfile
from datetime import datetime, timezone, timedelta

agent_id    = sys.argv[1]
counter_dir = os.environ["COUNTER_DIR"]
raw         = os.environ.get("STATUSLINE_INPUT", "")

try:
    data = json.loads(raw)
except Exception:
    data = {}

ctx      = data.get("context_window") or {}
used_pct = ctx.get("used_percentage", 0)
total_in = ctx.get("total_input_tokens", 0)
ctx_size = ctx.get("context_window_size", 0)

if not agent_id or agent_id == "unknown":
    sys.exit(0)

os.makedirs(counter_dir, exist_ok=True)
counter_file = os.path.join(counter_dir, f"{agent_id}.json")

# 既存フィールド読み取り (count / alpha 等を保持)
try:
    with open(counter_file) as f:
        existing = json.load(f)
    if not isinstance(existing, dict):
        existing = {}
except Exception:
    existing = {}

jst = timezone(timedelta(hours=9))
now = datetime.now(jst).strftime("%Y-%m-%dT%H:%M:%S+09:00")

existing.update({
    "context_pct":         round(float(used_pct), 2),
    "total_input_tokens":  int(total_in),
    "context_window_size": int(ctx_size),
    "source":              "statusLine",
    "last_updated":        now,
})

# Atomic write
tmp_fd, tmp_path = tempfile.mkstemp(
    dir=os.path.dirname(counter_file) or ".", suffix=".tmp"
)
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(existing, f, ensure_ascii=False)
    os.replace(tmp_path, counter_file)
except Exception:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
PYEOF

# --- ステータスバー表示 (既存 statusline.sh 互換) ---
MODEL=$(echo "$INPUT"  | jq -r '.model.display_name // "?"'             2>/dev/null || echo "?")
USED=$(echo "$INPUT"   | jq -r '.context_window.used_percentage // 0'   2>/dev/null | awk '{print int($1)}')
REMAIN=$(echo "$INPUT" | jq -r '.context_window.remaining_percentage // 0' 2>/dev/null | awk '{print int($1)}')
IN_TOK=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null || echo "0")
OUT_TOK=$(echo "$INPUT" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null || echo "0")
CWD=$(echo "$INPUT"    | jq -r '.workspace.current_dir // "?"'          2>/dev/null || echo "?")
BASENAME="${CWD##*/}"

USED="${USED:-0}"
if [ "$USED" -ge 90 ]; then
    COLOR='\033[1;31m'
elif [ "$USED" -ge 70 ]; then
    COLOR='\033[1;33m'
else
    COLOR='\033[1;32m'
fi
RESET='\033[0m'
DIM='\033[2m'

BAR_WIDTH=10
FILLED=$(( (USED * BAR_WIDTH) / 100 ))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
[ "$FILLED" -lt 0 ]            && FILLED=0
EMPTY=$(( BAR_WIDTH - FILLED ))

BAR=""
for ((i=0; i<FILLED; i++)); do BAR="${BAR}█"; done
for ((i=0; i<EMPTY;  i++)); do BAR="${BAR}░"; done

printf "${DIM}[%s]${RESET} ${COLOR}%s %d%%${RESET} ${DIM}(remain %d%%) | in:%s out:%s | 📁 %s${RESET}" \
    "$MODEL" "$BAR" "$USED" "$REMAIN" "$IN_TOK" "$OUT_TOK" "$BASENAME"

exit 0
