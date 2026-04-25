#!/usr/bin/env bash
# clasp_rapt_monitor.sh — RAPT期限監視 + ntfy push通知
# cmd_588 Scope B: AC3/AC4
#
# ~/.clasprc.json の expiry_date から最終トークン発行時刻を算出し、
# 6h経過: WARN + ntfy通知
# 7h経過: CRITICAL + ntfy緊急通知(復旧手順含む)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASPRC="$HOME/.clasprc.json"
LOG_PREFIX="[rapt_monitor $(date '+%Y-%m-%d %H:%M:%S UTC')]"

WARN_S=21600   # 6h
CRIT_S=25200   # 7h

# ~/.clasprc.json が存在しない場合はスキップ (clasp未セットアップ環境)
if [[ ! -f "$CLASPRC" ]]; then
    echo "$LOG_PREFIX OK: $CLASPRC not found, skipping"
    exit 0
fi

# expiry_date (epoch ms) 取得
EXPIRY_MS=$(python3 - <<'PY' 2>/dev/null
import json, sys, os
path = os.path.expanduser('~/.clasprc.json')
try:
    d = json.load(open(path))
    val = d.get('tokens', {}).get('default', {}).get('expiry_date')
    if val is None:
        sys.exit(1)
    print(int(val))
except Exception:
    sys.exit(1)
PY
) || {
    echo "$LOG_PREFIX OK: expiry_date not available in $CLASPRC, skipping"
    exit 0
}

NOW_S=$(date +%s)
EXPIRY_S=$(( EXPIRY_MS / 1000 ))
# access_token は発行から1h有効なので、発行時刻 = expiry - 3600
TOKEN_ISSUE_S=$(( EXPIRY_S - 3600 ))
ELAPSED_S=$(( NOW_S - TOKEN_ISSUE_S ))

# elapsed が負 (トークンがまだ有効期限前) は正常扱い
if (( ELAPSED_S < 0 )); then
    echo "$LOG_PREFIX OK: token freshly issued (expiry in $((EXPIRY_S - NOW_S))s)"
    exit 0
fi

ELAPSED_H=$(( ELAPSED_S / 3600 ))
ELAPSED_M=$(( (ELAPSED_S % 3600) / 60 ))

if (( ELAPSED_S < WARN_S )); then
    echo "$LOG_PREFIX OK: RAPT elapsed=${ELAPSED_H}h${ELAPSED_M}m (< 6h)"

elif (( ELAPSED_S < CRIT_S )); then
    REMAINING_H=$(( 8 - ELAPSED_H ))
    echo "$LOG_PREFIX WARN: RAPT elapsed=${ELAPSED_H}h${ELAPSED_M}m — 残り約${REMAINING_H}h で RAPT 期限切れ"
    bash "$SCRIPT_DIR/ntfy.sh" \
        "⚠️ clasp RAPT WARN: 認証から ${ELAPSED_H}h${ELAPSED_M}m 経過。残り約 ${REMAINING_H}h で期限切れ。早めに clasp run を実行して更新してください。" \
        "clasp RAPT 期限警告" \
        "warning" || true

else
    echo "$LOG_PREFIX CRITICAL: RAPT elapsed=${ELAPSED_H}h${ELAPSED_M}m — RAPT 期限切れ間近／切れの可能性"
    RECOVERY="【復旧手順】案B(最短): https://script.google.com で GAS Editor を開き直接実行 / 案A: ローカルで clasp login → scp ~/.clasprc.json ubuntu@VPS:/home/ubuntu/.clasprc.json → 家老 inbox へ通知"
    bash "$SCRIPT_DIR/ntfy.sh" \
        "🚨 clasp RAPT CRITICAL: 認証から ${ELAPSED_H}h${ELAPSED_M}m 経過。RAPT 期限切れの可能性。clasp run が 403 になります。${RECOVERY}" \
        "clasp RAPT 緊急: 期限切れ間近" \
        "warning,sos" || true
fi
