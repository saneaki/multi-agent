# 顧客メール管理GASシステム 設計ドキュメント

**cmd_455** | 作成: 軍師(subtask_455b) | 参照: cmd_447調査レポート
**North Star**: 顧客メール管理を自動化し、送受信履歴・PDF保存・AI要約を一元管理できる基盤を構築する

---

## 1. プロジェクト概要

### 1.1 システム概要

指定顧客のメールアドレスとの送受信メールを自動で管理するGoogle Apps Script(GAS)システム。
時間トリガーで定期実行し、新着メールの検出→PDF変換→Drive保存→AI要約→スプレッドシート転記を行う。

### 1.2 アーキテクチャ図

```
┌─────────────────────────────────────────────────────────┐
│                   Google Spreadsheet                     │
│                                                          │
│  ┌──────────────────┐                                    │
│  │  元帳シート        │  顧客マスタ（メアド・フォルダ等）     │
│  │  (Master)         │                                    │
│  └──────┬───────────┘                                    │
│         │ 1:N                                            │
│  ┌──────┴───────────┐  ┌─────────────────┐              │
│  │ メール一覧シートA   │  │ メール一覧シートB │  ...          │
│  │ (顧客A)           │  │ (顧客B)         │              │
│  └──────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
         │                        ▲
         │ 参照                    │ 転記
         ▼                        │
┌─────────────────────────────────────────────────────────┐
│                     GAS (main.gs)                        │
│                                                          │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐ │
│  │gmail.gs  │  │ pdf.gs  │  │summary.gs│  │sheets.gs │ │
│  │Gmail検索 │  │PDF変換  │  │AI要約    │  │シート操作│ │
│  │メール取得│  │Drive保存│  │Gemini API│  │読込/書込 │ │
│  └─────────┘  └─────────┘  └──────────┘  └──────────┘ │
│                                                          │
│  ┌──────────┐                                            │
│  │config.gs │  PropertiesService / 定数管理               │
│  └──────────┘                                            │
└─────────────────────────────────────────────────────────┘
         │              │                │
         ▼              ▼                ▼
   ┌──────────┐  ┌───────────┐  ┌──────────────────┐
   │  Gmail    │  │Google Drive│  │ Gemini API       │
   │  (検索)   │  │ (PDF保存)  │  │ (Vertex AI AS)   │
   └──────────┘  └───────────┘  └──────────────────┘
```

### 1.3 処理フロー

```
時間トリガー(毎15分)
  │
  ▼
main.gs: processAllCustomers()
  │
  ├─ sheets.gs: getCustomerList() → 元帳から顧客一覧取得
  │
  ├─ 各顧客について:
  │   │
  │   ├─ gmail.gs: searchNewEmails(customerEmail, lastCheckDate)
  │   │   └─ Gmail検索(from:OR to:) + 処理済みラベル除外
  │   │
  │   ├─ 新着メール毎:
  │   │   ├─ pdf.gs: convertEmailToPdf(message) → Blob生成
  │   │   ├─ pdf.gs: savePdfToDrive(blob, folderId) → PDF保存+URL取得
  │   │   ├─ summary.gs: generateSummary(body) → AI要約生成
  │   │   ├─ gmail.gs: markAsProcessed(message) → 処理済みラベル付与
  │   │   └─ sheets.gs: appendEmailRow(sheetId, rowData) → シート転記
  │   │
  │   └─ sheets.gs: updateLastCheckDate(customerRow) → 最終チェック日時更新
  │
  └─ 6分制限チェック: 超過前に中断→次回トリガーで続行
```

---

## 2. スプレッドシート設計

### 2.1 元帳シート（顧客マスタ）

シート名: `元帳`

| 列 | ヘッダー | 型 | 説明 | 例 |
|----|---------|-----|------|-----|
| A | 顧客名 | String | 顧客の表示名 | 山田商事 |
| B | メールアドレス | String | 管理対象メールアドレス | yamada@example.com |
| C | Driveフォルダリンク | URL | PDF保存先フォルダのURL | https://drive.google.com/drive/folders/xxx |
| D | DriveフォルダID | String | フォルダID（プログラム用） | 1AbCdEfGhIjKlMnOpQrStUv |
| E | メール一覧シートリンク | URL | 顧客専用シートのURL | （同一SpreadsheetのシートURL） |
| F | メール一覧シート名 | String | シート名（プログラム用） | メール_山田商事 |
| G | 最終チェック日時 | DateTime | 前回処理完了時刻(JST) | 2026-04-06T03:00:00 |
| H | ステータス | String | active / inactive | active |

**設計判断:**
- DriveフォルダIDとシート名を別列で持つ理由: GAS内部処理はIDを使い、リンク列は人間の閲覧用。
- メール一覧シートは同一Spreadsheet内の別シートとする（管理の一元化）。
- 顧客毎にDriveフォルダを分離する理由: 権限管理の容易性・将来の顧客別共有対応。

