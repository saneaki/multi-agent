# cmd_205 法律文書WF Phase1実装メモ

## 対象WF
- ID: Cq0g3T60NfZGuO3t
- 名称: 法律文書自動分析 v1.0
- 実装日: 2026-02-21

## 変更内容

### 変更1: Filter PDF Only → Filter PDF/Word
- 条件をOR（any）に拡張
- 追加条件:
  - `application/vnd.openxmlformats-officedocument.wordprocessingml.document` (docx)
  - `application/msword` (doc)

### 変更2: Gemini APIモデル変更
- `gemini-2.5-flash` → `gemini-2.0-flash`
- mimeTypeをハードコード(`application/pdf`) → 動的(`$json.mimeType`)

### 変更3: Format MD Output - Word拡張子対応
- `.replace(/\.pdf$/i, '_分析.md')` → `.replace(/\.(pdf|docx|doc)$/i, '_分析.md')`

### 追加: Call Gemini API - Content MD
- 文書全文をMarkdown変換するGemini API呼び出し
- position: [1220, 240]
- Format MD Outputの後に配置

### 追加: Format Content MD
- Geminiテキストレスポンスをbinaryに変換
- position: [1450, 240]

### 追加: _ai_analysis/フォルダ作成
- Google Drive Create Folder操作
- 親フォルダ: `$('Google Drive Trigger').first().json.parents[0]`
- continueOnFail: true
- position: [1680, 240]

### 変更: Upload MD to Drive → Upload summary_rebuttal.md
- ファイル名: `$('Download PDF').first().json.name` + `_summary_rebuttal.md`
- 保存先: `_ai_analysis/フォルダ作成` のID
- position: [1910, 240]

### 追加: Upload Content MD to Drive
- ファイル名: `$('Download PDF').first().json.name` + `_content.md`
- 保存先: `_ai_analysis/フォルダ作成` のID
- position: [2140, 240]

### 変更: Format Chat Notification
- メッセージ更新: `_ai_analysis/ に2ファイル生成` を含む通知
- position: [2370, 240]

## 最終フロー（13ノード）

```
Google Drive Trigger
  → Filter PDF/Word
  → Download PDF
  → Convert Binary to Base64
  → Call Gemini API（要約・反論）
  → Format MD Output
  → Call Gemini API - Content MD（全文MD変換）
  → Format Content MD
  → _ai_analysis/フォルダ作成
  → Upload summary_rebuttal.md
  → Upload Content MD to Drive
  → Format Chat Notification
  → Send Google Chat
```

## テスト状況
- WF構造: PUT成功、13ノード確認
- active: true
- E2Eテスト: 認証情報（OAuth2）が必要なためGDriveへの自走アップロード不可
  → 次回定期ポーリング（10分毎）時の実ファイルで検証予定
