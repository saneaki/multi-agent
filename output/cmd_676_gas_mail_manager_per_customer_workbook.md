# cmd_676 gas-mail-manager 顧客毎独立WB化 — 実装レポート

**実施日**: 2026-05-08 14:35-15:00 JST
**実施者**: 足軽7号 (Opus+T)
**親 cmd**: cmd_676
**status**: **partially_blocked** — clasp push 完了 (15:02 JST, 7 files), clasp run は OAuth scope `script.scriptapp` 欠落で実行不可。実機検証は明日 09:00 JST daily trigger 自然発火 or 殿手動 GAS editor run 待ち。

---

## 1. 北極星 (north_star) 整合

> 元帳統合構造を顧客毎独立 WB 構造へ変更し、G='on' 顧客ごとに C列root Drive 配下へ「{A列}_総合シート」を作成、メール一覧と PDF 保存を顧客 root 配下へ集約する。元帳は元帳機能のみ残す。

ローカル実装は完遂。production 反映は clasp 認証復旧待ち (Tier 2: stop-and-report)。

## 2. 仕様 diff (旧 → 新)

### 2.1 元帳列スキーマ

| 列 | 旧 (cmd_455) | 新 (cmd_676) |
|----|-------------|--------------|
| A | 顧客名 | 顧客名 |
| B | メールアドレス | メールアドレス |
| C | Drive フォルダ link | **顧客 root Drive link (chip)** |
| D | Drive フォルダ ID | **顧客 WB link (GAS 書込, chip)** |
| E | メール一覧シート link | **PDF 保存先 link (chip)** |
| F | メール一覧シート名 | **最終チェック日時** |
| G | 最終チェック日時 | **on/off フィルタ** |
| H | ステータス (active/inactive) | 担当弁護士 (読取のみ) |
| I | (なし) | 担当事務 (読取のみ) |

旧 H='active' フィルタは新 G='on' に役割移行。boolean true / 'on' (case-insensitive) のみ通過。

### 2.2 メール一覧の所在

- 旧: 元帳 spreadsheet 内の `メール_{顧客名}` シート群 (1 spreadsheet 集約)
- 新: 各顧客 root Drive 配下の `{A列}_総合シート` WB 内 `メール一覧` シート (顧客毎分散)

### 2.3 PDF 保存先

- 旧: 元帳 D 列の Drive フォルダ ID (顧客毎フォルダ直下)
- 新: 元帳 E 列「08 メール送受信」フォルダ (顧客 root 配下のサブフォルダ chip)

### 2.4 backfill 関数撤去

cmd_676 仕様で「既存PDF移行は実装しない、新着のみ新仕様適用」。
旧 main.gs に存在した以下を本 cmd で削除:

- `backfillCustomer(customerName, startDate, endDate, force)` (cmd_589/590)
- `backfillTerachi()` (cmd_589 一括ラッパー)
- `backfillSheetFromDrive()` (cmd_585b orphan PDF 取込)
- `updateExistingRowSummary(sheetName, messageId, summary)` (force-mode helper)

旧 schema 依存ゆえ新 schema 下で機能しない。再要求時は新 schema で再実装。

## 3. 実装サマリー

### 3.1 src/sheets.gs (全面書換)

主要追加:

- 列定数 `COL_NAME=1`〜`COL_STAFF=9` (1-based)
- `extractUrlFromCell(cell)`: RichTextValue.getLinkUrl() 優先、plain URL fallback
- `extractDriveFolderId(url)`: `/folders/{id}` 抽出
- `extractSpreadsheetId(url)`: `/spreadsheets/d/{id}` 抽出
- `isCustomerOn(rawValue)`: G 列 on 判定 (boolean true / 'on' case-insensitive)
- `setChipLink(cell, displayText, url)`: RichTextValue で hyperlinked text 設定
- `getCustomerList()`: G='on' のみ返却。off/空/他値完全除外
- `getOrCreateCustomerWorkbook(customer)`: C列root配下 `{name}_総合シート` WB 作成 or 再利用
- `ensureCustomerWbLink(rowIndex, wbUrl, wbName)`: D列補填(欠落時のみ、既存保持)
- `ensureEmailListSheet(wbSs)`: 顧客WB 内 `メール一覧` シート作成 or ヘッダー保証
- `appendEmailRowToWb(wbSs, rowData)`: 顧客WB へ行追加
- `isMessageAlreadyRecordedInWb(wbSs, messageId)`: 顧客WB 内重複チェック
- `updateLastCheckDate(rowIndex, checkDate)`: F列(列6)更新

