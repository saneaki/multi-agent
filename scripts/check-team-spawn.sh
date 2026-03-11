#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# check-team-spawn.sh - チームメンバー spawn 制限フック
# ═══════════════════════════════════════════════════════════════════════════════
#
# Claude Code の PreToolUse フックとして動作し、将軍以外のエージェントが
# チームメンバーを追加（Task with team_name）またはチームを作成（TeamCreate）
# することを防ぐ。
#
# 判定ロジック:
#   1. 作業ディレクトリに .shogun/ がない → 将軍システム外なので制限しない（exit 0）
#   2. SHOGUN_ROLE=shogun → 将軍なので全て許可（exit 0）
#   3. Task で team_name あり → ブロック（exit 2）
#   4. TeamCreate → ブロック（exit 2）
#   5. それ以外 → 許可（exit 0）
#
# 設定方法:
#   ~/.claude/settings.json の hooks.PreToolUse に追加:
#   {
#     "matcher": "Task|TeamCreate",
#     "hooks": [{ "type": "command", "command": "~/.claude/hooks/check-team-spawn.sh" }]
#   }
#
# 前提:
#   - 将軍は claude-shogun 経由で起動され、SHOGUN_ROLE=shogun が設定される
#   - チームメイトは tmux split-window で生成され、SHOGUN_ROLE を持たない
#   - 将軍・チームメイトとも同じ作業ディレクトリで動作し、.shogun/ が存在する
#   - 将軍システム外のプロジェクトには .shogun/ がないため制限されない
#   - jq がインストールされていること
#
# ═══════════════════════════════════════════════════════════════════════════════

# stdin からツール入力 JSON を読む
input=$(cat)

# 将軍システム判定: .shogun/ ディレクトリの有無
# .shogun/ は shutsujin_departure.sh が作成するプロジェクト固有データ
# このディレクトリがなければ将軍システム外 → 制限しない
if [ ! -d ".shogun" ]; then
    exit 0
fi

# 将軍は全て許可
if [ "$SHOGUN_ROLE" = "shogun" ]; then
    exit 0
fi

# ツール名を取得
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

case "$tool_name" in
    Task)
        team_name=$(echo "$input" | jq -r '.tool_input.team_name // empty')
        if [ -n "$team_name" ]; then
            echo "[BLOCKED] チームメンバーの追加は将軍のみに許可されている。Task tool のサブエージェント利用（team_name なし）は許可。" >&2
            exit 2
        fi
        ;;
    TeamCreate)
        echo "[BLOCKED] チーム作成は将軍のみに許可されている。" >&2
        exit 2
        ;;
esac

exit 0
