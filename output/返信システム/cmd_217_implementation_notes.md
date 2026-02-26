# cmd_217 案件同期+GitHub Issue v1.0 実装メモ

## 実装日: 2026-02-23

## 概要

既存WF「案件タスク完了→対応履歴同期 Webhook版 v2.0」(ID: XjYci5rlyNx2ckcD)をベースに、
GitHub Issue自動作成機能を追加した新規WFを作成した（active=false）。

## A. 既存WF（XjYci5rlyNx2ckcD）— 変更なし確認

- ノード数: 15（変更なし）
- active: true（変更なし）
- Webhookパス: notion-task-sync（変更なし）

## B. 新規WF: 案件同期+GitHub Issue v1.0

- **WF ID**: TDsEGyC8XHFAQEZb
- **active**: false（殿がアクティブ化のタイミングを判断）
- **Webhookパス**: notion-issue-sync

### ノード構成（19ノード）

| # | ノード名 | 役割 |
|---|---------|------|
| N01 | Webhook受信 | POST /webhook/notion-issue-sync でペイロード受信 |
| N02 | Webhook応答 | 即座に200 OK返却 |
| N03 | タスクデータ抽出 | 既存WFから流用。status/taskPageId/casePageId等を抽出 |
| N04 | ステータス判定 | status == "Issue" OR "Issue作成" → true |
| N05 | Code: GitHub Issueペイロード構築 | title/body/labels組み立て |
| N06 | GitHub Issue作成 | POST https://api.github.com/repos/saneaki/n8n/issues |
| N07 | NotionにIssue URL書き戻し | PATCH 案件タスクページ、continueOnFail=true |
| N08 | ステータス「Issue」か判定 | status == "Issue" → true（案件DB同期へ） |
| N09 | タスク本文ブロック取得 | 既存WFから流用 |
| N10 | ブロック変換 | 既存WFから流用 |
| N11 | 案件ページブロック取得 | 既存WFから流用 |
| N12 | 対応履歴トグル検索 | 既存WFから流用 |
| N13 | 対応履歴トグル有無分岐 | 既存WFから流用 |
| N14 | 対応履歴トグル作成 | 既存WFから流用（falseブランチ） |
| N15 | ブロックID取得 | 既存WFから流用 |
| N16 | パス統合 | 既存WFから流用（Merge） |
| N17 | 追記ペイロード構築 | 既存WFから流用 |
| N18 | 対応履歴に追記 | 既存WFから流用 |
| N19 | 案件同期ステータス更新 | 既存WFから流用 |

### フロー

```
N01 → N02 → N03 → N04(ステータス判定)
  [Issue OR Issue作成] → N05 → N06(GitHub Issue作成) → N07(Notion URL書き戻し)
    → N08(「Issue」か判定)
      [Issue] → N09〜N19(案件DB同期)
      [Issue作成のみ] → (終了)
  [その他] → (終了)
```

### ステータス分岐仕様

| status | GitHub Issue | 案件DB同期 |
|--------|-------------|----------|
| "Issue" | 作成 | する |
| "Issue作成" | 作成 | しない |
| その他 | なし | なし |

### GitHub Issue内容

- **title**: `{タスク名}（{完了日時}）`
- **body**: タスク情報（タスク名/タスク内容/担当者/完了日時/メモ）+ Notionタスクページリンク
- **labels**: `["auto-created"]`
- **リポジトリ**: saneaki/n8n（private, Issues有効）

### 認証

- GitHub API: `$env.GITHUB_TOKEN`
- Notion API: `$env.NOTION_INTEGRATION_TOKEN`

## C. テスト結果

| テスト | 結果 |
|--------|------|
| 既存WF（XjYci5rlyNx2ckcD）ノード数=15 | PASS |
| 新規WF active=false | PASS |
| Webhook Trigger (path: notion-issue-sync) | PASS |
| ステータス判定 IFノード存在 | PASS |
| ステータス「Issue」か判定 IFノード存在 | PASS |
| GitHub Issue作成 HTTPノード存在 | PASS |
| NotionにIssue URL書き戻し (continueOnFail=true) | PASS |
| タスク本文ブロック取得ノード存在 | PASS |
| 案件同期ステータス更新ノード存在 | PASS |
| GitHub API接続確認（saneaki/n8n, has_issues=true） | PASS |

## D. artifacts

- `/tmp/existing_wf_217.json` — 既存WFバックアップ
- `/tmp/create_wf_217.py` — 新規WF生成スクリプト
- `/tmp/new_wf_217.json` — 新規WF JSON
- `/tmp/new_wf_217_response.json` — n8n API応答
