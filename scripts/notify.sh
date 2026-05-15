#!/usr/bin/env bash
# ============================================================
# notify.sh — Discord notification wrapper (cmd_658 Phase 3)
#
# 旧 ntfy.sh 互換の引数(body/title/type)で呼び出し、
# Discord backend にディスパッチする。
#
# Usage (ntfy.sh と完全互換):
#   bash scripts/notify.sh "<body>" ["<title>"] ["<extra_tags_or_type>"]
#
# 環境変数 / config/discord.env:
#   NOTIFY_BACKEND  : discord (default)
#   NOTIFY_CHUNKED  : 1/true/yes で長文を Part N/M に分割送信
#
# 互換性:
#   - 旧 `bash scripts/ntfy.sh "body" "title" "tags"` 呼出元は
#     `bash scripts/notify.sh "body" "title" "tags"` へ置換済み。
#   - NOTIFY_BACKEND=ntfy は Phase 3 で廃止。設定されていれば
#     構成エラーとして exit 1 する。
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
        if ! command -v python3 >/dev/null 2>&1; then
            echo "[notify.sh] ERROR: python3 not found; Discord backend cannot run" >&2
            exit 1
        fi
        DISCORD_ARGS=(
            --body "$BODY"
            --title "$TITLE"
            --type "$EXTRA"
        )
        case "${NOTIFY_CHUNKED:-}" in
            1|true|TRUE|yes|YES)
                DISCORD_ARGS+=(--chunked)
                ;;
        esac
        python3 "$SCRIPT_DIR/scripts/discord_notify.py" \
            "${DISCORD_ARGS[@]}"
        exit $?
        ;;
    ntfy)
        echo "[notify.sh] ERROR: NOTIFY_BACKEND=ntfy was retired in cmd_692; use NOTIFY_BACKEND=discord" >&2
        exit 1
        ;;
    *)
        echo "[notify.sh] ERROR: unknown NOTIFY_BACKEND=$BACKEND (expected: discord)" >&2
        exit 1
        ;;
esac
