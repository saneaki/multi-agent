#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# cmd_complete_notifier.sh — dashboard.md 変更検知 → Discord自動通知
#
# 概要:
#   dashboard.md の「本日の戦果」セクションの🏆🏆完了行を監視し、
#   新しく追加された cmd 完了時に殿へ Discord 通知を送る。
#
# 動作:
#   - inotifywait で dashboard.md を常時監視
#   - 変更検知時: 🏆🏆マーカーを含む完了行のみ抽出（セマンティックゲート）
#   - 未通知 cmd ID を state file（logs/discord_completed_cmds.txt）で管理
#   - 未通知のものだけ Discord 送信（重複防止）
#
# 🏆🏆セマンティックゲート設計 (cmd_538 Fix A):
#   dashboard.mdには2種類の🏆行が書かれる:
#     1) 軍師QC PASS行: 「🏆cmd_NNN subtask_xxx PASS」（🏆単体） — subtask完了時点
#     2) 家老🏆🏆完了行: 「🏆🏆cmd_NNN COMPLETE」（🏆🏆二重） — 全完了判定後
#   notifierは🏆🏆を含む行のみをトリガーにすることで、
#   subtask単体PASS時の早期通知を防止する。
#   🏆🏆は家老がStep 11.7で書く = 全Phase QC PASS確認+cmd完了判定後。
#
# 起動: watcher_supervisor.sh から nohup で起動される
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PIDFILE="/home/ubuntu/shogun/logs/cmd_complete_notifier.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (PID $(cat "$PIDFILE")). Exiting." >&2
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

DASHBOARD="$SCRIPT_DIR/dashboard.md"
YAML_DASHBOARD="$SCRIPT_DIR/dashboard.yaml"
STATE_FILE="$SCRIPT_DIR/logs/discord_completed_cmds.txt"
GUNSHI_QC_STATE="$SCRIPT_DIR/logs/gunshi_qc_dispatched_cmds.txt"
LOG_FILE="$SCRIPT_DIR/logs/cmd_complete_notifier.log"

# state file 初期化
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"
touch "$GUNSHI_QC_STATE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# dashboard.yaml から cmd完遂+ends完了を検出し、未dispatchなら家老へ通知
dispatch_gunshi_qc_if_needed() {
    if [ ! -f "$YAML_DASHBOARD" ]; then
        return 0
    fi

    SCRIPT_DIR="$SCRIPT_DIR" python3 - <<'PYEOF'
import os
import re
import subprocess
import sys

import yaml

script_dir = os.environ["SCRIPT_DIR"]
dashboard_yaml = os.path.join(script_dir, "dashboard.yaml")
state_file = os.path.join(script_dir, "logs/gunshi_qc_dispatched_cmds.txt")
gunshi_task_file = os.path.join(script_dir, "queue/tasks/gunshi.yaml")
inbox_script = os.path.join(script_dir, "scripts/inbox_write.sh")

try:
    with open(dashboard_yaml, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f"[gunshi_dispatch] dashboard.yaml load failed: {e}", file=sys.stderr)
    sys.exit(0)

dispatched = set()
if os.path.exists(state_file):
    with open(state_file, encoding="utf-8") as f:
        dispatched = {line.strip() for line in f if line.strip()}

today_items = data.get("achievements", {}).get("today", [])
if not isinstance(today_items, list):
    today_items = []

for item in today_items:
    if not isinstance(item, dict):
        continue
    result = str(item.get("result", ""))
    task_text = str(item.get("task", ""))

    if "ends完了" not in result:
        continue
    m = re.search(r"(cmd_\d+)完遂", task_text)
    if not m:
        continue
    cmd_id = m.group(1)

    if cmd_id in dispatched:
        print(f"[gunshi_dispatch] {cmd_id}: already dispatched, skip", file=sys.stderr)
        continue

    gunshi_active = False
    if os.path.exists(gunshi_task_file):
        try:
            with open(gunshi_task_file, encoding="utf-8") as f:
                gunshi_task = yaml.safe_load(f) or {}
            if (
                gunshi_task.get("parent_cmd") == cmd_id
                and gunshi_task.get("status") in ("assigned", "in_progress")
            ):
                gunshi_active = True
        except Exception as e:
            print(f"[gunshi_dispatch] gunshi task read failed: {e}", file=sys.stderr)

    if gunshi_active:
        print(f"[gunshi_dispatch] {cmd_id}: gunshi already active, skip", file=sys.stderr)
        with open(state_file, "a", encoding="utf-8") as f:
            f.write(cmd_id + "\n")
        dispatched.add(cmd_id)
        continue

    msg = (
        f"{cmd_id} 完遂検知 (dashboard.yaml: ends完了)。"
        "gunshi QC dispatch 要否を確認し、未dispatchなら発令せよ (cmd_598 自動トリガー)。"
    )
    subprocess.run(
        ["bash", inbox_script, "karo", msg, "cmd_complete_qc_trigger", "cmd_complete_notifier"],
        check=False,
    )
    with open(state_file, "a", encoding="utf-8") as f:
        f.write(cmd_id + "\n")
    dispatched.add(cmd_id)
    print(f"[gunshi_dispatch] dispatched to karo: {cmd_id}", file=sys.stderr)
PYEOF
}

