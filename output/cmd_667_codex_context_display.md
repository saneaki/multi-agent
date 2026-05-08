# cmd_667: Codex tmux context残量表示 — 調査+実装

**Task**: `subtask_667_codex_context_display`
**Assignee**: ashigaru3 (Sonnet+T)
**Date**: 2026-05-08 JST
**Parent cmd**: cmd_667

---

## 1. 目的

Codex CLI 起動中の足軽5/6/7 (および家老の Codex 切替時) でも、Claude Code と同等に **context残量を殿が tmux pane 上で視認できる状態** を作る。

### Before

- Claude Code: TUI 内 statusbar に `[model] X% (remain Y%) | in:N out:M` 表示あり
- Codex (gpt-5.5): TUI 内に同等の常時表示なし → 殿は `/context` コマンドで都度確認するしかない
- tmux 外側からは pane border (`@model_name`) に `Codex` と固定表示のみ

### After

- tmux pane border (上端) に `ashigaru5 (Codex 47%) ...` 形式で **active session の使用率** を動的表示
- status-interval (15秒) ごとに自動更新
- idle session / Claude pane は従来通り `(Codex)` / `(Sonnet+T)` 表示（差分なし）

---

## 2. 調査結果 (AC A-1)

### 2.1 Codex CLI 0.128.0 / 0.129.0 標準機能

`codex --help`、`codex debug --help`、`codex features --help` を確認:

| Sub-command | 機能 | context 残量表示 |
|-------------|------|------------------|
| `codex` | TUI 起動 | TUI 内 `/context` コマンドのみ (殿が毎回叩く必要あり) |
| `codex debug models` | モデルカタログ JSON | × |
| `codex features list` | feature flag 状態 | × |
| `codex --no-alt-screen` | inline mode | TUI 内 `/context` のみ |

**結論**: Codex CLI 0.128.0 にも 0.129.0 にも、Claude Code 相当の **常時表示型 statusbar** は無い。0.129.0 のリリースノートを当方で確認した範囲でも追加なし。

### 2.2 セッションログ調査 (突破口)

`~/.codex/sessions/YYYY/MM/DD/rollout-{ISO}-{uuid}.jsonl` に **token_count イベント** が記録されている:

```json
{
  "timestamp": "2026-05-08T00:24:02.037Z",
  "type": "event_msg",
  "payload": {
    "type": "token_count",
    "info": {
      "last_token_usage": {
        "input_tokens": 121007,
        "cached_input_tokens": 118656,
        "output_tokens": 263,
        "reasoning_output_tokens": 97,
        "total_tokens": 121270
      },
      "total_token_usage": {...},
      "model_context_window": 258400
    }
  }
}
```

→ `last_token_usage.input_tokens / model_context_window` で **使用率を逆算可能**。

### 2.3 codex プロセス → rollout file の対応付け

複数 codex 同時起動 (karo / ash5 / ash6 / ash7) で誤判定なく対応付ける方法を検討:

| 候補 | 結果 |
|------|------|
| (a) ファイル名 ISO timestamp と codex プロセス開始時刻のマッチング | × — 複数プロセスが同一秒帯で起動した場合に区別できない |
| (b) codex プロセス環境変数の session_id | × — `gpt-5.5` codex の env には session 情報なし |
| (c) **`/proc/{codex_pid}/fd/` で open file descriptor を直接確認** | ◎ — codex バイナリが書き込み中の rollout を 100% 確実に取得 |

→ **(c) を採用**。

---

## 3. 実装 (AC A-2, A-3, A-4)

### 3.1 新規ファイル: `scripts/codex_context.sh`

**役割**: agent_id を引数に取り、Codex pane なら ` 47%` (先頭空白付き) を返す。Codex 以外 / idle / エラー時は空文字。

**処理フロー**:
1. `tmux list-panes` で agent_id → pane / `@agent_cli` / `pane_pid` を逆引き
2. `@agent_cli != codex` なら exit 0 (空文字)
3. `pgrep -P pane_pid -f codex` で codex プロセス取得
4. codex プロセス + 子孫の `/proc/{pid}/fd/` を再帰スキャン → open `rollout-*.jsonl` を 1 件取得
5. python3 で末尾 256KB を読み、最後の `"type":"token_count"` イベントから:
   - `last_token_usage.input_tokens` ÷ `model_context_window` × 100 を四捨五入
6. ` 47%` 形式で stdout 出力

**実行時間**: 0.16 秒 (測定値、status-interval 15s に対し十分)