### 2.2 メール一覧シート（顧客毎）

シート名: `メール_{顧客名}`（例: `メール_山田商事`）

| 列 | ヘッダー | 型 | 説明 | 例 |
|----|---------|-----|------|-----|
| A | 送受信日時 | DateTime | メールの日時(JST) | 2026-04-05 14:30:00 |
| B | 方向 | String | 送信/受信 | 受信 |
| C | 送信者 | String | From表示名+アドレス | 山田太郎 <yamada@example.com> |
| D | 宛先 | String | To/CC表示 | info@company.com |
| E | 件名 | String | メール件名 | 見積書の件 |
| F | AI要約 | String | Gemini生成の要約(100字程度) | 見積書の修正依頼。納期を1週間延長希望。 |
| G | メールPDFリンク | URL | DriveのPDF URL | https://drive.google.com/file/d/xxx |
| H | GmailMessageId | String | Gmail内部ID（重複防止キー） | 18e1a2b3c4d5e6f7 |
| I | 処理日時 | DateTime | GASが処理した日時 | 2026-04-06 03:15:00 |

**設計判断:**
- 「方向」列を追加: from/toの判定で送信/受信を明示。業務上の検索性を向上。
- GmailMessageIdを記録: ラベル方式の補助として、シート側でも一意性を保証。
- 降順ソート不実施: GASで行追加は末尾が効率的。閲覧時はSpreadsheetのフィルタ/ソートで対応。

---

## 3. GASモジュール設計

### 3.1 main.gs — トリガーエントリ + オーケストレーション

**責務:** 処理全体のエントリポイント。顧客ループ・6分制限管理・エラーハンドリング。

```javascript
/**
 * 時間トリガーから呼ばれるメインエントリポイント。
 * 元帳の全active顧客についてメール処理を実行する。
 * 6分制限対策: 残り60秒でループを中断し、次回トリガーで続行。
 */
function processAllCustomers() → void

/**
 * 単一顧客のメール処理。
 * @param {Object} customer - 顧客情報オブジェクト
 *   { name, email, folderId, sheetName, lastCheckDate }
 * @returns {Object} { processed: number, errors: string[] }
 */
function processCustomer(customer) → { processed, errors }

/**
 * 6分制限チェック。開始時刻から経過時間を計算。
 * @param {number} startTime - Date.now()の開始時刻
 * @param {number} safetyMarginMs - 安全マージン(デフォルト60000ms=1分)
 * @returns {boolean} true=制限に近い、中断すべき
 */
function isApproachingTimeLimit(startTime, safetyMarginMs) → boolean

/**
 * トリガー設定用。スクリプトエディタから手動実行。
 * 既存トリガーを削除し、15分間隔の時間トリガーを作成。
 */
function setupTrigger() → void

/**
 * トリガー削除用。
 */
function removeTrigger() → void
```

**6分制限管理の設計:**

```javascript
function processAllCustomers() {
  const startTime = Date.now();
  const customers = getCustomerList(); // sheets.gs
  const resumeIndex = getResumeIndex(); // config.gs — 前回中断位置

  for (let i = resumeIndex; i < customers.length; i++) {
    if (isApproachingTimeLimit(startTime, 60000)) {
      saveResumeIndex(i); // config.gs — 中断位置保存
      Logger.log('6分制限接近。顧客インデックス ' + i + ' で中断。');
      return;
    }

    try {
      processCustomer(customers[i]);
    } catch (e) {
      Logger.log('顧客処理エラー: ' + customers[i].name + ' - ' + e.message);
      // エラーでも次の顧客へ続行
    }
  }

  // 全顧客完了 → 再開位置リセット
  clearResumeIndex(); // config.gs
}
```

### 3.2 gmail.gs — Gmail検索・メール取得・処理済み判定

**責務:** Gmail APIとの全やり取り。検索クエリ構築・メール取得・ラベル管理。

```javascript
/**
 * 指定顧客の新着メール(未処理)を検索して返す。
 * @param {string} customerEmail - 顧客メールアドレス
 * @param {Date|null} afterDate - この日時以降のメールのみ(null=全件)
 * @returns {GmailMessage[]} 未処理メールの配列
 */
function searchNewEmails(customerEmail, afterDate) → GmailMessage[]

/**
 * メールに処理済みラベルを付与する。
 * @param {GmailMessage} message - 対象メッセージ
 */
function markAsProcessed(message) → void

/**
 * 処理済みラベルを取得(なければ作成)。
 * @returns {GmailLabel} 処理済みラベル
 */
function getOrCreateProcessedLabel() → GmailLabel

/**
 * メールの方向(送信/受信)を判定する。
 * @param {GmailMessage} message - メッセージ
 * @returns {string} "送信" | "受信"
 */
function getEmailDirection(message) → string

/**
 * メールの本文をプレーンテキストで取得する。
 * @param {GmailMessage} message - メッセージ
 * @returns {string} 本文テキスト(最大5000文字でトランケート)
 */
function getEmailBody(message) → string
```

