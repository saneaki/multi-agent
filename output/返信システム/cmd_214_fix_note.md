# cmd_214: Googleカレンダー同期WF v4.1 イベント削除エラー修正

## 問題

- WF: Googleカレンダー同期フロー v4.1 (ID: calendar-sync-v32)
- exec: 3751
- 失敗ノード: コピー先: イベント削除 (id: delete-event-001)
- エラー: `NodeApiError: Resource has been deleted`
- 原因: コピー先カレンダーで既に手動削除されていたイベントを再削除しようとした

## 修正

- 対象ノード: `コピー先: イベント削除` (delete-event-001)
- 変更: `continueOnFail: false` → `continueOnFail: true`
- 方法: n8n API PUT /api/v1/workflows/calendar-sync-v32

既に削除済みイベントの `ResourceHasBeenDeleted` エラーはスキップし、WF全体がエラー停止しなくなる。

## 検証

- ノード数: 23（変更前後同一、退行なし）
- continueOnFail: true 設定確認済み
- 他ノード変更なし

## 日時

2026-02-22T03:15:00+09:00
