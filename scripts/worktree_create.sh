#!/bin/bash
set -euo pipefail

# ============================================================
# worktree_create.sh
# ============================================================
# Purpose: Create a new git worktree for an agent
# Usage: bash scripts/worktree_create.sh <agent_id> <branch_name>
# Example: bash scripts/worktree_create.sh ashigaru1 feature-cmd-126
# ============================================================

# ============================================================
# Symlink Configuration
# ============================================================
# Targets that should be symlinked from main worktree to agent worktree.
# These are typically .gitignore-excluded runtime directories/files.
SYMLINK_TARGETS=("queue" "logs" "projects" "dashboard.md")

# Usage function
usage() {
    echo "Usage: $0 <agent_id> <branch_name>"
    echo ""
    echo "Arguments:"
    echo "  agent_id     : Agent identifier (e.g., ashigaru1, ashigaru2)"
    echo "  branch_name  : New branch name for the worktree"
    echo ""
    echo "Example:"
    echo "  $0 ashigaru1 feature-cmd-126"
    exit 1
}

# Argument check
if [ $# -ne 2 ]; then
    echo "ERROR: Exactly 2 arguments required, but got $#"
    usage
fi

AGENT_ID="$1"
BRANCH_NAME="$2"

# Detect project root (SCRIPT_DIR = project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_PATH="$SCRIPT_DIR/.trees/$AGENT_ID"

echo "[WORKTREE] Creating worktree for agent: $AGENT_ID"
echo "[WORKTREE] Branch: $BRANCH_NAME"
echo "[WORKTREE] Path: $WORKTREE_PATH"

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "ERROR: Worktree .trees/$AGENT_ID already exists"
    exit 1
fi

# Check if branch already exists
if git -C "$SCRIPT_DIR" branch --list "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo "ERROR: Branch $BRANCH_NAME already exists"
    exit 1
fi

# Create worktree
echo "[WORKTREE] Running: git worktree add .trees/$AGENT_ID -b $BRANCH_NAME"
if ! git -C "$SCRIPT_DIR" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"; then
    echo "ERROR: git worktree add failed"
    exit 1
fi

# Verify worktree creation
if [ ! -d "$WORKTREE_PATH" ]; then
    echo "ERROR: Worktree directory was not created: $WORKTREE_PATH"
    exit 1
fi

# ============================================================
# Create symlinks for runtime directories/files
# ============================================================
echo "[WORKTREE] Creating symlinks for runtime directories/files..."

for target in "${SYMLINK_TARGETS[@]}"; do
    SOURCE_PATH="$SCRIPT_DIR/$target"
    LINK_PATH="$WORKTREE_PATH/$target"

    # Check if source exists in main worktree
    if [ ! -e "$SOURCE_PATH" ]; then
        echo "[WORKTREE] SKIP: Source does not exist: $target"
        continue
    fi

    # Check if target already exists in agent worktree (idempotency)
    if [ -e "$LINK_PATH" ] || [ -L "$LINK_PATH" ]; then
        echo "[WORKTREE] SKIP: Already exists in worktree: $target"
        continue
    fi

    # Create symlink
    if ln -s "$SOURCE_PATH" "$LINK_PATH"; then
        echo "[WORKTREE] Symlink: $target → $SOURCE_PATH"
    else
        echo "WARNING: Failed to create symlink: $target"
    fi
done

echo "[WORKTREE] Symlink creation complete!"

echo "[WORKTREE] Created .trees/$AGENT_ID on branch $BRANCH_NAME"
echo "[WORKTREE] Success!"
