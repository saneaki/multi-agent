# cmd_668: Codex CLI 0.129.0 Upgrade

- **task_id**: subtask_668_codex_0129_upgrade
- **worker_id**: ashigaru4
- **status**: done
- **timestamp**: 2026-05-08T09:25 JST

---

## 1. 目的

Codex CLI を `0.128.0 → 0.129.0` へ升級し、ash5/ash6/ash7 の起動時 update prompt 停止解消の前提条件を整える。

---

## 2. 事前確認 (preflight)

| 項目 | 値 | 備考 |
|------|-----|------|
| 升級前 codex version | `codex-cli 0.128.0` | A-2 satisfied |
| codex 実行パス | `/home/ubuntu/.npm-global/bin/codex` | npm-global 配下 |
| npm prefix (global) | `/home/ubuntu/.npm-global` | sudo 不要 |
| node version | `v20.19.5` | OK |
| npm version | `10.8.2` | OK |
| 0.129 が Codex CLI update か | ✅ 確認済 | A-1 satisfied (家老確認済 + Codex 起動画面の "Update available! 0.128.0 -> 0.129.0" が証跡) |

---

## 3. 実施手順

### Step 3.1: 升級コマンド実行

```bash
npm install -g @openai/codex@0.129.0
```

**結果**: `changed 2 packages in 8s` ✅
- sudo 未使用 (権限 OK)
- curl|bash 未使用 (npm 正式経路)
- A-3 satisfied

### Step 3.2: version 確認

```bash
$ codex --version
codex-cli 0.129.0
```

A-4 satisfied ✅

### Step 3.3: 起動軽量確認 (`--help`)

```bash
$ codex --help
Codex CLI

If no subcommand is specified, options will be forwarded to the interactive CLI.

Usage: codex [OPTIONS] [PROMPT]
       codex [OPTIONS] <COMMAND> [ARGS]

Commands:
  exec         Run Codex non-interactively [aliases: e]
  review       Run a code review non-interactively
  login        Manage login
  logout       Remove stored authentication credentials
  mcp          Manage external MCP servers for Codex
  plugin       Manage Codex plugins
  mcp-server   Start Codex as an MCP server (stdio)
  app-server   [experimental] Run the app server or related tooling
  completion   Generate shell completion scripts
  update       Update Codex to the latest version
  sandbox      Run commands within a Codex-provided sandbox
  debug        Debugging tools
  apply        Apply the latest diff produced by Codex agent as a `git apply` to your local working
               tree [aliases: a]
  resume       Resume a previous interactive session ...
  fork         Fork a previous interactive session ...
  cloud        [EXPERIMENTAL] Browse tasks from Codex Cloud and apply changes locally
  exec-server  [EXPERIMENTAL] Run the standalone exec-server service
  features     Inspect feature flags
  help         Print this message or the help of the given subcommand(s)
```

A-5 satisfied ✅ (subcommand 一覧表示、エラーなし)

---

## 4. acceptance_criteria 充足状況

| ID | check | status | 備考 |
|----|-------|--------|------|
| A-1 | 0.129 が Codex CLI update であることを確認 | ✅ PASS | 家老確認済 + Codex 起動画面メッセージ |
| A-2 | 更新前 (0.128.0) と更新後 (0.129.0) を記録 | ✅ PASS | §2 / §3.2 記載 |
| A-3 | npm install -g @openai/codex@0.129.0 で更新 | ✅ PASS | sudo/curl|bash 未使用 |
| A-4 | codex --version が 0.129.0 を返す | ✅ PASS | §3.2 |
| A-5 | codex --help または dry-run で起動 PASS | ✅ PASS | §3.3 |
| B-1 | 本 md に手順・結果・復旧案を記録 | ✅ PASS | 本ファイル |

---

## 5. ash5/ash6/ash7 update prompt 停止状況の記録

升級時刻 (2026-05-08T09:25 JST) 時点で、以下 3 pane が codex CLI の `Update available!` プロンプトで停止中。

| agent | pane | cli_type | task status | 停止内容 |
|-------|------|----------|-------------|---------|
| ashigaru5 | multiagent:0.5 | codex (gpt-5.5) | done | "Update available! 0.128.0 -> 0.129.0" + 1/2/3 選択待ち |
| ashigaru6 | multiagent:0.6 | codex (gpt-5.5) | done | 同上 (上端見切れだが同一プロンプト) |
| ashigaru7 | multiagent:0.7 | codex (gpt-5.5) | done | 同上 |

**全員 task=done**。アクティブ実行中タスクは無し。停止は受信側 codex CLI が新リリース検出して prompt を出している状態。

### 影響範囲

- 当 3 pane は新規タスク受領しても codex プロンプトを通過するまで処理開始できない
- 家老が次タスクを発令する前に解除が必要

### 推奨復旧案 (家老判断仰ぎ)

3 つの選択肢:

#### 案 A: 各 pane で選択肢「2. Skip」を送出 (現セッション継続)
```bash
for n in 5 6 7; do
  tmux send-keys -t multiagent:0.${n} "2" Enter
done
```
- 利点: 既存 codex セッション (0.128.0 in-memory) を継続できる
- 欠点: 当面 0.129.0 機能を享受できない (次の codex 再起動で 0.129.0 に切替)

#### 案 B: 各 pane で選択肢「1. Update now」を送出 (再 install + 再起動)
```bash
for n in 5 6 7; do
  tmux send-keys -t multiagent:0.${n} "1" Enter
done
```
- 利点: codex セッションが再起動して即座に 0.129.0 化
- 欠点: グローバル package は既に 0.129.0 ゆえ npm install が冗長 (idempotent なので害なし)。codex 再起動でセッション履歴喪失の可能性

#### 案 C: 各 pane を /clear し、agent 経路で再起動
- 利点: 標準フロー (足軽 self_clear_check.sh 同等)
- 欠点: codex CLI は /clear 概念がないため、別途 codex セッション再起動操作が必要

**推奨**: **案 A (Skip)**。
理由:
- 升級効果は次 codex 起動時から享受される (即時性は不要)
- 既存セッション破壊なし
- npm install 重複リスクなし
- 当 3 agent は task=done で idle、急ぎなし

---

## 6. 失敗時復旧案

万一升級後に問題発覚した場合 (本タスクでは発生せず、参考):

### Rollback A: 0.128.0 へダウングレード
```bash
npm install -g @openai/codex@0.128.0
codex --version  # 0.128.0 確認
```

### Rollback B: グローバル削除 + 再 install
```bash
npm uninstall -g @openai/codex
npm install -g @openai/codex@<安定版>
```

### npm cache 不整合時
```bash
npm cache clean --force
npm install -g @openai/codex@0.129.0
```

---

## 7. 結論

- ✅ Codex CLI 0.128.0 → 0.129.0 升級成功
- ✅ acceptance_criteria A-1〜A-5, B-1 全て PASS
- ⚠️ ash5/ash6/ash7 pane は依然 update prompt 停止中。家老判断にて案 A (Skip 送出) を推奨

---

## 付録: 環境情報

- VPS: srv1121380
- OS: Ubuntu (kernel 6.8.0-110-generic)
- npm prefix: `/home/ubuntu/.npm-global`
- node: v20.19.5
- npm: 10.8.2
- 升級所要時間: 約 8 秒 (npm changed 2 packages)
