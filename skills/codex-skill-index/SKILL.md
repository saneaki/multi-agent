---
name: codex-skill-index
description: >
  Use when a Codex agent needs to locate and load a SKILL.md for a specific task.
  Codex has no Claude Code native skill activation (/skill-name or Skill tool).
  This index maps trigger phrases to SKILL.md paths and documents compatibility ratings
  (◎/○/×) for all 232+ skills in the shogun skill library.
tags: [codex, skill-management, index, shogun-ops]
---

# codex-skill-index

Codex エージェント向けスキル索引。Claude Code の `/skill-name` 自動起動が使えない
Codex からスキルを参照する際の「trigger phrase → SKILL.md パス + 互換性評価」マッピング。

## Background

Claude Code はスキル description のマッチングで自動起動する。
Codex にはそのような仕組みがないため:

1. タスクの問題領域を確認
2. この索引で対応スキルを検索
3. `Read skills/<name>/SKILL.md` または `Read ~/.claude/skills/<name>/SKILL.md` で手動ロード

## Codex Loading Methods

| 方法 | Codex での動作 | 最適用途 |
|------|---------------|---------|
| `Read SKILL.md` 直接 | ✅ | 単発タスク、特定スキル確認 |
| ファイル mention で context に含める | ✅ | TUI workflow で常時参照したい場合 |
| 安定ルールを `AGENTS.md` にコピー | ✅ | 常時有効なルール (運用上限など) |
| `~/.codex/config.toml` で MCP 設定 | ✅ | n8n / GitHub / Exa 等 MCP 依存スキル |
| Claude Code `/skill-name` / Skill tool | ❌ | Codex では不可 |

## Compatibility Ratings (cmd_663 調査結果 2026-05-08)

| Rating | 件数 | 意味 |
|--------|-----|------|
| ◎ | 197 | Markdown をそのまま読んで適用可能 |
| ○ | 29 | ツール名/hook設定/MCPパスの読み替えが必要 |
| × | 6 | コアロジックが Claude Code slash/Agent に依存 |

**× 対象** (Claude Code 専用、Codex では直接利用不可):

| スキル | 理由 |
|--------|------|
| `orchestrate` | `/orchestrate` + Claude agent chaining 前提 |
| `multi-workflow` | Claude command/wrapper workflow + `.claude/plan` 前提 |
| `dmux-workflows` | dmux/Claude workflow integration 前提 |
| `autonomous-loops` | Claude Code loop automation semantics |
| `skill-stocktake` | slash command + Agent invocation がコア |
| `shogun-claude-code-posttooluse-hook-guard` | PostToolUse hook (Claude Code 固有) がターゲット |

## Top 10 Codex で即使用可能なスキル

| # | スキル | パス | Trigger |
|---|--------|------|---------|
| 1 | `codex-cli-poc-verification` | `skills/codex-cli-poc-verification/SKILL.md` | Codex startup/integration 確認 |
| 2 | `shogun-agent-status` | `skills/shogun-agent-status/SKILL.md` | agent pane 状態確認スクリプト |
| 3 | `n8n-expression-syntax` | `~/.claude/skills/n8n-expression-syntax/SKILL.md` | n8n expression が動かない |
| 4 | `python-testing` | `~/.claude/skills/python-testing/SKILL.md` | Python ユニットテスト |
| 5 | `security-review` | `~/.claude/skills/security-review/SKILL.md` | セキュリティレビュー実施 |
| 6 | `skill-creation-workflow` | `skills/skill-creation-workflow/SKILL.md` | スキル候補を SKILL.md 化 |
| 7 | `shogun-dashboard-sync-silent-failure-pattern` | `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md` | dashboard 同期 silent failure |
| 8 | `github-actions-docs-check-template` | `~/.claude/skills/github-actions-docs-check-template/SKILL.md` | GHA 問題トラブルシュート |
| 9 | `shogun-n8n-wf-analyzer` | `~/.claude/skills/shogun-n8n-wf-analyzer/SKILL.md` | n8n WF 分析 |
| 10 | `n8n-validation-expert` | `~/.claude/skills/n8n-validation-expert/SKILL.md` | n8n バリデーション |

## カテゴリ別索引 (◎/○/× 付き)

### shogun ops (代表的なもの)

| スキル | Rating | Trigger (いつ使う) |
|--------|--------|--------------------|
| `shogun-gas-clasp-rapt-reauth-fallback` | ◎ | `clasp push` で invalid_rapt/invalid_grant |
| `shogun-gas-automated-verification` | ◎ | GAS 関数の clasp run + clasp logs 自動化 |
| `codex-context-pane-border` | ◎ | tmux pane に Codex context% 表示 |
| `shogun-tmux-busy-aware-send-keys` | ○ | tmux send-keys で idle 待ち (Claude → Codex 読み替え) |
| `shogun-model-switch` | ○ | モデル切替 (shp.sh コマンド) |
| `shogun-agent-status` | ◎ | 全 agent の状態確認 |
| `shogun-error-fix-dual-review` | ◎ | エラー修正時の dual-model review |
| `shogun-precompact-snapshot-e2e-pattern` | ○ | compaction 前 snapshot (Claude Code context 管理概念の読み替え要) |

### n8n / automation (◎ のみ抜粋)

| スキル | Trigger |
|--------|---------|
| `n8n-workflow-patterns` | n8n WF 設計全般 |
| `n8n-code-javascript` | n8n Code node JS |
| `n8n-expression-syntax` | `{{ }}` 式が動かない |
| `shogun-n8n-jq-false-alternative-guard` | jq `//` 演算子で false が偽値扱い |
| `shogun-n8n-trigger-stuck-recovery` | n8n trigger stuck |
| `shogun-n8n-gmail-id-archive-pattern` | Gmail ID 直接参照アーカイブ |

### development workflow (◎ のみ抜粋)

| スキル | Trigger |
|--------|---------|
| `tdd-workflow` | TDD 実装 |
| `security-review` | セキュリティ審査 |
| `deployment-patterns` | デプロイパターン |
| `database-migrations` | DB マイグレーション |
| `github-actions-release-artifact` | GHA artifact upload/download |

## スキル検索手順 (Codex 向け)

```text
1. 問題の domain を特定 (n8n / GAS / tmux / codex / security 等)
2. このファイルの索引で該当スキルを探す
3. Read でロード:
   Read /home/ubuntu/shogun/skills/<name>/SKILL.md
   または
   Read /home/ubuntu/.claude/skills/<name>/SKILL.md
4. スキルの Trigger セクションを確認して適用
```

## AGENTS.md に昇格済みの高頻度スキル

以下は安定ルールとして `AGENTS.md` / `instructions/*.md` に取り込み済み。
Codex の通常タスクでは再 Read 不要:

- 破壊的操作安全 (destructive_safety.md)
- F004 ポーリング禁止
- タイムスタンプ規則 (jst_now.sh)
- Inbox プロトコル (inbox_write.sh)

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_663 | ash6 (Codex) が全 232 スキルの互換性調査 | ◎ 197 / ○ 29 / × 6 分類完了、2層ロード戦略確立 |
| cmd_675 | ash4 (Sonnet) がスキル索引 SKILL.md として体系化 | Codex 向け trigger phrase → path マッピング整備 |

## Related Skills

- `skill-creation-workflow` — スキル候補を SKILL.md に変換するプロセス
- `codex-cli-poc-verification` — Codex 起動・動作確認
- `codex-context-pane-border` — Codex context 表示 (tmux pane border)

## Source

- cmd_663: ash6 (Codex) による全スキル互換性マトリクス調査
- cmd_675: ash4 による索引スキル化 + trigger phrase 整備
