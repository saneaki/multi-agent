#!/usr/bin/env bash
# guard.sh — Claude Code PreToolUse hook for Bash tool
# Based on halsk/multi-agent-shogun guard.sh, customized for marucc fork.
#
# Reads JSON from stdin: {"tool_name": "Bash", "tool_input": {"command": "..."}}
# exit 0 = allow, exit 2 = block (stderr shown as error message)

set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ============================================================
# Helper: detect git subcommand invocation
# Catches: direct (git push), full path (/usr/bin/git push),
#   command/env wrapper, function alias (f(){ git "$@"; }; f push),
#   variable alias (v=git; $v push)
# ============================================================
has_git_subcmd() {
  local cmd="$1"
  local subcmd="$2"
  # Direct: git push, git commit
  echo "$cmd" | grep -qE "git\s+$subcmd\b" && return 0
  # Full path: /usr/bin/git push
  echo "$cmd" | grep -qE "/git\s+$subcmd\b" && return 0
  # command/env wrapper: command git push, env git push
  echo "$cmd" | grep -qE "(command|env)\s+git\s+$subcmd\b" && return 0
  # Function alias: f() { git "$@"; } ... f push
  echo "$cmd" | grep -qE '\(\)\s*\{[^}]*git\b' && echo "$cmd" | grep -qE "\b$subcmd\b" && return 0
  # Variable alias: v=git; $v push
  echo "$cmd" | grep -qE '\w+=git(\s|;|&|$)' && echo "$cmd" | grep -qE "\b$subcmd\b" && return 0
  # Variable subcommand: SUBCMD=push; git $SUBCMD
  echo "$cmd" | grep -qiE "\w+=$subcmd(\s|;|&|\"|$)" && echo "$cmd" | grep -qE 'git\s+\$' && return 0
  return 1
}

# ============================================================
# Guard 1: rm コマンド → trash 強制
# ============================================================
if echo "$COMMAND" | grep -qE '\brm\s+'; then
  echo "❌ rm コマンドは禁止です。trash を使用してください。" >&2
  exit 2
fi

# ============================================================
# Guard 2: 破壊的操作ガード (D001-D008)
# ============================================================

# D001: rm -rf on critical paths
if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+(/\*?$|/mnt/\*|/home/\*|~(/|$| ))' || \
   echo "$COMMAND" | grep -qE 'rm\s+-rf\s+~$'; then
  echo "❌ 破壊的操作が検出されました: rm -rf 重要パス。D001 違反です。" >&2
  exit 2
fi

# D003: git push --force / -f (without --force-with-lease)
if has_git_subcmd "$COMMAND" "push" && echo "$COMMAND" | grep -qE '\-\-force\b' && ! echo "$COMMAND" | grep -q 'force-with-lease'; then
  echo "❌ 破壊的操作が検出されました: git push --force。D003 違反です。--force-with-lease を使用してください。" >&2
  exit 2
fi
if has_git_subcmd "$COMMAND" "push" && echo "$COMMAND" | grep -qE '(^|\s)-f\b'; then
  echo "❌ 破壊的操作が検出されました: git push -f。D003 違反です。--force-with-lease を使用してください。" >&2
  exit 2
fi

# D004: git reset --hard / git checkout -- . / git restore . / git clean -f
if has_git_subcmd "$COMMAND" "reset" && echo "$COMMAND" | grep -q '\-\-hard'; then
  echo "❌ 破壊的操作が検出されました: git reset --hard。D004 違反です。git stash を使用してください。" >&2
  exit 2
fi
if has_git_subcmd "$COMMAND" "checkout" && echo "$COMMAND" | grep -qE '\-\-\s+\.'; then
  echo "❌ 破壊的操作が検出されました: git checkout -- .。D004 違反です。" >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+restore\s+\.'; then
  echo "❌ 破壊的操作が検出されました: git restore .。D004 違反です。" >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'git\s+clean\s+-f'; then
  echo "❌ 破壊的操作が検出されました: git clean -f。D004 違反です。git clean -n でドライランを先に実行してください。" >&2
  exit 2
fi

# D005: chmod -R / chown -R on system paths
if echo "$COMMAND" | grep -qE '(chmod|chown)\s+-R\b' && \
   echo "$COMMAND" | grep -qE '\s/(etc|usr|bin|sbin|lib|lib64|var|opt|root|sys|proc|boot|dev|srv|mnt|snap)(/| |$)'; then
  echo "❌ 破壊的操作が検出されました: chmod/chown -R on system path。D005 違反です。" >&2
  exit 2
fi

# D006: kill/killall/pkill/tmux kill-server/tmux kill-session
if echo "$COMMAND" | grep -qE '\b(killall|pkill)\b'; then
  echo "❌ 破壊的操作が検出されました: killall/pkill。D006 違反です。" >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'tmux\s+kill-(server|session)'; then
  echo "❌ 破壊的操作が検出されました: tmux kill-server/kill-session。D006 違反です。" >&2
  exit 2
fi

# D007: mkfs/dd if=/fdisk
if echo "$COMMAND" | grep -qE '\b(mkfs|fdisk)\b'; then
  echo "❌ 破壊的操作が検出されました: mkfs/fdisk。D007 違反です。" >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE 'dd\s+if='; then
  echo "❌ 破壊的操作が検出されました: dd if=。D007 違反です。" >&2
  exit 2
fi

# D008: pipe-to-shell patterns
if echo "$COMMAND" | grep -qE '(curl|wget)\s+.*\|\s*(bash|sh)'; then
  echo "❌ 破壊的操作が検出されました: curl/wget|bash|sh パターン。D008 違反です。" >&2
  exit 2
fi

exit 0
