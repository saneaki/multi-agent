---
name: shogun-gas-clasp-rapt-reauth-fallback
description: clasp push 実行時に invalid_rapt / invalid_grant エラーが発生した場合の復旧パターン
type: operational
battle_tested: cmd_486 (2026-04-09) / cmd_564 (2026-04-24) / cmd_565 (2026-04-24)
tags: [shogun, gas, clasp, oauth, rapt, fallback]
---

# shogun-gas-clasp-rapt-reauth-fallback

## Trigger
`clasp push` 実行時に以下エラーが発生する場合:
```
{"error":"invalid_grant","error_description":"reauth related error (invalid_rapt)"}
```

## 原因
- OAuth OOB (Out-of-Band) フロー廃止 (Google, 2022-10) により、VPS などの
  headless 環境での `clasp login` が不可能になった。
- VPS 側の `~/.clasprc.json` (または `/root/.clasprc.json`) の refresh_token が
  RAPT 再認証境界を越えると、VPS からの再認証が不可能。
- 症状: `clasp push` exit=0 だが stdout に error JSON が出力される (clasp 3.3.0 時点)。

## 復旧手順 (案A: ローカル clasp login 経由)
1. 殿のローカル PC で: `npm install -g @google/clasp && clasp login`
2. ブラウザで Google 認証ダイアログが起動するので承認。
3. 生成された `~/.clasprc.json` の **全内容** を家老に安全な経路で送付。
4. 家老が VPS 側の `/home/ubuntu/.clasprc.json` を上書き:
   ```bash
   # VPS 側で実行 (受け取った内容で上書き)
   cat > /home/ubuntu/.clasprc.json << 'EOF'
   <clasprc.json の内容>
   EOF
   ```
5. 家老が `cd /home/ubuntu/gas-mail-manager && clasp push` を再実行。
6. "Pushed N files." が出力されれば成功。

## 復旧手順 (案B: GAS editor 直接編集)
1. GAS project URL を開く:
   `https://script.google.com/home/projects/<scriptId>/edit`
2. diff を参照して各ファイルを手動で編集・保存。
3. GAS editor 上部で対象関数を選択 → 実行。

## scp を使った転送例
```bash
# 殿ローカル PC で:
scp ~/.clasprc.json ubuntu@<VPS_IP>:/home/ubuntu/.clasprc.json
```

## Non-goals
- `clasp login --no-localhost`: OAuth OOB 廃止のため現在は動作しない。
- VPS 上での `clasp login`: ブラウザが必要なため不可 (headless 環境)。

## 予防策
- `~/.clasprc.json` の有効期限は Google OAuth refresh_token の policy に依存。
  定期的 (3〜6ヶ月ごと) に殿ローカルで `clasp login` を実行し clasprc.json を更新推奨。
- Gas project を更新する際は VPS 側の clasp 認証が有効か事前確認を推奨。

## 関連
- cmd_486: 初回 auth 切れ発生
- cmd_564: 同一問題再現、fallback 手順書作成
- cmd_565: 本 fallback 適用で復旧・skill 資産化

## scope 不足 vs RAPT 切り分け (cmd_676/680 統合)

`clasp run` / `gas_run_oauth.sh` の 403 系エラーは **2 つの異なる根因** に分かれる。
復旧手順は同じ「ローカル再ログイン + clasprc 転送」だが、フラグと runbook 文言を分けるべき。

### 切り分けマトリクス

| 症状 | 根因 | 復旧フラグ |
|------|------|-----------|
| `invalid_grant` / `invalid_rapt` | refresh_token 失効・RAPT 再認証境界 | 通常 `clasp login` で可 |
| HTTP 403 + `script.scriptapp scope` 必要 | clasp 既定 scope に manifest scope 未含 | `--use-project-scopes --include-clasp-scopes --creds creds.json` 必須 |
| HTTP 403 + Cloud project 不一致 | GAS と caller の Cloud Project 不一致 | `.clasp.json` の `projectId` 確認 + GAS editor で関連付け |

