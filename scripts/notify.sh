#!/usr/bin/env bash
# ============================================================
# notify.sh — backend-neutral notification wrapper (cmd_658 Phase 0)
#
# 旧 ntfy.sh 互換の引数で呼び出し、NOTIFY_BACKEND に応じて
# Discord (default) または ntfy (fallback) にディスパッチする。
#
# Usage (ntfy.sh と完全互換):
#   bash scripts/notify.sh "<body>" ["<title>"] ["<extra_tags_or_type>"]
#
# 環境変数 / config/discord.env:
#   NOTIFY_BACKEND  : discord (default) | ntfy
#
# 互換性:
#   - 旧 `bash scripts/ntfy.sh "body" "title" "tags"` は
#     `bash scripts/notify.sh "body" "title" "tags"` で同じ動作。
#   - NOTIFY_BACKEND=ntfy で旧経路にフォールバック (Phase 1 dual-stack)。
#
# Exit codes:
#   0 = success / best-effort 完了
#   1 = configuration error
#   その他 = backend 由来 (best-effort のため上位は通常無視で良い)
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCORD_ENV="$SCRIPT_DIR/config/discord.env"

# 1. discord.env を source (存在すれば)
if [ -f "$DISCORD_ENV" ]; then
    # shellcheck disable=SC1090
    set -a
    source "$DISCORD_ENV"
    set +a
fi

# 2. backend 決定: 環境変数 > discord.env > default(discord)
BACKEND="${NOTIFY_BACKEND:-discord}"

# 3. 引数: ntfy.sh と完全互換
BODY="${1:-}"
TITLE="${2:-}"
EXTRA="${3:-}"

if [ -z "$BODY" ]; then
    echo "[notify.sh] ERROR: body (\$1) is required" >&2
    exit 1
fi

case "$BACKEND" in
    discord)
        # Discord backend
        if ! command -v python3 >/dev/null 2>&1; then
            echo "[notify.sh] WARN: python3 not found — fallback to ntfy" >&2
            BACKEND=ntfy
        else
            python3 "$SCRIPT_DIR/scripts/discord_notify.py" \
                --body "$BODY" \
                --title "$TITLE" \
                --type "$EXTRA"
            exit $?
        fi
        ;;
esac

case "$BACKEND" in
    ntfy)
        # Legacy ntfy fallback
        if [ ! -f "$SCRIPT_DIR/scripts/ntfy.sh" ]; then
            echo "[notify.sh] ERROR: ntfy.sh not found and discord backend disabled" >&2
            exit 1
        fi
        bash "$SCRIPT_DIR/scripts/ntfy.sh" "$BODY" "$TITLE" "$EXTRA"
        exit $?
        ;;
    *)
        echo "[notify.sh] ERROR: unknown NOTIFY_BACKEND=$BACKEND (expected: discord|ntfy)" >&2
        exit 1
        ;;
esac
