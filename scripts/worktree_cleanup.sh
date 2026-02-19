#!/bin/bash
set -euo pipefail

# ============================================================
# worktree_cleanup.sh
# ============================================================
# Purpose: Safely remove a git worktree for an agent
# Usage: bash scripts/worktree_cleanup.sh <agent_id>
# Example: bash scripts/worktree_cleanup.sh ashigaru1
# ============================================================

# Usage function
usage() {
    echo "Usage: $0 <agent_id>"
    echo ""
    echo "Arguments:"
    echo "  agent_id : Agent identifier (e.g., ashigaru1, ashigaru2)"
    echo ""
    echo "Example:"
    echo "  $0 ashigaru1"
    exit 1
}

# Argument check
if [ $# -ne 1 ]; then
    echo "ERROR: Exactly 1 argument required, but got $#"
    usage
fi

AGENT_ID="$1"

# Detect project root (SCRIPT_DIR = project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_PATH="$SCRIPT_DIR/.trees/$AGENT_ID"

echo "[WORKTREE] Cleaning up worktree for agent: $AGENT_ID"
echo "[WORKTREE] Path: $WORKTREE_PATH"

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
    echo "WARNING: Worktree .trees/$AGENT_ID does not exist. Nothing to clean."
    exit 0
fi

# Check for uncommitted changes
echo "[WORKTREE] Checking for uncommitted changes..."
if [ -n "$(git -C "$WORKTREE_PATH" status --porcelain)" ]; then
    echo "WARNING: Uncommitted changes in .trees/$AGENT_ID. Aborting."
    echo ""
    echo "Uncommitted changes:"
    git -C "$WORKTREE_PATH" status --short
    exit 1
fi

# Get branch name
BRANCH_NAME=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)
echo "[WORKTREE] Branch: $BRANCH_NAME"

# ============================================================
# Safely remove symlinks before worktree removal
# ============================================================
echo "[WORKTREE] Removing symlinks in worktree..."

# Find all symlinks in worktree root (maxdepth 1)
SYMLINKS=$(find "$WORKTREE_PATH" -maxdepth 1 -type l 2>/dev/null || true)

if [ -n "$SYMLINKS" ]; then
    while IFS= read -r symlink; do
        SYMLINK_NAME=$(basename "$symlink")
        LINK_TARGET=$(readlink "$symlink")

        # Unlink the symlink (safe: does not affect link target)
        if unlink "$symlink"; then
            echo "[WORKTREE] Unlinked symlink: $SYMLINK_NAME (was pointing to $LINK_TARGET)"
        else
            echo "WARNING: Failed to unlink: $SYMLINK_NAME"
        fi
    done <<< "$SYMLINKS"
else
    echo "[WORKTREE] No symlinks found in worktree"
fi

# Verify that link targets (main queue/, logs/, etc.) are intact
echo "[WORKTREE] Verifying link target integrity..."
for target in "queue" "logs" "projects" "dashboard.md"; do
    MAIN_TARGET="$SCRIPT_DIR/$target"
    if [ -e "$MAIN_TARGET" ]; then
        echo "[WORKTREE] ✓ Intact: $target (in main worktree)"
    else
        echo "[WORKTREE] ! Not found (may not exist): $target"
    fi
done

echo "[WORKTREE] Symlink cleanup complete!"

# Remove worktree
echo "[WORKTREE] Running: git worktree remove .trees/$AGENT_ID"
if ! git -C "$SCRIPT_DIR" worktree remove "$WORKTREE_PATH"; then
    echo "ERROR: git worktree remove failed"
    exit 1
fi

# Try to delete branch (only if merged)
echo "[WORKTREE] Attempting to delete branch: $BRANCH_NAME"
if git -C "$SCRIPT_DIR" branch -d "$BRANCH_NAME" 2>/dev/null; then
    echo "[WORKTREE] Branch $BRANCH_NAME deleted (was merged)"
else
    echo "WARNING: Branch $BRANCH_NAME is not merged. Keeping the branch."
    echo "         To force delete, run: git branch -D $BRANCH_NAME"
fi

# Prune worktree metadata
echo "[WORKTREE] Running: git worktree prune"
git -C "$SCRIPT_DIR" worktree prune

echo "[WORKTREE] Removed .trees/$AGENT_ID and branch $BRANCH_NAME"
echo "[WORKTREE] Cleanup complete!"