### 推奨フラグ (cmd_676 fix → cmd_680 確認)

```bash
# 殿ローカル PC で:
clasp login --creds creds.json --use-project-scopes --include-clasp-scopes
# clasp 3.x で user 指定が必要な場合:
clasp login --user default --creds creds.json --use-project-scopes --include-clasp-scopes
```

scope 確認 (token に `script.scriptapp` 等の manifest scope が含まれるか):

```bash
# secret 値は出さず、含有 scope のみ確認
TOKEN=$(jq -r '.token.access_token // .access_token' /home/ubuntu/.clasprc.json)
curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN" | jq '.scope'
```

`https://www.googleapis.com/auth/script.scriptapp` が含まれていれば scope は十分。

### Battle-Tested (scope 補強)

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_676 | `clasp run dryRunCmd676` が 403 で失敗。tokeninfo に `script.scriptapp` 欠落 | `--use-project-scopes --include-clasp-scopes` で再ログイン後 PASS |
| cmd_680 | Codex 独立調査で公式 google/clasp `docs/run.md` の手順と完全一致確認 | 短期は creds 再認証、中期は Web App 化 |

### Non-goals (cmd_680 確認)

- `clasp login --adc`: Service Account / ADC は **EXPERIMENTAL/NOT WORKING** (公式 README 記載)。
- `scripts.run` を Service Account で呼ぶ: Apps Script API 公式が SA 不可と明記。
- `clasp login --no-localhost`: OAuth OOB 廃止 (2022-10) のため現在は動作しない。

### 関連 cmd
- cmd_676: scope 不足 403 の発見と修正
- cmd_680: Codex 独立調査による短期/中期判断 (短期=creds再認証、中期=Web App化)

## clasp run 完全代替フォールバック (cmd_707 統合)

> SC-shogun-gas-clasp-run-creds-fallback: このセクションに包含。cmd_726b で統合 (ash3/gunshi 評価 — cmd_707 ash6 由来)。

`clasp run` 自体が OAuth/scope 問題で回復不能な場合、または VPS 環境で `clasp login` が困難な場合の代替実行手段。

### 代替手段マトリクス

| 手段 | 条件 | 手順 |
|------|------|------|
| GAS Editor 直接実行 | ブラウザアクセス可能 | `script.google.com` → 対象関数選択 → 実行ボタン |
| time-based trigger | 定期実行で可 | GAS Editor → トリガー → 時刻ベーストリガー設定 |
| clasp login --creds | creds.json 取得済み | `clasp login --creds creds.json --use-project-scopes --include-clasp-scopes` |
| API executable 配備 | Apps Script API 有効化済み | Web App または doPost エンドポイント経由で実行 |

### clasp login --creds フロー (VPS 対応)

```bash
# 1. 殿ローカル PC で creds.json を生成
#    GCP Console → API & Services → OAuth 2.0 Client IDs → Desktop app → JSON DL

# 2. VPS に転送
scp creds.json ubuntu@<VPS_IP>:/home/ubuntu/

# 3. VPS で scope 付き再ログイン
cd /home/ubuntu/gas-mail-manager
clasp login --creds /home/ubuntu/creds.json \
    --use-project-scopes --include-clasp-scopes

# 4. 実行確認
clasp run <function-name>
```

### GAS Editor 直接実行 (最短 fallback)

1. `https://script.google.com/home/projects/<scriptId>/edit` を開く
2. 上部ドロップダウンで対象関数を選択
3. 「実行」ボタンをクリック
4. 実行ログでエラーがないことを確認

### Battle-Tested (clasp run fallback)

| cmd | 状況 | 結果 |
|-----|------|------|
| cmd_707 | clasp run が OAuth scope 不足で失敗。GAS Editor 直接実行で回避 | PASS: Editor 経由で function 実行確認 |
