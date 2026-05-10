# スキル履歴アーカイブ

dashboard.md 🛠️スキル欄から溢れた全エントリ。最新順（上が新しい）。
直近5件は dashboard.md に掲載中。ここにはそれ以降の全履歴を保持する。

## アーカイブ済みエントリ

| スキル名 | 出典 |
|----------|------|
| **daemon-health-monitor-process-vs-log-stale** | ash3 cmd_695: daemon監視で process_alive と log_stale を分離し、idle daemon には watcher_supervisor の roll-call を secondary heartbeat (health_evidence) として扱う pattern。process生存 + supervisor roll-call ALIVE で GREEN 判定し、log mtime stale だけで RED にしない。 inbox_watcher / cmd_complete_notifier 等の idle daemon に再利用可能。 | 承認待ち |
| **shogun-gas-clasp-rapt-reauth-fallback** 更新 ✅ | cmd_682 (2026-05-08): `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` (62→110行)。cmd_676/680 知見「scope 不足 vs RAPT 切り分け」セクション追記。切り分けマトリクス + `--use-project-scopes --include-clasp-scopes` 推奨フラグ + tokeninfo 確認手順 + Non-goals (clasp --adc / SA / OOB)。cmd_676 fix → cmd_680 公式 docs/run.md 一致確認 battle-tested。 |
| **shogun-gas-automated-verification** 更新 ✅ | cmd_682 (2026-05-08): `skills/shogun-gas-automated-verification/SKILL.md` (129→191行)。cmd_680 中期戦略「clasp run 依存からの脱却」セクション追記。役割分担表 (日常 run = Web App / deploy = clasp push / 緊急 = clasp run) + Web App endpoint 設計 + Service Account 制約マトリクス + scope 不足 runbook 分離。 |
| **shogun-n8n-notion-trigger-v1-flat-access** ✅実装済み | cmd_475 → cmd_682 (2026-05-08): `~/.claude/skills/shogun-n8n-notion-trigger-v1-flat-access/SKILL.md` (105行)。n8n Notion Trigger v1 が properties をトップレベルにフラット展開する仕様の対処。silent inconsistency (cmd_675b 監査で既配置 SKILL.md が skill_history 未登録判明) → cmd_682 で正式 ✅実装済 化。 |
| **shogun-n8n-manual-execution-api** ✅実装済み | cmd_296 → cmd_682 (2026-05-08): `~/.claude/skills/shogun-n8n-manual-execution-api/SKILL.md` (418行)。内部 API `/rest/workflows/{id}/run` の workflowData/triggerToStartFrom 必須仕様 + Cookie n8n-auth 必須 (API キー/Basic 不可)。silent inconsistency (skill_history「(補足)/承認待ち」表記だが skill 既配置) → cmd_682 で ✅実装済 化に格上げ。 |
| **shogun-n8n-notion-stale-data-cleanup** ✅統合済み | cmd_291/293 → cmd_682 (2026-05-08): `~/.claude/skills/shogun-n8n-notion-property-sync/SKILL.md` (461行) L345-/L406-/L458-459 に既包含確認。stale draftId / 偽陽性 checkbox バッチ修復 (116件 + 328件) + Notion Query API ページネーション (max 100/call) のパターン。新規追記不要、skill-creation-workflow §2 統合検討で merged 化。 |
| **shogun-n8n-gmail-trigger-manual-exec-single-item** ✅統合済み | cmd_297 → cmd_682 (2026-05-08): `~/.claude/skills/shogun-n8n-sib-trigger-incompatibility/SKILL.md` (244行) §4 (Gmail Trigger 手動実行制約) に既包含確認。非アクティブ WF が 1 通/exec のみ返す症状・原因・active 化 + ポーリング待機手順。新規追記不要、§2 統合検討で merged 化。 |
| **shogun-n8n-sib-loopback-multi-input-guard** ✅統合済み | cmd_297 → cmd_682 (2026-05-08): 同上 §2 (SiB 複数ループバック入力の暗黙 JOIN 停止) に既包含。Merge(append) で loop-back を 1 本化する回避策・SC-022 設定詳細を含む。新規追記不要、§2 統合検討で merged 化。 |
| **shogun-n8n-code-node-multi-item-index** ✅統合済み | cmd_290 → cmd_682 (2026-05-08): 同上 §3 (Code node `$input.all()` インデックスバグ cmd_290) に既包含。`$('nodeName').item` ループ内非連動 → `$('nodeName').all()[index].json` 解法。n8n-code-javascript SC-023 にも関連記載。merged 化。 |
| **shogun-n8n-gmail-oauth2-http-request** ✅統合済み | cmd_287c3 → cmd_682 (2026-05-08): `~/.claude/skills/n8n-http-credential-patterns/SKILL.md` (360行) §3 (Gmail OAuth2 HTTP Request 設定 SC-024) に既包含。authentication / nodeCredentialType 必須設定 + Gmail API エンドポイント早見表。merged 化。 |
| **n8n-http-predefined-credential** ✅統合済み | cmd_277 → cmd_682 (2026-05-08): 同上 §2 (predefinedCredentialType パターン SC-026) に既包含。Code node の httpRequestWithAuthentication 不可の回避策 + 主要 Credential Type ID 一覧。merged 化。 |
| **shogun-gemini-thinking-token-guard** ✅実装済み | cmd_675b (2026-05-08): `skills/shogun-gemini-thinking-token-guard/SKILL.md`。Gemini 2.5 系 maxOutputTokens/thinking 予算問題のスキル化。cmd_674 監査で skill_history 未登録判明、cmd_675b で正式 ✅実装済み 化 (audit gunshi 判定 c=既存実装済)。 |
| **shogun-rule-inventory-pattern** ❌棄却 | cmd_566 (ash3) → cmd_675b (2026-05-08): 棄却理由 = 5 行以下の自明手順 (`grep -E '^[A-Z][0-9]+' instructions/*.md` + qc_checklist.yaml 読取の組合わせ)。スキル化価値が低い (1 sh script で十分)。audit gunshi 判定 c=棄却。 |
| **shogun-qc-auto-check-naming-mode-pattern** ❌棄却 | cmd_552 → cmd_675b (2026-05-08): 棄却理由 = 1 sh script (qc_auto_check.sh) の機能拡張で汎用化価値が低い。他 sh script への横展開価値が薄く (各 script で独立判断)、スキル化不要。existing script のリファクタリング範疇。audit gunshi 判定 c=棄却。 |
| **shogun-gas-clasp-rapt-reauth-fallback** ✅実装済み | cmd_565 (2026-04-24): ash1 `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md`(62行)。clasp push 時 invalid_rapt/invalid_grant エラーの復旧パターン。OAuth OOB 廃止による VPS headless 環境での再認証不可問題。案A: ローカル clasp login → clasprc.json 転送 / 案B: GAS editor 直接編集。cmd_486/564/565 で 3 回実証済み。(cmd_675 にて skill_history 移行 / cmd_675b で正式 ✅化確定 audit gunshi 判定 c=既存実装済) |
| **shogun-gas-automated-verification** ✅実装済み | cmd_567 (2026-04-24): ash1 `skills/shogun-gas-automated-verification/SKILL.md`(129行)。GAS の clasp run + clasp logs 自動化基盤。Ubuntu VPS から自動テスト実現のための GCP Standard Cloud Project 設定・OAuth デスクトップ認証・Logger.log 互換性知見を体系化。よくある落とし穴5パターン収録。(cmd_675 にて skill_history 移行 / cmd_675b で正式 ✅化確定 audit gunshi 判定 c=既存実装済) |
| **shogun-gas-backfill-pattern** ✅実装済み | cmd_585/590 (2026-05-01 dashboard 候補→skill 化): 将軍 `skills/shogun-gas-backfill-pattern/SKILL.md`(218行)。GAS UrlFetchApp.fetchAll 並列 backfill (chunk=5)、force=false/true モード、resume on failure、trigger 完遂検出 (auto-delete) を体系化。実証: 寺地 Gmail thread 11年分 93件を 3m47s で完遂 (5x serial 比)。 |
| **shogun-bash-daemon-restart-subcommand-pattern** ✅実装済み | cmd_546 (2026-05-01 dashboard 候補→skill 化): 将軍 `skills/shogun-bash-daemon-restart-subcommand-pattern/SKILL.md`(197行)。systemd 非依存の bash daemon に `restart` サブコマンド追加。mode 引数 parse / lockfile + pgrep 二段 / kill -TERM 5秒 deadline / nohup spawn + PID 再検証 / stale lockfile 回復を体系化。 |
| **shogun-tmux-busy-aware-send-keys** ✅実装済み | cmd_582 (2026-05-01 dashboard 候補→skill 化): 将軍 `skills/shogun-tmux-busy-aware-send-keys/SKILL.md`(174行)。tmux send-keys で Enter 前に Claude idle を待つ wait_until_idle() (poll 0.5s/timeout 30s) + pane 整合チェック + stale pane 自動再検出を体系化。A-3 race condition 解消。 |
| **shogun-karo-task-validator** ✅統合済み | cmd_573 (2026-05-01 dashboard 候補→shift-left-validation-pattern 統合): `~/.claude/skills/shift-left-validation-pattern/SKILL.md` §適用事例に追記 (266→281行)。entry-anchor 正規表現分割 + 4層フィールド分類 + CRITICAL/HIGH/MEDIUM/LOW severity tier + bypass audit log YAML append。横展開対象: report YAML / dashboard.md。 |
| **shogun-l017-dual-model-smoke-qc** ✅統合済み | cmd_608 (2026-05-01 dashboard 候補→shogun-error-fix-dual-review 統合): `skills/shogun-error-fix-dual-review/SKILL.md` Variant 1 として追記 (200→272行)。L017 dual-model smoke test + gunshi north_star QC (N1-N4) + Go/NoGo 判定。新ルール/スクリプト/skill の実装品質保証。5回適用達成 (cmd_605/606/607/608 で安定運用)。 |
| **shogun-dual-model-layered-research** ✅統合済み | cmd_609 (2026-05-01 dashboard 候補→shogun-error-fix-dual-review 統合): 同上 Variant 2 として追記。Opus arm=構造設計層 + Codex arm=実装コード層 → 軍師が独立性確認 + 2層根本原因統合。silent failure / 設計バグ / 複合原因の構造分析。6回標準化達成。cmd_609 で 2層独立原因 (A4 parse bug + C5 閾値固定) を発見。 |
| **shogun-dashboard-sync-silent-failure-pattern** ✅実装済み | cmd_621 Scope B (2026-05-01): ash4(Opus) `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md`(145行)。dashboard.yaml→dashboard.md 同期 silent failure の 4 incident (cmd_607/615/619/agent-vs-assignee) と 5 pattern (P1-P5) を体系化。診断チェックリスト + cmd_620 Scope A/C/D 防止策マッピング + 横展開対象 (queue/reports, inbox, task YAML)。出典: output/cmd_620_scope_b_incident_analysis.md (229行)。 |
| **shogun-tmux-busy-aware-send-keys** | cmd_582 ash6(Sonnet+T): tmux send-keys で Enter 前に Claude idle を待つ wait_until_idle() パターン。A-3 race condition 解消。poll 0.5s / timeout configurable / WARN+fallback。pane整合チェック+stale pane 自動再検出。cmd_complete 通知 reliability 強化。battle-tested 条件: 1w 後 3 cmd_complete 通知で実測確認後に正式スキル化推奨。 | 承認待ち |
| **shogun-l017-dual-model-smoke-qc** | cmd_608 gunshi(Opus+T) 推奨: L017 dual-model smoke test + gunshi QC パターン (5回適用実績)。Claude arm + Codex arm を並列 dispatch → 独立検証 → gunshi north_star QC (N1-N4) → Go/NoGo 判定。典型適用: 新ルール/スクリプト/skill の実装品質保証。cmd_605/606/607/608 で安定運用確認。skill化推奨条件: 5回適用達成 (本cmd_608で達成)。 | 承認待ち |
| **shogun-dual-model-layered-research** | cmd_609 gunshi(Opus+T) 推奨: dual-model 異レイヤー研究 + gunshi 統合パターン (6回目で標準化)。Opus arm=構造設計層 (設計パターン/アーキテクチャ分析) + Codex arm=実装コード層 (コード分析/バグ特定) → gunshi が両arm独立性を確認し2層根本原因を統合。典型適用: silent failure / 設計バグ / 複合原因 の構造分析。cmd_609で2層独立原因 (A4 parse bug + C5閾値固定) を発見。単一モデルでは見落とす補完関係あり。 | 承認待ち |
| **semantic-gap-diagnosis** ✅実装済み | cmd_559 ash5(Sonnet): `~/.claude/skills/semantic-gap-diagnosis/SKILL.md`(188行)。means(手段完成) vs ends(目的到達) 乖離を検出する4ステップ診断パターン。4cmd実証事例(cmd_550/553/555/556)+gunshi QC discipline(Step 6-b)+gunshi_report means_ends_classification schema統合。gunshi 559g QC Go(2026-04-22)。 |
| **shift-left-validation-pattern** ✅実装済み | cmd_528d→cmd_547(2026-04-20): 軍師(Opus+T) `~/.claude/skills/shift-left-validation-pattern/SKILL.md`(140行/--mode validate/run case分岐+exit code規約+stderr詳細出力+実装テンプレート+適用事例)。足軽1号(Sonnet)作成。 |
| **shogun-precompact-snapshot-e2e-pattern** ✅実装済み | cmd_468c4→cmd_547(2026-04-20): 足軽5号(Opus+T) `~/.claude/skills/shogun-precompact-snapshot-e2e-pattern/SKILL.md`(150行/4シナリオ構造+TMUX_PANE切替+diff -q安全復元+PostToolUse/SessionStart横展開)。足軽1号(Sonnet)作成。 |
| **codex-cli-poc-verification** ✅実装済み | cmd_446→cmd_472a1(2026-04-08): 足軽6号(Codex) `~/.claude/skills/codex-cli-poc-verification/SKILL.md`(75行/フロントマター完備/検証手順+典型エラー対処)。AC3/3 PASS。 |
| **python-utf8-errors-replace** ✅実装済み | cmd_457→cmd_472a2(2026-04-08): 足軽2号(Sonnet) `~/.claude/skills/python-utf8-errors-replace/SKILL.md`(6377bytes/Before&After例+横展開対象3ファイル特定)。AC 4/4 PASS。 |
| **notion-session-log-section-pattern** ✅実装済み | cmd_458→cmd_472a3(2026-04-08): 足軽3号(Sonnet) `~/.claude/skills/notion-session-log-section-pattern/SKILL.md`(159行/正規表現パターン+アンチパターン+errors=replace注意事項)。AC 4/4 PASS。 |
| **n8n-daily-guard-pattern** ✅実装済み | cmd_466 d1_opus→cmd_472a4(2026-04-08): 足軽7号(Opus) `~/.claude/skills/n8n-daily-guard-pattern/SKILL.md`(237行/8ノード雛形 L26-+3軸代替案テンプレ L175+feedback-system.json参照 L219)。AC 5/5 PASS。 |
| **shogun-compaction-log-analysis** ✅実装済み | cmd_468→cmd_472a5(2026-04-08): 足軽4号(Opus+T) `~/.claude/skills/shogun-compaction-log-analysis/SKILL.md`(11829bytes/336行/解析6コマンド+agent識別3手法+精度マトリクス/200行ログで実機検証済)。AC 4/4 PASS。 |
| **switch_cli-yaml-section-tracking** ✅統合(重複解消) | cmd_448→cmd_472(2026-04-08): 既存 shogun-switch-cli-yaml-update-guard スキルと実質重複のため新規作成せず削除。重複解消はcmd_472配備時に将軍が判断。 |
| **switch-cli-yaml-update-guard** ✅実装済み | cmd_446→cmd_448: switch_cli.sh update_settings_yaml() formations破壊バグ。in_cli_agentsフラグによるセクションスコープ追跡+cli_typeキー統一。~/.claude/skills/shogun-switch-cli-yaml-update-guard/SKILL.md。commit subtask_448c2(足軽1号)。 |
| **bypass-permissions-write-fix** ✅実装済み | cmd_423→cmd_440: bypass permissionsモードで.claude/配下Write/Edit/Bash確認プロンプト回避。3-Layer Fix(defaultMode+PermissionRequest hook+hookスクリプト)。230行SKILL.md。commit 5fd85bc(足軽1号)。 |
| **n8n-gmail-subject-case-sensitivity** ✅実装済み | cmd_427→cmd_440: n8n Gmail node downloadAttachments:true時PascalCase問題。3ソリューション(ORフォールバック/Object.keys()/正規化ノード)+Prevention CL。271行SKILL.md。commit 972178c(足軽2号)。 |
| **github-release-version-migration** ✅実装済み | cmd_439→cmd_440: GitHub API PATCHリリースメタデータ変更+gitタグ削除→再作成。一括移行スクリプト+Safety+ロールバック+Real Example(v1.0.x→v0.8.x)。326行SKILL.md。commit 5fd85bc(足軽3号)。 |
| **github-actions-release-artifact** ✅実装済み | cmd_411→cmd_419: GITHUB_TOKEN permissions 403エラー+artifact upload/download方式+ubuntu-latestリリース。8セクション構成SKILL.md。commit 93d22de(足軽3号)。 |
| **pyinstaller-pymupdf-dll-bundling** ✅実装済み | cmd_413→cmd_419: PyMuPDF DLLバンドル漏れ→サイレントクラッシュ。collect_dynamic_libs('pymupdf')追加+hiddenimports修正+デバッグ手法。commit e40b12f(足軽4号)。 |
| **github-actions-powershell-continueonerror** ✅実装済み | cmd_413→cmd_419: Windows runner PowerShell互換性問題。continue-on-error:true vs shell:bash判断基準+実例。commit 3f990fe(足軽5号)。 |
| **n8n-gcal-api-pagination-guard** ✅実装済み | cmd_392→cmd_407: GCal API maxResults未指定(デフォルト250件)で643件中393件が未同期になったバグ。maxResults=2500設定・nextPageToken警告ログ・HTTP Request v4.2組込みページネーション($input.all()結合)の3パターン収録。Google API横展開(Drive/Gmail等)含む。SKILL.md作成済み。 |
| **n8n-gcal-allday-end-date-fix** ✅実装済み | cmd_404→cmd_407: GCal終日イベントend.date排他仕様(exclusive)とn8nのinclusive解釈のズレによる+1日ズレバグ。-1日補正パターン+JavaScriptコード例+検証方法。フラットファイル作成済み。 |
| **n8n-gmail-downloadattachments-from-uppercase** ✅統合 | cmd_389→cmd_390: shogun-n8n-gmail-id-archive-patternに統合済み。downloadAttachments=true時のemail.From大文字問題+フォールバックコード。 |
| **n8n-continueOnFail-audit-pattern** ✅統合 | cmd_388→cmd_390: n8n-pipeline-cut-guardに統合済み。continueOnFail=trueによるデータエラー隠蔽の検出・修正パターン。 |
| **shogun-ir1-implicit-allowlist-pattern** ✅ | cmd_376→cmd_390: IR-1 Hookのimplicit allowlistパターン(agent YAML/SKILL.md/target_path)3種+editable_files設定方法+task YAML設計ガイドライン。SKILL.md 176行作成済み。 |
| **shogun-labor-status-case-analysis** ✅ | cmd_387→cmd_390: 在宅勤務者・業務委託者の労働者性判断フレームワーク(昭和60年報告6要素+判例3件+チェックリスト10項)。SKILL.md 174行作成済み。 |
| **n8n-filesystem-v2-binary-workaround** ✅ | cmd_369→cmd_390: n8n filesystem-v2バイナリストレージ環境でbinaryData.dataが参照文字列を返す問題。getBinaryDataBuffer()等での回避。shogun-n8n-filesystem-v2-binary SKILL.md実装済み。 |
| **shogun-n8n-jq-false-alternative-guard** ✅ | cmd_332(SC-040): jq `//`演算子はfalseも偽値扱い。独立スキル95行作成済み。 |
| **shogun-obsidian-legal-templater-design** ✅ | cmd_386→cmd_390: 法律文書向けObsidianテンプレート設計パターン(Templater7種+Dataview4種)。SKILL.md 169行作成済み。 |
| **bash-crlf-write-tool-guard** ✅ | cmd_334(SC-043): WriteツールCRLF混入の診断・修正・予防パターン。257L/8セクション。push b8ec13f。 |
| **n8n-credential-oauth-refresh** ✅ | cmd_354→cmd_390: n8n API方式(推奨)+SQLite直接(代替)+OAuth refresh→access_token+Google Sheets API直叩き+セキュリティ+トラブルシュート。SKILL.md 362行作成済み。 |
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
| **n8n-drive-ai-text-injection** ✅ | cmd_277→cmd_390: Drive _ai_text/サブフォルダからmd読み込み→Geminiプロンプト注入パターン。コスト制御(3件/12000字/30000字)含む。SKILL.md 277行作成済み。 |
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

