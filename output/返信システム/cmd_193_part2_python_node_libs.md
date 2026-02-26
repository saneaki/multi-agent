# cmd_193 パート2: Python系/Node.js系ライブラリ + 外部ツール調査レポート

**担当**: ashigaru3
**作成日**: 2026-02-19
**調査対象**: Python系ライブラリ・Node.js系ライブラリ・外部コマンドラインツール

---

## 1. Python系ライブラリ

### 1.1 PyMuPDF / PyMuPDF4LLM

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF, XPS, EPUB, MOBI, FB2, CBZ, SVG等 |
| 変換出力 | Markdown, テキスト, JSON, LlamaIndex形式 |
| 変換品質 | 高品質。見出し・太字・イタリック・コードブロック・リスト・表を自動検出。画像抽出対応（write_images=True） |
| コスト | 無料（オープンソース, AGPL/商用ライセンス） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `pip install pymupdf pymupdf4llm` で導入。n8n CloudではPip不可 |
| VPSセットアップ難易度 | 低: `pip install pymupdf4llm` のみ |
| 備考 | `pymupdf4llm.to_markdown("input.pdf")` で即変換。`page_chunks=True`でページ分割出力。RAG/LLM向けに最適化。LangChain統合あり |

**GitHub**: https://github.com/pymupdf/pymupdf4llm
**PyPI**: https://pypi.org/project/pymupdf4llm/

---

### 1.2 pdfplumber

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF（プログラム生成PDFに特化、スキャンPDFは不得意） |
| 変換出力 | 構造化テキスト、表データ（CSV/DataFrame向け）。Markdown直接出力は非対応 |
| 変換品質 | **表抽出に特化した高精度**。ページ内の文字・矩形・線オブジェクトに詳細アクセス可能。複数段組・表・フォント属性フィルタ対応 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `pip install pdfplumber` |
| VPSセットアップ難易度 | 低: pip一行のみ |
| 備考 | 表データの構造化抽出に強み。テキストのみ抽出→別途Markdown変換が必要。RAGよりDB・分析ユースケース向け |

**GitHub**: https://github.com/jsvine/pdfplumber
**PyPI**: https://pypi.org/project/pdfplumber/

---

### 1.3 python-docx

| 項目 | 内容 |
|------|------|
| 対応形式 | Word (.docx) のみ |
| 変換出力 | テキスト・段落・表・スタイル情報。Markdown直接出力は非対応 |
| 変換品質 | Word文書の構造（段落・表・スタイル）に正確にアクセス可能。Markdown変換には手動コード記述が必要 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `pip install python-docx` |
| VPSセットアップ難易度 | 低: pip一行のみ |
| 備考 | 低レベルAPIのため、Markdown変換には自前ロジック実装が必要。mammoth（Node.js）の方がDocx→HTML/Markdownに適している |

---

### 1.4 markdownify (python-markdownify)

| 項目 | 内容 |
|------|------|
| 対応形式 | HTML入力 → Markdown出力（PDF/Docx直接変換は不可） |
| 変換出力 | GitHub Flavored Markdown対応 |
| 変換品質 | HTML→Markdown変換に特化し高品質。見出し・リスト・表・コードブロック対応。設定でアスタリスク/アンダースコア選択可能 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `pip install markdownify` |
| VPSセットアップ難易度 | 低: pip一行のみ |
| 備考 | PDF/Docx変換の**中間処理**として活用（例: pdf→html→markdownify→md）。最新版2025年11月リリース |

**GitHub**: https://github.com/matthewwithanm/python-markdownify
**PyPI**: https://pypi.org/project/markdownify/

---

### 1.5 marker-pdf (marker)

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF, DOCX, PPTX, XLSX, HTML, EPUB, 画像 |
| 変換出力 | Markdown, JSON, HTML, chunks形式 |
| 変換品質 | **最高品質クラス**。Surya OCRエンジン+オプションLLM統合（Gemini等）。多段組・表・数式・破損テキスト対応。100言語以上。GPU加速対応。H100で122ページ/分 |
| コスト | 無料（GPL-3.0）。LLM統合時はAPI費用別途 |
| n8n Code node利用可否 | **困難**: PyTorch依存で重い（数GB）。n8n Code node内での直接実行は非推奨。Execute Commandノード経由が現実的 |
| VPSセットアップ難易度 | **高**: `pip install marker-pdf` + PyTorch + 追加依存。GPU推奨（CPU動作は遅い） |
| 備考 | ローカル高品質変換の最右翼。VPS単体では重く、専用サーバー化（marker-api）を推奨 |

