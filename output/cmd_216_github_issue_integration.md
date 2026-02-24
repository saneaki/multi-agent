# Notionタスク完了→GitHub Issue統合 設計レポート

---

## 1. 既存WFの現状分析

### 1.1 WF概要

| 項目 | 内容 |
|------|------|
| WF名 | 案件タスク完了→対応履歴同期 Webhook版 v2.0 |
| WF ID | XjYci5rlyNx2ckcD |
| トリガー | Webhook POST /notion-task-sync |
| ノード数 | 15 |
| 主な処理 | NotionタスクDB完了イベントを受信し、案件ページの「対応履歴」トグルにタスク内容を追記 |

**役割の整理:**
- Notionタスクは「いつまでに何をやるか」の実行記録
- 対応履歴は案件ページへの時系列ログ（完了済み作業の蓄積）
- 本WFはタスク完了を検知して対応履歴に自動転記する仕組み

---

### 1.2 フロー図（テキスト形式）

```
[Webhook受信]
  POST /notion-task-sync
       │
       ▼
[即座に200返却]  ←── 処理の遅延がクライアントに影響しないようにする
       │
       ▼
[タスクデータ抽出]
  - taskPageId      : NotionタスクページID
  - taskTitle       : タスク名
  - casePageId      : 紐付け案件ページID
  - completedAt     : 完了日時
       │
       ▼
[有効タスク判定]
  taskPageId AND casePageId が存在するか?
       │
  ┌────┴────┐
 YES       NO
  │         │
  ▼        終了
[タスク本文ブロック取得]
  GET /blocks/{taskPageId}/children
       │
       ▼
[ブロック変換]
  - コピー不可ブロック除去（DB埋め込み等）
  - ブロックIDをリセット（新規追記用）
       │
       ▼
[案件ページブロック取得]
  GET /blocks/{casePageId}/children
       │
       ▼
[対応履歴トグル検索]
  heading_1「対応履歴」を探す
       │
  ┌────┴──────┐
 存在する    存在しない
  │               │
  │          [対応履歴トグル作成]
  │               │
  └────┬──────┘
       ▼
[ブロックID取得（Merge）]
  対応履歴トグルのブロックIDを確定
       │
       ▼
[追記ペイロード構築]
  heading_3 トグル（タスクタイトル・完了日付）
  └── タスク本文ブロック群
       │
       ▼
[対応履歴に追記]
  PATCH /blocks/{toggleBlockId}/children
       │
       ▼
[案件同期ステータス更新]
  Notionタスクページのステータスプロパティを更新
       │
       ▼
[終了]
```

---

### 1.3 現状の課題・拡張余地

**現状の課題:**

| # | 課題 | 影響 |
|---|------|------|
| C1 | 対応履歴はNotionの閲覧者に閉じており、技術的な問題追跡・ナレッジ化がしづらい | ノウハウが案件ページに埋もれる |
| C2 | 「なぜこの対応をしたか」の論点・判断根拠がタスク記録に含まれない | 後日の振り返りで文脈が失われる |
| C3 | 案件横断的なパターン検索・タグ検索ができない | 類似案件への応用が困難 |
| C4 | 外部協力者（弁護士仲間・専門家等）との課題共有手段がない | 知識交換の制約 |

**拡張余地:**

- 既存WFの出力（追記完了イベント）をトリガーとしてGitHub Issue作成を連鎖させる
- Notionタスク完了Webhookを複数WFで並列処理する構成が可能
- GitHubのラベル・マイルストーン・プロジェクトとNotionの案件IDを紐付けることで双方向追跡が実現できる

---

## 2. GitHub Issue統合の方向性（3案比較）

### 案A: 案件単位Issue（1案件=1Issue）

**概要:** 案件が開始された時点でGitHub Issueを1件作成する。タスク完了イベントごとにIssueのコメントを追記する。

#### Issue粒度と作成タイミング

- 粒度: **案件単位**（1案件=1Issue）
- 作成タイミング: Notionで案件が「受任」ステータスになった時点（別途受任トリガーWF必要）
- タスク完了時: Issueに**コメント追記**（本文は変更しない）

#### Issueテンプレート

