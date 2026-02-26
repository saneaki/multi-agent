# スキル化方法論 統合分析・方法論叩き台

> **cmd_143** | 作成日: 2026-02-15 | 統合担当: ashigaru6
>
> 本文書は2サブタスクの調査報告（143a: 既存スキル棚卸し、143b: Web調査）を統合し、
> 現状の問題分析と方法論の叩き台を提示するものである。

---

## 1. エグゼクティブサマリー

### 現状

- **既存スキル**: 95ファイル（59ディレクトリ）、9カテゴリ
- **2つの形式が混在**: shogun-*（単体.md、日本語、8件）と ECC由来（ディレクトリ/SKILL.md、英語、42件）
- **スキル作成ツール**: 5資産が存在するが**全て未稼働**
- **Context Window圧迫リスク**: description合計が16,000文字制限に迫る可能性

### 主要な問題

1. **フォーマット不統一**: 単体.md vs ディレクトリ形式の混在
2. **粒度のばらつき**: 102行〜4,468行まで大幅に差異
3. **命名規則の部分的不統一**: shogun-*プレフィックスの有無
4. **スキル作成ツール全未稼働**: 5資産中0資産が機能している
5. **技術スタック不適合**: Java/Spring/Django系スキルが実際のプロジェクトで未使用

### 方法論の核心

- **作成基準**: 同一パターンが2回以上発生 → スキル化検討
- **統合基準**: 常にセットで使用される + 共通前提知識 → 統合
- **廃止基準**: 6ヶ月未使用 or 技術スタック変更 → アーカイブ
- **フォーマット標準**: ディレクトリ形式に段階的統一、SKILL.md 500行以下

---

## 2. 既存スキル一覧と分類

> 出典: subtask_143a（ashigaru5報告書）

### 2.1 カテゴリ別スキル一覧

| # | カテゴリ | スキル数 | ファイル数 | 代表的なスキル | 備考 |
|---|---------|---------|-----------|--------------|------|
| 1 | n8n系 | 14 | 49 | n8n-code-javascript, n8n-workflow-patterns | 最大規模カテゴリ |
| 2 | 開発ワークフロー系 | 7 | 7 | tdd-workflow, verification-loop, e2e-testing | プロジェクト横断で有用 |
| 3 | ドキュメント/ユーティリティ系 | 6 | 9 | claude-md-improver, legal-document-namer | 雑多な集合 |
| 4 | 言語固有: Java/Spring | 6 | 6 | springboot-patterns, springboot-security | **実プロジェクト未使用** |
| 5 | Docker/インフラ系 | 4 | 5 | docker-patterns, deployment-patterns | shogun-*含む |
| 6 | Django系 | 4 | 4 | django-patterns, django-tdd | **実プロジェクト未使用** |
| 7 | セキュリティ系 | 3 | 4 | security-review, security-scan | shogun-*含む |
| 8 | 言語固有: TypeScript/Frontend | 3 | 3 | frontend-patterns, api-design | |
| 9 | 言語固有: Python | 3 | 3 | python-patterns, python-testing | 実プロジェクトで使用 |
| 10 | データベース系 | 3 | 3 | database-migrations, postgres-patterns | |
| 11 | 言語固有: Go | 2 | 2 | golang-patterns, golang-testing | |
| 12 | 学習系 | 2 | 4 | continuous-learning, continuous-learning-v2 | **未稼働** |
| 13 | その他 | 3 | 3 | tkinter-help-system, cpp-testing | 特殊用途 |

### 2.2 形式別の比較

| 属性 | shogun-*スキル（8件） | ECC由来スキル（42件） |
|------|---------------------|---------------------|
| ファイル形態 | 単体 .md | ディレクトリ/SKILL.md + 補助ファイル |
| YAMLフロントマター | あり（name, description, tags） | あり（name, description, version） |
| description言語 | 日本語 | 英語 |
| 本文構造 | 問題の本質→パターン→実装例→検証方法 | When to Activate→パターン→Examples→Related |
| 出典 | cmd_xxx への言及あり | Everything Claude Code プラグイン由来 |
| 平均行数 | 451行 | 約400行（SKILL.mdのみ） |
| 一貫性 | 高い（同一プロセスで生成） | 中程度（テンプレートベース） |

### 2.3 shogun-*スキルの出典特定

