# cmd_155: PDF統合パイプライン設計書

## 概要

既存の PDF Page Checker（cmd_149）を拡張し、複数PDFの**結合 + 日本語OCR + 重複・脱漏検知**を一括処理する Streamlit アプリケーションを設計する。

**対象ユーザー**: 学術書スキャンPDFを扱う法律事務所スタッフ
**動作環境**: WSL2 (Ubuntu) + Python 3.10+
**ベースコード**: `/home/saneaki/hananoen/pdf_page_checker/`

---

## 1. 技術選定

### 1.1 OCRライブラリ比較

| 項目 | Tesseract (pytesseract) | EasyOCR | PaddleOCR (PP-OCRv5) | Surya OCR |
|------|------------------------|---------|---------------------|-----------|
| 日本語精度 | 良好（前処理依存） | 非常に良好 | **最高（94.5%）** | 良好 |
| WSL2導入 | 容易（apt + pip） | 最も容易（pip のみ） | 容易（pip のみ） | やや複雑 |
| Python API | シンプル | 優秀 | 優秀 | 良好 |
| 処理速度 | 中程度 | 中程度 | **最速** | 中程度 |
| ライセンス | Apache 2.0 | Apache 2.0 | Apache 2.0 | OSS |
| サイズ | 小（言語データ約2MB） | 中（100-300MB） | **極小（<10MB）** | 大（GPU 12.8GB推奨） |
| 保守状況 | 活発（v5） | 活発 | **非常に活発（2026年1月更新）** | 活発 |

### 1.2 OCR推奨案: PaddleOCR（PP-OCRv5）

**選定理由:**

1. **最高精度**: OmniDocBench v1.5 で 94.5%（v4比13%向上）、日本語に特化した最適化あり
2. **軽量**: モデルサイズ <10MB、CPU版でも実用的な速度
3. **PDF直接処理**: `ocr.ocr('file.pdf')` でPDFを直接処理可能
4. **活発な開発**: 2026年1月に PaddleOCR-VL-1.5 リリース
5. **Apache 2.0**: 商用利用可能

**フォールバック**: EasyOCR（PaddleOCR導入に問題が生じた場合の代替）

**導入コマンド:**

```bash
pip install paddlepaddle paddleocr
```

### 1.3 重複検知アルゴリズム比較

| 手法 | 精度 | 速度 | FP率 | FN率 | ブランクページ対応 |
|------|------|------|------|------|-------------------|
| テキスト類似度（コサイン類似度） | 高 | 中（OCRがボトルネック） | <2% | 5-10% | 不可 |
| 画像ハッシュ（dHash/pHash） | 高 | **最速（150ms/ページ）** | <1% | 3-5% | 対応 |
| **ハイブリッド（2段階）** | **最高** | **高速（200ms/ページ）** | **<1%** | **2-3%** | **対応** |

### 1.4 重複検知推奨案: ハイブリッド2段階フィルタリング

**Stage 1（高速スクリーニング）**: dHash による画像ハッシュ比較

- PyMuPDF でページを画像化（約100ms/ページ）
- dHash 計算（約10ms/画像）
- ハミング距離 ≤ 3 で重複候補を抽出

**Stage 2（精密検証）**: OCRテキスト + コサイン類似度

- Stage 1 で抽出された候補ペアのみOCR実行
- TF-IDF ベクトル化 + コサイン類似度
- 閾値 > 0.95 で重複確定

**選定理由:**

- 200ページPDFで約40秒（Stage 1: 30秒 + Stage 2: 10秒）
- 偽陽性 <1%、偽陰性 2-3%
- ブランクページ・画像のみページにも対応

---

## 2. アーキテクチャ設計

### 2.1 モジュール構成