```markdown
タイトル:
[{案件ID}] {案件名}（依頼者: {依頼者名}）

本文:
## 案件概要
- **案件ID**: {caseId}
- **依頼者**: {clientName}
- **案件種別**: {caseType}（例: 交通事故、相続、契約紛争）
- **受任日**: {retainedAt}
- **担当弁護士**: {attorney}
- **Notion案件ページ**: {notionCaseUrl}

## 争点・論点（随時更新）
（受任時点では空欄。作業を通じてコメントで蓄積）

## ステータス
- [ ] 受任
- [ ] 証拠収集
- [ ] 交渉・主張
- [ ] 解決・終結

ラベル: case/{caseType}, status/active
```

**タスク完了時のコメント追記フォーマット:**

```markdown
### ✅ タスク完了: {taskTitle}
- **完了日時**: {completedAt}
- **Notionタスク**: {notionTaskUrl}

#### 実施内容
{taskBodyBlocks（Markdown変換済み）}
```

#### 自動化方法

```
Notionタスク完了Webhook
  → 新規WF「GitHub Issue コメント追記」
      ├── タスクデータ抽出（既存WFと同じロジック）
      ├── Notionプロパティから案件IssueNumberを取得
      ├── GitHub API: POST /repos/{owner}/{repo}/issues/{issue_number}/comments
      └── 完了
```

#### メリット・デメリット

| | 内容 |
|---|------|
| + | 案件の全履歴が1 Issue に集約される |
| + | GitHub Projects のカンバンで案件進捗管理ができる |
| + | Issue番号で案件を一意識別できる |
| - | 長期案件でコメントが大量になりノイズが増える |
| - | 案件開始時の別途トリガーWFが必要（受任Webhook追加） |
| - | 論点・技術的考察が対応記録コメントに埋もれやすい |

---

### 案B: タスク完了イベント単位Issue（タスク完了ごとに自動作成）

**概要:** タスクが完了するたびに自動的にGitHub Issueを1件作成する。最も自動化の度合いが高い。

#### Issue粒度と作成タイミング

- 粒度: **タスク単位**（1タスク完了=1Issue）
- 作成タイミング: Notionタスクの「完了」ステータス変更をトリガー（既存WFと同じタイミング）
- フィルタリング: 「Issue対象」ラベルが付いているタスクのみ

#### Issueテンプレート

```markdown
タイトル:
[{案件ID}] {taskTitle}（完了: {completedAt|YYYY-MM-DD}）

本文:
## タスク情報
- **案件**: [{caseName}]({notionCaseUrl})（案件ID: {caseId}）
- **完了日時**: {completedAt}
- **担当**: {assignee}
- **Notionタスク**: {notionTaskUrl}

## 実施内容
{taskBodyBlocks（Markdown変換済み）}

ラベル: case/{caseType}, task/completed
```

#### 自動化方法

```
Notionタスク完了Webhook（既存と同一）
  → 新規WF「タスク完了→GitHub Issue作成」
      ├── タスクデータ抽出
      ├── Issue作成フィルタ判定（「Issue対象」フラグ）
      │     NO → スキップ
      │     YES → 続行
      ├── GitHub API: POST /repos/{owner}/{repo}/issues
      ├── Issue URLをNotionタスクページに書き戻し
      └── 完了
```

#### 既存WFへの統合方法

**新規WF追加（既存WF改修なし）。** WF1末尾からHTTP Requestで内部Webhook呼び出し:

```
WF1の最終ノード後 → HTTP Request → POST /notion-task-sync-github（WF2のエンドポイント）
```

#### メリット・デメリット

| | 内容 |
|---|------|
| + | 既存WFのトリガーをそのまま流用できる |
| + | タスクの粒度で問題追跡でき検索・フィルタがしやすい |
| - | 完了タスクごとにIssueが増えすぎる（月10件→年120件） |
| - | 全タスクがIssue化されると技術的考察と事務作業が混在する |
| - | フィルタ判定基準の設計が必要 |

---

### 案C: 論点・問題単位Issue（手動起点+n8n自動補完）【推奨】

**概要:** 法的論点・技術的問題・判例調査など「考察が必要な課題」はNotionで手動フラグを立て、n8nがGitHub Issueを自動生成する。最も粒度が適切で弁護士業務に合致する。

#### Issue粒度と作成タイミング

