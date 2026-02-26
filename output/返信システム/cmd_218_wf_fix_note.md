# cmd_218 WF修正記録

## 対象WF
- ID: TDsEGyC8XHFAQEZb
- 旧名称: 案件同期+GitHub Issue v1.0
- 新名称: 案件同期+GitHub Issue v2.0

## 修正内容

### 修正1: WF名称変更
- `案件同期+GitHub Issue v1.0` → `案件同期+GitHub Issue v2.0`
- 既存WF（XjYci5rlyNx2ckcD）の命名規則（v2.0形式）に統一

### 修正2: ステータス遷移ロジック変更

#### ステータス判定ノード
- 変更前: `Issue` OR `Issue作成` → true分岐
- 変更後: `Issue` のみ → true分岐（`Issue作成` は通過しない）

#### ステータス「Issue」か判定ノード（削除）
- 不要になったため削除
- 接続変更: `NotionにIssue URL書き戻し` → `タスク本文ブロック取得` に直接接続

#### 新規ノード「タスクステータスを「Issue作成」に変更」追加
- 位置: [3960, 300]（案件同期ステータス更新の後）
- Notion PATCH API: タスクページのステータスを「Issue作成」に更新
- URL: `https://api.notion.com/v1/pages/{taskPageId}`
- body: `{"properties":{"状態":{"status":{"name":"Issue作成"}}}}`

## 最終フロー

```
Webhook受信 → Webhook応答 → タスクデータ抽出 → ステータス判定[Issue=true]
  → GitHub Issueペイロード構築 → GitHub Issue作成 → NotionにIssue URL書き戻し
  → タスク本文ブロック取得 → ブロック変換 → 案件ページブロック取得
  → 対応履歴トグル検索 → トグル有無分岐 → (作成 or 取得) → パス統合
  → 追記ペイロード構築 → 対応履歴に追記 → 案件同期ステータス更新
  → タスクステータスを「Issue作成」に変更
```

## 検証結果
- WF名: ✓ 案件同期+GitHub Issue v2.0
- active: ✓ false（変更なし）
- ノード数: ✓ 19（削除1 + 追加1）
- ステータス判定: ✓ Issueのみ（and条件、1条件）
- 削除済み: ✓ ステータス「Issue」か判定
- 追加済み: ✓ タスクステータスを「Issue作成」に変更
- 既存WF（XjYci5rlyNx2ckcD）: ✓ 15ノード変更なし

## 実行日時
2026-02-23 JST
