# 構成員フィードバック送信ガイド

## フォームURL

**Notion DB URL**: https://www.notion.so/01d9f2b401e442e685ecf4b2feb5bfb8

**Notion Forms URL**: https://www.notion.so/forms/01d9f2b401e442e685ecf4b2feb5bfb8

> 注意: Notion Forms は Notion DB から手動で有効化が必要な場合があります。
> 有効化手順は下記「Notion Forms設定手順」を参照してください。

## 項目の説明

| 項目 | 内容 | 型 | 例 |
|------|------|-----|-----|
| タイトル | フィードバックの要約 | テキスト | "ダッシュボード更新が遅い" |
| 種別 | バグ/要望/質問/感想/その他 (複数選択可) | multi_select | バグ, 要望 |
| 詳細 | 詳しい説明 | テキスト | 具体的な状況を記載 |
| 送信者メールアドレス | メールアドレス (省略可) | email | user@example.com |
| 緊急度 | high/medium/low | select | medium |
| 対象プロジェクト | pdf総合ソフト/その他 | select | pdf総合ソフト |
| スクリーンショット等 | 添付ファイル (省略可) | files | - |

## shogun側での処理フロー

1. フォーム送信 → Notion DBに保存
2. n8n (5分ポーリング) → shogunのinboxに自動配信
3. shogunが処理 → 必要に応じてcmd化

## Notion Forms設定手順（手動）

APIでのForms有効化が不可の場合、以下を手動で実施:

1. Notion上でDBページを開く
2. 右上「...」→「Add a view」→「Form」を選択
3. 表示されたFormビューのURLをコピー
4. URLを本ドキュメントの「フォームURL」欄に更新

## エラー時

n8n処理失敗時はDiscord通知が届く。
karo宛にreportを送付すること。

## DB情報

| 項目 | 値 |
|------|-----|
| DB名 | フィードバックフォーム |
| DB ID | 01d9f2b4-01e4-42e6-85ec-f4b2feb5bfb8 |
| Data Source ID | dd8e3175-0e16-4690-ac32-0ee5f1f0d9e8 |
| 作成日 | 2026-04-07 |
| 最終編集 | 2026-04-08 |

## スキーマ (Notion DB プロパティ一覧)

| プロパティ名 | 型 | 備考 |
|------------|-----|------|
| タイトル | title | 必須 |
| 種別 | multi_select | バグ/要望/質問/感想/その他 |
| 詳細 | rich_text | 任意 |
| 緊急度 | select | high/medium/low |
| 対象プロジェクト | select | pdf総合ソフト/その他 |
| 送信者メールアドレス | email | 任意 |
| スクリーンショット等 | files | 任意 |
| 作成日時 | created_time | 自動 |
| 対応 | checkbox | shogun側で管理 |
| 要約 | rich_text | shogun側で記入 |
