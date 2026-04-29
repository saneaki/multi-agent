#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
SRC="$REPO_ROOT/scripts/git-hooks/post-commit"
DST="$REPO_ROOT/.git/hooks/post-commit"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source hook not found: $SRC" >&2
  exit 1
fi

if [[ -e "$DST" && ! -L "$DST" ]]; then
  cp "$DST" "${DST}.bak.$(date +%Y%m%d%H%M%S)"
  rm -f "$DST"
elif [[ -L "$DST" ]]; then
  rm -f "$DST"
fi

ln -s "$SRC" "$DST"
chmod +x "$SRC"
echo "installed: $DST -> $SRC"
