# n8nワークフロー エラー調査・改善設計書

> **cmd_166** | 作成日: 2026-02-16 | 担当: 軍師（gunshi）
>
> 4系統のn8nワークフローで発生しているエラーを調査し、原因特定と改善策を策定する。

---

## エグゼクティブサマリ

| WF | エラー | 原因（推定確度） | 緊急度 | 改善難度 |
|----|--------|-----------------|--------|---------|
| 領収書自動転記 v8.1 | Bad request | Gemini thinking token消費（90%） | 高 | 低 |
| 法律文書自動分析 v1.0 | Bad request | Gemini thinking token消費（90%） | 中 | 低 |
| Gmailダイジェスト通知 v1.0 | Bad request | Telegram Markdown parse_mode（80%） | 高 | 中 |
| Googleカレンダー同期 v4.1 | Too many requests | Google Calendar APIレート制限（確定） | 低 | 低 |

**推奨対応順序**: WF1 → WF3 → WF2 → WF4（頻度×業務影響度順）

---

## 1. 領収書自動転記システム v8.1

### 1.1 エラー概要

| 項目 | 内容 |
|------|------|
| **エラーメッセージ** | "Bad request - please check your parameters" |
| **発生ノード** | Gemini OCR + データ抽出ノード（HTTP Request → Gemini API） |
| **発生回数** | 2回再発、自然回復なし |
| **影響** | 領収書データがNotionに転記されない |

### 1.2 原因分析

#### 最有力: Gemini thinking token消費問題（確度90%）

**メカニズム:**

```
1. maxOutputTokens: 500（推定）を設定
2. Gemini 2.5 Flash/Proがthinking mode有効
3. thinking tokenが478トークンを消費（内部推論）
4. 実出力に使えるトークンは22トークンのみ
5. JSON応答が途中切断: {"receipt_date":"2026
6. finishReason: MAX_TOKENS が返る
7. n8nのHTTP Requestノードが不正なJSONを受信
8. 後続のCodeノードでJSON.parse()が失敗
9. "Bad request" として表面化
```

**根拠:**

- 同一エラーメッセージが領収書WFと法律文書WFの両方で発生 → 共通基盤（Gemini API）が原因
- Gemini 2.5 Flash/Proの既知問題（shogun-gemini-thinking-token-guard スキル参照）
- 「自然回復なし」= 設定値の問題であり一時的障害ではない
- cmd_137のGmail v4.0でもgemini-2.5-flashを使用中 → 同系統の設計

**OCR特有のリスク:**

領収書OCRはプロンプトが複雑（画像認識 + 構造化データ抽出）であり、thinkingトークン消費が通常のテキスト処理より多い。

```
通常テキスト処理: thinking ~300 token → 出力 ~200 token
OCR+構造化抽出:   thinking ~800 token → 出力 ~500 token
→ maxOutputTokens=1000 でも不足する可能性大
```

#### 副次候補1: contents.partsが空（確度5%）

- 画像データが正しくBase64エンコードされていない場合に発生
- 特定の画像形式（HEIC等）で発生する可能性
- ただし「2回再発、自然回復なし」の症状と不整合（画像依存なら成功/失敗が混在するはず）

#### 副次候補2: コンテキストウィンドウ超過（確度5%）

- 高解像度画像のトークン数がGemini APIの上限を超過
- ただしGemini 2.5 Flashの入力上限は100万トークンであり、通常の領収書画像では到達しない

### 1.3 改善設計

#### 改善A: maxOutputTokensの増量（必須・即効性あり）

**変更前（推定）:**

```json
"generationConfig": {
  "maxOutputTokens": 500
}
```

**変更後:**

```json
"generationConfig": {
  "maxOutputTokens": 4096,
  "responseMimeType": "application/json"
}
```

**推奨値の根拠:**

| 期待出力 | 推定トークン数 | 推奨maxOutputTokens |
|---------|---------------|---------------------|
| 領収書JSON（日付、金額、店名、科目等） | ~500 tokens | 2048 |
| 複数品目の領収書JSON | ~1000 tokens | 4096 |

thinking tokenが出力予算の60-80%を消費することを前提に、**期待出力の4倍**を設定。

#### 改善B: finishReasonチェックの追加（推奨）

Gemini APIレスポンスを処理するCodeノードに以下を追加:

```javascript
const geminiData = $input.first().json;
const finishReason = geminiData.candidates?.[0]?.finishReason;

// finishReasonチェック
if (finishReason === 'MAX_TOKENS') {
  console.warn('WARNING: maxOutputTokens到達。設定値の増量が必要。');
  console.warn('現在の応答長:', geminiData.candidates?.[0]?.content?.parts?.[0]?.text?.length);
}

const geminiResponse = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
```

#### 改善C: JSON.parse()のtry-catch強化（推奨）

```javascript
let receiptData;
try {
  receiptData = JSON.parse(geminiResponse);
} catch (e) {
  console.error('=== 領収書データパースエラー ===');
  console.error('エラー内容:', e.message);
  console.error('応答文字列:', geminiResponse);
  console.error('finishReason:', finishReason);
  console.error('→ maxOutputTokens設定を確認（推奨: 4096以上）');

  // フォールバック: 手動確認キューに入れる
  receiptData = {
    parse_error: true,
    raw_response: geminiResponse,
    error_message: e.message,
    receipt_date: '',
    amount: 0,
    vendor: '解析エラー',
    needs_manual_review: true
  };
}
```

#### 改善D: responseMimeTypeの明示指定（推奨）

```json
"generationConfig": {
  "maxOutputTokens": 4096,
  "responseMimeType": "application/json"
}
```

`responseMimeType: "application/json"` を指定することで、Geminiが厳密なJSON形式で応答するよう強制。thinking後のJSON構造化がより安定する。

### 1.4 実装時の注意点

1. **maxOutputTokensの変更のみで即効性あり** — コスト増は微量（実出力分のみ課金）
2. 改善B,C,Dは防御的プログラミングであり、Aと併せて実装すべき
3. テスト時は手元の領収書画像で実行し、`finishReason`を確認すること
4. `continueOnFail: true` が設定されている場合、エラーが隠蔽されている可能性 → 実行ログ要確認

---

## 2. 法律文書自動分析 v1.0

### 2.1 エラー概要

| 項目 | 内容 |
|------|------|
| **エラーメッセージ** | "Bad request - please check your parameters" |
| **発生ノード** | Call Gemini APIノード（HTTP Request → Gemini API） |
| **発生回数** | 1回 |
| **影響** | 法律文書の分析結果が出力されない |

### 2.2 原因分析

#### 最有力: Gemini thinking token消費問題（確度90%）

領収書WFと同一のメカニズム。法律文書分析は特にthinkingトークン消費が大きい。

**法律文書特有のリスク:**

```
法律文書分析のプロンプト:
- 入力: 法律文書テキスト（数千〜数万文字）
- 期待出力: 分析結果JSON（争点整理、リスク評価、推奨対応等）
- thinking消費: 非常に高い（法的推論は内部思考が多い）

→ maxOutputTokens=1000 程度では確実に不足
→ 推奨: maxOutputTokens=8192
```

#### 副次候補: 入力テキストのエンコーディング問題（確度10%）

- 法律文書にはPDF由来の特殊文字（罫線、丸付き数字等）が含まれる
- これらがGemini APIのcontents.partsで不正な文字列として扱われる可能性
- 対策: 入力テキストのサニタイズ処理を追加

### 2.3 改善設計

#### 改善A: maxOutputTokensの増量（必須）

```json
"generationConfig": {
  "maxOutputTokens": 8192,
  "temperature": 0.2,
  "responseMimeType": "application/json"
}
```

法律文書分析は出力が長くなる傾向があるため、領収書WFより大きい値を設定。

#### 改善B: finishReasonチェック（WF1と同様）

WF1の改善Bと同一パターンを適用。

#### 改善C: 入力テキストサニタイズ（推奨）

```javascript
// Gemini API呼び出し前のCodeノードに追加
const rawText = $json.documentText || '';

// PDF由来の特殊文字を除去/置換
const sanitizedText = rawText
  .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, '') // 制御文字除去
  .replace(/\uFFFD/g, '') // 置換文字除去
  .replace(/[\u200B-\u200D\uFEFF]/g, ''); // ゼロ幅文字除去

// 入力長チェック（Gemini 2.5 Flashの安全圏）
if (sanitizedText.length > 500000) {
  console.warn('入力テキストが非常に長い。先頭50万文字に切り詰め。');
}

return [{ json: { documentText: sanitizedText.slice(0, 500000) } }];
```