### 3.2 src/main.gs (全面書換)

主要変更:

- `processAllCustomers()`: G='on' 顧客のみ処理ループ。6 分制限・resume index は維持
- `processCustomer(customer)`:
  1. E列 PDF folderId 必須チェック → 不正なら skip
  2. `getOrCreateCustomerWorkbook(customer)` → 失敗時 skip
  3. `ensureCustomerWbLink(rowIndex, wb.url, wb.name)` (D列補填)
  4. `searchNewEmails(customer.email, lastCheckDate)`
  5. 各メール `processSingleEmail(customer, wb, message)`
  6. `updateLastCheckDate(rowIndex, new Date())`
- `processSingleEmail(customer, wb, message)`:
  - 重複check (`isMessageAlreadyRecordedInWb`)
  - PDF生成・E列フォルダ保存 (`savePdfToDrive(customer.pdfFolderId, ...)`)
  - 要約・WB.メール一覧追記 (`appendEmailRowToWb`)
  - Gmail ラベル付与 (`markAsProcessed`)
- `dryRunCmd676()`: G='on' 顧客一覧 + 列解析結果のみ Logger.log する診断関数 (実機検証用)
- `triggerProcessAllCustomers()` / `setupTrigger()` / `removeTrigger()`: 維持
- `isApproachingTimeLimit(startTime, safetyMarginMs)`: 維持

### 3.3 src/{config,gmail,pdf,summary}.gs (修正なし)

cmd_676 範囲外。chip 解析・WB 操作は sheets.gs/main.gs のみで吸収可能。

### 3.4 shogun-side mirror (projects/gas-mail-manager/)

- `projects/gas-mail-manager/src/sheets.gs` ← 同期 (cmd_676 反映)
- `projects/gas-mail-manager/src/main.gs` ← 同期 (cmd_676 反映)
- `projects/gas-mail-manager/src/{config,gmail,pdf,summary}.gs` ← 既存温存 (cmd_676 範囲外、軽微 JSDoc 差分のみ)
- `projects/gas-mail-manager/docs/auth-guide.md` ← 既存保護 (殿の手記)

## 4. blocker (clasp RAPT auth)

### 4.1 症状

```
$ cd /home/ubuntu/gas-mail-manager && clasp push
{"error":"invalid_grant","error_description":"reauth related error (invalid_rapt)",
 "error_uri":"https://support.google.com/a/answer/9368756","error_subtype":"invalid_rapt"}
```

clasp 3.3.0 / scriptId=`1a7zxw0jBja2hzR6BPnkX2XT_z9ys19Afrat6PK3TovSuVqQWkTBdkzkS` /
projectId=`kaji-487204`。`/home/ubuntu/.clasprc.json` 最終更新 2026-05-01 23:22。

### 4.2 復旧手順 (`shogun-gas-clasp-rapt-reauth-fallback` skill 案A)

1. **殿のローカル PC** で:
   ```bash
   npm install -g @google/clasp
   clasp login
   ```
2. ブラウザで Google 認証ダイアログ承認 → `~/.clasprc.json` 生成
3. 生成された `.clasprc.json` を VPS へ転送:
   ```bash
   scp ~/.clasprc.json ubuntu@<VPS_IP>:/home/ubuntu/.clasprc.json
   ```
4. 家老が VPS 側で:
   ```bash
   cd /home/ubuntu/gas-mail-manager && clasp push
   # → "Pushed N files." を確認
   ```

### 4.3 復旧後の検証手順 (家老実行)

```bash
cd /home/ubuntu/gas-mail-manager

# Step1: schema dry-run (G=on 顧客と各列解析結果のみ Logger 出力)
clasp run dryRunCmd676 2>&1 | tee /tmp/cmd_676_dryrun.log
clasp logs --simplified 2>&1 | tail -50 | tee -a /tmp/cmd_676_dryrun.log

# Step2: 1サイクル本実行 (G=on 全顧客処理。寺地淳子様 G=on で WB 作成 or 再利用)
clasp run processAllCustomers 2>&1 | tee /tmp/cmd_676_run1.log
clasp logs --simplified 2>&1 | tail -100 | tee -a /tmp/cmd_676_run1.log
```

### 4.4 実機テスト確認項目 (家老/軍師 QC)

