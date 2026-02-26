# cmd_192: Gmail WF v5.0 Phase 3 — Google Drive文書内容をGeminiに注入

## 概要

Gmail WFにおいて、案件に紐づくGoogle Driveフォルダ内の文書内容をGeminiに読ませ、
案件の文脈を踏まえた高品質な返信案を生成する。

Phase 2（cmd_191）ではDriveフォルダのURLを文字列として渡すだけだったが、
Phase 3ではフォルダ内の文書を実際に読み取り、内容をGeminiのプロンプトに注入する。

## 採用方式: 案B — 原本+AI用テキスト併存

原本ファイルを変更せず、`_ai_text/` サブフォルダにMarkdown変換テキストを自動生成する。
Gmail WFは `_ai_text/` のmdを優先読み込みし、なければPDF直送でフォールバックする。

### フォルダ構成

```
案件フォルダ/
  ├── 契約書.pdf              ← 原本（変更しない）
  ├── 準備書面(1).docx        ← 原本（変更しない）
  ├── 相手方回答書.pdf        ← 原本（変更しない）
  ├── 見積書.xlsx             ← 原本（変更しない）
  └── _ai_text/               ← 自動生成サブフォルダ
       ├── 契約書.md           ← PDF → テキスト抽出
       ├── 準備書面(1).md      ← Word → テキストエクスポート
       ├── 相手方回答書.md     ← PDF → テキスト抽出
       └── _manifest.json      ← ファイル一覧・変換日時・ハッシュ
```

### 方式選定理由

| 評価軸 | 案A(直送) | 案B(テキスト併存) ★採用 | 案C(統合要約) |
|--------|----------|----------------------|-------------|
| 初期コスト | なし | WF構築 | WF構築 |
| 運用コスト | 中（毎回フル課金） | 低（キャッシュ活用） | 最低 |
| 精度 | 高(96%) | 最高(100%) | 中（要約依存） |
| 再利用性 | 低 | 高（md再利用可能） | 中 |
| 法的原本性 | 保持 | 保持（原本不変） | 保持 |
| 同一案件反復 | 毎回PDF送信 | md読取のみ(90%オフ) | 要約1回のみ |

---

## システム全体構成

2つのWFが連携する:

```
【WF-1: テキスト自動変換WF（新規構築）】
  Google Drive Trigger(案件フォルダ監視)
    → ファイル種別判定
      → Word: Google Docs APIでtext/plainエクスポート → _ai_text/{name}.md 保存
      → PDF: Gemini 2.5 Flashでテキスト抽出 → _ai_text/{name}.md 保存
      → その他: スキップ
    → _manifest.json 更新

【WF-2: Gmail自動化WF（既存を拡張 = Phase 3本体）】
  Gmail Trigger → メール解析 → 人物DB検索 → 案件取得(ドライブリンク)
    → Drive API: _ai_text/ フォルダ内のmd一覧取得
      → md読み込み（最新3件まで）
        → Gemini判断(文書内容注入) → 返信案生成(文書内容注入)
    → フォールバック: _ai_text/ なければ原本PDF直送
```

---

## ファイル形式別APIコスト考察

### Gemini 2.5 Flash 料金体系

| 項目 | 単価 |
|------|------|
| 入力トークン | $0.30 / 100万トークン |
| 出力トークン | $2.50 / 100万トークン |
| キャッシュ読取 | 入力の10%（$0.03 / 100万トークン） |

### PDF直送 vs テキスト変換（案B）のコスト比較

| 方式 | 10ページ契約書 | 同案件2通目以降 | 特徴 |
|------|--------------|---------------|------|
| **PDF直接送信** | 2,580トークン($0.0008) | 2,580トークン(同額) | 毎回フル課金 |
| **案B: md事前変換** | 変換時: ~15,000トークン($0.005) | md読取: ~15,000トークン($0.005) | テキスト量に比例 |
| **案B + キャッシュ** | 変換時: ~15,000トークン($0.005) | キャッシュ: ~15,000トークン($0.0005) | **2通目以降90%オフ** |

**損益分岐点**: 同一案件で3通以上のメールを処理する場合、案B+キャッシュがPDF直送より安くなる。
法律案件では同一顧客から複数回メールが届くのが通常であり、案Bが有利。

### ファイル形式別の変換方法

