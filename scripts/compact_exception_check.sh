#!/usr/bin/env bash
# compact_exception_check.sh — /compact 例外運用ガード (cmd_531 Phase 4)
#
# Usage: bash scripts/compact_exception_check.sh <agent_id> <context_pct>
#
# 発動許可条件(全 AND):
#   cond_1: shogun_to_karo.yaml に status=in_progress + context_policy=preserve_across_stages
#           な cmd が1件以上
#   cond_2: current context_pct > 80
#   cond_3: /clear 実施不能 (cond_1=TRUE なら TRUE とする — preserve 要件で文脈喪失不可)
#
# 全 PASS → exit 0 + 使用推奨メッセージ + snapshot 強制書込 + ログ append
# NG      → exit 1 + reason + "/clear 可能性を検討せよ" 助言
#
# 本スクリプト "単体" では /compact は発動しない。呼出元(agent)が本スクリプトで
# exit 0 を確認してから /compact を実施する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$SCRIPT_DIR/.venv/bin/python3"
SHOGUN_TO_KARO="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/compact_exceptions.log"

AGENT_ID="${1:-}"
CONTEXT_PCT="${2:-}"

_usage() {
    echo "Usage: bash scripts/compact_exception_check.sh <agent_id> <context_pct>" >&2
    echo "  agent_id:    shogun | karo | gunshi | ashigaru{N}" >&2
    echo "  context_pct: 0-100 (整数)" >&2
}

if [ -z "$AGENT_ID" ] || [ -z "$CONTEXT_PCT" ]; then
    _usage
    exit 1
fi

if ! echo "$CONTEXT_PCT" | grep -qE '^[0-9]+$'; then
    echo "[compact_exception_check] ERROR: context_pct must be integer (got: ${CONTEXT_PCT})" >&2
    exit 1
fi

_log_stderr() {
    echo "[compact_exception_check] $*" >&2
}

# ── cond_1: preserve_across_stages な in_progress cmd 抽出 (531d regex 流用) ──
PRESERVE_CMD_ID=""
if [ -f "$SHOGUN_TO_KARO" ]; then
    PRESERVE_CMD_ID=$("$PYTHON" <<PYEOF 2>/dev/null || echo ""
import re
with open("$SHOGUN_TO_KARO") as f:
    content = f.read()
blocks = re.split(r'(?m)^(?=- (?:cmd_id|id): cmd_\d+)', content)
for block in blocks:
    m = re.match(r'- (?:cmd_id|id): (cmd_\d+)', block)
    if not m:
        continue
    status_m = re.search(r'(?m)^  status:\s*["\']?([A-Za-z_]+)["\']?', block)
    if not status_m or status_m.group(1) != 'in_progress':
        continue
    policy_m = re.search(r'(?m)^  context_policy:\s*["\']?([A-Za-z_]+)["\']?', block)
    if policy_m and policy_m.group(1) == 'preserve_across_stages':
        print(m.group(1))
        break
PYEOF
)
fi
PRESERVE_CMD_ID="${PRESERVE_CMD_ID//[$'\n\r']/}"

if [ -z "$PRESERVE_CMD_ID" ]; then
    _log_stderr "NG cond_1: 進行中 cmd に context_policy=preserve_across_stages なし"
    _log_stderr "→ /clear 可能性を検討せよ (preserve 要件なき cmd なら /clear で安全にリセット可)"
    exit 1
fi
_log_stderr "OK  cond_1: preserve_across_stages cmd=${PRESERVE_CMD_ID}"

# ── cond_2: context_pct > 80 ──
if [ "$CONTEXT_PCT" -le 80 ] 2>/dev/null; then
    _log_stderr "NG cond_2: context_pct=${CONTEXT_PCT} <= 80 (閾値未満)"
    _log_stderr "→ /compact は不要。/clear 可能性を検討せよ"
    exit 1
fi
_log_stderr "OK  cond_2: context_pct=${CONTEXT_PCT} > 80"

# ── cond_3: /clear 実施不能 (cond_1=TRUE → TRUE) ──
_log_stderr "OK  cond_3: /clear 実施不能 (preserve_across_stages cmd=${PRESERVE_CMD_ID} 進行中)"

# ── 全 PASS: snapshot 強制書込 + ログ append ──
TS=$(bash "$SCRIPT_DIR/scripts/jst_now.sh" --yaml 2>/dev/null || date -Iseconds)

_log_stderr "ALL PASS — /compact 例外発動許可"
_log_stderr "事前 snapshot を強制書込中..."
bash "$SCRIPT_DIR/scripts/context_snapshot.sh" write "$AGENT_ID" \
    "/compact exception entry (cmd=${PRESERVE_CMD_ID}, ctx=${CONTEXT_PCT}%)" \
    "pre_compact_snapshot" \
    "compact_exception_allowed_at=${TS}" \
    "context_policy=preserve_across_stages" >&2 || \
    _log_stderr "WARN: snapshot write failed (続行)"

mkdir -p "$LOG_DIR"
REASON="context_pct>${CONTEXT_PCT}%_preserve_cmd=${PRESERVE_CMD_ID}"
echo "${TS}|${AGENT_ID}|${PRESERVE_CMD_ID}|${CONTEXT_PCT}|${REASON}" >> "$LOG_FILE"
_log_stderr "ログ記録: ${LOG_FILE}"

# stdout: 呼出元が捕捉できる構造化行
cat <<EOF
compact_exception=approved
agent_id=${AGENT_ID}
cmd_id=${PRESERVE_CMD_ID}
context_pct=${CONTEXT_PCT}
timestamp=${TS}
EOF
exit 0