- 粒度: **論点・問題単位**（法的課題、判断が必要な事項、再利用可能なナレッジ）
- 作成タイミング: Notionタスクに「GitHub Issue作成」チェックボックスを追加し、チェック時にトリガー
- タスク完了とは独立して発火（進行中のタスクでも論点が明確になった時点で作成可能）

#### Issueテンプレート

```markdown
タイトル:
[{caseType}][{論点種別}] {issueSummary}

例:
[相続][遺留分] 代襲相続人が遺留分を主張できる範囲について

本文:
## 案件コンテキスト（非公開情報は除く）
- **関連案件ID**: {caseId}（GitHub上は匿名化可能）
- **発生状況**: {backgroundContext}
- **Notionリンク**: {notionTaskUrl}（アクセス制限付き）

## 論点・問題の定義
{issueSummary}

## 現時点での検討内容
{taskBodyBlocks（Markdown変換済み）}

## 参照判例・条文
（手動追記またはタスクのリンクブロックから自動抽出）

## 解決策候補
- [ ] 候補1:
- [ ] 候補2:

## 参考文献・リソース
（URLリンクブロックがあれば自動取得）

ラベル: legal/{caseType}, issue-type/{論点種別}, status/open
```

**論点種別ラベル候補:**
- `issue-type/legal-argument`（法的主張）
- `issue-type/evidence`（証拠評価）
- `issue-type/procedure`（手続き問題）
- `issue-type/precedent`（判例調査）
- `issue-type/settlement`（和解検討）
- `issue-type/knowledge`（ナレッジ化）

#### 自動化方法

```
Notionタスクの「GitHub Issue作成」チェックON
  → Notionプロパティ編集Webhook（/notion-issue-trigger）
      ├── タスクデータ抽出
      ├── issueSummaryフィールド取得
      ├── タスク本文ブロック取得（Notion API）
      ├── URLリンクブロック抽出（参考文献候補）
      ├── 個人情報・依頼者名の匿名化処理（オプション）
      ├── GitHub API: POST /repos/{owner}/{repo}/issues
      ├── NotionタスクページにIssue URL書き戻し
      └── 完了
```

#### 既存WFへの統合方法

**完全独立の新規WF。** 既存WFとはトリガーエンドポイントも異なる。

| WF | エンドポイント | トリガー条件 | 処理 |
|---|---|---|---|
| WF1（既存） | /notion-task-sync | タスク完了ステータス変更 | 対応履歴同期 |
| WF2（新規） | /notion-issue-trigger | 「GitHub Issue作成」チェックON | GitHub Issue作成 |

#### メリット・デメリット

| | 内容 |
|---|------|
| + | 弁護士の判断で意味のある論点のみIssue化される（ノイズなし） |
| + | 案件情報の匿名化処理を挟む余地がある（機密保持） |
| + | 法的ナレッジとして再利用可能なIssueが蓄積される |
| + | 依頼者情報を含まない純粋な法的論点として整理できる |
| - | 手動チェックが必要なため、多忙時に記録漏れが起きる |
| - | 「論点サマリ」フィールドを別途Notionに追加する必要がある |
| - | Issue化の判断基準を最初に設計する必要がある |

---

## 3. 比較表

| 観点 | 案A（案件単位） | 案B（タスク単位） | 案C（論点単位） |
|------|--------------|----------------|----------------|
| **Issue粒度** | 粗い（1案件=1 Issue） | 細かい（1タスク=1 Issue） | 適切（1論点=1 Issue） |
| **作成トリガー** | 受任時（新規WF必要） | タスク完了時（既存WFと同一） | 手動チェック（独立WF） |
| **自動化度** | 中（受任WF追加必要） | 高（完全自動） | 中（手動判断+自動生成） |
| **ノイズリスク** | 低（Issue数は案件数） | 高（全タスクでIssue増加） | 低（必要な論点のみ） |
| **ナレッジ蓄積** | 弱（案件記録として混在） | 弱（タスク記録が主） | 強（論点・考察が中心） |
| **機密保持** | 要注意（案件名がタイトル） | 要注意（タスク名が露出） | 匿名化処理が組み込みやすい |
| **既存WF改修** | 不要 | 不要（連鎖呼び出し推奨） | 不要（完全独立） |
| **Notion追加設計** | 案件ページにIssue番号フィールド | タスクページにIssue URLフィールド | タスクページにチェックボックス+論点サマリフィールド |
| **法的業務適合度** | 中 | 低 | **高** |

