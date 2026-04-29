---
name: skill-creation-workflow
description: >
  スキル候補をスキルファイルに変換する標準プロセス。
  有用度/汎用性/独立性評価→既存統合判断→SKILL.md作成→
  skill_candidates.yaml・memory/skill_history.md更新→git pushまでを体系化。
  Use when processing skill candidates (SC-xxx) into concrete SKILL.md files.
tags: [meta, skill-management, workflow, shogun-system]
---

# Skill Creation Workflow

スキル候補（SC-xxx）を再利用可能なスキルファイルに変換する標準プロセス。

## 1. スキル候補の評価

### 評価基準

| 軸 | 問い | 高評価の条件 |
|----|------|-------------|
| 有用度 | 同じ問題に再度遭遇するか | 過去2回以上発生 |
| 汎用性 | 特定WF以外でも使えるか | n8n全般または汎用ツールに適用可能 |
| 独立性 | 独立したスキルとして成立するか | 既存スキルと重複しない核心がある |

### 却下基準

- 特定WFにのみ依存した1回限りの対処
- 既存スキルに完全に包含可能な内容（→ 相互参照注記のみ追加）
- 5行以下で表現できる自明なTip

## 2. 既存スキルとの統合検討

### 統合優先ルール

```
同一ドメイン → 統合優先
既存スキル行数 + 追加分行数 < 500 → 統合
既存スキル行数 + 追加分行数 ≥ 500 → 分離（新規作成）
```

### 統合判断フロー

```
SC候補を確認
  ↓ 既存スキルに同一ドメインあり?
  → YES: 行数チェック
    ↓ 統合後 < 500行?
    → YES: 既存スキルに統合（セクション追加）
    → NO: 新規スキルとして独立作成
  → NO: 新規スキルとして独立作成
```

### 統合実例

| SC | 統合先 | 判断理由 |
|----|--------|---------|
| SC-041/042 (Task Runner stall) | trigger-stuck-recovery | 同一ドメイン・323L→+65L |
| SC-024 (HTTP認証) | 新規: n8n-http-credential-patterns | 独立ドメイン・単独で大きい |
| SC-027 (件名サニタイズ) | gmail-id-archive-pattern §2 | 実質包含済み → 相互参照注記のみ |

## 3. スキルファイル作成

### SKILL.md 必須構成

```markdown
---
name: <skill-name>
description: >
  [English] Use when ... （1行でトリガー条件を記述）
  [日本語] ...が必要な時に使用。...
tags: [tag1, tag2]
---

# タイトル

## Problem Statement（またはセクション名）

（本文）

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_xxx | ... | ... |

## Related Skills

- `skill-name` — 関連理由

## Source

- cmd_xxx: 由来の説明
```

### 品質チェックリスト

- [ ] `wc -l` が499以下
- [ ] `npx markdownlint-cli` 通過（エラーゼロ）
- [ ] front-matter (name/description/tags) あり
- [ ] Battle-Tested Examples に実績cmdを記録
- [ ] Related Skills で関連スキルを相互参照
- [ ] SC包含注記（統合の場合）: `> SC-XXX (名前): このセクションに包含`

## 4. skill\_candidates.yaml 更新

### ステータス定義

| ステータス | 意味 |
|-----------|------|
| `pending` | 評価待ち |
| `approved` | スキル化承認（新規作成予定） |
| `merged` | 既存スキルに統合済み |
| `created` | 新規SKILL.md作成済み |
| `rejected` | 却下（理由を記録） |

### 更新例

```yaml
- id: SC-025
  name: n8n-drive-ai-text-injection
  status: merged
  merged_into: shogun-n8n-gemini-pdf-analysis
  source_cmd: cmd_277
  merged_at: cmd_321
```

## 5. memory/skill\_history.md 更新

skill\_history.mdはdashboard.md 🛠️スキル欄のアーカイブ。
新規作成・統合後にファイル先頭の「アーカイブ済みエントリ」テーブルに追記:

```markdown
| **<skill-name>** ✅ | cmd_XXX(SC-YYY): 内容1行要約。行数・作業種別。 |
```

統合の場合:

```markdown
| **<skill-name>** 更新 ✅ | cmd_XXX(SC-YYY): 追加内容要約。旧行数L→新行数L。 |
```

## 6. git commit + push

```bash
cd /home/ubuntu/.claude

# 対象ファイルのみ add（git add -A は使わない）
git add skills/<skill-name>/SKILL.md
# 統合の場合は既存ファイルも
git add skills/<existing-skill>/SKILL.md

git commit -m "feat(skill): <description> (cmd_XXX)"
git push origin main
# 競合時（他の足軽との同時push）:
git pull --rebase origin main && git push origin main
```

## 6.5 shogun skill symlink 自動化

`/home/ubuntu/shogun` 環境では、`skills/` 変更を commit すると `post-commit` hook が
`scripts/sync_shogun_skills.sh` を実行し、`/home/ubuntu/.claude/skills/` へ symlink を自動同期する。

初回のみ以下を実行:

```bash
bash scripts/install_git_hooks.sh
```

手動同期が必要な場合:

```bash
bash scripts/sync_shogun_skills.sh
```

## Real Examples

| cmd | 作業種別 | 結果 |
|-----|---------|------|
| cmd_332 | SC-041/042 → trigger-stuck-recoveryに統合 | 237L→322L。同一ドメイン統合パターン |
| cmd_334 | SC-043 → bash-crlf-write-tool-guard新規作成 | 独立ドメイン・257L新規 |
| cmd_321 | SC-025/027/021/039 → 3スキルに統合 | 既存包含確認+相互参照注記のみのケース含む |
| cmd_340 | SC → skill-creation-workflow新規作成 | 本スキル自体がワークフローの産物 |

## Source

- cmd_332: SC-041/042統合プロセスから抽出
- cmd_334: 独立スキル作成プロセスから抽出
- cmd_340: スキル化ワークフローを明示的にスキルとして定義
