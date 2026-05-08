#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# codex_context.sh v2 — Codex pane の context残量(%)を返す
#
# Usage:
#   bash scripts/codex_context.sh <agent_id>
#
# Output (stdout):
#   " 47%"       — Codex pane でアクティブ session の場合
#   ""           — Codex 以外 / idle / エラー
#
# Design (cmd_671 — v2 SQLite+logs based):
#   1. agent_id → tmux pane 逆引き
#   2. @agent_cli == codex 確認 (それ以外は空文字)
#   3. pane_pid → node PID → native Codex binary PID
#   4. logs_2.sqlite: process_uuid (pid:{native_pid}:...) → thread_id
#   5. state_5.sqlite: thread_id → rollout_path (存在確認)
#   6. rollout ファイルから token_count イベントを読んで % 計算
#   7. (fallback) logs で不明の場合: 起動時刻 + state_5.sqlite でヒューリスティック照合
#
# v1 (cmd_667) からの変更点:
#   /proc/{pid}/fd/ スキャンを廃止 — Codex 0.129.0 は rollout file を
#   書込みごとに open/write/close するため fd に残らない (A-1 実証済み)
#   logs_2.sqlite の process_uuid 'pid:{native_pid}:...' → thread_id を
#   state_5.sqlite threads テーブルで照合する確実な方式に変更
#
# Note:
#   - tmux pane-border-format の #() に埋め込み、status-interval (15s) で自動更新
#   - state_5.sqlite / logs_2.sqlite は WAL モード → 複数リーダー安全
#   - 失敗時は静かに空文字を返し、表示を壊さない
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

AGENT_ID="${1:-}"
CODEX_LOGS_DB="${HOME}/.codex/logs_2.sqlite"
CODEX_STATE_DB="${HOME}/.codex/state_5.sqlite"
SHOGUN_DIR="/home/ubuntu/shogun"

[[ -z "$AGENT_ID" ]] && exit 0

command -v tmux >/dev/null 2>&1 || exit 0

# tmux pane を agent_id で逆引き
PANE_LINE=$(tmux list-panes -a -F '#{@agent_id} #{@agent_cli} #{pane_pid}' 2>/dev/null \
    | awk -v a="$AGENT_ID" '$1 == a {print; exit}')

[[ -z "$PANE_LINE" ]] && exit 0

CLI=$(echo "$PANE_LINE" | awk '{print $2}')
PANE_PID=$(echo "$PANE_LINE" | awk '{print $3}')

[[ "$CLI" != "codex" ]] && exit 0
[[ -z "$PANE_PID" ]] && exit 0

# pane_pid → node codex PID → native Codex binary PID
CODEX_NODE_PID=$(pgrep -P "$PANE_PID" -f 'codex' 2>/dev/null | head -1)
[[ -z "$CODEX_NODE_PID" ]] && exit 0

CODEX_NATIVE_PID=$(pgrep -P "$CODEX_NODE_PID" 2>/dev/null | head -1)
[[ -z "$CODEX_NATIVE_PID" ]] && CODEX_NATIVE_PID="$CODEX_NODE_PID"

# プロセス開始時刻 (epoch秒) を計算 (fallback用)
_boottime=$(awk '/btime/{print $2}' /proc/stat 2>/dev/null)
_hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
_starttime=$(awk '{print $22}' "/proc/$CODEX_NODE_PID/stat" 2>/dev/null)
PROC_START_S=0
if [[ -n "$_starttime" && -n "$_boottime" ]]; then
    PROC_START_S=$(( _boottime + _starttime/_hz ))
fi

PYTHON_BIN="${SHOGUN_DIR}/.venv/bin/python3"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN="python3"

"$PYTHON_BIN" - "$CODEX_NATIVE_PID" "$CODEX_NODE_PID" "$PROC_START_S" \
               "$CODEX_LOGS_DB" "$CODEX_STATE_DB" "$SHOGUN_DIR" <<'PYEOF' 2>/dev/null
import os
import sys
import json
import sqlite3

native_pid    = int(sys.argv[1])
node_pid      = int(sys.argv[2])
proc_start_s  = int(sys.argv[3])
logs_db       = sys.argv[4]
state_db      = sys.argv[5]
cwd           = sys.argv[6]

