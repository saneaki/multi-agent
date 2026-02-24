# cmd_221 メールダイジェストWF バグ修正記録

## バグ1: 優先度判定の誤り（GitHub Issue #5）

### 根本原因
Gmail v5.0/v6.0の「Gemini判断+要約準備」ノードのプロンプトに、`urgency`の判断基準（high/medium/lowの定義）が含まれていなかった。Geminiが基準なしでデフォルトの「low」を返すケースが発生。

### 修正内容
プロンプトに以下を追加:
```
【緊急度の判断基準】
- high（高）: 期日・締切が明示されている、クライアントからの返信・確認・合意要求、法的手続きに直接関わる内容、至急対応が必要
- medium（中）: 近日中に対応が必要な業務連絡、案件の進捗に影響する確認事項、返信を要する一般的なビジネス連絡
- low（低）: 急ぎではない情報共有のみ、返信不要な通知・メルマガ、将来の参考情報
```

### 修正対象WF
- Gmail自動化ワークフロー v5.0 (6HfrbcXoujQSfSQC, active) ✅
- Gmail自動化ワークフロー v6.0 (x2HSCjYW3wCQlp6a, inactive) ✅

---

## バグ2: HTML文字化け（GitHub Issue #6）

### 根本原因
「ダイジェスト構築」コードがHTMLタグ（`<b>高</b>`等）でメッセージを構築していたが、Telegram Bot API呼び出し時に`parse_mode: "HTML"`が未設定のためHTMLタグが文字として表示されていた。

### 修正内容
Telegram Bot送信ノードのjsonBodyに`"parse_mode": "HTML"`を追加。

### 修正対象WF
- Gmail ダイジェスト通知 v1.0 (XgI1VYV2oDZyGKhf, active) ✅
- Gmail ダイジェスト通知 v2.0 (Qitb61IRPn4XZkgA, inactive) ✅

---

## GitHub Issue対応
- Issue #5: 解決コメント追加 + クローズ ✅
- Issue #6: 解決コメント追加 + クローズ ✅

## 実行日時
2026-02-24 JST

---

## 追加バグ3: 緊急メール通知の送信先誤り（GitHub Issue #7）

### 根本原因
Gmail v5.0/v6.0の「Telegram即時通知」ノードで `$env.TELEGRAM_CHAT_ID`（個人用: 8201375732）を使用していたため、緊急通知が個人DMに送信されていた。

### 修正内容
`$env.TELEGRAM_CHAT_ID` → `$env.TELEGRAM_CHAT_ID_GROUP`（-5233973051, グループ用）に変更。

### 修正対象WF
- Gmail自動化ワークフロー v5.0 (6HfrbcXoujQSfSQC, active) ✅
- Gmail自動化ワークフロー v6.0 (x2HSCjYW3wCQlp6a, inactive) ✅

- GitHub Issue #7: コメント追加 + クローズ ✅
