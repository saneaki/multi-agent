# Gmail WF v5→v6 & ダイジェスト通知WF v1→v2 アップグレード計画書

**作成日**: 2026-02-25
**作成者**: ashigaru2 (subtask_235a)
**対象**: Gmail自動化WF v5.0→v6.0 / Gmailダイジェスト通知WF v1.0→v2.0
**実施**: 計画のみ（本書は計画書。実装はcmd_235以降の別subtaskで実施）

---

## 1. WF概要・現状

| WF | ID | ノード数 | active |
|----|-----|---------|--------|
| Gmail自動化 v5.0 | 6HfrbcXoujQSfSQC | 34 | **True** (稼働中) |
| Gmail自動化 v6.0 | x2HSCjYW3wCQlp6a | 37 | False (待機中) |
| Gmailダイジェスト v1.0 | XgI1VYV2oDZyGKhf | 8 | **True** (稼働中) |
| Gmailダイジェスト v2.0 | Qitb61IRPn4XZkgA | 9 | False (待機中) |

---

## 2. v5.0 → v6.0 差分（追加ノード）

v6.0はv5.0のコピーに以下3ノードを追加した構成。

| No | ノード名 | 種別 | 機能 |
|----|---------|------|------|
| 1 | ログイン通知除外 | if | subjectに「ログイン通知」または「Login notification」が含まれる場合に除外 |
| 2 | ログイン通知スキップ | noOp | ログイン通知の安全スキップ（フロー終端） |
| 3 | LINE通知 | httpRequest | LINE Messaging API push通知（設定要・後述） |

### ログイン通知除外ロジック詳細

```
conditions (OR, case-insensitive):
  - subject contains "ログイン通知"
  - subject contains "Login notification"
caseSensitive: false
```

### LINE通知ノード詳細（現在はプレースホルダー）

```
URL: https://api.line.me/v2/bot/message/push
Headers:
  Authorization: Bearer YOUR_LINE_CHANNEL_ACCESS_TOKEN  ← 要設定
  Content-Type: application/json
Body:
  {
    "to": "YOUR_LINE_USER_ID",                          ← 要設定
    "messages": [{
      "type": "text",
      "text": {{ $('Gemini判断+要約準備').item.json.summary || '新着メール通知' }}
    }]
  }
```

---

## 3. v1.0 → v2.0 差分（追加ノード）

v2.0はv1.0のコピーに以下1ノードを追加した構成。

| No | ノード名 | 種別 | 機能 |
|----|---------|------|------|
| 1 | LINE通知 | httpRequest | LINE Messaging API push通知（設定要・後述） |

### LINE通知ノード詳細（現在はプレースホルダー）

```
URL: https://api.line.me/v2/bot/message/push
Headers:
  Authorization: Bearer YOUR_LINE_CHANNEL_ACCESS_TOKEN  ← 要設定
  Content-Type: application/json
Body:
  {
    "to": "YOUR_LINE_USER_ID",                          ← 要設定
    "messages": [{
      "type": "text",
      "text": {{ $('ダイジェスト構築').item.json.digestText || 'Gmailダイジェスト通知' }}
    }]
  }
```

---

## 4. Notion API 2025-09-03 移行対象ノード

### 4-1. Gmail自動化 v6.0（3ノード移行対象）

| ノード名 | 現行Version | 現行URL | 変更後Version | URL変更 |
|---------|------------|---------|--------------|--------|
| Notion DB保存 | 2022-06-28 | /v1/pages | **2025-09-03** | 変更なし |
| Notion DB更新 | 2022-06-28 | /v1/pages/{id} | **2025-09-03** | 変更なし |
| Notion案件詳細取得 | 2022-06-28 | /v1/databases/{NOTION_ANKEN_DB_ID}/query | **2025-09-03** | **要確認（後述）** |