```
pdf_page_checker/
├── app.py                    # Streamlit メインアプリ（既存を拡張）
├── page_detector.py          # ページ番号検出（既存・変更なし）
├── ocr_engine.py             # NEW: OCRエンジン抽象化
├── pdf_merger.py             # NEW: PDF結合処理
├── duplicate_detector.py     # NEW: 重複検知（ハイブリッド）
├── pipeline.py               # NEW: パイプラインオーケストレーター
├── requirements.txt          # 依存パッケージ（拡張）
├── tests/
│   ├── test_page_detector.py # 既存テスト
│   ├── test_ocr_engine.py    # NEW
│   ├── test_pdf_merger.py    # NEW
│   ├── test_duplicate.py     # NEW
│   └── test_pipeline.py      # NEW
└── README.md
```

### 2.2 既存コードとの統合方針

- `page_detector.py`: **変更なし**。現在のページ番号検出ロジックをそのまま利用
- `app.py`: Streamlit UIを拡張し、新機能のタブ/画面を追加
- 新モジュールは既存コードに依存しつつ、独立してテスト可能な設計

### 2.3 データフロー

```
[入力: フォルダ/複数PDFファイル]
         │
         ▼
┌─────────────────────┐
│  1. PDF結合          │ pdf_merger.py
│  - ファイルソート     │ - 自然順ソート（natsort）
│  - ブックマーク生成   │ - PyPDF2/PyMuPDF
│  - 結合PDF出力       │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  2. 日本語OCR        │ ocr_engine.py
│  - ページ画像化      │ - PyMuPDF (fitz)
│  - テキスト抽出      │ - PaddleOCR
│  - 結果キャッシュ    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  3. ページ番号検出    │ page_detector.py（既存）
│  - ヘッダ/フッタ解析 │ - extract_page_numbers_from_text()
│  - 連番チェック      │ - check_sequence()
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  4. 重複検知         │ duplicate_detector.py
│  - Stage1: dHash     │ - imagehash
│  - Stage2: OCR+類似度│ - scikit-learn
└─────────┬───────────┘
          │
          ▼
[出力: 統合レポート（Streamlit画面）]
  - 結合PDFダウンロード
  - 脱漏ページ一覧
  - 重複ページ一覧
  - OCRテキストプレビュー
```

### 2.4 各モジュール詳細

#### ocr_engine.py

```python
class OCREngine:
    """OCRエンジン抽象化。PaddleOCR をデフォルトで使用。"""

    def __init__(self, engine: str = "paddleocr"):
        ...

    def extract_text(self, pdf_path: str, page_num: int) -> str:
        """指定ページのテキストを抽出。"""
        ...

    def extract_all(self, pdf_path: str) -> list[PageText]:
        """全ページのテキストを一括抽出。"""
        ...
```

#### pdf_merger.py

```python
class PDFMerger:
    """複数PDFファイルを1つに結合。"""

    def merge(self, pdf_paths: list[str], output_path: str) -> MergeResult:
        """PDFを結合しブックマーク付きで出力。"""
        ...
```

#### duplicate_detector.py

```python
class DuplicateDetector:
    """ハイブリッド2段階重複検知。"""

    def detect(self, pdf_path: str) -> list[DuplicatePair]:
        """重複ページペアを検出。"""
        # Stage 1: dHash スクリーニング
        # Stage 2: OCR + コサイン類似度検証
        ...
```

#### pipeline.py

```python
class PDFPipeline:
    """結合→OCR→検知の一括パイプライン。"""

    def run(self, input_dir: str, options: PipelineOptions) -> PipelineResult:
        """パイプライン全体を実行。"""
        ...
```

---

## 3. UI設計（Streamlit画面構成）

### 3.1 画面レイアウト