FALLBACK_WINDOW_NEW_S  = 60    # 起動後 60 秒以内の新規スレッド
FALLBACK_LOOK_BEHIND_S = 2     # clock jitter 許容


def open_db(path, timeout=2.0):
    uri = f"file:{path}?mode=ro"
    return sqlite3.connect(uri, uri=True, timeout=timeout)


def find_rollout_via_logs(native_pid, logs_db, state_db):
    """logs_2.sqlite → state_5.sqlite 経由で rollout_path を取得する (主要パス)。"""
    try:
        logs_conn  = open_db(logs_db)
        state_conn = open_db(state_db)
        logs_cur   = logs_conn.cursor()
        state_cur  = state_conn.cursor()

        # native PID に対応する process_uuid のスレッドを取得 (最新優先)
        logs_cur.execute(
            """
            SELECT thread_id, MAX(ts) AS last_ts
            FROM logs
            WHERE process_uuid LIKE ?
              AND thread_id IS NOT NULL
            GROUP BY thread_id
            ORDER BY last_ts DESC
            LIMIT 20
            """,
            (f"pid:{native_pid}:%",),
        )

        for thread_id, _ in logs_cur.fetchall():
            state_cur.execute(
                "SELECT rollout_path FROM threads WHERE id = ?",
                (thread_id,),
            )
            row = state_cur.fetchone()
            if row and row[0]:
                return row[0]
        return None
    except Exception:
        return None
    finally:
        try:
            logs_conn.close()
            state_conn.close()
        except Exception:
            pass


def find_rollout_via_time(proc_start_s, state_db, cwd):
    """プロセス起動時刻ベースで rollout_path を推定する (fallback)。"""
    if proc_start_s <= 0:
        return None
    proc_start_ms = proc_start_s * 1000
    try:
        conn = open_db(state_db)
        cur  = conn.cursor()

        # Strategy A: 起動後 60 秒以内に作成された新規スレッド
        cur.execute(
            """
            SELECT rollout_path FROM threads
            WHERE cwd = ?
              AND created_at_ms BETWEEN ? AND ?
            ORDER BY created_at_ms ASC
            LIMIT 1
            """,
            (cwd,
             proc_start_ms - FALLBACK_LOOK_BEHIND_S * 1000,
             proc_start_ms + FALLBACK_WINDOW_NEW_S * 1000),
        )
        row = cur.fetchone()
        if row and row[0]:
            return row[0]

        # Strategy B: 起動前に作成 + 起動後に更新 (resumed session)
        cur.execute(
            """
            SELECT rollout_path FROM threads
            WHERE cwd = ?
              AND created_at_ms < ?
              AND updated_at_ms > ?
            ORDER BY updated_at_ms DESC
            LIMIT 1
            """,
            (cwd, proc_start_ms, proc_start_ms),
        )
        row = cur.fetchone()
        if row and row[0]:
            return row[0]

        return None
    except Exception:
        return None
    finally:
        try:
            conn.close()
        except Exception:
            pass


def read_token_pct(rollout):
    """rollout ファイルから最新の token_count を読み % を返す。"""
    if not rollout or not os.path.isfile(rollout):
        return None

    file_size = os.path.getsize(rollout)
    if file_size == 0:
        return None

    chunk = 256 * 1024
    try:
        with open(rollout, "rb") as fh:
            if file_size > chunk:
                fh.seek(file_size - chunk, 0)
                fh.readline()
            data = fh.read().decode("utf-8", errors="ignore")
    except OSError:
        return None

    last_event = None
    for line in data.splitlines():
        if '"type":"token_count"' in line:
            last_event = line

    if not last_event:
        return None

    try:
        obj  = json.loads(last_event)
        info = obj["payload"]["info"]
        last = info.get("last_token_usage") or info.get("total_token_usage", {})
        used = last.get("input_tokens", 0)
        win  = info.get("model_context_window", 0)
        if win <= 0 or used < 0:
            return None
        pct = round(used / win * 100)
        return min(pct, 999)
    except Exception:
        return None


# 主要パス: logs → state_5
rollout = find_rollout_via_logs(native_pid, logs_db, state_db)

# fallback: 起動時刻ヒューリスティック
if not rollout:
    rollout = find_rollout_via_time(proc_start_s, state_db, cwd)

pct = read_token_pct(rollout)
if pct is not None:
    print(f" {pct}%")
PYEOF