**参考**: Notion人物DB検索は既に2025-09-03移行済み（URL: /v1/data_sources/1aae8d62-e4aa-809d-a2c6-000b658e92e9/query）

### 4-2. Gmailダイジェスト v2.0（2ノード移行対象）

| ノード名 | 現行Version | 現行URL | 変更後Version | URL変更 |
|---------|------------|---------|--------------|--------|
| Notion DB検索 | 2022-06-28 | /v1/databases/{NOTION_GMAIL_DB_ID}/query | **2025-09-03** | **要確認（後述）** |
| Notion通知済み更新 | 2022-06-28 | /v1/pages/{pageId} | **2025-09-03** | 変更なし |

### 4-3. data_source_id 調査結果

| DB名 | DB ID (.env) | data_source_id | 状況 |
|------|-------------|----------------|------|
| 新メールDB (Gmail) | NOTION_GMAIL_DB_ID=306e8d62... | 306e8d62-e4aa-80eb-b51c-000b37f04f25 | ✅ 特定済み（将軍がAPI確認） |
| 案件DB | NOTION_ANKEN_DB_ID=1a4e8d62... | 1a4e8d62-e4aa-8145-a95c-000bdde23244 | ✅ 特定済み（将軍がAPI確認） |
| 人物DB | — | 1aae8d62-e4aa-809d-a2c6-000b658e92e9 | 特定済み・WF使用中 |
| 日記DB | — | NOTION_DIARY_DS_ID (.env設定済み) | 特定済み |
| 活動ログDB | — | NOTION_ACTIVITY_LOG_DS_ID (.env設定済み) | 特定済み |

**data_source_id調査方法**:
1. Notion Webでデータベースページを開く
2. URLの末尾32桁がDB IDと一致するかをAPI `/v1/data_sources/{id}/query` でテスト
3. または既存WFの実行ログから確認（案件DBは `/databases/` エンドポイントで引き続き動作する可能性あり）

**注意**: `/databases/{id}/query` は2025-09-03で `invalid_request_url` を返す場合がある。
ただし `/data_sources/{id}/query` でも404が返る場合はDB IDと同一のIDで試す。

---

## 5. 環境変数の追加・変更

実装前に以下の環境変数を `/home/ubuntu/.n8n-mcp/n8n/.env` に追加する。

### 5-1. LINE連携（新規追加 - 必須）

| 変数名 | 値 | 取得先 |
|--------|-----|--------|
| `LINE_CHANNEL_ACCESS_TOKEN` | (要設定) | LINE Developers Console > チャンネルアクセストークン |
| `LINE_USER_ID` | (要設定) | LINE User ID or Group ID |

**LINE Developer Console**: https://developers.line.biz/ja/

### 5-2. Notion data_source_id（新規追加 - 調査後）

| 変数名 | 値 | 用途 |
|--------|-----|------|
| `NOTION_GMAIL_DS_ID` | `306e8d62-e4aa-80eb-b51c-000b37f04f25` | 新メールDB data_source_id |
| `NOTION_ANKEN_DS_ID` | `1a4e8d62-e4aa-8145-a95c-000bdde23244` | 案件DB data_source_id |

---

## 6. 実装手順書

### Phase 1: 事前準備

```
[ ] 1. LINE_CHANNEL_ACCESS_TOKEN と LINE_USER_ID を取得・.envに追加
[x] 2. NOTION_GMAIL_DS_ID = 306e8d62-e4aa-80eb-b51c-000b37f04f25（特定済み・.envに追加要）
[x] 3. NOTION_ANKEN_DS_ID = 1a4e8d62-e4aa-8145-a95c-000bdde23244（特定済み・.envに追加要）
[ ] 4. docker compose up -d で n8n 再起動（.env変更反映）
```

### Phase 2: v6.0 Notion API更新（3ノード）

