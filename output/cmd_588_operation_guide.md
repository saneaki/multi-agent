# cmd_588 GAS 自動運用ガイド

**cmd_588** | 作成: ashigaru2 (subtask_588c) | 日付: 2026-04-26

**North Star**: 殿が迷わず運用できる。案 D (業務自動) / 案 F (RAPT 監視) の役割分担を文書化する。

---

## 1. 概要

cmd_588 で整備した 2 つの自動化機能の概要と役割分担。

| 機能 | 案 | 概要 | 殿の介入 |
|------|-----|------|---------|
| Time-driven trigger | 案 D | 毎日 9:00 に processAllCustomers() を自動実行 | 初回 setupTrigger() 実行のみ。以降 0 |
| RAPT 監視 push | 案 F | 30 分毎に RAPT 期限をチェック。期限近接時に ntfy push | 通知受信後に再認証 (5-10 分) |

**月間介入時間の変化:**

| 作業 | 改善前 | 改善後 |
|------|--------|--------|
| 日常業務 (processAllCustomers) | 殿が毎日手動実行 (~30 分/月) | Time-driven trigger が自動実行 (0 分/月) |
| RAPT 再認証 | エラー発生後に対応 (場当たり) | 期限前に ntfy で通知 (予防対応) |
| 月合計 | 30-60 分 | 5-15 分 (再認証 1-2 回のみ) |

---

## 2. Time-driven trigger 設定手順 (案 D)

> 詳細は `output/cmd_588_trigger_setup.md` も参照。

### 2.1 前提条件

| # | 前提 | 確認方法 |
|---|------|---------|
| 1 | main.gs に `triggerProcessAllCustomers` が存在 | GAS エディタで関数一覧を確認 |
| 2 | GAS 側に最新コードが反映済 | `clasp push` 完了、または GAS エディタで直接確認 |
| 3 | 元帳の active 顧客リスト (folderId / sheetName) が整備済 | 元帳シート D 列・F 列を目視確認 |

### 2.2 設定手順 (1 回のみ)

1. ブラウザで <https://script.google.com/> を開き、**gas-mail-manager** を選択する。
2. 左メニューの `main.gs` を開く。
3. 関数選択ドロップダウンで **setupTrigger** を選ぶ。
4. ▶ 実行ボタンを押す。初回は OAuth 同意ダイアログが出るので許可する。
5. 実行ログ (Ctrl+Enter) で以下を確認する:
   ```
   毎日 9:00 のトリガーを設定しました (triggerProcessAllCustomers)。
   ```

### 2.3 トリガー確認

1. 左メニュー「トリガー」(時計アイコン) を開く。
2. 以下の 1 行が表示されていれば成功:

   | 関数 | イベント | 種類 |
   |------|---------|------|
   | triggerProcessAllCustomers | 時間主導型 | 日タイマー (午前 9〜10 時) |

3. 旧 `processAllCustomers` 15 分間隔トリガーが削除されていることを確認する。

### 2.4 動作確認 (翌朝)

翌朝 9:00 過ぎに GAS エディタ「実行数」を開き、`triggerProcessAllCustomers` の実行ログを確認する:
```
[trigger] processAllCustomers 開始: <ISO 時刻>
[trigger] processAllCustomers 完了: <経過 ms>
```

### 2.5 トリガー停止方法

- **UI から削除**: 「トリガー」画面で当該行右の縦三点 → 削除。
- **スクリプト実行**: 関数選択で `removeTrigger` を選び ▶ 実行。

---

## 3. RAPT 監視運用 (案 F)

### 3.1 仕組み

`scripts/clasp_rapt_monitor.sh` が cron で 30 分毎に実行され、`~/.clasprc.json` の最終トークン発行時刻から経過時間を算出する。

| 経過時間 | 判定 | アクション |
|---------|------|-----------|
| < 6 時間 | OK | ログのみ (ntfy 通知なし) |
| 6〜7 時間 | WARN | ntfy 軽度通知「次回 clasp run 前に再認証推奨」 |
| >= 7 時間 | CRITICAL | ntfy 緊急通知「RAPT 期限切れ間近、今すぐ再認証」 + 復旧手順 |

### 3.2 cron 設定 (初回のみ)

VPS で以下のコマンドを実行し crontab に追加する:

```bash
crontab -e
```