**GitHub**: https://github.com/datalab-to/marker
**PyPI**: https://pypi.org/project/marker-pdf/

---

### 1.6 docling (IBM)

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF, DOCX, PPTX, HTML, 画像（OCR対応） |
| 変換出力 | Markdown, JSON, HTML, DocTags形式 |
| 変換品質 | **高品質**。IBM Research開発。ページレイアウト・読み順・表構造・コード・数式・画像分類を理解。OCR不要時はコンピュータビジョンモデルで30倍高速 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **困難**: 重い依存（transformers等）。Execute Commandノード経由が現実的 |
| VPSセットアップ難易度 | **高**: `pip install docling` + 大規模ML依存。初回起動時にモデルダウンロード必要 |
| 備考 | LangChain・LlamaIndex・CrewAI・Haystack統合対応。AIアジェンティックワークフローに最適。air-gapped環境でのローカル実行も可能 |

**GitHub**: https://github.com/docling-project/docling
**公式ドキュメント**: https://docling-project.github.io/docling/

---

### 1.7 Microsoft MarkItDown

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF, Word, Excel, PowerPoint, 画像, HTML, 音声, URL等（多形式対応） |
| 変換出力 | Markdown (LLM向け) |
| 変換品質 | 中品質。軽量・シンプル設計でLLM入力向けに最適化。複雑なレイアウトは不得意な場合あり |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `pip install markitdown` (Python 3.10以上) |
| VPSセットアップ難易度 | **低〜中**: pip一行。依存は比較的軽量 |
| 備考 | 2024年末Microsoft公開。複数形式をワンストップ処理できる点が強み |

**GitHub**: https://github.com/microsoft/markitdown

---

## 2. Node.js系ライブラリ

### 2.1 pdf-parse

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF |
| 変換出力 | プレーンテキスト（Markdown変換は別途必要） |
| 変換品質 | テキスト抽出に特化。ネイティブ依存なし（Pure TypeScript）。メタデータ・パスワード保護PDF対応 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `npm install pdf-parse`。n8n Cloudでは外部npm不可 |
| VPSセットアップ難易度 | 低: npm一行 |
| 備考 | ブラウザ・Node.js両対応。表・画像の構造的変換は非対応。テキスト抽出後にturndown等でMarkdown化が必要 |

**npm**: https://www.npmjs.com/package/pdf-parse

---

### 2.2 mammoth

| 項目 | 内容 |
|------|------|
| 対応形式 | Word (.docx) のみ |
| 変換出力 | HTML（主用途）、Markdown（非推奨・制限あり） |
| 変換品質 | **Docx→HTML変換に高品質**。スタイルマッピングで見出し・太字等を制御可能。公式はHTML→Markdown変換（turndown等）を推奨 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `npm install mammoth` |
| VPSセットアップ難易度 | 低: npm一行 |
| 備考 | Docx→HTML→Markdown（turndown経由）の2段変換が推奨フロー。ブラウザ・Node.js両対応 |

**npm**: https://www.npmjs.com/package/mammoth

---

### 2.3 turndown

| 項目 | 内容 |
|------|------|
| 対応形式 | HTML入力 → Markdown出力 |
| 変換出力 | CommonMark / GFM対応Markdown |
| 変換品質 | 高品質。プラグイン拡張対応（GFM表・Strikethrough等）。カスタムルール追加可能 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `npm install turndown` |
| VPSセットアップ難易度 | 低: npm一行 |
| 備考 | mammoth（docx→HTML）と組み合わせた**docx→HTML→Markdown**パイプラインが定番。MCP Server実装にも採用されるほど信頼性高い |

**GitHub**: https://github.com/mixmark-io/turndown
**npm**: https://www.npmjs.com/package/turndown

---

### 2.4 unified / remark

