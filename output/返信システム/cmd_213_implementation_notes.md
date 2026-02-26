# cmd_213 法律文書WF Phase4実装メモ

## 実装日: 2026-02-22

## A. 既存WF改修（Cq0g3T60NfZGuO3t, 27ノード維持）

### Code: Notionスコアリング - candidates詳細追加
candidates配列に以下フィールドを追加:
- `pageId`: Notion ページID
- `driveLink`: ドライブリンク（email型URL）
- `targetFolderId`: /folders/({id}) 正規表現で抽出

### Format 候補通知（手動確認依頼） - Webhookリンク追加
- fileId/idx/fileName/candidatesJsonをクエリパラメータとしてエンコード
- 各候補に選択リンクを付与
- `http://localhost:5678/webhook/legal-doc-confirm?fileId=...&idx=N&...`

## B. 新規WF: 法律文書 人間確認WF v1.0

- **WF ID**: ORPc1hauXyinKALR
- **active**: false（殿がアクティブ化のタイミングを判断）

### ノード構成（6ノード）

| # | ノード名 | 役割 |
|---|---------|------|
| N1 | Webhook Trigger | GET /webhook/legal-doc-confirm でパラメータ受信 |
| N2 | Code: 移動先取得 + バリデーション | fileId/idx/candidatesJsonを検証・パース |
| N3 | Move File to 案件フォルダ（人間確認） | 原本を選択された案件フォルダに移動 |
| N4 | _ai_analysis/フォルダ作成（人間確認・案件内） | 案件フォルダ内に_ai_analysis/を作成 |
| N5 | Code: 完了通知フォーマット | 完了メッセージ生成 |
| N6 | Send Google Chat（人間確認完了通知） | Google Chatに通知送信 |

### フロー
N1 → N2 → N3 → N4 → N5 → N6
