#!/usr/bin/env bash
# generate_notion_summary.sh
# cmd_631 Scope C2 — Obsidian md → cmd 単位 LLM narrative → Notion upsert JSON
#
# 仕様: output/cmd_631_specification.md §4
# Model: gemini-3.1-flash-lite-preview
# 入力: C1 (session_to_obsidian.sh) が生成した Obsidian md (## cmd_NNN: H2 区切り)
# 出力: Notion DIARY_DB upsert 用 JSON ({date, obsidian_link, cmds: [...]})

set -uo pipefail

readonly SCRIPT_NAME="generate_notion_summary"
# 仕様書 §4.3 で固定。.env の GEMINI_MODEL とは独立 (それは別用途)。
readonly NOTION_SUMMARY_MODEL="gemini-3.1-flash-lite-preview"
readonly GEMINI_API_BASE="https://generativelanguage.googleapis.com/v1beta/models"
readonly GEMINI_API_URL="${GEMINI_API_BASE}/${NOTION_SUMMARY_MODEL}:generateContent"
readonly MAX_TOKENS=800
readonly REQUEST_TIMEOUT=30
readonly RETRY_MAX=3
readonly RETRY_WAIT=30
readonly OBSIDIAN_REPO_BASE="https://github.com/saneaki/obsidian/blob/main/daily"

# ---------- helpers ----------

log()  { echo "[${SCRIPT_NAME}] $*" >&2; }
err()  { echo "[${SCRIPT_NAME}][ERROR] $*" >&2; }
die()  { err "$*"; exit "${2:-1}"; }

usage() {
  cat >&2 <<'USAGE'
Usage:
  generate_notion_summary.sh --input <obsidian.md> [--date YYYY-MM-DD]
                             [--dry-run] [--output <json_path>]

Args:
  --input PATH    C1 出力の Obsidian md ファイル (必須)
  --date DATE     対象日付 YYYY-MM-DD (default: md frontmatter から抽出)
  --dry-run       API 呼出なし、prompt のみ stdout 出力
  --output PATH   JSON 出力先 (default: stdout)

Exit codes:
  0  正常完了
  1  GEMINI_API_KEY2 不在 / API timeout / I/O error
  2  input md parse 失敗
USAGE
}

# ---------- arg parse ----------

INPUT_MD=""
TARGET_DATE=""
DRY_RUN=0
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)    INPUT_MD="${2:-}"; shift 2 ;;
    --date)     TARGET_DATE="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --output)   OUTPUT_PATH="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          err "unknown option: $1"; usage; exit 2 ;;
  esac
done

[[ -z "$INPUT_MD" ]]   && { err "--input required"; usage; exit 2; }
[[ ! -f "$INPUT_MD" ]] && die "input md not found: $INPUT_MD" 2

# ---------- env load ----------

if [[ -f /home/ubuntu/shogun/.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /home/ubuntu/shogun/.env; set +a
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -z "${GEMINI_API_KEY2:-}" ]] && die "GEMINI_API_KEY2 not set (.env or env)" 1
fi

# ---------- parse frontmatter date ----------

if [[ -z "$TARGET_DATE" ]]; then
  TARGET_DATE=$(awk '
    /^---[[:space:]]*$/ { inside = !inside; next }
    inside && /^date:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      sub(/^date:[[:space:]]*/, "", $0); print; exit
    }
  ' "$INPUT_MD" | tr -d '\r')
fi

