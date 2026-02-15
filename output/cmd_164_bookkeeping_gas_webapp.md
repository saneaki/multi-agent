# 複式簿記スマホ入力 GAS Web App コード一式

**文書ID**: cmd_164
**作成日**: 2026-02-15
**目的**: スマホから複式簿記データを直接Google Sheetsに入力するWeb Appの実装

---

## 目次

1. [システム概要](#1-システム概要)
2. [Code.gs（GAS本体）](#2-codegsgas本体)
3. [index.html（入力画面）](#3-indexhtml入力画面)
4. [設置手順](#4-設置手順)
5. [使い方](#5-使い方)

---

## 1. システム概要

### 仕様

- **入力項目**: 科目コード（英字4桁）、日付、金額、摘要
- **入力先**: スプレッドシートID `1Guaf49W0wOpRkr5FXIz6oylsmipWSfNj55nnm-XLLK4`
- **列マッピング**: C列=コード、D列=額、E列=日付、F列=摘要
- **行検索ロジック**: E列（日付）が空の行を上から検索し、最初に見つかった空行に入力
- **上書き防止**: 既存データのある行には絶対に上書きしない

### システム構成

```
┌─────────┐    ┌─────────────────┐    ┌──────────────────┐
│ スマホ   │ →  │ GAS Web App     │ →  │ Google Sheets    │
│（ブラウザ）│    │（Code.gs）      │    │（既存の簿記データ）│
└─────────┘    └─────────────────┘    └──────────────────┘
```

---

## 2. Code.gs（GAS本体）

以下のコードをGoogle Apps Scriptエディタに貼り付けてください。

```javascript
// ============================================================
// 設定値
// ============================================================

// 入力先スプレッドシートのID
var SPREADSHEET_ID = '1Guaf49W0wOpRkr5FXIz6oylsmipWSfNj55nnm-XLLK4';

// ============================================================
// doGet — ブラウザでアクセスした時に入力画面を表示
// ============================================================

function doGet() {
  var html = HtmlService.createHtmlOutputFromFile('index')
    .setTitle('仕訳入力')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);

  html.addMetaTag('viewport', 'width=device-width, initial-scale=1');

  return html;
}

// ============================================================
// processForm — フォームデータをSheetsに書き込み
// ============================================================

function processForm(formData) {
  try {
    // 入力値の検証
    if (!formData.code || formData.code.length !== 4) {
      throw new Error('科目コードは英字4桁で入力してください');
    }

    if (!formData.date) {
      throw new Error('日付を入力してください');
    }

    if (!formData.amount || isNaN(formData.amount) || Number(formData.amount) <= 0) {
      throw new Error('正しい金額を入力してください');
    }

    // スプレッドシートを開く
    var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = ss.getSheets()[0];  // 1枚目のシートを使用

    // E列（日付列）のデータを取得
    var lastRow = sheet.getLastRow();
    var dateColumn = sheet.getRange(1, 5, lastRow, 1).getValues();  // E列 = 5番目

    // 空行を検索（1行目はヘッダーなので2行目から）
    var targetRow = -1;
    for (var i = 1; i < dateColumn.length; i++) {  // i=1 → 2行目から
      if (!dateColumn[i][0] || dateColumn[i][0] === '') {
        targetRow = i + 1;  // 配列indexは0始まり、シート行番号は1始まり
        break;
      }
    }

    // 空行が見つからない場合は最終行の次に追加
    if (targetRow === -1) {
      targetRow = lastRow + 1;
    }

    // C, D, E, F列に書き込み
    sheet.getRange(targetRow, 3).setValue(formData.code.toUpperCase());  // C列: コード（大文字変換）
    sheet.getRange(targetRow, 4).setValue(Number(formData.amount));      // D列: 金額
    sheet.getRange(targetRow, 5).setValue(new Date(formData.date));      // E列: 日付
    sheet.getRange(targetRow, 6).setValue(formData.description || '');   // F列: 摘要

    return {
      success: true,
      message: '登録しました ✅',
      row: targetRow
    };

  } catch (error) {
    return {
      success: false,
      message: 'エラー: ' + error.message
    };
  }
}
```

---

## 3. index.html（入力画面）

以下のHTMLをGoogle Apps Scriptエディタに追加してください。

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>仕訳入力</title>
  <style>
    /* ===== 基本設定 ===== */
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      padding: 20px;
    }

    .container {
      max-width: 480px;
      margin: 0 auto;
      background: white;
      border-radius: 16px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
      overflow: hidden;
    }

    /* ===== ヘッダー ===== */
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      text-align: center;
      padding: 24px;
      font-size: 24px;
      font-weight: bold;
    }

    /* ===== フォームエリア ===== */
    .form-area {
      padding: 24px;
    }

    .form-group {
      margin-bottom: 20px;
    }

    .form-group label {
      display: block;
      font-size: 14px;
      font-weight: bold;
      color: #333;
      margin-bottom: 6px;
    }

    .form-group input,
    .form-group textarea {
      width: 100%;
      padding: 14px;
      font-size: 16px;
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      background: #fafafa;
      transition: all 0.2s;
    }

    .form-group input:focus,
    .form-group textarea:focus {
      border-color: #667eea;
      background: white;
      outline: none;
      box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
    }

    .code-input {
      text-transform: uppercase;
      letter-spacing: 2px;
      font-weight: bold;
    }

    .hint {
      font-size: 12px;
      color: #999;
      margin-top: 4px;
    }

    /* ===== 送信ボタン ===== */
    .submit-btn {
      width: 100%;
      padding: 16px;
      font-size: 18px;
      font-weight: bold;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
      margin-top: 10px;
    }

    .submit-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
    }

    .submit-btn:active {
      transform: translateY(0);
    }

    .submit-btn:disabled {
      background: #ccc;
      cursor: not-allowed;
      transform: none;
    }

    /* ===== メッセージ ===== */
    .message {
      text-align: center;
      padding: 14px;
      border-radius: 8px;
      margin-top: 16px;
      font-weight: bold;
      display: none;
    }

    .message.success {
      background: #d4edda;
      color: #155724;
      border: 2px solid #c3e6cb;
    }

    .message.error {
      background: #f8d7da;
      color: #721c24;
      border: 2px solid #f5c6cb;
    }

    /* ===== ローディング ===== */
    .loading {
      display: none;
      text-align: center;
      padding: 20px;
    }

    .spinner {
      border: 4px solid #f3f3f3;
      border-top: 4px solid #667eea;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
      margin: 0 auto;
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>

  <div class="container">
    <div class="header">📒 仕訳入力</div>

    <div class="form-area">
      <!-- 科目コード -->
      <div class="form-group">
        <label>科目コード</label>
        <input type="text"
               id="code"
               class="code-input"
               placeholder="例: ABCD"
               maxlength="4"
               autocomplete="off">
        <div class="hint">英字4桁（自動的に大文字に変換されます）</div>
      </div>

      <!-- 日付 -->
      <div class="form-group">
        <label>日付</label>
        <input type="date" id="date">
      </div>

      <!-- 金額 -->
      <div class="form-group">
        <label>金額</label>
        <input type="number"
               id="amount"
               placeholder="例: 1200"
               min="1"
               step="1">
        <div class="hint">円単位で入力してください</div>
      </div>

      <!-- 摘要 -->
      <div class="form-group">
        <label>摘要（メモ）</label>
        <input type="text"
               id="description"
               placeholder="例: 渋谷→新宿"
               maxlength="100">
        <div class="hint">任意入力（空欄可）</div>
      </div>

      <!-- 送信ボタン -->
      <button class="submit-btn" id="submitBtn" onclick="submitForm()">
        ✅ 登録する
      </button>

      <!-- メッセージ -->
      <div class="message" id="message"></div>

      <!-- ローディング -->
      <div class="loading" id="loading">
        <div class="spinner"></div>
        <p style="margin-top: 10px; color: #666;">登録中...</p>
      </div>
    </div>
  </div>

  <script>
    // ===== 初期化 =====

    // 日付の初期値を「今日」にセット
    document.getElementById('date').value = new Date().toISOString().split('T')[0];

    // コード入力欄にフォーカス
    document.getElementById('code').focus();

    // ===== 送信処理 =====

    function submitForm() {
      // 入力値を取得
      var code = document.getElementById('code').value.trim();
      var date = document.getElementById('date').value;
      var amount = document.getElementById('amount').value;
      var description = document.getElementById('description').value.trim();

      // 入力チェック
      if (!code || code.length !== 4) {
        showMessage('科目コードは英字4桁で入力してください', 'error');
        return;
      }

      if (!/^[A-Za-z]{4}$/.test(code)) {
        showMessage('科目コードは英字のみで入力してください', 'error');
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
      var confirmMsg = '以下の内容で登録しますか？\n\n'
        + '科目コード: ' + code.toUpperCase() + '\n'
        + '日付: ' + date + '\n'
        + '金額: ¥' + Number(amount).toLocaleString() + '\n'
        + '摘要: ' + (description || '（なし）');

      if (!confirm(confirmMsg)) {
        return;
      }

      // ボタン無効化
      var btn = document.getElementById('submitBtn');
      btn.disabled = true;

      // ローディング表示
      document.getElementById('loading').style.display = 'block';
      document.getElementById('message').style.display = 'none';

      // GASにデータ送信
      google.script.run
        .withSuccessHandler(function(result) {
          btn.disabled = false;
          document.getElementById('loading').style.display = 'none';

          if (result.success) {
            showMessage(result.message, 'success');

            // フォームをクリア（日付は今日のまま）
            document.getElementById('code').value = '';
            document.getElementById('amount').value = '';
            document.getElementById('description').value = '';

            // コード欄にフォーカス（連続入力しやすく）
            document.getElementById('code').focus();
          } else {
            showMessage(result.message, 'error');
          }
        })
        .withFailureHandler(function(error) {
          btn.disabled = false;
          document.getElementById('loading').style.display = 'none';
          showMessage('通信エラー: ' + error.message, 'error');
        })
        .processForm({
          code: code,
          date: date,
          amount: amount,
          description: description
        });
    }

    // ===== メッセージ表示 =====

    function showMessage(text, type) {
      var el = document.getElementById('message');
      el.textContent = text;
      el.className = 'message ' + type;
      el.style.display = 'block';

      // 成功メッセージは3秒後に自動で消す
      if (type === 'success') {
        setTimeout(function() {
          el.style.display = 'none';
        }, 3000);
      }
    }

    // ===== Enterキーで送信 =====

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' && e.target.id !== 'submitBtn') {
        e.preventDefault();
        submitForm();
      }
    });
  </script>

</body>
</html>
```

---

## 4. 設置手順

### ステップ1: スプレッドシートを開く

1. ブラウザで以下のURLを開く:
   ```
   https://docs.google.com/spreadsheets/d/1Guaf49W0wOpRkr5FXIz6oylsmipWSfNj55nnm-XLLK4/edit
   ```

### ステップ2: Apps Scriptエディタを開く

1. スプレッドシート上部のメニューから「拡張機能」→「Apps Script」をクリック

### ステップ3: コードを貼り付け

1. デフォルトで表示される `コード.gs` に、上記の **Code.gs（GAS本体）** のコードを貼り付け
2. 左上の「＋」ボタン → 「HTML」を選択 → ファイル名を `index` にする
3. 作成された `index.html` に、上記の **index.html（入力画面）** のコードを貼り付け
4. 保存（Ctrl+S または Cmd+S）

### ステップ4: デプロイ

1. 右上の「デプロイ」→「新しいデプロイ」をクリック
2. 「種類の選択」→「ウェブアプリ」を選択
3. 設定:
   - **説明**: 「仕訳入力アプリ v1」（任意）
   - **次のユーザーとして実行**: 「自分」
   - **アクセスできるユーザー**: 「自分のみ」（または「全員」でスマホからアクセス可能）
4. 「デプロイ」をクリック
5. 初回は権限の承認が必要:
   - 「アクセスを承認」→ Googleアカウントを選択 → 「許可」

### ステップ5: URLを取得

1. デプロイ完了後、「ウェブアプリのURL」が表示される
2. このURLをコピーしてスマホに送信（メール、LINE、メモ等）

### ステップ6: スマホで登録

#### iPhoneの場合:
1. SafariでウェブアプリのURLを開く
2. 画面下部の共有ボタン（□に↑）をタップ
3. 「ホーム画面に追加」を選択
4. 名前を「仕訳入力」に変更して「追加」

#### Androidの場合:
1. ChromeでウェブアプリのURLを開く
2. 画面右上の「︙」メニューをタップ
3. 「ホーム画面に追加」を選択
4. 名前を「仕訳入力」に変更して「追加」

---

## 5. 使い方

### 日常の入力フロー

1. スマホのホーム画面から「仕訳入力」アイコンをタップ
2. 科目コードを英字4桁で入力（例: `ABCD`）
3. 日付を選択（初期値は今日）
4. 金額を入力（例: `1200`）
5. 摘要を入力（例: `渋谷→新宿`）※任意
6. 「✅ 登録する」ボタンをタップ
7. 確認ダイアログで「OK」
8. 「登録しました ✅」メッセージが表示される
9. フォームが自動でクリアされる → 続けて次の仕訳を入力可能

### データの確認

入力されたデータはスプレッドシートで確認できます:

- **C列**: 科目コード（英字4桁、自動的に大文字変換）
- **D列**: 金額
- **E列**: 日付
- **F列**: 摘要

### 注意事項

- **E列が空の行に入力される**: 既存データを上書きしません
- **連続入力に最適化**: 登録後すぐに次の仕訳を入力できます
- **オフライン不可**: インターネット接続が必要です
- **セキュリティ**: デプロイ時に「自分のみ」を選択した場合、他のユーザーはアクセスできません

---

## 達成基準チェックリスト

- ✅ 1. GAS Web Appのコード一式（Code.gs + index.html）が成果物として提供されている
- ✅ 2. スマホからアクセス可能なWeb App URLが発行できる状態のコードになっている
- ✅ 3. 入力項目は4つ: 科目コード（英字4桁）、日付（デフォルト今日）、金額、摘要
- ✅ 4. 科目マスタは不要。コードは殿が直接入力する（英字4桁）
- ✅ 5. 入力先はスプレッドシートID 1Guaf49W0wOpRkr5FXIz6oylsmipWSfNj55nnm-XLLK4 のC列:コード、D列:額、E列:日付、F列:摘要
- ✅ 6. E列（日付）が空の行を検索し、最上行から入力する（既存データを上書きしない）
- ✅ 7. 入力成功時にフィードバック表示がある（登録完了メッセージ）
- ✅ 8. GASコードの設置手順（スプレッドシートへの貼付け → デプロイ方法）が記載されている

---

**実装完了**: 2026-02-15
