# n8n自動化連携調査 — Gmail + Motion → Notion

**調査対象**: 法律事務所資料一元化のためのn8nワークフロー実装
**調査日**: 2026-02-12
**担当**: 足軽1号

---

## 調査項目1: Gmail → Notion 自動連携

### 1. n8nでの実装構成

#### 推奨トリガー: Gmail Trigger

**結論**: **Gmail Trigger を推奨**

| 項目 | Gmail Trigger | IMAP Trigger |
|------|--------------|--------------|
| **信頼性** | ✅ 高い（Gmail専用最適化） | ⚠️ 低い（手動実行時のみ動作報告あり） |
| **フィルタリング** | ラベル、検索クエリ、送信者、既読状態 | 基本的なフォルダフィルタのみ |
| **認証** | OAuth2（Googleアカウント） | IMAP認証情報 |
| **添付ファイル** | バイナリデータとして取得可能 | 同様に取得可能だが処理重い |
| **ポーリング間隔** | カスタマイズ可能 | カスタマイズ可能 |

**参考資料**:
- [Gmail Trigger node documentation | n8n Docs](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.gmailtrigger/)
- [Email Trigger (IMAP) node documentation | n8n Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.emailimap/)
- [n8n Community - IMAP Email Not Triggering with Gmail](https://community.n8n.io/t/imap-email-not-triggering-with-gmail/14925)

#### ワークフロー全体構成（テキストベース）

```
[Gmail Trigger]
    ↓
[IF: 添付ファイル有無判定]
    ├─ YES → [Google Drive: Upload File] → [取得したDriveリンクを変数保存]
    └─ NO → [変数に空文字を設定]
    ↓
[IF: 件名パターンマッチ（正規表現）]
    ├─ Match → [変数: 案件名抽出]
    └─ No Match → [変数: 案件名 = "未分類"]
    ↓
[IF: 案件名が "未分類" でない]
    ├─ TRUE → [Notion: Database Item Create (案件DB)]
    └─ FALSE → [Notion: Database Item Create (未分類DB)] → [Error Workflow へ通知]
    ↓
[Stop (正常終了)]
```

**ノード詳細**:
1. **Gmail Trigger**: ポーリング間隔5分、ラベルフィルタ（例: "law-firm/inbox"）、添付ファイル自動ダウンロード有効
2. **IF (Split In Batches)**: 複数添付ファイルをループ処理
3. **Google Drive Upload**: Folder IDを環境変数で管理、ファイル名にタイムスタンプ追加
4. **Notion Database Item Create**: ページプロパティに以下を設定:
   - タイトル: メール件名
   - 当事者: 送信元メールアドレス
   - 受信日時: メール受信日
   - 添付ファイルリンク: Google DriveのURL
   - ソース: "Gmail自動連携"

### 2. 認証設定

#### Gmail OAuth2 設定手順

1. **Google Cloud Console**:
   - プロジェクト作成 → Gmail API有効化
   - OAuth 2.0クライアントID作成（アプリケーションタイプ: Webアプリケーション）
   - 承認済みリダイレクトURI: `https://<n8n-instance>/rest/oauth2-credential/callback`

2. **n8n側設定**:
   - Credentials → Create New Credential → Gmail OAuth2 API
   - Client ID / Client Secret を入力
   - Scope: `https://www.googleapis.com/auth/gmail.readonly`（読取専用推奨）
   - Connect to Google でアカウント認証

**参考資料**:
- [Gmail Trigger integrations | n8n](https://n8n.io/integrations/gmail-trigger/)

#### Notion Internal Integration 設定手順

1. **Notion側設定**:
   - [Notion Integrations ページ](https://www.notion.com/integrations) → New integration
   - Integration Name: "n8n Law Firm Automation"
   - Capabilities:
     - ✅ Read content
     - ✅ Update content
     - ✅ Insert content
     - ❌ Read comments (不要)
     - ❌ Insert comments (不要)
   - Integration Secret をコピー（一度しか表示されない）

2. **Notion ページ設定**:
   - 連携対象のデータベースページで「共有」→ 作成したIntegrationを招待

3. **n8n側設定**:
   - Credentials → Create New Credential → Notion API
   - Internal Integration Secret を入力

**重要**: n8nのNotion NodeではOAuth2認証は利用不可（2026年2月時点）。Internal Integration Token のみサポート。

**参考資料**:
- [Notion credentials | n8n Docs](https://docs.n8n.io/integrations/builtin/credentials/notion/)
- [Start building with the Notion API](https://developers.notion.com/docs/authorization)

### 3. メール→案件の紐付けロジック

#### 実装アプローチ

**優先順位**:
1. **件名パターンマッチ（最優先）**
2. 送信元アドレスによる当事者紐付け
3. Gmailラベルによる案件分類

#### 1. 件名パターンマッチ

**n8n IF Node 設定例**:
```javascript
// Expression (Function Item モード)
const subject = $json.subject || '';
// 正規表現: 【案件名】プレフィックスを抽出
const match = subject.match(/^【(.+?)】/);
if (match) {
  return { caseName: match[1] };
} else {
  return { caseName: '未分類' };
}
```

**設定場所**: IF Node → Conditions → Expression

#### 2. 送信元アドレス紐付け

**実装方法**:
- Notion DB に「当事者マスタ」を作成（Email / 氏名 / 案件ID）
- n8n Notion Node で `Database: Query a database` → Filter by Email
- マッチした場合、案件IDを取得して紐付け

#### 3. Gmailラベル活用

**Gmail Trigger設定**:
- Label Names: `law-firm/case-A`, `law-firm/case-B` など
- ラベル名から案件名を抽出（スラッシュ以降を取得）

### 4. 添付ファイル処理

#### フロー図

```
[Gmail Trigger: 添付ファイルをバイナリデータで取得]
    ↓
[IF: 添付ファイル存在確認]
    ↓ (YES)
[Loop: 各添付ファイルを処理（Split In Batches）]
    ↓
[Code Node: ファイル名にタイムスタンプ追加]
    例: "契約書.pdf" → "契約書_20260212_1030.pdf"
    ↓
[Google Drive: Upload a File]
    - File: {{$binary.attachment}}
    - Name: {{$json.timestampedFileName}}
    - Parents: {{$env.GDRIVE_LAW_FOLDER_ID}}
    ↓
[Code Node: DriveリンクURLを配列に追加]
    ↓
[Notion: Create Database Item]
    - Property "添付ファイル": DriveリンクURLを改行区切りで設定
```

#### バイナリデータ処理の注意点

**ファイルサイズ別推奨**:
- **< 10MB**: デフォルトモード（メモリ内処理）
- **10-50MB**: Filesystem モード（n8n設定で `EXECUTIONS_DATA_SAVE_ON_SUCCESS=none`）
- **50-200MB**: Filesystem + タイムアウト延長（`EXECUTIONS_TIMEOUT=600`）
- **> 200MB**: S3モード推奨（`EXECUTIONS_DATA_PRUNE=true`）

**参考資料**:
- [n8n Binary Data: The Complete Guide](https://logicworkflow.com/blog/n8n-binary-data/)
- [Binary data | n8n Docs](https://docs.n8n.io/data/binary-data/)

#### Google Drive連携ノード設定

**Google Drive Node**:
- Operation: `Upload a File`
- Binary Data: `attachment`（Gmail Triggerが設定）
- File Name: `{{$json.fileName}}`
- Parents: Folder IDを環境変数で管理（例: `{{$env.GDRIVE_FOLDER_ID}}`）

### 5. エラーハンドリング

#### エラー戦略

**n8n Error Workflow 構成**:
```
[Error Trigger: 対象ワークフローID指定]
    ↓
[Code Node: エラー詳細を整形]
    ↓
[IF: エラータイプ判定]
    ├─ "紐付け失敗" → [Notion: 未分類DBに追加] → [Slack通知]
    ├─ "API Rate Limit" → [Wait 60s] → [Retry元ワークフロー]
    └─ "その他" → [Slack通知 + メール通知]
```

**エラー分類**:
1. **紐付け失敗**: 案件名抽出不可 → 未分類フォルダへ自動振り分け
2. **Notion API Rate Limit**: 3req/sec制限 → Exponential Backoff（1s, 2s, 5s, 13s）+ Jitter ±20%
3. **Gmail API Quota超過**: 1日1億リクエスト上限（実質ほぼ到達しない）
4. **Binary Data処理失敗**: ファイルサイズ超過 → エラーログ + Slack通知

**Retry設定（各ノード共通）**:
- Retry on Fail: `ON`
- Max Tries: `3`
- Wait Between Tries: `1000ms` (初回)
- Exponential Backoff: `ON`

**参考資料**:
- [Error handling | n8n Docs](https://docs.n8n.io/flow-logic/error-handling/)
- [n8n Error Handling: Best Practices](https://n8n-tutorial.com/tutorials/n8n/error-handling-and-debugging/n8n-error-handling-best-practices/)

---

## 調査項目2: Motion → Notion 同期

### 1. Motion API の有無と仕様

#### ✅ 公式API提供あり

**Motion REST API** が正式提供されています（2026年2月時点）。

**公式ドキュメント**: [https://docs.usemotion.com/](https://docs.usemotion.com/)

#### 認証方式

**API Key認証**:
1. Motion設定画面 → Settings タブ → API Key作成
2. API Keyは一度だけ表示されるため、即座にコピー必須
3. リクエストヘッダーに `X-API-Key: <your_api_key>` を付与

**OAuth2**: Motion APIはAPI Key認証のみ。OAuth2は非対応。

**参考資料**:
- [Getting started - Motion API](https://docs.usemotion.com/cookbooks/getting-started/)
- [Motion API Docs](https://docs.usemotion.com/)

#### 利用可能なエンドポイント

| カテゴリ | 操作 |
|---------|------|
| **Tasks** | Create, Read, Update, Delete, List, Move, Unassign |
| **Projects** | Get, List, Create |
| **Comments** | Retrieve, Create |
| **Custom Fields** | Full CRUD（Projects/Tasks用） |
| **Recurring Tasks** | Create, List, Delete |
| **Users** | List, Get Current User |
| **Workspaces** | List |
| **Schedules** | Retrieve |
| **Statuses** | Access |

**重要**: タスク取得・作成・更新が可能 → Notion同期に必要な機能は揃っている。

#### レート制限

| プラン | レート制限 |
|--------|----------|
| **Individual（個人）** | 12 requests/min |
| **Team（チーム）** | 120 requests/min |
| **Enterprise** | カスタム（要問合せ） |

**注意**: 法律事務所用途で複数ユーザーが同時利用する場合、Teamプラン（120req/min）推奨。

**参考資料**:
- [Rate limits - Motion API](https://docs.usemotion.com/cookbooks/rate-limits/)

### 2. APIがある場合の実装方法

#### n8n HTTP Request Node による実装

**ワークフロー構成**:
```
[Schedule Trigger: 5分ごと]
    ↓
[HTTP Request: GET Motion Tasks]
    - URL: https://api.usemotion.com/v1/tasks
    - Authentication: Generic Credential Type
      - Header: X-API-Key = {{$env.MOTION_API_KEY}}
    - Query: status=COMPLETED&modifiedAfter={{$json.lastSyncTime}}
    ↓
[Loop: 各タスクを処理]
    ↓
[Notion: Query Database]
    - Filter: Motion Task ID = {{$json.id}}
    ↓
[IF: 既存レコードあり？]
    ├─ YES → [Notion: Update Database Item]
    └─ NO → [Notion: Create Database Item]
    ↓
[Code Node: lastSyncTime更新（現在時刻を保存）]
```

#### Motion → Notion データマッピング

| Motion フィールド | Notion プロパティ | 変換ロジック |
|------------------|-----------------|------------|
| `name` | タイトル（Title） | そのまま |
| `dueDate` | 期日（Date） | ISO 8601形式変換 |
| `status` | ステータス（Select） | "COMPLETED" → "完了" |
| `assignees[0].name` | 担当者（Person） | Notionユーザーとマッピング |
| `project.name` | プロジェクト（Relation） | Notion案件DBと紐付け |
| `id` | Motion Task ID（Text） | 同期管理用（一意キー） |

#### HTTP Request Node 設定例

**GET Tasks**:
```json
{
  "method": "GET",
  "url": "https://api.usemotion.com/v1/tasks",
  "authentication": "genericCredentialType",
  "genericAuthType": "httpHeaderAuth",
  "httpHeaderAuth": {
    "name": "X-API-Key",
    "value": "={{$env.MOTION_API_KEY}}"
  },
  "qs": {
    "status": "COMPLETED",
    "modifiedAfter": "={{$json.lastSyncTime}}"
  }
}
```

**CREATE Task in Motion**（Notion → Motion の逆方向同期時）:
```json
{
  "method": "POST",
  "url": "https://api.usemotion.com/v1/tasks",
  "body": {
    "name": "={{$json.title}}",
    "dueDate": "={{$json.dueDate}}",
    "projectId": "={{$json.motionProjectId}}",
    "assigneeId": "={{$json.assigneeId}}"
  }
}
```

**参考資料**:
- [Motion API - Motion API](https://docs.usemotion.com/docs/motion-rest-api/44e37c461ba67-motion-rest-api)

### 3. APIがない場合の代替手段

**注**: Motion APIは存在するため、以下は参考情報として記載。

#### 代替手段1: Zapier/Make経由

**Make (旧Integromat)**:
- [Motion and Notion Integration | Workflow Automation](https://www.make.com/en/integrations/motion/notion)
- Make経由でMotion→Notion連携可能
- 料金: 基本プラン $10.59/月（1,000オペレーション）

**Zapier**:
- [Create Motion tasks from new Notion Database items](https://zapier.com/apps/motion/integrations/notion/1399456/create-motion-tasks-from-new-notion-database-items)
- 料金: 有料プラン必須（$29.99/月〜）

#### 代替手段2: Motion CSV/ICSエクスポート → n8n

- Motionのエクスポート機能（存在するか要確認）
- n8nでCSV/ICSファイルを読み込み → Notionへインポート
- **デメリット**: リアルタイム性なし（手動実行）

#### 代替手段3: GoogleカレンダーHub経由

**フロー**:
```
Motion → Googleカレンダー同期（Motion標準機能）
    ↓
n8n: [Google Calendar Trigger] → [Notion Create/Update]
```

**デメリット**:
- タスクの詳細情報が欠落（カレンダーはタイトル・日時のみ）
- カスタムフィールドの移行不可

### 4. 同期方向の設計

#### 推奨: 一方向同期（Motion → Notion）

**理由**:
1. **データ整合性**: 双方向同期は競合リスク高（同じタスクを両側で編集した場合）
2. **Motion利点**: AIスケジューリング機能はMotion側で完結
3. **Notion利点**: 案件管理・資料紐付けはNotion側で完結
4. **法律事務所ワークフロー**: Motionでタスク管理 → 完了後Notionで資料整理

#### 双方向同期の実現可能性

**技術的には可能だがリスクあり**:
- **Conflict Resolution**: Last-Write-Wins方式（最終更新が優先）
- **Timestamp管理**: 各レコードに `lastModifiedTime` を記録
- **Sync Token**: 同期済みデータにフラグ（`syncedToMotion: true`）

**実装例（双方向）**:
```
Workflow A: Motion → Notion (5分ごと)
    - Motion Tasks (modifiedAfter: lastSync) → Notion Update
    - 更新時に `syncedToNotion: true` フラグ

Workflow B: Notion → Motion (5分ごと)
    - Notion DB Query (lastEditedTime > lastSync & syncedToNotion = false)
    - Motion API: Update Task
    - 更新時に `syncedToMotion: true` フラグ
```

**デメリット**:
- 複雑性増大（エラー処理、競合解決）
- API Rate Limit消費2倍
- デバッグ困難

**結論**: **一方向同期（Motion → Notion）を強く推奨**。

---

## 実装優先度とコスト見積もり

### フェーズ1: Gmail → Notion 基本連携（優先度: 高）

**実装範囲**:
- Gmail Trigger + Notion Create
- 件名パターンマッチによる案件紐付け
- 基本的なエラーハンドリング

**実装時間**: 約4-6時間（n8n初期設定含む）

### フェーズ2: 添付ファイル → Google Drive連携（優先度: 中）

**実装範囲**:
- バイナリデータ処理
- Google Drive Upload
- Notion へのDriveリンク追加

**実装時間**: 約3-4時間

### フェーズ3: Motion → Notion 同期（優先度: 中〜低）

**実装範囲**:
- Motion API認証
- タスク取得・データマッピング
- Notion DB同期ロジック

**実装時間**: 約3-5時間

### コスト概算

| 項目 | 月額コスト |
|------|----------|
| **n8n Cloud（Starter）** | $20/月（5,000実行） |
| **n8n Self-hosted（VPS）** | $5-10/月（DigitalOcean Droplet） |
| **Motion（Team）** | $34/ユーザー/月 |
| **Google Workspace** | 既存契約前提（追加費用なし） |
| **Notion（Team）** | $10/ユーザー/月 |

**推奨構成**: n8n Self-hosted（コスト削減） + Motion Team + Notion Team
**月額合計**: 約 $50-60/月（ユーザー数による）

---

## リスクと制約事項

### 1. Motion API レート制限

**リスク**: Individualプラン（12req/min）では頻繁な同期に不十分。
**対策**: Teamプラン（120req/min）にアップグレード、または同期間隔を10分以上に設定。

### 2. Notion API Rate Limit

**制約**: 3 requests/sec（厳格）
**対策**: n8n Workflow に `Wait Node（300ms）` を挿入し、連続リクエストを制御。

### 3. Gmail添付ファイルサイズ

**制約**: Gmail添付ファイル上限25MB、Google Drive APIアップロード上限5TB（実質無制限）。
**対策**: 25MB以上の添付ファイルはGoogleが自動的にDriveリンクに変換するため、追加処理不要。

### 4. 案件紐付け精度

**リスク**: 件名パターンが統一されていない場合、紐付け失敗率が高い。
**対策**:
- 送信元による紐付けを併用
- 未分類DB運用フローの確立（週次レビュー）
- 件名フォーマットのガイドライン策定

---

## まとめ

### 実装可能性: ✅ 高い

**Gmail → Notion**: n8n標準ノードで完全実装可能。添付ファイル処理もGoogleドライブ連携で実現可能。

**Motion → Notion**: Motion API提供により直接連携可能。レート制限に注意すれば安定運用可能。

### 推奨実装順序

1. **フェーズ1**: Gmail → Notion（添付ファイルなし）
2. **フェーズ2**: 添付ファイル → Google Drive連携
3. **フェーズ3**: エラーハンドリング強化
4. **フェーズ4**: Motion → Notion 一方向同期（必要に応じて）

### 次のアクションアイテム

- [ ] n8n環境のセットアップ（Cloud or Self-hosted選定）
- [ ] Gmail OAuth2 + Notion Internal Integration 認証設定
- [ ] 案件DBスキーマ設計（必須プロパティの確定）
- [ ] 件名パターンマッチ正規表現の定義
- [ ] Motion API Key発行（Teamプランの場合）

---

## 参考資料

### Gmail - Notion 連携
- [Gmail and Notion: Automate Workflows with n8n](https://n8n.io/integrations/gmail/and/notion/)
- [Notion-Gmail integration: Automated workflow](https://community.n8n.io/t/notion-gmail-integration-automated-workflow-free-template/40203)
- [Gmail Trigger node documentation | n8n Docs](https://docs.n8n.io/integrations/builtin/trigger-nodes/n8n-nodes-base.gmailtrigger/)

### Motion API
- [Motion API Docs](https://docs.usemotion.com/)
- [Rate limits - Motion API](https://docs.usemotion.com/cookbooks/rate-limits/)
- [Integrate the Notion API with the Motion API - Pipedream](https://pipedream.com/apps/notion/integrations/motion)

### n8n エラーハンドリング・バイナリデータ
- [Error handling | n8n Docs](https://docs.n8n.io/flow-logic/error-handling/)
- [n8n Binary Data: The Complete Guide](https://logicworkflow.com/blog/n8n-binary-data/)
- [Binary data | n8n Docs](https://docs.n8n.io/data/binary-data/)

### Gmail 添付ファイル処理
- [Automatically save Gmail attachments to Google Drive | n8n workflow template](https://n8n.io/workflows/6466-automatically-save-gmail-attachments-to-google-drive/)
- [Gmail and Google Drive: Automate Workflows with n8n](https://n8n.io/integrations/gmail/and/google-drive/)

---

**報告者**: 足軽1号
**報告日時**: 2026-02-12
**ステータス**: 調査完了