| スキル | 出典cmd | 根拠 |
|--------|---------|------|
| shogun-docker-volume-recovery | cmd_131 | ファイル内に明記 |
| shogun-n8n-cron-stagger | cmd_134（推定） | cron分散がcmd_134の内容と合致 |
| shogun-n8n-api-field-constraints | 不明 | cmd言及なし |
| shogun-n8n-telegram-digest | 不明 | cmd言及なし |
| shogun-n8n-workflow-upgrade | 不明 | cmd言及なし |
| shogun-notion-db-id-validator | 不明 | cmd言及なし |
| shogun-traefik-docker-label-guard | 不明 | cmd言及なし |
| shogun-gemini-thinking-token-guard | 不明 | cmd言及なし |

---

## 3. スキル作成関連資産の整理

> 出典: subtask_143a（ashigaru5報告書）

### 3.1 5資産の比較

| 資産 | 入力源 | 出力先 | トリガー | 粒度 | 信頼度 | 状態 |
|------|--------|--------|---------|------|--------|------|
| /skill-create | Git履歴 | SKILL.md | 手動 | スキル | なし | 利用可能（未使用） |
| CL v1 | セッション | learned/*.md | Stop hook | スキル | なし | **未稼働**（hook未設定） |
| CL v2 | 全ツール呼出 | homunculus/instincts/ | Pre/PostToolUse | Instinct | 0.3〜0.9 | **未稼働**（dir未作成） |
| /evolve | instincts/ | evolved/ | 手動 | クラスタ | あり | **利用不可**（前提なし） |
| /learn | セッション | learned/*.md | 手動 | スキル | なし | 利用可能（未使用） |

### 3.2 ライフサイクル上の位置づけ

```
[入力源]        → [検出・抽出]           → [蓄積]           → [進化]
Git履歴         → /skill-create          → SKILL.md（即座に完成品）
セッション      → CL v1（自動・Stop）    → learned/*.md
セッション      → /learn（手動）         → learned/*.md
全ツール呼出    → CL v2（自動・Hook）    → instincts/      → /evolve → evolved/
```

### 3.3 機能重複の分析

- **/learn と CL v1**: 「セッションからスキル直接生成」で機能重複（手動 vs 自動）
- **CL v1 → CL v2**: 進化関係（v2はv1のスーパーセット）
- **/skill-create**: 入力源が異なる（Git履歴）ため独立性が高い
- **/evolve**: CL v2専用のポスト処理（instinct蓄積が前提）

### 3.4 shogun-*スキルの生成方法（推定）

5資産のいずれとも異なる方法で生成されている。learned/ や homunculus/ には存在せず、直接 skills/ 直下に配置。日本語で、実際のインシデント（cmd_xxx）に基づく実践的パターン集。**おそらく手動作成**（家老または足軽がcmd完了後に経験をスキル化）。

---

## 4. 公式仕様・ベストプラクティス調査結果

> 出典: subtask_143b（ashigaru8報告書）要点抽出

### 4.1 Claude Code公式スキル仕様

**SKILL.md フロントマター（公式フィールド）**

| フィールド | 必須度 | 当プロジェクト活用状況 |
|----------|--------|---------------------|
| name | 推奨 | 使用中 |
| description | 強く推奨 | 使用中（日英混在） |
| disable-model-invocation | 任意 | **未活用** |
| allowed-tools | 任意 | **未活用** |
| model | 任意 | **未活用** |
| context | 任意 | **未活用** |
| hooks | 任意 | **未活用** |

**公式推奨事項**:
- SKILL.md は 500行以下
- ディレクトリ形式を推奨（SKILL.md + 補助ファイル）
- description は「いつ使うか」を明確に記述（Claude自動起動判定に直結）
- description 合計は Context Window の 2%（デフォルト16,000文字）

**スキル vs ルール vs コマンド vs エージェント**:

| 項目 | Rules | Skills | Commands | Agents |
|------|-------|--------|----------|--------|
| 読み込み | 常に全文 | description→必要時全文 | 手動起動時のみ | 委譲時 |
| Context圧迫 | **高**（常駐） | **低**（遅延ロード） | なし | 分離 |
| 用途 | 不変の制約 | 専門知識 | 副作用系タスク | 分離実行 |

### 4.2 コミュニティBP要点（8件）