| 元ファイル形式 | 殿の文書での発生頻度 | 変換方法 | API呼出 |
|--------------|-------------------|---------|---------|
| **Word (.docx)** | 高（当方提出書面） | Google Docs APIに一時アップロード → text/plain エクスポート | Drive API 2回 |
| **PDF（テキスト埋込）** | 高（相手方書面・当方書面） | Gemini 2.5 Flashでテキスト抽出 | Gemini API 1回 |
| **PDF（スキャン画像）** | 中（古い書面・FAX受信） | Gemini 2.5 Flashでテキスト抽出（OCR込み） | Gemini API 1回 |
| **Excel (.xlsx)** | 低（見積書等） | Google Sheets APIでCSVエクスポート | Drive API 2回 |
| **画像（JPG/PNG）** | 低 | Gemini 2.5 Flashで内容記述 | Gemini API 1回 |
| **Google Docs** | 低（社内文書） | text/plain エクスポート（最も簡単） | Drive API 1回 |

### 変換コスト試算（1ファイルあたり）

| ファイル種別 | 変換コスト | 備考 |
|------------|-----------|------|
| Word → md | ~$0.0001 | Drive API呼出のみ（Gemini不要） |
| PDF 5ページ → md | ~$0.004 | Gemini抽出（258×5=1,290入力+出力） |
| PDF 20ページ → md | ~$0.015 | Gemini抽出（258×20=5,160入力+出力） |
| Excel → md | ~$0.0001 | Drive API呼出のみ |

---

## 実装計画

### WF-1: テキスト自動変換WF（新規構築）

#### WF-1a: トリガーとファイル種別判定

**目的**: 案件フォルダへの新規ファイル追加を検知し、変換対象を判定する

1. Google Drive Trigger ノード
   - イベント: ファイル作成/更新
   - 監視対象: 案件フォルダ群（Notion案件DBの「ドライブリンク」に登録されたフォルダ）
   - ポーリング間隔: 5分（リアルタイム性は不要）
2. フィルタ: `_ai_text/` フォルダ内のファイルは除外（無限ループ防止）
3. ファイル種別判定 (Switch node)
   - `application/vnd.openxmlformats-officedocument.wordprocessingml.document` → Word変換
   - `application/pdf` → PDF変換
   - `application/vnd.google-apps.document` → Google Docsエクスポート
   - `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` → Excel変換
   - その他 → スキップ

**API呼出**: Google Drive API 1回（トリガー）

#### WF-1b: Word (.docx) 変換

**目的**: Word文書をMarkdownテキストに変換する

1. Word → Google Docsにインポート（一時ファイル）
   - Drive API `files.copy` with `mimeType: application/vnd.google-apps.document`
2. Google Docs → text/plain エクスポート
   - Drive API `files.export` with `mimeType: text/plain`
3. テキストをMarkdown形式に整形（Code node）
   - ファイル名、変換日時をヘッダに付加
   - 文字数が50,000文字を超える場合は切り詰め
4. `_ai_text/{元ファイル名}.md` として保存
   - Drive API `files.create`
5. 一時Google Docsファイルを削除
   - Drive API `files.delete`

**API呼出**: Google Drive API 4回

#### WF-1c: PDF 変換

**目的**: PDFからテキストを抽出してMarkdownに変換する

1. PDFをダウンロード
   - Drive API `files.get` with `alt=media`
   - ファイルサイズ制限: 10MB以下のみ処理
2. Gemini 2.5 Flashにテキスト抽出を依頼
   - プロンプト:
     ```
     以下のPDF文書のテキスト内容を忠実に抽出してください。
     - 見出し構造があればMarkdownの##で表現
     - 表があればMarkdownテーブルで表現
     - 図やイメージの説明は[図: 説明]で記述
     - 原文のテキストを変更・要約しないでください
     ```
   - PDFをinline dataとして送信
3. 抽出テキストを `_ai_text/{元ファイル名}.md` として保存
4. `_manifest.json` を更新

**API呼出**: Drive API 2回 + Gemini API 1回

#### WF-1d: マニフェスト管理

**目的**: 変換済みファイルの管理と重複変換の防止

`_ai_text/_manifest.json` の構造:
```json
{
  "last_updated": "2026-02-19T20:00:00+09:00",
  "files": [
    {
      "original_id": "abc123",
      "original_name": "契約書.pdf",
      "converted_name": "契約書.md",
      "converted_id": "def456",
      "original_modified": "2026-02-15T10:00:00Z",
      "converted_at": "2026-02-15T10:05:00Z",
      "original_size": 245000,
      "converted_size": 12000,
      "method": "gemini_extract"
    }
  ]
}
```

