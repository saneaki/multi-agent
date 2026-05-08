---
name: codex-context-pane-border
description: >
  Use when displaying Codex CLI context usage percentage in tmux pane-border-format.
  Codex 0.129.0+ stores session data in SQLite (not /proc/fd/); requires two-step
  lookup via logs_2.sqlite → state_5.sqlite to extract rollout path and token count.
  tmux #() dynamic command embedding + scripts/codex_context.sh implementation pattern.
tags: [codex, tmux, context, sqlite, shogun-ops]
---

# codex-context-pane-border

Codex CLI のコンテキスト使用率を tmux pane border に動的表示するパターン。

## Problem Statement

Codex CLI (0.129.0+) は Claude Code のような常時 statusbar を持たない。
殿が複数 Codex pane のコンテキスト残量を視認するには `/context` を都度打つしかなかった。
tmux の `pane-border-format` に `#()` でスクリプトを埋め込むことで解決できるが、
**Codex 0.129.0 では `/proc/fd/` スキャンが機能しない** ため専用の検出ロジックが必要。

## Root Cause: /proc/fd/ は 0.129.0 では機能しない

```bash
# Codex 0.128.0: rollout file を fd で保持し続ける
# Codex 0.129.0: open → write → close (ターンごとに完結) → fd に残らない
ls /proc/{codex_pid}/fd/  # → 空 (常に失敗)
```

Codex 0.129.0 はセッションデータを SQLite DB に記録する:

| DB | パス | 用途 |
|----|------|------|
| `logs_2.sqlite` | `~/.codex/sessions/logs_2.sqlite` | thread_id ↔ process_uuid 対応 |
| `state_5.sqlite` | `~/.codex/sessions/state_5.sqlite` | thread_id → rollout_path + token_count |

## SQLite 二段階照合方式 (v2 実装)

```text
pane の @agent_cli == codex?
  ↓ YES
  pane PID → pgrep -P → node PID → pgrep -P → native Codex binary PID

  logs_2.sqlite:
    WHERE process_uuid LIKE 'pid:{native_pid}:%'
      AND thread_id IS NOT NULL
    ORDER BY ts DESC
    → thread_id

  state_5.sqlite:
    WHERE id = {thread_id}
    → rollout_path

  rollout_path (jsonl):
    最後の "type":"token_count" イベント
    → last_token_usage.input_tokens / model_context_window × 100 → "XX%"
```

### フォールバック (プロセス起動時刻ヒューリスティック)

logs_2 で一致が見つからない場合:

- **Strategy A**: プロセス起動後 60 秒以内に作成されたスレッド (新規 session)
- **Strategy B**: プロセス起動前に作成 + 起動後に更新されたスレッド (resumed session)
- いずれも不一致 → 空文字 (idle として正常)

## scripts/codex_context.sh 実装要点

```bash
#!/usr/bin/env python3
# scripts/codex_context.sh として bash 経由で呼び出し可
import sys, subprocess, sqlite3, json, os, time

LOGS_DB  = os.path.expanduser("~/.codex/sessions/logs_2.sqlite")
STATE_DB = os.path.expanduser("~/.codex/sessions/state_5.sqlite")

def get_context_pct(agent_id):
    # 1. pane → node → native pid chain
    # 2. logs_2 で process_uuid LIKE 'pid:{pid}:%' → thread_id
    # 3. state_5 で id = thread_id → rollout_path
    # 4. jsonl で最後の token_count → input/window → pct
    ...
    return f" {pct}%"   # 表示形式: " 47%"

if __name__ == "__main__":
    print(get_context_pct(sys.argv[1]))
```

SQLite アクセスは **WAL モード** のため複数リーダー同時アクセスは安全。
`sqlite3` CLI が利用不可の場合は Python `sqlite3` モジュールを使用。

## tmux pane-border-format 設定

```bash
tmux set-option -t multiagent -w pane-border-format \
  "#{?pane_active,#[reverse],}#[bold]#{@agent_id}#[default] (#{@model_name}#(/home/ubuntu/shogun/scripts/codex_context.sh #{@agent_id})) #{@current_task}"
```

`#(...)` は `status-interval` (推奨: 15s) ごとに再実行される。
`tmux display-message -p` では `#()` は評価されない (tmux 3.4 仕様) — 実機 border で視認必須。

## 実機動作確認手順

```bash
# 1. スクリプト単体テスト
bash scripts/codex_context.sh karo
# → " 44%" または "" (idle)

# 2. 30秒以上観察して自動更新確認
watch -n 15 'bash scripts/codex_context.sh karo'

# 3. スクリプト実行時間確認 (15秒間隔に収まるか)
time bash scripts/codex_context.sh karo
# → 0.749s 程度が目安
```

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_667 | ash3 が /proc/fd/ ベースで初回実装 | 0.128.0 では動作、0.129.0 では常に空 |
| cmd_671 | ash5 が SQLite 二段階照合方式に修復 | karo: 44-51% 動的表示確認 (T+31s で 49%→50% 変化確認) |

実測スクリプト実行時間: 0.749s (15秒 status-interval 内で十分)

## Related Skills

- `shogun-tmux-busy-aware-send-keys` — tmux pane 操作 + idle 検出パターン
- `shogun-agent-status` — agent 状態確認スクリプト群
- `codex-cli-poc-verification` — Codex CLI 初期動作確認

## Source

- cmd_667: ash3 による初回実装 (tmux #() + /proc/fd/ 方式)
- cmd_671: ash5 による SQLite 二段階照合修復 (0.129.0 対応完遂版)
