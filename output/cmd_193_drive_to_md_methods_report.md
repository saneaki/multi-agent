# cmd_193: Google Drive文書 → Markdown変換 方法論調査レポート

**作成**: 軍師（gunshi）
**作成日**: 2026-02-19
**調査体制**: 足軽1号(既存リポジトリ+n8n)・足軽3号(Python/Node系)・足軽4号(Gemini/DocAI/GAS)の並列調査を統合

---

## 調査目的

Google Driveに格納された文書（PDF, Word, Excel等）をMarkdown形式に変換する方法を網羅的に調査し、殿の既存インフラ（n8n, VPS, Google Workspace, Gemini API）に最適な手法を推奨する。

---

## 1. 調査結果サマリー

### 1.1 殿の既存資産

| 資産 | 状態 | 備考 |
|------|------|------|
| saneaki/markitdown | フォーク済み | microsoft/markitdown（Stars 87k+）のフォーク。カスタマイズなし |
| gmail-to-markdown | 非公開 | 公開リポジトリに存在しない（プライベートの可能性） |
| googledrive-to-markdown | 非公開 | 同上 |
| n8n (Docker, VPS) | 稼働中 | セルフホスト。Execute Command・Code node利用可能 |
| Gemini API credential | 使用中 | 法律文書WF等で運用実績あり |
| Google Workspace | 使用中 | Gmail, Drive, Docs連携済み |

### 1.2 調査した手法（全19件）

| カテゴリ | 件数 | 主要ツール |
|---------|------|-----------|
| Google系API/サービス | 4件 | Gemini API, Drive API OCR, Document AI, GAS |
| Python系ライブラリ | 7件 | PyMuPDF4LLM, pdfplumber, marker-pdf, docling, MarkItDown等 |
| Node.js系ライブラリ | 5件 | pdf-parse, mammoth, turndown, unified/remark, pdf2md |
| 外部ツール | 3件 | Pandoc, Mathpix, MinerU |

---

## 2. 総合比較表

### 2.1 主要手法の横断比較

| 手法 | PDF | Word | Excel | 画像OCR | MD品質 | コスト | n8n統合 | セットアップ |
|------|-----|------|-------|---------|--------|--------|---------|------------|
| **Gemini 2.0 Flash** | ◎ | ◎ | ○ | ◎ | ★5 | 0.4円/10p | ★5 | ★5(既存cred) |
| **MarkItDown** | ○ | ◎ | ◎ | △(要OCR) | ★3 | 無料 | ★3 | ★4(pip) |
| **PyMuPDF4LLM** | ◎ | △ | × | × | ★4 | 無料 | ★3 | ★4(pip) |
| **Pandoc** | △(出力のみ) | ◎ | × | × | ★4 | 無料 | ★4(apt) | ★5(apt) |
| **mammoth+turndown** | × | ◎ | × | × | ★4 | 無料 | ★4(npm) | ★4(npm) |
| **marker-pdf** | ◎ | ◎ | ○ | ◎ | ★5 | 無料 | ★1(重い) | ★1(GPU推奨) |
| **docling (IBM)** | ◎ | ◎ | × | ◎ | ★4 | 無料 | ★1(重い) | ★1(ML依存) |
| **n8n Extract from File** | ○(text) | × | ○(ODS) | × | ★2 | 無料 | ★5(組込) | ★5(不要) |
| **Drive API OCR** | △(10p制限) | × | × | △ | ★2 | 無料 | ★4 | ★4 |
| **Document AI** | ◎ | ○ | ○ | ◎ | ★5 | $1.50/p | ★2 | ★1(GCP) |
| **GAS** | △(10p制限) | ○ | ○ | △ | ★3 | 無料 | ★3(Webhook) | ★3 |
| **Mathpix** | ◎(数式) | × | × | ◎ | ★5(数式) | 有料 | ★4(API) | ★4(API) |

### 2.2 評価基準

- **MD品質**: Markdown変換の構造保持・正確性（★1〜5）
- **コスト**: 1ファイルあたりのランニングコスト
- **n8n統合**: n8nワークフローへの組み込み容易さ（★1〜5）
- **セットアップ**: 初期導入の手軽さ（★1〜5）

---

## 3. 推奨案3案

### 推奨案A: Gemini 2.0 Flash API 一本化（最推奨）

**概要**: 全ファイル形式をGemini 2.0 Flash APIで処理する最もシンプルな構成。