**検索クエリ設計:**

```javascript
function searchNewEmails(customerEmail, afterDate) {
  // 送受信両方を検索 + 処理済みラベル除外
  let query = `{from:${customerEmail} to:${customerEmail}}`;
  query += ' -label:gas-mail-manager-processed';

  if (afterDate) {
    const dateStr = Utilities.formatDate(afterDate, 'JST', 'yyyy/MM/dd');
    query += ` after:${dateStr}`;
  }

  const threads = GmailApp.search(query, 0, 100); // 1回100件上限
  const messages = [];
  threads.forEach(thread => {
    thread.getMessages().forEach(msg => {
      messages.push(msg);
    });
  });

  return messages;
}
```

**処理済みラベル設計:**

| 項目 | 値 |
|------|-----|
| ラベル名 | `gas-mail-manager-processed` |
| 目的 | Gmail検索時に除外(-label:で高速フィルタ) |
| 付与タイミング | PDF保存+シート転記の両方が成功した後 |
| 補助確認 | シートのGmailMessageId列でも二重チェック可能 |

**推奨: ラベル方式を主、シートID方式を補助とする理由:**
- ラベル方式はGmail検索で自動除外されるため、シート全行スキャンが不要で高速
- シートのGmailMessageIdは万一のラベル付与漏れ時のフォールバック

### 3.3 pdf.gs — メール→PDF変換・Drive保存

**責務:** GmailメッセージをPDFに変換し、Google Driveの指定フォルダに保存。

```javascript
/**
 * GmailメッセージをPDF Blobに変換する。
 * HTML本文+添付ファイル情報をPDF化。
 * @param {GmailMessage} message - 対象メッセージ
 * @returns {Blob} PDF Blob
 */
function convertEmailToPdf(message) → Blob

/**
 * PDFをDriveの指定フォルダに保存する。
 * @param {Blob} pdfBlob - PDF Blob
 * @param {string} folderId - 保存先DriveフォルダID
 * @param {string} fileName - ファイル名(例: "2026-04-05_件名.pdf")
 * @returns {string} 保存されたファイルのURL
 */
function savePdfToDrive(pdfBlob, folderId, fileName) → string

/**
 * メールからPDFファイル名を生成する。
 * @param {GmailMessage} message - メッセージ
 * @returns {string} ファイル名(例: "2026-04-05_見積書の件.pdf")
 */
function generatePdfFileName(message) → string
```

**PDF変換設計:**

