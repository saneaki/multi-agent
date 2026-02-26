# cmd_193 パート1調査: 殿の既存GitHubリポジトリ分析 + n8n内蔵機能調査

**担当**: ashigaru1 / subtask_193b
**作成日時**: 2026-02-19
**調査対象**: saneaki GitHubアカウント + n8n組み込みノード機能

---

## 1. 殿のGitHubリポジトリ分析

### 1-1. 調査対象リポジトリの存在確認

タスクで指定された2リポジトリの調査結果:

| リポジトリ | 状態 | 備考 |
|-----------|------|------|
| saneaki/gmail-to-markdown | **存在しない** | 公開リポジトリになし。プライベートまたは未公開の可能性 |
| saneaki/googledrive-to-markdown | **存在しない** | 公開リポジトリになし。プライベートまたは未公開の可能性 |

saneaki の公開リポジトリ一覧（2026-02-19時点）:

| リポジトリ名 | 説明 |
|-------------|------|
| **markitdown** | Microsoft/markitdownのフォーク（ファイル→Markdown変換Pythonツール）|
| n8n-mcp | n8n用MCPサーバー |
| multi-agent | 侍マルチエージェントシステム（このシステム自体）|
| keyball39 | キーボール設定 |
| nvm | Node Version Manager |

### 1-2. saneaki/markitdown（最重要）

**基本情報**
- 親リポジトリ: **microsoft/markitdown**（Stars: 87,281）
- 言語: Python
- フォーク時のカスタマイズ: なし（0スター、説明変更なし）
- URL: https://github.com/saneaki/markitdown（microsoft/markitdownのフォーク）

**概要**: MicrosoftがOSSで公開するPythonライブラリ。ファイル・オフィス文書をMarkdownに変換するツール。LLMおよびテキスト分析パイプライン向けに設計されている。

**対応ファイル形式**

| 形式 | 対応 | 備考 |
|------|------|------|
| PDF | ✅ | テキストベースPDFに有効。スキャンPDFはOCR統合が必要 |
| Word (.docx) | ✅ | ネイティブ対応 |
| PowerPoint (.pptx) | ✅ | ネイティブ対応 |
| Excel (.xlsx) | ✅ | ネイティブ対応 |
| 画像（PNG/JPG等）| ✅ | EXIFメタデータ + OCR |
| 音声 | ✅ | 音声文字起こし + メタデータ |
| HTML | ✅ | ウェブページ変換 |
| YouTube URL | ✅ | ページ情報変換 |
| CSV | ✅ | 構造化データ変換 |
| JSON | ✅ | 構造化データ変換 |
| XML | ✅ | 構造化データ変換 |
| ZIP | ✅ | 内部コンテンツを反復処理 |
| EPUB | ✅ | 電子書籍 |

**技術仕様**
- Python 3.10以上が必要
- インストール: `pip install 'markitdown[all]'`（全依存関係）または形式別インストール (`[pdf]`, `[docx]`, `[pptx]`)
- CLIまたはPython API両対応
- Azure Document Intelligence統合（高度なPDF処理）
- MCP (Model Context Protocol) サーバー対応（Claude Desktop等と統合可能）

**設計思想・変換品質**
- **LLM/テキスト分析向け最適化**（人間向け高忠実度変換ではない）
- 「重要な文書構造とコンテンツをMarkdownで保持」が目標
- Markdownはトークン効率が高く、LLM処理に経済的
- スキャンPDFは直接処理不可（OCRサービス連携が必要）

**コスト**: オープンソース（無料）、実行環境は自前で用意

---

## 2. n8n 内蔵機能調査

### 2-1. Extract from File ノード

**概要**: バイナリ形式ファイルからデータを抽出しJSON形式に変換するn8n組み込みノード。追加インストール不要で使用可能。

**対応操作（公式）**

| 操作名 | 対象形式 | 出力 |
|--------|---------|------|
| Extract From CSV | CSVファイル | JSONデータ配列 |
| Extract From HTML | HTMLファイル | JSONデータ |
| Extract From JSON | JSONバイナリファイル | JSONデータ |
| Extract From ICS | iCalendar形式 | JSONデータ |
| Extract From ODS | OpenDocument Spreadsheet | JSONデータ |
| Extract From PDF | PDFファイル | JSONデータ（テキスト） |
| Extract From RTF | リッチテキスト形式 | JSONデータ |
| Extract From Text File | テキストファイル | JSONデータ |
| Move File to Base64 String | バイナリデータ | Base64文字列 |

**重要な制限事項**

| 項目 | 詳細 |
|------|------|
| Word (.docx) 対応 | **ネイティブ非対応**（公式操作リストに含まれず）|
| Excel (.xlsx) 対応 | ODS対応のみ（XLS/XLSXは非公式/コミュニティ情報あり）|
| スキャンPDF | **処理不可**（テキストベースPDFのみ）|
| 出力形式 | JSON変換（Markdownへの直接変換は不可）|
| 変換品質 | テキスト抽出のみ。レイアウト・書式保持なし |

**n8n実行環境**: クラウド・セルフホスト両対応
**コスト**: 無料（追加インストール不要）
**セットアップ複雑さ**: 低（ドラッグ&ドロップで即使用可能）

### 2-2. Google Drive ノード - Markdown エクスポート機能

**概要**: n8n Google DriveノードのファイルダウンロードにMarkdown形式エクスポートが追加された（PR #25115）。