| 項目 | 内容 |
|------|------|
| 対応形式 | Markdown ↔ HTML変換（AST処理パイプライン）。入力変換は別パーサーが必要 |
| 変換出力 | Markdown, HTML, AST |
| 変換品質 | **プラグインエコシステムが強力**。CommonMark準拠。TypeScript完全対応。remark-gfm（GFM）、remark-lint等豊富なプラグイン |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **可（自己ホスト限定）**: `npm install unified remark remark-parse remark-stringify` |
| VPSセットアップ難易度 | 低: npm |
| 備考 | Markdown処理・変換・バリデーション等の**後処理パイプライン**として強力。PDF/Docx直接変換には不向き。他ライブラリの出力整形に活用 |

**GitHub**: https://github.com/remarkjs/remark
**npm**: https://www.npmjs.com/package/remark

---

### 2.5 pdf2md

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF |
| 変換出力 | Markdown |
| 変換品質 | 中品質。PDF.jsベースのクライアントサイドPDF→Markdown変換 |
| コスト | 無料（MIT） |
| n8n Code node利用可否 | **限定的**: Node.js環境依存。PDF.jsとの組み合わせ設定が必要 |
| VPSセットアップ難易度 | 中: 複数依存あり |
| 備考 | Webサービス版（pdf2md.morethan.io）が有名。Node.js実装は活発なメンテが減少傾向 |

---

## 3. 外部ツール / コマンドラインツール

### 3.1 Pandoc

| 項目 | 内容 |
|------|------|
| 対応形式 | **30種類以上の形式に対応**（Markdown, HTML, PDF, DOCX, LaTeX, EPUB等） |
| 変換出力 | Markdown（複数フレーバー）, HTML, PDF, DOCX等すべて |
| 変換品質 | **高品質**。見出し・表・引用・脚注・数式（LaTeX）・TOC対応。文献引用（CSL）対応 |
| コスト | 無料（GPL） |
| n8n Code node利用可否 | **Execute Commandノード経由**: `pandoc input.docx -o output.md` |
| VPSセットアップ難易度 | **低**: `apt install pandoc` のみ |
| 備考 | DocxからMarkdownへの変換が特に優秀。PDFはpdflatex経由の**PDF出力**のみ対応（PDF→Markdown変換は不得意）。VPS上でn8nのExecute Commandノードから容易に呼び出し可能 |

**公式**: https://pandoc.org/
**GitHub**: https://github.com/jgm/pandoc

---

### 3.2 Mathpix

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF（特に数式・STEM文書）、画像 |
| 変換出力 | Markdown, LaTeX, HTML, DOCX |
| 変換品質 | **数式変換に特化した最高品質**。OCRと数式認識を組み合わせ、TeX形式の数式を正確に変換 |
| コスト | **有料（従量課金）**: API呼び出し単位で課金。2025年3月より値下げ実施 |
| n8n Code node利用可否 | **HTTP Requestノード経由**: REST API（v3/pdf）を呼び出し |
| VPSセットアップ難易度 | **低**: APIキー登録のみ（サーバー側設定不要） |
| 備考 | 数式・科学技術文書専用。一般文書には過剰スペック・高コスト。n8n HTTP Requestノードから呼び出し容易 |

**公式**: https://mathpix.com/
**API**: https://docs.mathpix.com/

---

### 3.3 MinerU

| 項目 | 内容 |
|------|------|
| 対応形式 | PDF |
| 変換出力 | Markdown, JSON |
| 変換品質 | **学術論文・複雑PDF向けに高品質**。複雑な表をHTMLでレンダリング。LLM向け構造化出力 |
| コスト | 無料（オープンソース） |
| n8n Code node利用可否 | **Execute Commandノード経由**: Python CLI経由。重い依存あり |
| VPSセットアップ難易度 | **高**: ML依存が多く、GPUなしでは遅い |
| 備考 | marker-pdfと双璧の高品質変換ツール。OpenDataLab（上海AI Lab）開発 |

**GitHub**: https://github.com/opendatalab/MinerU

---

### 3.4 その他（参考）

| ツール | 形式 | 特徴 | コスト |
|--------|------|------|--------|
| Aspose.Words (Cloud) | PDF, DOCX, 多数 | 商用グレード・高精度。REST API | 有料 |
| pdf2md.morethan.io | PDF | Webサービス版（API非公開） | 無料 |
| Dolphin (ByteDance) | PDF | ViT OCR + レイアウト理解 | 無料（重い） |