以下の行を追加:
```
*/30 * * * * bash /home/ubuntu/shogun/scripts/clasp_rapt_monitor.sh >> /tmp/rapt_monitor.log 2>&1
```

### 3.3 ntfy 通知受信時の対応

CRITICAL 通知を受け取ったら、**ローカル端末** (Windows/Mac) で以下を実行:

**案 A: clasp login → scp 転送 (推奨)**

```bash
# ローカル端末で実行
cd /path/to/gas-mail-manager
npx clasp login
# ブラウザで Google 認証 → ~/.clasprc.json が更新される

# VPS に転送
scp ~/.clasprc.json ubuntu@<VPS_IP>:~/.clasprc.json
```

**案 B: GAS Editor から実行 (clasp 不要)**

1. <https://script.google.com/> → gas-mail-manager を開く。
2. 関数選択で `processAllCustomers` → ▶ 実行。
3. GAS は自前の OAuth で動作するため、RAPT エラーなし。

> 詳細: `shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` 参照。

### 3.4 ログ確認

```bash
# VPS で実行
tail -f /tmp/rapt_monitor.log
```

出力例:
```
[rapt_monitor 2026-04-26 09:00:01 UTC] OK: elapsed=2h15m (token issued at 2026-04-26 06:44 UTC)
[rapt_monitor 2026-04-26 15:00:01 UTC] WARN: elapsed=6h15m — 次回 clasp run 前に再認証を推奨
[rapt_monitor 2026-04-26 16:00:01 UTC] CRITICAL: elapsed=7h15m — RAPT 期限切れ間近
```

---

## 4. 業務 / 検証 のすみ分け

| 処理 | 方式 | 殿の作業 |
|------|------|---------|
| 日常メール処理 (全顧客) | Time-driven trigger (毎日 9:00) | なし (自動) |
| backfill (寺地様など過去遡及) | 手動実行 | `clasp run backfillTerachi` 等を必要時に実行 |
| ad-hoc clasp run (バグ修正後テスト) | 手動実行 | RAPT 通知を確認後、必要なら再認証してから実行 |
| GAS 実行結果確認 | GAS エディタ「実行数」| エラーが出ていた場合に確認 (通常は不要) |

**backfill を自動化しない理由:**
- 1 回限りの過去遡及処理 (寺地様 93 件等)
- 長時間処理のため trigger 化すると意図せぬ再実行リスク
- 完了確認が必要なため手動のほうが安全

---

## 5. cron 設定まとめ

VPS の crontab に追加する設定:

```cron
# RAPT 監視: 30 分毎
*/30 * * * * bash /home/ubuntu/shogun/scripts/clasp_rapt_monitor.sh >> /tmp/rapt_monitor.log 2>&1
```

> Time-driven trigger は GAS 側で管理。crontab への追加は不要。

---

## 6. トラブルシューティング

### RAPT エラー: `invalid_grant` / `invalid_rapt`

```
{"error":"invalid_grant","error_description":"reauth related error (invalid_rapt)"}
```

**原因:** OAuth RAPT トークンの 8 時間制限超過。  
**対処:** セクション 3.3 の案 A または案 B で再認証する。

### trigger が動かない

1. GAS エディタ「実行数」で実行ログを確認する。
2. エラーが出ている場合は内容を確認する。
3. `setupTrigger()` を再実行してトリガーを再設定する。

### trigger が二重に動いている

1. GAS エディタ「トリガー」を開く。
2. `triggerProcessAllCustomers` が複数行ある場合は 1 行を残して削除する。
3. または `removeTrigger()` → `setupTrigger()` の順で再設定する。

### ntfy 通知が届かない

```bash
# VPS で手動テスト
bash /home/ubuntu/shogun/scripts/ntfy.sh "テスト通知" "テストタイトル"
```

通知が届かない場合は `config/settings.yaml` の `ntfy_topic` と認証設定を確認する。

---

## 7. 関連ファイル

| ファイル | 内容 |
|---------|------|
| `output/cmd_588_trigger_setup.md` | Time-driven trigger 詳細手順 (Scope A) |
| `scripts/clasp_rapt_monitor.sh` | RAPT 監視スクリプト (Scope B) |
| `context/gas-mail-manager.md` | GAS システム設計ドキュメント (自動運用方針追記) |
| `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` | RAPT 再認証スキル |
| `/home/ubuntu/gas-mail-manager/src/main.gs` | GAS メインエントリ (triggerProcessAllCustomers 実装) |
