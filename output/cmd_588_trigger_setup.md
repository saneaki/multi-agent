# cmd_588 Scope A — GAS Time-driven Trigger 設定手順書

## 概要

gas-mail-manager の processAllCustomers を **毎日 9:00** に自動実行する Time-driven trigger を設定する。
本書は GAS エディタ UI から `setupTrigger()` を 1 回手動実行するだけで完結するように整理した手順である。

- 対象 GAS プロジェクト: gas-mail-manager (Apps Script)
- 実行関数: `triggerProcessAllCustomers` (main.gs に新規追加された try-catch 付きラッパー)
- スケジュール: 毎日 9:00 (JST タイムゾーン: GAS プロジェクト設定に従う)
- 関連 cmd: cmd_588 (clasp RAPT 自動運用化), cmd_588 Scope B (ntfy push 連携 — 別タスク)

## 前提条件

| # | 前提 | 確認方法 |
|---|------|---------|
| 1 | main.gs に `triggerProcessAllCustomers` が存在 | `grep -n triggerProcessAllCustomers /home/ubuntu/gas-mail-manager/src/main.gs` |
| 2 | GAS 側に最新 main.gs が反映済 | `npx clasp push` 完了 (RAPT 有効時) または GAS エディタ画面で関数一覧に triggerProcessAllCustomers が出現 |
| 3 | 元帳の active 顧客リスト (folderId / sheetName) が整備済 | 元帳シート D 列・F 列を目視確認 |
| 4 | OAuth 認可スコープがリフレッシュ済 | GAS UI から手動 1 回実行で同意ダイアログを完了させる |

## 設定手順 (6 ステップ)

### Step 1. GAS プロジェクトを開く

1. ブラウザで <https://script.google.com/> にアクセスする。
2. プロジェクト一覧から **gas-mail-manager** を選択する。

### Step 2. main.gs を開く

1. 左メニュー「ファイル」→ `main.gs` を開く。
2. 関数一覧に `triggerProcessAllCustomers` と `setupTrigger` の両方が表示されることを確認する。
   - 表示されない場合は前提 #2 (clasp push 未完了) を疑い、main.gs の最新化を先に行う。

### Step 3. 既存トリガーを確認する

1. 左メニュー「トリガー」(時計アイコン) を開く。
2. 既存に `processAllCustomers` の 15 分間隔トリガーが残っていることを確認する。
   - これは setupTrigger() 実行時に自動削除されるが、念のため事前確認する。

### Step 4. setupTrigger を 1 回手動実行する

1. main.gs の関数選択ドロップダウンで **setupTrigger** を選ぶ。
2. ▶ 実行ボタンを押す。
3. 初回は OAuth 同意ダイアログが出る。許可する。
4. 実行ログ (Ctrl+Enter) で次のメッセージを確認する。

   ```
   毎日 9:00 のトリガーを設定しました (triggerProcessAllCustomers)。
   ```

### Step 5. トリガー設定を確認する

1. 左メニュー「トリガー」を再度開く。
2. 次の 1 行が表示されていれば成功:

   | 関数 | デプロイ | イベント | 種類 |
   |------|---------|---------|------|
   | triggerProcessAllCustomers | Head | 時間主導型 | 日タイマー (午前 9〜10 時) |

3. 旧 `processAllCustomers` 15 分間隔トリガーが消えていることを確認する。

### Step 6. 翌朝の実行ログを確認する

1. 翌朝 9:00 過ぎに GAS エディタ「実行数」を開く。
2. `triggerProcessAllCustomers` の実行ログに次の行があることを確認する。

   ```
   [trigger] processAllCustomers 開始: <ISO 時刻>
   [trigger] processAllCustomers 完了: <経過 ms>
   ```

3. ERROR 行が出ていた場合は cmd_588 Scope B (ntfy 通知) で殿に push される予定。

## 適用範囲

| 処理 | 自動化方針 | 理由 |
|------|-----------|------|
| 日常業務 (processAllCustomers) | **Time-driven trigger で自動化** | 毎日 9:00 に最新メールを取り込む。6 分制限超過時は resumeIndex により次回再開する仕組みを既に保持。 |
| backfill (寺地様 など) | **手動実行を継続** | 1 回限りの過去メール遡及で長時間処理 (~93 件)。trigger 化すると意図せぬ再実行や 6 分制限再突入の懸念があるため、必要時に `clasp run backfillTerachi` 等で殿が起動する。 |

## トリガー停止方法

- **個別停止**: GAS UI 「トリガー」画面で当該行右の縦三点 → 削除。
- **一括停止**: main.gs の関数選択で `removeTrigger` を選び実行する。`Logger.log('全トリガーを削除しました。')` が出れば成功。

## 参考: clasp push が失敗する場合 (RAPT エラー)

```
{"error":"invalid_grant","error_description":"reauth related error (invalid_rapt)"}
```

このエラーは Google の Reauthentication Proof Token (RAPT) 期限切れである。`npx clasp login` をローカル端末で再実行し、ブラウザで再認可する。VPS 環境では `--no-localhost` オプション + auth code コピー&ペーストで対応する。cmd_588 Scope B 以降で監視・自動再認可フローを整備予定。

## 関連ファイル

- `/home/ubuntu/gas-mail-manager/src/main.gs` — triggerProcessAllCustomers / setupTrigger 実装
- `output/cmd_588_trigger_setup.md` (本書)
- `queue/tasks/ashigaru4.yaml` — subtask_588a_trigger_wrapper
- `queue/reports/ashigaru4_report.yaml` — 実装報告