```
対象WF: x2HSCjYW3wCQlp6a
n8n API: GET /api/v1/workflows/x2HSCjYW3wCQlp6a → JSON取得

更新内容:
[ ] Notion DB保存: headerParameters内 Notion-Version を 2025-09-03 に変更
[ ] Notion DB更新: headerParameters内 Notion-Version を 2025-09-03 に変更
[ ] Notion案件詳細取得:
    - Notion-Version を 2025-09-03 に変更
    - URL を /v1/data_sources/{{ $env.NOTION_ANKEN_DS_ID }}/query に変更

n8n API: PUT /api/v1/workflows/x2HSCjYW3wCQlp6a で更新
```

### Phase 3: v6.0 LINE通知ノード設定

```
[ ] Authorization ヘッダー値を
    "Bearer YOUR_LINE_CHANNEL_ACCESS_TOKEN"
    → "Bearer {{ $env.LINE_CHANNEL_ACCESS_TOKEN }}" に変更
[ ] Body の "to" を
    "YOUR_LINE_USER_ID"
    → "{{ $env.LINE_USER_ID }}" に変更
```

### Phase 4: v2.0 Notion API更新（2ノード）

```
対象WF: Qitb61IRPn4XZkgA
n8n API: GET /api/v1/workflows/Qitb61IRPn4XZkgA → JSON取得

更新内容:
[ ] Notion DB検索:
    - Notion-Version を 2025-09-03 に変更
    - URL を /v1/data_sources/{{ $env.NOTION_GMAIL_DS_ID }}/query に変更
[ ] Notion通知済み更新: Notion-Version を 2025-09-03 に変更

n8n API: PUT /api/v1/workflows/Qitb61IRPn4XZkgA で更新
```

### Phase 5: v2.0 LINE通知ノード設定

```
[ ] Authorization ヘッダー値を
    "Bearer YOUR_LINE_CHANNEL_ACCESS_TOKEN"
    → "Bearer {{ $env.LINE_CHANNEL_ACCESS_TOKEN }}" に変更
[ ] Body の "to" を
    "YOUR_LINE_USER_ID"
    → "{{ $env.LINE_USER_ID }}" に変更
```

### Phase 6: テスト（Gmail v6.0）

```
[ ] テストメール送信: python3 scripts/send_test_email.py
[ ] n8n exec確認: GET /api/v1/executions?workflowId=x2HSCjYW3wCQlp6a
[ ] 確認項目:
    - Gmail Triggerが発火すること
    - Notion DB保存が成功すること（2025-09-03 APIで）
    - Notion案件詳細取得が成功すること
    - ログイン通知メールが除外されること
    - LINE通知が届くこと（LINE情報設定済みの場合）
```

### Phase 7: テスト（ダイジェスト v2.0）

```
[ ] v2.0を手動実行（n8n内部APIで）
[ ] exec確認: GET /api/v1/executions?workflowId=Qitb61IRPn4XZkgA
[ ] 確認項目:
    - Notion DB検索が成功すること（2025-09-03 APIで）
    - Telegramへの送信が成功すること
    - Notion通知済みフラグ更新が成功すること
    - LINE通知が届くこと（LINE情報設定済みの場合）
```

### Phase 8: active化切り替え

```
Gmail WF切り替え:
[ ] v5.0 (6HfrbcXoujQSfSQC): PATCH /api/v1/workflows/6HfrbcXoujQSfSQC → active=false
[ ] v6.0 (x2HSCjYW3wCQlp6a): PATCH /api/v1/workflows/x2HSCjYW3wCQlp6a → active=true

ダイジェスト WF切り替え:
[ ] v1.0 (XgI1VYV2oDZyGKhf): PATCH /api/v1/workflows/XgI1VYV2oDZyGKhf → active=false
[ ] v2.0 (Qitb61IRPn4XZkgA): PATCH /api/v1/workflows/Qitb61IRPn4XZkgA → active=true
```

---

## 7. ロールバック手順

v6.0またはv2.0で問題が発生した場合:

