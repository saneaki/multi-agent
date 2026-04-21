#!/usr/bin/env bash
# counter_increment.sh — PostToolUse hook: tool実行毎に count を++する
#
# 仕様:
#   - stdin: Claude Code PostToolUse JSON (透過して stdout に出力)
#   - stdout: stdin をそのまま pass-through (hook 透過原則)
#   - stderr: [counter] agent=X count=N
#   - counter_file: ~/.claude/tool_call_counter/<agent_id>.json
#     { "count": N, "context_pct": X.X, "last_updated": "ISO8601", ... }
#   - context_pct フィールドは statusLine hook (Scope1) が上書きするため、
#     PostToolUse hook は count のみを++し、context_pct 等の既存フィールドは保持する
#   - Graceful degradation: いかなる失敗でも tool 実行を阻害しない (exit 0)
#
# AGENT_ID 取得順序:
#   1. 環境変数 AGENT_ID (明示指定)
#   2. $TMUX_PANE → tmux display-message @agent_id
#   3. fallback "unknown"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="${SCRIPT_DIR}/.venv/bin/python3"
[ -x "$PY" ] || PY="python3"

COUNTER_DIR="${HOME}/.claude/tool_call_counter"

# --- stdin 透過: 読み取りつつ stdout に流し、後段処理用にも保持 ---
STDIN_BUF="$(cat)"
printf '%s' "$STDIN_BUF"

# --- AGENT_ID 決定 ---
AGENT_ID="${AGENT_ID:-}"
if [ -z "$AGENT_ID" ] && [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID="$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)"
fi
AGENT_ID="${AGENT_ID:-unknown}"

# unknown は記録しない (VSCode 等の非tmux環境)
if [ "$AGENT_ID" = "unknown" ]; then
    exit 0
fi

mkdir -p "$COUNTER_DIR" 2>/dev/null || exit 0
COUNTER_FILE="${COUNTER_DIR}/${AGENT_ID}.json"
LOCKFILE="${COUNTER_FILE}.lock"

# --- flock で排他制御しつつ count++ のみ実施 ---
(
    if command -v flock >/dev/null 2>&1; then
        flock -w 2 9 || exit 0
    fi

    "$PY" - "$COUNTER_FILE" "$AGENT_ID" <<'PYEOF'
import json, os, sys, tempfile
from datetime import datetime, timezone, timedelta

counter_file, agent_id = sys.argv[1], sys.argv[2]

# 既存 JSON 読み取り (context_pct 等全フィールドを保持)
try:
    with open(counter_file) as f:
        d = json.load(f)
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}

count = int(d.get("count", 0)) + 1
d["count"] = count

# JST ISO8601 (+09:00)
jst = timezone(timedelta(hours=9))
d["last_updated"] = datetime.now(jst).strftime("%Y-%m-%dT%H:%M:%S+09:00")

# context_pct フィールドは既存値のまま保持 (statusLine hook が更新)

# Atomic write (tmpfile + rename)
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(counter_file), suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(d, f, ensure_ascii=False)
    os.replace(tmp_path, counter_file)
except Exception:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    sys.exit(0)

sys.stderr.write(f"[counter] agent={agent_id} count={count}\n")
PYEOF
) 9>"$LOCKFILE"

exit 0