---

## 4. 推奨案と実装ロードマップ

### 4.1 推奨案と理由

**推奨: 案C（論点・問題単位Issue）をベースに、案Bの自動連鎖を部分採用するハイブリッド構成**

**推奨理由:**

1. **弁護士業務の本質に合致する**: 弁護士業務において価値のある記録は「何を完了したか」ではなく「何を考え、どう判断したか」である。論点単位のIssueはまさにこの目的に合致する。

2. **機密保持が設計段階で組み込める**: 案件名・依頼者名を匿名化してからIssue化する処理を標準フローに入れることで、公開リポジトリでも運用できる余地が生まれる。

3. **ノイズを防げる**: 月10〜20件のタスクが全て自動でIssue化されると、6ヶ月で100件超になる。有意義な論点のみを手動選別することで、GitHubを「法的ナレッジDB」として維持できる。

4. **既存WFへの影響ゼロ**: 完全独立の新規WFとして追加できる。既存の対応履歴同期WFは一切変更不要。

---

### 4.2 新規WF設計（案C）

**WF名:** `Notion論点フラグ→GitHub Issue作成 v1.0`

**エンドポイント:** `POST /notion-issue-trigger`

```
[Webhook受信] POST /notion-issue-trigger
       │
       ▼
[即座に200返却]
       │
       ▼
[ペイロード検証]
  taskPageId存在 + "GitHub Issue作成"=true + issueSummary非空
       │
  ┌────┴────┐
 有効       無効→終了
  │
  ▼
[タスク詳細取得] GET /pages/{taskPageId}
  → casePageId, caseType, 論点種別, 論点サマリ取得
       │
       ▼
[タスク本文ブロック取得] GET /blocks/{taskPageId}/children
       │
       ▼
[Markdown変換]
  NotionブロックをMarkdown文字列に変換
  URLリンクブロックを「参考リソース」として別途抽出
       │
       ▼
[匿名化処理（オプション）]
  依頼者名を「依頼者A」等に置換
       │
       ▼
[Issueラベル構築]
  legal/{caseType} + issue-type/{論点種別}
       │
       ▼
[GitHub Issue作成]
  POST /repos/saneaki/legal-cases/issues
       │
       ▼
[Issue URL書き戻し]
  PATCH /pages/{taskPageId} → "GitHub Issue URL"プロパティ更新
  + "GitHub Issue作成済み" チェックをON（二重防止）
       │
       ▼
[完了]
```

**必要なNotionフィールド追加（タスクDB）:**

| フィールド名 | 型 | 用途 |
|---|---|---|
| GitHub Issue作成 | チェックボックス | Webhookトリガー条件 |
| GitHub Issue作成済み | チェックボックス | 二重作成防止フラグ |
| 論点サマリ | テキスト | IssueタイトルのSuffix |
| 論点種別 | セレクト | Issueラベル用 |
| GitHub Issue URL | URL | 作成後のIssue URLを保存 |

---

### 4.3 段階的導入ステップ

**Phase 1: 基盤整備（Week 1〜2）**

```
Step 1: GitHubリポジトリ作成
  - saneaki/legal-cases を作成（Privateリポジトリ推奨）
  - ラベル一式を作成（legal/*, issue-type/*, status/*）
  - Issueテンプレートを .github/ISSUE_TEMPLATE/ に配置

Step 2: NotionタスクDBフィールド追加
  - 上記5フィールドを追加
  - テスト用タスク3〜5件で動作確認

Step 3: n8nシークレット登録
  - GitHub Personal Access Token を n8n Credentials に登録
  - スコープ: repo（Privateリポジトリの場合）
```

**Phase 2: WF実装（Week 2〜3）**

```
Step 4: 新規WF作成（/notion-issue-trigger）
  - Webhookノード追加（responseMode: lastNode or immediately）
  - Notion APIノードでタスク詳細取得
  - Markdown変換ロジック（Codeノード）
  - GitHub APIノードでIssue作成（httpRequest推奨）
  - Notion API書き戻しノード

Step 5: NotionでWebhook URL登録
  - タスクDBの「GitHub Issue作成」プロパティ編集時にトリガー設定

Step 6: テスト実行
  - ダミータスクでE2E動作確認
```

