# cmd_728b: Lord Approval Skill Draft

作成: 2026-05-15 15:15 JST
担当: ashigaru5 (Opus+T)
範囲: `skills/shogun-lord-approval-request-pattern/SKILL.md` 起草のみ。共有3源 (skill_candidates.yaml / skill_history.md / dashboard.md) は触らず後段同期案を §5 に記録。

## 1. Summary

cmd_728 β。α (cmd_728a 業界調査 11 source) と cmd_728e (`scripts/discord_notify.py --chunked` 実装) の結果を踏まえ、殿承認依頼 skill `shogun-lord-approval-request-pattern` を起草した。

- 作成 path: `skills/shogun-lord-approval-request-pattern/SKILL.md` (283 line)
- frontmatter: `Use when` (殿への承認依頼・判断要請) + `Do NOT use for` (家老内/軍師内/足軽内の技術判断) 両明示
- 必須8フィールド: 件名 / 背景・経緯 / 調査・検討プロセス / 選択肢 + trade-off / 推奨判断と根拠 / 殿のアクション / 期限・SLA / 参考資料
- テンプレ: Discord 詳細版 (1200-1600字) + dashboard 短縮版 (120-180字) の二系統
- `--chunked` usage: 直接実行 / `NOTIFY_CHUNKED=1 notify.sh` wrapper / 判定基準 / `--dry-run` part 数確認
- cmd_716 gate registry mapping, `shogun-error-fix-dual-review` 連携, `skill-creation-workflow` 関係を明示
- 共有3源は編集せず、後段同期案を本 output §5 に記録

## 2. Acceptance Criteria Self-Check

| AC | Status | Evidence |
|---|---|---|
| B-1 | PASS | `skills/shogun-lord-approval-request-pattern/SKILL.md` 新設 (skill-creation-workflow §1-§3 準拠: 評価 → 統合判断 → SKILL.md 作成)。`shogun-decision-notify-pattern` (ntfy infrastructure) と独立ドメインのため統合せず新規 |
| B-2 | PASS | frontmatter description に [English] / [日本語] 両方で `Use when` (殿への承認依頼・判断要請時) と `Do NOT use for` (家老内/軍師内/足軽内の技術判断) を明示 (SKILL.md L4-L13) |
| B-3 | PASS | (a) 必須8フィールド (SKILL.md §"8 Required Fields"); (b) Discord 詳細テンプレ (§"Discord Detailed Template"); (c) dashboard 短縮テンプレ (§"Dashboard Short Template"); (d) `--chunked` usage (§"--chunked Usage") |
| B-4 | PASS | (a) cmd_716 gate registry mapping (§"Relation to cmd_716 Gate Registry": 7項目 mapping + coexistence); (b) `shogun-error-fix-dual-review` 連携 (§"Relation to shogun-error-fix-dual-review": 材料 → 承認依頼 前後関係); (c) `skill-creation-workflow` 関係 (§"Relation to skill-creation-workflow": 並列・dashboard表現参照) |
| B-5 | PASS | `queue/skill_candidates.yaml` / `memory/skill_history.md` / `dashboard.md` 無編集 (本 §5 sync proposal で後段反映案を記録) |
| B-6 | PASS | line count=283 (< 500 OK), frontmatter完備, markdown構文 (15 H2 section), git preflight 本 §6 記録, commit/push 後段判断 |

## 3. Skill Quality Check

### Line / Structure

- 全行数: 283 line (`skill-creation-workflow` §3 上限 500 line 内)
- H2 section 数: 15 (When to Use / When NOT to Use / Why / 8 Required Fields / Discord Template / Dashboard Template / --chunked Usage / cmd_716 Gate Registry / Dual Review 連携 / Skill Creation Workflow 連携 / Anti-Patterns / Battle-Tested / Sync Proposal / Related Skills / Source)
- 必須6 section (`skill-creation-workflow` §3) ALL present: front matter / Problem (Why) / Battle-Tested Examples / Related Skills / Source / 本体テンプレ

