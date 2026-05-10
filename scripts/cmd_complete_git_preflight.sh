#!/usr/bin/env bash
# cmd_complete_git_preflight.sh: verify git cleanliness before cmd completion.

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: bash scripts/cmd_complete_git_preflight.sh [--repo PATH] [--ref REF]

Checks:
  - repository has no uncommitted tracked or untracked changes
  - HEAD is not ahead of upstream/ref
  - HEAD is not behind/diverged from upstream/ref

Exit codes:
  0: clean and synchronized
  1: dirty, ahead, behind, or diverged
  2: usage error
  3: no upstream/ref available
EOF
}

REPO="."
REF=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            REPO="$2"
            shift 2
            ;;
        --ref)
            [ "$#" -ge 2 ] || { usage; exit 2; }
            REF="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not a git worktree: $REPO" >&2
    exit 2
fi

TOPLEVEL="$(git -C "$REPO" rev-parse --show-toplevel)"
HEAD_SHA="$(git -C "$TOPLEVEL" rev-parse --short HEAD)"
BRANCH_LINE="$(git -C "$TOPLEVEL" status --short --branch)"
STATUS_SHORT="$(git -C "$TOPLEVEL" status --porcelain=v1)"

if [ -z "$REF" ]; then
    if ! REF="$(git -C "$TOPLEVEL" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
        echo "repo: $TOPLEVEL"
        echo "head: $HEAD_SHA"
        echo "branch: $BRANCH_LINE"
        echo "clean: $([ -z "$STATUS_SHORT" ] && echo true || echo false)"
        echo "ref: null"
        echo "status: FAIL"
        echo "reason: no upstream configured; pass --ref origin/main when push verification is required"
        exit 3
    fi
fi

if ! git -C "$TOPLEVEL" rev-parse --verify --quiet "$REF" >/dev/null; then
    echo "ERROR: ref not found: $REF" >&2
    exit 2
fi

read -r BEHIND AHEAD < <(git -C "$TOPLEVEL" rev-list --left-right --count "${REF}...HEAD")

DIRTY_COUNT=0
if [ -n "$STATUS_SHORT" ]; then
    DIRTY_COUNT="$(printf '%s\n' "$STATUS_SHORT" | sed '/^$/d' | wc -l | tr -d ' ')"
fi

echo "repo: $TOPLEVEL"
echo "head: $HEAD_SHA"
echo "branch: $BRANCH_LINE"
echo "ref: $REF"
echo "dirty_count: $DIRTY_COUNT"
echo "ahead: $AHEAD"
echo "behind: $BEHIND"

if [ "$DIRTY_COUNT" -eq 0 ] && [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ]; then
    echo "status: PASS"
    exit 0
fi

echo "status: FAIL"
if [ "$DIRTY_COUNT" -gt 0 ]; then
    echo "reason: uncommitted changes remain"
    printf '%s\n' "$STATUS_SHORT"
elif [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
    echo "reason: branch diverged from $REF"
elif [ "$AHEAD" -gt 0 ]; then
    echo "reason: local commits are not pushed"
elif [ "$BEHIND" -gt 0 ]; then
    echo "reason: local branch is behind $REF"
fi

exit 1
