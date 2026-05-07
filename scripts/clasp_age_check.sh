#!/usr/bin/env bash
# clasp_age_check.sh — clasp OAuth トークン経過日数監視
# .clasprc.json の mtime を基準に経過日数を計算し、閾値超過時に ntfy 通知
# Exit: 0=NORMAL, 1=WARN, 2=CRITICAL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$SCRIPT_DIR/config/settings.yaml"
LOG_FILE="/tmp/clasp_age_check.log"

log() {
  local ts
  ts="$(date +'%Y-%m-%d %H:%M:%S JST')"
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

# settings.yaml から設定値を読み取る
read_setting() {
  local key="$1" default="$2"
  local val
  val="$(grep "^  ${key}:" "$SETTINGS" 2>/dev/null | awk '{print $2}' | tr -d '"' || true)"
  echo "${val:-$default}"
}

WARN_DAYS="$(read_setting warn_days 25)"
CRITICAL_DAYS="$(read_setting critical_days 28)"
TOKEN_PATH="$(read_setting token_path /home/ubuntu/.clasprc.json)"

# .clasprc.json の存在確認
if [[ ! -f "$TOKEN_PATH" ]]; then
  log "ERROR: $TOKEN_PATH が見つかりません。clasp login が必要です。"
  bash "$SCRIPT_DIR/scripts/notify.sh" "clasp_age_check: .clasprc.json 不在 — clasp login が必要" clasp_age_warn
  exit 2
fi

# 経過日数計算
FILE_EPOCH="$(date -r "$TOKEN_PATH" +%s)"
NOW_EPOCH="$(date +%s)"
ELAPSED_SECONDS=$(( NOW_EPOCH - FILE_EPOCH ))
ELAPSED_DAYS=$(( ELAPSED_SECONDS / 86400 ))

log "clasp token path: $TOKEN_PATH"
log "token 更新日時: $(date -r "$TOKEN_PATH" +'%Y-%m-%d %H:%M:%S')"
log "経過日数: ${ELAPSED_DAYS}日"
log "閾値: WARN=${WARN_DAYS}日, CRITICAL=${CRITICAL_DAYS}日"

# 閾値判定
if (( ELAPSED_DAYS >= CRITICAL_DAYS )); then
  STATUS="CRITICAL"
  MSG="【緊急】clasp token ${ELAPSED_DAYS}日経過 — 即 re-login 必要"
  BADGE="🔴"
  log "${BADGE} ${STATUS}: ${MSG}"
  bash "$SCRIPT_DIR/scripts/notify.sh" "clasp_age_check: ${MSG}" clasp_age_warn
  exit 2

elif (( ELAPSED_DAYS >= WARN_DAYS )); then
  STATUS="WARN"
  MSG="clasp token ${ELAPSED_DAYS}日経過 — 再 login を検討してください"
  BADGE="🟡"
  log "${BADGE} ${STATUS}: ${MSG}"
  bash "$SCRIPT_DIR/scripts/notify.sh" "clasp_age_check: ${MSG}" clasp_age_warn
  exit 1

elif (( ELAPSED_DAYS >= 16 )); then
  STATUS="INFO"
  BADGE="🟡"
  log "${BADGE} ${STATUS}: clasp token ${ELAPSED_DAYS}日経過 (INFO — 通知不要)"
  exit 0

else
  STATUS="NORMAL"
  BADGE="🟢"
  log "${BADGE} ${STATUS}: clasp token ${ELAPSED_DAYS}日経過 (正常範囲内)"
  exit 0
fi