### Frontmatter Validation

| 項目 | 内容 |
|---|---|
| `name:` | `shogun-lord-approval-request-pattern` (kebab-case, task YAML editable_files 一致) |
| `description:` | [English] + [日本語] 両方、`Use when` + `Do NOT use for` 明記 |
| `tags:` | `[shogun-system, human-oversight, decision-memo, dashboard, discord, gate-registry]` |

### Markdown Syntax Verification

- Code fence (` ```text `, ` ```bash `, ` ```markdown `) 全て対応する閉じ fence あり
- Table: 4 (8 Required Fields / cmd_716 mapping / Battle-Tested Examples / Field Notes)
- Link: skill 内相互参照 (`skill-creation-workflow`, `shogun-error-fix-dual-review` 等)、外部参照は cmd 番号

## 4. Existing Skill Non-Overlap Analysis

| 既存 skill | ドメイン | 本 skill との関係 |
|---|---|---|
| `shogun-decision-notify-pattern` (`/home/ubuntu/.claude/skills/`) | 通知 infrastructure (ntfy 4要素: push + atomic append + cooldown + fail-safe) | **補完**。本 skill は content format、`decision-notify` は配信機構。Discord 経路化後も `decision-notify` Element 1 (push) body に本 skill テンプレを詰める形で連携 |
| `shogun-error-fix-dual-review` | コード起因エラーの並列 review (Opus + Codex) → 軍師統合 | **前段**。dual-review output (CRITICAL/HIGH findings / 衝突裁定) は本 skill §2 背景・§4 選択肢の材料。Variant 1 verdict=conditional 時に殿承認依頼へ昇格 |
| `skill-creation-workflow` | skill 候補 → SKILL.md 変換プロセス + 共有3源同期 | **並列**。本 skill 自身が本 workflow §1-§6 に従って作成された。skill 化承認の dashboard 表現に本 skill テンプレを使う関係 |

### 重複なし判定

- `decision-notify`: ntfy 機構の堅牢性 vs 本 skill: 殿向け content の structured format → ドメイン分離明確
- `error-fix-dual-review`: コード review の workflow vs 本 skill: 殿への報告 format → 工程分離明確
- `skill-creation-workflow`: skill 化の手続き vs 本 skill: 殿承認の書式 → 手続きの主体分離明確

`skill-creation-workflow` §2 統合判断 flow に照らし、本 skill は **新規スキルとして独立作成** (既存スキル同一ドメインなし、独立性高い)。

## 5. Sync Proposal (後段同期案)

本 cmd_728b では編集禁止 (B-5)。cmd_728c (instructions 改訂) / cmd_728d (軍師 QC) 完了後の後段同期任務で以下を反映する案。

### 5.1 queue/skill_candidates.yaml 追記案

```yaml
- id: SC-shogun-lord-approval-request-pattern
  name: shogun-lord-approval-request-pattern
  status: created
  source_cmd: cmd_728b
  created_at: '2026-05-15T15:15:45+09:00'
  path: skills/shogun-lord-approval-request-pattern/SKILL.md
  lines: 283
  related_to:
    - shogun-decision-notify-pattern  # 補完: 通知 infrastructure
    - shogun-error-fix-dual-review     # 前段: 判断材料供給
    - skill-creation-workflow          # 並列: skill 化承認の dashboard 表現
  source_research:
    - output/cmd_728a_lord_approval_best_practice_research.md  # 11 source
    - output/cmd_728e_discord_notify_long_message_support.md   # --chunked 実装
  battle_tested:
    - cmd_716  # 9時間 cmd 進行遅延を露呈した dogfooding 起点
```

### 5.2 memory/skill_history.md 追記案

ファイル先頭の「アーカイブ済みエントリ」テーブルに追加:

```markdown
| **shogun-lord-approval-request-pattern** ✅ | cmd_728b(SC-shogun-lord-approval-request-pattern): 殿承認依頼の必須8フィールド + Discord詳細/dashboard短縮の二系統テンプレ + `--chunked` usage を体系化。新規 283L。cmd_716 dogfooding を battle-tested 起点として収録。 |
```

### 5.3 dashboard.md 追記案

戦果欄 (✅) に追加:

```markdown
| 15:XX | ashigaru5 | 🏆 cmd_728b 完了: 殿承認依頼 skill 起草 | `skills/shogun-lord-approval-request-pattern/SKILL.md` 283L 新設 / 必須8フィールド / Discord+dashboard 二系統テンプレ / --chunked usage / cmd_716+dual-review+skill-creation-workflow 関係明示 |
```

要対応欄からは SO-19 に従い cmd_728 全完了時に該当 `[cmd_728-*]` action_required を削除する。本 task β 単独で要対応欄を更新する必要なし (cmd_728c/d 続行中)。

### 5.4 instructions/ 追記案 (cmd_728c 領域 — 参考)

cmd_728c (γ instructions 改訂) の参考として、追加箇所案を以下に記録する:

- `instructions/shogun.md` の `Command Writing` または新規 `Lord Approval Request` 節に skill 参照 link
- `instructions/karo.md` の `dashboard / action_required 更新規律` 節に dashboard 短縮版テンプレ link
- `instructions/common/shogun_mandatory.md` の Action Required / Verification Before Report 周辺で「詳細は Discord/output、dashboard は短縮」を本 skill へ link

cmd_728c 担当足軽が本 §5.4 を参考に instructions 改訂すること。

## 6. Git Preflight (cmd_704)

### 作業前 `git status --short`

```text
 M docs/dashboard_schema.json
 M memory/global_context.md
 M queue/external_inbox.yaml
 M queue/reports/ashigaru1_report.yaml
 M queue/reports/ashigaru4_report.yaml
 M queue/reports/ashigaru5_report.yaml
 M queue/reports/gunshi_report.yaml
 M queue/suggestions.yaml
 M queue/tasks/ashigaru4.yaml
 M scripts/discord_notify.py
 M scripts/notify.sh
 M scripts/shc.sh
 M tests/unit/test_notify_discord.bats
```

### 本 task の変更ファイル

新規:
- `skills/shogun-lord-approval-request-pattern/SKILL.md` (283L)
- `output/cmd_728b_lord_approval_skill_draft.md`

更新:
- `queue/reports/ashigaru5_report.yaml` (cmd_728b 完了記録)
- `queue/tasks/ashigaru5.yaml` (status: done)
- `queue/inbox/ashigaru5.yaml` (msg_20260515_060810_39cd1feb read:true)

### 不触ファイル (B-5 + RACE-001)

- `queue/skill_candidates.yaml` — 後段同期任務へ委譲 (§5.1)
- `memory/skill_history.md` — 同上 (§5.2)
- `dashboard.md` — Karo / Gunshi 専管 (Ashigaru 編集禁止) + 後段同期 (§5.3)
- `instructions/*.md` — cmd_728c (γ) で改訂 (§5.4 参考案のみ提示)

### Commit/Push 判断

cmd_728 統合作業 (cmd_728d 軍師 QC + cmd_728c instructions 改訂後) の squash/pub 判断に委ねる。
単独 commit する場合は `feat(skill): add shogun-lord-approval-request-pattern (cmd_728b)` を推奨。

## 7. Notes for Karo

- cmd_728a / cmd_728e の output / discord_notify --chunked 実装は本 skill 内 §"--chunked Usage" にそのまま反映済。
- `shogun-decision-notify-pattern` (ntfy infrastructure) との重複懸念は §4 で解消 (ドメイン分離明確)。
- 軍師 QC (cmd_728d) では特に以下を確認推奨:
  - 必須8フィールドの順序が殿の意思決定 flow と整合するか
  - Discord 詳細テンプレが 1200-1600 字を超えないか (実例 cmd を1件入れて検証)
  - cmd_716 gate registry mapping が cmd_716 Phase D 完成後の schema と整合可能か
- instructions 改訂 (cmd_728c) は §5.4 を参考に進めること。
