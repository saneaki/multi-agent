#!/bin/bash
# Gmail Trigger自動監視・自動復旧スクリプト
# cmd_329 / subtask_329b (bugs fixed)
#
# Gmail自動化WF v5.2 (19oFs9lh8Vri10kA) のTrigger Stuckを検知し自動復旧する。
# cron登録: */30 * * * *

set -euo pipefail

# ============================================================
# 設定
# ============================================================
WF_ID="19oFs9lh8Vri10kA"
N8N_URL="http://localhost:5678"
N8N_ENV="/home/ubuntu/.n8n-mcp/n8n/.env"
SHOGUN_DIR="/home/ubuntu/shogun"
LOG_FILE="${SHOGUN_DIR}/logs/watch_gmail_trigger.log"

# 閾値（分）
THRESHOLD_WEEKDAY_DAYTIME=30   # 平日 09:00-19:00 JST
THRESHOLD_OTHER=150             # 夜間・休日

# ============================================================
# 初期化
# ============================================================
mkdir -p "$(dirname "$LOG_FILE")"

# Bug fix 2: teeを削除（二重出力防止。crontab >> との重複解消）
# Bug fix 3: TZ=Asia/Tokyo追加（cronはUTC環境で動作するため、明示的にJST指定が必須）
log() {
    echo "[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')] $*" >> "$LOG_FILE"
}

# API KEY読み込み（ハードコード禁止）
if [ ! -f "$N8N_ENV" ]; then
    log "ERROR: .env not found: $N8N_ENV"
    exit 1
fi
# shellcheck source=/home/ubuntu/.n8n-mcp/n8n/.env
source "$N8N_ENV"

if [ -z "${N8N_API_KEY:-}" ]; then
    log "ERROR: N8N_API_KEY not set in $N8N_ENV"
    exit 1
fi

# jq確認
if ! command -v jq &>/dev/null; then
    log "ERROR: jq not found. Install jq first."
    exit 1
fi

# ============================================================
# 最終exec取得
# ============================================================
EXEC_JSON=$(curl -sf -H "X-N8N-API-KEY: $N8N_API_KEY" \
    "${N8N_URL}/api/v1/executions?workflowId=${WF_ID}&limit=1" 2>/dev/null || echo '{}')

LAST_EXEC_AT=$(echo "$EXEC_JSON" | jq -r '.data[0].startedAt // empty' 2>/dev/null || true)

if [ -z "${LAST_EXEC_AT:-}" ]; then
    log "WARNING: No exec found for WF ${WF_ID}. Skipping."
    exit 0
fi

# ============================================================
# 差分計算（秒 → 分）
# ============================================================
LAST_EXEC_EPOCH=$(date -d "$LAST_EXEC_AT" +%s 2>/dev/null || {
    log "ERROR: Failed to parse exec time: $LAST_EXEC_AT"
    exit 1
})
NOW_EPOCH=$(date +%s)
DIFF_SEC=$(( NOW_EPOCH - LAST_EXEC_EPOCH ))
DIFF_MIN=$(( DIFF_SEC / 60 ))

# ============================================================
# 閾値判定（JST基準）
# Bug fix 3: log()のタイムスタンプをJSTに修正。DOW・HOUR判定ロジックは元から正しい。
# ============================================================
DOW=$(TZ=Asia/Tokyo date +%u)    # 1=月 〜 5=金, 6=土, 7=日
HOUR=$(TZ=Asia/Tokyo date +%-H)  # 先頭ゼロ除去（10進数保証）

if [ "$DOW" -le 5 ] && [ "$HOUR" -ge 9 ] && [ "$HOUR" -lt 19 ]; then
    THRESHOLD=$THRESHOLD_WEEKDAY_DAYTIME
    PERIOD="weekday-daytime"
else
    THRESHOLD=$THRESHOLD_OTHER
    PERIOD="off-hours"
fi

LAST_EXEC_JST=$(TZ=Asia/Tokyo date -d "$LAST_EXEC_AT" '+%H:%M JST' 2>/dev/null || echo "$LAST_EXEC_AT")

log "INFO: WF=${WF_ID} last_exec=${LAST_EXEC_JST} diff=${DIFF_MIN}min threshold=${THRESHOLD}min period=${PERIOD} (DOW=${DOW} HOUR=${HOUR})"

# ============================================================
# スタック検知 → 自動復旧
# ============================================================
if [ "$DIFF_MIN" -gt "$THRESHOLD" ]; then
    log "WARNING: Trigger stuck detected! (${DIFF_MIN}min > ${THRESHOLD}min) Recovering..."

    # Bug fix 1: deactivate
    # 旧: curl -sf ... | jq -r '.active // "error"'
    #   → jqの//演算子はfalseも偽値扱い。false // "error" = "error"(誤)
    # 新: tempfileでHTTPステータスとボディを分離取得。.active | tostringでbooleanを正確に文字列化
    DEACT_TMP=$(mktemp)
    DEACT_HTTP=$(curl -s -o "$DEACT_TMP" -w "%{http_code}" -X POST \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows/${WF_ID}/deactivate" 2>/dev/null || echo "000")
    DEACT=$(cat "$DEACT_TMP"); rm -f "$DEACT_TMP"
    DEACT_STATUS=$(echo "$DEACT" | jq -r '.active | tostring' 2>/dev/null || echo "json-error")
    log "INFO: deactivate → HTTP=${DEACT_HTTP} active=${DEACT_STATUS}"

    if [ "$DEACT_HTTP" != "200" ]; then
        log "WARNING: deactivate failed (HTTP=${DEACT_HTTP}). Body: ${DEACT}. Retrying in 3s..."
        sleep 3
        DEACT_TMP=$(mktemp)
        DEACT_HTTP=$(curl -s -o "$DEACT_TMP" -w "%{http_code}" -X POST \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "${N8N_URL}/api/v1/workflows/${WF_ID}/deactivate" 2>/dev/null || echo "000")
        DEACT=$(cat "$DEACT_TMP"); rm -f "$DEACT_TMP"
        DEACT_STATUS=$(echo "$DEACT" | jq -r '.active | tostring' 2>/dev/null || echo "json-error")
        log "INFO: deactivate retry → HTTP=${DEACT_HTTP} active=${DEACT_STATUS}"
    fi

    sleep 2

    # activate
    ACT_TMP=$(mktemp)
    ACT_HTTP=$(curl -s -o "$ACT_TMP" -w "%{http_code}" -X POST \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows/${WF_ID}/activate" 2>/dev/null || echo "000")
    ACT=$(cat "$ACT_TMP"); rm -f "$ACT_TMP"
    ACT_STATUS=$(echo "$ACT" | jq -r '.active | tostring' 2>/dev/null || echo "json-error")
    log "INFO: activate → HTTP=${ACT_HTTP} active=${ACT_STATUS}"
    [ "$ACT_HTTP" != "200" ] && log "WARNING: activate failed (HTTP=${ACT_HTTP}). Body: ${ACT}"

    log "INFO: Recovery complete."

    # ntfy通知（静音 = 通知あり = スタック時のみ）
    bash "${SHOGUN_DIR}/scripts/ntfy.sh" \
        "⚠️ Gmail Trigger自動復旧(最終exec: ${LAST_EXEC_JST})" \
        "Gmail Trigger Stuck 自動復旧" || true
else
    log "INFO: OK. No action needed. (${DIFF_MIN}min <= ${THRESHOLD}min)"
fi
