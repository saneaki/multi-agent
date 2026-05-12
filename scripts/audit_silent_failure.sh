#!/usr/bin/env bash
# Audit shell scripts for silent-failure suppressions that can hide control-plane errors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-${ROOT_DIR}/output/cmd_717b_silent_failure_audit_so17_hardening.md}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

mapfile -t TARGETS < <(
    {
        [[ -f "${ROOT_DIR}/shutsujin_departure.sh" ]] && printf '%s\n' "${ROOT_DIR}/shutsujin_departure.sh"
        find "${ROOT_DIR}/scripts" -maxdepth 1 -type f -name '*.sh' -print
        [[ -d "${ROOT_DIR}/scripts/lib" ]] && find "${ROOT_DIR}/scripts/lib" -maxdepth 1 -type f -name '*.sh' -print
    } | sort -u
)

PATTERN='([&0-9]*>/?dev/null|>/dev/null[[:space:]]+2>&1)[[:space:]]*(\|\|)[[:space:]]*(log_info|true|:)($|[[:space:];#])'

classify_line() {
    local line="$1"

    case "$line" in
        *"tmux send-keys"*|*"switch_cli"*|*"pkill "*|*"kill-window"*|*"inotifywait"*|*"fswatch"*)
            printf 'remediation_required|critical control-plane action is suppressed; failure must be surfaced or explicitly gated'
            ;;
        *"notify.sh"*|*"discord"*|*"gchat"*|*"ntfy"*|*"webhook"*)
            printf 'review_required|notification failure may be acceptable only with fallback/log evidence'
            ;;
        *"set-option"*|*"select-pane"*|*"set-environment"*|*"resize-pane"*)
            printf 'review_required|tmux cosmetic/metadata operation may be acceptable, but operational impact must be documented'
            ;;
        *"rm -f"*|*"rmdir"*|*"mkdir -p"*|*"touch "*|*"cp "*|*"mv "*|*"cat "*|*"grep "*|*"crontab "*)
            printf 'allowed_with_comment|required only if best-effort cleanup/probe is intentional and nearby comment explains why'
            ;;
        *)
            printf 'review_required|suppression requires explicit justification or propagation decision'
            ;;
    esac
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

for file in "${TARGETS[@]}"; do
    grep -HEn "$PATTERN" "$file" 2>/dev/null || true
done > "$tmp_file"

total=0
remediation=0
review=0
allowed=0

while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    total=$((total + 1))
    line_text="${match#*:}"
    line_text="${line_text#*:}"
    classification="$(classify_line "$line_text")"
    case "${classification%%|*}" in
        remediation_required) remediation=$((remediation + 1)) ;;
        review_required) review=$((review + 1)) ;;
        allowed_with_comment) allowed=$((allowed + 1)) ;;
    esac
done < "$tmp_file"

{
    echo "# cmd_717b Silent Failure Audit + SO-17 Hardening"
    echo
    echo "| item | value |"
    echo "|---|---|"
    echo "| generated_at | $(bash "${ROOT_DIR}/scripts/jst_now.sh" 2>/dev/null || date -u '+%Y-%m-%d %H:%M UTC') |"
    echo "| scope | shutsujin_departure.sh, scripts/*.sh, scripts/lib/*.sh |"
    echo "| pattern | stderr/stdout suppression followed by \`|| log_info\`, \`|| true\`, or \`|| :\` |"
    echo "| total_matches | ${total} |"
    echo "| remediation_required | ${remediation} |"
    echo "| review_required | ${review} |"
    echo "| allowed_with_comment | ${allowed} |"
    echo
    echo "## 0. cmd_706 Completion Review Note"
    echo
    echo 'cmd_706 fixed `switch_cli.sh` and `shc.sh`, but its completion boundary was too narrow: it verified the child switch path, not the parent `shutsujin_departure.sh` outcome. The missing guard was an outcome-level SO-17 check: when the north star is "shx must either visibly fail or halt", QC must require an actual dry-run/E2E artifact of the parent path rather than unit AC evidence from child scripts only.'
    echo
    echo "## Classification Policy"
    echo
    echo "- remediation_required: control-plane actions whose failure can make an operation appear successful."
    echo "- review_required: possible best-effort behavior, but outcome should be logged, surfaced, or justified."
    echo "- allowed_with_comment: acceptable only when the operation is a probe, cleanup, or cosmetic update and a nearby comment explains that best-effort behavior is intentional."
    echo
    echo "## Findings"
    echo
    if [[ "$total" -eq 0 ]]; then
        echo "No silent-failure suppression pattern matched."
    else
        echo "| # | file:line | classification | comment_required | reason | source |"
        echo "|---:|---|---|---|---|---|"
        idx=0
        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            idx=$((idx + 1))
            file="${match%%:*}"
            rest="${match#*:}"
            line_no="${rest%%:*}"
            source_line="${rest#*:}"
            classification="$(classify_line "$source_line")"
            class_name="${classification%%|*}"
            reason="${classification#*|}"
            comment_required="yes"
            [[ "$class_name" == "remediation_required" ]] && comment_required="n/a - fix required"
            rel_path="${file#${ROOT_DIR}/}"
            escaped_source="$(printf '%s' "$source_line" | sed 's/|/\\|/g; s/`/\\`/g')"
            printf '| %d | `%s:%s` | %s | %s | %s | `%s` |\n' \
                "$idx" "$rel_path" "$line_no" "$class_name" "$comment_required" "$reason" "$escaped_source"
        done < "$tmp_file"
    fi
    echo
    echo "## Acceptance Notes"
    echo
    echo "- This audit is read-only for the scanned source files."
    echo "- The script intentionally does not bulk-fix findings; owners must decide whether each suppression is safe, needs a comment, or must propagate failure."
} > "$OUTPUT_PATH"

cat "$OUTPUT_PATH"
