---
name: shogun-gas-automated-verification
description: Google Apps Script (GAS) の自動検証基盤構築スキル。clasp 3.x を用いた clasp run + clasp logs の自動化パターン。VPS/Ubuntu 環境での OAuth 認証・GCP Standard Cloud Project 設定・Logger.log 互換性の確立知見を含む。
version: "1.0"
created_at: "2026-04-24"
created_by: ashigaru1
source_cmd: cmd_567
tags: [gas, clasp, gcp, oauth, automation, testing]
---

# shogun-gas-automated-verification

GAS (Google Apps Script) の自動検証基盤を構築するスキル。
Ubuntu VPS 上で `clasp run` + `clasp logs` による自動テストを実現するための
セットアップ手順と落とし穴を体系化したもの。

## Trigger

以下の場合に使用:
- VPS (Ubuntu) から GAS 関数を自動実行・ログ取得したい
- clasp run が権限エラーで失敗する
- clasp logs でログが取れない
- GCP Standard Cloud Project と Apps Script の連携設定が必要

## Battle-Tested セットアップ手順

### 必須セットアップ (必ず全て実施)

#### 1. GCP Standard Cloud Project 準備
- GCP コンソール → 「新しいプロジェクト」または既存プロジェクトを使用
- **注意**: clasp run は Standard Cloud Project が必須 (Apps Script デフォルトプロジェクトは不可)
- GCP プロジェクト ID をメモしておく (例: `kaji-487204`)

#### 2. OAuth クライアント ID 作成
- GCP コンソール → 「API とサービス」→「認証情報」→「認証情報を作成」→「OAuth クライアント ID」
- **アプリケーションの種類: 必ず『デスクトップアプリ』を選択**
  - ❌ ウェブアプリ → `Invalid redirect URL` エラーで clasp login --creds 失敗
  - ✅ デスクトップアプリ → 正常動作
- クライアント ID + シークレットを JSON でダウンロード → `creds.json` として保存

#### 3. Google Apps Script API 有効化
- https://script.google.com/home/usersettings を開く
- 「Google Apps Script API」を ON に切替

#### 4. Apps Script を Standard Cloud Project に紐付け
- GAS エディタ → 「プロジェクトの設定」→「Google Cloud Platform (GCP) プロジェクト」
- GCP プロジェクト番号を入力して関連付け
- **この手順をスキップすると clasp run が失敗する**

#### 5. .clasp.json に projectId 追加 (clasp logs 使用時は必須)
```json
{
  "scriptId": "...",
  "rootDir": ".",
  "projectId": "your-gcp-project-id"
}
```
- `projectId` がないと `clasp logs` 実行時に `"GCP project ID is not set"` エラー

#### 6. clasp login --creds (デスクトップ OAuth 認証)
```bash
clasp login --creds creds.json --use-project-scopes --include-clasp-scopes
```
- `--use-project-scopes`: GCP プロジェクトのスコープを使用
- `--include-clasp-scopes`: clasp 必須スコープを追加
- **clasp 3.x では両フラグが必須** (片方だけでは不足)
- 実行後にブラウザで Google OAuth 認証を完了

### 6.5. OAuth 承諾の取り消し方法
- https://myaccount.google.com/permissions で登録済みアプリを確認・削除可

#### 7. clasp run でテスト
```bash
cd /path/to/project
clasp run processAllCustomers 2>&1 | tee /tmp/clasp_run_test.log
```

#### 8. clasp logs で実行ログ確認
```bash
clasp logs --simplified 2>&1 | tail -50
```
- Logger.log は Cloud Logging 経由で **INFO レベル**として記録
- `--simplified` で読みやすい形式で出力

## Logger.log vs console.log 互換性 (SUP5a 知見)

| ログ関数 | clasp logs での取得 | 備考 |
|---------|------------------|------|
| `Logger.log()` | ✅ **INFO レベルで取得可** | Cloud Logging 経由 |
| `console.log()` | ✅ 取得可 | 同様に INFO レベル |

**結論**: `Logger.log()` のみ使用のコードでも `clasp logs` で取得可能。`console.log()` への置換は不要。

## gas_run.sh テンプレート

```bash
#!/bin/bash
set -euo pipefail
FUNC="${1:-processAllCustomers}"
CMD_ID="${2:-manual}"
cd /home/ubuntu/gas-mail-manager
echo "=== clasp run $FUNC ===" | tee /tmp/gas_run_${CMD_ID}.log
clasp run "$FUNC" 2>&1 | tee -a /tmp/gas_run_${CMD_ID}.log
echo "=== clasp logs ===" >> /tmp/gas_run_${CMD_ID}.log
clasp logs --simplified 2>&1 | tail -50 | tee -a /tmp/gas_run_${CMD_ID}.log
```

使用例:
```bash
bash scripts/gas_run.sh processAllCustomers cmd_567
cat /tmp/gas_run_cmd_567.log
```

## よくある落とし穴

| エラー | 原因 | 対処 |
|-------|------|------|
| `Authorization is required` | GAS → GCP Project 未紐付け or 権限不足 | GAS エディタで GCP Project 設定 |
| `Invalid redirect URL` | OAuth クライアント種別が「ウェブアプリ」 | 「デスクトップアプリ」で作り直す |
| `GCP project ID is not set` | .clasp.json に projectId なし | .clasp.json に projectId フィールド追加 |
| `Unable to run script function` | clasp login が --creds なし | `clasp login --creds creds.json --use-project-scopes --include-clasp-scopes` |
| `You do not have permission to call SpreadsheetApp.openById` | 認証スコープ不足 | GAS エディタで一度手動実行して OAuth 承諾 |

## 参考 (shogun プロジェクト実績)

- 構築完了: 2026-04-24 (cmd_565/cmd_567)
- 認証: clasp 3.3.0 + --use-project-scopes + --include-clasp-scopes + GCP kaji-487204
- Logger.log 動作確認: INFO レベルで clasp logs --simplified に出力確認済
