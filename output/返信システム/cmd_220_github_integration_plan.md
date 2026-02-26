# GitHub案件管理統合 実装計画書

> 作成日: 2026-02-23 | 出典: cmd_215〜219の議論・設計・実装経験
> ステータス: Phase 1 着手待ち（殿の手動作業が起点）

---

## 1. 概要・目的

### ビジョン

弁護士事務所の業務情報を**3ツールで役割分担**し、自動連携によって「入力一回・活用多数」を実現する。

### 3ツール役割分担（最終形）

| ツール | 役割 | 特徴 |
|--------|------|------|
| **Notion** | 案件・タスク管理、スケジュール、担当者 | 非技術者向けUI、セレクト・リレーション・数式 |
| **GDrive** | 法律文書、証拠資料、成果物の保管 | Office連携、大容量、共有リンク |
| **GitHub** | ナレッジ蓄積、論点・課題追跡、Tech情報 | Issues/Projects/Wiki、検索性、API、バージョン管理 |

### 情報フロー（最終形）

```
Notionタスク「状態」=「Issue」
  ↓ n8n WF（案件同期+GitHub Issue v2.0）自動トリガー
GitHub Issues に論点・課題を自動作成
  ↓
Notionタスクに Issue URL 書き戻し（双方向リンク）
  ↓ 自動
Notionタスク「状態」=「Issue作成」（完了）

Notion TipsDB
  ↓ n8n Wiki同期WF（週次）
GitHub Wiki に業務Tipsを自動同期

GitHub Issues
  ↓ GitHub Projects（自動追加）
案件別ボードで進捗可視化
```

---

## 2. 現状分析

### 実装済み

| 項目 | 内容 |
|------|------|
| WF | `案件同期+GitHub Issue v2.0` (ID: TDsEGyC8XHFAQEZb, **active=false**) |
| 機能 | Notionステータス「Issue」→ 案件DB同期 + GitHub Issue作成 → Notionステータスを「Issue作成」に自動変更 |
| GitHub対象 | saneaki/n8n（Privateリポジトリ、Issues有効） |
| ラベル | `auto-created` のみ |
| Notionステータス | 「Issue」「Issue作成」**未追加**（殿の手動作業待ち） |

### 🚨 未完了事項（殿の手動作業待ち）

1. **NotionタスクDBの「状態」プロパティに「Issue」「Issue作成」を追加** （優先度: 最高）
2. **WF `TDsEGyC8XHFAQEZb` を active=true に変更** （上記完了後）
3. **リポジトリ移行**: saneaki/n8n → saneaki/legal-cases（将来）

### 参考レポート

- `output/cmd_215_github_case_management.md` — GDrive vs GitHub比較（278行）
- `output/cmd_216_github_issue_integration.md` — 統合設計（584行）、3案比較

---

## 3. ラベル設計

### ラベル体系