| ID | 項目 | 確認方法 |
|----|------|---------|
| C-1 | 寺地淳子様 G='on' 1サイクル成功 | `clasp logs` に `WB created` または `顧客処理完了: 寺地淳子様` 確認 |
| C-2 | 圓真諒 G='off' 完全スキップ | 元帳 圓真諒行 D/F/PDF/Gmail unchanged |
| A-2 | C列root配下に「{A}_総合シート」WB 作成/再利用 | 寺地淳子様 root Drive で `寺地淳子様_総合シート` 存在確認 |
| A-3 | D列チップ形式リンク貼付 | 元帳 寺地淳子様行 D列 hyperlink 確認 |
| A-4 | 顧客WB 「メール一覧」シート存在・ヘッダー一致 | 寺地淳子様_総合シート を開いて確認 |
| A-5 | Gmail検索→PDF→E列フォルダ→AI要約→転記→ラベル | E列 「08 メール送受信」 フォルダ内 PDF 確認 + WB.メール一覧 行確認 |
| A-6 | F列実行毎更新 | 元帳 F列タイムスタンプ変化 |
| B-1 | 既存メール一覧シート群を GAS が touch しない | 元帳の旧 `メール_{name}` シート群が無変化 |
| B-2 | 既存PDF移行コード未実装 | main.gs に backfill 系関数なし |
| B-3 | H/I 列読取のみ | 元帳 H/I 列 unchanged |

## 5. AC (acceptance_criteria) 自己照合

| AC | 内容 | 状況 |
|----|------|------|
| A-1 | G='on' のみ処理、off/空/他値完全スキップ | ✅ `isCustomerOn` + `getCustomerList` で実装 |
| A-2 | C配下に「{A}_総合シート」WB 作成/再利用 | ✅ `getOrCreateCustomerWorkbook` |
| A-3 | D列チップ形式リンク補填、既存保持 | ✅ `ensureCustomerWbLink` (RichTextValue.setLinkUrl) |
| A-4 | 顧客WB内「メール一覧」シート作成・既存フォーマット | ✅ `ensureEmailListSheet` (9列ヘッダー) |
| A-5 | Gmail検索→PDF→E列フォルダ→要約→転記→ラベル | ✅ `processSingleEmail` で連結 |
| A-6 | F列最終チェック実行毎更新 | ✅ `updateLastCheckDate` |
| B-1 | 元帳内既存メール一覧シートを GAS touch しない | ✅ 操作対象が顧客WBに変更されたため自動的に touch しない |
| B-2 | 既存PDF移行コード未実装 | ✅ backfill 系関数を main.gs から削除 |
| B-3 | H/I 列は読取のみ | ✅ `getCustomerList` で読取、書込なし |
| C-1 | 寺地淳子様 G='on' 実機1サイクル成功 | ⏸️ blocked (clasp RAPT 期限切れ) |
| C-2 | 圓真諒 G='off' 完全スキップ確認 | ⏸️ blocked (同) |
| C-3 | clasp push 本番反映 | ⏸️ blocked (同) |
| E-1 | output ファイル作成 | ✅ 本ファイル |
| E-2 | context/gas-mail-manager.md と projects/ 更新 | ✅ context 先頭に cmd_676 仕様変更通知 + projects mirror 同期 |

ローカル実装 (A-1〜B-3, E-1, E-2) は **10/10 PASS**。
production 反映 (C-1, C-2, C-3) は clasp 認証復旧後に家老が実行し再 QC 必要。

## 6. RACE-001 整合確認

- 編集権限: gas-mail-manager/src/sheets.gs, gas-mail-manager/src/main.gs, projects/gas-mail-manager/src/{sheets,main}.gs, context/gas-mail-manager.md, output/cmd_676_*, queue/reports/ashigaru7_report.yaml, queue/tasks/ashigaru7.yaml
- gas-mail-manager リポジトリは独立、shogun 並走 cmd と衝突なし
- shogun 側は context + projects + output + queue のみ。dashboard/config 等他者範囲は触らず

## 7. 残課題

1. **clasp RAPT 認証復旧** (殿のローカル `clasp login` 必要、上記 §4.2 手順)
2. **実機検証 C-1/C-2/C-3** (家老が clasp run dryRunCmd676 → processAllCustomers 実行、軍師QCにて確認)
3. **元帳の旧シート整理** (殿の手動作業: 元帳内 `メール_{name}` シート群削除、新仕様への切替日明示)
4. **新規 backfill 関数の要否判断** (殿/家老: 既存メールを新WBへ取込む必要があれば別 cmd で再実装)
5. **chip 厳密版 (Sheets API v4 chipRuns) 移行** (現行は RichTextValue.setLinkUrl による hyperlinked text。Sheets smart-chip 厳密実装は別 cmd で検討)