| # | BP | 要点 | 当プロジェクト適用度 |
|---|-----|------|-------------------|
| 1 | 粒度 | 単一目的に集中、500行以下、5kトークン以下 | 高 |
| 2 | 管理ツール | Skills Manager (Tauri)、マーケットプレイス1,537件 | 低〜中 |
| 3 | 統合/分割基準 | 常にセットで使用→統合、複数ユースケース→分割 | 高 |
| 4 | 廃止基準 | 6ヶ月未使用→廃止、active/archived/experimental分離 | 中 |
| 5 | バージョニング | メタデータ or Git履歴で管理（フォルダ名は非推奨） | 中 |
| 6 | テスト/検証 | Examples + Expected Output、段階的テスト | 中 |
| 7 | レイヤリング | CLAUDE.md(150行以内) → Skills → Prompts | 高 |
| 8 | 大規模コレクション | 機能/ユースケース/技術スタックで分類 | 低 |

---

## 5. 類似ツール比較

> 出典: subtask_143b（ashigaru8報告書）

| 観点 | Cursor | GitHub Copilot | Windsurf | Claude Code |
|------|--------|----------------|----------|-------------|
| ルール形式 | .mdc (MD+YAML) | Markdown | Markdown | Markdown |
| サイズ制限 | 500行 | 1,000行 | 6,000文字 | 500行推奨 |
| 適用制御 | Glob+Always/Manual | 3層優先順位 | 4モード | description自動判定 |
| AI自動適用 | Context-aware | 階層優先 | Model Decision | description判定 |
| 動的コンテキスト | なし | なし | Memories | MCP Memory+YAML |
| チーム共有 | Git管理 | .github repo | Git管理 | Git管理 |

**Claude Code独自の強み**:
- マルチエージェント統合（Shogun/Karo/Ashigaru）
- Hookシステム（PreToolUse/PostToolUse）
- MCP Memory（セッション永続化）
- YAML Queue（状態管理）

---

## 6. 現状の問題分析

### 6a. 重複する内容を持つスキル

**n8n系（14スキル、最大カテゴリ）の重複分析**:

| 重複候補ペア | 重複内容 | 統合判定 |
|-------------|---------|---------|
| n8n-code-javascript / n8n-expression-syntax | 式構文の解説が一部重複 | **要検討**: 式→Code nodeへの発展的学習で統合の余地 |
| n8n-api-deploy / n8n-workflow-patterns | API呼び出しパターンが部分的に重複 | **統合不要**: 目的が明確に異なる（デプロイ vs 設計パターン） |
| shogun-n8n-api-field-constraints / n8n-node-configuration | ノード設定のフィールド制約情報 | **要検討**: n8n-node-configurationにshogun側の知見を統合可能 |
| n8n-validation-expert / n8n-node-configuration | バリデーションとノード設定の境界が曖昧 | **要検討**: 「設定→バリデーション」の連続フローとして統合の余地 |

**他カテゴリの重複**:

| 重複候補ペア | 統合判定 |
|-------------|---------|
| security-review / security-scan | **統合不要**: review=コードレビュー、scan=設定スキャンで目的が異なる |
| continuous-learning v1 / v2 | **v1廃止候補**: v2はv1の完全上位互換 |
| tdd-workflow / python-testing / golang-testing | **統合不要**: 言語固有パターンは分離が適切 |

### 6b. 粒度のばらつき

公式推奨500行に対する乖離分析:

| 分類 | スキル例 | 行数 | 判定 |
|------|---------|------|------|
| **過大（500行超）** | n8n-code-javascript | 4,468行 | SKILL.md+5補助ファイル。構造は適切だがSKILL.md単体の行数要確認 |
| **過大** | python-testing | 815行 | 分割候補（fixtures/parametrize → 補助ファイル化） |
| **過大** | pytest-migration | 808行 | 分割候補（移行手順 → 補助ファイル化） |
| **過大** | python-patterns | 749行 | 分割候補 |
| **過大** | django-patterns | 733行 | 分割候補（ただし未使用スキル） |
| **適正範囲** | shogun-*系 | 243〜552行 | 概ね公式推奨範囲内 |
| **過小** | strategic-compact | 102行 | 単独スキルとしては小さいが、明確な目的あり |
| **過小** | verification-loop | 125行 | 小さいが独立した機能を持つ |
| **過小** | java-coding-standards | 146行 | 小さく、かつ未使用。廃止候補 |

### 6c. 命名規則の不統一

| 観点 | 現状 | 公式ルール | 適合度 |
|------|------|-----------|--------|
| ケース | 全てケバブケース | 小文字・数字・ハイフンのみ | **適合** |
| プレフィックス | shogun-*（8件）と無印（42件）の混在 | 規定なし | **許容範囲**だが統一が望ましい |
| 長さ | 最長 shogun-traefik-docker-label-guard（37文字） | 64文字以内 | **適合** |
| 言語 | description日英混在 | 規定なし | **要統一**（日本語に統一推奨） |