```
[Google Drive] → [n8n: Driveノード DL] → [n8n: HTTP Request / AI Agent]
  → [Gemini 2.0 Flash: "このファイルをMarkdownに変換せよ"]
  → [Markdown出力] → [保存/後続処理]
```

| 評価軸 | 評価 |
|--------|------|
| 対応形式 | PDF, Word, Excel, 画像, スキャンPDF — 全形式対応 |
| 変換品質 | 最高クラス（AIによる文脈理解・レイアウト認識） |
| コスト | 約0.4円/10ページ（Flash）。無料枠1,500 req/日 |
| n8n統合 | 既存Gemini credential再利用。n8nテンプレート多数あり |
| セットアップ | 追加設定ほぼ不要（HTTP Requestノードのみ） |
| ページ制限 | 1,000ページ/リクエスト（1Mトークンコンテキスト） |
| 日本語精度 | 最高クラス（マルチモーダルLLM） |

**長所**:
- 実装が最もシンプル（1ノードで完結可能）
- 既存インフラをそのまま活用
- スキャンPDF・画像OCRも追加設定なしで対応
- 法律文書の複雑なレイアウト・表も高精度で処理

**短所**:
- API従量課金（ただし非常に安価）
- ネットワーク依存（オフライン不可）
- 大量処理時のレート制限（1,500 req/日の無料枠）

**コスト試算**:
- 月100ファイル（平均10p）: 約40円/月
- 月1,000ファイル（平均10p）: 約400円/月（無料枠内に収まる可能性大）

---

### 推奨案B: MarkItDown + Pandoc（ローカルOSS構成）

**概要**: 殿がフォーク済みのMarkItDownとPandocを組み合わせ、API費用ゼロで変換する構成。

```
[Google Drive] → [n8n: Driveノード DL]
  → [形式判定]
  → PDF:   [Execute Command: markitdown input.pdf]
  → Word:  [Execute Command: pandoc input.docx -o output.md]
  → Excel: [Execute Command: markitdown input.xlsx]
  → [Markdown出力] → [保存/後続処理]
```

| 評価軸 | 評価 |
|--------|------|
| 対応形式 | PDF(テキスト), Word, Excel, PowerPoint, HTML |
| 変換品質 | 中〜高（テキストベース文書は良好。スキャンPDFは不可） |
| コスト | 完全無料（OSS） |
| n8n統合 | Execute Commandノード経由。Docker環境のカスタマイズ必要 |
| セットアップ | 中程度（pip install markitdown + apt install pandoc） |
| ページ制限 | なし（ローカル処理） |
| 日本語精度 | 中（テキスト抽出は正確。OCRは対応外） |

**長所**:
- ランニングコスト完全ゼロ
- オフライン動作可能
- 殿がmarkitdownをフォーク済み（カスタマイズ可能）
- Pandocはapt一行で導入可能

**短所**:
- スキャンPDF・画像のOCR不可（テキスト埋込PDFのみ）
- Dockerfileカスタマイズが必要（Python環境追加）
- 複雑なレイアウト（表・多段組）の変換精度が劣る
- 形式別にツールを使い分けるロジックが必要

**セットアップ手順**:
```bash
# VPSのn8n Dockerコンテナに追加
pip install 'markitdown[all]'
apt install pandoc
```

---

### 推奨案C: ハイブリッド構成（Gemini + MarkItDown/Pandoc）

**概要**: 文書の特性に応じてローカル処理とAI処理を使い分ける最適化構成。

```
[Google Drive] → [n8n: Driveノード DL]
  → [判定ノード: 文書タイプ・複雑度]
  → テキストPDF/Word/Excel (単純):
      [MarkItDown / Pandoc（ローカル・無料）]
  → スキャンPDF/画像/複雑文書:
      [Gemini 2.0 Flash API（高品質・低コスト）]
  → [Markdown出力] → [保存/後続処理]
```

| 評価軸 | 評価 |
|--------|------|
| 対応形式 | 全形式対応（ローカル+AI のフォールバック構成） |
| 変換品質 | 最高（複雑文書はGemini、単純文書はローカルで十分） |
| コスト | 最小化（単純文書は無料、複雑文書のみAPI課金） |
| n8n統合 | 中程度（ルーティングロジックの実装が必要） |
| セットアップ | 中〜高（ローカル環境+Gemini両方の設定） |
| 柔軟性 | 最高（将来の拡張・ツール追加が容易） |