### 3.2 改修: `shutsujin_departure.sh` (line 701-706)

```bash
# pane-border-format でモデル名を常時表示
# Codex pane では context 残量を末尾に動的表示 (cmd_667)
#   例: "ashigaru5 (Codex 47%)" — codex_context.sh が active session の使用率を返す
#   idle / claude pane では空文字を返すので従来表示 ("ashigaru5 (Codex)" / "(Sonnet+T)") を維持
tmux set-option -t multiagent -w pane-border-status top
tmux set-option -t multiagent -w pane-border-format \
  '#{?pane_active,#[reverse],}#[bold]#{@agent_id}#[default] (#{@model_name}#(/home/ubuntu/shogun/scripts/codex_context.sh #{@agent_id})) #{@current_task}'
```

**ポイント**:
- `#()` は tmux の **shell command 評価** で `status-interval` (15s) ごとに更新
- Codex pane の場合のみ `#()` が ` 47%` を返し `(Codex 47%)` 形式に
- 他 pane では空文字 → 従来表示 `(Codex)` / `(Sonnet+T)` 維持 (副作用なし)

### 3.3 既存 multiagent セッションへの即時反映

```bash
tmux set-option -t multiagent -w pane-border-format \
  '#{?pane_active,#[reverse],}#[bold]#{@agent_id}#[default] (#{@model_name}#(/home/ubuntu/shogun/scripts/codex_context.sh #{@agent_id})) #{@current_task}'
```

→ 反映済み (`tmux show-options -t multiagent -w | grep pane-border-format` で確認)。

### 3.4 `.gitignore` whitelist

`scripts/codex_context.sh` がトップレベル `*` ignore に巻き込まれないよう whitelist 追加:

```diff
+ !scripts/codex_context.sh
```

(line 122 — `!scripts/context_snapshot.sh` の直後)

### 3.5 編集経路の整理 (AC A-4 への回答)

| ファイル | 変更点 |
|----------|--------|
| `scripts/codex_context.sh` | **新規** (helper script) |
| `shutsujin_departure.sh` | line 701-706: pane-border-format に `#()` 追加 |
| `.gitignore` | line 122 後: `!scripts/codex_context.sh` 追加 |

**未編集** (敢えて変更しない):
- `lib/cli_adapter.sh` — モデル表示名解決は影響範囲外
- `scripts/switch_cli.sh` — `@model_name` の固定表示は維持 (動的部分は `#()` 経路で別途追加)
- `scripts/shp.sh` — model 番号切替は影響範囲外

---

## 4. Smoke test 結果 (AC B-1)

### 4.1 helper script の単体動作

```bash
$ bash /home/ubuntu/shogun/scripts/codex_context.sh karo
 47%

$ bash /home/ubuntu/shogun/scripts/codex_context.sh ashigaru5
                       # idle codex (rollout 未開) → 空文字

$ bash /home/ubuntu/shogun/scripts/codex_context.sh ashigaru3
                       # claude pane → 空文字

$ bash /home/ubuntu/shogun/scripts/codex_context.sh xxxx
                       # 不正 agent_id → 空文字

$ time bash /home/ubuntu/shogun/scripts/codex_context.sh karo
 47%
real    0m0.160s
```

| 条件 | 期待 | 結果 |
|------|------|------|
| Codex active session (karo) | ` X%` | ` 47%` ✓ |
| Codex idle session (ash5/6/7) | 空文字 | 空文字 ✓ |
| Claude pane (ash1-4 / gunshi) | 空文字 | 空文字 ✓ |
| 不正 agent_id | 空文字 | 空文字 ✓ |
| 引数なし | 空文字 | 空文字 ✓ |
| 実行時間 | < 1秒 | 0.16秒 ✓ |

### 4.2 複数 codex 識別の検証

調査時点で 4 codex プロセスが起動 (karo / ash5 / ash6 / ash7):

```
karo:      pid=4163867 → /home/ubuntu/.codex/sessions/2026/05/08/rollout-2026-05-08T00-08-12-019e04e9-...jsonl (open)
ash5:      pid=4167393 → (no rollout open, idle)
ash6:      pid=4167788 → (no rollout open, idle)
ash7:      pid=4168299 → (no rollout open, idle)
```

`/proc/{pid}/fd/` 直接スキャン方式により、karo のみが正しく rollout を取得 → ash5/6/7 は idle として空文字。**誤判定ゼロ**。

### 4.3 tmux pane-border-format の反映確認