#### 改善D: エラー時フォールバック

```javascript
let analysisResult;
try {
  analysisResult = JSON.parse(geminiResponse);
} catch (e) {
  console.error('法律文書分析パースエラー:', e.message);
  analysisResult = {
    parse_error: true,
    raw_response: geminiResponse,
    summary: '分析エラー: AI応答の解析に失敗',
    risk_level: 'unknown',
    needs_manual_review: true
  };
}
```

### 2.4 実装時の注意点

1. 法律文書はテキスト量が多く、maxOutputTokensは**8192以上**を推奨
2. temperatureは法律分析のため低め（0.2）に設定
3. 発生回数1回と少ないが、同一原因の可能性が高いため予防的に修正すべき

---

## 3. Gmailダイジェスト通知 v1.0

### 3.1 エラー概要

| 項目 | 内容 |
|------|------|
| **エラーメッセージ** | "Bad request - please check your parameters" |
| **発生ノード** | Telegram Bot送信ノード（HTTP Request → Telegram API） |
| **発生回数** | 毎時再発、4回以上 |
| **影響** | メールダイジェストがTelegramに届かない |

### 3.2 原因分析

**重要: このWFのエラーはGemini APIではなくTelegram Bot APIで発生している。**

#### 最有力: Telegram Markdown parse_modeエラー（確度80%）

**メカニズム:**