**Markdownエクスポート仕様**

| 項目 | 詳細 |
|------|------|
| MIMEタイプ | `text/markdown` |
| 対象ファイル | **Google Docs専用**（ネイティブGoogle形式のみ） |
| 非対応ファイル | Word/PDF/画像等（Google形式でないもの）|
| エクスポート選択肢 | HTML, MS Word, Open Office, PDF, RTF, Text, **Markdown（新規）** |

**利用シナリオ**
```
Google Drive（Google Docs形式） → n8n Google Driveノード → Markdown形式でダウンロード
```

**制限事項**
- Google Docs（ネイティブ形式）にのみ対応
- アップロードされたWordやPDFをMarkdownに変換するのには使えない
- Google Sheetsは別途 CSV エクスポートが可能

**コミュニティノード追加選択肢**

| ノード名 | 機能 | 特記事項 |
|---------|------|---------|
| n8n-nodes-google-drive-file | Docs→Markdown, Sheets→CSV, Slides→PlainText変換 | コミュニティ製 |
| n8n-nodes-docx-to-markdown | DOCX→Markdown変換 | コミュニティ製 |

### 2-3. HTTP Request ノード + 外部API連携パターン

**外部変換APIとの連携**: HTTP Requestノードを通じて以下のAPIが利用可能。

| API/サービス | 対応形式 | コスト | 実行環境 |
|-------------|---------|--------|---------|
| Google Document AI | PDF, 画像, Word等 | 有料（従量制）| クラウド |
| Azure Document Intelligence | PDF, 画像, 複合文書 | 有料（従量制）| クラウド |
| Gemini API（Document Understanding）| PDF, 画像等 | 従量制（無料枠あり）| クラウド |
| MinerU API | PDF中心 | 要確認 | クラウド |

### 2-4. Code ノード + npmパッケージ利用

**n8n Code nodeでの外部ライブラリ利用**

| 用途 | ライブラリ | 備考 |
|------|---------|------|
| PDF→テキスト | pdf-parse | n8nセルフホスト環境で利用可能 |
| DOCX→テキスト | mammoth | Node.js系 |
| 汎用変換 | （要確認）| n8n Cloudでは制限あり |

**注意**: n8n Cloudでは外部npmパッケージのインストールに制限がある。セルフホスト環境では自由度が高い。

### 2-5. @bitovi/n8n-nodes-markitdown（コミュニティノード）

**概要**: Microsoft MarkItDownをn8nワークフローに統合するコミュニティノード。

| 項目 | 詳細 |
|------|------|
| 操作 | Convert to Markdown（単一操作）|
| 対応形式 | PDF, Word, PowerPoint, Excel, 画像(OCR), 音声, HTML, CSV, JSON, XML, ZIP |
| 必要環境 | セルフホストn8n + Python 3.7+ + markitdownパッケージ |
| n8n Cloud対応 | **不可**（外部依存あり）|
| セットアップ複雑さ | 高（Dockerfileカスタマイズ必要）|
| コスト | 無料（OSS）|

---

## 3. 比較表: 方法別まとめ

| 方法 | Word | PDF | Excel | 画像 | コスト | 実行環境 | 複雑さ |
|------|------|-----|-------|------|-------|---------|--------|
| n8n Extract from File | ❌ | ✅（テキストのみ）| ✅（ODS）| ❌ | 無料 | n8n内 | 低 |
| n8n Google Drive node（Markdown）| ❌ | ❌ | ❌ | ❌ | 無料 | n8n内 | 低 |
| @bitovi/n8n-nodes-markitdown | ✅ | ✅ | ✅ | ✅（OCR）| 無料 | セルフホスト必須 | 高 |
| microsoft/markitdown（直接利用）| ✅ | ✅ | ✅ | ✅（OCR）| 無料 | Python環境 | 中 |
| HTTP Request + 外部API（Gemini等）| ✅ | ✅ | △ | ✅ | 有料 | n8n内 | 中 |
| Code node + pdf-parse/mammoth | ✅（DOCX）| ✅（テキスト）| △ | ❌ | 無料 | セルフホスト | 中 |

---

## 4. 調査サマリー（軍師統合向け）

### 主要発見

1. **gmail-to-markdown / googledrive-to-markdown リポジトリは公開存在しない**
   - saneakiの公開リポジトリに該当なし。プライベートリポジトリの可能性
   - 代わりに **saneaki/markitdown**（microsoft/markitdownのフォーク）が存在する

2. **殿は microsoft/markitdown をフォーク済み**
   - カスタマイズはされていないが、このライブラリを活用する意図がある可能性
   - n8nとの連携は @bitovi/n8n-nodes-markitdown コミュニティノードで実現可能

3. **n8n内蔵機能の限界**
   - Word (.docx) の直接処理は不可（コミュニティノードが必要）
   - スキャンPDFはOCR外部連携が必須
   - Google Docs → Markdown は公式機能として追加済み（PR #25115）

4. **推奨アーキテクチャ候補**（軍師の統合判断向け）
   - **シンプル構成**: n8n Extract from File（PDF/CSV/HTML）+ Gemini API（複雑文書）
   - **フル対応構成**: セルフホストn8n + @bitovi/n8n-nodes-markitdown（全形式対応）
   - **Google Docs特化**: n8n Google Driveノード Markdownエクスポート（設定最小）

---

**調査完了**: 軍師へ報告後、統合レポート作成を依頼する。