- ファイル追加/更新時: original_modifiedが変わっていれば再変換
- 不要になったmd（原本が削除された場合）の自動クリーンアップ

---

### WF-2: Gmail WF Phase 3 拡張（既存WF改修）

#### Phase 3-A: _ai_text/ フォルダ検出とmd一覧取得

**目的**: 案件Driveフォルダ内の `_ai_text/` サブフォルダからmd一覧を取得する

1. 「ドライブリンク」URLからフォルダIDを抽出（Code node）
   - URL形式: `https://drive.google.com/drive/folders/{folderId}`
2. Drive API `files.list` で `_ai_text/` サブフォルダを検索
   - query: `'{folderId}' in parents and name = '_ai_text' and mimeType = 'application/vnd.google-apps.folder'`
3. `_ai_text/` が存在する場合: フォルダ内のmd一覧を取得
   - query: `'{ai_text_folderId}' in parents and mimeType = 'text/markdown'`
   - orderBy: `modifiedTime desc`（最新順）
4. `_ai_text/` が存在しない場合: フォールバック（Phase 3-A-fallback）

**フォールバック**: 原本フォルダのファイル一覧を取得し、PDF直送モードに切替

**API呼出**: Drive API 2回

#### Phase 3-B: mdファイル読み込み

**目的**: 上位N件のmdファイルの内容を読み込む

1. 読み込み対象の選定（Code node）
   - 最大3件（コスト制御）
   - 最新更新日順
   - _manifest.json は除外
2. 各mdファイルの内容を取得
   - Drive API `files.get` with `alt=media`
3. テキスト長制限
   - 1ファイルあたり最大12,000文字（約3,000トークン）
   - 全ファイル合計最大30,000文字（約8,000トークン）
   - 切り詰め時は「（以下省略 — 全文は案件フォルダ参照）」を付加

**フォールバック（mdなし時）**:
- 原本PDF/Wordを直接取得（最大2件、合計10ページまで）
- PDFは258トークン/ページでGeminiに直送

**API呼出**: Drive API 1〜3回

#### Phase 3-C: Geminiプロンプトへの文書内容注入

**目的**: 読み込んだ文書テキストをGemini判断・返信案に注入する

1. 案件情報整形ノードを拡張
   ```javascript
   // driveDocumentsフィールドを追加
   {
     driveDocuments: [
       { fileName: "契約書.md", content: "...", truncated: false },
       { fileName: "準備書面(1).md", content: "...", truncated: true }
     ],
     driveDocumentCount: 2,
     driveSource: "ai_text"  // or "direct" (fallback)
   }
   ```

2. Gemini判断プロンプトに文書セクション追加
   ```
   ## 案件関連ドキュメント（{driveDocumentCount}件）
   以下は案件フォルダ内の主要文書です。メールへの対応判断に活用してください。

   ### 📄 {fileName1}
   {content1}

   ### 📄 {fileName2}
   {content2}
   ```

3. 返信案生成プロンプトにも同セクションを注入

4. 文書なしの場合: 「案件ドキュメント: フォルダ内に文書なし」

#### Phase 3-D: コスト制御

**目的**: APIコストの予算内管理

1. Gmail WF側のコスト制御
   | パラメータ | 値 | 理由 |
   |-----------|-----|------|
   | md読み込み上限 | 3件 | Drive API呼出抑制 |
   | テキスト上限/ファイル | 12,000文字 | トークン制限 |
   | テキスト上限/合計 | 30,000文字 | Geminiプロンプト制限 |
   | PDF直送上限 | 10ページ | フォールバック時 |

2. 変換WF側のコスト制御
   | パラメータ | 値 | 理由 |
   |-----------|-----|------|
   | PDF変換上限 | 30ページ | Gemini抽出コスト制限 |
   | ファイルサイズ上限 | 10MB | 巨大ファイル除外 |
   | 同時変換数 | 1件ずつ | レート制限回避 |
   | 変換間隔 | 2秒 | Drive APIレート制限 |

---

## コスト試算

### 1メール処理あたり（Gmail WF Phase 3）