**Phase 3: 運用開始（Week 4〜）**

```
Step 7: 実案件への適用
  - 過去の重要論点をさかのぼってIssue化（手動）
  - 新規タスクからフラグ運用開始

Step 8: Phase 2検討（案Bハイブリッド）
  - タスク完了時に「論点化候補」ntfy通知を出すか評価
```

---

## 5. n8n実装メモ（技術的詳細）

### 5.1 GitHub APIでIssue作成

```
POST https://api.github.com/repos/{owner}/{repo}/issues
Authorization: Bearer {GITHUB_TOKEN}
Content-Type: application/json

{
  "title": "[相続][遺留分] 代襲相続人が遺留分を主張できる範囲について",
  "body": "## 案件コンテキスト\n...",
  "labels": ["legal/inheritance", "issue-type/legal-argument"],
  "assignees": ["saneaki"]
}
```

**n8nノード推奨:** `n8n-nodes-base.httpRequest`（JSON body完全制御可能）

**Issue作成後のレスポンスから取得:** `html_url` をNotionに書き戻す。

### 5.2 Notionペイロードから抽出すべきフィールド

```javascript
// n8n Codeノード（ペイロード抽出）
const page = $input.item.json.page;
const props = page.properties;

const taskPageId = page.id;
const taskTitle = props['名前']?.title?.[0]?.plain_text ?? '（タイトルなし）';
const casePageId = props['案件']?.relation?.[0]?.id ?? null;
const isIssueTarget = props['GitHub Issue作成']?.checkbox ?? false;
const isAlreadyCreated = props['GitHub Issue作成済み']?.checkbox ?? false;
const issueSummary = props['論点サマリ']?.rich_text?.[0]?.plain_text ?? '';
const issueType = props['論点種別']?.select?.name ?? 'general';
const completedAt = props['完了日']?.date?.start ?? new Date().toISOString().split('T')[0];

if (!taskPageId || !casePageId || !isIssueTarget || isAlreadyCreated || !issueSummary) {
  return [{ json: { skip: true } }];
}

return [{ json: { taskPageId, taskTitle, casePageId, issueSummary, issueType, completedAt } }];
```

### 5.3 NotionブロックのMarkdown変換

```javascript
function blocksToMarkdown(blocks) {
  return blocks.map(block => {
    const type = block.type;
    const getText = (arr) => (arr || []).map(t => t.plain_text).join('');
    switch (type) {
      case 'paragraph':       return getText(block.paragraph.rich_text) + '\n';
      case 'heading_1':       return `# ${getText(block.heading_1.rich_text)}\n`;
      case 'heading_2':       return `## ${getText(block.heading_2.rich_text)}\n`;
      case 'heading_3':       return `### ${getText(block.heading_3.rich_text)}\n`;
      case 'bulleted_list_item': return `- ${getText(block.bulleted_list_item.rich_text)}`;
      case 'numbered_list_item': return `1. ${getText(block.numbered_list_item.rich_text)}`;
      case 'code':
        const lang = block.code.language || '';
        return `\`\`\`${lang}\n${getText(block.code.rich_text)}\n\`\`\`\n`;
      case 'quote':           return `> ${getText(block.quote.rich_text)}\n`;
      case 'divider':         return '---\n';
      case 'bookmark':
      case 'link_preview':
        return block[type]?.url ? `- ${block[type].url}` : '';
      default: return '';
    }
  }).filter(Boolean).join('\n');
}
```

---

## 参考

**GitHub API:**
- Issues作成: `POST /repos/{owner}/{repo}/issues`
- Issueコメント追加: `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`
- 必要スコープ: `repo`（privateリポジトリの場合）

**推奨リポジトリ構成（saneaki/legal-cases）:**

```
.github/
  ISSUE_TEMPLATE/
    legal-argument.md      # 法的論点テンプレート
    evidence-review.md     # 証拠評価テンプレート
    precedent-research.md  # 判例調査テンプレート
  labels.yml               # ラベル一覧
README.md
```

**Notionのポイント:**
- Webhookトリガー: プロパティ編集時（有料プランのオートメーション機能）
- Formula型で `concat("[", prop("案件種別"), "][", prop("論点種別"), "] ", prop("論点サマリ"))` としてIssueタイトル候補を自動生成可能

---
*作成日: 2026-02-23 | cmd_216*