```bash
N8N_API_KEY="..."
# Gmail WF ロールバック
curl -X PATCH http://localhost:5678/api/v1/workflows/x2HSCjYW3wCQlp6a \
  -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  -d '{"active": false}'
curl -X PATCH http://localhost:5678/api/v1/workflows/6HfrbcXoujQSfSQC \
  -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  -d '{"active": true}'

# ダイジェスト WF ロールバック
curl -X PATCH http://localhost:5678/api/v1/workflows/Qitb61IRPn4XZkgA \
  -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  -d '{"active": false}'
curl -X PATCH http://localhost:5678/api/v1/workflows/XgI1VYV2oDZyGKhf \
  -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" \
  -d '{"active": true}'
```

v5.0/v1.0は変更していないため、即時ロールバック可能。

---

## 8. テスト項目一覧

### Gmail自動化 v6.0

| # | テスト項目 | 確認方法 | 合否 |
|---|-----------|---------|------|
| 1 | Gmail Trigger正常発火 | exec status=success | - |
| 2 | 添付ファイルあり処理 | Google Drive保存確認 | - |
| 3 | Gemini判断成功 | AI判断結果パース成功 | - |
| 4 | Notion DB保存（2025-09-03） | Notion DBにレコード追加 | - |
| 5 | Notion案件詳細取得（2025-09-03） | 案件情報取得成功 | - |
| 6 | 返信必要メール: Telegram即時通知 | Telegram受信確認 | - |
| 7 | Gmail下書き作成 | Gmail下書き確認 | - |
| 8 | Notion DB更新（2025-09-03） | URLプロパティ更新確認 | - |
| 9 | ログイン通知除外 | ログイン通知メールがスキップされる | - |
| 10 | LINE通知 | LINE受信確認（設定済みの場合） | - |

### Gmailダイジェスト v2.0

| # | テスト項目 | 確認方法 | 合否 |
|---|-----------|---------|------|
| 1 | Notion DB検索（2025-09-03） | 未通知レコード取得成功 | - |
| 2 | 0件時: No Operationで終了 | exec成功確認 | - |
| 3 | ダイジェスト構築 | 正しい形式の文字列生成 | - |
| 4 | Telegram Bot送信 | Telegram受信確認 | - |
| 5 | 通知済み更新（2025-09-03） | Notionフラグ更新確認 | - |
| 6 | LINE通知 | LINE受信確認（設定済みの場合） | - |

---

## 9. 未解決事項・前提条件

| 項目 | 状況 | 対応 |
|------|------|------|
| LINE_CHANNEL_ACCESS_TOKEN | **未設定** | 殿がLINE Developerから取得・.envに追加 |
| LINE_USER_ID | **未設定** | 殿が通知先USER_ID/GROUP_IDを設定 |
| NOTION_GMAIL_DS_ID | **306e8d62-e4aa-80eb-b51c-000b37f04f25** | .envに追加要 |
| NOTION_ANKEN_DS_ID | **1a4e8d62-e4aa-8145-a95c-000bdde23244** | .envに追加要 |

**重要**: LINE環境変数が未設定の場合、LINE通知ノードはエラーになる。
実装時はLINE通知ノードに `continueOnFail: true` を設定するか、LINE情報設定後に有効化する。

---

## 10. 実装順序の推奨

```
1. 事前: LINE情報・data_source_idの調査・.env追加（殿/実装者）
2. Step1: v6.0 Notion API移行（3ノード）→ テスト
3. Step2: v6.0 LINE通知設定 → テスト
4. Step3: v6.0 active化切り替え（v5.0→v6.0）
5. Step4: v2.0 Notion API移行（2ノード）→ テスト
6. Step5: v2.0 LINE通知設定 → テスト
7. Step6: v2.0 active化切り替え（v1.0→v2.0）
```

Gmail WFを先に対応し、ダイジェストWFを後に対応する。
各WFは独立しているため、並列実施も可能。
