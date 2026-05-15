---
name: shogun-tmux-busy-aware-send-keys
description: >
  [English] Use when sending keystrokes to a tmux pane running Claude Code (or any interactive
  agent) and you must wait for the agent to be idle before pressing Enter. Covers
  `wait_until_idle()` polling pattern (0.5s interval, configurable timeout), pane sanity check,
  stale pane auto-redetection, and WARN+fallback on timeout. Solves A-3 race condition where
  Enter is sent while the agent is still streaming output.
  [日本語] tmux pane 上の Claude Code (or interactive agent) に send-keys で Enter を送る前に、
  agent が idle になるまで待機する必要がある場合に使用。wait_until_idle() polling
  (0.5s interval、timeout 設定可) / pane 整合チェック / stale pane 自動再検出 / timeout 時 WARN
  + fallback を実装。Enter 送信時に agent がまだ stream 中という A-3 race condition を解消。
tags: [tmux, send-keys, claude-code, race-condition, idle-detection, agent-coordination]
---

# tmux Busy-Aware send-keys Pattern

tmux pane の Claude Code agent に send-keys + Enter を送る際、agent が **idle** になるまで待機して race condition を解消するパターン。

## When to Use

- 家老 / 将軍 / cmd_complete 通知 script から ash agent に inbox_write 等を促す
- tmux send-keys で複数行を順次送信する時 (前行の処理完了を待つ)
- agent が長い response を stream 中に Enter を送ると **行頭ずれ / 連結 / 入力欠落** が発生

## Skip

- Claude Code の prompt 入力欄が空 (idle) と確実に分かる文脈
- inbox_write.sh (ファイル経由) で済む場合 — そもそも tmux send-keys を使わない方が good

## Problem (A-3 race condition)

```
時刻 T0: agent が response stream 中 (まだ "..." 表示)
時刻 T1: 別 process が tmux send-keys "<msg>" Enter
時刻 T2: agent は stream 終了直後に "<msg>\n" を受領 → buffer に混入
結果: <msg> が agent の前 response に連結 / 行頭ずれ
```

これは **A-3 race condition** と命名された不具合 (cmd_582 で発見)。

## Core Pattern

### 1. wait_until_idle() polling

```bash
wait_until_idle() {
  local pane_id="$1"
  local timeout="${2:-30}"  # default 30s
  local poll_interval=0.5

  local elapsed=0
  while (( elapsed < timeout )); do
    # pane の現在表示内容を取得
    local content
    content=$(tmux capture-pane -t "$pane_id" -p -S -3 2>/dev/null) || return 1

    # idle 判定: prompt 行が表示されている (例: "❯ " or "human: " or "│ > ")
    if echo "$content" | tail -3 | grep -qE '^(❯ |human: |│ > )'; then
      return 0
    fi

    sleep "$poll_interval"
    elapsed=$(echo "$elapsed + $poll_interval" | bc)
  done

  # timeout: WARN + fallback
  echo "WARN: pane $pane_id not idle after ${timeout}s, sending anyway" >&2
  return 0  # fallback: 強制送信
}
```

### 2. pane 整合チェック (stale pane 検出)

```bash
verify_pane() {
  local pane_id="$1"
  local expected_agent_id="$2"

  # tmux pane が存在するか
  tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qx "$pane_id" || {
    echo "ERROR: pane $pane_id not found" >&2
    return 1
  }

  # @agent_id metadata 確認
  local actual_id
  actual_id=$(tmux display-message -t "$pane_id" -p '#{@agent_id}' 2>/dev/null)
  if [[ "$actual_id" != "$expected_agent_id" ]]; then
    echo "WARN: pane $pane_id has @agent_id='$actual_id' (expected '$expected_agent_id')" >&2
    # stale pane: 再検出を試みる
    pane_id=$(tmux list-panes -a -F '#{pane_id}|#{@agent_id}' 2>/dev/null | \
              awk -F'|' -v id="$expected_agent_id" '$2 == id { print $1; exit }')
    if [[ -z "$pane_id" ]]; then
      echo "ERROR: agent '$expected_agent_id' pane not found anywhere" >&2
      return 1
    fi
    echo "Re-detected pane: $pane_id"
  fi

  echo "$pane_id"
  return 0
}
```

### 3. send-keys with idle wait

```bash
safe_send_keys() {
  local agent_id="$1"
  local message="$2"
  local pane_id

  # pane 検証 + 再検出
  pane_id=$(verify_pane "${EXPECTED_PANE_ID:-}" "$agent_id") || return 1

  # idle 待ち
  wait_until_idle "$pane_id" 30

  # send-keys (literal で)
  tmux send-keys -t "$pane_id" -l "$message"
  sleep 0.2
  tmux send-keys -t "$pane_id" Enter
}
```

## Battle-Tested Examples

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_582 | 家老 cmd_complete 通知で ash inbox 更新時に A-3 race condition 発見 | wait_until_idle() + pane 整合チェック + stale pane 再検出 を実装、A-3 race 解消 |
| cmd_605〜cmd_608 | dual-model smoke 連発期の cmd_complete 通知 (1週間で 3 通知以上) | A-3 race 再発ゼロ — battle-tested 観測条件達成 |
| cmd_711 | `inbox_watcher.sh` tmux scroll mode fix で同 pattern 適用 | scroll mode 解除 + busy-aware send-keys で reliability 向上 |
| cmd_725a | `shu`/`shk` 起動 smoke guard で send-keys 経路の整合 | noninteractive startup 経路にも適用可能と確認 |
| cmd_726c | 観察完了で正式 battle-tested 格上げ (本 SKILL.md frontmatter `created` 更新) | shogun-tmux-busy-aware-send-keys を承認待ち → 正式採用化 |

**実証パラメータ**:
- poll interval = 0.5s
- timeout = 30s (configurable)
- battle-tested 観察結果: cmd_582 (2026-04-29) を起点に 1 週間以上の運用観察 + 3 件以上の cmd_complete 通知運用で A-3 race 再発ゼロ確認。cmd_726c で **観察完了** ✅

## Related Skills

- `shogun-claude-code-posttooluse-hook-guard` — Claude Code hook 発火問題 (関連: tmux 連携)
- (注) tmux send-keys 自体は **agent 全員禁止** (CLAUDE.md F-rule)。本 pattern は **inbox_write.sh / cmd_complete 通知 script 等の system level utility** 向け
- `shogun-agent-status` — tmux pane metadata から agent 状態取得 (本 pattern の前提)

## Anti-pattern

- ❌ `sleep 5; tmux send-keys ...` — fixed sleep は agent の処理時間に依存しない、不安定
- ❌ idle 検出なしで send-keys 連発 — buffer 混入、入力欠落
- ❌ tmux pane を ID で hardcode — pane が再生成されたら stale で動作不能 → metadata 経由で再検出

## Source

- cmd_582 (2026-04-29): ash6 (Sonnet+T) が cmd_complete 通知で A-3 race condition 発見・対処
- 観察期間: cmd_582 起点で 1 週間以上、3 件以上の cmd_complete 通知で実測検証 (cmd_605〜cmd_608 dual-model smoke 連発期 / cmd_711 / cmd_725a)
- cmd_726c (2026-05-15): 観察完了で正式 battle-tested 格上げ (γ subtask ashigaru4)