| 項目 | Phase 2(現行) | Phase 3(md読取) | Phase 3(PDF直送fallback) |
|------|-------------|----------------|------------------------|
| Notion API | 2-3回 | 2-3回 | 2-3回 |
| Drive API | 0回 | 3-5回 | 3-5回 |
| Gemini入力 | ~2,000トークン | ~10,000トークン | ~4,500トークン |
| Gemini出力 | ~1,000トークン | ~1,500トークン | ~1,500トークン |
| **コスト/メール** | **~$0.001** | **~$0.006** | **~$0.003** |

### 変換WF（1ファイル変換あたり）

| ファイル種別 | 変換コスト | Drive API | Gemini API |
|------------|-----------|-----------|------------|
| Word → md | ~$0.0001 | 4回 | 0回 |
| PDF 5p → md | ~$0.004 | 2回 | 1回 |
| PDF 20p → md | ~$0.015 | 2回 | 1回 |
| Google Docs → md | ~$0.0001 | 1回 | 0回 |

### 月間コスト概算（仮定: 月100通メール、案件平均5ファイル）

| 項目 | 月額 |
|------|------|
| Gmail WF Phase 3 処理 | ~$0.60 |
| 変換WF（初回50案件×5ファイル） | ~$1.00 |
| 変換WF（月次新規30ファイル） | ~$0.12 |
| **合計** | **~$1.72/月** |

---

## 段階的リリース計画

| ステップ | 内容 | 前提条件 | 成果物 |
|---------|------|---------|--------|
| **Step 0** | 前提確認 | — | Drive API認証、テストフォルダ |
| **Step 1** | WF-1 テキスト変換WF構築 | Step 0 | 新規WF稼働、_ai_text/自動生成 |
| **Step 2** | WF-2 Phase 3-A md一覧取得 | Step 1 | Gmail WFがmd検出可能に |
| **Step 3** | WF-2 Phase 3-B md読み込み | Step 2 | 文書テキスト取得完了 |
| **Step 4** | WF-2 Phase 3-C プロンプト注入 | Step 3 | Geminiに文書内容注入 |
| **Step 5** | WF-2 Phase 3-D コスト制御 | Step 4 | ハードリミット設定 |
| **Step 6** | 統合テスト+軍師QC | Step 5 | 全体動作確認 |

各ステップ完了後にテストメール送信 → exec確認 → 軍師QCを実施。

## 前提条件・事前確認

- [ ] n8nにGoogle Drive APIのOAuth2認証が設定済みか確認
- [ ] テスト用案件のNotion「ドライブリンク」にフォルダURLが設定済みか確認
- [ ] テスト用フォルダにサンプル文書を配置（Word 1件、PDF 2件）
- [ ] `_ai_text/` サブフォルダの手動作成テスト（Drive APIで作成可能か確認）

## リスク・注意事項

1. **変換品質**: PDF→テキスト抽出はGemini依存。複雑なレイアウトの法律文書で品質確認が必要
2. **トークンコスト**: Phase 2比で約6倍だが月額$2以下。同一案件反復でキャッシュ効果あり
3. **レスポンス遅延**: md読み込み分の処理時間追加（推定+3〜5秒、PDF直送時+5〜10秒）
4. **Drive API権限**: Service AccountまたはOAuth2がフォルダにアクセスできること
5. **無限ループ防止**: 変換WFが `_ai_text/` 内のファイル変更でトリガーされないこと
6. **PDF OCR限界**: Google Drive OCRはPDF 2MB/10ページ制限。Gemini抽出はこの制限なし
7. **スキャンPDF品質**: FAX受信等の低品質スキャンPDFはテキスト抽出精度が低下する可能性

## 参考情報

- Gemini API トークン: https://ai.google.dev/gemini-api/docs/tokens
- Gemini API 料金: https://ai.google.dev/gemini-api/docs/pricing
- Gemini 文書処理: https://ai.google.dev/gemini-api/docs/document-processing
- Google Drive API 制限: https://developers.google.com/workspace/drive/api/guides/limits
- Google Drive エクスポート形式: https://developers.google.com/workspace/drive/api/guides/ref-export-formats
- Google Drive OCR: https://support.google.com/drive/answer/176692
- n8n Google Drive PDF抽出テンプレート: https://n8n.io/workflows/9061-extract-and-clean-pdf-data-from-google-drive/
- Document AI vs Gemini比較: https://didikmulyadi.medium.com/data-extractions-cost-and-performance-comparison-between-google-document-ai-and-vertex-ai-studio-d161631a113e
