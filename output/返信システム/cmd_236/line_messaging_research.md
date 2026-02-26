# LINE連携調査結果

## 要件

顧客からの個人LINEアカウントへのメッセージを、Gmail自動化WFと同じパイプライン
（AI分析→Notion DB保存→通知→返信案生成）で処理したい。
ダイジェスト通知にもLINEメッセージを含める。

## 技術的制約

- 個人LINEアカウントには受信メッセージを取得するAPIが存在しない
- LINE Messaging API（Webhook受信）はLINE公式アカウント専用
- LINE Notifyは2025年3月に廃止済み

## 実現可能な選択肢

### A. LINE公式アカウント導入（推奨）

- 事務所用の公式アカウント（無料枠: 月200通送信、受信無制限）を作成
- 顧客にはそちらでやり取りしてもらう
- Messaging API Webhookで全メッセージをn8nに自動転送
- LINE Developers登録が必要

### B. 手動転送方式

- メッセージをメール転送→Gmail経由で既存パイプラインに流す
- 毎回手動操作が必要（自動化の意味が薄い）

### C. LINE公式アカウント + 個人LINE併用

- 新規顧客は公式アカウント、既存顧客は順次移行
- 段階的に自動処理範囲を拡大

## n8n連携パターン（公式アカウント方式）

- LINE Messaging API Webhook → n8n Webhook受信ノード
- n8nコミュニティノード: n8n-nodes-linewebhook, n8n-nodes-line-messaging
- 処理パイプライン: Webhook受信→メッセージ抽出→Gemini分析→Notion保存→通知→返信案
- replyTokenで自動返信も可能
- 参考WFテンプレート: https://n8n.io/workflows/3600-line-chatbot-with-google-sheets-memory-and-gemini-ai/

## LINE公式アカウント料金プラン（2026年時点）

| プラン | 月額 | 送信数/月 | 受信 |
|--------|------|-----------|------|
| コミュニケーション | 0円 | 200通 | 無制限 |
| ライト | 5,000円 | 5,000通 | 無制限 |
| スタンダード | 15,000円 | 30,000通 | 無制限 |

## セットアップ手順

1. LINE Developers (https://developers.line.biz/) にログイン
2. プロバイダー作成 → Messaging APIチャネル作成
3. チャネルアクセストークン（長期）発行 → LINE_CHANNEL_ACCESS_TOKEN
4. チャネル基本設定 → Your user ID → LINE_USER_ID
5. Webhook URL設定 → n8nのWebhookエンドポイントを指定
6. .envに追加: LINE_CHANNEL_ACCESS_TOKEN, LINE_USER_ID

## 参考URL

- LINE Developers: https://developers.line.biz/
- Messaging API概要: https://developers.line.biz/ja/docs/messaging-api/overview/
- Webhook受信: https://developers.line.biz/en/docs/messaging-api/receiving-messages/
- n8n LINE統合: https://n8n.io/integrations/webhook/and/line/
- n8n WFテンプレート: https://n8n.io/workflows/2733-line-message-api-push-message-and-reply/
- コミュニティノード(linewebhook): https://github.com/syshen/n8n-nodes-linewebhook
- コミュニティノード(line-messaging): https://github.com/elct9620/n8n-nodes-line-messaging
