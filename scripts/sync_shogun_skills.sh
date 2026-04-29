#!/usr/bin/env bash
set -euo pipefail

SRC_BASE="/home/ubuntu/shogun/skills"
DST_BASE="/home/ubuntu/.claude/skills"
LOG_FILE="/home/ubuntu/shogun/logs/sync_skills.log"

mkdir -p "$(dirname "$LOG_FILE")" "$DST_BASE"

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S UTC')
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

sync_one() {
  local name="$1"
  local src="$SRC_BASE/$name"
  local dst="$DST_BASE/$name"

  if [[ "$name" == "gemini-thinking-token-guard" && -e "$dst" && ! -L "$dst" ]]; then
    log "SKIP conflict: $name (real directory exists at destination)"
    return 0
  fi

  if [[ -L "$dst" ]]; then
    local current
    current=$(readlink "$dst" || true)
    if [[ "$current" == "$src" ]]; then
      log "OK already linked: $name"
      return 0
    fi
    if [[ ! -e "$dst" ]]; then
      log "Repair broken symlink: $name"
    else
      log "Relink changed symlink: $name"
    fi
    rm -f "$dst"
    ln -s "$src" "$dst"
    log "OK linked: $name"
    return 0
  fi

  if [[ -e "$dst" ]]; then
    log "SKIP conflict: $name (destination exists and is not symlink)"
    return 0
  fi

  ln -s "$src" "$dst"
  log "OK new link: $name"
}

log "=== sync start ==="
if [[ ! -d "$SRC_BASE" ]]; then
  log "SKIP source not found: $SRC_BASE"
  exit 0
fi

for dir in "$SRC_BASE"/*; do
  [[ -d "$dir" ]] || continue
  name=$(basename "$dir")
  sync_one "$name"
done

log "=== sync done ==="
