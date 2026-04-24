# cmd_585 AR4 escalate備え: clasp再authorize手順書

作成日時: 2026-04-25T04:35:27+09:00
対象: `/home/ubuntu/gas-mail-manager/`
目的: GAS 側 GCP project を `n8ntry-477615` に切替した際に、`clasp run` / `clasp logs` 用 OAuth を再確立する。

## 0. 事前確認（現状）
実行結果:
- `.clasp.json`: `/home/ubuntu/gas-mail-manager/.clasp.json` 存在
- `projectId`: `kaji-487204`
- `creds.json`: `/home/ubuntu/gas-mail-manager/creds.json` 存在

補足:
- `.clasp.json` は scriptId / projectId の紐付け情報。
- `clasp login --creds ...` は user-provided OAuth client を使って `.clasprc.json` / `creds.json` を更新する運用。

## 1. a) n8ntry-477615でOAuth 2.0 Client(Desktop)作成
1. GCP Console で project を `n8ntry-477615` に切替。
2. `APIs & Services > Credentials` へ移動。
3. `CREATE CREDENTIALS > OAuth client ID`。
4. Application type は `Desktop app` を選択。
5. 作成後、`client_secret_*.json` をダウンロード。

注意:
- `clasp` 公式 README 上、`clasp login --creds <filename>` 用に Desktop client が必要。

## 2. b) client_secret_*.json を VPS へ転送
ローカルPCからVPSへ（例）:
```bash
scp ~/Downloads/client_secret_*.json ubuntu@<VPS_HOST>:/home/ubuntu/gas-mail-manager/
```

VPS内で確認:
```bash
ls -l /home/ubuntu/gas-mail-manager/client_secret_*.json
```

## 3. c) clasp login --creds 実行
```bash
cd /home/ubuntu/gas-mail-manager
npx clasp login --creds client_secret_*.json
```

補足:
- ブラウザ認証で対象Googleアカウントを選ぶ。
- `--use-project-scopes` が必要な運用なら追加:
```bash
npx clasp login --creds client_secret_*.json --use-project-scopes
```

## 4. d) 新 credentials 生成確認
```bash
ls -l /home/ubuntu/gas-mail-manager/creds.json
ls -l ~/.clasprc.json
npx clasp show-authorized-user --json
```

確認ポイント:
- `creds.json` / `.clasprc.json` の更新時刻が再authorize後になっていること。
- `show-authorized-user` で authorized 状態を確認できること。

## 5. e) clasp run で動作確認
```bash
cd /home/ubuntu/gas-mail-manager
npx clasp run generateSummaryTest
```

失敗時の追加確認:
- Apps Script API が有効か（`script.google.com/home/usersettings`）
- GAS 側「Project Settings > Google Cloud Platform (GCP) Project」の紐付けが意図通りか
- 実行Googleアカウントが script への編集権限を保持しているか

## ToS / API_KEY_SERVICE_BLOCKED 調査メモ（cmd_585 Scope I）
結論（現時点）:
- `API_KEY_SERVICE_BLOCKED` は Google 公式定義では「API key restriction違反」。
- したがって、ToS未受諾そのものが直接この reason を返す一次原因とは断定しづらい。
- ToS関連の問題は、別系統のエラー（例: AI Studio側 403 Access Restricted、consumer suspended 等）として出る可能性が高い。

実務的チェック順:
1. API key restriction（API制限/アプリ制限）を最優先確認。
2. 次に AI Studio / Gemini ToS 同意状態と利用可能地域を確認。
3. それでも unresolved の場合、billing / project suspension / leaked key ブロックを確認。

補足:
- AI Studio docs では 403 Access Restricted は ToS不適合やリージョン不一致の可能性が示される。
- Gemini API key docs では「ToS受諾後に default project / key が作成される」と明記される。

## 参照
- https://developers.google.com/apps-script/guides/clasp
- https://github.com/google/clasp
- https://ai.google.dev/gemini-api/docs/api-key
- https://ai.google.dev/gemini-api/docs/troubleshoot-ai-studio
- https://docs.cloud.google.com/php/docs/reference/common-protos/latest/Api.ErrorReason
- https://stackoverflow.com/questions/78738590/unable-to-restrict-generative-language-api-key-on-google-cloud