**長所**:
- コスト最適化（大半の文書はローカルで無料処理）
- 全形式・全品質レベルに対応
- 段階的に導入可能（まずGeminiだけ→後からローカル追加）

**短所**:
- アーキテクチャが最も複雑
- ルーティングロジックの設計・テストが必要
- メンテナンスコストが高い

---

## 4. 推奨案比較

| 評価軸 | 案A: Gemini一本化 | 案B: ローカルOSS | 案C: ハイブリッド |
|--------|------------------|-----------------|-----------------|
| **実装コスト** | ★5（最小） | ★3 | ★2 |
| **ランニングコスト** | ★4（月数十円〜） | ★5（無料） | ★5（ほぼ無料） |
| **変換品質** | ★5 | ★3 | ★5 |
| **対応形式の広さ** | ★5 | ★3 | ★5 |
| **保守容易性** | ★5 | ★4 | ★2 |
| **既存インフラ活用** | ★5 | ★4 | ★4 |
| **総合スコア** | **30/30** | **22/30** | **23/30** |

---

## 5. 最終推奨

### 推奨案A: Gemini 2.0 Flash API 一本化を最終推奨とする

**推奨理由**:

1. **実装の圧倒的シンプルさ**: 既存のGemini credential + HTTP Requestノード1つで全形式に対応。WF開発工数が最小。

2. **変換品質が最高**: マルチモーダルLLMによる文脈理解は、テキスト抽出系ツール（MarkItDown, PyMuPDF等）を品質で凌駕。法律文書の複雑な表・注釈・参照構造も正確に変換。

3. **コストが実質無視できる水準**: 月100ファイル処理で約40円。無料枠（1,500 req/日）で大半のユースケースをカバー。

4. **スキャンPDF・画像にも追加設定なしで対応**: ローカルツールではOCR連携が別途必要な場面でも、Geminiは単一のAPIコールで完結。

5. **n8nテンプレートが豊富**: 「5 ways to process images & PDFs with Gemini AI in n8n」等の公式テンプレートが存在し、実装の参考になる。

6. **殿の既存インフラとの完全な親和性**: Gemini API keyは既にn8n WFで使用中。追加設定ゼロで即座に利用開始可能。

### 将来の発展パス

```
Phase 1（即時）: Gemini 2.0 Flash API 一本化で運用開始
Phase 2（必要に応じて）: 大量処理時のコスト最適化でMarkItDown/Pandocを追加（案Cへ移行）
Phase 3（将来）: 専用変換サーバー構築（marker-pdf等）で完全ローカル化
```

### 実装に必要なアクション

| 優先度 | アクション | 担当 |
|--------|----------|------|
| P1 | n8n WFにGemini PDF→MD変換ノードを追加 | 足軽 |
| P1 | プロンプト設計（「Markdownに変換せよ」の最適化） | 軍師 |
| P2 | バッチ処理WF設計（Drive内の複数ファイル一括変換） | 家老 |
| P3 | MarkItDown/Pandocのローカル環境整備（案Cへの発展準備） | 足軽 |

---

## 参考: 個別調査レポート

| パート | 担当 | ファイル |
|--------|------|---------|
| パート1: 既存リポジトリ+n8n | 足軽1号 | output/cmd_193_part1_existing_repos_n8n.md |
| パート2: Python/Node系ライブラリ | 足軽3号 | output/cmd_193_part2_python_node_libs.md |
| パート3: Gemini/DocAI/GAS | 足軽4号 | output/cmd_193_part3_gemini_docai_gas.md |

---

## 参考リンク（主要）

- [Gemini API - Document understanding](https://ai.google.dev/gemini-api/docs/document-processing)
- [Gemini API Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [microsoft/markitdown](https://github.com/microsoft/markitdown) (Stars 87k+)
- [PyMuPDF4LLM](https://github.com/pymupdf/pymupdf4llm)
- [Pandoc](https://pandoc.org/)
- [marker-pdf](https://github.com/datalab-to/marker)
- [docling (IBM)](https://github.com/docling-project/docling)
- [n8n: 5 ways to process PDFs with Gemini](https://n8n.io/workflows/3078-5-ways-to-process-images-and-pdfs-with-gemini-ai-in-n8n/)
- [@bitovi/n8n-nodes-markitdown](https://www.npmjs.com/package/@bitovi/n8n-nodes-markitdown)
