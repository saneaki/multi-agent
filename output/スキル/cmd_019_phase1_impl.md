# Gmail自動管理システム Phase 1 実装手順書

**cmd_019 | subtask_019a | 足軽5号**
**作成日: 2026-02-12**

> 本手順書は以下の資料に基づく:
>
> - `cmd_016_requirements.md` — 要件定義書（システム構成・OAuthスコープ・データフロー等）
> - `cmd_016_dev_tools.md` — 開発ツール調査レポート
> - `cmd_018_setup_guide.md` — 開発環境セットアップ手順書
>
> **対象読者**: 殿（開発者）。本手順書のコードをコピペすれば Phase 1 が動作する。

---

## 目次

1. [Phase 1 概要](#第1章-phase-1-概要)
2. [Google Workspace 準備](#第2章-google-workspace-準備)
3. [モジュール設計](#第3章-モジュール設計)
4. [TypeScript コード全文](#第4章-typescript-コード全文)
5. [テストコード全文](#第5章-テストコード全文)
6. [デプロイと動作確認](#第6章-デプロイと動作確認)
7. [運用設定](#第7章-運用設定)
8. [Phase 2への準備](#第8章-phase-2への準備)

---

## 第1章: Phase 1 概要

### 1.1 実装する機能の全体像

Phase 1 は Gmail 自動管理システムの基盤を構築する。以下の3つの機能を実装する:

1. **メール取得**: 未処理の Gmail メールを検索・取得する
2. **クライアント判定**: 送信者アドレスからクライアントを特定する
3. **スプレッドシート記録**: クライアント別スプレッドシートにメール情報を記録する

**Phase 1 で実装しないもの**:

- PDF 変換・Drive 保存（Phase 2）
- Gemini API による要約生成（Phase 3）
- 管理 UI・ダッシュボード（Phase 4）

### 1.2 モジュール構成図

```
src/
├── types.ts              ← 型定義（全モジュール共通）
├── config.ts             ← マスタースプレッドシートからの設定読み込み
├── gmail-fetcher.ts      ← Gmail メール取得・検索
├── client-matcher.ts     ← 送信者→クライアント判定
├── sheet-writer.ts       ← スプレッドシートへの書き込み
├── dedup.ts              ← 重複処理防止
├── batch-processor.ts    ← バッチ処理制御（タイムアウト監視含む）
├── logger.ts             ← 実行ログ記録（マスターシートの execution_log）
└── index.ts              ← エントリーポイント（GAS 公開関数）
```

**依存関係**:

```
index.ts
  ├── batch-processor.ts
  │     ├── gmail-fetcher.ts
  │     │     └── dedup.ts
  │     ├── client-matcher.ts
  │     │     └── config.ts
  │     ├── sheet-writer.ts
  │     └── logger.ts
  └── config.ts
        └── types.ts（全モジュールが参照）
```

### 1.3 データフロー図

```
[Gmail 受信メール]
       │
       ▼
(1) gmail-fetcher.ts — GmailApp.search() で未処理メール取得
       │                 検索クエリ: -label:_auto/processed
       │                 dedup.ts で PropertiesService 重複チェック
       │
       ▼
(2) client-matcher.ts — 送信者アドレスとマスター設定を照合
       │                  config.ts がマスタースプレッドシートから設定読込
       │                  マッチなし → 「未分類」として処理
       │
       ▼
(3) sheet-writer.ts — クライアント別スプレッドシートに行追加
       │               No., 受信日時, 送信者, 件名, PDFリンク(空欄),
       │               概要(空欄), 添付ファイル, 処理日時
       │
       ▼
(4) dedup.ts — 処理済みメール ID を PropertiesService に保存
       │         Gmail ラベル `_auto/processed` を付与
       │
       ▼
(5) logger.ts — 実行ログをマスタースプレッドシートの execution_log に記録
```

### 1.4 要件定義書（cmd_016）との対応表

| 要件定義書セクション | Phase 1 での対応 | 実装モジュール |
|-------------------|----------------|-------------|
| §1 システム構成 | メール取得 + Sheets記録のみ | gmail-fetcher, sheet-writer |
| §2 データフロー (1)(2)(6)(7) | 取得→判定→記録→マーク | 全モジュール |
| §3 マスタースプレッドシート設計 | clients + execution_log | config, logger |
| §4 クライアント別シート設計 | メール一覧シート（PDF・概要は空欄） | sheet-writer |
| §8 トリガー方式 | 5分間隔の時間駆動トリガー | index.ts (setup) |
| §9 エラーハンドリング | バッチ処理 + リトライ + ログ | batch-processor, logger |
| §9.3 重複処理防止 | PropertiesService + Gmail ラベル | dedup |
| §10 セキュリティ | OAuth スコープ最小権限 | appsscript.json |
| §11 GAS技術的制約 | 6分制限対応バッチ処理 | batch-processor |

---

## 第2章: Google Workspace 準備

### 2.1 マスタースプレッドシートの作成

#### Step 1: スプレッドシートを新規作成

```
1. Google Sheets（https://sheets.google.com/）を開く
2. 「空白のスプレッドシート」をクリック
3. タイトルを「Gmail自動管理_マスター」に変更
4. URL からスプレッドシート ID を控える
   例: https://docs.google.com/spreadsheets/d/【ここがID】/edit
```

#### Step 2: `clients` シートの作成

```
1. 既存の「シート1」タブ名を「clients」に変更
   （タブ名をダブルクリック → 「clients」と入力 → Enter）

2. A1〜I1 に以下のヘッダーを入力:
```

| セル | 値 |
|------|-----|
| A1 | client_id |
| B1 | client_name |
| C1 | email_pattern |
| D1 | spreadsheet_id |
| E1 | sheet_name |
| F1 | drive_folder_id |
| G1 | is_active |
| H1 | created_at |
| I1 | notes |

```
3. ヘッダー行を太字にする
   A1:I1 を選択 → Ctrl+B

4. ヘッダー行を固定する
   メニュー → 表示 → 固定 → 1行
```

#### Step 3: `execution_log` シートの作成

```
1. 下部の「+」ボタンでシートを追加
2. タブ名を「execution_log」に変更

3. A1〜G1 に以下のヘッダーを入力:
```

| セル | 値 |
|------|-----|
| A1 | execution_id |
| B1 | started_at |
| C1 | finished_at |
| D1 | emails_processed |
| E1 | emails_failed |
| F1 | status |
| G1 | error_details |

```
4. ヘッダー行を太字にする + 固定する（同上）
```

#### Step 4: テスト用クライアントデータの投入

`clients` シートに以下のテストデータを入力する:

| client_id | client_name | email_pattern | spreadsheet_id | sheet_name | drive_folder_id | is_active | created_at | notes |
|-----------|-------------|---------------|----------------|------------|-----------------|-----------|------------|-------|
| CL001 | テスト株式会社 | *@test-corp.co.jp | （後で設定） | メール一覧 | （後で設定） | TRUE | 2026/02/12 | テスト用 |
| CL002 | 山田太郎 | yamada@example.com | （後で設定） | メール一覧 | （後で設定） | TRUE | 2026/02/12 | 個人テスト |

> **注意**: `spreadsheet_id` と `drive_folder_id` は、Step 5 でクライアント別スプレッドシートとフォルダを作成した後に記入する。

### 2.2 クライアント別スプレッドシートのテンプレート作成

#### Step 5: クライアント別スプレッドシートの作成

テスト用に1つ作成する。本番では各クライアントごとに作成する。

```
1. 新規スプレッドシートを作成
   タイトル: 「テスト株式会社_メール管理」

2. 既存の「シート1」タブ名を「メール一覧」に変更

3. A1〜H1 に以下のヘッダーを入力:
```

| セル | 値 |
|------|-----|
| A1 | No. |
| B1 | 受信日時 |
| C1 | 送信者 |
| D1 | 件名 |
| E1 | PDFリンク |
| F1 | 概要 |
| G1 | 添付ファイル |
| H1 | 処理日時 |

```
4. ヘッダー行を太字にする + 固定する

5. 条件付き書式の設定:
   F 列を選択 → メニュー → 表示形式 → 条件付き書式
   - 「セルの書式設定の条件」→「テキストが次を含む」→「要約生成失敗」
   - 書式: 背景色を黄色に設定
   → 「完了」をクリック

6. ヘッダー固定:
   メニュー → 表示 → 固定 → 1行

7. URL からスプレッドシート ID を控え、マスターの clients シートの
   spreadsheet_id カラムに記入する
```

### 2.3 Gmail ラベルの作成

```
1. Gmail（https://mail.google.com/）を開く
2. 左メニューの「もっと見る」をクリック
3. 「新しいラベルを作成」をクリック
4. ラベル名: 「_auto」を入力 → 「作成」
5. 再度「新しいラベルを作成」をクリック
6. ラベル名: 「processed」を入力
   「次のラベルの下位にネスト」にチェック → 「_auto」を選択 → 「作成」

結果: 「_auto/processed」ラベルが作成される
```

### 2.4 各リソースの ID 取得方法

| リソース | ID の取得方法 |
|----------|-------------|
| スプレッドシート ID | URL の `/d/` と `/edit` の間の文字列。例: `https://docs.google.com/spreadsheets/d/`**`1AbCdEfGhIjKlMnOpQrStUvWxYz`**`/edit` |
| Google Drive フォルダ ID | フォルダを開いた状態の URL の末尾。例: `https://drive.google.com/drive/folders/`**`1AbCdEfGhIjKlMnOpQrStUvWxYz`** |

> **Phase 1 では Drive フォルダは使用しない**が、マスターの `drive_folder_id` は Phase 2 に備えて設定しておくことを推奨する。設定しない場合は空欄でよい。

---

## 第3章: モジュール設計

### 3.1 src/ ディレクトリ構造

```
src/
├── types.ts              # 共通型定義
├── config.ts             # マスタースプレッドシートからの設定読み込み
├── gmail-fetcher.ts      # メール取得・検索
├── client-matcher.ts     # 送信者→クライアント判定
├── sheet-writer.ts       # スプレッドシートへの書き込み
├── dedup.ts              # 重複処理防止（PropertiesService + ラベル）
├── batch-processor.ts    # バッチ処理制御（タイムアウト監視含む）
├── logger.ts             # 実行ログ記録
└── index.ts              # エントリーポイント（GAS公開関数）
```

### 3.2 各モジュールのインターフェース定義

#### types.ts

```typescript
/** マスタースプレッドシートの clients シートの1行 */
export interface ClientConfig {
  clientId: string;
  clientName: string;
  emailPattern: string;
  spreadsheetId: string;
  sheetName: string;
  driveFolderId: string;
  isActive: boolean;
  createdAt: string;
  notes: string;
}

/** メール1通分の記録データ */
export interface EmailRecord {
  no: number;
  receivedAt: Date;
  sender: string;
  subject: string;
  pdfLink: string;       // Phase 1 では空文字
  summary: string;        // Phase 1 では空文字
  attachments: string;
  processedAt: Date;
}

/** 実行ログ（execution_log シートの1行） */
export interface ExecutionLog {
  executionId: string;
  startedAt: Date;
  finishedAt: Date;
  emailsProcessed: number;
  emailsFailed: number;
  status: 'success' | 'partial' | 'error';
  errorDetails: string;
}

/** バッチ処理の結果 */
export interface ProcessResult {
  processed: number;
  failed: number;
  errors: string[];
  timedOut: boolean;
}
```

#### config.ts

```typescript
/**
 * マスタースプレッドシートから有効なクライアント設定一覧を読み込む。
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @returns 有効な ClientConfig の配列
 */
export function loadClientConfigs(masterSpreadsheetId: string): ClientConfig[];
```

#### gmail-fetcher.ts

```typescript
/**
 * 未処理の Gmail メッセージを取得する。
 * 検索クエリ: -label:_auto/processed
 * @param maxResults - 最大取得件数（デフォルト 20）
 * @returns GmailMessage の配列
 */
export function fetchUnprocessedEmails(maxResults?: number): GoogleAppsScript.Gmail.GmailMessage[];
```

#### client-matcher.ts

```typescript
/**
 * 送信者のメールアドレスからクライアントを特定する。
 * @param senderEmail - 送信者メールアドレス
 * @param configs - クライアント設定一覧
 * @returns マッチした ClientConfig。マッチなしの場合 null
 */
export function matchClient(
  senderEmail: string,
  configs: ClientConfig[]
): ClientConfig | null;

/**
 * メールの From ヘッダーからメールアドレスを抽出する。
 * 例: "田中太郎 <tanaka@example.com>" → "tanaka@example.com"
 * @param fromHeader - From ヘッダーの文字列
 * @returns メールアドレス
 */
export function extractEmailAddress(fromHeader: string): string;
```

#### sheet-writer.ts

```typescript
/**
 * クライアント別スプレッドシートにメール情報を追加する。
 * @param spreadsheetId - クライアント別スプレッドシートの ID
 * @param sheetName - シート名（デフォルト: メール一覧）
 * @param record - メール記録データ
 */
export function writeEmailRecord(
  spreadsheetId: string,
  sheetName: string,
  record: EmailRecord
): void;
```

#### dedup.ts

```typescript
/**
 * メッセージが処理済みかどうかを判定する。
 * PropertiesService のキーをチェック。
 * @param messageId - Gmail メッセージ ID
 * @returns true = 処理済み
 */
export function isProcessed(messageId: string): boolean;

/**
 * メッセージを処理済みとしてマークする。
 * PropertiesService にキーを保存し、Gmail ラベルを付与する。
 * @param message - Gmail メッセージオブジェクト
 */
export function markAsProcessed(message: GoogleAppsScript.Gmail.GmailMessage): void;

/**
 * 日次メンテナンス: 90日以上経過した処理済み ID を削除する。
 * PropertiesService の容量対策。
 * @returns 削除した件数
 */
export function cleanupOldEntries(): number;
```

#### batch-processor.ts

```typescript
/**
 * メール処理のバッチ実行。
 * 5分のタイムアウト監視付き。1回あたり最大20通を処理。
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @returns バッチ処理の結果
 */
export function processBatch(masterSpreadsheetId: string): ProcessResult;
```

#### logger.ts

```typescript
/**
 * 実行ログをマスタースプレッドシートの execution_log シートに追記する。
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @param log - 実行ログデータ
 */
export function writeExecutionLog(
  masterSpreadsheetId: string,
  log: ExecutionLog
): void;
```

#### index.ts

```typescript
/**
 * メイン処理: トリガーから5分間隔で呼び出される。
 * 未処理メールを取得し、クライアント判定→スプレッドシート記録を行う。
 */
declare function processEmails(): void;

/**
 * 日次メンテナンス: 毎日午前2時に実行。
 * 古い処理済み ID の削除、ログ整理を行う。
 */
declare function dailyMaintenance(): void;

/**
 * 初期セットアップ: 手動で1回だけ実行。
 * トリガーの登録を行う。
 */
declare function setup(): void;
```

### 3.3 モジュール間の依存関係図

```
                    ┌──────────┐
                    │ index.ts │  GAS 公開関数（processEmails, setup, dailyMaintenance）
                    └────┬─────┘
                         │
              ┌──────────▼──────────┐
              │ batch-processor.ts  │  バッチ処理制御（タイムアウト監視）
              └──┬───┬───┬───┬─────┘
                 │   │   │   │
    ┌────────────▼┐  │   │  ┌▼──────────┐
    │gmail-fetcher│  │   │  │ logger.ts  │  実行ログ記録
    │   .ts       │  │   │  └────────────┘
    └──────┬──────┘  │   │
           │         │   │
    ┌──────▼──────┐  │  ┌▼────────────┐
    │  dedup.ts   │  │  │sheet-writer  │  スプレッドシート書き込み
    │             │  │  │   .ts        │
    └─────────────┘  │  └─────────────┘
                     │
           ┌─────────▼─────────┐
           │ client-matcher.ts │  クライアント判定
           └─────────┬─────────┘
                     │
              ┌──────▼──────┐
              │  config.ts  │  設定読み込み
              └──────┬──────┘
                     │
              ┌──────▼──────┐
              │  types.ts   │  型定義（全モジュールが import）
              └─────────────┘
```

---

## 第4章: TypeScript コード全文

> **重要**: 以下のコードは全て完全版。抜粋ではない。`src/` ディレクトリにそのままコピーすること。

### 4.1 src/types.ts

```typescript
// src/types.ts
// 全モジュール共通の型定義

/**
 * マスタースプレッドシートの clients シートの1行を表す。
 * §3.1 クライアント設定シートの設計に準拠。
 */
export interface ClientConfig {
  /** クライアント識別子（例: CL001） */
  clientId: string;
  /** クライアント名（日本語） */
  clientName: string;
  /** メールアドレスまたはドメインパターン（例: *@example.co.jp） */
  emailPattern: string;
  /** クライアント別スプレッドシートの ID */
  spreadsheetId: string;
  /** 対応シート名（デフォルト: メール一覧） */
  sheetName: string;
  /** PDF保存先 Google Drive フォルダ ID（Phase 2 で使用） */
  driveFolderId: string;
  /** 有効/無効フラグ */
  isActive: boolean;
  /** 登録日 */
  createdAt: string;
  /** 備考 */
  notes: string;
}

/**
 * メール1通分の記録データ。
 * §4 クライアント別スプレッドシートの設計に準拠。
 */
export interface EmailRecord {
  /** 行番号（連番） */
  no: number;
  /** メールの受信日時 */
  receivedAt: Date;
  /** 送信者名 + メールアドレス */
  sender: string;
  /** メールの件名 */
  subject: string;
  /** Google Drive 上の PDF ファイルへのリンク（Phase 1 では空文字） */
  pdfLink: string;
  /** Gemini API による要約（Phase 1 では空文字） */
  summary: string;
  /** 添付ファイル名（カンマ区切り） */
  attachments: string;
  /** システムが処理した日時 */
  processedAt: Date;
}

/**
 * 実行ログデータ。
 * §3.2 実行ログシートの設計に準拠。
 */
export interface ExecutionLog {
  /** 実行 ID（タイムスタンプベース） */
  executionId: string;
  /** 実行開始日時 */
  startedAt: Date;
  /** 実行終了日時 */
  finishedAt: Date;
  /** 処理したメール数 */
  emailsProcessed: number;
  /** 失敗したメール数 */
  emailsFailed: number;
  /** 実行ステータス */
  status: 'success' | 'partial' | 'error';
  /** エラー詳細（ある場合） */
  errorDetails: string;
}

/**
 * バッチ処理の結果を表す。
 */
export interface ProcessResult {
  /** 正常に処理したメール数 */
  processed: number;
  /** 処理に失敗したメール数 */
  failed: number;
  /** エラーメッセージの配列 */
  errors: string[];
  /** タイムアウトにより中断したかどうか */
  timedOut: boolean;
}
```

### 4.2 src/config.ts

```typescript
// src/config.ts
// マスタースプレッドシートからクライアント設定を読み込む

import { ClientConfig } from './types';

/**
 * マスタースプレッドシート ID を取得する。
 * Script Properties に MASTER_SPREADSHEET_ID として保存されている前提。
 *
 * なぜ Script Properties を使うのか:
 * - コードにハードコードしない（複数環境で使えるようにするため）
 * - appsscript.json にスコープを追加する必要がない（PropertiesService は標準）
 */
export function getMasterSpreadsheetId(): string {
  const props = PropertiesService.getScriptProperties();
  const id = props.getProperty('MASTER_SPREADSHEET_ID');
  if (!id) {
    throw new Error(
      'MASTER_SPREADSHEET_ID が Script Properties に設定されていません。' +
      'Apps Script エディタ → プロジェクトの設定 → スクリプト プロパティ で設定してください。'
    );
  }
  return id;
}

/**
 * マスタースプレッドシートの clients シートから有効なクライアント設定一覧を読み込む。
 *
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @returns 有効な（is_active = TRUE）ClientConfig の配列
 */
export function loadClientConfigs(masterSpreadsheetId: string): ClientConfig[] {
  const ss = SpreadsheetApp.openById(masterSpreadsheetId);
  const sheet = ss.getSheetByName('clients');
  if (!sheet) {
    throw new Error('マスタースプレッドシートに「clients」シートが見つかりません。');
  }

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) {
    // ヘッダー行のみ = クライアント未登録
    return [];
  }

  // A2:I{lastRow} を一括取得（ヘッダー行をスキップ）
  const data = sheet.getRange(2, 1, lastRow - 1, 9).getValues();

  const configs: ClientConfig[] = [];
  for (const row of data) {
    const clientId = String(row[0]).trim();
    if (!clientId) {
      // 空行はスキップ
      continue;
    }

    const config: ClientConfig = {
      clientId,
      clientName: String(row[1]).trim(),
      emailPattern: String(row[2]).trim(),
      spreadsheetId: String(row[3]).trim(),
      sheetName: String(row[4]).trim() || 'メール一覧',
      driveFolderId: String(row[5]).trim(),
      isActive: row[6] === true || String(row[6]).toUpperCase() === 'TRUE',
      createdAt: String(row[7]),
      notes: String(row[8]),
    };

    // 有効なクライアントのみ返す
    if (config.isActive && config.spreadsheetId) {
      configs.push(config);
    }
  }

  return configs;
}
```

### 4.3 src/gmail-fetcher.ts

```typescript
// src/gmail-fetcher.ts
// 未処理の Gmail メールを取得する

import { isProcessed } from './dedup';

/** Phase 1 のデフォルトバッチサイズ（§11: 1回あたり上限20通） */
const DEFAULT_MAX_RESULTS = 20;

/**
 * 未処理の Gmail メッセージを取得する。
 *
 * 検索クエリ:
 * - `-label:_auto/processed`: 処理済みラベルが付いていないメール
 * - `in:inbox`: 受信トレイのメールのみ
 *
 * さらに PropertiesService で二重チェックする（ラベル付与失敗時のフォールバック）。
 *
 * なぜ Gmail 検索とPropertiesService の両方でチェックするのか:
 * - Gmail ラベル: 検索クエリで効率的にフィルタ（大量メールでも高速）
 * - PropertiesService: ラベル付与が失敗した場合のセーフティネット
 *
 * @param maxResults - 最大取得件数（デフォルト 20）
 * @returns GmailMessage の配列（未処理のもののみ）
 */
export function fetchUnprocessedEmails(
  maxResults: number = DEFAULT_MAX_RESULTS
): GoogleAppsScript.Gmail.GmailMessage[] {
  const query = 'in:inbox -label:_auto/processed';
  const threads = GmailApp.search(query, 0, maxResults);

  const messages: GoogleAppsScript.Gmail.GmailMessage[] = [];
  for (const thread of threads) {
    const threadMessages = thread.getMessages();
    for (const message of threadMessages) {
      // PropertiesService での二重チェック
      if (!isProcessed(message.getId())) {
        messages.push(message);
      }
    }
    // バッチサイズ制限
    if (messages.length >= maxResults) {
      break;
    }
  }

  return messages.slice(0, maxResults);
}

/**
 * GmailMessage から添付ファイル名の一覧を取得する。
 *
 * @param message - Gmail メッセージオブジェクト
 * @returns 添付ファイル名のカンマ区切り文字列。添付なしの場合は空文字
 */
export function getAttachmentNames(
  message: GoogleAppsScript.Gmail.GmailMessage
): string {
  const attachments = message.getAttachments();
  if (attachments.length === 0) {
    return '';
  }
  return attachments.map((a) => a.getName()).join(', ');
}
```

### 4.4 src/client-matcher.ts

```typescript
// src/client-matcher.ts
// 送信者メールアドレスからクライアントを特定する

import { ClientConfig } from './types';

/**
 * メールの From ヘッダーからメールアドレス部分を抽出する。
 *
 * GmailMessage.getFrom() は以下の形式を返す:
 * - "田中太郎 <tanaka@example.com>"
 * - "tanaka@example.com"
 * - "<tanaka@example.com>"
 *
 * @param fromHeader - From ヘッダーの文字列
 * @returns メールアドレス（小文字に正規化）
 */
export function extractEmailAddress(fromHeader: string): string {
  // <...> で囲まれたアドレスを抽出
  const match = fromHeader.match(/<([^>]+)>/);
  if (match) {
    return match[1].toLowerCase().trim();
  }
  // 囲まれていない場合はそのまま返す
  return fromHeader.toLowerCase().trim();
}

/**
 * メールパターンと送信者アドレスの照合を行う。
 *
 * パターン形式:
 * - "*@example.co.jp" — ドメイン全体にマッチ
 * - "tanaka@example.com" — 完全一致
 *
 * @param senderEmail - 送信者メールアドレス（小文字）
 * @param pattern - マスタースプレッドシートの email_pattern
 * @returns マッチした場合 true
 */
export function matchesPattern(senderEmail: string, pattern: string): boolean {
  const normalizedPattern = pattern.toLowerCase().trim();

  if (normalizedPattern.startsWith('*@')) {
    // ドメインパターン: *@example.co.jp
    const domain = normalizedPattern.substring(2); // "@" 以降
    return senderEmail.endsWith('@' + domain);
  }

  // 完全一致
  return senderEmail === normalizedPattern;
}

/**
 * 送信者のメールアドレスからクライアントを特定する。
 *
 * マスタースプレッドシートの email_pattern と照合し、最初にマッチしたクライアントを返す。
 * マッチしない場合は null を返す（呼び出し元で「未分類」として処理する）。
 *
 * @param senderEmail - 送信者メールアドレス（extractEmailAddress 済みの値）
 * @param configs - クライアント設定一覧
 * @returns マッチした ClientConfig。マッチなしの場合 null
 */
export function matchClient(
  senderEmail: string,
  configs: ClientConfig[]
): ClientConfig | null {
  const normalized = senderEmail.toLowerCase().trim();

  for (const config of configs) {
    // email_pattern はカンマ区切りで複数パターンを設定可能
    const patterns = config.emailPattern.split(',');
    for (const pattern of patterns) {
      if (matchesPattern(normalized, pattern)) {
        return config;
      }
    }
  }

  return null;
}
```

### 4.5 src/sheet-writer.ts

```typescript
// src/sheet-writer.ts
// クライアント別スプレッドシートにメール情報を書き込む

import { EmailRecord } from './types';

/**
 * 日時を "yyyy/MM/dd HH:mm" 形式の文字列にフォーマットする。
 * GAS の Utilities.formatDate を使用。
 *
 * @param date - フォーマット対象の Date
 * @returns フォーマットされた日時文字列
 */
export function formatDateTime(date: Date): string {
  return Utilities.formatDate(date, 'Asia/Tokyo', 'yyyy/MM/dd HH:mm');
}

/**
 * クライアント別スプレッドシートにメール情報を1行追加する。
 *
 * §4 クライアント別スプレッドシート設計に準拠:
 * No. | 受信日時 | 送信者 | 件名 | PDFリンク | 概要 | 添付ファイル | 処理日時
 *
 * ソート順は「受信日時の降順（新しいメールが上）」のため、
 * ヘッダー直下（2行目）に挿入する。
 *
 * @param spreadsheetId - クライアント別スプレッドシートの ID
 * @param sheetName - シート名
 * @param record - メール記録データ
 */
export function writeEmailRecord(
  spreadsheetId: string,
  sheetName: string,
  record: EmailRecord
): void {
  const ss = SpreadsheetApp.openById(spreadsheetId);
  const sheet = ss.getSheetByName(sheetName);
  if (!sheet) {
    throw new Error(
      `スプレッドシート ${spreadsheetId} にシート「${sheetName}」が見つかりません。`
    );
  }

  // ヘッダー直下に行を挿入（新しいメールが上に来るように）
  // 行2にinsertすると、既存の行が下にずれる
  sheet.insertRowAfter(1);

  // No. は既存の最大行数から計算（ヘッダー行を除く）
  // insertRowAfter の後なので lastRow - 1 が実際のデータ行数
  const dataRowCount = sheet.getLastRow() - 1;

  const row = [
    dataRowCount, // No.（連番）
    formatDateTime(record.receivedAt),
    record.sender,
    record.subject,
    record.pdfLink,      // Phase 1 では空文字
    record.summary,       // Phase 1 では空文字
    record.attachments,
    formatDateTime(record.processedAt),
  ];

  // 2行目に書き込み
  sheet.getRange(2, 1, 1, row.length).setValues([row]);
}
```

### 4.6 src/dedup.ts

```typescript
// src/dedup.ts
// 重複処理防止（PropertiesService + Gmail ラベル）
// §9.3 重複処理防止の設計に準拠

/** PropertiesService のキープレフィックス */
const PROCESSED_PREFIX = 'processed_';

/** 処理済みラベル名 */
const PROCESSED_LABEL = '_auto/processed';

/** クリーンアップ対象の経過日数（§9.3: 90日以上） */
const CLEANUP_DAYS = 90;

/**
 * メッセージが処理済みかどうかを判定する。
 * PropertiesService のキーを確認する。
 *
 * @param messageId - Gmail メッセージ ID
 * @returns true = 処理済み
 */
export function isProcessed(messageId: string): boolean {
  const props = PropertiesService.getScriptProperties();
  const value = props.getProperty(PROCESSED_PREFIX + messageId);
  return value !== null;
}

/**
 * メッセージを処理済みとしてマークする。
 *
 * 1. PropertiesService にメッセージ ID と処理日時を保存
 * 2. メッセージのスレッドに _auto/processed ラベルを付与
 *
 * なぜスレッド単位でラベルを付けるのか:
 * Gmail のラベルはスレッド単位で適用される。
 * メッセージ単位では付けられないため、スレッド全体にラベルを適用する。
 *
 * @param message - Gmail メッセージオブジェクト
 */
export function markAsProcessed(
  message: GoogleAppsScript.Gmail.GmailMessage
): void {
  const messageId = message.getId();
  const props = PropertiesService.getScriptProperties();

  // 1. PropertiesService に保存（値は処理日時のタイムスタンプ）
  props.setProperty(PROCESSED_PREFIX + messageId, String(Date.now()));

  // 2. Gmail ラベルを付与
  const label = getOrCreateLabel(PROCESSED_LABEL);
  const thread = message.getThread();
  thread.addLabel(label);
}

/**
 * Gmail ラベルを取得する。存在しない場合は作成する。
 *
 * @param labelName - ラベル名（例: "_auto/processed"）
 * @returns GmailLabel オブジェクト
 */
function getOrCreateLabel(
  labelName: string
): GoogleAppsScript.Gmail.GmailLabel {
  let label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    label = GmailApp.createLabel(labelName);
  }
  return label;
}

/**
 * 日次メンテナンス: 90日以上経過した処理済み ID を削除する。
 *
 * §9.3 PropertiesService の容量対策:
 * - プロパティストア上限: 500KB（約9,000プロパティ）
 * - 90日以上経過したエントリは不要（Gmail ラベルが永続的に残るため）
 *
 * @returns 削除した件数
 */
export function cleanupOldEntries(): number {
  const props = PropertiesService.getScriptProperties();
  const allProperties = props.getProperties();
  const cutoffTime = Date.now() - CLEANUP_DAYS * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  for (const key of Object.keys(allProperties)) {
    if (!key.startsWith(PROCESSED_PREFIX)) {
      continue;
    }

    const timestamp = parseInt(allProperties[key], 10);
    if (isNaN(timestamp) || timestamp < cutoffTime) {
      props.deleteProperty(key);
      deletedCount++;
    }
  }

  return deletedCount;
}
```

### 4.7 src/batch-processor.ts

```typescript
// src/batch-processor.ts
// バッチ処理制御（タイムアウト監視含む）
// §11 GAS の技術的制約（6分実行制限）に準拠

import { ClientConfig, EmailRecord, ProcessResult } from './types';
import { loadClientConfigs, getMasterSpreadsheetId } from './config';
import { fetchUnprocessedEmails, getAttachmentNames } from './gmail-fetcher';
import { matchClient, extractEmailAddress } from './client-matcher';
import { writeEmailRecord } from './sheet-writer';
import { markAsProcessed } from './dedup';
import { writeExecutionLog } from './logger';

/**
 * 最大実行時間（ミリ秒）。
 * GAS の制限は6分 = 360,000ms。
 * 1分のマージンを確保して5分 = 300,000ms とする。
 * §11: 残り60秒未満でループ中断。
 */
const MAX_EXECUTION_MS = 5 * 60 * 1000;

/** 1回のバッチで処理する最大メール数（§11: 上限20通） */
const BATCH_SIZE = 20;

/** API エラー時のリトライ回数（§9.4: 3回） */
const MAX_RETRIES = 3;

/** リトライ間隔の基本値（ミリ秒）（§9.4: 指数バックオフ 1s, 2s, 4s） */
const RETRY_BASE_MS = 1000;

/**
 * メール処理のバッチ実行。
 *
 * 処理フロー:
 * 1. マスタースプレッドシートからクライアント設定を読み込む
 * 2. 未処理メールを取得（最大 BATCH_SIZE 件）
 * 3. 各メールについて:
 *    a. タイムアウトチェック（残り60秒未満で中断）
 *    b. クライアント判定
 *    c. スプレッドシートに記録
 *    d. 処理済みマーク
 * 4. 実行ログをマスタースプレッドシートに記録
 *
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @returns バッチ処理の結果
 */
export function processBatch(masterSpreadsheetId: string): ProcessResult {
  const startTime = Date.now();
  const result: ProcessResult = {
    processed: 0,
    failed: 0,
    errors: [],
    timedOut: false,
  };

  // 1. クライアント設定を読み込む
  let configs: ClientConfig[];
  try {
    configs = loadClientConfigs(masterSpreadsheetId);
  } catch (e) {
    const errorMsg = `設定読み込み失敗: ${e instanceof Error ? e.message : String(e)}`;
    result.errors.push(errorMsg);
    result.failed = 1;
    return result;
  }

  if (configs.length === 0) {
    Logger.log('有効なクライアント設定がありません。処理をスキップします。');
    return result;
  }

  // 2. 未処理メールを取得
  let messages: GoogleAppsScript.Gmail.GmailMessage[];
  try {
    messages = fetchUnprocessedEmails(BATCH_SIZE);
  } catch (e) {
    const errorMsg = `メール取得失敗: ${e instanceof Error ? e.message : String(e)}`;
    result.errors.push(errorMsg);
    result.failed = 1;
    return result;
  }

  if (messages.length === 0) {
    Logger.log('未処理メールはありません。');
    return result;
  }

  Logger.log(`未処理メール ${messages.length} 件を取得。処理を開始します。`);

  // 3. 各メールを処理
  for (const message of messages) {
    // タイムアウトチェック: 残り60秒未満で中断
    const elapsed = Date.now() - startTime;
    if (elapsed > MAX_EXECUTION_MS - 60 * 1000) {
      Logger.log('タイムアウト間近のため処理を中断します。残りは次回トリガーで処理。');
      result.timedOut = true;
      break;
    }

    try {
      processOneEmail(message, configs);
      result.processed++;
    } catch (e) {
      result.failed++;
      const errorMsg =
        `メール処理失敗 (ID: ${message.getId()}, 件名: ${message.getSubject()}): ` +
        `${e instanceof Error ? e.message : String(e)}`;
      result.errors.push(errorMsg);
      Logger.log(errorMsg);
      // 個別のメール処理失敗では全体を停止しない（次のメールへ続行）
    }
  }

  return result;
}

/**
 * 1通のメールを処理する。
 *
 * @param message - Gmail メッセージオブジェクト
 * @param configs - クライアント設定一覧
 */
function processOneEmail(
  message: GoogleAppsScript.Gmail.GmailMessage,
  configs: ClientConfig[]
): void {
  const fromHeader = message.getFrom();
  const senderEmail = extractEmailAddress(fromHeader);

  // クライアント判定
  const clientConfig = matchClient(senderEmail, configs);

  if (!clientConfig) {
    // マッチしないメールは処理済みマークだけ付けてスキップ
    // §2: マッチしない場合 → 「未分類」フォルダに保存 + 警告ログ
    Logger.log(`未分類メール: ${senderEmail} — ${message.getSubject()}`);
    markAsProcessed(message);
    return;
  }

  // スプレッドシートに記録
  const record: EmailRecord = {
    no: 0, // sheet-writer 内で計算
    receivedAt: message.getDate(),
    sender: fromHeader,
    subject: message.getSubject(),
    pdfLink: '',       // Phase 1 では空文字
    summary: '',        // Phase 1 では空文字
    attachments: getAttachmentNames(message),
    processedAt: new Date(),
  };

  // リトライ付きでスプレッドシートに書き込み
  retryWithBackoff(() => {
    writeEmailRecord(
      clientConfig.spreadsheetId,
      clientConfig.sheetName,
      record
    );
  });

  // 処理済みマーク
  markAsProcessed(message);

  Logger.log(
    `処理完了: ${clientConfig.clientName} — ${message.getSubject()}`
  );
}

/**
 * 指数バックオフ付きリトライ。
 * §9.4 リトライ戦略に準拠（API一時エラー: 3回、1s/2s/4s）。
 *
 * @param fn - リトライ対象の関数
 */
function retryWithBackoff(fn: () => void): void {
  let lastError: unknown;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      fn();
      return; // 成功
    } catch (e) {
      lastError = e;
      const waitMs = RETRY_BASE_MS * Math.pow(2, attempt);
      Logger.log(
        `リトライ ${attempt + 1}/${MAX_RETRIES}（${waitMs}ms 待機）: ` +
        `${e instanceof Error ? e.message : String(e)}`
      );
      Utilities.sleep(waitMs);
    }
  }
  throw lastError;
}
```

### 4.8 src/logger.ts

```typescript
// src/logger.ts
// 実行ログをマスタースプレッドシートの execution_log シートに記録する
// §3.2 実行ログシートの設計に準拠

import { ExecutionLog } from './types';

/**
 * 日時を "yyyy/MM/dd HH:mm:ss" 形式にフォーマットする。
 *
 * @param date - フォーマット対象の Date
 * @returns フォーマットされた日時文字列
 */
function formatDateTimeFull(date: Date): string {
  return Utilities.formatDate(date, 'Asia/Tokyo', 'yyyy/MM/dd HH:mm:ss');
}

/**
 * 実行 ID を生成する。
 * タイムスタンプベース: "exec_20260212_100530"
 *
 * @param date - 基準日時
 * @returns 実行 ID 文字列
 */
export function generateExecutionId(date: Date): string {
  const formatted = Utilities.formatDate(date, 'Asia/Tokyo', 'yyyyMMdd_HHmmss');
  return `exec_${formatted}`;
}

/**
 * 実行ログをマスタースプレッドシートの execution_log シートに追記する。
 *
 * カラム: execution_id | started_at | finished_at | emails_processed |
 *         emails_failed | status | error_details
 *
 * @param masterSpreadsheetId - マスタースプレッドシートの ID
 * @param log - 実行ログデータ
 */
export function writeExecutionLog(
  masterSpreadsheetId: string,
  log: ExecutionLog
): void {
  const ss = SpreadsheetApp.openById(masterSpreadsheetId);
  const sheet = ss.getSheetByName('execution_log');
  if (!sheet) {
    Logger.log('execution_log シートが見つかりません。ログの記録をスキップします。');
    return;
  }

  const row = [
    log.executionId,
    formatDateTimeFull(log.startedAt),
    formatDateTimeFull(log.finishedAt),
    log.emailsProcessed,
    log.emailsFailed,
    log.status,
    log.errorDetails,
  ];

  sheet.appendRow(row);
}
```

### 4.9 src/index.ts

```typescript
// src/index.ts
// エントリーポイント: GAS 公開関数を定義する
//
// rollup-plugin-gas が global に代入された関数を
// トップレベル関数宣言に変換する。これにより GAS のトリガーや
// google.script.run から呼び出し可能になる。

import { ProcessResult, ExecutionLog } from './types';
import { getMasterSpreadsheetId } from './config';
import { processBatch } from './batch-processor';
import { writeExecutionLog, generateExecutionId } from './logger';
import { cleanupOldEntries } from './dedup';

/**
 * メイン処理: 未処理メールを取得し、クライアント判定→スプレッドシート記録を行う。
 *
 * トリガー（5分間隔）から呼び出される関数。
 * 1回の実行で最大20通を処理。残りは次回トリガーで処理される。
 */
function processEmails(): void {
  const startedAt = new Date();
  let masterSpreadsheetId: string;

  try {
    masterSpreadsheetId = getMasterSpreadsheetId();
  } catch (e) {
    Logger.log(`致命的エラー: ${e instanceof Error ? e.message : String(e)}`);
    return;
  }

  Logger.log('=== processEmails 開始 ===');

  let result: ProcessResult;
  try {
    result = processBatch(masterSpreadsheetId);
  } catch (e) {
    // バッチ処理全体が失敗した場合
    const errorMsg = `バッチ処理エラー: ${e instanceof Error ? e.message : String(e)}`;
    Logger.log(errorMsg);

    const log: ExecutionLog = {
      executionId: generateExecutionId(startedAt),
      startedAt,
      finishedAt: new Date(),
      emailsProcessed: 0,
      emailsFailed: 0,
      status: 'error',
      errorDetails: errorMsg,
    };
    safeWriteLog(masterSpreadsheetId, log);
    return;
  }

  // 実行ログを記録
  const finishedAt = new Date();
  const status: ExecutionLog['status'] =
    result.failed === 0 && !result.timedOut
      ? 'success'
      : result.processed === 0 && result.failed > 0
        ? 'error'
        : 'partial';

  const log: ExecutionLog = {
    executionId: generateExecutionId(startedAt),
    startedAt,
    finishedAt,
    emailsProcessed: result.processed,
    emailsFailed: result.failed,
    status,
    errorDetails: result.errors.join(' | '),
  };

  safeWriteLog(masterSpreadsheetId, log);

  Logger.log(
    `=== processEmails 完了: 処理=${result.processed}, 失敗=${result.failed}, ` +
    `タイムアウト=${result.timedOut} ===`
  );
}

/**
 * 日次メンテナンス: 古い処理済み ID の削除、ログ整理。
 *
 * 毎日午前2時のトリガーから呼び出される。
 * §9.3: 90日以上経過した処理済みIDを日次メンテナンスで削除。
 */
function dailyMaintenance(): void {
  Logger.log('=== dailyMaintenance 開始 ===');

  try {
    const deletedCount = cleanupOldEntries();
    Logger.log(`処理済みID クリーンアップ完了: ${deletedCount} 件削除`);
  } catch (e) {
    Logger.log(
      `クリーンアップエラー: ${e instanceof Error ? e.message : String(e)}`
    );
  }

  Logger.log('=== dailyMaintenance 完了 ===');
}

/**
 * 初期セットアップ: トリガー登録。
 *
 * 手動で1回だけ実行する関数。
 * - 既存トリガーを全削除 → 新規登録（重複防止）
 * - 5分間隔のメイン処理トリガー
 * - 日次メンテナンストリガー（毎日午前2時）
 */
function setup(): void {
  Logger.log('=== setup 開始 ===');

  // 既存のトリガーを削除（重複防止）
  const triggers = ScriptApp.getProjectTriggers();
  for (const trigger of triggers) {
    ScriptApp.deleteTrigger(trigger);
  }
  Logger.log(`既存トリガー ${triggers.length} 件を削除`);

  // 5分間隔のメイン処理トリガー
  ScriptApp.newTrigger('processEmails')
    .timeBased()
    .everyMinutes(5)
    .create();

  // 日次メンテナンストリガー（毎日午前2時）
  ScriptApp.newTrigger('dailyMaintenance')
    .timeBased()
    .atHour(2)
    .everyDays(1)
    .create();

  Logger.log('トリガー登録完了: processEmails(5分), dailyMaintenance(毎日2時)');

  // Script Properties の確認
  try {
    const id = getMasterSpreadsheetId();
    Logger.log(`MASTER_SPREADSHEET_ID: ${id} （設定済み）`);
  } catch (e) {
    Logger.log(
      '⚠ MASTER_SPREADSHEET_ID が未設定です。' +
      'プロジェクトの設定 → スクリプト プロパティ で設定してください。'
    );
  }

  Logger.log('=== setup 完了 ===');
}

/**
 * ログ書き込みのラッパー。ログ記録自体の失敗で処理を止めないようにする。
 */
function safeWriteLog(masterSpreadsheetId: string, log: ExecutionLog): void {
  try {
    writeExecutionLog(masterSpreadsheetId, log);
  } catch (e) {
    Logger.log(
      `実行ログの記録に失敗: ${e instanceof Error ? e.message : String(e)}`
    );
  }
}

// rollup-plugin-gas が認識するためにグローバルに公開
declare const global: Record<string, unknown>;
global.processEmails = processEmails;
global.dailyMaintenance = dailyMaintenance;
global.setup = setup;
```

---

## 第5章: テストコード全文

### 5.1 test/ ディレクトリ構造

```
test/
├── mocks/
│   └── gas-globals.ts          # GAS グローバルのモック定義
├── config.test.ts              # config.ts のテスト
├── gmail-fetcher.test.ts       # gmail-fetcher.ts のテスト
├── client-matcher.test.ts      # client-matcher.ts のテスト
├── sheet-writer.test.ts        # sheet-writer.ts のテスト
├── dedup.test.ts               # dedup.ts のテスト
└── batch-processor.test.ts     # batch-processor.ts のテスト
```

### 5.2 test/mocks/gas-globals.ts

> cmd_018 のセットアップ手順書で提供済みのモックを Phase 1 用に拡張。

```typescript
// test/mocks/gas-globals.ts
// GAS グローバルオブジェクトのモック定義
// jest.config.js の setupFiles で自動読み込み

// --- GmailApp ---
const mockGmailLabel = {
  getName: jest.fn().mockReturnValue('_auto/processed'),
};

const mockGmailThread = {
  getMessages: jest.fn().mockReturnValue([]),
  addLabel: jest.fn(),
};

const mockGmailApp = {
  search: jest.fn().mockReturnValue([]),
  getInboxThreads: jest.fn().mockReturnValue([]),
  getUserLabelByName: jest.fn().mockReturnValue(mockGmailLabel),
  createLabel: jest.fn().mockReturnValue(mockGmailLabel),
};

// --- DriveApp ---
const mockFolder = {
  createFile: jest.fn().mockReturnValue({
    getUrl: jest.fn().mockReturnValue('https://drive.google.com/file/d/xxx/view'),
    getId: jest.fn().mockReturnValue('file-id-123'),
    setName: jest.fn(),
  }),
  getFoldersByName: jest.fn().mockReturnValue({
    hasNext: jest.fn().mockReturnValue(false),
    next: jest.fn(),
  }),
  createFolder: jest.fn(),
};

const mockDriveApp = {
  getFolderById: jest.fn().mockReturnValue(mockFolder),
  getRootFolder: jest.fn().mockReturnValue(mockFolder),
};

// --- SpreadsheetApp ---
const mockRange = {
  getValues: jest.fn().mockReturnValue([[]]),
  setValues: jest.fn(),
  setValue: jest.fn(),
  getValue: jest.fn(),
};

const mockSheet = {
  getRange: jest.fn().mockReturnValue(mockRange),
  getLastRow: jest.fn().mockReturnValue(1),
  appendRow: jest.fn(),
  getName: jest.fn().mockReturnValue('メール一覧'),
  insertRowAfter: jest.fn(),
};

const mockSpreadsheet = {
  getSheetByName: jest.fn().mockReturnValue(mockSheet),
  getActiveSheet: jest.fn().mockReturnValue(mockSheet),
  insertSheet: jest.fn().mockReturnValue(mockSheet),
};

const mockSpreadsheetApp = {
  openById: jest.fn().mockReturnValue(mockSpreadsheet),
  getActiveSpreadsheet: jest.fn().mockReturnValue(mockSpreadsheet),
};

// --- UrlFetchApp ---
const mockUrlFetchApp = {
  fetch: jest.fn().mockReturnValue({
    getContentText: jest.fn().mockReturnValue('{}'),
    getResponseCode: jest.fn().mockReturnValue(200),
  }),
};

// --- PropertiesService ---
const propertiesStore: Record<string, string> = {};

const mockProperties = {
  getProperty: jest.fn((key: string) => propertiesStore[key] ?? null),
  setProperty: jest.fn((key: string, value: string) => {
    propertiesStore[key] = value;
  }),
  deleteProperty: jest.fn((key: string) => {
    delete propertiesStore[key];
  }),
  getProperties: jest.fn(() => ({ ...propertiesStore })),
};

const mockPropertiesService = {
  getScriptProperties: jest.fn().mockReturnValue(mockProperties),
  getUserProperties: jest.fn().mockReturnValue(mockProperties),
};

// --- Utilities ---
const mockUtilities = {
  newBlob: jest.fn().mockReturnValue({
    getAs: jest.fn().mockReturnValue({
      getBytes: jest.fn().mockReturnValue([]),
      setName: jest.fn(),
    }),
    setName: jest.fn(),
    getContentType: jest.fn().mockReturnValue('application/pdf'),
  }),
  formatDate: jest.fn(
    (_date: Date, _tz: string, format: string) => {
      const d = _date instanceof Date ? _date : new Date();
      const pad = (n: number): string => String(n).padStart(2, '0');
      // 簡易フォーマット（テスト用）
      if (format === 'yyyy/MM/dd HH:mm') {
        return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
      }
      if (format === 'yyyy/MM/dd HH:mm:ss') {
        return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
      }
      if (format === 'yyyyMMdd_HHmmss') {
        return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
      }
      return d.toISOString();
    }
  ),
  base64Encode: jest.fn().mockReturnValue('base64string'),
  sleep: jest.fn(),
};

// --- Logger ---
const mockLogger = {
  log: jest.fn(),
};

// --- ScriptApp ---
const mockScriptApp = {
  getProjectTriggers: jest.fn().mockReturnValue([]),
  deleteTrigger: jest.fn(),
  newTrigger: jest.fn().mockReturnValue({
    timeBased: jest.fn().mockReturnValue({
      everyMinutes: jest.fn().mockReturnValue({
        create: jest.fn(),
      }),
      atHour: jest.fn().mockReturnValue({
        everyDays: jest.fn().mockReturnValue({
          create: jest.fn(),
        }),
      }),
    }),
  }),
};

// グローバルに登録
Object.assign(global, {
  GmailApp: mockGmailApp,
  DriveApp: mockDriveApp,
  SpreadsheetApp: mockSpreadsheetApp,
  UrlFetchApp: mockUrlFetchApp,
  PropertiesService: mockPropertiesService,
  Utilities: mockUtilities,
  Logger: mockLogger,
  ScriptApp: mockScriptApp,
});

// テスト間でモック状態をリセットするヘルパー
export function resetAllMocks(): void {
  jest.clearAllMocks();
  // PropertiesService のストアをクリア
  for (const key of Object.keys(propertiesStore)) {
    delete propertiesStore[key];
  }
}

// PropertiesService のストアに直接値をセットするヘルパー（テスト用）
export function setPropertyDirectly(key: string, value: string): void {
  propertiesStore[key] = value;
}
```

### 5.3 test/config.test.ts

```typescript
// test/config.test.ts
import { resetAllMocks, setPropertyDirectly } from './mocks/gas-globals';
import { loadClientConfigs, getMasterSpreadsheetId } from '../src/config';

describe('config', () => {
  beforeEach(() => {
    resetAllMocks();
  });

  describe('getMasterSpreadsheetId', () => {
    test('Script Properties に設定されている場合、ID を返す', () => {
      setPropertyDirectly('MASTER_SPREADSHEET_ID', 'test-sheet-id');
      const result = getMasterSpreadsheetId();
      expect(result).toBe('test-sheet-id');
    });

    test('Script Properties に未設定の場合、エラーをスローする', () => {
      expect(() => getMasterSpreadsheetId()).toThrow(
        'MASTER_SPREADSHEET_ID が Script Properties に設定されていません'
      );
    });
  });

  describe('loadClientConfigs', () => {
    test('有効なクライアント設定を読み込む', () => {
      const mockSheet = {
        getLastRow: jest.fn().mockReturnValue(3),
        getRange: jest.fn().mockReturnValue({
          getValues: jest.fn().mockReturnValue([
            ['CL001', 'テスト株式会社', '*@test.co.jp', 'sheet-001', 'メール一覧', 'folder-001', true, '2026/02/12', ''],
            ['CL002', '山田太郎', 'yamada@example.com', 'sheet-002', '', 'folder-002', true, '2026/02/12', 'テスト'],
          ]),
        }),
      };

      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(mockSheet),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const configs = loadClientConfigs('master-id');

      expect(configs).toHaveLength(2);
      expect(configs[0].clientId).toBe('CL001');
      expect(configs[0].emailPattern).toBe('*@test.co.jp');
      expect(configs[0].sheetName).toBe('メール一覧');
      expect(configs[1].clientId).toBe('CL002');
      expect(configs[1].sheetName).toBe('メール一覧'); // デフォルト値
    });

    test('is_active が FALSE のクライアントは除外される', () => {
      const mockSheet = {
        getLastRow: jest.fn().mockReturnValue(2),
        getRange: jest.fn().mockReturnValue({
          getValues: jest.fn().mockReturnValue([
            ['CL001', 'テスト', '*@test.co.jp', 'sheet-001', 'メール一覧', 'folder-001', false, '', ''],
          ]),
        }),
      };

      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(mockSheet),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const configs = loadClientConfigs('master-id');
      expect(configs).toHaveLength(0);
    });

    test('spreadsheet_id が空のクライアントは除外される', () => {
      const mockSheet = {
        getLastRow: jest.fn().mockReturnValue(2),
        getRange: jest.fn().mockReturnValue({
          getValues: jest.fn().mockReturnValue([
            ['CL001', 'テスト', '*@test.co.jp', '', 'メール一覧', 'folder-001', true, '', ''],
          ]),
        }),
      };

      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(mockSheet),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const configs = loadClientConfigs('master-id');
      expect(configs).toHaveLength(0);
    });

    test('clients シートが見つからない場合、エラーをスローする', () => {
      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(null),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      expect(() => loadClientConfigs('master-id')).toThrow(
        '「clients」シートが見つかりません'
      );
    });

    test('ヘッダー行のみ（クライアント未登録）の場合、空配列を返す', () => {
      const mockSheet = {
        getLastRow: jest.fn().mockReturnValue(1),
      };

      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(mockSheet),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const configs = loadClientConfigs('master-id');
      expect(configs).toHaveLength(0);
    });
  });
});
```

### 5.4 test/gmail-fetcher.test.ts

```typescript
// test/gmail-fetcher.test.ts
import { resetAllMocks, setPropertyDirectly } from './mocks/gas-globals';
import { fetchUnprocessedEmails, getAttachmentNames } from '../src/gmail-fetcher';

describe('gmail-fetcher', () => {
  beforeEach(() => {
    resetAllMocks();
  });

  describe('fetchUnprocessedEmails', () => {
    test('未処理メールを取得する', () => {
      const mockMessage1 = {
        getId: jest.fn().mockReturnValue('msg-001'),
      };
      const mockMessage2 = {
        getId: jest.fn().mockReturnValue('msg-002'),
      };
      const mockThread = {
        getMessages: jest.fn().mockReturnValue([mockMessage1, mockMessage2]),
      };
      (GmailApp.search as jest.Mock).mockReturnValue([mockThread]);

      const messages = fetchUnprocessedEmails(20);

      expect(GmailApp.search).toHaveBeenCalledWith(
        'in:inbox -label:_auto/processed',
        0,
        20
      );
      expect(messages).toHaveLength(2);
    });

    test('処理済みメールは除外される', () => {
      const mockMessage1 = {
        getId: jest.fn().mockReturnValue('msg-001'),
      };
      const mockMessage2 = {
        getId: jest.fn().mockReturnValue('msg-002'),
      };
      const mockThread = {
        getMessages: jest.fn().mockReturnValue([mockMessage1, mockMessage2]),
      };
      (GmailApp.search as jest.Mock).mockReturnValue([mockThread]);

      // msg-001 を処理済みとしてマーク
      setPropertyDirectly('processed_msg-001', String(Date.now()));

      const messages = fetchUnprocessedEmails(20);
      expect(messages).toHaveLength(1);
      expect(messages[0].getId()).toBe('msg-002');
    });

    test('maxResults で結果数を制限できる', () => {
      const mockMessages = Array.from({ length: 5 }, (_, i) => ({
        getId: jest.fn().mockReturnValue(`msg-${i}`),
      }));
      const mockThread = {
        getMessages: jest.fn().mockReturnValue(mockMessages),
      };
      (GmailApp.search as jest.Mock).mockReturnValue([mockThread]);

      const messages = fetchUnprocessedEmails(3);
      expect(messages).toHaveLength(3);
    });

    test('検索結果が空の場合、空配列を返す', () => {
      (GmailApp.search as jest.Mock).mockReturnValue([]);

      const messages = fetchUnprocessedEmails();
      expect(messages).toHaveLength(0);
    });
  });

  describe('getAttachmentNames', () => {
    test('添付ファイル名をカンマ区切りで返す', () => {
      const mockMessage = {
        getAttachments: jest.fn().mockReturnValue([
          { getName: jest.fn().mockReturnValue('契約書.pdf') },
          { getName: jest.fn().mockReturnValue('見積書.xlsx') },
        ]),
      } as unknown as GoogleAppsScript.Gmail.GmailMessage;

      const result = getAttachmentNames(mockMessage);
      expect(result).toBe('契約書.pdf, 見積書.xlsx');
    });

    test('添付ファイルがない場合、空文字を返す', () => {
      const mockMessage = {
        getAttachments: jest.fn().mockReturnValue([]),
      } as unknown as GoogleAppsScript.Gmail.GmailMessage;

      const result = getAttachmentNames(mockMessage);
      expect(result).toBe('');
    });
  });
});
```

### 5.5 test/client-matcher.test.ts

```typescript
// test/client-matcher.test.ts
import { resetAllMocks } from './mocks/gas-globals';
import {
  extractEmailAddress,
  matchesPattern,
  matchClient,
} from '../src/client-matcher';
import { ClientConfig } from '../src/types';

describe('client-matcher', () => {
  beforeEach(() => {
    resetAllMocks();
  });

  describe('extractEmailAddress', () => {
    test('"名前 <email>" 形式からアドレスを抽出する', () => {
      expect(extractEmailAddress('田中太郎 <tanaka@example.com>'))
        .toBe('tanaka@example.com');
    });

    test('"<email>" 形式からアドレスを抽出する', () => {
      expect(extractEmailAddress('<tanaka@example.com>'))
        .toBe('tanaka@example.com');
    });

    test('プレーンなアドレスをそのまま返す', () => {
      expect(extractEmailAddress('tanaka@example.com'))
        .toBe('tanaka@example.com');
    });

    test('大文字を小文字に正規化する', () => {
      expect(extractEmailAddress('Tanaka@Example.COM'))
        .toBe('tanaka@example.com');
    });

    test('前後の空白をトリムする', () => {
      expect(extractEmailAddress('  tanaka@example.com  '))
        .toBe('tanaka@example.com');
    });
  });

  describe('matchesPattern', () => {
    test('ドメインパターン（*@domain）にマッチする', () => {
      expect(matchesPattern('info@test-corp.co.jp', '*@test-corp.co.jp'))
        .toBe(true);
    });

    test('異なるドメインにはマッチしない', () => {
      expect(matchesPattern('info@other-corp.co.jp', '*@test-corp.co.jp'))
        .toBe(false);
    });

    test('完全一致パターンにマッチする', () => {
      expect(matchesPattern('yamada@example.com', 'yamada@example.com'))
        .toBe(true);
    });

    test('異なるアドレスにはマッチしない', () => {
      expect(matchesPattern('suzuki@example.com', 'yamada@example.com'))
        .toBe(false);
    });

    test('パターンの大文字小文字を無視する', () => {
      expect(matchesPattern('info@test.co.jp', '*@TEST.CO.JP'))
        .toBe(true);
    });
  });

  describe('matchClient', () => {
    const configs: ClientConfig[] = [
      {
        clientId: 'CL001',
        clientName: 'テスト株式会社',
        emailPattern: '*@test-corp.co.jp',
        spreadsheetId: 'sheet-001',
        sheetName: 'メール一覧',
        driveFolderId: 'folder-001',
        isActive: true,
        createdAt: '2026/02/12',
        notes: '',
      },
      {
        clientId: 'CL002',
        clientName: '山田太郎',
        emailPattern: 'yamada@example.com',
        spreadsheetId: 'sheet-002',
        sheetName: 'メール一覧',
        driveFolderId: 'folder-002',
        isActive: true,
        createdAt: '2026/02/12',
        notes: '',
      },
      {
        clientId: 'CL003',
        clientName: '複数パターン社',
        emailPattern: '*@multi.co.jp,ceo@multi-group.com',
        spreadsheetId: 'sheet-003',
        sheetName: 'メール一覧',
        driveFolderId: 'folder-003',
        isActive: true,
        createdAt: '2026/02/12',
        notes: '',
      },
    ];

    test('ドメインパターンでクライアントを特定する', () => {
      const result = matchClient('info@test-corp.co.jp', configs);
      expect(result).not.toBeNull();
      expect(result?.clientId).toBe('CL001');
    });

    test('完全一致でクライアントを特定する', () => {
      const result = matchClient('yamada@example.com', configs);
      expect(result).not.toBeNull();
      expect(result?.clientId).toBe('CL002');
    });

    test('カンマ区切りの複数パターンにマッチする', () => {
      const result1 = matchClient('staff@multi.co.jp', configs);
      expect(result1?.clientId).toBe('CL003');

      const result2 = matchClient('ceo@multi-group.com', configs);
      expect(result2?.clientId).toBe('CL003');
    });

    test('マッチしない場合は null を返す', () => {
      const result = matchClient('unknown@nowhere.com', configs);
      expect(result).toBeNull();
    });
  });
});
```

### 5.6 test/sheet-writer.test.ts

```typescript
// test/sheet-writer.test.ts
import { resetAllMocks } from './mocks/gas-globals';
import { writeEmailRecord, formatDateTime } from '../src/sheet-writer';
import { EmailRecord } from '../src/types';

describe('sheet-writer', () => {
  beforeEach(() => {
    resetAllMocks();
  });

  describe('formatDateTime', () => {
    test('Date を "yyyy/MM/dd HH:mm" 形式にフォーマットする', () => {
      const date = new Date(2026, 1, 12, 10, 30); // 2026-02-12 10:30
      const result = formatDateTime(date);
      expect(result).toBe('2026/02/12 10:30');
    });
  });

  describe('writeEmailRecord', () => {
    test('スプレッドシートに行を挿入して書き込む', () => {
      const mockRange = {
        setValues: jest.fn(),
      };
      const mockSheet = {
        getLastRow: jest.fn().mockReturnValue(3), // ヘッダー + 挿入行 + 既存1行
        insertRowAfter: jest.fn(),
        getRange: jest.fn().mockReturnValue(mockRange),
      };
      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(mockSheet),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const record: EmailRecord = {
        no: 0,
        receivedAt: new Date(2026, 1, 12, 10, 0),
        sender: '田中太郎 <tanaka@example.com>',
        subject: '契約書の件',
        pdfLink: '',
        summary: '',
        attachments: '契約書.pdf',
        processedAt: new Date(2026, 1, 12, 10, 5),
      };

      writeEmailRecord('sheet-001', 'メール一覧', record);

      expect(mockSheet.insertRowAfter).toHaveBeenCalledWith(1);
      expect(mockSheet.getRange).toHaveBeenCalledWith(2, 1, 1, 8);
      expect(mockRange.setValues).toHaveBeenCalledWith([
        expect.arrayContaining([
          2, // No. (lastRow - 1 = 3 - 1 = 2)
          '2026/02/12 10:00',
          '田中太郎 <tanaka@example.com>',
          '契約書の件',
          '',
          '',
          '契約書.pdf',
          '2026/02/12 10:05',
        ]),
      ]);
    });

    test('シートが見つからない場合、エラーをスローする', () => {
      const mockSS = {
        getSheetByName: jest.fn().mockReturnValue(null),
      };
      (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

      const record: EmailRecord = {
        no: 0,
        receivedAt: new Date(),
        sender: 'test@test.com',
        subject: 'test',
        pdfLink: '',
        summary: '',
        attachments: '',
        processedAt: new Date(),
      };

      expect(() =>
        writeEmailRecord('sheet-001', 'メール一覧', record)
      ).toThrow('シート「メール一覧」が見つかりません');
    });
  });
});
```

### 5.7 test/dedup.test.ts

```typescript
// test/dedup.test.ts
import {
  resetAllMocks,
  setPropertyDirectly,
} from './mocks/gas-globals';
import { isProcessed, markAsProcessed, cleanupOldEntries } from '../src/dedup';

describe('dedup', () => {
  beforeEach(() => {
    resetAllMocks();
  });

  describe('isProcessed', () => {
    test('未処理のメッセージは false を返す', () => {
      expect(isProcessed('msg-001')).toBe(false);
    });

    test('処理済みのメッセージは true を返す', () => {
      setPropertyDirectly('processed_msg-001', String(Date.now()));
      expect(isProcessed('msg-001')).toBe(true);
    });
  });

  describe('markAsProcessed', () => {
    test('PropertiesService に保存し、ラベルを付与する', () => {
      const mockThread = {
        addLabel: jest.fn(),
      };
      const mockMessage = {
        getId: jest.fn().mockReturnValue('msg-001'),
        getThread: jest.fn().mockReturnValue(mockThread),
      } as unknown as GoogleAppsScript.Gmail.GmailMessage;

      markAsProcessed(mockMessage);

      // PropertiesService に保存されたことを確認
      expect(isProcessed('msg-001')).toBe(true);

      // ラベルが付与されたことを確認
      expect(mockThread.addLabel).toHaveBeenCalled();
    });
  });

  describe('cleanupOldEntries', () => {
    test('90日以上経過したエントリを削除する', () => {
      const now = Date.now();
      const oldTimestamp = now - 91 * 24 * 60 * 60 * 1000; // 91日前
      const recentTimestamp = now - 10 * 24 * 60 * 60 * 1000; // 10日前

      setPropertyDirectly('processed_old-msg', String(oldTimestamp));
      setPropertyDirectly('processed_recent-msg', String(recentTimestamp));
      setPropertyDirectly('other_key', 'not-a-processed-entry');

      const deleted = cleanupOldEntries();

      expect(deleted).toBe(1);
      expect(isProcessed('old-msg')).toBe(false); // 削除済み
      expect(isProcessed('recent-msg')).toBe(true); // 残っている
    });

    test('処理済みエントリがない場合、0 を返す', () => {
      const deleted = cleanupOldEntries();
      expect(deleted).toBe(0);
    });
  });
});
```

### 5.8 test/batch-processor.test.ts

```typescript
// test/batch-processor.test.ts
import { resetAllMocks, setPropertyDirectly } from './mocks/gas-globals';
import { processBatch } from '../src/batch-processor';

describe('batch-processor', () => {
  beforeEach(() => {
    resetAllMocks();
    // MASTER_SPREADSHEET_ID を設定
    setPropertyDirectly('MASTER_SPREADSHEET_ID', 'master-sheet-id');
  });

  test('未処理メールがない場合、処理数0で正常終了する', () => {
    // clients シートのモック
    const mockClientsSheet = {
      getLastRow: jest.fn().mockReturnValue(2),
      getRange: jest.fn().mockReturnValue({
        getValues: jest.fn().mockReturnValue([
          ['CL001', 'テスト', '*@test.co.jp', 'sheet-001', 'メール一覧', '', true, '', ''],
        ]),
      }),
    };
    const mockSS = {
      getSheetByName: jest.fn().mockReturnValue(mockClientsSheet),
    };
    (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);
    (GmailApp.search as jest.Mock).mockReturnValue([]);

    const result = processBatch('master-sheet-id');

    expect(result.processed).toBe(0);
    expect(result.failed).toBe(0);
    expect(result.timedOut).toBe(false);
  });

  test('有効なクライアント設定がない場合、処理をスキップする', () => {
    const mockClientsSheet = {
      getLastRow: jest.fn().mockReturnValue(1), // ヘッダーのみ
    };
    const mockSS = {
      getSheetByName: jest.fn().mockReturnValue(mockClientsSheet),
    };
    (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

    const result = processBatch('master-sheet-id');

    expect(result.processed).toBe(0);
    expect(result.failed).toBe(0);
    expect(GmailApp.search).not.toHaveBeenCalled();
  });

  test('メール取得でエラーが発生した場合、エラー結果を返す', () => {
    const mockClientsSheet = {
      getLastRow: jest.fn().mockReturnValue(2),
      getRange: jest.fn().mockReturnValue({
        getValues: jest.fn().mockReturnValue([
          ['CL001', 'テスト', '*@test.co.jp', 'sheet-001', 'メール一覧', '', true, '', ''],
        ]),
      }),
    };
    const mockSS = {
      getSheetByName: jest.fn().mockReturnValue(mockClientsSheet),
    };
    (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);
    (GmailApp.search as jest.Mock).mockImplementation(() => {
      throw new Error('Gmail API error');
    });

    const result = processBatch('master-sheet-id');

    expect(result.failed).toBe(1);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toContain('メール取得失敗');
  });

  test('マッチしない送信者のメールは処理済みマークのみ付ける', () => {
    // clients シートのモック
    const mockClientsSheet = {
      getLastRow: jest.fn().mockReturnValue(2),
      getRange: jest.fn().mockReturnValue({
        getValues: jest.fn().mockReturnValue([
          ['CL001', 'テスト', '*@test.co.jp', 'sheet-001', 'メール一覧', '', true, '', ''],
        ]),
      }),
    };
    const mockSS = {
      getSheetByName: jest.fn().mockReturnValue(mockClientsSheet),
    };
    (SpreadsheetApp.openById as jest.Mock).mockReturnValue(mockSS);

    // 未知の送信者からのメール
    const mockThread = {
      addLabel: jest.fn(),
    };
    const mockMessage = {
      getId: jest.fn().mockReturnValue('msg-unknown'),
      getFrom: jest.fn().mockReturnValue('unknown@nowhere.com'),
      getSubject: jest.fn().mockReturnValue('テスト件名'),
      getDate: jest.fn().mockReturnValue(new Date()),
      getAttachments: jest.fn().mockReturnValue([]),
      getThread: jest.fn().mockReturnValue(mockThread),
    };
    const mockGmailThread = {
      getMessages: jest.fn().mockReturnValue([mockMessage]),
    };
    (GmailApp.search as jest.Mock).mockReturnValue([mockGmailThread]);

    const result = processBatch('master-sheet-id');

    // 未分類メールも processed としてカウント（スキップではない）
    // markAsProcessed が呼ばれていることを確認
    expect(mockThread.addLabel).toHaveBeenCalled();
  });
});
```

### 5.9 テスト実行コマンドと期待される結果

```bash
# テスト実行
npx jest

# 期待される結果:
# PASS  test/config.test.ts
# PASS  test/gmail-fetcher.test.ts
# PASS  test/client-matcher.test.ts
# PASS  test/sheet-writer.test.ts
# PASS  test/dedup.test.ts
# PASS  test/batch-processor.test.ts
#
# Test Suites: 6 passed, 6 total
# Tests:       XX passed, XX total

# カバレッジ付きテスト
npx jest --coverage

# 期待される結果:
# ----------------------|---------|----------|---------|---------|
# File                  | % Stmts | % Branch | % Funcs | % Lines |
# ----------------------|---------|----------|---------|---------|
# All files             |   8X.XX |   8X.XX  |   8X.XX |   8X.XX |
#  config.ts            |   ...   |   ...    |   ...   |   ...   |
#  gmail-fetcher.ts     |   ...   |   ...    |   ...   |   ...   |
#  client-matcher.ts    |   ...   |   ...    |   ...   |   ...   |
#  sheet-writer.ts      |   ...   |   ...    |   ...   |   ...   |
#  dedup.ts             |   ...   |   ...    |   ...   |   ...   |
#  batch-processor.ts   |   ...   |   ...    |   ...   |   ...   |
#  logger.ts            |   ...   |   ...    |   ...   |   ...   |
# ----------------------|---------|----------|---------|---------|
# 80% 以上であることを確認
```

---

## 第6章: デプロイと動作確認

### 6.1 ビルド → clasp push の手順

```bash
# Step 1: ビルド（TypeScript → JavaScript）
npm run build

# 期待される結果:
# （エラーなく完了。dist/Code.js が生成される）

# Step 2: dist/ の内容を確認
ls dist/
# 期待される結果:
# Code.js  appsscript.json

# Step 3: appsscript.json が dist/ にあることを確認
# なければコピー:
cp appsscript.json dist/appsscript.json

# Step 4: Apps Script にプッシュ
npx clasp push

# 期待される結果:
# └─ dist/Code.js
# └─ dist/appsscript.json
# Pushed 2 files.
```

### 6.2 Script Properties の設定

```
Step 1: Apps Script エディタを開く
        npx clasp open-script
        （ブラウザで Apps Script エディタが開く）

Step 2: 左メニュー「プロジェクトの設定」（歯車アイコン）をクリック

Step 3: 下部の「スクリプト プロパティ」セクション

Step 4: 「スクリプト プロパティを追加」をクリック

Step 5: 以下を入力:
        プロパティ: MASTER_SPREADSHEET_ID
        値: （第2章で作成したマスタースプレッドシートの ID）

Step 6: 「スクリプト プロパティを保存」をクリック
```

### 6.3 トリガー設定手順

#### 方法A: コードで設定（推奨）

```
Step 1: Apps Script エディタで「setup」関数を選択
        （上部のプルダウンメニューから「setup」を選択）

Step 2: 「実行」ボタン（▶）をクリック

Step 3: 初回実行時に権限の承認ダイアログが表示される:
        3a. 「権限を確認」をクリック
        3b. Google アカウントを選択
        3c. 「このアプリは Google で確認されていません」が表示された場合
            → 「詳細」→「Gmail Client Manager（安全ではないページ）に移動」
        3d. 要求されるスコープを確認し「許可」をクリック

Step 4: 実行ログで以下を確認:
        === setup 開始 ===
        既存トリガー 0 件を削除
        トリガー登録完了: processEmails(5分), dailyMaintenance(毎日2時)
        MASTER_SPREADSHEET_ID: xxxxxx （設定済み）
        === setup 完了 ===
```

#### 方法B: GAS エディタの GUI で設定

```
Step 1: 左メニュー「トリガー」（時計アイコン）をクリック

Step 2: 「トリガーを追加」をクリック

Step 3: メイン処理トリガーの設定:
        - 実行する関数: processEmails
        - 実行するデプロイ: Head
        - イベントのソース: 時間主導型
        - 時間ベースのトリガーのタイプ: 分ベースのタイマー
        - 時間の間隔: 5分おき
        → 「保存」

Step 4: 日次メンテナンストリガーの設定:
        - 実行する関数: dailyMaintenance
        - 実行するデプロイ: Head
        - イベントのソース: 時間主導型
        - 時間ベースのトリガーのタイプ: 日付ベースのタイマー
        - 時刻: 午前2時〜3時
        → 「保存」
```

### 6.4 動作確認手順

#### 確認1: テスト用メール送信

```
Step 1: テスト用の Gmail アカウント（または別のメールアカウント）から、
        マスタースプレッドシートに登録した email_pattern に合致するアドレスで
        テストメールを送信する。

        例: テスト株式会社（*@test-corp.co.jp）を登録した場合、
            test-corp.co.jp ドメインのアドレスからメールを送る。

        ※ 自分の Gmail アカウントから自分宛にメールを送ることも可能。
           その場合は email_pattern に自分のアドレスを設定する。
```

#### 確認2: 手動実行

```
Step 1: Apps Script エディタで「processEmails」関数を選択

Step 2: 「実行」ボタン（▶）をクリック

Step 3: 実行ログを確認:
        === processEmails 開始 ===
        未処理メール X 件を取得。処理を開始します。
        処理完了: テスト株式会社 — テスト件名
        === processEmails 完了: 処理=1, 失敗=0, タイムアウト=false ===
```

#### 確認3: マスタースプレッドシートの実行ログ確認

```
Step 1: マスタースプレッドシートを開く

Step 2: 「execution_log」シートを確認

Step 3: 以下の内容が記録されていることを確認:
        - execution_id: exec_20260212_XXXXXX
        - started_at: 実行開始日時
        - finished_at: 実行終了日時
        - emails_processed: 1（送信したテストメール数）
        - emails_failed: 0
        - status: success
        - error_details: （空欄）
```

#### 確認4: クライアント別スプレッドシートのメール一覧確認

```
Step 1: テスト用クライアントのスプレッドシートを開く

Step 2: 「メール一覧」シートを確認

Step 3: 以下の内容が記録されていることを確認:
        - No.: 1
        - 受信日時: テストメールの受信日時
        - 送信者: テストメールの送信者
        - 件名: テストメールの件名
        - PDFリンク: （空欄）← Phase 1 では空
        - 概要: （空欄）← Phase 1 では空
        - 添付ファイル: （添付がある場合はファイル名）
        - 処理日時: 処理実行日時
```

#### 確認5: Gmail の処理済みラベル確認

```
Step 1: Gmail を開く

Step 2: 左メニューの「_auto」→「processed」ラベルを確認

Step 3: 処理されたテストメールに「_auto/processed」ラベルが
        付与されていることを確認
```

#### 確認6: トリガー自動実行の確認

```
Step 1: 5分間待機（トリガーが発火するまで）

Step 2: 追加のテストメールを送信

Step 3: 5分後にクライアント別スプレッドシートを確認
        新しいメールが自動的に記録されていれば成功

Step 4: Apps Script エディタ → 左メニュー「実行」で
        トリガーによる実行履歴が記録されていることを確認
```

---

## 第7章: 運用設定

### 7.1 新しいクライアントの追加手順

```
Step 1: クライアント別スプレッドシートを新規作成
        - タイトル例: 「○○株式会社_メール管理」
        - シート名「メール一覧」を作成
        - 第2章の Step 5 と同じヘッダー行を設定
        - ヘッダー固定 + 条件付き書式

Step 2: スプレッドシート ID を控える

Step 3: マスタースプレッドシートの clients シートに行を追加:
        - client_id: 新しい ID（例: CL003）
        - client_name: クライアント名
        - email_pattern: メールアドレスまたはドメインパターン
          ※ 複数パターンはカンマ区切り（例: *@corp.co.jp,tanaka@personal.jp）
        - spreadsheet_id: Step 2 で控えた ID
        - sheet_name: メール一覧
        - drive_folder_id: （Phase 2 で使用。空欄可）
        - is_active: TRUE
        - created_at: 今日の日付
        - notes: 任意の備考

Step 4: 次回の processEmails 実行（最大5分後）から
        新しいクライアントのメールが処理される
        ※ コードの変更やデプロイは不要（マスタースプレッドシートを読み込むため）
```

### 7.2 トリガーの有効化/無効化

#### メール処理の一時停止

```
Step 1: Apps Script エディタを開く（npx clasp open-script）
Step 2: 左メニュー「トリガー」をクリック
Step 3: processEmails のトリガーの右端「⋮」→「トリガーを削除」

再開する場合:
Step 4: 「トリガーを追加」→ processEmails を5分間隔で設定
        または setup() を再実行
```

#### 特定のクライアントの処理停止

```
Step 1: マスタースプレッドシートの clients シートを開く
Step 2: 対象クライアントの is_active を FALSE に変更
        ※ 行は削除しない（履歴保持のため）
Step 3: 次回の processEmails 実行から、そのクライアントのメールは
        「未分類」扱いになる（処理済みマークは付くがシートには記録されない）
```

### 7.3 処理済み ID の定期クリーンアップ

`dailyMaintenance` 関数が毎日午前2時に自動実行され、90日以上経過した処理済み ID を PropertiesService から削除する。

**手動でクリーンアップを実行する場合**:

```
Step 1: Apps Script エディタで「dailyMaintenance」を選択
Step 2: 「実行」をクリック
Step 3: 実行ログで削除件数を確認
```

**PropertiesService の容量監視**:

```
現在の使用量を確認するには、Apps Script エディタのコンソールで以下を実行:

function checkPropertyUsage() {
  const props = PropertiesService.getScriptProperties().getProperties();
  const keys = Object.keys(props);
  const processedCount = keys.filter(k => k.startsWith('processed_')).length;
  const totalSize = JSON.stringify(props).length;
  Logger.log(`処理済みID数: ${processedCount}`);
  Logger.log(`プロパティストア使用量: 約 ${totalSize} bytes / 500,000 bytes`);
}
```

### 7.4 エラー発生時の対処フロー

```
[エラー検知]
     │
     ├── マスタースプレッドシートの execution_log を確認
     │   status が "error" または "partial" の行を探す
     │
     ├── error_details の内容で原因を特定:
     │
     │   ├── "設定読み込み失敗"
     │   │   → マスタースプレッドシートの ID が正しいか確認
     │   │   → Script Properties の MASTER_SPREADSHEET_ID を再確認
     │   │
     │   ├── "メール取得失敗"
     │   │   → Gmail API のクォータを確認
     │   │   → OAuth スコープに gmail.readonly があるか確認
     │   │
     │   ├── "シート「メール一覧」が見つかりません"
     │   │   → クライアント別スプレッドシートにシートが存在するか確認
     │   │   → clients シートの sheet_name カラムが正しいか確認
     │   │
     │   └── "致命的エラー" / "バッチ処理エラー"
     │       → Apps Script エディタの実行ログでスタックトレースを確認
     │       → コードの修正が必要な場合は修正→ビルド→プッシュ
     │
     └── Apps Script エディタ → 左メニュー「実行」で
         詳細な実行ログとスタックトレースを確認
```

---

## 第8章: Phase 2への準備

### 8.1 Phase 1 完了後のチェックリスト

- [ ] マスタースプレッドシートの clients シートにクライアントが登録されている
- [ ] テストメールが正しくクライアント別スプレッドシートに記録される
- [ ] 処理済みメールに `_auto/processed` ラベルが付与される
- [ ] 同じメールが二重処理されない（重複防止が機能している）
- [ ] execution_log に実行ログが記録される
- [ ] 5分間隔のトリガーが正常に動作する
- [ ] dailyMaintenance が毎日実行される
- [ ] 未知の送信者のメールがエラーを起こさない（未分類として処理される）
- [ ] 大量メール（20通以上）でタイムアウトせずにバッチ処理される
- [ ] テストカバレッジが80%以上である

### 8.2 Phase 2（PDF変換→Drive保存）で追加するモジュールの概要

Phase 2 では以下のモジュールを追加する:

| モジュール | 役割 | 依存先 |
|-----------|------|--------|
| `src/pdf-converter.ts` | HTML→PDF Blob変換（インライン画像のBase64補完処理含む） | Utilities.newBlob, GmailMessage |
| `src/drive-manager.ts` | Google Drive フォルダ管理（年/月サブフォルダ自動作成）、ファイル保存 | DriveApp |

**pdf-converter.ts のインターフェース（予定）**:

```typescript
/**
 * メール本文を PDF Blob に変換する。
 * インライン画像の CID 参照を Base64 データ URI に置換する補完処理を含む。
 * @param message - Gmail メッセージ
 * @returns PDF Blob（変換失敗時は HTML Blob をフォールバック）
 */
export function convertToPdf(
  message: GoogleAppsScript.Gmail.GmailMessage
): GoogleAppsScript.Base.Blob;
```

**drive-manager.ts のインターフェース（予定）**:

```typescript
/**
 * クライアントの Drive フォルダに PDF を保存する。
 * 年/月サブフォルダを自動作成する。
 * @param folderId - クライアントのルートフォルダ ID
 * @param blob - PDF Blob
 * @param fileName - ファイル名（命名規則適用済み）
 * @returns 保存されたファイルの URL
 */
export function saveToDrive(
  folderId: string,
  blob: GoogleAppsScript.Base.Blob,
  fileName: string
): string;
```

### 8.3 Phase 1 のコードで Phase 2 を見据えた設計ポイント

Phase 1 のコードには以下の拡張ポイントが設計されている:

#### 拡張点1: EmailRecord の pdfLink フィールド

```typescript
// 現在（Phase 1）: 空文字で記録
const record: EmailRecord = {
  ...
  pdfLink: '',       // ← Phase 2 で Drive ファイル URL が入る
  summary: '',        // ← Phase 3 で Gemini 要約が入る
  ...
};
```

Phase 2 では `batch-processor.ts` の `processOneEmail` 関数内で、`writeEmailRecord` の前に PDF 変換・Drive 保存を追加し、結果の URL を `pdfLink` にセットする。

#### 拡張点2: ClientConfig の driveFolderId フィールド

```typescript
// マスタースプレッドシートに drive_folder_id カラムが既に存在
// Phase 2 で drive-manager.ts がこの値を使用する
```

#### 拡張点3: batch-processor.ts の processOneEmail 関数

```typescript
// 現在の processOneEmail の処理フロー:
// 1. クライアント判定
// 2. スプレッドシートに記録
// 3. 処理済みマーク

// Phase 2 で以下を 2. の前に追加:
// 1.5. PDF 変換（pdf-converter.ts）
// 1.6. Drive 保存（drive-manager.ts）
// 1.7. record.pdfLink に URL をセット
```

#### 拡張点4: エラーハンドリングの拡張

Phase 1 で実装した `retryWithBackoff` 関数は Phase 2 の PDF 変換・Drive 保存でも再利用できる。リトライ戦略（§9.4）は API エラー種別に応じて指数バックオフのパラメータを変えられるよう設計済み。

#### 拡張点5: appsscript.json のスコープ

Phase 1 の `appsscript.json` には `drive.file` スコープが既に含まれている。Phase 2 で追加のスコープは不要（ただし、再承認が必要になる場合がある）。

---

## 付録: 参考情報

| 項目 | URL |
|------|-----|
| GmailApp リファレンス | https://developers.google.com/apps-script/reference/gmail/gmail-app |
| SpreadsheetApp リファレンス | https://developers.google.com/apps-script/reference/spreadsheet |
| PropertiesService リファレンス | https://developers.google.com/apps-script/reference/properties/properties-service |
| GAS クォータ一覧 | https://developers.google.com/apps-script/guides/services/quotas |
| rollup-plugin-gas | https://github.com/mato533/rollup-plugin-gas |
| clasp 公式リポジトリ | https://github.com/google/clasp |

---

## 付録: 要確認事項

以下の項目は実装時に最新情報を確認すること:

1. ~~rollup-plugin-gas の最新バージョン~~ → **解決済み**: `rollup-plugin-gas@^2.0.2`（mato533/rollup-plugin-gas）で確定（cmd_020で修正）
2. **GmailApp.search のクォータ**: Workspace アカウントと Consumer アカウントでクォータが異なる。実運用のアカウント種別に応じて `BATCH_SIZE` の調整が必要になる場合がある
3. **clasp 3.x のコマンド名**: `clasp push` / `clasp create-script` 等のコマンド名は clasp のバージョンで変わる場合がある。`npx clasp --help` で最新のコマンド一覧を確認

---

*本手順書は 2026年2月12日時点の情報に基づく。Google Apps Script の API・制約・料金は予告なく変更される場合がある。実装開始時に最新情報を再確認すること。*