| カテゴリ | ラベル例 | 色 | Notionプロパティ対応 |
|---------|---------|-----|---------------------|
| **案件名** | `案件:池内久美子` `案件:田中建設` | 青 (#0075ca) | 案件DB名（リレーション） |
| **種別** | `論点` `手続き` `調査` `システム` | 緑 (#0e8a16) | タスク内容（select型） |
| **優先度** | `優先:高` `優先:中` `優先:低` | 赤/橙/黄 | （手動設定） |
| **状態** | `進行中` `保留` `要確認` | 橙 (#e4e669) | Notionステータスから連動 |
| **自動生成** | `auto-created` | グレー (#ededed) | WFで自動付与 |

### NotionプロパティとGitHubラベルのマッピング

```
Notion「タスク内容」（select型）→ 種別ラベル
  論点調査   → label: 論点
  手続き     → label: 手続き
  書類作成   → label: 調査
  システム   → label: システム
  （その他） → label: auto-created のみ

Notion「案件」（relation型）→ 案件名ラベル
  案件名を取得して「案件:{名前}」ラベルを生成

自動付与（常時）→ label: auto-created
```

### 初期ラベルセットアップ（Phase 1 殿の手動作業）

GitHub UI (`Settings > Labels`) で以下を作成:

```
auto-created    #ededed
論点            #0e8a16
手続き          #0e8a16
調査            #0e8a16
システム        #0e8a16
優先:高         #d93f0b
優先:中         #fbca04
優先:低         #e4e669
進行中          #e4e669
要確認          #d93f0b
```

---

## 4. 実装フェーズ

### Phase 1: 基盤整備【現在地】

**目標:** WFを実際に動かせる状態にする

| アクション | 担当 | 工数 |
|-----------|------|------|
| NotionタスクDBに「Issue」「Issue作成」ステータス追加 | **殿（手動）** | 5分 |
| WF TDsEGyC8XHFAQEZb を active=true に変更 | **殿（手動）** | 2分 |
| GitHubラベル初期セットアップ（10ラベル） | **殿（手動）** | 10分 |
| 動作テスト（Notionタスクのステータスを「Issue」に変更→Issue作成確認） | 家老 | 自動 |

**完了条件:** Notionで「Issue」セット → GitHub Issueが自動作成される

---

### Phase 2: WF拡張（ラベル自動付与）

**目標:** Issue作成時に適切なラベルを自動付与する

**担当:** 足軽（cmd_221として発令予定）

**実装内容:**

```
WF「案件同期+GitHub Issue v2.0」の修正:

1. タスクデータ抽出コードに案件名取得を追加
   - Notion APIで案件ページ名を取得
   - 案件名ラベル「案件:{名前}」を生成

2. GitHub Issueペイロード構築ノードを修正
   - labels配列に案件名ラベル + 種別ラベル + auto-created を追加

3. ラベルマッピング（Code ノード内）:
   const taskContentToLabel = {
     '論点調査': '論点',
     '手続き': '手続き',
     '書類作成': '調査',
     'システム': 'システム'
   };
   const labels = ['auto-created'];
   if (taskContentToLabel[taskContent]) {
     labels.push(taskContentToLabel[taskContent]);
   }
   if (casePageName) {
     labels.push(`案件:${casePageName}`);
   }
```

**受入基準:**
- Issue作成時に3種のラベルが自動付与される
- 既存WF（XjYci5rlyNx2ckcD）変更なし

---

### Phase 3: GitHub Projects設定

**目標:** 案件別ボードでIssueを可視化する

**担当:** 殿（手動）+ WF拡張（必要に応じて）

**実装内容:**

```
GitHub Projects（Classic or New）:
  プロジェクト名: 「{事務所名} 案件管理」
  ビュー構成:
    - 案件別ボード（案件名ラベルでフィルタ）
    - 種別別リスト（論点/手続き/調査でフィルタ）
    - 未完了一覧（open Issues）
    - 今週完了（クローズ日フィルタ）
```

**WF連携（Phase 3後半）:**
GitHub API `POST /repos/{owner}/{repo}/issues/{issue_number}/projects` でIssue→Project自動追加（将来）

---

### Phase 4: GitHub Wiki同期（Notion TipsDB → Wiki）

**目標:** Notionで管理している業務Tipsを GitHub Wiki に自動同期する

**担当:** 足軽（cmd_222として発令予定）

**実装内容（新規WF）:**

```
WF名: 「Notion TipsDB → GitHub Wiki 同期 v1.0」
Schedule Trigger: 毎週月曜 09:00 JST

フロー:
Notion TipsDB全件取得
  ↓ Code: MarkdownフォーマットをGitHub Wiki用に変換
  ↓ GitHub API: GET /repos/{owner}/{repo}/contents/{path} で既存確認
  ↓ GitHub API: PUT /repos/{owner}/{repo}/contents/{path} でページ更新
    （新規: ファイル作成、既存: SHA取得して上書き）
```

**注意事項:**
- GitHub Wiki は git リポジトリ（{repo}.wiki.git）として管理される
- API経由での更新: `PUT /repos/{owner}/{repo}/contents/{file}` はWikiには使えない
- Wiki更新は GitHub Contents API の wiki 用エンドポイントを使用:
  `POST /repos/{owner}/{repo}/git/blobs` + `trees` + `commits` + `refs`
  または、git clone + push でも実現可能

**代替案（シンプル版）:**
Wiki更新が複雑な場合は、Discussions（GitHub Discussions）を代替に検討。
API: `POST /repos/{owner}/{repo}/discussions`

---

## 5. 殿の手動作業 vs WF自動化 区分

### 殿の手動作業（Phase 1）

```
□ NotionタスクDB「状態」プロパティに追加:
    「Issue」（赤系カラー推奨）
    「Issue作成」（グレー系カラー推奨）

□ n8n にログインし WF active化:
    対象WF: 案件同期+GitHub Issue v2.0 (TDsEGyC8XHFAQEZb)
    active=false → active=true に変更

□ GitHubリポジトリでラベル作成:
    github.com/saneaki/n8n/issues/labels
    （または将来の saneaki/legal-cases）
    ラベル10件を追加（前述のラベル設計参照）

□ GitHub Projects 作成:
    案件管理ボードの初期設定

□ （将来）新リポジトリ作成:
    saneaki/legal-cases として private + Issues有効で作成
```

### WF自動化（家老・足軽が担当）

```
✅ 実装済み:
  - タスクステータス「Issue」→ GitHub Issue自動作成
  - Notionにissue URL書き戻し
  - ステータスを「Issue作成」に自動変更
  - 案件DB対応履歴の同期

🔄 Phase 2（cmd_221）:
  - 案件名・種別ラベルの自動付与

🔄 Phase 4（cmd_222）:
  - Notion TipsDB → GitHub Wiki 週次同期
```

---

## 6. スケジュール案

```
2026-02-23（今日）
  └─ Phase 1着手（殿の手動作業）
     └─ Notionステータス追加 → WF active化 → ラベル設定

2026-02-23〜24
  └─ Phase 1完了テスト
     └─ 「Issue」セット → GitHub Issue自動作成 → 確認

2026-02-24〜
  └─ Phase 2（cmd_221）: WF拡張（ラベル自動付与）
     └─ 足軽が実装 → 軍師QC → 本番適用

2026-02-25〜
  └─ Phase 3: GitHub Projects初期設定（殿）

TBD
  └─ Phase 4（cmd_222）: Wiki同期WF
     └─ TipsDBの整備状況に応じて
```

---

## 7. リスクと対策

| リスク | 確率 | 対策 |
|--------|------|------|
| NotionのWebhook送信がtimeout | 低 | responseNode即時200応答が実装済み |
| GitHub API Rate Limit（60req/h未認証/5000 認証済み） | 低 | Token認証済みのため問題なし |
| Notionプロパティ名変更でWF停止 | 中 | `shogun-n8n-notion-property-sync` スキル参照 |
| リポジトリ移行時のIssue URL破損 | 中 | 移行前にNotionのIssue URLを一括更新する作業が必要 |
| GitHub Wiki API の複雑さ | 高 | Phase 4は代替案（Discussions）も検討 |
| 守秘義務（実名・案件詳細の漏洩） | 低 | Private repo + 略称ラベル + 詳細はNotionリンクで対応 |

---

## 8. 将来のリポジトリ移行計画

現在: `saneaki/n8n`（n8n開発リポジトリ兼用）
将来: `saneaki/legal-cases`（案件管理専用 private repo）

**移行トリガー:** Issue数が50件を超えた時点、または案件数が10件を超えた時点

**移行手順:**
1. `saneaki/legal-cases` を private + Issues有効で作成
2. WF の `github_repo` パラメータを変更（`saneaki/n8n` → `saneaki/legal-cases`）
3. 既存Issueを手動で移行（GitHub CLI: `gh issue list` + 再作成）
4. NotionのIssue URLを一括更新

---

## 付録: 関連ファイル

| ファイル | 内容 |
|---------|------|
| `output/cmd_215_github_case_management.md` | GDrive vs GitHub比較レポート |
| `output/cmd_216_github_issue_integration.md` | 統合設計（3案比較+推奨） |
| `output/cmd_217_implementation_notes.md` | WF v1.0実装記録 |
| `output/cmd_218_wf_fix_note.md` | WF v2.0修正記録 |

## 付録: 関連スキル

| スキル | 用途 |
|--------|------|
| `shogun-notion-github-issue-sync` | WF実装パターン |
| `shogun-n8n-wf-versioning` | WFバージョニング手順 |
| `shogun-github-issue-knowledge-base` | ラベル設計・守秘義務対策 |
| `shogun-n8n-notion-property-sync` | Notionプロパティ変更時のWF修正 |
