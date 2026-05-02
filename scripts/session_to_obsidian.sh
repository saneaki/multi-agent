#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="/tmp/session_to_obsidian.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "[session_to_obsidian] lock held -> skip" >&2
  exit 0
fi

DRY_RUN=0
DO_PUSH=0
TARGET_DATE=""
OUTPUT_DIR="${OBSIDIAN_REPO_PATH:-/home/ubuntu/obsidian}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      TARGET_DATE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_DATE" ]]; then
  TARGET_DATE="$(TZ=Asia/Tokyo date +%F)"
fi

if ! [[ "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid --date: $TARGET_DATE" >&2
  exit 1
fi

YMD="${TARGET_DATE//-/}"
YEAR="${TARGET_DATE:0:4}"
MONTH="${TARGET_DATE:5:2}"
DAY="${TARGET_DATE:8:2}"
START_ISO="${TARGET_DATE}T00:00:00+09:00"
END_ISO="${TARGET_DATE}T23:00:00+09:00"
GEN_AT="${TARGET_DATE}T23:00:00+09:00"

OUT_PATH="${OUTPUT_DIR}/daily/${YEAR}/${MONTH}/${DAY}/${YMD}_shogun_session.md"

S1_DIR="${HOME}/.claude/sessions"
S2_FILE="queue/reports/gunshi_report.yaml"
S3_FILE="queue/inbox/shogun.yaml"
S5_FILE="dashboard.md"

[[ -d "$S1_DIR" ]] || { echo "Missing source dir: $S1_DIR" >&2; exit 1; }
[[ -f "$S2_FILE" ]] || { echo "Missing source file: $S2_FILE" >&2; exit 1; }
[[ -f "$S3_FILE" ]] || { echo "Missing source file: $S3_FILE" >&2; exit 1; }
[[ -f "$S5_FILE" ]] || { echo "Missing source file: $S5_FILE" >&2; exit 1; }

redact() {
  sed -E \
    -e 's/(NOTION_INTEGRATION_TOKEN|GEMINI_API_KEY2|GEMINI_API_KEY)=[^[:space:]]+/\1=[REDACTED]/g' \
    -e 's/(secret|password|token)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_.-]{20,}/\1=[REDACTED]/Ig' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9_.-]{20,}/\1[REDACTED]/g' \
    -e 's/(refresh_token|access_token)["[:space:]]*[:=][[:space:]]*"[A-Za-z0-9_.-]{20,}"/\1=[REDACTED]/Ig'
}

# cmd candidate extraction from S3 (lord_command and cmd issuance patterns)
mapfile -t CMD_IDS < <(
  awk -v start="$START_ISO" -v end="$END_ISO" '
    function flush() {
      if (ts >= start && ts < end && (typ ~ /lord_command/ || msg ~ /cmd_[0-9]+[[:space:]]*発令|新[[:space:]]*cmd[[:space:]]*発令/)) {
        if (match(msg, /cmd_[0-9]+/)) {
          print substr(msg, RSTART, RLENGTH)
        }
      }
      ts=""; typ=""; msg=""
    }
    /^- content:[[:space:]]*/ { flush(); msg=$0; sub(/^- content:[[:space:]]*/, "", msg); next }
    /^  timestamp:[[:space:]]*/ { ts=$2; gsub(/\047/, "", ts); next }
    /^  type:[[:space:]]*/ { typ=$2; next }
    { if (msg != "" && $0 ~ /^  /) { line=$0; sub(/^  /, "", line); msg=msg " " line } }
    END { flush() }
  ' "$S3_FILE" | sort -u
)

# fallback: read in-progress cmd IDs from dashboard
if [[ ${#CMD_IDS[@]} -eq 0 ]]; then
  mapfile -t CMD_IDS < <(grep -oE "cmd_[0-9]+" "$S5_FILE" | sort -u)
fi

if [[ ${#CMD_IDS[@]} -eq 0 ]]; then
  CMD_IDS=("cmd_unknown")
fi

CMDS_JOINED="$(printf "%s, " "${CMD_IDS[@]}")"
CMDS_JOINED="${CMDS_JOINED%, }"

build_section() {
  local cmd="$1"
  local title
  title="$(awk -v c="$cmd" '$0 ~ c {print; exit}' "$S5_FILE" | sed -E 's/^.*\|[[:space:]]*'"$cmd"'[[:space:]]*\|[[:space:]]*//; s/[[:space:]]*\|.*$//')"
  if [[ -z "$title" ]]; then
    title="(title unavailable)"
  fi

  local issued_at
  issued_at="$(awk -v c="$cmd" '
    $0 ~ c {found=1}
    found && /^  timestamp:/ {gsub(/\047/, "", $2); print $2; exit}
  ' "$S3_FILE")"
  [[ -n "$issued_at" ]] || issued_at="unknown"

  {
    echo "## ${cmd}: ${title}"
    echo "- **発令時刻**: ${issued_at}"
    echo "- **担当**: (auto-detected)"
    echo "- **agents**: 殿, 将軍, 家老, 軍師, 足軽"
    echo
    echo "### 殿令 / 発令内容"
    awk -v c="$cmd" '
      $0 ~ c {print; shown=1; next}
      shown && /^- content:/ {exit}
      shown {print}
    ' "$S3_FILE" | head -n 20 | sed 's/^/- /'
    echo
    echo "### 将軍検討"
    awk '/from: shogun/{flag=1} flag && /^- content:/{print; cnt++; if (cnt>=3) exit}' "$S3_FILE" | sed 's/^/- /'
    echo
    echo "### 足軽\/軍師提案"
    awk '/^suggestions:/{f=1; next} f && /^concerns_flagged:/{exit} f {print}' "$S2_FILE" | head -n 20 | sed 's/^/- /'
    echo
    echo "### 完遂報告サマリ"
    awk '/^result:/{f=1; next} f && /^  ac_verification:/{exit} f {print}' "$S2_FILE" | head -n 20 | sed 's/^/- /'
    echo
    echo "---"
    echo
  }
}

{
  echo "---"
  echo "date: ${TARGET_DATE}"
  echo "shogun_session: true"
  printf "cmds: ["
  for i in "${!CMD_IDS[@]}"; do
    if [[ "$i" -gt 0 ]]; then printf ", "; fi
    printf "%s" "${CMD_IDS[$i]}"
  done
  echo "]"
  echo "generated_at: ${GEN_AT}"
  echo "---"
  echo
  echo "# ${TARGET_DATE} shogun 会話ログ"
  echo

  for cmd in "${CMD_IDS[@]}"; do
    build_section "$cmd"
  done

  echo "## S1 セッションファイル一覧"
  ls -1 "$S1_DIR" | grep -E "${TARGET_DATE}|shogun" | head -n 50 | sed 's/^/- /'
} | redact > /tmp/session_to_obsidian_rendered.md

if [[ "$DRY_RUN" -eq 1 ]]; then
  cat /tmp/session_to_obsidian_rendered.md
  exit 0
fi

mkdir -p "$(dirname "$OUT_PATH")"
if ! cp /tmp/session_to_obsidian_rendered.md "$OUT_PATH"; then
  echo "Failed to write: $OUT_PATH" >&2
  exit 2
fi

echo "Wrote: $OUT_PATH"

if [[ "$DO_PUSH" -eq 1 ]]; then
  if ! cd "$OUTPUT_DIR"; then
    echo "Failed to cd to obsidian repo: $OUTPUT_DIR" >&2
    exit 1
  fi

  if ! git add "$OUT_PATH"; then
    echo "git add failed: $OUT_PATH" >&2
    exit 1
  fi

  if ! git commit -m "session: $(date +%Y-%m-%d) shogun log"; then
    echo "git commit failed" >&2
    exit 1
  fi

  if ! git push origin main; then
    echo "git push failed" >&2
    exit 1
  fi

  echo "Pushed to origin/main"
fi

exit 0