```
$ tmux show-options -t multiagent -w | grep pane-border-format
pane-border-format "...{@model_name}#(/home/ubuntu/shogun/scripts/codex_context.sh #{@agent_id})..."
```

→ 設定反映済み。

---

## 5. 既知の限界 (Honest disclosure)

### 5.1 `tmux display-message` 経由での即時確認は不可

tmux 3.4 の仕様により `#(shell-command)` は **status-line / pane-border-format の描画時のみ評価** され、`display-message -p` では空文字を返す:

```bash
$ tmux display-message -p '[#(echo hello)]'
[]                       # 空 (描画系でないため未評価)
```

→ **当方からは pane border の実描画を確認できない**。殿が tmux 画面で `(Codex 47%)` 表示を視認する必要あり。

### 5.2 idle codex は context 0% ではなく "表示なし"

Codex は会話開始 (最初のtoken使用) まで rollout file を作らない仕様。ash5/6/7 が cmd 受領前は `(Codex)` のまま (= context 未消費の状態)。タスク発令後に表示が現れるはず。

### 5.3 `#()` の評価間隔と CPU負荷

- `#()` は **status-interval (15秒) ごと**に評価
- 1 pane あたり実行時間 0.16秒 × 9 pane = 約 1.4秒/15秒間隔 → CPU負荷は無視可能
- ただし **頻繁な `tmux refresh-client` で評価頻度が上がる** 可能性あり (実用上は無視可)

### 5.4 AC C-1: 既存 Claude Code 起動経路への影響

- pane-border-format 末尾に `#()` を追加しただけ → Claude Code (cli=claude) では `#()` が空文字を返し、表示は **完全に従来通り**
- `lib/cli_adapter.sh` / `scripts/switch_cli.sh` / `scripts/shp.sh` は未変更 → CLI 起動経路に影響なし
- Claude Code TUI 内 statusbar は元々 Claude 側の機能で別系統

→ **既存 Claude Code 経路は破壊なし** (AC C-1 達成)。

---

## 6. 運用ガイダンス

### 6.1 殿による画面確認手順

1. tmux multiagent セッションを表示 (例: `attach-session -t multiagent`)
2. `agents` window を開く
3. 各 pane 上端の border を確認:
   - `karo (Codex 47%) ...` ← active codex なら % が表示される
   - `ashigaru5 (Codex) ...` ← idle codex なら従来通り
   - `ashigaru1 (Sonnet+T) ...` ← claude pane は変化なし
4. status-interval (15秒) 単位で更新

### 6.2 動作しない場合の調査

- `bash scripts/codex_context.sh karo` を直接実行して値が返るか
- `tmux show-options -t multiagent -w | grep pane-border` で format 設定確認
- `/proc/{codex_pid}/fd/` で open rollout を確認 (`ls -l /proc/{pid}/fd/ | grep rollout`)
- もし `#()` が動作しない tmux 版がある場合、**daemon 方式**にfallback (`@model_name` を直接更新する script を 30秒ごとに呼ぶ systemd user timer) — 未実装、必要時に追加実装

### 6.3 想定される拡張

- (将来) gpt-5.5 以外のモデル (Spark / Codex5.3) の context_window を取得 → 同じ仕組みで対応可能
- (将来) Claude Code pane でも tmux border に `[Opus 4.7] X%` を表示する場合は、Claude Code の statusbar から JSON 出力する経路が必要 (別 cmd)

---

## 7. AC 確認

| AC | 要求 | 状態 |
|----|------|------|
| A-1 | Codex CLI 0.128/0.129 標準機能調査 | ✓ 標準機能なし、JSONL session log 経由で実現可能と判定 |
| A-2 | wrapper / pane title / status line / monitor の比較・最小改修案選定 | ✓ pane-border-format `#()` + helper script を選定 |
| A-3 | ash5/ash6/ash7 で残量または代替メトリクス表示 | ✓ active session で % 表示、idle は従来通り |
| A-4 | 反映経路の明記 | ✓ §3.5 の表参照 |
| B-1 | smoke test 結果記録 | ✓ §4 参照 |
| C-1 | Claude Code 起動経路を壊さない | ✓ §5.4 参照 |

---

## 8. 完了報告

- 成果物: `scripts/codex_context.sh` (新規), `shutsujin_departure.sh` (更新), `.gitignore` (whitelist追加)
- 状態: 実装完了 + smoke test PASS
- 残課題: 殿による pane border 実画面確認 (§5.1 の制約により当方未確認)
- 次のステップ: karo に task_completed 報告 → gunshi QC へ dispatch (karo判断)