---

## 4. 総合比較表

### Python系ライブラリ比較

| ライブラリ | PDF対応 | Docx対応 | 変換品質 | n8n利用 | セットアップ難易度 | コスト |
|-----------|---------|----------|----------|---------|-----------------|--------|
| PyMuPDF4LLM | ◎ | △ | 高 | ○(自ホスト) | 低 | 無料 |
| pdfplumber | ◎(表抽出) | × | 高(表) | ○(自ホスト) | 低 | 無料 |
| python-docx | × | ◎ | 中(低レベル) | ○(自ホスト) | 低 | 無料 |
| markdownify | HTML→MD | HTML→MD | 高(HTML) | ○(自ホスト) | 低 | 無料 |
| marker-pdf | ◎ | ◎ | 最高 | △(重い) | 高 | 無料 |
| docling | ◎ | ◎ | 高 | △(重い) | 高 | 無料 |
| MarkItDown | ◎ | ◎ | 中 | ○(自ホスト) | 低〜中 | 無料 |

### Node.js系ライブラリ比較

| ライブラリ | PDF対応 | Docx対応 | 変換品質 | n8n利用 | セットアップ難易度 | コスト |
|-----------|---------|----------|----------|---------|-----------------|--------|
| pdf-parse | ◎(テキスト) | × | 中(テキストのみ) | ○(自ホスト) | 低 | 無料 |
| mammoth | × | ◎ | 高(HTML) | ○(自ホスト) | 低 | 無料 |
| turndown | HTML→MD | HTML→MD | 高(HTML) | ○(自ホスト) | 低 | 無料 |
| unified/remark | MD処理 | MD処理 | 高(後処理) | ○(自ホスト) | 低 | 無料 |

### 外部ツール比較

| ツール | PDF対応 | Docx対応 | 変換品質 | n8n利用方法 | セットアップ難易度 | コスト |
|--------|---------|----------|----------|------------|-----------------|--------|
| Pandoc | △(出力のみ) | ◎ | 高 | Execute Command | 低 | 無料 |
| Mathpix | ◎(数式) | × | 最高(数式) | HTTP Request | 低(API) | 有料 |
| MinerU | ◎ | × | 最高 | Execute Command | 高 | 無料 |

---

## 5. n8n Code node での利用制約まとめ

```
n8n Code nodeでnpm/pip使用可否:
- n8n Cloud: npm/pip ともに不可（外部パッケージ使用不可）
- 自己ホスト(Docker):
    npm → N8N_NODE_FUNCTION_ALLOW_EXTERNAL=* 設定で一部解禁
    pip → コンテナにpip install済み環境を用意（Dockerfile カスタマイズ）
- n8n Code nodeは軽量ライブラリのみ推奨
  重いML系（marker, docling, MinerU）はExecute Commandノード経由を推奨
- 推奨アーキテクチャ（VPS自己ホスト）:
    軽量: PyMuPDF4LLM / MarkItDown → n8n Python Code node
    重量: marker / docling → Execute Command / 別サービス化
    Docx: Pandoc → Execute Command（apt installのみ）
    Docx+Node: mammoth+turndown → JavaScript Code node
```

---

## 6. 推奨ユースケース別選択指針

| ユースケース | 推奨ツール | 理由 |
|------------|-----------|------|
| PDF→Markdown（軽量・即座） | PyMuPDF4LLM | インストール簡単、高品質 |
| PDF→Markdown（最高品質） | marker-pdf or MinerU | ML精度最高、ただし重い |
| Docx→Markdown（n8n内） | mammoth + turndown | npm、軽量、HTML中間変換 |
| Docx→Markdown（VPS） | Pandoc | apt install一行、高品質 |
| HTML→Markdown | markdownify(Py) / turndown(JS) | 中間変換として定番 |
| 数式含むPDF | Mathpix API | 数式変換精度が圧倒的 |
| 多形式ワンストップ | MarkItDown | PDF/Word/Excel等をまとめて処理 |
| 表データ抽出 | pdfplumber | 表抽出に特化した高精度 |

---

*調査担当: ashigaru3 / cmd_193 パート2*
