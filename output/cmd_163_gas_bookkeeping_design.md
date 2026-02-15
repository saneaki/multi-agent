# 複式簿記スマホ入力システム 設計書

**文書ID**: cmd_163
**作成日**: 2026-02-15
**バージョン**: 1.0
**対象読者**: システム利用者（非エンジニア向け）

---

## 目次

1. [全体構成図](#1-全体構成図)
2. [科目マスタSheetの設計](#2-科目マスタsheetの設計)
3. [入力バッファSheetの列構成](#3-入力バッファsheetの列構成)
4. [GAS Web AppのUI設計](#4-gas-web-appのui設計)
5. [GASのコード構成](#5-gasのコード構成)
6. [バッファから本帳簿への転記方式](#6-バッファから本帳簿への転記方式)
7. [エラーハンドリング](#7-エラーハンドリング)

---

## 1. 全体構成図

### システムの流れ

```
┌─────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌────────────┐
│ スマホ   │ →  │ GAS Web App     │ →  │ 入力バッファSheet │ →  │ 本帳簿     │
│（ブラウザ）│    │（入力画面を表示）│    │（仕訳データ蓄積）│    │（既存Excel）│
└─────────┘    └─────────────────┘    └──────────────────┘    └────────────┘
                       ↓ 参照
               ┌─────────────────┐
               │ 科目マスタSheet │
               │（コード対応表） │
               └─────────────────┘
```

### 仕組みの説明

このシステムは3つの部品で構成されます。

1. **GAS Web App（入力画面）**
   - スマホのブラウザからアクセスする入力画面です
   - GAS = Google Apps Script の略で、Googleが提供するプログラム実行環境です
   - Web App = インターネット上で動くアプリケーションのことです

2. **Google Sheets（データ保存場所）**
   - 1つのスプレッドシートに2つのシートを作ります
   - **科目マスタ**: 「コード → 勘定科目名」の対応表
   - **入力バッファ**: スマホから入力された仕訳データの一時保管場所

3. **本帳簿（既存のExcel）**
   - 現在使用中のExcelファイルはそのまま使い続けます
   - 入力バッファに溜まったデータを定期的に転記します

### 使い方の流れ

```
① スマホで入力画面を開く（ブックマークまたはホーム画面のアイコン）
② 科目コード・日付・金額・摘要の4項目を入力して「登録」ボタンを押す
③ 入力バッファSheetに1行追加される
④ 必要なタイミングで入力バッファの内容を本帳簿Excelに転記する
```

---

## 2. 科目マスタSheetの設計

### 科目マスタとは

「科目コード」を入力するだけで、借方（お金の使い道）と貸方（お金の出どころ）が自動的に決まる仕組みです。

**例**: コード `101` を入力 → 借方「旅費交通費」、貸方「現金」が自動入力されます。

つまり「電車代を現金で払った」という仕訳が、`101` の3桁を入力するだけで完成します。

### シート構成

シート名: `科目マスタ`

| 列 | 項目名 | 説明 | 入力例 |
|----|--------|------|--------|
| A | コード | 3桁の数字（科目コード） | 101 |
| B | 取引名 | この仕訳パターンの名前 | 電車・バス代 |
| C | 借方科目 | お金の使い道の勘定科目 | 旅費交通費 |
| D | 貸方科目 | お金の出どころの勘定科目 | 現金 |
| E | 税区分 | 消費税の区分（空欄可） | 課税仕入10% |
| F | メモ | 補足説明（空欄可） | 通勤以外の交通費 |

### 科目コードの登録例

日常的によく使う仕訳パターンをあらかじめ登録しておきます。

| コード | 取引名 | 借方科目 | 貸方科目 | 税区分 |
|--------|--------|----------|----------|--------|
| 101 | 電車・バス代 | 旅費交通費 | 現金 | 課税仕入10% |
| 102 | タクシー代 | 旅費交通費 | 現金 | 課税仕入10% |
| 103 | ガソリン代 | 旅費交通費 | 現金 | 課税仕入10% |
| 201 | 事務用品（現金） | 消耗品費 | 現金 | 課税仕入10% |
| 202 | 事務用品（銀行） | 消耗品費 | 普通預金 | 課税仕入10% |
| 301 | 打合せ飲食 | 会議費 | 現金 | 課税仕入10% |
| 302 | 接待飲食 | 交際費 | 現金 | 課税仕入10% |
| 401 | 書籍・資料 | 新聞図書費 | 現金 | 課税仕入10% |
| 501 | 携帯電話代 | 通信費 | 普通預金 | 課税仕入10% |
| 502 | インターネット代 | 通信費 | 普通預金 | 課税仕入10% |
| 601 | 売上（現金） | 現金 | 売上高 | 課税売上10% |
| 602 | 売上（振込） | 普通預金 | 売上高 | 課税売上10% |
| 701 | コピー・印刷代 | 事務費 | 現金 | 課税仕入10% |
| 801 | 振込手数料 | 支払手数料 | 普通預金 | 非課税 |
| 901 | 切手・はがき | 通信費 | 現金 | 非課税 |

### コード体系の考え方

- **1xx**: 交通関連（旅費交通費）
- **2xx**: 物品購入（消耗品費）
- **3xx**: 飲食関連（会議費・交際費）
- **4xx**: 書籍・情報関連
- **5xx**: 通信関連
- **6xx**: 売上関連
- **7xx**: 事務関連
- **8xx**: 手数料関連
- **9xx**: その他

新しい仕訳パターンが必要になったら、科目マスタSheetに1行追加するだけです。プログラムの変更は不要です。

---

## 3. 入力バッファSheetの列構成

### シート構成

シート名: `入力バッファ`

| 列 | 項目名 | 説明 | 入力例 |
|----|--------|------|--------|
| A | ID | 自動採番（登録順の通し番号） | 1 |
| B | 登録日時 | データが登録された日時（自動） | 2026-02-15 14:30:00 |
| C | 仕訳日付 | 取引が発生した日付（入力値） | 2026-02-15 |
| D | 科目コード | 入力された科目コード | 101 |
| E | 取引名 | 科目マスタから自動取得 | 電車・バス代 |
| F | 借方科目 | 科目マスタから自動取得 | 旅費交通費 |
| G | 貸方科目 | 科目マスタから自動取得 | 現金 |
| H | 金額 | 入力された金額 | 1200 |
| I | 税区分 | 科目マスタから自動取得 | 課税仕入10% |
| J | 摘要 | 入力された摘要メモ | 渋谷→新宿 |
| K | 転記済み | 本帳簿への転記が完了したか | FALSE |

### 列の役割

- **A〜B列（自動）**: システムが自動的に埋めます。手を触れる必要はありません
- **C〜D, H, J列（入力値）**: スマホから入力した4項目がそのまま入ります
- **E〜G, I列（自動展開）**: 科目コードから科目マスタを参照して自動的に埋まります
- **K列（管理用）**: 本帳簿に転記したかどうかの印。転記後に `TRUE` に変更します

---

## 4. GAS Web AppのUI設計

### 設計方針

- **1画面完結**: スクロールなしで全項目が見える
- **スマホ最適化**: 指でタップしやすい大きなボタン・入力欄
- **入力は4項目のみ**: 科目コード、日付、金額、摘要

### 画面レイアウト

```
┌──────────────────────────────┐
│    📒 仕訳入力               │
│──────────────────────────────│
│                              │
│  科目コード                  │
│  ┌────────────┐ ┌─────────┐ │
│  │ 101        │ │ 選択 ▼  │ │
│  └────────────┘ └─────────┘ │
│  → 旅費交通費 / 現金         │
│                              │
│  日付                        │
│  ┌──────────────────────┐   │
│  │ 2026-02-15     📅    │   │
│  └──────────────────────┘   │
│                              │
│  金額                        │
│  ┌──────────────────────┐   │
│  │ ¥                    │   │
│  └──────────────────────┘   │
│                              │
│  摘要                        │
│  ┌──────────────────────┐   │
│  │                      │   │
│  └──────────────────────┘   │
│                              │
│  ┌──────────────────────┐   │
│  │      ✅ 登録する      │   │
│  └──────────────────────┘   │
│                              │
│  最近の入力:                 │
│  02/15 101 ¥1,200 渋谷→新宿 │
│  02/15 301 ¥3,500 A社打合せ  │
│  02/14 201 ¥980 コピー用紙   │
│                              │
└──────────────────────────────┘
```

### UI仕様の詳細

**科目コード入力**
- 数字を直接入力（3桁）するか、「選択」ボタンでリストから選べます
- コードを入力すると、下に「借方科目 / 貸方科目」がリアルタイム表示されます
- 存在しないコードを入れると赤字で「該当する科目コードがありません」と表示

**日付入力**
- 初期値は「今日の日付」が自動セットされます
- カレンダーアイコンをタップすると日付選択画面が開きます
- 未来の日付も入力可能（前受金の入力等に対応）

**金額入力**
- 数字専用キーボードが自動で開きます
- 3桁ごとにカンマ表示（例: 12,500）
- 小数点は入力不可（円単位のみ）

**摘要入力**
- 自由記述欄です（取引先名や内容メモ）
- 最大100文字まで
- 空欄でも登録可能

**登録ボタン**
- タップすると入力内容を確認するダイアログが表示されます
- 「OK」で登録完了 → 成功メッセージ表示、入力欄クリア
- 登録後、画面下部の「最近の入力」リストが更新されます

**最近の入力一覧**
- 直近5件の登録データを表示
- 直前の入力を目視確認でき、誤入力に気づきやすい

### HTML/CSSの設計

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <!-- スマホの画面幅に合わせて表示する設定 -->
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>仕訳入力</title>
  <style>
    /* ===== 基本設定 ===== */
    * {
      box-sizing: border-box;  /* 枠線を含めたサイズ計算 */
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      background: #f5f5f5;     /* 薄いグレーの背景 */
      padding: 16px;
      max-width: 480px;        /* スマホ画面の最大幅 */
      margin: 0 auto;          /* 中央寄せ */
    }

    /* ===== ヘッダー ===== */
    .header {
      text-align: center;
      font-size: 20px;
      font-weight: bold;
      padding: 12px 0;
      color: #333;
    }

    /* ===== 入力グループ（各項目の枠） ===== */
    .form-group {
      margin-bottom: 16px;
    }
    .form-group label {
      display: block;
      font-size: 14px;
      font-weight: bold;
      color: #555;
      margin-bottom: 4px;
    }
    .form-group input,
    .form-group select,
    .form-group textarea {
      width: 100%;
      padding: 12px;           /* 指でタップしやすい余白 */
      font-size: 16px;         /* スマホで拡大されないサイズ */
      border: 2px solid #ddd;
      border-radius: 8px;      /* 角丸 */
      background: #fff;
    }
    .form-group input:focus,
    .form-group textarea:focus {
      border-color: #4285f4;   /* フォーカス時にGoogleブルー */
      outline: none;
    }

    /* ===== 科目コード入力エリア ===== */
    .code-row {
      display: flex;           /* 横並び配置 */
      gap: 8px;
    }
    .code-row input {
      flex: 1;                 /* 入力欄を広く */
    }
    .code-row select {
      width: 100px;            /* 選択ボタンは固定幅 */
    }
    .code-preview {
      font-size: 13px;
      color: #4285f4;          /* 青文字で科目名表示 */
      margin-top: 4px;
      min-height: 20px;        /* 空欄時もスペース確保 */
    }
    .code-preview.error {
      color: #d93025;          /* エラー時は赤文字 */
    }

    /* ===== 登録ボタン ===== */
    .submit-btn {
      width: 100%;
      padding: 14px;
      font-size: 18px;
      font-weight: bold;
      background: #4285f4;     /* Googleブルー */
      color: #fff;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      margin-top: 8px;
    }
    .submit-btn:active {
      background: #3367d6;     /* 押した時に少し暗く */
    }
    .submit-btn:disabled {
      background: #ccc;        /* 無効時はグレー */
    }

    /* ===== メッセージ表示 ===== */
    .message {
      text-align: center;
      padding: 10px;
      border-radius: 8px;
      margin-top: 12px;
      display: none;           /* 初期状態は非表示 */
    }
    .message.success {
      background: #e6f4ea;
      color: #137333;
    }
    .message.error {
      background: #fce8e6;
      color: #d93025;
    }

    /* ===== 最近の入力一覧 ===== */
    .recent {
      margin-top: 20px;
      padding-top: 16px;
      border-top: 1px solid #ddd;
    }
    .recent h3 {
      font-size: 14px;
      color: #555;
      margin-bottom: 8px;
    }
    .recent-item {
      font-size: 13px;
      padding: 6px 0;
      color: #333;
      border-bottom: 1px solid #eee;
    }
  </style>
</head>
<body>

  <div class="header">📒 仕訳入力</div>

  <!-- 科目コード -->
  <div class="form-group">
    <label>科目コード</label>
    <div class="code-row">
      <input type="tel" id="code" placeholder="例: 101"
             maxlength="3" inputmode="numeric">
      <select id="codeSelect" onchange="onCodeSelect()">
        <option value="">選択▼</option>
        <!-- GASが科目マスタから選択肢を自動生成 -->
      </select>
    </div>
    <div class="code-preview" id="codePreview"></div>
  </div>

  <!-- 日付 -->
  <div class="form-group">
    <label>日付</label>
    <input type="date" id="entryDate">
  </div>

  <!-- 金額 -->
  <div class="form-group">
    <label>金額</label>
    <input type="tel" id="amount" placeholder="例: 1200"
           inputmode="numeric">
  </div>

  <!-- 摘要 -->
  <div class="form-group">
    <label>摘要</label>
    <input type="text" id="description" placeholder="例: 渋谷→新宿"
           maxlength="100">
  </div>

  <!-- 登録ボタン -->
  <button class="submit-btn" id="submitBtn" onclick="submitEntry()">
    ✅ 登録する
  </button>

  <!-- メッセージ -->
  <div class="message" id="message"></div>

  <!-- 最近の入力 -->
  <div class="recent" id="recentArea">
    <h3>最近の入力:</h3>
    <div id="recentList"></div>
  </div>

  <script>
    // ===== 初期化処理 =====

    // 日付の初期値を「今日」にセット
    document.getElementById('entryDate').value =
      new Date().toISOString().split('T')[0];

    // 科目マスタをGASから読み込み、選択リストを作成
    google.script.run
      .withSuccessHandler(function(masterData) {
        // masterData = [[コード, 取引名, 借方, 貸方, 税区分], ...]
        window.masterMap = {};  // コード→情報の対応表を保持
        var select = document.getElementById('codeSelect');
        masterData.forEach(function(row) {
          window.masterMap[row[0]] = {
            name: row[1], debit: row[2],
            credit: row[3], tax: row[4]
          };
          var opt = document.createElement('option');
          opt.value = row[0];
          opt.text = row[0] + ': ' + row[1];
          select.appendChild(opt);
        });
      })
      .getMasterData();  // GAS側の関数を呼び出し

    // 最近の入力を読み込み
    loadRecent();

    // ===== 科目コード入力時の処理 =====

    // キー入力のたびに科目名を表示
    document.getElementById('code').addEventListener('input', function() {
      showCodePreview(this.value);
    });

    // 選択リストから選んだ時の処理
    function onCodeSelect() {
      var code = document.getElementById('codeSelect').value;
      document.getElementById('code').value = code;
      showCodePreview(code);
    }

    // 科目コードに対応する科目名を表示する
    function showCodePreview(code) {
      var preview = document.getElementById('codePreview');
      if (!code) {
        preview.textContent = '';
        preview.className = 'code-preview';
        return;
      }
      var info = window.masterMap[code];
      if (info) {
        // 見つかった → 青文字で科目名を表示
        preview.textContent = '→ ' + info.debit + ' / ' + info.credit;
        preview.className = 'code-preview';
      } else {
        // 見つからない → 赤文字でエラー表示
        preview.textContent = '該当する科目コードがありません';
        preview.className = 'code-preview error';
      }
    }

    // ===== 登録処理 =====

    function submitEntry() {
      // 入力値を取得
      var code = document.getElementById('code').value;
      var date = document.getElementById('entryDate').value;
      var amount = document.getElementById('amount').value;
      var desc = document.getElementById('description').value;

      // 入力チェック
      if (!code || !window.masterMap[code]) {
        showMessage('正しい科目コードを入力してください', 'error');
        return;
      }
      if (!date) {
        showMessage('日付を入力してください', 'error');
        return;
      }
      if (!amount || isNaN(amount) || Number(amount) <= 0) {
        showMessage('正しい金額を入力してください', 'error');
        return;
      }

      // 確認ダイアログ
      var info = window.masterMap[code];
      var msg = date + '\n'
        + info.debit + ' / ' + info.credit + '\n'
        + '¥' + Number(amount).toLocaleString() + '\n'
        + (desc || '（摘要なし）');
      if (!confirm('以下の内容で登録しますか？\n\n' + msg)) {
        return;  // キャンセルされた
      }

      // ボタンを無効化（二重送信防止）
      var btn = document.getElementById('submitBtn');
      btn.disabled = true;
      btn.textContent = '登録中...';

      // GAS側に送信
      google.script.run
        .withSuccessHandler(function() {
          showMessage('登録しました ✅', 'success');
          // 入力欄をクリア（日付は今日のまま）
          document.getElementById('code').value = '';
          document.getElementById('codeSelect').value = '';
          document.getElementById('amount').value = '';
          document.getElementById('description').value = '';
          document.getElementById('codePreview').textContent = '';
          btn.disabled = false;
          btn.textContent = '✅ 登録する';
          loadRecent();  // 一覧を更新
        })
        .withFailureHandler(function(err) {
          showMessage('登録に失敗しました: ' + err.message, 'error');
          btn.disabled = false;
          btn.textContent = '✅ 登録する';
        })
        .postEntry(code, date, Number(amount), desc);
    }

    // ===== 最近の入力を読み込む =====

    function loadRecent() {
      google.script.run
        .withSuccessHandler(function(entries) {
          var list = document.getElementById('recentList');
          list.innerHTML = '';
          if (!entries || entries.length === 0) {
            list.innerHTML = '<div class="recent-item">まだ入力がありません</div>';
            return;
          }
          entries.forEach(function(e) {
            var div = document.createElement('div');
            div.className = 'recent-item';
            div.textContent = e.date + ' ' + e.code
              + ' ¥' + Number(e.amount).toLocaleString()
              + ' ' + (e.desc || '');
            list.appendChild(div);
          });
        })
        .getRecentEntries();
    }

    // ===== メッセージ表示 =====

    function showMessage(text, type) {
      var el = document.getElementById('message');
      el.textContent = text;
      el.className = 'message ' + type;
      el.style.display = 'block';
      // 3秒後に自動で消す
      setTimeout(function() {
        el.style.display = 'none';
      }, 3000);
    }
  </script>

</body>
</html>
```

---

## 5. GASのコード構成

### ファイル構成

GASプロジェクトには以下の2ファイルを作成します。

| ファイル名 | 役割 |
|-----------|------|
| コード.gs | プログラム本体（データの読み書き処理） |
| index.html | 入力画面（前章のHTML/CSS/JavaScript） |

### コード.gs（プログラム本体）

```javascript
// ============================================================
// 設定値（ここを自分のスプレッドシートに合わせて変更する）
// ============================================================

// スプレッドシートのID
// （スプレッドシートのURLの /d/ と /edit の間の文字列）
var SPREADSHEET_ID = 'ここにスプレッドシートのIDを貼り付ける';

// シート名
var MASTER_SHEET_NAME = '科目マスタ';
var BUFFER_SHEET_NAME = '入力バッファ';

// ============================================================
// doGet — ブラウザでアクセスした時に入力画面を表示する
// ============================================================

function doGet() {
  // index.html の内容をブラウザに返す
  var html = HtmlService.createHtmlOutputFromFile('index')
    .setTitle('仕訳入力')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);

  // スマホの画面幅に合わせる設定
  html.addMetaTag('viewport', 'width=device-width, initial-scale=1');

  return html;
}

// ============================================================
// getMasterData — 科目マスタの全データを取得する
// （入力画面の選択リスト作成に使用）
// ============================================================

function getMasterData() {
  // スプレッドシートを開く
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(MASTER_SHEET_NAME);

  // 最終行を取得（データがある行数）
  var lastRow = sheet.getLastRow();

  // データがない場合は空配列を返す
  if (lastRow < 2) return [];

  // 2行目から最後の行まで（1行目はヘッダー）、A〜E列を取得
  // [[コード, 取引名, 借方, 貸方, 税区分], ...]
  var data = sheet.getRange(2, 1, lastRow - 1, 5).getValues();

  // コードを文字列に変換して返す（数値のままだと比較に問題が出る）
  return data.map(function(row) {
    return [String(row[0]), row[1], row[2], row[3], row[4]];
  });
}

// ============================================================
// postEntry — 仕訳データを入力バッファSheetに書き込む
// （入力画面の「登録」ボタンから呼ばれる）
// ============================================================

function postEntry(code, date, amount, description) {
  // スプレッドシートを開く
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);

  // --- 科目マスタからコードを検索 ---
  var masterSheet = ss.getSheetByName(MASTER_SHEET_NAME);
  var masterData = masterSheet.getRange(
    2, 1, masterSheet.getLastRow() - 1, 5
  ).getValues();

  // コードに一致する行を探す
  var matched = null;
  for (var i = 0; i < masterData.length; i++) {
    if (String(masterData[i][0]) === String(code)) {
      matched = masterData[i];
      break;
    }
  }

  // 見つからない場合はエラー
  if (!matched) {
    throw new Error('科目コード ' + code + ' は科目マスタに存在しません');
  }

  // --- 入力バッファSheetに書き込む ---
  var bufferSheet = ss.getSheetByName(BUFFER_SHEET_NAME);
  var lastRow = bufferSheet.getLastRow();
  var newId = lastRow;  // ID = 行番号ベースの通し番号

  // 1行追加: [ID, 登録日時, 仕訳日付, コード, 取引名, 借方, 貸方, 金額, 税区分, 摘要, 転記済み]
  bufferSheet.appendRow([
    newId,                              // A: ID
    new Date(),                         // B: 登録日時（現在時刻）
    new Date(date),                     // C: 仕訳日付
    code,                               // D: 科目コード
    matched[1],                         // E: 取引名（マスタから）
    matched[2],                         // F: 借方科目（マスタから）
    matched[3],                         // G: 貸方科目（マスタから）
    amount,                             // H: 金額
    matched[4],                         // I: 税区分（マスタから）
    description || '',                  // J: 摘要
    false                               // K: 転記済み（初期値: FALSE）
  ]);
}

// ============================================================
// getRecentEntries — 最近5件の入力データを取得する
// （入力画面の「最近の入力」表示に使用）
// ============================================================

function getRecentEntries() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(BUFFER_SHEET_NAME);
  var lastRow = sheet.getLastRow();

  // データがない場合は空配列を返す
  if (lastRow < 2) return [];

  // 最新5件を取得（データが5件未満の場合は全件）
  var startRow = Math.max(2, lastRow - 4);
  var numRows = lastRow - startRow + 1;
  var data = sheet.getRange(startRow, 1, numRows, 10).getValues();

  // 新しい順に並べ替えて返す
  return data.reverse().map(function(row) {
    var d = new Date(row[2]);
    return {
      date: (d.getMonth() + 1) + '/' + d.getDate(),
      code: String(row[3]),
      amount: row[7],
      desc: row[9]
    };
  });
}
```

### デプロイ手順（初回設定）

GAS Web Appとして公開するための手順です。一度だけ行います。

1. Google Sheetsを開き、メニューの「拡張機能」→「Apps Script」をクリック
2. 上記の `コード.gs` と `index.html` をそれぞれ作成
3. `コード.gs` の `SPREADSHEET_ID` を実際のスプレッドシートIDに書き換える
4. 右上の「デプロイ」→「新しいデプロイ」をクリック
5. 種類に「ウェブアプリ」を選択
6. 「次のユーザーとして実行」→「自分」を選択
7. 「アクセスできるユーザー」→「自分のみ」を選択
8. 「デプロイ」をクリック → URLが発行される
9. そのURLをスマホのブックマークに登録、またはホーム画面に追加

---

## 6. バッファから本帳簿への転記方式

### 2つの方式

入力バッファに溜まったデータを本帳簿に移す方法は2つあります。

#### 方式A: 手動転記（推奨）

最もシンプルで確実な方法です。

**手順:**
1. 入力バッファSheetを開く
2. K列（転記済み）が `FALSE` の行を確認する
3. 手動で本帳簿Excelに転記する
4. 転記した行のK列を `TRUE` に変更する

**利点:**
- 転記時に内容を目視確認できる
- 本帳簿のフォーマットに合わせて柔軟に対応可能
- 設定不要ですぐに使い始められる

**向いている場合:**
- 月に数十件程度の入力
- 本帳簿に独自の書式やルールがある場合

#### 方式B: GASトリガーによる自動転記

データが増えてきたら、自動で転記するGASプログラムも用意できます。

```javascript
// ============================================================
// transferToLedger — 未転記データを本帳簿Sheetに自動転記する
// ※ 本帳簿をGoogle Sheets上に作る場合に使用可能
// ============================================================

function transferToLedger() {
  var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  var buffer = ss.getSheetByName(BUFFER_SHEET_NAME);
  var lastRow = buffer.getLastRow();

  if (lastRow < 2) return;  // データなし

  // 全データを取得
  var data = buffer.getRange(2, 1, lastRow - 1, 11).getValues();
  var transferred = 0;

  data.forEach(function(row, index) {
    // K列（11番目=index 10）がFALSEの行だけ処理
    if (row[10] === false || row[10] === 'FALSE') {

      // ★ ここに本帳簿への書き込み処理を記述 ★
      // 例: 本帳簿Sheetの最終行に追加
      // var ledger = ss.getSheetByName('本帳簿');
      // ledger.appendRow([row[2], row[5], row[6], row[7], row[8], row[9]]);

      // 転記済みフラグをTRUEに更新
      buffer.getRange(index + 2, 11).setValue(true);
      transferred++;
    }
  });

  // 転記件数をログに記録
  Logger.log(transferred + '件を転記しました');
}
```

**自動実行の設定方法:**
1. Apps Scriptエディタで「トリガー」（時計アイコン）をクリック
2. 「トリガーを追加」をクリック
3. 実行する関数に `transferToLedger` を選択
4. イベントのソースに「時間主導型」を選択
5. 頻度を「毎日」「毎週」などお好みで設定

**注意:**
- 本帳簿がExcelファイル（.xlsx）の場合、GASからは直接書き込めません
- その場合は方式A（手動転記）を使用するか、本帳簿もGoogle Sheetsに移行する必要があります

### 推奨

まずは**方式A（手動転記）**で運用を開始し、操作に慣れてから必要に応じて方式Bへの移行を検討してください。

---

## 7. エラーハンドリング

### 想定されるエラーと対処

| エラー | 発生条件 | 対処（自動） | ユーザーへの表示 |
|--------|----------|-------------|----------------|
| 不正な科目コード | 科目マスタに存在しないコードを入力 | 登録ボタン無効化 | 「該当する科目コードがありません」（赤文字） |
| 金額が未入力/不正 | 空欄、0以下、文字列を入力 | 送信前にチェック | 「正しい金額を入力してください」 |
| 日付が未入力 | 日付欄が空欄 | 送信前にチェック | 「日付を入力してください」 |
| 二重送信 | 登録ボタンを連打 | ボタンを即座に無効化 | ボタン表示が「登録中...」に変化 |
| ネットワーク切断 | スマホのネット接続が不安定 | GASがエラーを返す | 「登録に失敗しました」+ エラー内容 |
| スプレッドシート権限エラー | 共有設定の問題 | GASがエラーを返す | 「登録に失敗しました」+ エラー内容 |

### 入力値チェックの詳細

入力画面側（JavaScript）とサーバー側（GAS）の2段階でチェックします。

**画面側チェック（即時反映）:**
- 科目コード: 入力のたびに科目マスタと照合 → 不一致なら赤文字警告
- 金額: 数値以外の入力をブロック（`inputmode="numeric"` で数字キーボード表示）
- 摘要: 100文字以上は入力不可（`maxlength` 指定）

**サーバー側チェック（登録ボタン押下時）:**
- 科目コードが科目マスタに存在するか再確認
- 金額が正の整数であるか確認
- 日付が有効な日付であるか確認

### 重複入力の防止

完全な重複（同じ日付・同じコード・同じ金額・同じ摘要）を防ぐため、登録時に以下のチェックを行います。

```javascript
// postEntry 関数内に追加する重複チェック
function checkDuplicate(sheet, date, code, amount, description) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return false;  // データがなければ重複なし

  // 直近10件をチェック（全件チェックは処理が重くなるため）
  var startRow = Math.max(2, lastRow - 9);
  var data = sheet.getRange(startRow, 1, lastRow - startRow + 1, 10).getValues();

  for (var i = 0; i < data.length; i++) {
    var row = data[i];
    var rowDate = new Date(row[2]).toISOString().split('T')[0];
    var inputDate = new Date(date).toISOString().split('T')[0];

    if (rowDate === inputDate &&
        String(row[3]) === String(code) &&
        Number(row[7]) === Number(amount) &&
        row[9] === (description || '')) {
      return true;  // 重複あり
    }
  }
  return false;  // 重複なし
}
```

重複が検出された場合は、確認ダイアログで「同じ内容のデータが既にあります。本当に登録しますか？」と表示し、ユーザーの判断に委ねます。

---

## 付録: セットアップ手順まとめ

### 必要な準備

1. **Googleアカウント**: Google Sheets と GAS を使うために必要
2. **スマートフォン**: ブラウザが使えれば機種は問いません

### 手順

| # | 作業 | 所要時間 |
|---|------|---------|
| 1 | Google Sheetsで新しいスプレッドシートを作成 | 1分 |
| 2 | 「科目マスタ」シートを作成し、ヘッダーとデータを入力 | 10分 |
| 3 | 「入力バッファ」シートを作成し、ヘッダーを入力 | 2分 |
| 4 | 「拡張機能」→「Apps Script」を開く | 1分 |
| 5 | コード.gs と index.html を作成（本設計書のコードをコピー） | 5分 |
| 6 | SPREADSHEET_ID を書き換える | 1分 |
| 7 | 「デプロイ」→「新しいデプロイ」→「ウェブアプリ」で公開 | 2分 |
| 8 | 発行されたURLをスマホのブックマークに登録 | 1分 |

合計: 約20分で使い始められます。

### 入力バッファSheetのヘッダー

1行目に以下を入力してください:

| A | B | C | D | E | F | G | H | I | J | K |
|---|---|---|---|---|---|---|---|---|---|---|
| ID | 登録日時 | 仕訳日付 | 科目コード | 取引名 | 借方科目 | 貸方科目 | 金額 | 税区分 | 摘要 | 転記済み |
