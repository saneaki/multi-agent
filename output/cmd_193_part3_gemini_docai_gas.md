# cmd_193 パート3: Gemini API / Google Document AI / Google Apps Script 調査レポート

調査日: 2026-02-19
担当: ashigaru4 (VSCode代行)
調査対象: Google系ツールによるDrive文書→Markdown変換手段

---

## 1. Gemini API によるPDF/文書→Markdown変換

### 概要

Gemini APIはPDFをネイティブにマルチモーダル処理できる。テキスト抽出・Markdown変換・構造化データ出力が一度のAPIコールで可能。

### 対応方法

**方法A: File API経由のアップロード（大容量PDF向け）**

```
POST https://generativelanguage.googleapis.com/upload/v1beta/files
Content-Type: multipart/form-data
→ fileUri取得後、generateContent呼び出しでURI参照
```

**方法B: Base64インライン（小容量PDF向け）**

```json
{
  "parts": [
    {"inline_data": {"mime_type": "application/pdf", "data": "<base64>"}},
    {"text": "このPDFをMarkdown形式に変換してください"}
  ]
}
```

### n8n での実装パターン

n8nには既製テンプレートが多数存在:
- 「5 ways to process images & PDFs with Gemini AI in n8n」(n8n workflow #3078)
- 「Analyze images & PDFs from Google Drive with Gemini AI」(n8n workflow #11038)
- Extract text from PDF and image using Vertex AI (Gemini) into CSV (n8n workflow #2614)

殿の既存インフラ（法律文書WF等）でGemini APIは既に使用中であり、credential再利用可能。

### 料金・無料枠 (2026年2月現在)

| モデル | 無料枠 | 入力 (有料) | 出力 (有料) |
|--------|--------|------------|------------|
| Gemini 2.0 Flash | 1,500 req/日 | $0.10/1Mトークン | $0.40/1Mトークン |
| Gemini 2.0 Flash (Batch) | — | $0.05/1Mトークン | $0.20/1Mトークン |
| Gemini 1.5 Pro | 50 req/日 | $1.25/1Mトークン (≤128k) | $5.00/1Mトークン |

**コスト効率**: Gemini 2.0 Flash でPDF処理をした場合、約6,000ページ/$1 という試算あり。GPT-4比5〜30倍安い。

### 制限

| 項目 | 制限値 |
|------|--------|
| コンテキストウィンドウ | 1Mトークン（約1,500ページ相当） |
| PDFファイルサイズ推奨 | 25〜30 MB または 500〜1,000ページ |
| 1日リクエスト数（無料） | 1,500 req/日 (Gemini 2.0 Flash) |
| ファイルAPI保存期間 | 48時間 |

### ネイティブテキストPDFの特記事項

PDFにネイティブ埋め込みテキストがある場合、そのトークンは**課金されない**。スキャンPDF（画像扱い）は通常の画像トークン料金。

---

## 2. Google Drive API OCR (PDF → Google Docs → text/plain)

### 概要

Drive APIを使ってPDFをGoogle DocsにOCR変換し、テキストとしてエクスポートする方法。追加料金なし（Google Workspace範囲内）。

### 実装方法

**Step1: PDFをOCRでGoogle Docsに変換**

```
POST https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart
{
  "name": "filename",
  "mimeType": "application/vnd.google-apps.document"  // Google Docs形式を指定
}
// PDFバイナリをbodyに添付
// → OCRが自動実行されGoogle Docsファイルが生成される
```

**Step2: Google DocsをMarkdown/テキストにエクスポート**

```
GET https://www.googleapis.com/drive/v3/files/{fileId}/export?mimeType=text/plain
// または mimeType=text/markdown (一部対応)
```

### 制限

| 項目 | 制限値 |
|------|--------|
| 最大ファイルサイズ | 2 MB |
| OCR対象ページ数 | **最初の10ページのみ** |
| 日本語OCR精度 | 中程度（スキャンPDF品質に依存） |
| Markdown変換精度 | 低（text/plainのエクスポート＋手動変換が現実的） |

### 料金

**無料**（Google Workspace / Drive API v3の範囲内）

### 評価

- ✅ 追加費用なし
- ✅ Google認証情報再利用可能
- ❌ 10ページ制限が致命的（長文文書に不向き）
- ❌ Markdown変換品質が低い（書式情報が失われやすい）
- ❌ 2MBサイズ制限（法律文書・大容量PDFに不向き）

---

## 3. Google Document AI

### 概要

エンタープライズ向けの高精度文書解析サービス。GCP（Google Cloud Platform）上で動作し、フォーム解析・OCR・構造化データ抽出に特化。

### 主な機能

- **Enterprise Document OCR**: 200言語以上のOCR、50言語の手書き認識
- **Form Parser**: フォームフィールドの自動抽出
- **Custom Extractor**: Gemini 2.0 Flash駆動のカスタム抽出モデル（2025年）
- **Math OCR**: 数式のLaTeX形式抽出
- **チェックボックス検出**: マーク状態の認識

### 料金 (2025年現在)

| プロセッサ種別 | 料金 |
|--------------|------|
| Enterprise Document OCR | $1.50/ページ（基本テキスト抽出） |
| Enterprise Document OCR（大量）| $0.06/ページ〜（100万ページ超） |
| Form Parser | 追加料金（テーブル・フォーム抽出） |
| Custom Extractor | 価格改定済み（2025年） |

### 処理速度

- Document AI: 22〜23秒/リクエスト
- Gemini 1.5 Flash: 11〜14秒/リクエスト（比較）

### セットアップ複雑さ

1. GCPプロジェクト作成が必要
2. Document AI APIの有効化
3. プロセッサの作成・設定
4. サービスアカウントキー管理
5. n8nとの接続: HTTP RequestノードでREST API呼び出し（専用ノードなし）

### 評価

- ✅ 最高精度のOCR（エンタープライズ品質）
- ✅ 200+言語対応、手書き認識
- ❌ **高コスト**（$1.50/ページは個人用途には高い）
- ❌ GCP設定が複雑（既存n8nとの統合に追加工数）
- ❌ n8n専用ノードなし（HTTP Request手動設定が必要）
- ❌ 個人・小規模用途には過剰スペック

---

## 4. Google Apps Script (GAS)

### 概要

Google Workspaceの自動化スクリプト環境。Drive・Docs・Sheets等を直接操作可能。n8nからWebhookで呼び出せる。

### PDF→テキスト変換パターン

**パターンA: Drive OCRを使ったテキスト抽出**

```javascript
function convertPdfToText(fileId) {
  // PDFをGoogle DocsにOCR変換
  const pdfFile = DriveApp.getFileById(fileId);
  const blob = pdfFile.getBlob();
  const folder = DriveApp.getRootFolder();

  // Drive API v3 でOCR有効でアップロード
  const resource = {
    name: pdfFile.getName(),
    mimeType: 'application/vnd.google-apps.document'
  };
  const options = { ocr: true, ocrLanguage: 'ja' };
  const gdoc = Drive.Files.create(resource, blob, options);

  // テキスト抽出
  const doc = DocumentApp.openById(gdoc.id);
  return doc.getBody().getText();
}
```

**パターンB: Google Docs→Markdown変換**

```javascript
// DocumentApp経由でMarkdown形式エクスポート
// ※ 2024年にGoogle DocsがMarkdown import/export対応
function exportAsMarkdown(docId) {
  const doc = DocumentApp.openById(docId);
  // Drive API export
  const url = `https://docs.google.com/document/d/${docId}/export?format=md`;
  const options = {
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() }
  };
  return UrlFetchApp.fetch(url, options).getContentText();
}
```

**パターンC: n8nからGAS Webhookを呼び出す連携**

```javascript
// GAS側: doPost(e)でWebhookエンドポイント作成
function doPost(e) {
  const data = JSON.parse(e.postData.contents);
  const fileId = data.fileId;
  const text = convertPdfToText(fileId);
  return ContentService.createTextOutput(JSON.stringify({ text }))
    .setMimeType(ContentService.MimeType.JSON);
}
```

n8n側: HTTP RequestノードでGAS Webhook URL (script.google.com/macros/s/.../exec) をPOST

### 制限

| 項目 | 制限値 |
|------|--------|
| 実行時間上限 | 6分/実行 |
| OCR精度 | Drive OCR依存（Drive APIと同等） |
| PDFページ制限 | Drive OCRと同じ（10ページ制限） |
| Markdown変換精度 | Google Docs経由なら中〜高（書式保持） |

### 料金

**無料**（Google Workspace範囲内。GAS実行はクォータ内で無料）

### 評価

- ✅ 無料
- ✅ Google Workspaceと深く統合
- ✅ n8nからWebhook呼び出しが容易
- ✅ 2024年からGoogle Docs→Markdown直接エクスポート対応
- ❌ OCR精度はDrive API依存（限界あり）
- ❌ 10ページPDF制限（Drive OCR経由の場合）
- ❌ GASデプロイ・権限管理が必要

---

## 5. 比較表

| 評価軸 | Gemini API | Drive API OCR | Document AI | Google Apps Script |
|--------|-----------|--------------|-------------|-------------------|
| **Markdown変換品質** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **日本語精度** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **コスト** | 無料枠あり/低コスト | 無料 | 高コスト | 無料 |
| **ページ数上限** | 1,000ページ | **10ページ** | 実質無制限 | **10ページ** |
| **n8n統合容易さ** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **セットアップ複雑さ** | 低（既存credential） | 低 | 高（GCP設定） | 中（GASデプロイ） |
| **Word/Docs対応** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 6. 殿の既存インフラとの親和性評価

### 既存インフラ前提
- n8n (Docker, VPS Ubuntu)
- Google Workspace (Gmail, Drive)
- Gemini API認証情報 → **既にn8n WFで使用中**
- GAS → 使用実績不明（要確認）

### 各手法の親和性

**Gemini API** ★★★★★ 最推奨

- 既存のGemini credential（API Key or Vertex AI）がそのまま使用可能
- n8nのAI Agentノード・HTTP Requestノードどちらでも統合可能
- 法律文書WF等で既に運用実績あり
- 1,000ページ超の大容量PDFにも対応

**Google Drive API OCR** ★★☆☆☆ 補助的用途のみ

- Google OAuth認証は既存で再利用可能
- 10ページ制限が法律文書・長文Wordに致命的
- 短い文書（議事録・1〜2ページ文書）には有効

**Google Document AI** ★★☆☆☆ 不採用推奨

- コスト・セットアップ複雑さ・n8n統合の手間を考えると費用対効果が低い
- Gemini APIのほうが安く・速く・n8n統合も容易

**Google Apps Script** ★★★☆☆ 補助ツールとして有用

- Google Docsファイルのネイティブ変換に強み（.docx→Markdown直接）
- PDFはDrive OCR経由のため10ページ制限あり
- n8n→GAS Webhookパターンは実績あり（cmd_xxxで使用可能）

---

## 7. 推奨アーキテクチャ

### PDF → Markdown 変換

```
[Google Drive: PDF格納]
    ↓ (n8n: Google Driveノードでダウンロード)
[バイナリデータ]
    ↓ (n8n: HTTP Request or AI Agent)
[Gemini 2.0 Flash API: PDF multimodal処理]
    ↓ (プロンプト: "このPDFをMarkdown形式に変換してください")
[Markdown テキスト出力]
    ↓ (n8n: Write Binary File or Google Drive Upload)
[Google Drive: .md ファイル保存]
```

**コスト試算**: 10ページPDF（≒5,000トークン入力 + 5,000トークン出力）
= $0.10/1M × 0.005 + $0.40/1M × 0.005 = **約$0.0025/ファイル（0.4円）**

### Word (.docx) → Markdown 変換

```
[Google Drive: .docx格納]
    ↓ (n8n: Google Driveノードでダウンロード)
[バイナリデータ]
    ↓ (選択肢A: Gemini API multipart)
    ↓ (選択肢B: GAS Webhook → Google Docs変換 → Markdownエクスポート)
[Markdown出力]
```

**選択肢B（GAS経由）はWordの書式保持精度が高い**が、GASのデプロイが必要。

---

## 参考リンク

- [Gemini API - Document understanding](https://ai.google.dev/gemini-api/docs/document-processing)
- [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Google Drive API OCR](https://support.google.com/drive/answer/176692?hl=en)
- [Google Document AI Pricing](https://cloud.google.com/document-ai/pricing)
- [GAS PDF to Text (labnol)](https://www.labnol.org/extract-text-from-pdf-220422)
- [n8n: 5 ways to process PDFs with Gemini](https://n8n.io/workflows/3078-5-ways-to-process-images-and-pdfs-with-gemini-ai-in-n8n/)
- [Document AI vs Gemini API 比較 (Medium)](https://didikmulyadi.medium.com/data-extractions-cost-and-performance-comparison-between-google-document-ai-and-vertex-ai-studio-d161631a113e)
- [GAS Google Docs↔Markdown変換](https://medium.com/google-cloud/convert-google-document-to-markdown-and-vice-versa-using-google-apps-script-a05c86509db4)