```
1. ダイジェスト構築ノードがメール件名・本文からテキスト生成
2. テキスト内にMarkdown特殊文字が含まれる（_, *, `, [ 等）
3. Telegram Bot API に parse_mode: "Markdown" で送信
4. TelegramのMarkdownパーサーが特殊文字をエスケープ不正と判断
5. HTTP 400 "Bad request" が返る
6. 毎時再発 = 同じ未通知メールが毎回ダイジェストに含まれ続ける
```

**根拠:**

- 「毎時再発」= 同一データに対する繰り返し処理 → データ内容に起因するエラー
- Telegram Markdown v1は特殊文字のエスケープが厳格
- メール件名・本文にはMarkdown特殊文字が頻出（例: `test_result`, `Re: 確認_依頼`, `**重要**`）
- 通知済みフラグが更新されないため、同じメールが毎回処理される → 無限ループ

**Telegram Markdown v1で問題になる文字:**

| 文字 | 例 | 影響 |
|------|-----|------|
| `_` | `test_result_2026` | イタリック開始と解釈され、対応する`_`がないとエラー |
| `*` | `**重要**` | ボールド開始と解釈され、ネスト不正でエラー |
| `` ` `` | コード内の文字 | コードブロック開始と解釈 |
| `[` | `[INFO]` | リンク記法の開始と解釈 |

#### 副次候補1: メッセージ長超過（確度10%）

- Telegram APIは4096文字が上限
- チャンク分割が実装されていない、または分割ロジックにバグがある場合に発生
- ただし「4回以上」と毎回同じ挙動 → 長さだけの問題なら一部は成功するはず

#### 副次候補2: Bot Token/Chat IDの失効（確度5%）

- Bot Tokenが変更・失効した場合に発生
- ただしこの場合のエラーメッセージは通常 "Unauthorized" (401)
- "Bad request" (400) はパラメータ形式の問題を示す

#### 副次候補3: 空メッセージ送信（確度5%）

- ダイジェスト構築でテキストが空になるケース
- 0件チェック（IFノード）が正常に動作していない可能性
- Telegram APIは空のtextフィールドで400を返す

### 3.3 改善設計

#### 改善A: parse_modeの変更（最優先・即効性あり）

**選択肢1: parse_mode削除（最も安全）**

```json
{
  "chat_id": "{{ $env.TELEGRAM_CHAT_ID }}",
  "text": {{ JSON.stringify($json.digestText) }},
}
```

Markdown装飾を捨てて、プレーンテキストで送信。確実にエラーを回避。

**選択肢2: MarkdownV2に移行（推奨）**

```json
{
  "chat_id": "{{ $env.TELEGRAM_CHAT_ID }}",
  "text": {{ JSON.stringify($json.digestText) }},
  "parse_mode": "MarkdownV2"
}
```

MarkdownV2はエスケープルールが明確。ただし**全ての特殊文字を明示的にエスケープ**する必要がある。

**選択肢3: HTMLモードに移行（推奨・最も堅牢）**

```json
{
  "chat_id": "{{ $env.TELEGRAM_CHAT_ID }}",
  "text": {{ JSON.stringify($json.digestText) }},
  "parse_mode": "HTML"
}
```

HTMLモードは特殊文字の影響を受けにくく、`<b>`, `<i>` タグで装飾可能。

**推奨: 選択肢3（HTMLモード）**

理由: メール本文由来のテキストはMarkdown特殊文字を多く含むため、HTMLモードが最も安全。

#### 改善B: テキストサニタイズ処理の追加（必須）

ダイジェスト構築Codeノードに、Telegram送信前のサニタイズを追加:

```javascript
// === HTMLモード用サニタイズ ===
function sanitizeForTelegramHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

// === ダイジェスト構築内で適用 ===
const lines = sorted.map(result => {
  const props = result.properties;
  const urgency = props['緊急度']?.select?.name || 'low';
  const icon = urgency === 'high' ? '&#128308;' : urgency === 'medium' ? '&#128993;' : '&#9898;';
  const urgencyLabel = urgency === 'high' ? '高' : urgency === 'medium' ? '中' : '低';
  const senderName = sanitizeForTelegramHtml(
    props['送信者名']?.rich_text?.[0]?.plain_text || '不明'
  );
  const subject = sanitizeForTelegramHtml(
    props['件名']?.title?.[0]?.plain_text || '(件名なし)'
  );
  const summary = sanitizeForTelegramHtml(
    props['要約']?.rich_text?.[0]?.plain_text || ''
  );
  const replyDraft = props['返信案']?.rich_text?.[0]?.plain_text || '';
  const hasReply = replyDraft ? 'あり' : 'なし';

  return `${icon} <b>${urgencyLabel}</b> | ${senderName} - ${subject}\n${summary} | 返信案: ${hasReply}`;
});
```

#### 改善C: チャンク分割の確認・修正（推奨）

```javascript
// 4096文字制限対策 — 安全マージン4000文字
const MAX_LEN = 4000;
const chunks = [];
const header = `<b>メールダイジェスト (${totalCount}件)</b>\n\n`;

if (fullText.length <= MAX_LEN) {
  chunks.push(fullText);
} else {
  let current = header;
  for (const line of lines) {
    const entry = line + '\n\n';
    if ((current + entry).length > MAX_LEN) {
      if (current.trim() !== header.trim()) {
        chunks.push(current.trim());
      }
      current = '<b>メールダイジェスト (続き)</b>\n\n' + entry;
    } else {
      current += entry;
    }
  }
  if (current.trim()) {
    chunks.push(current.trim());
  }
}
```

#### 改善D: Telegram送信のエラーハンドリング強化（推奨）

```javascript
// Telegram送信後の結果チェック（Codeノードで実装）
const telegramResponse = $input.first().json;

if (telegramResponse.ok === false) {
  console.error('Telegram送信エラー:', telegramResponse.description);
  console.error('error_code:', telegramResponse.error_code);

  if (telegramResponse.error_code === 400) {
    console.error('→ parse_mode/メッセージ形式のエラー。テキスト内容を確認。');
    console.error('→ 送信テキスト長:', $json.digestText?.length);
  }
}
```

#### 改善E: 無限ループ防止策（重要）

現状の問題: エラー → 通知済みフラグ未更新 → 次回同じメールを再処理 → 同じエラー → 無限ループ

**対策: Telegram送信とNotion更新の分離**

```
現行（推定）:
  ダイジェスト構築 → Telegram送信 → 成功時のみNotion更新
  → Telegram失敗 → Notion未更新 → 次回同じメール → 無限ループ

改善後:
  ダイジェスト構築
    ├─ Telegram送信（失敗してもOK）
    └─ Notion更新（Telegram結果に依存しない）← 並列分岐
  → Telegram失敗 → Notion更新は成功 → 次回は新しいメールのみ
```

shogun-n8n-telegram-digestスキルの設計通り、Telegram送信とNotion更新を**並列分岐**にすることで、送信失敗時の無限ループを防止する。

### 3.4 実装時の注意点

1. **改善Aのparse_mode変更が最優先** — これだけで毎時エラーが解消する可能性が高い
2. 改善Eの並列分岐は設計変更を伴うため、WF構造を確認してから着手
3. テスト時は特殊文字を含むメール件名（`test_result`, `Re: 確認*重要*`等）でダイジェストを生成して検証
4. Bot Token/Chat IDの有効性は `https://api.telegram.org/bot{TOKEN}/getMe` で確認可能

---

## 4. Googleカレンダー同期フロー v4.1

### 4.1 エラー概要

| 項目 | 内容 |
|------|------|
| **エラーメッセージ** | "Too many requests" |
| **発生ノード** | syncToken取得ノード |
| **発生回数** | 1回 |
| **影響** | カレンダー同期が一時停止（レート制限により自然回復する可能性あり） |

### 4.2 原因分析

#### 確定: Google Calendar APIレート制限

**メカニズム:**

```
1. Google Calendar API のレート制限に到達
2. HTTP 429 "Too many requests" が返る
3. syncTokenの取得に失敗
4. 同期処理が一時停止
```

**Google Calendar APIのレート制限:**

| 制限 | 値 |
|------|-----|
| 1ユーザーあたりの秒間リクエスト | 10 requests/second |
| 1日あたりのリクエスト | 1,000,000/day |
| Calendar Events.list のページサイズ | max 2,500 |

発生回数1回であり、一時的な負荷集中が原因と推測。常時発生する問題ではない。

### 4.3 改善設計

#### 改善A: retryOnFailの追加（推奨）

```json
{
  "retryOnFail": true,
  "maxTries": 3,
  "waitBetweenTries": 2000
}
```

429エラーに対する自動リトライ。2秒間隔で最大3回。

#### 改善B: Exponential Backoff（将来的改善）

頻発するようであれば、Codeノードでexponential backoffを実装:

```javascript
// リトライロジック（必要になった場合のみ）
const maxRetries = 3;
const baseDelay = 1000; // ms

for (let attempt = 0; attempt < maxRetries; attempt++) {
  try {
    // Calendar API呼び出し
    break;
  } catch (e) {
    if (e.statusCode === 429 && attempt < maxRetries - 1) {
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    } else {
      throw e;
    }
  }
}
```

### 4.4 実装時の注意点

1. 発生1回のため**経過観察が主**。retryOnFail追加のみで十分
2. 再発が頻繁になった場合は、cron実行間隔の見直しを検討
3. syncTokenの有効期限切れ（410 Gone）とは別問題であることに注意

---

## 5. 横断的改善事項

### 5.1 共通パターン: エラーメッセージの同一性

4つのWF全てで "Bad request - please check your parameters" という**n8nレベルの汎用エラーメッセージ**が表示されている（WF4を除く）。これはn8nがHTTPレスポンスのエラーを包括的に表示するための仕様。

**実際のエラー源の見分け方:**

| n8n表示メッセージ | 実際の原因を特定する方法 |
|------------------|------------------------|
| Bad request | 実行ログの `responseData` を確認。Gemini APIなら `finishReason`、Telegram APIなら `error_code` と `description` が含まれる |

### 5.2 共通改善: 実行ログ監視の仕組み化

現状、エラーが `continueOnFail: true` で隠蔽されている可能性がある。

**推奨:**

1. 各WFのエラーノードにGoogle Chat Webhook通知を追加
2. エラー発生時に自動でアラートが飛ぶようにする

```json
{
  "method": "POST",
  "url": "https://chat.googleapis.com/v1/spaces/xiMFuiAAAAE/messages?key=...",
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={\n  \"text\": \"n8nエラー通知: {{ $json.error?.message || 'Unknown error' }}\\nWF: {{ $workflow.name }}\\nNode: {{ $json.error?.node || 'Unknown' }}\"\n}"
}
```

### 5.3 Gemini API系の共通設定テンプレート

WF1, WF2で共通して使えるGemini API呼び出しの安全な設定:

```json
{
  "generationConfig": {
    "maxOutputTokens": 4096,
    "temperature": 0.3,
    "responseMimeType": "application/json"
  }
}
```

**チェックリスト（全Gemini APIノード共通）:**

- [ ] maxOutputTokensが**2048以上**に設定されている
- [ ] responseMimeTypeが `application/json` に設定されている（JSON出力の場合）
- [ ] Codeノードで finishReason === 'MAX_TOKENS' をチェックしている
- [ ] JSON.parse() が try-catch で囲まれている
- [ ] フォールバック値が後続ノードで有効な値になっている

---

## 6. 実装計画

### Phase 1: 即時対応（全WF共通パラメータ修正）

| 対象 | 変更内容 | 影響範囲 | 所要時間 |
|------|----------|---------|---------|
| WF1: 領収書 | maxOutputTokens → 4096 | Gemini HTTPノードのJSON body修正 | 15分 |
| WF2: 法律文書 | maxOutputTokens → 8192 | Gemini HTTPノードのJSON body修正 | 15分 |
| WF3: ダイジェスト | parse_mode → "HTML" + サニタイズ追加 | Telegram HTTPノード + Codeノード修正 | 1時間 |
| WF4: カレンダー | retryOnFail: true 追加 | syncTokenノード設定変更 | 10分 |

### Phase 2: 防御的プログラミング（各WFにエラーハンドリング追加）

| 対象 | 変更内容 | 所要時間 |
|------|----------|---------|
| WF1 | finishReasonチェック + JSON.parse try-catch | 30分 |
| WF2 | finishReasonチェック + 入力サニタイズ + JSON.parse try-catch | 45分 |
| WF3 | 並列分岐化（Telegram/Notion分離）+ エラーハンドリング | 1.5時間 |

### Phase 3: 監視強化（横断的改善）

| 対象 | 変更内容 | 所要時間 |
|------|----------|---------|
| 全WF | Google Chat Webhookエラー通知追加 | 各30分 |
| 全WF | continueOnFail箇所のログ出力強化 | 各15分 |

### 合計所要時間見積もり

| Phase | 所要時間 | 優先度 |
|-------|---------|--------|
| Phase 1 | 約1.5時間 | 最高（即時実施） |
| Phase 2 | 約2.5時間 | 高（Phase 1後に実施） |
| Phase 3 | 約2.5時間 | 中（安定稼働後に実施） |

---

## 7. 検証手順

### WF1: 領収書自動転記

1. maxOutputTokens変更後、テスト領収書画像で手動実行
2. 実行ログで `finishReason` が `STOP`（正常終了）であることを確認
3. JSON出力が完全であること（途中切断なし）を確認
4. Notionに正しくデータ転記されることを確認

### WF2: 法律文書分析

1. maxOutputTokens変更後、テスト文書で手動実行
2. 実行ログで `finishReason` が `STOP` であることを確認
3. 分析結果JSONが完全であることを確認

### WF3: Gmailダイジェスト通知

1. parse_mode変更 + サニタイズ追加後、手動実行
2. 特殊文字を含むテストメール（件名に `_`, `*` 等）がNotionにある状態で実行
3. Telegramにダイジェストが正常に届くことを確認
4. 通知済みフラグが更新されることを確認
5. 次回実行時に同じメールが再送されないことを確認

### WF4: Googleカレンダー同期

1. retryOnFail追加後、通常稼働で経過観察
2. 429エラーが再発した場合、自動リトライで回復することを確認

---

## 付録A: 調査手段の制約

| 手段 | 利用可否 | 備考 |
|------|---------|------|
| n8n REST API直接アクセス | 不可 | N8N_API_KEY未設定 |
| n8n MCP tools | 未接続 | MCP設定にn8n-mcpあるが未確認 |
| WF JSON直接取得 | 不可 | API経由でのみ取得可能 |
| 実行ログ確認 | 不可 | n8n管理画面からのみ閲覧可能 |
| スキル参照 | 可 | shogun-gemini-thinking-token-guard, shogun-n8n-wf-analyzer, shogun-n8n-telegram-digest |
| 過去設計書参照 | 可 | cmd_137: Gmail v4.0 WF構造分析済み |

**実装担当者への依頼:**

- 各WFのGeminiノードの現在のmaxOutputTokens値を確認すること
- 直近の実行ログからfinishReasonを確認すること
- Telegram送信ノードの現在のparse_mode設定を確認すること
- 上記確認結果により、本設計書の推定確度を検証すること

## 付録B: 参照スキル一覧

| スキル名 | 用途 |
|---------|------|
| shogun-gemini-thinking-token-guard | Gemini thinking token問題の検知・対策パターン |
| shogun-n8n-wf-analyzer | n8n WF構造分析・改善計画パターン |
| shogun-n8n-telegram-digest | Telegram ダイジェスト通知パターン |
| shogun-n8n-workflow-upgrade | WF改修実行パターン（Phase 2以降で参照） |