```
┌──────────────────────────────────────────────┐
│  PDF統合パイプライン                          │
│  ──────────────────────────────────────────── │
│  [結合] [OCR] [ページチェック] [重複検知]      │  ← タブ切替
├──────────────────────────────────────────────┤
│                                              │
│  ▶ 入力セクション                             │
│  ┌──────────────────────────────────────┐    │
│  │  📂 フォルダパスを入力 or ファイル選択  │    │
│  │  [____________________________] [参照]│    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ▶ オプション                                │
│  ☑ PDF結合  ☑ OCR  ☑ ページチェック  ☑ 重複検知│
│  OCRエンジン: [PaddleOCR ▼]                   │
│  重複検知閾値: [0.95 ─────●──]                │
│                                              │
│  [▶ 一括処理開始]                             │
│                                              │
├──────────────────────────────────────────────┤
│  ▶ 進捗                                     │
│  ████████████░░░░░░░░ 60% (OCR処理中... 12/20)│
│                                              │
├──────────────────────────────────────────────┤
│  ▶ 結果サマリー                               │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                │
│  │ 5  │ │ 98 │ │ 2  │ │ 1  │                │
│  │ファ│ │検出│ │欠落│ │重複│                │
│  │イル│ │ペジ│ │ペジ│ │ペジ│                │
│  └────┘ └────┘ └────┘ └────┘                │
│                                              │
│  ▶ 詳細結果（タブ内）                         │
│  ...                                         │
│                                              │
│  [📥 結合PDFダウンロード] [📥 レポートCSV]     │
└──────────────────────────────────────────────┘
```

### 3.2 タブ構成

| タブ | 機能 | 単独実行 |
|------|------|----------|
| **結合** | 複数PDFをソート＆結合、ブックマーク付与 | 可 |
| **OCR** | PDFからテキスト抽出、結果プレビュー | 可 |
| **ページチェック** | 既存のページ飛び検出（cmd_149互換） | 可 |
| **重複検知** | 重複ページの視覚的比較表示 | 可 |
| **一括処理** | 上記すべてをパイプライン実行 | — |

### 3.3 ユーザー操作フロー

1. フォルダパス入力 or ファイルアップロード
2. 処理オプション選択（チェックボックス）
3. 「一括処理開始」ボタン押下
4. 進捗バーでリアルタイム表示
5. 結果サマリー確認
6. 各タブで詳細確認
7. 結合PDF / レポートCSVダウンロード

---

## 4. 実装フェーズ分割

### Phase 1: PDF結合モジュール（独立）

**作業内容:**

- `pdf_merger.py` の実装
  - 自然順ソート（natsort）
  - PyPDF2 による結合処理
  - PyMuPDF によるブックマーク付与
  - 破損PDF のスキップ処理
- `test_pdf_merger.py` の実装
- 既存 `pdf_tools/pdf_merger_dnd.py` からロジックを参考

**依存**: なし（独立実行可能）

### Phase 2: OCRエンジンモジュール（独立）

**作業内容:**

- `ocr_engine.py` の実装
  - PaddleOCR ラッパー
  - ページ単位テキスト抽出
  - バッチ処理対応
  - 結果キャッシュ（同一PDFの再処理回避）
- `test_ocr_engine.py` の実装
- PaddleOCR のWSL2動作検証

**依存**: なし（独立実行可能）

### Phase 3: 重複検知モジュール（独立）

**作業内容:**

- `duplicate_detector.py` の実装
  - Stage 1: dHash による高速スクリーニング
  - Stage 2: OCRテキスト + コサイン類似度
  - 結果レポート生成
- `test_duplicate.py` の実装

**依存**: Phase 2 の ocr_engine.py（Stage 2 で使用）。ただし Stage 1 のみで先行実装可能

### Phase 4: パイプライン統合 + UI（Phase 1-3 完了後）

**作業内容:**

- `pipeline.py` の実装（Phase 1-3 のオーケストレーション）
- `app.py` の拡張（タブUI、進捗表示、ダウンロード機能）
- `test_pipeline.py` の実装
- E2Eテスト

**依存**: Phase 1, 2, 3 すべて完了が前提

### フェーズ依存関係図

```
Phase 1 (結合) ──┐
Phase 2 (OCR)  ──┼── Phase 4 (統合+UI)
Phase 3 (重複) ──┘
     ↑
  Phase 2に部分依存（Stage 2のみ）
```

**並列化可能性**: Phase 1, 2, 3 は**独立して並列実行可能**。Phase 4 は全Phase完了後。

---

## 5. 依存パッケージとインストール要件

### 5.1 requirements.txt（想定）