if [[ ! "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  die "could not resolve target date (use --date YYYY-MM-DD or add 'date:' to frontmatter)" 2
fi

YEAR="${TARGET_DATE%%-*}"
REST="${TARGET_DATE#*-}"
MONTH="${REST%%-*}"
DAY="${TARGET_DATE##*-}"
OBSIDIAN_LINK="${OBSIDIAN_REPO_BASE}/${YEAR}/${MONTH}/${DAY}/${YEAR}${MONTH}${DAY}_shogun_session.md"

# ---------- chunk split (## cmd_NNN: H2) ----------

CHUNK_DIR="$(mktemp -d -t notion_summary_XXXXXX)"
trap 'rm -rf "$CHUNK_DIR"' EXIT

awk -v dir="$CHUNK_DIR" '
  BEGIN { idx = 0; out = "" }
  /^## cmd_[0-9]+:/ {
    if (out != "") close(out)
    idx += 1
    out = sprintf("%s/cmd_%04d.md", dir, idx)
  }
  out != "" { print > out }
' "$INPUT_MD"

shopt -s nullglob
CHUNK_FILES=("$CHUNK_DIR"/cmd_*.md)
shopt -u nullglob

if [[ ${#CHUNK_FILES[@]} -eq 0 ]]; then
  die "no '## cmd_NNN:' headings found in input md" 2
fi

# ---------- prompt builder ----------

readonly SYSTEM_PROMPT='あなたは shogun マルチエージェントシステムの会話ログを要約する narrative writer です。
入力された 1 つの cmd の会話ログから、以下の構成で日本語 500 字以内の narrative を生成してください。

【構成 (必須)】
1. どういう考えで (背景・動機・北極星)
2. 何を作って (実装・成果物・担当 agent)
3. 結果どうだったか (AC PASS/FAIL・所見・次アクション)

【制約】
- 500 字以内 (450-550 字推奨)
- 機械的羅列禁止 (例: "AC1 PASS / AC2 PASS" は不可)
- ストーリー形式で、1 段落の文章として読める形に
- 殿/将軍/家老/軍師/足軽 の役割語彙を維持
- 提案者と意思決定者を明示する'

build_user_prompt() {
  local cmd_id="$1" chunk_file="$2"
  printf '以下は %s の会話ログです:\n\n' "$cmd_id"
  cat "$chunk_file"
  printf '\n\n500 字以内の narrative を生成してください。\n'
}

# Gemini API は systemInstruction + contents を受ける。
# 1 chunk あたり request body を jq で構築 (安全な escape)。
build_request_body() {
  local user_prompt="$1"
  jq -n \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$user_prompt" \
    --argjson max "$MAX_TOKENS" \
    '{
      systemInstruction: { parts: [ { text: $sys } ] },
      contents: [ { role: "user", parts: [ { text: $usr } ] } ],
      generationConfig: { maxOutputTokens: $max, temperature: 0.4 }
    }'
}

# ---------- Gemini call w/ retry ----------

call_gemini() {
  local body="$1"
  local attempt=0 http_code resp_file
  resp_file="$(mktemp -t gemini_resp_XXXXXX)"

  while (( attempt < RETRY_MAX )); do
    attempt=$((attempt + 1))
    http_code=$(curl -sS \
      -o "$resp_file" \
      -w '%{http_code}' \
      --max-time "$REQUEST_TIMEOUT" \
      -H "Content-Type: application/json" \
      -H "x-goog-api-key: ${GEMINI_API_KEY2}" \
      -X POST "$GEMINI_API_URL" \
      --data-binary "$body" 2>/dev/null) || http_code="000"

    if [[ "$http_code" == "200" ]]; then
      cat "$resp_file"
      rm -f "$resp_file"
      return 0
    fi

    if [[ "$http_code" == "429" ]]; then
      log "429 rate limited (attempt ${attempt}/${RETRY_MAX}) — waiting ${RETRY_WAIT}s"
      sleep "$RETRY_WAIT"
      continue
    fi

    log "http=${http_code} (attempt ${attempt}/${RETRY_MAX})"
    sleep 2
  done

  rm -f "$resp_file"
  return 1
}

extract_narrative() {
  jq -r '
    .candidates[0].content.parts[]?.text? // empty
    | select(. != null)
  ' 2>/dev/null \
    | tr -d '\r' \
    | awk 'BEGIN{ORS=""} {print} END{print ""}'
}

fallback_narrative() {
  local cmd_id="$1" title="$2"
  printf '%s: 完遂 / 主要成果物: %s (LLM fallback)' "$cmd_id" "${title:-未取得}"
}

# ---------- per-chunk processing ----------

extract_cmd_id() {
  awk 'NR==1 { match($0, /cmd_[0-9]+/); if (RSTART) print substr($0, RSTART, RLENGTH); exit }' "$1"
}

extract_title() {
  awk 'NR==1 { sub(/^## cmd_[0-9]+:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

extract_agents() {
  # **agents**: 殿, 将軍, 家老, 軍師 → ["殿","将軍","家老","軍師"]
  local raw
  raw=$(awk -F'\\*\\*agents\\*\\*:[[:space:]]*' '
    /\*\*agents\*\*:/ { print $2; exit }
  ' "$1" | tr -d '\r')
  if [[ -z "$raw" ]]; then
    printf '[]'
    return
  fi
  printf '%s' "$raw" | jq -R '
    split(",")
    | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
    | map(select(length > 0))
  '
}

extract_status() {
  # 完了報告 / 完遂 を含む → completed、それ以外 → in_progress
  if grep -qE '完遂報告|完了報告|完了|完遂' "$1" 2>/dev/null; then
    printf 'completed'
  else
    printf 'in_progress'
  fi
}

# ---------- main loop ----------

CMDS_JSON_FILE="$(mktemp -t cmds_arr_XXXXXX.json)"
echo '[]' > "$CMDS_JSON_FILE"
trap 'rm -rf "$CHUNK_DIR" "$CMDS_JSON_FILE"' EXIT

EXIT_STATUS=0

for chunk_file in "${CHUNK_FILES[@]}"; do
  cmd_id="$(extract_cmd_id "$chunk_file")"
  title="$(extract_title "$chunk_file")"
  agents_json="$(extract_agents "$chunk_file")"
  status="$(extract_status "$chunk_file")"

  if [[ -z "$cmd_id" ]]; then
    log "skip chunk (no cmd_id): $chunk_file"
    continue
  fi

  user_prompt="$(build_user_prompt "$cmd_id" "$chunk_file")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    # AC1: dry-run は prompt を stdout 出力、API 呼出なし
    printf -- '----- prompt for %s -----\n' "$cmd_id"
    printf '[system]\n%s\n\n' "$SYSTEM_PROMPT"
    printf '[user]\n%s\n' "$user_prompt"
    printf -- '----- end prompt for %s -----\n\n' "$cmd_id"
    continue
  fi

  body="$(build_request_body "$user_prompt")"

  if narrative_resp="$(call_gemini "$body")"; then
    narrative="$(printf '%s' "$narrative_resp" | extract_narrative)"
    [[ -z "$narrative" ]] && {
      log "empty narrative for ${cmd_id}, using fallback"
      narrative="$(fallback_narrative "$cmd_id" "$title")"
      EXIT_STATUS=1
    }
  else
    log "Gemini call failed for ${cmd_id} after ${RETRY_MAX} attempts, using fallback"
    narrative="$(fallback_narrative "$cmd_id" "$title")"
    EXIT_STATUS=1
  fi

  # cmds 配列に append
  jq --arg cmd_id "$cmd_id" \
     --arg title "$title" \
     --arg narrative "$narrative" \
     --argjson agents "$agents_json" \
     --arg status "$status" \
     '. + [{
        cmd_id: $cmd_id,
        title: $title,
        narrative: $narrative,
        agents: $agents,
        status: $status
      }]' \
     "$CMDS_JSON_FILE" > "${CMDS_JSON_FILE}.tmp" && mv "${CMDS_JSON_FILE}.tmp" "$CMDS_JSON_FILE"
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run complete (${#CHUNK_FILES[@]} chunks)"
  exit 0
fi

# ---------- final JSON ----------

FINAL_JSON="$(jq -n \
  --arg date "$TARGET_DATE" \
  --arg link "$OBSIDIAN_LINK" \
  --slurpfile cmds "$CMDS_JSON_FILE" \
  '{ date: $date, obsidian_link: $link, cmds: $cmds[0] }')"

if [[ -n "$OUTPUT_PATH" ]]; then
  printf '%s\n' "$FINAL_JSON" > "$OUTPUT_PATH"
  log "JSON written to $OUTPUT_PATH"
else
  printf '%s\n' "$FINAL_JSON"
fi

exit "$EXIT_STATUS"
