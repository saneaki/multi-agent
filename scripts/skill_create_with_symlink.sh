#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <skill-name>" >&2
  exit 1
fi

name="$1"
root="/home/ubuntu/shogun/skills/$name"
dst="/home/ubuntu/.claude/skills/$name"
skill_md="$root/SKILL.md"

if [[ -d "$root" ]]; then
  echo "SKIP: skill already exists: $root"
  exit 0
fi

mkdir -p "$root" "/home/ubuntu/.claude/skills"
cat > "$skill_md" <<TEMPLATE
---
name: $name
description: >
  Describe when to use this skill.
tags: [custom]
---

# $name

## Purpose

Describe the workflow and constraints.
TEMPLATE

if [[ -e "$dst" && ! -L "$dst" ]]; then
  echo "SKIP: destination exists as real path: $dst"
  exit 0
fi

rm -f "$dst"
ln -s "$root" "$dst"
echo "created: $root"
echo "linked:  $dst -> $root"