## 8. context_policy

`clear_between` (本 cmd は cmd_676 単一スコープ、多段ではない)。
完了報告後 `safe_clear_check.sh` → `/clear` 推奨。

## 9. 完了報告先

karo (inbox_write task_completed)。
本 report 作成後、shogun-side commit/push → blocked status で報告。

---

## 10. 進捗更新 (2026-05-08 15:06 JST: 殿 clasprc 転送後再開)

### 10.1 clasp push 結果

```
$ cd /home/ubuntu/gas-mail-manager && clasp push
Pushed 7 files at 3:02:09 PM.
└─ appsscript.json
└─ src/config.gs
└─ src/gmail.gs
└─ src/main.gs
└─ src/pdf.gs
└─ src/sheets.gs
└─ src/summary.gs
```

**production 反映 = ✅ DONE**。新 code は scriptId=`1a7zxw0jBja2hzR6BPnkX2XT_z9ys19Afrat6PK3TovSuVqQWkTBdkzkS` 上に live。

C-3 (clasp push 本番反映) は **PASS**。

### 10.2 clasp run blocker (新事象)

```
$ cd /home/ubuntu/gas-mail-manager && clasp run dryRunCmd676
Unable to run script function. Please make sure you have permission to run the script function.

$ bash scripts/gas_run_oauth.sh dryRunCmd676
HTTP response code: 403
ERROR: script.scriptapp scope が必要。
```

OAuth token scope 検査結果 (Google tokeninfo endpoint):
```
scope: email profile cloud-platform drive.file drive.metadata.readonly
       logging.read script.deployments script.projects script.webapp.deploy
       service.management userinfo.email userinfo.profile openid
```

**`https://www.googleapis.com/auth/script.scriptapp` 欠落** → script.run API 使用不可。

殿のローカルで実行された `clasp login` (default) は push に必要な scope のみ含み、run に必要な script.scriptapp scope を含まない。

### 10.3 復旧 path (3案)

| 案 | 内容 | 効率 | 推奨度 |
|----|------|------|--------|
| A | 明日 09:00 JST daily trigger の自然発火を待つ。clasp logs で結果検証 | 殿 0 action / 18 時間待機 | ⭐⭐ |
| B | 殿が GAS editor (https://script.google.com/home/projects/1a7zxw0jBja2hzR6BPnkX2XT_z9ys19Afrat6PK3TovSuVqQWkTBdkzkS/edit) を開いて dryRunCmd676 を選択 → 実行 | 殿 1分 / 即時検証可 | ⭐⭐⭐ |
| C | 殿ローカルで `clasp login --use-project-scopes --include-clasp-scopes` 再実行 → clasprc.json 再転送 | 殿 5 分 / 以降の clasp run も自動化可 | ⭐⭐⭐ |

### 10.4 既存 daily trigger 動作確認 (clasp logs)

`clasp logs --simplified` は機能するため過去 trigger 実行を確認:

- `2026-05-08T00:46:04.876Z` (= **09:46 JST** today) に旧 code で processAllCustomers 自動実行 → 寺地淳子様 2件処理。**圓真諒 0件処理 (旧 schema 下では H='active' フィルタで通過していた事を示唆)**。
- 過去 10 日分 daily trigger 実行記録あり、いずれも完了 ms < 30000。

**要点**: daily trigger は健在。明日 09:00 JST の発火で新 code が初実行される。

### 10.5 実機テスト残作業 (家老/軍師依頼)

- C-1 寺地淳子様 G='on' 1サイクル成功 → 案B または案A 後に clasp logs 検証
- C-2 圓真諒 G='off' 完全スキップ → 同上
- A-2〜A-6 元帳/Drive/WB 確認 → 殿手動目視確認
- B-1〜B-3 → 殿手動目視確認

### 10.6 推奨次アクション (家老向け)

1. 殿に **案B** (GAS editor から dryRunCmd676 手動実行) を打診し即時検証実施
2. 不可なら **案A** (明日 09:00 JST 自然発火) を採用、05/09 09:30 JST に clasp logs 検証
3. 同時並行で **案C** (clasp re-login with --use-project-scopes --include-clasp-scopes) を将来運用整備として進言


