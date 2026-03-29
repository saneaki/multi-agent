# スキル履歴アーカイブ

dashboard.md 🛠️スキル欄から溢れた全エントリ。最新順（上が新しい）。
直近5件は dashboard.md に掲載中。ここにはそれ以降の全履歴を保持する。

## アーカイブ済みエントリ

| スキル名 | 出典 |
|----------|------|
| **n8n-credential-oauth-refresh** | cmd_354: n8n SQLite復号→OAuth refresh_token→access_token取得→Google Sheets API直叩きパターン。スキル化承認待ち |
| **skill-creation-workflow** ✅ | cmd_340(SC-045): スキル候補→評価→統合/新規判断→SKILL.md作成→更新→pushの標準プロセス。171L新規作成。 |
| **shogun-n8n-wf-version-switch-checklist** ✅ | cmd_344(SC-046): WFバージョン切替時のスクリプトWF_ID更新チェックリスト。grep -r洗い出し・dual-active防止・実例付き。SKILL.md 122行新規作成。 |
| **shogun-n8n-runners-enabled-deprecation** → 統合済 | cmd_331→cmd_332: trigger-stuck-recoveryに統合済み。 |
| **skill-creation-workflow** ✅ | cmd_340(SC-045): スキル候補評価→統合/新規判断→SKILL.md作成→更新→push の標準プロセスをメタスキルとして171L新規作成。 |
| **shogun-n8n-trigger-stuck-recovery** 更新 ✅ | cmd_340(SC-044): docker restart escalation(deactivate/activate不能な固着+Offer expiredなしSTALL新知見+watchdog設計)追加。322L→391L。 |
| **n8n-http-credential-patterns** ✅ | cmd_321新規: SC-024(HTTP認証パターン)+SC-026(credential設定)統合。345L新規作成。 |
| **bash-crlf-write-tool-guard** ✅ | cmd_334(SC-043): WriteツールでbashスクリプトにCRLF混入→set -euo pipefailが「invalid option name」で失敗。診断(cat -A/file/hexdump)+修正(sed -i 's/\r//')+予防策を257行に体系化。 |
| **shogun-gemini-markdown-json-guard** ✅ | cmd_324: Gemini 2.5 FlashがJSON応答を```json...```でラップする問題の対処パターン。JSON.parse前にMarkdownブロック除去。将来はresponseMimeType設定で根本解決。 |
| **shogun-n8n-jq-false-alternative-guard** ✅ | cmd_332(SC-040): jq `//` 演算子がfalseを偽値扱いするバグ。n8n API `.active` 解析で誤判定。`\| tostring` で回避。独立スキル95行。 |
| **shogun-n8n-trigger-stuck-recovery** 更新 ✅ | cmd_332(SC-041/042): Poll Trigger Stall(Offer expired主因/Pruning誘発/cron再登録バグ)+ N8N_RUNNERS_ENABLED廃止(v2.7.5)セクション追加。237L→322L。 |
| **n8n-wf-dual-active-guard** ✅ | cmd_325: 同一TriggerのWFが複数active時の二重処理防止。activate前に同一Trigger WFのactive確認必須。旧WFパッチ後はactivateしない運用ルール。 |
| **n8n-code-javascript** ✅ | cmd_321圧縮: 699L→347L(50%削減)。SC-023(runMode切替)/SC-029(パフォーマンス)/SC-030(デバッグ)統合。 |
| **n8n-node-configuration** ✅ | cmd_321圧縮: 785L→300L(62%削減)。SC-026(credential設定)統合。 |
| **shogun-n8n-sib-trigger-incompatibility** ✅ | cmd_321: SC-022(SiB+Trigger制約)+SC-028(Webhook+SiB)統合。244L。 |
| **n8n-code-rfc2822-subject-sanitize** ✅ | cmd_323: RFC2822ヘッダー折り返し(\r?\n\s*)→空文字削除パターン。\n→スペース変換ではGmail検索ミスマッチ発生。 |
| **shogun-n8n-notion-property-sync** ✅ | cmd_321: SC-020(staleデータ116件+328件修復パターン)統合。459L。 |
| **shogun-n8n-continueOnFail-pattern** ✅ | cmd_291: n8n-pipeline-cut-guardに統合済み(外部API onErrorセクション追記)。git a386f39 |
| **shogun-n8n-notion-stale-data-cleanup** | cmd_291/293: Notion DBのstaleデータ(draftId/誤アーカイブ済フラグ)がWF誤動作を引き起こす。cmd_291で116件・cmd_293で328件修復。バッチ処理(page_size:100)でNotionレート制限対応。スキル化承認待ち |
| **shogun-n8n-gmail-id-archive-pattern** ✅ | cmd_295: Gmail ID直接参照アーカイブ+件名サニタイズ吸収。5セクション(件名検索限界/ID保存/API/フォールバック/移行CL)。SKILL.md 246行作成済み。git 589fdda |
| **shogun-n8n-gmail-trigger-manual-exec-single-item** | cmd_297: Gmail Trigger非アクティブWF手動実行は複数未読メールがあっても1通/execのみ返す。複数メール同時処理テストはWF active化+ポーリング待機が必要。スキル化承認待ち |
| **shogun-n8n-sib-trigger-incompatibility** ✅ | cmd_297調査: SiB+Trigger互換性バグ+ループバック暗黙JOIN+Code nodeインデックス+Gmail Trigger手動制約。4セクション統合。SKILL.md 185行作成済み。git 589fdda |
| **shogun-n8n-sib-loopback-multi-input-guard** | cmd_297: SiB(Split In Batches)に複数loop-backを直接接続すると暗黙JOINで処理停止。Merge(appendモード)でloop-backを1本化して回避。shogun-n8n-merge-either-or-branchと関連。スキル化承認待ち |
| **shogun-n8n-manual-execution-api** (補足) | cmd_296: 内部API /rest/workflows/{id}/run はworkflowData+triggerToStartFrom必須。Cookie n8n-auth必須(APIキー/Basic認証不可)。スキル化承認待ち |
| **shogun-n8n-code-node-multi-item-index** | cmd_290: Code nodeで$('nodeName').itemがループ内でインデックス連動しない問題。$('nodeName').all()[index].jsonで解決。スキル化承認待ち |
| **shogun-n8n-gmail-oauth2-http-request** | cmd_287c3: HTTP RequestでGmail OAuth2使用時のauthentication/nodeCredentialType必須パターン。n8n-http-predefined-credentialと統合検討要。スキル化承認待ち |
| **shogun-claude-code-posttooluse-hook-guard** ✅ | cmd_283+284: PostToolUse Hook未発火の診断・修正パターン(matcher構文制約+settings.json優先順位)。SKILL.md 225行作成済み。git a62dcb8 |
| **n8n-drive-ai-text-injection** | cmd_277: Drive _ai_text/サブフォルダからmd読み込み→Geminiプロンプト注入パターン。コスト制御(3件/12000字/30000字)含む。スキル化承認待ち |
| **n8n-http-predefined-credential** | cmd_277: HTTP RequestノードでpredefinedCredentialType使用。Code nodeのhttpRequestWithAuthentication不可の回避策。スキル化承認待ち |
| **shogun-n8n-docx-text-extraction** ✅ | cmd_275+276: n8n docxテキスト抽出3アプローチ(unzip+XML/Mammoth.js/Docs API)。SKILL.md 13KB作成済み。git efcd1cc |
| **shogun-n8n-gmail-trigger-cron-step-guard** ✅ | cmd_267b+272: Gmail Trigger cron */N step値→explicit minute list変換。SKILL.md 187行作成済み。git 41de19a |
| **shogun-notion-inline-db-api-version** ✅ | cmd_242+248+252: is_inline=TrueのNotionDBはAPIバージョン2022-06-28必須。SKILL.md 7.9KB作成済み |
| **shogun-notion-dual-property-relation** ✅ | cmd_248+252: Notion dual_propertyによるDB間リレーション自動設定パターン。SKILL.md 9.5KB作成済み |
| **shogun-n8n-merge-either-or-branch** ✅ | cmd_234+cmd_236: MergeノードでIF分岐統合時は同一index(0,0)に接続すべし。SKILL.md 174行作成済み |
| **n8n-expression-brace-guard** | cmd_184/195 (cmd_229で追記) |
| **notion-multi-source-db** | cmd_188/189/190 |

## 既存スキルファイル参照

他17件 → `~/.claude/skills/` 参照（SKILL.md作成済みのもの）
