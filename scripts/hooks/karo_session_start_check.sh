#!/usr/bin/env bash
# karo_session_start_check.sh
# 家老専用SessionStart環境確認hook
# $TMUX_PANE未設定（VSCode環境）では何もしない
# agent_id=karoの場合のみ委譲経路・禁止事項を通知する

set -euo pipefail

if [ -z "${TMUX_PANE:-}" ]; then
    exit 0
fi

AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")

if [ "$AGENT_ID" != "karo" ]; then
    exit 0
fi

echo "⚠️ 家老環境確認: tmux pane=$TMUX_PANE, agent_id=karo。"
echo "   足軽1〜7号(multiagent:0.1〜0.7)への委譲経路は有効。"
echo "   Agent()による成果物生成は禁止（F003）。足軽に委譲せよ。"
echo "   Session Start Step 1完了。"
exit 0