# dashboard.md から完了行を抽出し、未通知 cmd を Discord 送信
check_and_notify() {
    if [ ! -f "$DASHBOARD" ]; then
        return 0
    fi

    # 完了行パターン: | HH:MM | ... 🏆🏆cmd_NNN COMPLETE ... | ... ✅ ... |
    # 🏆🏆フィルタ: subtask PASS行(🏆単体)を除外し、家老🏆🏆COMPLETE行のみトリガー
    while IFS= read -r line; do
        # cmd番号を抽出(🏆🏆直後の cmd_NNN のみ厳密抽出、description 内の cmd 参照を誤抽出しない)
        cmd_id=$(echo "$line" | grep -oP '🏆🏆cmd_\d+' | head -1 | sed 's/🏆🏆//' || true)
        if [ -z "$cmd_id" ]; then
            continue
        fi

        # 既に通知済みか確認
        if grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            continue
        fi

        # 完了概要を抽出（3列目: cmd_NNN以降のテキスト）
        summary=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/✅.*//' | sed 's/^ *//; s/ *$//')
        summary="${summary:0:60}"

        # 通知送信 (Discord)
        log "Sending notify for $cmd_id: $summary"
        if bash "$SCRIPT_DIR/scripts/notify.sh" "✅ ${cmd_id} 完了 — ${summary}" "家老より" "cmd_complete" >> "$LOG_FILE" 2>&1; then
            echo "$cmd_id" >> "$STATE_FILE"
            log "notify sent: $cmd_id"
        else
            log "notify FAILED for $cmd_id"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep -P '🏆🏆cmd_\d+' || true)

    # cmd_598: dashboard.yaml SoT から gunshi QC dispatch トリガー
    dispatch_gunshi_qc_if_needed
}

log "cmd_complete_notifier started (🏆🏆 trigger). Watching: $DASHBOARD"

# 起動時に既存の完了行を state file に記録（起動直後の大量通知を防止）
if [ -f "$DASHBOARD" ]; then
    while IFS= read -r line; do
        cmd_id=$(echo "$line" | grep -oP '🏆🏆cmd_\d+' | head -1 | sed 's/🏆🏆//' || true)
        if [ -n "$cmd_id" ] && ! grep -qxF "$cmd_id" "$STATE_FILE" 2>/dev/null; then
            echo "$cmd_id" >> "$STATE_FILE"
        fi
    done < <(grep -P '^\| \d\d:\d\d \|' "$DASHBOARD" | grep -P '🏆🏆cmd_\d+' || true)
    log "Initial state loaded: $(wc -l < "$STATE_FILE") cmd IDs registered"
fi

# inotifywait チェック
if ! command -v inotifywait &>/dev/null; then
    log "ERROR: inotifywait not found. Cannot watch dashboard.md"
    exit 1
fi

# メインループ: dashboard.md を監視
while true; do
    # タイムアウト付きで変更を待つ（Fallback: 60秒ごとにポーリング）
    if inotifywait -q -t 60 -e modify,close_write,moved_to "$DASHBOARD" >> "$LOG_FILE" 2>&1; then
        log "dashboard.md changed, checking for new completions"
        check_and_notify
    else
        # タイムアウト（rc=2）またはエラー（rc=1）: ポーリングとして check
        check_and_notify
    fi
done