## 2026-05-02 cmd_631 で廃止: notion_session_log.sh

二重記録問題解消のため廃止。新システム (session_to_obsidian.sh + generate_notion_summary.sh
+ daily-notion-sync.yml on saneaki/obsidian) に置換。詳細は output/cmd_631_requirements.md
+ output/cmd_631_specification.md 参照。アーカイブ: scripts/archived/notion_session_log.sh

## 2026-05-10 cmd_698: skill_candidate already-reflected confirmation

ash3 が cmd_698 で skill_candidate.found=true を報告:
- 'n8n Code node から外部APIを呼ぶ際、fetchではなく this.helpers.httpRequest を使う必要がある'
- 'Gmail nodeのSubject/From大文字キーとsnippet fallback を考慮する実装パターン'

軍師 cross-reference 結果: 既存 skill で完全カバー済 (battle-tested 強化のみ):
- `~/.claude/skills/n8n-code-javascript/SKILL.md` が `$helpers.httpRequest()` を明示
- `~/.claude/skills/n8n-gmail-subject-case-sensitivity/SKILL.md` (cmd_427→440 で実装済) が Subject/From PascalCase を網羅

dashboard 🛠️ への追記は不要 (重複防止)。本 cmd_698 は両 skill の battle-tested 強化事例として記録。