**プレフィックス方針の論点**:
- shogun-*: 自プロジェクト固有のインシデントベーススキル → プレフィックスで区別する価値あり
- ECC由来: 汎用スキル → プレフィックス不要
- **結論**: 現状の使い分けは合理的。今後もshogun-*プレフィックスを手動作成スキルに使用

### 6d. フォーマットの不統一

| 形式 | 件数 | 公式推奨 | 移行コスト |
|------|------|---------|-----------|
| ディレクトリ/SKILL.md | 50件 | **推奨** | 不要 |
| 単体 .md（shogun-*） | 8件 | 非推奨 | 低（ディレクトリ作成 + リネーム） |
| 単体 .md（その他） | 残り | 非推奨 | 低 |

**移行の具体案**:
```
# 現在
skills/shogun-docker-volume-recovery.md

# 移行後
skills/shogun-docker-volume-recovery/SKILL.md
skills/shogun-docker-volume-recovery/examples.md  # 将来追加可能
```

### 6e. 古くなった情報を含む可能性のあるスキル

| リスクレベル | 対象 | 理由 |
|------------|------|------|
| **高** | 出典cmd不明の shogun-*（6件） | いつ、なぜ作成されたか追跡不可 |
| **中** | ECC由来スキル全般（42件） | プラグインの更新サイクルに依存、最終更新日不明 |
| **中** | Java/Spring系（6件）、Django系（4件） | 実プロジェクトで未使用。技術情報の陳腐化リスク |
| **低** | n8n系（14件） | 実際の運用で継続的に検証されている |

### 6f. スキル作成ツールの未活用

| 資産 | 未稼働理由 | 稼働させるべきか |
|------|-----------|----------------|
| /skill-create | 単に未実行 | **是**: Git履歴からのパターン抽出は初期スキル生成に有用 |
| CL v1 | Stop hook未設定 | **否**: CL v2が上位互換。v1の設定は不要 |
| CL v2 | homunculus/ 未作成、Hook未設定 | **要検討**: 運用コスト（Haiku API消費）vs 学習効果のバランス |
| /evolve | CL v2前提 | **CL v2次第**: v2が稼働すれば自動的に利用可能に |
| /learn | 単に未実行 | **是**: 手動パターン抽出は即座に開始可能、コスト低 |

**推奨優先順位**:
1. **/learn を即時活用開始**（コスト0、手動トリガー）
2. **/skill-create を試験実行**（Git履歴分析、1回限り）
3. **CL v2 の評価**（セットアップコスト中、運用コスト要算出）
4. **CL v1 は廃止**（v2が上位互換）

### 6g. Context Window圧迫リスク

**現状の推定**:
- 95スキルの description 合計: 推定 8,000〜12,000文字（英語＋日本語混在）
- 制限: 16,000文字（SLASH_COMMAND_TOOL_CHAR_BUDGET で変更可能）
- **現時点ではギリギリ安全圏**だが、スキル追加に伴い超過リスクあり

**圧迫源の分析**:

| 圧迫源 | 現状のContext消費 | 対策 |
|--------|-----------------|------|
| rules/ 全文常駐 | **高** | 頻繁に参照しないルールを skills/ に移行 |
| skills description | **中** | 簡潔化、不要スキルの廃止 |
| CLAUDE.md | **高** | 150行以内推奨に対し現状数百行 |

**rules/ → skills/ 移行候補**:

| ルールファイル | 参照頻度 | 移行判定 |
|--------------|---------|---------|
| common/coding-style.md | 高（毎回参照） | **維持** |
| common/security.md | 高（コミット前必須） | **維持** |
| common/testing.md | 中 | **維持**（TDD必須のため） |
| common/patterns.md | 低 | **移行候補** |
| common/performance.md | 低 | **移行候補** |
| common/hooks.md | 低 | **移行候補** |
| common/agents.md | 中 | **維持**（エージェント起動判定に必要） |

---

## 7. 方法論の叩き台

### 7a. スキル作成基準（いつスキル化すべきか）

**判断フロー**:

```
同一パターンが発生
  │
  ├─ 1回目: インシデントとして記録（cmd_xxxノート）
  │
  ├─ 2回目: スキル化候補としてフラグ（skill_candidate: true）
  │
  └─ 3回目以降: スキル作成を実行
```

**最低限必要な内容**:

| セクション | 必須/推奨 | 内容 |
|-----------|---------|------|
| YAMLフロントマター | 必須 | name, description（日本語、「いつ使うか」を明記） |
| 問題の本質 | 必須 | なぜこのスキルが必要か |
| パターン | 必須 | 具体的な解決パターン（コード例含む） |
| 検証方法 | 推奨 | パターンが正しく適用されたかの確認手順 |
| 実戦例 | 推奨 | 実際の cmd_xxx での適用事例 |
| エッジケース | 任意 | 注意すべき例外的状況 |

**再利用可能性の判定基準**:
1. **プロジェクト横断で適用可能か**（n8n系 → 全n8nプロジェクトで有用）
2. **時間経過で陳腐化しにくいか**（フレームワーク固有 < 設計パターン）
3. **他のエージェント（足軽）が利用可能か**（暗黙知の形式知化）

### 7b. スキル統合基準（いつ既存スキルに統合すべきか）

**統合すべき3条件**（いずれかを満たす場合）:

| 条件 | 判定方法 | 例 |
|------|---------|-----|
| 常にセットで使用 | 過去6ヶ月のcmd履歴で共起率80%以上 | docker-volume-recovery + env-audit |
| 共通前提知識が多い | 前提知識セクションの70%以上が一致 | n8n-validation-expert + n8n-node-configuration |
| 単独では小さすぎる | 100行以下で独立した価値が薄い | strategic-compact（ただし明確な目的あれば例外） |

**統合時のチェックリスト**:
- [ ] 統合後のSKILL.mdが500行以下であること
- [ ] 統合前の両スキルのdescriptionを新descriptionに反映
- [ ] 補助ファイル（examples.md等）への分離を検討
- [ ] 統合元スキルのシンボリックリンク or リダイレクトは不要（完全置換）

### 7c. スキル廃止基準（いつ廃止すべきか）

**廃止判断フロー**:

```
スキル廃止レビュー（四半期ごと推奨）
  │
  ├─ 6ヶ月以上未使用 → 廃止候補
  │     ├─ 技術スタックが現役 → archived/ に移動（復活可能）
  │     └─ 技術スタック変更済み → 削除
  │
  ├─ より優れた代替が登場 → 移行計画作成 → 移行完了後に削除
  │
  └─ 情報が古くなっている → 更新 or 廃止
```

**即時廃止候補（現時点）**:

| スキル | 廃止理由 | 推奨アクション |
|--------|---------|--------------|
| continuous-learning v1 | v2が上位互換 | 削除 |
| Java/Spring系（6件） | 実プロジェクト未使用、技術スタック不適合 | archived/に移動 |
| Django系（4件） | 実プロジェクト未使用、技術スタック不適合 | archived/に移動 |
| cpp-testing | 実プロジェクト未使用 | archived/に移動 |

**ディレクトリ構成案**:
```
skills/
├── (active skills)          # 通常のスキル群
├── archived/                # 廃止スキル（復活可能）
│   ├── java-coding-standards/
│   ├── springboot-*/
│   ├── django-*/
│   └── cpp-testing/
└── learned/                 # 自動学習スキル（CL v1/v2出力先）
```

### 7d. スキルフォーマット標準

**shogun-*スキルの標準テンプレート**:

```markdown
---
name: shogun-{topic}
description: |
  {日本語で記述。「いつ使うか」を明記。1024文字以内。}
  Use when {English summary for mixed-language contexts}.
---

# {スキル名}

## 問題の本質

{なぜこのスキルが必要か。1-3段落。}

## パターン

### パターン1: {名称}

{具体的な解決方法。コード例含む。}

### パターン2: {名称}（あれば）

{...}

## 検証方法

{パターンが正しく適用されたかの確認手順}

## 実戦例

| cmd | 状況 | 適用結果 |
|-----|------|---------|
| cmd_xxx | {状況} | {結果} |

## 出典

- cmd_xxx: {概要}
```

**必須セクション**: 問題の本質、パターン（最低1つ）
**推奨セクション**: 検証方法、実戦例、出典
**言語方針**: 本文は日本語。コード例・技術用語は英語のまま。descriptionは日本語主体＋英語要約1行。

### 7e. スキル作成ツールの活用方針

| ツール | 役割 | 稼働判定 | 備考 |
|--------|------|---------|------|
| /skill-create | Git履歴からの初期スキル生成 | **稼働推奨** | 新プロジェクト参入時に1回実行 |
| /learn | 手動パターン抽出 | **即時稼働** | インシデント解決後に随時実行 |
| CL v2 + /evolve | 自動パターン検出→進化 | **評価後に判断** | API消費コスト算出が先 |
| CL v1 | セッション終了時の自動抽出 | **廃止** | v2が上位互換 |