```
# 既存
streamlit>=1.30.0
pdfplumber>=0.10.0
pytest>=8.0.0

# PDF結合
PyPDF2>=3.0.0
PyMuPDF>=1.23.0
natsort>=8.4.0

# OCR
paddlepaddle>=2.6.0
paddleocr>=2.8.0

# 重複検知
imagehash>=4.3.0
Pillow>=10.0.0
scikit-learn>=1.4.0

# テスト
pytest-cov>=4.1.0
```

### 5.2 WSL2固有の依存（apt packages）

```bash
# PaddleOCR の依存
sudo apt update
sudo apt install -y libgl1-mesa-glx libglib2.0-0

# フォールバック用（Tesseract を Stage 2 で使う場合）
# sudo apt install -y tesseract-ocr tesseract-ocr-jpn
```

### 5.3 インストール手順

```bash
# 1. システムパッケージ
sudo apt update && sudo apt install -y libgl1-mesa-glx libglib2.0-0

# 2. Python仮想環境
cd /home/saneaki/hananoen/pdf_page_checker
python3 -m venv .venv
source .venv/bin/activate

# 3. pip install
pip install -r requirements.txt
```

---

## 6. テスト計画

### 6.1 テスト方針

| レベル | 対象 | ツール | カバレッジ目標 |
|--------|------|--------|---------------|
| ユニット | 各モジュールの関数単位 | pytest + pytest-cov | 80%以上 |
| 統合 | パイプライン全体フロー | pytest | 主要パス網羅 |
| E2E | Streamlit UI操作 | 手動（家老担当） | クリティカルフロー |

### 6.2 各モジュールのテスト方針

#### pdf_merger.py

- 正常系: 2-3ファイルの結合、ブックマーク確認
- 異常系: 破損PDF、0ページPDF、暗号化PDF
- 境界値: 空フォルダ、1ファイルのみ

#### ocr_engine.py

- 正常系: 日本語テキストPDFのOCR精度検証
- 異常系: 画像のみPDF、白紙ページ
- 性能: 処理時間の計測（100ページ以内で1分以内が目標）
- モック: PaddleOCR をモック化してロジックテスト

#### duplicate_detector.py

- 正常系: 意図的に重複させたPDFで検出確認
- Stage 1: dHash の閾値テスト
- Stage 2: コサイン類似度の閾値テスト
- 偽陽性テスト: 類似だが異なるページが誤検出されないこと
- 偽陰性テスト: 明らかな重複が検出されること

#### pipeline.py

- 統合テスト: 結合→OCR→検知の一連のフロー
- 部分実行: 各機能の単独実行（チェックボックスOFF時）
- エラー伝播: 途中工程のエラーが適切に報告されること

### 6.3 テストデータ

- テスト用の小規模PDF（3-5ページ）を `tests/fixtures/` に配置
- 重複ページを含むPDF、ページ飛びPDF、白紙ページPDFを用意
- 実際の学術書スキャンPDFでの検証は手動テスト

### 6.4 カバレッジ80%達成の方針

- 各モジュールのパブリック関数を100%テスト
- 外部ライブラリ（PaddleOCR等）はモックで代替
- Streamlit UI部分はカバレッジ対象外（手動E2Eで補完）
- `pytest --cov=. --cov-report=term-missing` でカバレッジ計測

---

## 7. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| PaddleOCR のWSL2互換性問題 | OCR機能が使えない | EasyOCR にフォールバック |
| GPU未搭載環境での処理速度低下 | 100ページ超のPDFで遅延 | CPU版で十分な速度（バッチ処理最適化） |
| 学術書の多様なフォーマット | ページ番号検出漏れ | 既存 page_detector.py のパターン拡張 |
| 大量PDF（100+ファイル）の結合 | メモリ不足 | ストリーム処理、バッチ結合 |

---

## 8. 今後の拡張可能性

- **レポート出力**: Excel/CSV形式での検査結果エクスポート
- **バッチモード**: CLI実行（Streamlit不要の自動処理）
- **差分比較**: 2つのPDFの差分ページ表示
- **クラウドOCR連携**: Google Cloud Vision / Azure AI Vision との連携オプション
