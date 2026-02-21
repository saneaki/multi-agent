# cmd_206 法律文書WF Phase2実装 + Gemini移行メモ

## 対象WF
- ID: Cq0g3T60NfZGuO3t
- 名称: 法律文書自動分析 v1.0
- 実装日: 2026-02-21

## タスクA: Geminiモデル移行（2.0-flash → 2.5-flash）

| ノード | 変更前 | 変更後 |
|--------|--------|--------|
| Call Gemini API | gemini-2.0-flash | gemini-2.5-flash |
| Call Gemini API - Content MD | gemini-2.0-flash | gemini-2.5-flash |

- gemini-2.0-flash は2026年6月1日廃止予定
- 後継: gemini-2.5-flash

## タスクB: Phase2追加ノード（9ノード）

| # | ノード名 | タイプ | 役割 |
|---|---------|--------|------|
| B-1 | Call Gemini API - 案件特定 | httpRequest | content.mdから当事者名/事件番号/案件種別を構造化抽出 |
| B-2 | Code: スコア判定 + Notion検索クエリ | code | 抽出結果を整理、検索優先度を決定 |
| B-3 | Notion案件DB検索 | httpRequest | 事件番号OR当事者名でNotion DB検索 |
| B-4 | Code: Notionスコアリング | code | 検索結果スコアリング、DriveリンクからフォルダID抽出 |
| B-5 | IF: 高確信/低確信 | if | confidence===high && targetFolderId !== null で分岐 |
| B-6 | Move Original File to 案件フォルダ | googleDrive | 原本を案件フォルダに移動（高確信ルート） |
| B-7 | Format 完了通知（自動移動） | code | 自動移動完了メッセージ生成 |
| B-8 | Format 候補通知（手動確認依頼） | code | 低確信時の候補一覧メッセージ生成 |
| B-9 | Send Google Chat Phase2 | httpRequest | 通知送信（B-7/B-8共通） |

## その他変更

- **Format Content MD**: `json.content`フィールド追加（B-1のプロンプトで参照）

## 最終フロー（22ノード）

```
Google Drive Trigger → Filter PDF/Word → Download PDF → Convert Binary to Base64
  → Call Gemini API（2.5-flash）→ Format MD Output
  → Call Gemini API - Content MD（2.5-flash）→ Format Content MD
  → _ai_analysis/フォルダ作成 → Upload summary_rebuttal.md → Upload Content MD to Drive
  → Format Chat Notification → Send Google Chat
  → Call Gemini API - 案件特定（B-1, 2.5-flash）
  → Code: スコア判定 + Notion検索クエリ（B-2）
  → Notion案件DB検索（B-3）
  → Code: Notionスコアリング（B-4）
  → IF: 高確信/低確信（B-5）
      [true]  → Move Original File to 案件フォルダ（B-6）→ Format 完了通知（B-7）→ Send Google Chat Phase2
      [false] → Format 候補通知（手動確認依頼）（B-8）→ Send Google Chat Phase2
```

## Notion検索設計

```json
{
  "filter": {
    "or": [
      {"property": " 事件番号", "rich_text": {"equals": "{caseNumber}"}},
      {"property": "タイトル", "title": {"contains": "{partyName}"}}
    ]
  },
  "page_size": 5
}
```

- 事件番号フィールド名: ` 事件番号`（先頭スペースあり）
- ドライブリンク: `email`型 → `folders/([a-zA-Z0-9_-]+)` で正規表現抽出
