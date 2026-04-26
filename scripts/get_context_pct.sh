#!/usr/bin/env bash
# get_context_pct.sh - Print current context percentage as integer (0-100).
# Usage: bash scripts/get_context_pct.sh [agent_id]

set -euo pipefail

AGENT_ID="${1:-karo}"

case "$AGENT_ID" in
  karo|gunshi|shogun|ashigaru1|ashigaru2|ashigaru3|ashigaru4|ashigaru5|ashigaru6|ashigaru7) ;;
  *)
    echo "unsupported agent_id: $AGENT_ID" >&2
    exit 2
    ;;
esac

COUNTER_FILE="${HOME}/.claude/tool_call_counter/${AGENT_ID}.json"
if [ ! -f "$COUNTER_FILE" ]; then
  echo "counter file not found: $COUNTER_FILE" >&2
  exit 1
fi

PYTHON="python3"
if [ -x "/home/ubuntu/shogun/.venv/bin/python3" ]; then
  PYTHON="/home/ubuntu/shogun/.venv/bin/python3"
fi

PCT="$($PYTHON - "$COUNTER_FILE" <<'PYEOF'
import json
import sys

fpath = sys.argv[1]
try:
    with open(fpath, encoding="utf-8") as f:
        data = json.load(f)
    raw = data.get("context_pct")
    if raw is None:
        raw = data.get("usage_pct")
    if raw is None:
        raw = data.get("percent")
    if raw is None:
        raise ValueError("missing context pct fields")
    pct = int(float(raw))
    if pct < 0:
        pct = 0
    if pct > 100:
        pct = 100
    print(pct)
except Exception as e:
    print(f"parse error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)"

if ! echo "$PCT" | grep -qE '^[0-9]+$'; then
  echo "invalid pct: $PCT" >&2
  exit 1
fi

echo "$PCT"