**shogun-*スキル（手動作成）との役割分担**:
- **手動作成（shogun-*）**: 重要インシデントの深い知見。品質保証あり。
- **/learn**: 中程度の知見の迅速な保存。後でshogun-*に昇格可能。
- **/skill-create**: プロジェクト横断パターンの初期検出。精査が必要。
- **CL v2**: 無意識的パターンの自動検出。instinctレベル。evolveで昇格。

### 7f. Context Window管理戦略

**rules/ → skills/ 移行の判断基準**:

| 基準 | ルール維持 | スキル移行 |
|------|-----------|-----------|
| 参照頻度 | 毎セッション必要 | 特定タスクでのみ必要 |
| 強制度 | 違反不可の制約 | 推奨・ガイダンス |
| サイズ | 50行以下 | 50行超 |
| 例 | security.md, coding-style.md | patterns.md, performance.md, hooks.md |

**description最適化ガイドライン**:
1. **1行目に「Use when...」を配置**（Claude自動判定の精度向上）
2. **具体的なキーワードを含める**（「n8n Code node error」等）
3. **不要な修飾を削除**（「This comprehensive skill...」→不要）
4. **400文字以内を目標**（制限1,024文字だが短い方がContext効率的）
5. **未使用スキルのdescription削除は不可**（削除するならスキルごと廃止）

**モニタリング方法**:
```bash
# description合計文字数の確認（定期実行推奨）
grep -r "^description:" ~/.claude/skills/*/SKILL.md ~/.claude/skills/shogun-*.md | \
  sed 's/.*description: //' | wc -c
```

---

## 8. 推奨アクション

### 短期（1-2週間）

| # | アクション | 優先度 | 工数 | 効果 |
|---|-----------|--------|------|------|
| S1 | /learn コマンドの即時活用開始 | **高** | 極小 | インシデント知見の保存が即座に始まる |
| S2 | CL v1 スキルの廃止 | **高** | 極小 | 不要資産の整理、混乱防止 |
| S3 | 未使用スキル（Java/Spring/Django/C++）のarchived/移動 | **高** | 小 | Context Window圧迫軽減（推定11スキル分） |
| S4 | shogun-*スキルのdescription品質向上 | **中** | 小 | Claude自動起動判定の精度向上 |

### 中期（1-2ヶ月）

| # | アクション | 優先度 | 工数 | 効果 |
|---|-----------|--------|------|------|
| M1 | shogun-*スキルのディレクトリ形式移行 | **中** | 中 | フォーマット統一、補助ファイル追加可能 |
| M2 | rules/ の3ファイル（patterns/performance/hooks）をskills/に移行 | **中** | 中 | Context Window常駐データ削減 |
| M3 | /skill-create の試験実行 | **中** | 小 | Git履歴からの隠れたパターン発見 |
| M4 | n8n系スキルの重複レビュー（4ペア） | **中** | 中 | 統合によるスキル数削減 |
| M5 | 出典cmd不明スキル（6件）のトレーサビリティ調査 | **低** | 小 | スキルの信頼性向上 |

### 長期（3ヶ月以降）

| # | アクション | 優先度 | 工数 | 効果 |
|---|-----------|--------|------|------|
| L1 | CL v2 セットアップ評価（API消費コスト算出） | **中** | 中 | 自動学習システムの稼働判断 |
| L2 | スキル廃止レビューの四半期実施プロセス確立 | **低** | 小 | 継続的な品質維持 |
| L3 | description合計文字数モニタリングの自動化 | **低** | 小 | Context Window超過の早期検知 |
| L4 | CLAUDE.md の150行以内への圧縮検討 | **低** | 中 | Context Window効率化 |

---

## 付録: 達成基準チェック

| # | 基準 | 状態 |
|---|------|------|
| 1 | 現状の問題点が7項目（a-g）全て分析されている | 完了（§6 a-g） |
| 2 | 方法論の叩き台が6項目（a-f）全て提案されている | 完了（§7 a-f） |
| 3 | 推奨アクションが優先度付きで提示されている | 完了（§8 短期/中期/長期） |
| 4 | 143a/143bの調査結果が適切に引用・統合されている | 完了（各セクションに出典明記） |
| 5 | 出力先が output/cmd_143_skill_methodology_research.md である | 完了 |
