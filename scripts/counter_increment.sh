#!/usr/bin/env bash
# counter_increment.sh — PostToolUse hook: tool実行毎に count を++し context_pct を算出
#
# 仕様:
#   - stdin: Claude Code PostToolUse JSON (透過して stdout に出力)
#   - stdout: stdin をそのまま pass-through (hook 透過原則)
#   - stderr: [counter] count=N context_pct=X%
#   - counter_file: ~/.claude/tool_call_counter/<agent_id>.json
#     { "count": N, "context_pct": X.X, "last_updated": "ISO8601" }
#   - alpha: config/counter_coefficients.yaml から読取、未存在/未指定は 0.5
#   - context_pct = min(100, count * alpha)
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
COEFF_FILE="${SCRIPT_DIR}/config/counter_coefficients.yaml"

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

# --- flock で排他制御しつつ count++ / context_pct 更新 ---
(
    if command -v flock >/dev/null 2>&1; then
        flock -w 2 9 || exit 0
    fi

    "$PY" - "$COUNTER_FILE" "$COEFF_FILE" "$AGENT_ID" <<'PYEOF'
import json, os, sys, tempfile
from datetime import datetime, timezone, timedelta

counter_file, coeff_file, agent_id = sys.argv[1], sys.argv[2], sys.argv[3]

# 既存 count 読み取り
count = 0
try:
    with open(counter_file) as f:
        d = json.load(f)
    count = int(d.get("count", 0))
except Exception:
    count = 0
count += 1

# alpha 決定 (nested: agents.<id>.alpha / flat: <id>: val / default 0.5)
alpha = 0.5
try:
    import yaml
    with open(coeff_file) as f:
        cfg = yaml.safe_load(f) or {}
    if isinstance(cfg, dict):
        agents = cfg.get("agents")
        if isinstance(agents, dict) and agent_id in agents:
            entry = agents[agent_id]
            if isinstance(entry, dict) and "alpha" in entry:
                alpha = float(entry["alpha"])
            elif isinstance(entry, (int, float)):
                alpha = float(entry)
        elif agent_id in cfg and isinstance(cfg[agent_id], (int, float)):
            alpha = float(cfg[agent_id])
        elif "default" in cfg and isinstance(cfg["default"], (int, float)):
            alpha = float(cfg["default"])
except FileNotFoundError:
    pass
except Exception:
    pass

context_pct = round(min(100.0, count * alpha), 1)

# JST ISO8601 (+09:00)
jst = timezone(timedelta(hours=9))
now_iso = datetime.now(jst).strftime("%Y-%m-%dT%H:%M:%S+09:00")

out = {"count": count, "context_pct": context_pct, "last_updated": now_iso, "alpha": alpha}

# Atomic write (tmpfile + rename)
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(counter_file), suffix=".tmp")
try:
    with os.fdopen(tmp_fd, "w") as f:
        json.dump(out, f, ensure_ascii=False)
    os.replace(tmp_path, counter_file)
except Exception:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    sys.exit(0)

sys.stderr.write(f"[counter] agent={agent_id} count={count} context_pct={context_pct}% alpha={alpha}\n")
PYEOF
) 9>"$LOCKFILE"

exit 0