```javascript
function convertEmailToPdf(message) {
  const subject = message.getSubject() || '(件名なし)';
  const from = message.getFrom();
  const to = message.getTo();
  const date = message.getDate();
  const body = message.getBody(); // HTML本文

  // HTML構築: ヘッダー情報 + 本文
  const html = `
    <html><head><meta charset="utf-8">
    <style>
      body { font-family: 'Noto Sans JP', sans-serif; font-size: 12px; }
      .header { background: #f5f5f5; padding: 10px; margin-bottom: 15px; }
      .header p { margin: 3px 0; }
    </style></head><body>
    <div class="header">
      <p><strong>件名:</strong> ${subject}</p>
      <p><strong>From:</strong> ${from}</p>
      <p><strong>To:</strong> ${to}</p>
      <p><strong>日時:</strong> ${date}</p>
    </div>
    <div class="body">${body}</div>
    </body></html>
  `;

  // HTML→PDF変換
  const blob = Utilities.newBlob(html, 'text/html', 'email.html');
  // Note: GASではUtilities直接変換はサポートされないため、
  // Google Docs経由の中間変換パターンを使用（下記実装詳細参照）
  return convertHtmlToPdfViaDoc(blob, subject);
}

// Google Docs中間変換パターン
function convertHtmlToPdfViaDoc(htmlBlob, title) {
  // 一時Docを作成
  const tempDoc = Drive.Files.insert(
    { title: title, mimeType: 'application/vnd.google-apps.document' },
    htmlBlob,
    { convert: true }
  );
  // DocをPDFでエクスポート
  const pdfBlob = DriveApp.getFileById(tempDoc.id)
    .getAs('application/pdf');
  // 一時Doc削除
  Drive.Files.trash(tempDoc.id);
  return pdfBlob;
}
```

**ファイル名規則:** `YYYY-MM-DD_件名(最大30文字).pdf`
- 日付順ソートが可能
- 件名は30文字でトランケート(ファイル名長制限対策)

### 3.4 summary.gs — AI要約生成

**責務:** メール本文からAI要約を生成する。API選択と呼び出し管理。

```javascript
/**
 * メール本文のAI要約を生成する。
 * Vertex AI Gemini APIを使用。
 * @param {string} emailBody - メール本文(プレーンテキスト)
 * @returns {string} 要約テキスト(100文字程度)
 */
function generateSummary(emailBody) → string

/**
 * Vertex AI Gemini APIを呼び出す。
 * @param {string} prompt - プロンプト
 * @returns {string} APIレスポンステキスト
 */
function callGeminiApi(prompt) → string
```

**API選択: UrlFetchApp + Gemini API (REST)**

| 方式 | メリット | デメリット |
|------|---------|-----------|
| **Vertex AI Advanced Service** | GASネイティブ統合・OAuth自動 | GASプロジェクトにGCPリンク必須・設定が複雑 |
| **UrlFetchApp + Gemini API** | APIキーのみで動作・シンプル・GCPリンク不要 | APIキー管理が必要 |
| **UrlFetchApp + OpenAI API** | 高品質要約 | 外部依存・追加コスト |

**推奨: UrlFetchApp + Gemini API (REST)** を採用する。

**理由:**
1. GCPプロジェクトリンクが不要で、セットアップが簡単
2. APIキーはPropertiesServiceで安全に管理可能
3. Gemini APIの無料枠(15 RPM / 100万トークン/日)で十分
4. Vertex AI Advanced ServiceはGAS→GCPリンク設定が煩雑で、初回プロジェクトとしてはオーバースペック
5. 将来的にVertex AIへの移行も容易(エンドポイントURLの変更のみ)

**実装設計:**

```javascript
function generateSummary(emailBody) {
  if (!emailBody || emailBody.trim().length === 0) {
    return '(本文なし)';
  }

  // 本文を3000文字にトランケート(API入力制限とコスト抑制)
  const truncatedBody = emailBody.substring(0, 3000);

  const prompt = `以下のメール本文を日本語で100文字以内に要約してください。
要点のみを簡潔に記載してください。

メール本文:
${truncatedBody}`;

  try {
    return callGeminiApi(prompt);
  } catch (e) {
    Logger.log('AI要約エラー: ' + e.message);
    return '(要約生成失敗)';
  }
}

function callGeminiApi(prompt) {
  const apiKey = getConfig('GEMINI_API_KEY'); // config.gs
  const model = 'gemini-2.0-flash'; // 高速・低コスト
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const payload = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: {
      maxOutputTokens: 200,
      temperature: 0.3 // 要約は低温度で安定させる
    }
  };

  const options = {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  const response = UrlFetchApp.fetch(url, options);
  const json = JSON.parse(response.getContentText());

  if (json.candidates && json.candidates[0]) {
    return json.candidates[0].content.parts[0].text.trim();
  }

  throw new Error('Gemini APIレスポンス不正: ' + response.getContentText());
}
```

**モデル選択: gemini-2.0-flash**
- 要約タスクには十分な性能
- 高速レスポンス(1-2秒)で6分制限内の処理数を最大化
- 無料枠: 15 RPM / 100万トークン/日(メール要約用途では十分)

**レート制限対策:**
- 15 RPM制限: 1顧客あたりの新着メール数が多い場合、`Utilities.sleep(4000)` で4秒間隔を空ける
- エラー時リトライ: 429エラーは指数バックオフ(4秒→8秒→16秒、最大3回)

### 3.5 sheets.gs — スプレッドシート操作

**責務:** スプレッドシートの読み書き。元帳の顧客一覧取得・メール一覧への行追加。

```javascript
/**
 * 元帳シートからactive顧客一覧を取得する。
 * @returns {Object[]} 顧客オブジェクトの配列
 *   [{ name, email, folderId, sheetName, lastCheckDate, rowIndex }]
 */
function getCustomerList() → Object[]

/**
 * メール一覧シートに1行追加する。
 * @param {string} sheetName - シート名
 * @param {Object} rowData - 行データ
 *   { date, direction, from, to, subject, summary, pdfUrl, messageId, processedAt }
 */
function appendEmailRow(sheetName, rowData) → void

/**
 * 元帳の最終チェック日時を更新する。
 * @param {number} rowIndex - 元帳の行番号(1-based)
 * @param {Date} checkDate - チェック日時
 */
function updateLastCheckDate(rowIndex, checkDate) → void

/**
 * 顧客用メール一覧シートを新規作成する（元帳に新顧客追加時）。
 * ヘッダー行を自動設定。
 * @param {string} sheetName - 作成するシート名
 */
function createEmailListSheet(sheetName) → void

/**
 * シート内で指定GmailMessageIdが既に存在するか確認する（二重登録防止）。
 * @param {string} sheetName - シート名
 * @param {string} messageId - GmailMessageId
 * @returns {boolean} true=既に存在
 */
function isMessageAlreadyRecorded(sheetName, messageId) → boolean
```

**実装設計:**

```javascript
function getCustomerList() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('元帳');
  const data = sheet.getDataRange().getValues();
  const customers = [];

  // ヘッダー行スキップ(i=1から)
  for (let i = 1; i < data.length; i++) {
    if (data[i][7] !== 'active') continue; // H列: ステータス

    customers.push({
      name: data[i][0],        // A: 顧客名
      email: data[i][1],       // B: メールアドレス
      folderId: data[i][3],    // D: DriveフォルダID
      sheetName: data[i][5],   // F: メール一覧シート名
      lastCheckDate: data[i][6] ? new Date(data[i][6]) : null, // G: 最終チェック日時
      rowIndex: i + 1          // 1-based行番号(更新用)
    });
  }

  return customers;
}

function appendEmailRow(sheetName, rowData) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);

  if (!sheet) {
    createEmailListSheet(sheetName);
  }

  const row = [
    rowData.date,
    rowData.direction,
    rowData.from,
    rowData.to,
    rowData.subject,
    rowData.summary,
    rowData.pdfUrl,
    rowData.messageId,
    rowData.processedAt
  ];

  sheet.appendRow(row);
}
```

### 3.6 config.gs — 設定値管理

**責務:** PropertiesServiceを使った設定値・状態の永続化。

```javascript
/**
 * 設定値を取得する。
 * @param {string} key - 設定キー
 * @returns {string|null} 設定値
 */
function getConfig(key) → string|null

/**
 * 設定値を保存する。
 * @param {string} key - 設定キー
 * @param {string} value - 設定値
 */
function setConfig(key, value) → void

/**
 * バッチ再開インデックスを取得する(6分制限対策)。
 * @returns {number} 再開する顧客インデックス(0始まり)。なければ0。
 */
function getResumeIndex() → number

/**
 * バッチ再開インデックスを保存する。
 * @param {number} index - 中断した顧客インデックス
 */
function saveResumeIndex(index) → void

/**
 * バッチ再開インデックスをクリアする(全顧客処理完了時)。
 */
function clearResumeIndex() → void

/**
 * 初期設定。スクリプトエディタから手動実行。
 * 必要なPropertiesを対話的に設定する。
 */
function initializeConfig() → void
```

**PropertiesService設計:**

| キー | 値 | 用途 |
|------|-----|------|
| `GEMINI_API_KEY` | AIzaSy... | Gemini API認証 |
| `PROCESSED_LABEL_NAME` | gas-mail-manager-processed | 処理済みラベル名 |
| `RESUME_INDEX` | 0-N | バッチ再開位置(6分制限対策) |
| `TRIGGER_INTERVAL_MINUTES` | 15 | トリガー間隔(分) |
| `MAX_EMAILS_PER_RUN` | 50 | 1回の実行で処理する最大メール数 |
| `SUMMARY_MAX_CHARS` | 100 | 要約の最大文字数 |

**実装設計:**

```javascript
function getConfig(key) {
  return PropertiesService.getScriptProperties().getProperty(key);
}

function setConfig(key, value) {
  PropertiesService.getScriptProperties().setProperty(key, value);
}

function getResumeIndex() {
  const idx = getConfig('RESUME_INDEX');
  return idx ? parseInt(idx, 10) : 0;
}

function saveResumeIndex(index) {
  setConfig('RESUME_INDEX', String(index));
}

function clearResumeIndex() {
  PropertiesService.getScriptProperties().deleteProperty('RESUME_INDEX');
}

function initializeConfig() {
  const props = PropertiesService.getScriptProperties();
  // デフォルト値設定(既存値は上書きしない)
  const defaults = {
    'PROCESSED_LABEL_NAME': 'gas-mail-manager-processed',
    'TRIGGER_INTERVAL_MINUTES': '15',
    'MAX_EMAILS_PER_RUN': '50',
    'SUMMARY_MAX_CHARS': '100'
  };

  Object.keys(defaults).forEach(key => {
    if (!props.getProperty(key)) {
      props.setProperty(key, defaults[key]);
    }
  });

  Logger.log('設定初期化完了。GEMINI_API_KEYは手動設定してください。');
  Logger.log('設定方法: ファイル > プロジェクトのプロパティ > スクリプトのプロパティ');
}
```

---

## 4. API・スコープ設計

### 4.1 必要なOAuthスコープ

appsscript.json に定義:

```json
{
  "timeZone": "Asia/Tokyo",
  "dependencies": {
    "enabledAdvancedServices": [
      {
        "userSymbol": "Drive",
        "version": "v2",
        "serviceId": "drive"
      }
    ]
  },
  "oauthScopes": [
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.labels",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/spreadsheets.currentonly",
    "https://www.googleapis.com/auth/script.external_request"
  ],
  "exceptionLogging": "STACKDRIVER"
}
```

| スコープ | 用途 | 理由 |
|----------|------|------|
| `gmail.modify` | メール検索+ラベル付与 | readonlyではラベル付与不可 |
| `gmail.labels` | ラベル作成・管理 | 処理済みラベルの作成 |
| `drive` | PDF保存・一時Doc作成削除 | DriveApp + Drive Advanced Service |
| `spreadsheets.currentonly` | バインドされたSpreadsheet操作 | 元帳・メール一覧シートの読み書き |
| `script.external_request` | UrlFetchApp(Gemini API呼出し) | 外部API通信 |

**スコープ最小化の設計判断:**
- `gmail.modify`は`gmail.readonly`より広いが、ラベル付与に必要
- `spreadsheets`ではなく`spreadsheets.currentonly`でバインド先のみに制限
- `drive.file`ではなく`drive`を使用: 一時Doc作成がドライブ全体へのアクセスを要求するため

### 4.2 AI API認証方式

| 項目 | 値 |
|------|-----|
| API | Gemini API (REST) |
| 認証 | APIキー(PropertiesServiceに保存) |
| エンドポイント | `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent` |
| レート制限 | 15 RPM (無料枠) |
| コスト | 無料枠内(100万トークン/日) |

### 4.3 Drive Advanced Service

PDF変換でDrive API v2を使用(HTML→Google Docs変換に必要)。
GAS側で「Advanced Services > Drive API v2」を有効化すること。

---

## 5. GAS 6分制限対策

### 5.1 設計方針

GASのスクリプト実行時間上限は6分/回。顧客数×メール数が増加すると超過する可能性がある。
**PropertiesServiceで進捗を保存し、次回トリガー実行時に続行する方式**を採用。

### 5.2 バッチ処理設計

```
┌─────────────────────────────────────────┐
│ processAllCustomers() — 実行1回目        │
│                                          │
│  顧客A: メール10件処理 ✅ (2分)          │
│  顧客B: メール15件処理 ✅ (3分)          │
│  顧客C: 開始前に5分経過検知 → 中断       │
│         RESUME_INDEX = 2 保存            │
└─────────────────────────────────────────┘
           │ 15分後、次のトリガー
           ▼
┌─────────────────────────────────────────┐
│ processAllCustomers() — 実行2回目        │
│                                          │
│  RESUME_INDEX = 2 読込                   │
│  顧客C: メール5件処理 ✅ (1分)           │
│  顧客D: メール3件処理 ✅ (1分)           │
│  全顧客完了 → RESUME_INDEX クリア        │
└─────────────────────────────────────────┘
```

### 5.3 タイムアウト検知パターン

```javascript
const SAFETY_MARGIN_MS = 60 * 1000; // 1分の安全マージン
const MAX_EXECUTION_MS = 6 * 60 * 1000; // 6分

function isApproachingTimeLimit(startTime, safetyMarginMs) {
  const elapsed = Date.now() - startTime;
  return elapsed >= (MAX_EXECUTION_MS - (safetyMarginMs || SAFETY_MARGIN_MS));
}
```

### 5.4 メール単位の中断対応

顧客内のメール処理中に6分制限に到達した場合:
- 処理済みメールにはラベルが付与済み → 次回実行時に自動スキップ
- RESUME_INDEXはメール単位ではなく顧客単位 → シンプルに保つ
- 理由: ラベル方式により、同一顧客の再処理でもラベル付き(処理済み)メールは検索から除外される

---

## 6. 処理済みメール判定設計

### 6.1 方式比較

| 方式 | メリット | デメリット | 判定 |
|------|---------|-----------|------|
| **A: Gmailラベル** | 検索時自動除外(高速)・Gmail UIで可視 | Gmail側を変更する | **主方式** |
| **B: シートID照合** | Gmail非変更・完全な記録 | 毎回全行スキャン(低速) | **補助方式** |
| **C: PropertiesService日時** | 最もシンプル | 処理失敗時にメール漏れリスク | 不採用 |

### 6.2 推奨: ラベル方式(主) + シートID方式(補助)

**主方式(ラベル):**
1. Gmail検索クエリに `-label:gas-mail-manager-processed` を含める
2. 処理完了後に `gas-mail-manager-processed` ラベルを付与
3. 結果: 次回検索では自動的に除外される

**補助方式(シートID):**
1. シートにGmailMessageIdを記録
2. ラベル付与前にシート確認は不要(ラベルが一次フィルタ)
3. 用途: 手動でのデータ参照・デバッグ・ラベル事故時の復旧

**ラベル付与タイミング:**
```
メール取得 → PDF変換 → Drive保存 → AI要約 → シート転記 → ラベル付与
```
- ラベルは最後に付与する
- 中間で失敗した場合、ラベルなし → 次回再処理される(安全側)
- PDF/シートの二重登録はGmailMessageIdで検出可能

---

## 7. 時間トリガー設計

### 7.1 推奨間隔: 15分

| 間隔 | メリット | デメリット |
|------|---------|-----------|
| 5分 | ほぼリアルタイム | トリガー日次累計上限(6h)を消費しやすい |
| **15分** | バランス良好。1日96回=96分で6h上限の27% | 最大15分の遅延 |
| 60分 | 累計消費最小 | 1時間の遅延は業務に支障 |

**推奨理由:**
- 15分間隔 × 6分実行 = 1日最大96分の累計実行時間
- Workspace上限(6時間=360分)の27%で余裕あり
- 一般的なメール対応の緊急度を考えると15分遅延は許容範囲

### 7.2 設定手順

```javascript
function setupTrigger() {
  // 既存トリガー削除
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => {
    if (trigger.getHandlerFunction() === 'processAllCustomers') {
      ScriptApp.deleteTrigger(trigger);
    }
  });

  // 15分間隔トリガー作成
  ScriptApp.newTrigger('processAllCustomers')
    .timeBased()
    .everyMinutes(15)
    .create();

  Logger.log('15分間隔トリガーを設定しました。');
}
```

### 7.3 手動テスト

```
1. スクリプトエディタで initializeConfig() を実行 → 初期設定
2. GEMINI_API_KEY をスクリプトプロパティに手動設定
3. processAllCustomers() を手動実行 → 動作確認
4. setupTrigger() を実行 → 自動実行開始
```

---

## 8. 実装フェーズ引き継ぎ

### 8.1 ファイル構成

```
gas-mail-manager/
├── src/
│   ├── main.gs          # エントリポイント + オーケストレーション
│   ├── gmail.gs         # Gmail検索・取得・ラベル管理
│   ├── pdf.gs           # PDF変換・Drive保存
│   ├── summary.gs       # AI要約生成(Gemini API)
│   ├── sheets.gs        # スプレッドシート操作
│   ├── config.gs        # 設定値管理(PropertiesService)
│   └── appsscript.json  # プロジェクト設定・スコープ定義
├── .clasp.json          # claspプロジェクト設定(git除外)
├── .claspignore         # push除外パターン
├── .gitignore           # .clasprc.json, .clasp.json等除外
└── README.md            # セットアップ手順・概要
```

### 8.2 実装順序(推奨)

依存関係を考慮した実装順序:

```
Phase 1: 基盤
  ├─ config.gs     (他モジュールが依存)
  ├─ sheets.gs     (データ構造の確認)
  └─ appsscript.json (スコープ定義)

Phase 2: コア機能
  ├─ gmail.gs      (メール検索・取得)
  └─ pdf.gs        (PDF変換)

Phase 3: AI機能
  └─ summary.gs    (Gemini API連携)

Phase 4: 統合
  └─ main.gs       (オーケストレーション・6分制限・トリガー)
```

### 8.3 各ファイルの実装内容詳細

#### config.gs (Phase 1)
- `getConfig(key)` / `setConfig(key, value)` — PropertiesService ラッパー
- `getResumeIndex()` / `saveResumeIndex(index)` / `clearResumeIndex()` — 6分制限用
- `initializeConfig()` — 初期設定(デフォルト値投入)
- 実装量: 約50行

#### sheets.gs (Phase 1)
- `getCustomerList()` — 元帳読込。ヘッダースキップ+active顧客フィルタ
- `appendEmailRow(sheetName, rowData)` — メール一覧追加。シートなければ自動作成
- `updateLastCheckDate(rowIndex, checkDate)` — 元帳の最終チェック日時更新
- `createEmailListSheet(sheetName)` — ヘッダー付き新シート作成
- `isMessageAlreadyRecorded(sheetName, messageId)` — GmailMessageId二重チェック
- 実装量: 約80行

#### gmail.gs (Phase 2)
- `searchNewEmails(customerEmail, afterDate)` — Gmail検索。ラベル除外クエリ構築
- `markAsProcessed(message)` — 処理済みラベル付与
- `getOrCreateProcessedLabel()` — ラベル取得/作成
- `getEmailDirection(message)` — 送信/受信判定(自分のアドレスとfrom比較)
- `getEmailBody(message)` — プレーンテキスト取得(5000文字上限)
- 実装量: 約80行

#### pdf.gs (Phase 2)
- `convertEmailToPdf(message)` — HTML構築+Docs中間変換
- `savePdfToDrive(pdfBlob, folderId, fileName)` — Drive保存+URL返却
- `generatePdfFileName(message)` — 日付+件名のファイル名生成
- `convertHtmlToPdfViaDoc(htmlBlob, title)` — Google Docs経由のHTML→PDF変換
- 実装量: 約70行
- **注意:** Drive Advanced Service(v2)の有効化が必要

#### summary.gs (Phase 3)
- `generateSummary(emailBody)` — プロンプト構築+API呼出し+エラーハンドリング
- `callGeminiApi(prompt)` — UrlFetchApp経由のREST API呼出し
- 実装量: 約60行
- **注意:** GEMINI_API_KEY のPropertiesService設定が必要

#### main.gs (Phase 4)
- `processAllCustomers()` — メインループ。顧客一覧→メール処理→6分制限管理
- `processCustomer(customer)` — 単一顧客処理。検索→PDF→要約→転記→ラベル
- `isApproachingTimeLimit(startTime, safetyMarginMs)` — 経過時間チェック
- `setupTrigger()` / `removeTrigger()` — トリガー管理
- 実装量: 約80行

### 8.4 テスト計画

| テスト | 内容 | 方法 |
|--------|------|------|
| config単体 | PropertiesServiceの読み書き | 手動実行+Logger確認 |
| sheets単体 | 元帳読込・行追加 | テスト用シートで手動実行 |
| gmail単体 | メール検索・ラベル付与 | テスト用メールアドレスで検証 |
| pdf単体 | PDF変換・Drive保存 | 1通のメールで手動実行 |
| summary単体 | AI要約生成 | テスト文章で手動実行 |
| 統合 | processAllCustomers() | テスト顧客(1名)で全フロー実行 |
| 6分制限 | バッチ中断・再開 | 顧客数を増やしてシミュレート |

### 8.5 足軽タスク分割案

```
足軽A: config.gs + sheets.gs + appsscript.json (Phase 1)
足軽B: gmail.gs + pdf.gs (Phase 2)
足軽C: summary.gs (Phase 3)
足軽D: main.gs + 統合テスト (Phase 4, Phase 1-3完了後)
```

- Phase 1-3は並列実行可能(RACE-001: 各足軽が異なるファイルを担当)
- Phase 4はPhase 1-3完了後にシリアル実行

---

## 9. 自動運用方針 (cmd_588, 2026-04-26)

### 9.1 運用方針

| 機能 | 方式 | 詳細 |
|------|------|------|
| 業務処理 (日常) | Time-driven trigger | `triggerProcessAllCustomers` 毎日 9:00 自動実行 (案 D) |
| RAPT 監視 | cron 30 分毎 | `scripts/clasp_rapt_monitor.sh` で 6h warn / 7h critical ntfy push (案 F) |
| backfill | 手動継続 | 過去遡及処理 (寺地様 93 件等) は意図せぬ再実行防止のため手動 |

### 9.2 RAPT 期限制御

- `~/.clasprc.json` の `tokens.default.expiry_date` (epoch ms) から経過時間を算出。
- 6h 経過 → ntfy WARN 通知 (次回 clasp run 前に再認証推奨)。
- 7h 経過 → ntfy CRITICAL 通知 (復旧手順: `shogun-gas-clasp-rapt-reauth-fallback` スキル)。

### 9.3 関連ファイル

- `output/cmd_588_operation_guide.md` — 殿向け運用ガイド (全手順)
- `output/cmd_588_trigger_setup.md` — Time-driven trigger 詳細手順
- `scripts/clasp_rapt_monitor.sh` — RAPT 監視スクリプト

---

## 付録: 設計判断サマリー

| 判断項目 | 選択 | 理由 |
|----------|------|------|
| AI API | Gemini API (REST/UrlFetchApp) | GCPリンク不要・セットアップ簡単・無料枠十分 |
| AIモデル | gemini-2.0-flash | 要約タスクに十分・高速・低コスト |
| 処理済み検出 | ラベル方式(主)+シートID(補) | 検索時自動除外で高速。シートIDは補助 |
| PDF変換 | Google Docs中間変換 | GAS標準でHTML→PDF直接変換不可のため |
| 6分制限 | PropertiesServiceで進捗保存 | シンプルで確実。ラベル方式と相性良好 |
| トリガー間隔 | 15分 | 日次累計の27%で余裕。15分遅延は許容範囲 |
| スプレッドシート構成 | 同一Spreadsheet内の複数シート | 管理一元化。顧客数が100超なら分割検討 |
| シート行追加 | 末尾追加(appendRow) | GAS最適。閲覧時はSpreadsheetフィルタで対応 |
