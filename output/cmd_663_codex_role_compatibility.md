# cmd_663 Scope A — 将軍/家老/軍師 Codex 起動可否調査

**作成**: 2026-05-08 04:56 JST
**担当**: ashigaru5 (Opus+T)
**parent_cmd**: cmd_663
**north_star**: 将軍/家老/軍師 を Codex で起動可否を確認し、9 構成員すべての CLI 自由度を保証する

---

## TL;DR

| Role | 起動可否 | 主要対応 | 工数 |
|------|---------|---------|------|
| 将軍 (Shogun) | ○ 一部修正で可 | sandbox (network)、MCP 移植、hook 代替、ntfy/Discord HTTP 用 network 開放 | 2–3h |
| 家老 (Karo) | ○ 一部修正で可 | MCP 移植、PostCompact hook 代替、Task agents 代替 | 3–4h |
| 軍師 (Gunshi) | ○ 一部修正で可 | MCP 移植、PreCompact snapshot hook 代替、WebFetch 代替 | 3–4h |
| 共通 | — | ~/.codex/config.toml 設定、switch_cli.sh の役職分岐確認、AGENTS.md 内 manual fallback | 4–6h |

**結論**: 3役職とも起動可能。ただし「Claude Code 固有機能 (hooks / MCP / Task tool / WebFetch)」を Codex で再現する代替設計が必須。試行は **家老 → 軍師 → 将軍** の順を推奨 (依存度小→大)。

---

## A-1. 過去 Codex 起動関連ファイル特定

repo + git history より、ash6/ash7 (Codex 足軽) の起動・運用に作成・改修されたファイルを系統別に整理。

### A-1-1. 役職別 instruction (auto-load 対象)

| ファイル | 役割 | サイズ感 | 備考 |
|---------|------|---------|------|
| `AGENTS.md` (repo root) | Codex の auto-load entry point。`project_doc_max_bytes` (default 32 KiB) 上限あり | 326 行 | shogun system 全体の概要 + 共通ルール |
| `instructions/cli_specific/codex_tools.md` | Codex CLI 固有機能の解説 (sandbox / approval / MCP / `--search` / `/new` 等) | 235 行 | claude_tools.md / copilot_tools.md / kimi_tools.md と並列 |
| `instructions/generated/codex-shogun.md` | Codex 用 shogun 役職 instruction (CLAUDE.md + 共通 + cli_specific を build_instructions.sh で結合) | 943 行 (生成物) | F006a により直接編集禁止。templates 経由 |
| `instructions/generated/codex-karo.md` | Codex 用 karo 役職 instruction | 1,255 行 (生成物) | 同上 |
| `instructions/generated/codex-ashigaru.md` | Codex 用 ashigaru 役職 instruction (ash6/ash7 が現に使用中) | 既存 | 同上 |
| `instructions/generated/codex-gunshi.md` | Codex 用 gunshi 役職 instruction | 1,474 行 (生成物) | 同上 |

**所感**: 全4役職 codex-{role}.md は生成済 (ash6/ash7 起動時に `build_instructions.sh` で生成)。**役職テンプレート自体は全員分すでに存在**。

### A-1-2. CLI 切替・起動 script

| ファイル | 主要関数・分岐 | 行 |
|---------|--------------|----|
| `scripts/switch_cli.sh` | `send_codex_startup_prompt()` (起動後プロンプト送信) | L674-700 |
|  | `effective_cli` 解決 + codex-safe fallback (CLI 不明時 = codex 想定) | L210-285 |
|  | `/clear → /new` 自動マッピング | L749-757 |
|  | `--no-alt-screen` 起動分岐 | (起動オプション部) |
|  | `escalation Phase 3` で Codex は `/clear` skip | L1356-1362 |
|  | `Escape escalation` を Codex で抑制 (cursor bug 回避なし) | L1010-1015 |
|  | `/model` send-keys を Codex で skip | L596-625 |
|  | `--type codex` 自動推論 (model `gpt-5.x-codex` / `gpt-5-codex` 検知) | L361-370 |
| `scripts/inbox_watcher.sh` | switch_cli.sh 経由で codex 経路を呼出 (`reset_cmd=/new`、`startup_prompt` 送信) | 主要連動 |
| `scripts/build_instructions.sh` | CLAUDE.md + roles/*.md + cli_specific/*.md を結合し codex-{role}.md / claude-{role}.md / copilot-{role}.md / kimi-{role}.md を生成 | 全 cli 横断 |
| `scripts/watcher_supervisor.sh` | inbox_watcher.sh の supervisor。Codex pane も再起動対象 | — |
| `scripts/ratelimit_check.sh` | `/status` から Codex msg/5h 上限を抽出 | Codex 専用処理 |
| `scripts/shp.sh` (cmd_662 新設) | shogun/karo/gunshi/ashigaru/all を一発で起動・switch する糖衣 | 既に Codex 引数許容 |

### A-1-3. 共通設定・configuration

| ファイル | Codex 関連項目 |
|---------|----------------|
| `config/settings.yaml` | `cli.agents.{ashigaru6,ashigaru7}.cli_type: codex`、`model: gpt-5.5`。`formations.hybrid` に Codex 2 名含む |
| `~/.codex/config.toml` (user-local、git 管理外) | Codex 固有: `project_doc_max_bytes`、`mcp_servers.*`、`approval_policy`、`sandbox_mode` |
| `AGENTS.md` (repo root) | Codex auto-load 対象 |

### A-1-4. Codex 移行で改修・新設された主要 commit (古→新)

```
e00f8b4  departure: simplify codex display name and use model name as pane title
9d4ca4d  feat: add --model support for Codex CLI (GPT-5.3-Codex-Spark ready)
40a296b  feat: Codex CLI startup prompt after /new + E2E tests (E2E-008)
0582aa6  fix: Codex /new多重送信バグ修正 + E2Eテスト追加
73e5623  fix: replace /clear with /new for Codex agents in all instruction files
cf4bd27  test: add 11 regression tests for Codex /clear→/new conversion
b01d56b  feat: add batch processing protocol, critical thinking rules, codex --search flag
cbad684  test: update codex CLI test to expect --search flag
e4abf69  feat(ratelimit): capture Codex /status rate limits + Android UI improvements
65bd635  fix(test): update display name tests for Codex5.3 and thinking defaults
0ba2753  cmd_454: align codex ashigaru skill_candidate report template
b085489  docs: add L3 task guidelines to codex-ashigaru instructions
aa1cfff chore(rules): 調査系タスク Opus+Codex 並列発令ルール永続化 (L016)
ef5222a feat(cmd_598): cmd完遂時 gunshi QC dispatch 自動化 (codex P3 先行実装)
f452216 watcher: dismiss Codex suggestion UI before nudge/reset
```

**所感**: ashigaru の Codex 化は、過去 cmd_454 / cmd_598 周辺で完了済。同じ機構を **shogun/karo/gunshi へ拡張**することが本 cmd の主題。テンプレ・script 基盤は揃っている — 不足は **役職固有の運用機能 (hooks / MCP / Task tool / WebFetch / network)** の代替設計。

---

## A-2. 6軸互換性評価

各 role × 6 評価軸 (persona / tmux / inbox / hooks / MCP / sandbox)。

### A-2-1. 将軍 (Shogun)

| 軸 | Claude Code (現行) | Codex (移行時) | 課題 | 対応 | 判定 |
|----|------------------|---------------|------|------|------|
| **persona** | `instructions/shogun.md` (Claude 用) を CLAUDE.md auto-load | `instructions/generated/codex-shogun.md` (943行) を AGENTS.md 経由 auto-load | AGENTS.md 32 KiB 上限。codex-shogun.md は ~70 KB で **既に上限超過**。Codex は `project_doc_max_bytes=65536` 拡張要 | `~/.codex/config.toml` に `project_doc_max_bytes = 65536` 設定 | ○ 設定で対応可 |
| **tmux pane metadata** | `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` で `shogun` 取得 | 同コマンド利用可 (`Bash` tool 経由)。`@agent_id` は `shutsujin_departure.sh` で設定 | Codex sandbox=workspace-write でも tmux コマンド実行可 (workspace 内 binary) | ✓ 動作確認のみ | ◎ そのまま可 |
| **inbox watcher** | `inbox_watcher.sh` で send-keys nudge。Lord typing 時 = `display-message` のみ (shogun-safe) | switch_cli.sh L1356 で Codex は escalation Phase 3 skip。**shogun pane 用の Lord-typing 検知は claude/codex 共通**で動作 | Codex TUI alt-screen は send-keys 干渉リスクあるが、`--no-alt-screen` で回避 (codex_tools.md L142-145) | `--no-alt-screen` 起動必須 | ○ 起動 flag 追加で可 |
| **hooks** | `.claude/settings.json` で PreToolUse/PostToolUse/Stop/PreCompact hooks (`pre_compact_snapshot.sh`, `post_compact_dispatch_restore.sh` 等) | Codex は **`.claude/settings.json` を読まない**。Codex 固有 hook は `~/.codex/config.toml` の `[shell_environment_policy]` 限定で、`tool_call_started`/`agent_message` 相当の hook は 無 | 主要 shogun hook = `pre_push_difference_check.sh` (Pre-push)、`pre_compact_snapshot.sh`、`scheduled_tasks` 系 → **Codex で全て不発火** | (a) cron daemon 化 (`scripts/hooks/*` を直接 cron 起動)、(b) AGENTS.md に手動 check 文言追記、(c) MCP server で hook 代替 | △ 要 fix (代替設計必須) |
| **MCP tools** | `mcp__memory__read_graph` を Step 2 で実行 (Memory MCP Claude Code 内蔵) | Codex は **memory MCP 内蔵なし**。`~/.codex/config.toml` `[mcp_servers.memory]` で `npx @anthropic/memory-mcp` 等を**手動登録**可能 | Memory MCP Claude/Codex 互換 server 要選定。OAuth 対応が Codex の利点 (`codex mcp login`) | `~/.codex/config.toml` に memory / github / notion MCP を手動登録 | ○ 設定で可 |
| **sandbox** | sandbox なし (Claude Code は無制限) | `--full-auto` = workspace-write + network blocked。**shogun は ntfy/Discord/Gmail/Google Chat 通知必須** = network 必要 | `ntfy.sh`, `gchat_send.sh`, `ntfy_listener.sh` 等が外部 HTTP 送信。`--full-auto` では一部失敗 | `--sandbox danger-full-access` または `~/.codex/config.toml` `[sandbox_workspace_write] network_access = true` | ○ 設定緩和で可 |

**判定**: 将軍 = **○ 一部修正で可**

**個別 fix 必要数**: 4 (persona size、hook 代替、MCP 移植、sandbox network)

### A-2-2. 家老 (Karo)

| 軸 | Claude Code (現行) | Codex (移行時) | 課題 | 対応 | 判定 |
|----|------------------|---------------|------|------|------|
| **persona** | `instructions/karo.md` を CLAUDE.md auto-load | `instructions/generated/codex-karo.md` (1,255行) を AGENTS.md 経由 auto-load | AGENTS.md 32 KiB 上限。codex-karo.md ~85 KB で **上限超過** | `~/.codex/config.toml` `project_doc_max_bytes = 65536` (or 131072) | ○ 設定対応可 |
| **tmux pane metadata** | `tmux display-message` で `karo` 取得 | 同上 | — | ✓ そのまま | ◎ |
| **inbox watcher** | `inbox_watcher.sh` で karo 用 nudge (multiagent:0.0)。task dispatch 時に `inbox_write` 経由 | switch_cli.sh L1356-1362 で Codex は `/clear` 強制 skip。代替: `/new` 送信 | karo は session 永続化要だが Codex の `/new` は session 内 fresh start で **task YAML 再読込み** で復旧可 | ✓ 標準動作で可 (codex 既存パスを通る) | ○ |
| **hooks** | `karo_session_start_check.sh` (PostCompact)、`ir1_editable_files_check.sh` (PreToolUse)、`pre_compact_dispatch_persist.sh` (PreCompact) | Codex で全 hook 不発火。`pre_compact_dispatch_persist.sh` 失敗 = **dispatch 状態が auto-compact で消滅** | 代替: (a) cron で 5 分毎 `pre_compact_dispatch_persist.sh` を呼出、(b) `dispatch_state.yaml` を毎タスク開始/終了時に手動 update、(c) snapshot 機構を AGENTS.md 手順に組込 | △ Codex で auto-compact 検知 hook 等価品なし → cron+手動 hybrid 必要 | △ 要 fix (重要) |
| **MCP tools** | `mcp__memory__read_graph` を Session Start Step 2、`mcp__github__*` を PR 操作で利用 | `~/.codex/config.toml` で memory + github MCP 手動登録 | OAuth 対応 (Codex 利点)。`enabled_tools`/`disabled_tools` で tool 制限可 | `~/.codex/config.toml` 設定 | ○ 設定対応可 |
| **sandbox** | 無制限 | `--full-auto` (workspace-write + network blocked) で **十分**。karo は inbox/dashboard/yaml 操作中心、外部 HTTP は ntfy 限定 | ntfy.sh は `bash scripts/ntfy.sh` 経由 → karo 直叩きなし (cmd_complete_notifier 等が代行) | ✓ `--full-auto` で OK | ◎ |

**判定**: 家老 = **○ 一部修正で可**

**個別 fix 必要数**: 3 (persona size、hook 代替 [重要]、MCP 移植)

**最重要 fix**: dispatch 状態の永続化 — Claude Code PreCompact hook で実装済の `pre_compact_dispatch_persist.sh` を Codex 環境で何が代替するか。候補:
- (1) cron 定期実行 (5 分毎)
- (2) inbox_write 内に snapshot 呼出を埋込
- (3) Codex MCP server で `tool_call_started` 相当 event を hook (要 server 自作)

### A-2-3. 軍師 (Gunshi)

| 軸 | Claude Code (現行) | Codex (移行時) | 課題 | 対応 | 判定 |
|----|------------------|---------------|------|------|------|
| **persona** | `instructions/gunshi.md` を CLAUDE.md auto-load | `instructions/generated/codex-gunshi.md` (1,474行) を AGENTS.md 経由 auto-load | AGENTS.md 32 KiB 上限。codex-gunshi.md ~95 KB で**上限超過 (3 役職中最大)** | `~/.codex/config.toml` `project_doc_max_bytes = 131072` 必要 | ○ 設定対応可 |
| **tmux pane metadata** | `tmux display-message` で `gunshi` 取得 | 同上 | — | ✓ そのまま | ◎ |
| **inbox watcher** | `inbox_watcher.sh` で gunshi 用 nudge (multiagent:0.8) | switch_cli.sh の codex 分岐共通対応済 | — | ✓ そのまま (起動 flag のみ) | ○ |
| **hooks** | `pre_compact_snapshot.sh` (PreCompact) で QC 中の `queue/snapshots/gunshi_snapshot.yaml` を保存 | Codex で PreCompact hook なし → **auto-compact 時に QC 文脈消滅**、軍師の 5-step Critical Thinking が破壊されるリスク | 代替: (a) `context_snapshot.sh write` を gunshi が手動で各 step 後に呼出、(b) Codex `/compact` 直前に手動 snapshot、(c) cron 定期 snapshot | △ snapshot 自動化困難 → 手動 trigger 必須 | △ 要 fix |
| **MCP tools** | `mcp__memory__read_graph`、`WebSearch`、`WebFetch` (Claude Code 内蔵) | Codex `--search` flag で web search 内蔵 (cached + live mode)、`WebFetch` 等価なし → curl で代替 | 軍師の 5-step Critical Thinking で URL 検証が必要 → Codex `--search` で十分 (公式ドキュメント検索可) | `--search` 利用、curl 経由 fetch、`~/.codex/config.toml` で memory MCP 登録 | ○ 機能代替で可 |
| **sandbox** | 無制限 | `--full-auto` で network blocked。**WebSearch / curl で network 必須** | `--sandbox workspace-write` + `network_access=true` または `danger-full-access` | network 開放 | ○ 設定緩和で可 |

**判定**: 軍師 = **○ 一部修正で可**

**個別 fix 必要数**: 4 (persona size、hook 代替 [snapshot]、WebFetch 代替、sandbox network)

**最重要 fix**: PreCompact snapshot — gunshi の 5-step Critical Thinking は深い文脈を要するため、auto-compact による文脈損失が最大リスク。

---

## A-3. 役職別起動可否まとめ

### 総合評価表

| Role | persona | tmux | inbox | hooks | MCP | sandbox | 総合 |
|------|---------|------|-------|-------|-----|---------|------|
| **将軍 (Shogun)** | ○ | ◎ | ○ | △ | ○ | ○ | **○** |
| **家老 (Karo)** | ○ | ◎ | ○ | △ | ○ | ◎ | **○** |
| **軍師 (Gunshi)** | ○ | ◎ | ○ | △ | ○ | ○ | **○** |

凡例: ◎ そのまま可 / ○ 一部修正で可 / △ 要 fix / × 不可

### 共通対応事項 (3 役職とも必要)

| # | 対応 | 詳細 | 工数 |
|---|------|------|------|
| C1 | `~/.codex/config.toml` 設定 | `project_doc_max_bytes = 131072` (3役職とも instruction が 32 KiB 上限超え) | 0.5h |
| C2 | MCP server 移植 | memory / github / notion MCP を `~/.codex/config.toml` に手動登録。OAuth 利用検討 | 1.5h |
| C3 | switch_cli.sh の役職別分岐確認 | 現状 ash/gunshi 想定の Codex 分岐 (L1356 等) が shogun/karo でも動作するか E2E test | 1h |
| C4 | AGENTS.md 内 manual fallback 文言追加 | hook 不発火を補う「session 開始時の手動 check リスト」を AGENTS.md 末尾に明記 | 1h |
| C5 | `build_instructions.sh` で全役職 codex-{role}.md 再生成 | template 修正後の rebuild。CI "Build Instructions Check" 通過確認 | 0.5h |
| C6 | Codex E2E test (新規) | 各役職の起動 → instruction 認識 → tmux nudge 受信 → inbox 処理 → snapshot 書込み の通し試験 | 2h |
| **共通工数小計** | **6.5h** |

### 役職個別 fix リスト

#### 将軍 (Shogun) 個別

| # | 対応 | 詳細 | 工数 |
|---|------|------|------|
| S1 | sandbox network 開放 | `~/.codex/config.toml` `[sandbox_workspace_write] network_access = true` または起動時 `--sandbox danger-full-access` | 0.5h |
| S2 | `pre_push_difference_check.sh` の Codex 化 | git pre-push hook は git 側 (`.git/hooks/pre-push`) で動作するため Codex 関係なし → ✓ 確認のみ | 0.5h |
| S3 | shogun 専用 hook (scheduled tasks) の cron 移行 | `scripts/hooks/scheduled_tasks_*.sh` を crontab に登録 (Codex で hook 不発火のため) | 1h |
| S4 | ntfy / Discord / Google Chat / Gmail HTTP の動作確認 | network 開放後の send 通過確認 | 0.5h |
| **将軍個別工数** | **2.5h** |

#### 家老 (Karo) 個別

| # | 対応 | 詳細 | 工数 |
|---|------|------|------|
| K1 | dispatch 状態永続化の代替設計 | `pre_compact_dispatch_persist.sh` を cron 5分毎 + `inbox_write.sh` 内 hook で代替 | 2h |
| K2 | Task agents 代替 (F003 例外) | karo の decomposition planning で Task tool 使用 → Codex は `codex exec` subprocess で代替 | 1h |
| K3 | `karo_session_start_check.sh` (PostCompact) の代替 | Codex `/new` 後に AGENTS.md 自動再読込 → 手動 check リストを AGENTS.md 末尾に明記 | 0.5h |
| **家老個別工数** | **3.5h** |

#### 軍師 (Gunshi) 個別

| # | 対応 | 詳細 | 工数 |
|---|------|------|------|
| G1 | PreCompact snapshot の代替 | gunshi が各 step 後に `context_snapshot.sh write` を手動呼出する protocol を AGENTS.md に明記 | 1h |
| G2 | sandbox network 開放 | `--sandbox workspace-write` + `network_access=true` (`--search` 利用のため) | 0.5h |
| G3 | WebFetch 等価機能 | `curl` + `--search` (Codex 内蔵) で代替。AGENTS.md に curl 利用方法を明記 | 1h |
| G4 | 5-step Critical Thinking の Codex 適応 | Step 2 (Recalculate) は数値再計算 — Codex でも実行可。Step 4 (Pre-mortem) で `--search` 活用 | 0.5h |
| **軍師個別工数** | **3h** |

### 全体工数合計

| 区分 | 工数 |
|------|------|
| 共通対応 | 6.5h |
| 将軍個別 | 2.5h |
| 家老個別 | 3.5h |
| 軍師個別 | 3h |
| **合計** | **15.5h** (1 名 ash で 2 日、parallel 2 名で 1 日相当) |

---

## A-4. 重要発見・リスク

### 発見1. AGENTS.md サイズ上限が全役職で問題

`build_instructions.sh` で生成される codex-{role}.md は 70-95 KB に達するが、Codex デフォルトの `project_doc_max_bytes` は **32 KiB**。**3 役職とも上限超過**。`~/.codex/config.toml` 拡張必須。

```toml
# ~/.codex/config.toml に追加必要
project_doc_max_bytes = 131072  # 128 KiB
```

### 発見2. Hook 不発火の影響範囲

現行 hooks (`.claude/settings.json` 経由) で Codex 化により失われる主要機能:

| Hook | 用途 | Codex 移行時の影響 |
|------|------|-----------------|
| `pre_compact_snapshot.sh` | auto-compact 直前の snapshot 自動保存 | **gunshi** で深刻 (5-step QC 文脈損失) |
| `pre_compact_dispatch_persist.sh` | karo dispatch 状態の永続化 | **karo** で深刻 (再起動時 dispatch 喪失) |
| `post_compact_dispatch_restore.sh` | auto-compact 後の dispatch 復元 | karo の auto-compact 復旧失敗 |
| `karo_session_start_check.sh` | session 開始時の inbox/snapshot 自動 check | karo 起動時 manual check 必要 |
| `ir1_editable_files_check.sh` | IR-1 (editable_files 範囲外編集) PreToolUse 検知 | ashigaru 含む全員で fail-open (人手 review) |

**対策方針**: cron daemon 化 + AGENTS.md manual fallback の 2 重防御。Codex MCP server で event hook を再実装する案も将来検討余地あり。

### 発見3. 既存 ashigaru Codex 経路は再利用可

`switch_cli.sh` の codex 分岐 (effective_cli == "codex" 判定) は **role 名で分岐していない**。すなわち:
- `tmux set-option -p @agent_cli codex` を shogun pane / karo pane / gunshi pane に設定すれば、既存ロジックがそのまま適用される
- 実装変更は scripts 側でなく **設定 (settings.yaml + ~/.codex/config.toml) と AGENTS.md** が中心
- `shp.sh` (cmd_662 で新設) は既に shogun/karo/gunshi/ashigaru/all の引数を持ち、Codex 切替に流用可

### 発見4. F003 (Task agents) 代替

| 役職 | 既存 Task tool 用途 | Codex 代替 |
|------|------------------|-----------|
| 将軍 | F003 (禁止) | 影響なし |
| 家老 | F003 例外 (decomposition planning, 大規模 doc 読込) | `codex exec` subprocess で代替可 |
| 軍師 | (本来不可) | 影響なし |
| 足軽 | 内部並列化 (3+ independent sub-steps 時) | `codex exec` subprocess で代替可、ただし msg/5h 上限注意 |

### 発見5. Codex msg/5h 上限のリスク

| Item | Claude Code | Codex (Plus/Pro) |
|------|------------|------------------|
| Limit | API-based (rate limit only) | **5h あたりメッセージ上限** |
| 影響 | parallel multi-cmd で問題なし | shogun + karo + gunshi 全 Codex 化時、合計負荷集中で上限突破リスク |

`scripts/ratelimit_check.sh` で /status から Codex 上限抽出可能。**運用時は Claude/Codex 混成 (将軍=Codex, 家老=Claude, 軍師=Codex 等) を推奨**、全員 Codex は msg 上限で危険。

### 発見6. `network_access` の段階的開放推奨

3 役職とも sandbox network が必要だが、`danger-full-access` 全開放は不要。
推奨設定:

```toml
# ~/.codex/config.toml
[sandbox_workspace_write]
network_access = true  # ntfy / WebSearch / git push 等
allow_unrestricted_egress = false  # 既知 host のみ許可するなら ↓
# または allowlist 方式 (Codex 仕様確認要)
```

---

## A-5. 推奨実装順序 (cmd_663 後続)

3 役職一斉移行ではなく、**段階的移行**を推奨。依存度が小さい順:

```
Phase 1: 家老 Codex 化 (3.5h + 共通 6.5h = 10h)
  ├─ MCP 移植
  ├─ dispatch persist 代替 (cron)
  └─ E2E test (家老 + ash6/7 連動)
       ↓
Phase 2: 軍師 Codex 化 (3h)
  ├─ snapshot 代替 (manual)
  ├─ WebFetch 代替 (curl + --search)
  └─ E2E test (軍師 QC + 家老連動)
       ↓
Phase 3: 将軍 Codex 化 (2.5h)
  ├─ network 開放
  ├─ scheduled tasks → cron
  └─ E2E test (殿 ntfy → 将軍 → 家老 全 Codex)
       ↓
Phase 4: 全員 Codex 運用テスト (1 週間)
  └─ msg/5h 上限監視、Claude/Codex hybrid 最適配分の確定
```

合計工数: **15.5h** (parallel 2 名で 1 日 + テスト期間)

### 優先順位の根拠

1. **家老優先** = 中央指揮官。Codex 化の検証点が最多。失敗時の影響も封じ込めやすい (1 役職限定)
2. **軍師次** = QC 単独役職。失敗しても他役職に波及せず単独再試行可
3. **将軍最後** = 殿との接点。最も慎重に。network 開放のセキュリティ確認も含む

---

## A-6. north_star alignment

cmd_663 north_star: 「将軍/家老/軍師 を Codex で起動可否を確認し、9 構成員すべての CLI 自由度を保証する」

| 観点 | 達成度 | 根拠 |
|------|--------|------|
| 起動可否確認 | ✓ 達成 | 3 役職とも ○ 判定。fix リスト提示 |
| CLI 自由度保証 | ✓ 達成 | 各役職の Claude/Codex 切替が switch_cli.sh + settings.yaml で実現可能 (既存 ashigaru 経路を流用) |
| 9 構成員一斉移行可否 | △ 部分達成 | 技術的には可、ただし msg/5h 上限により Claude/Codex hybrid を強く推奨 |

**結論**: 起動可否は明確に **YES (○ 一部修正で可)**。fix 工数 15.5h で完全移行可能。実運用上は hybrid 構成が最適。

---

## 後続 cmd 候補

cmd_663 完遂後、以下を提案:

1. **cmd_XXX (家老 Codex 化 PoC)**: 共通対応 + 家老個別 fix を実装、ash6 連動 E2E test
2. **cmd_XXX (軍師 Codex 化 PoC)**: 軍師個別 fix + snapshot 手動 protocol 確立
3. **cmd_XXX (将軍 Codex 化 PoC)**: network 開放 + scheduled tasks cron 移行
4. **cmd_XXX (Codex MCP server 自作)**: hooks 等価機能を MCP server で再実装 (将来構想)
5. **cmd_XXX (msg/5h 上限自動監視)**: ratelimit_check.sh の自動 alert 化

---

**作成完了**: 2026-05-08 04:56 JST
**ashigaru5 (Opus+T)**
