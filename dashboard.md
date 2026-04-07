# 📊 戦況報告
最終更新: 2026-04-07 11:29 JST

## 🐸 Frog / ストリーク

| 項目 | 値 |
|------|-----|
| 今日のFrog | 未設定 |
| Frog状態 | 🐸 未撃破 |
| ストリーク | 🔥 29日目継続中 (最長: 29日) |
| 今日の完了 | 3（cmd: 3 + VF: 0） |
| VFタスク残り | 0件（うち今日期限: 0件） |

## 🚨 要対応 - 殿のご判断をお待ちしております

| タグ | 項目 | 詳細 |
|------|------|------|
| [info] | Claude Code .claude/skills パーミッションバグ | v2.1.78以降 .claude/skills がprotected directory exemptionから漏れている(anthropics/claude-code#37157, #38806)。セッション起動時に足軽がskills/操作でprompt停止する。暫定: 選択肢2で手動承認。公式修正待ち。将軍がセッション開始時に修正状況を確認する。 |
| [action] | gas-mail-manager 統合テスト実行(cmd_461) | コード修正完了後、殿の手動操作が必要: (1)ScriptPropertiesにSPREADSHEET_ID・DRIVE_ROOT_FOLDER_ID・GEMINI_API_KEYを設定 (2)テスト用スプレッドシートに元帳シート作成+テスト顧客1行追加 (3)GASエディタでprocessAllCustomers()実行→結果確認。GEMINI_API_KEYはGoogle AI Studio(aistudio.google.com)で無料取得可。 |
| [action] | Notion shogun-feedback FormsビューをUIから手動追加(cmd_464) | n8nが動作確認後に実施。Notion DBページ(https://www.notion.so/01d9f2b401e442e685ecf4b2feb5bfb8)を開き「ビューを追加」→「フォーム」を選択。詳細はdocs/feedback-system-guide.md参照。API制約により自動設定不可。 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_464 | | | 足軽2号(Sonnet)作業中 | assigned |
| cmd_465 | | | 足軽3号(Sonnet)作業中 | assigned |
| cmd_463 | | | 足軽4号(Sonnet)作業中 | in_progress |
| cmd_463 | | | 足軽5号(Sonnet)作業中 | in_progress |
| cmd_464 | | | 軍師(Opus+T)作業中 | assigned |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet) | 待機 | subtask_463_b1_sonnet完了: | |
| 足軽6号(Sonnet) | 待機 | subtask_463_b1_codex完了: | |
| 足軽7号(Sonnet) | 待機 | subtask_463_b2_codex完了: | |

## ✅ 本日の戦果（4/7 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 11:25 | cmd_463 | cmd_463フェーズ2配備完了 — 軍師ドラフト6件(B1×3/B2×3)レビューOK。フェーズ1教訓(agent_tool_tokens統一+公平性AC+Codex差別化)反映済み。B1(jst_now.sh --week): 足軽1(Sonnet)/4(Opus)/6(Codex)。B2(inbox priority L3): 足軽5(Opus)/7(Codex)。B2_sonnet=足軽2号(464b完了後)。cmd_465(dashboard構成員化)=足軽3号同時配備。合計6エージェント稼働中。 | ⚔️ フェーズ2開始 |
| 11:20 | cmd_464 | subtask_464a QC PASS — 足軽1号(Sonnet) Notion "shogun-feedback" DB作成完了。DB ID: 01d9f2b4-01e4-42e6-85ec-f4b2feb5bfb8。フィールド8種(タイトル/種別/詳細/送信者/緊急度/対象プロジェクト/ステータス/作成日時)+全Select設定完了。Forms URL取得(手動設定手順あり: API制約)。docs/feedback-system-guide.md作成。ashigaru2にDB ID通知済み。AC 9/10(1 PARTIAL: Forms自動化API制約 → 許容)。🛠️スキル候補: notion-db-creation-with-schema | ✅ QC PASS |
| 11:20 | cmd_463 | subtask_463_phase2_design完了 — 軍師がcmd_463フェーズ2ドラフト6件作成(output/cmd_463_drafts/)。フェーズ1教訓4点を全タスクに反映。B2_opus版にP0-1 specials自動既読化との干渉検討追加(Opusならではの深掘り)。 | ✅ 設計完了 |
| 08:50 | cmd_463 | subtask_463_a2_opus QC PASS — 足軽5号(Opus+Thinking) inbox_watcher.sh(1232行)Opus深層解析完了。output/cmd_463_a2_opus.md(499行/29KB)に23関数100%カバレッジ+外部cmd11+sourceLib2+ヒアドキュメント4箇所+呼び出し元6系統+mermaid 2図(データフロー+3段階エスカレーション状態機械)+環境変数16+グローバル状態7+エラーハンドリング17箇所+改善提案11件(P0×3/P1×3/P2×5)+優れた点9項目(公平性維持)。鋭い指摘:P0-1 specials自動既読化の責務分離違反でメッセージロスト経路、P0-2 watcher_supervisor死活復旧前提と内部グローバル状態の矛盾、P0-3 Pythonヒアドキュメント年次vCPUコスト概算。agent_tool_used=false。AC 8/8 PASS(足軽5号+軍師QC)。**Opus特性: 深層責務分離検出+片側評価回避+システム俯瞰** | ✅ QC PASS |
| 08:39 | cmd_463 | subtask_463_a2_sonnet QC PASS — 足軽2号(Sonnet) inbox_watcher.sh(1232行)解析。output/cmd_463_a2_sonnet.md(295行)に外部cmd13件+sourceLib2件+呼び出しscript1件+呼び出し元(watcher_supervisor+shutsujin_departure)+データフロー(reads/writes/sends分類+mermaid)+環境変数12件+起動引数3件+エラーハンドリング13箇所+改善提案5件(HIGH×2/MEDIUM×2/LOW×1+各コード例)。agent_tool_used=false。AC 8/8 PASS。**3モデル中最詳細(295行)** | ✅ QC PASS |
| 08:38 | cmd_463 | subtask_463_a1_opus QC PASS — 足軽4号(Opus) Python markdownパーサ3種比較。output/cmd_463_a1_opus.md(164行)に8評価軸スコア(40満点)+pros/cons+用途別マトリクス(Opus追加分析)+URL引用20件。主推奨=markdown-it-py(36/40)。一次情報重視: gh apiでmistuneライセンスをBSD-3に訂正。agent_tool_used=false(WebSearch×4+WebFetch×1+gh api×2 のみ、Task未使用)。AC 5/5 PASS。**Opus特性: 深い推論+用途別マトリクス+URL最多20件** | ✅ QC PASS |
| 08:38 | cmd_463 | subtask_463_a1_sonnet QC PASS — 足軽1号(Sonnet) Python markdownパーサ3種比較。output/cmd_463_a1_sonnet.md(142行)に7評価軸スコア+pros/cons+frontmatter補足+URL引用10件。推奨=markdown-it-py(CommonMark準拠+速度バランス)。agent_tool_used=true(Exploreエージェント並列2本=python-markdown+mistune担当 / markdown-it-py+ベンチ担当)、tokens≈45K。AC 5/5 PASS。**Sonnet特性: 並列Agent活用で効率化** | ✅ QC PASS |
| 08:37 | cmd_463 | subtask_463_a1_codex QC PASS — 足軽6号(Codex) Pythonのmarkdownパーサ3種(python-markdown/mistune/markdown-it-py)比較調査完了。output/cmd_463_a1_codex.md(97行)に5評価軸スコア表(総合25点中markdown-it-py 24点)+pros/cons+URL引用9件+取得制約(MCP無し→curl+raw.githubusercontent.com)。推奨: markdown-it-py(拡張性/frontmatter最高)。agent_tool_used=false(curl中心), tokens=38.5K。AC 5/5 PASS(足軽6号+軍師QC)。**Codex A1初データ取得** | ✅ QC PASS |
| 08:36 | cmd_463 | subtask_463_a2_codex QC PASS — 足軽7号(Codex) inbox_watcher.sh(1232行)解析レポート完了。output/cmd_463_a2_codex.md(143行)に呼び出し先(内部関数9+外部コマンド11)・呼び出し元・データフロー(mermaid)・環境変数16件・エラーハンドリング5箇所・改善提案5件(P1×2/P2×2/P3×1)を網羅。鋭い指摘:.venv/python3固定パス脆弱性。agent_tool_used=true, tokens=52K。AC 8/8 PASS(足軽7号+軍師QC)。**Codex A2初データ取得** | ✅ QC PASS |
| 08:28 | cmd_followup | subtask_464a QC PASS — 足軽4号 difference.md更新+未push 4件 push完了。Category F に output/cmd_462_feedback_system_research.md エントリ追加(line 106)+Keep fork count 59→60+Generated 2026-04-07更新。commit b2a8ed3 push成功。origin/original..HEAD = 0件。AC 4/4 PASS(足軽4号+軍師QC)。**push blocked解消** | ✅ QC PASS |
| 08:19 | cmd_462 | subtask_462d 統合完了 — 構成員フィードバック収集システム方法論調査レポート(9選択肢比較表+評価軸統合+主推奨/補助推奨/Phase別ロードマップ)作成完了。output/cmd_462_feedback_system_research.md(336行/15094bytes)。Google Chat送信完了(5チャンク)。commit 310069c→b2a8ed3でpush済(subtask_464a経由)。**主推奨: Notion Forms+n8nハイブリッド** / 補助: GitHub Issue Forms。3者推奨統合(1号Google Form+GAS, 2号n8n, 3号Notion)。AC 8/8 PASS(軍師統合)。🏆cmd_462完了 | ✅ 統合完了 |
| 08:09 | cmd_462 | subtask_462c QC PASS — フィードバック収集システム調査(Slack/Discord・Notion・GitHub Issue)。評価軸7項目スコアリング+URL引用10件超。1位Notion 22/35(既存notionAPI MCP+n8n親和性最高)、2位GitHub Issue 21/35(コスト$0)、3位Slack/Discord 17/35。AC 6/6 PASS(足軽3号+軍師QC) | ✅ QC PASS |
| 08:08 | cmd_462 | subtask_462b QC PASS — フィードバック収集システム調査(n8n Form Trigger / Canny / Typeform / Productboard)。評価軸7項目+URL引用9件。第1推奨: n8n Form Trigger(コスト¥0/shogun連携最高/VPS親和性最高)。第2推奨: Typeform+n8n(UX重視時)。Canny/Productboardは非推奨。AC 5/5 PASS(足軽2号+軍師QC) | ✅ QC PASS |
| 08:06 | cmd_462 | subtask_462a QC PASS — フィードバック収集システム調査(Google Form+GAS / Email+自動パース)。各選択肢で評価軸7項目+pros/cons+URL引用4+3=7件。推奨: Google Form+GAS(UX/拡張性/実装難易度バランス優)。Exploreエージェント並列調査。AC 5/5 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 08:00 | cmd_461 | subtask_461a QC PASS — gas-mail-manager standalone対応修正完了。sheets.gsにgetSpreadsheet()ヘルパー追加(openById使用)+全getActiveSpreadsheet()→getSpreadsheet()置換(0件残/7件: 定義1+呼出6)。config.gs initializeConfig()にSPREADSHEET_ID/DRIVE_ROOT_FOLDER_ID/GEMINI_API_KEYプレースホルダ追加。clasp push 7ファイル完了。commit 4185f8f push済み。AC 5/5 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 07:51 | cmd_459 | GASデプロイ+統合テスト完了 — Phase5 clasp push --force全7ファイルデプロイ成功+スクリプトエディタURL・デプロイメントID取得+ScriptProperties設定ガイド+統合テスト手順書。clasp runはAPI Executable要設定(手動手順記載)。AC 7/7 PASS(足軽3号+軍師QC)。🏆cmd_459完了 | ✅ AC 7/7 |
| 07:51 | cmd_459 | subtask_459a QC PASS — gas-mail-manager Phase5 GASデプロイ完了。clasp push --force: 全7ファイル(appsscript.json+src/6モジュール)成功。deploymentId+スクリプトエディタURL取得。clasp runはAPI Executable設定要(手順書記載)。ScriptProperties設定ガイド・統合テスト手順書完備。AC 7/7 PASS(足軽3号+軍師QC) | ✅ QC PASS |
| 07:33 | cmd_460 | Codex足軽L3試験投入完了 — 足軽6号(encoding横展開 AC 6/6)+足軽7号(L3ガイドライン追記 AC 6/6)。両名L3評価PASS。commit 7af931e+b085489 push済み。軍師判定: 本番L3投入可能。🏆cmd_460完了 | ✅ AC 12/12 |
| 07:32 | cmd_460 | subtask_460a QC PASS — encoding横展開(errors='replace'追加)。inbox_watcher.sh(3箇所)+ntfy_listener.sh(2箇所)+slim_yaml.py(1箇所)のread-mode open()修正。write-mode未変更。構文チェック全通過。commit 7af931e。AC 6/6 PASS(足軽6号+軍師QC)。**L3評価: PASS** | ✅ QC PASS |
| 07:32 | cmd_460 | subtask_460b QC PASS — codex-ashigaru.md「L3タスク対応ガイドライン」新セクション追加(4サブセクション: ファイル間依存/RACE-001/git add注意/報告)+AGENTS.md codex_l3_support追記。既存構造保持。commit b085489。AC 6/6 PASS(足軽7号+軍師QC)。**L3評価: PASS** | ✅ QC PASS |

## ✅ 昨日の戦果（4/6 JST）— 27cmd完了 🔥ストリーク29日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 14:24 | cmd_458 | Notion4/5日記ログ修正完了 — セクション検索正規表現を全パターン対応(本日/昨日/一昨日)+フォールバック廃止。4/5再同期SUCCESS(23cmd完了)。commit f8990b9 push済み。AC 4/4 PASS。🏆cmd_458完了 | ✅ AC 4/4 |
| 14:24 | cmd_458 | subtask_458a QC PASS — notion_session_log.shセクション検索バグ修正(正規表現を全パターン対応+フォールバック廃止)+4/5日記再同期SUCCESS(23cmd完了)。commit f8990b9 push済み。AC 4/4 PASS(足軽1号+軍師QC)。🛠️スキル候補: notion-session-log-section-pattern転記 | ✅ QC PASS |
| 09:05 | cmd_457 | Notionログ未記録修正+ダッシュボードclasp認証更新完了 — notion_session_log.sh UnicodeDecodeError修正(errors="replace")+Issue#28作成。clasp認証OOB OAuth廃止情報+回避策3種追記。commit 20e9390+e8631e2 push済み。AC 6/6 PASS(457a:4/4+457b:2/2)。🏆cmd_457完了 | ✅ AC 6/6 |
| 09:05 | cmd_457 | subtask_457a QC PASS — notion_session_log.sh UnicodeDecodeError根本原因特定+修正(L65 errors="replace"追加)。dashboard.md無効バイト列で日記ログ未記録を解消。commit 20e9390 push済み。Issue#28作成。AC 4/4 PASS(足軽1号+軍師QC)。🛠️スキル候補: python-utf8-errors-replace抽出 | ✅ QC PASS |
| 05:19 | cmd_456 | gas-mail-managerクローン+VSCodeワークスペース追加+shogun-repo-workspace-setupスキル作成完了 — /home/ubuntu/gas-mail-manager clone済み+shogun-workspace.code-workspace追加+.claude/skills/shogun-repo-workspace-setup/SKILL.md作成(commit 04d7a3e)。AC 8/8 PASS(足軽3号/6号)。🏆cmd_456完了 | ✅ AC 8/8 |
| 05:10 | cmd_455 | 顧客メール管理GASシステム構築完了 — clasp v3.3.0+GitHub(saneaki/gas-mail-manager)+設計書(450行)+全6モジュール実装(config/sheets/gmail/pdf/summary/main)。commit 5本push済み。AC 11/11通過(clasp認証のみ殿手動)。🏆cmd_455完了 | ✅ AC 11/11 |
| 09:01 | cmd_457 | subtask_457b QC PASS — dashboard.md🚨clasp認証[action]項目更新。Google OOB OAuth廃止警告+回避策3種(A:ローカルclasp login+clasprc.jsonコピー/B:GCPカスタムOAuth/C:サービスアカウント)+Apps Script API有効化前提追記。commit e8631e2 push済み。AC 2/2 PASS(足軽2号+軍師QC) | ✅ QC PASS |
| 05:08 | cmd_455 | subtask_455f QC PASS — main.gsメインオーケストレーター実装(processAllCustomers/processCustomer/isApproachingTimeLimit/setupTrigger/removeTrigger)。6分制限管理(saveResumeIndex中断+getResumeIndex再開)+15分間隔トリガー+顧客単位エラーハンドリング。設計書準拠・JSDoc全関数付・約125行。commit 672a28f。AC 7/7 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 05:03 | cmd_455 | subtask_455c QC PASS — config.gs(6関数: getConfig/setConfig/getResumeIndex/saveResumeIndex/clearResumeIndex/initializeConfig)+sheets.gs(5関数: getCustomerList/appendEmailRow/updateLastCheckDate/createEmailListSheet/isMessageAlreadyRecorded)+appsscript.json(5スコープ+Drive AS v2)。設計書準拠・JSDoc付・const/let使用。commit c1b5e1d。AC 5/5 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 05:01 | cmd_455 | subtask_455d QC PASS — gmail.gs(5関数: searchNewEmails/markAsProcessed/getOrCreateProcessedLabel/getEmailDirection/getEmailBody)+pdf.gs(4関数: convertEmailToPdf/convertHtmlToPdfViaDoc/savePdfToDrive/generatePdfFileName)実装。設計書準拠・JSDoc付。commit 5437734。AC 6/6 PASS(足軽3号+軍師QC) | ✅ QC PASS |
| 05:01 | cmd_455 | subtask_455e QC PASS — summary.gs実装(generateSummary/callGeminiApi)。Gemini REST API(gemini-2.0-flash)+getConfig+sleep(4s)レート制限+エラーハンドリング。設計書準拠・JSDoc付。commit 884bd85。AC 7/7 PASS(足軽7号+軍師QC) | ✅ QC PASS |
| 04:56 | cmd_455 | subtask_455a QC PASS — clasp CLI環境構築(v3.3.0)+GitHubリポジトリ(saneaki/gas-mail-manager private)+スキャフォールド(6 .gsファイル+appsscript.json)+認証手順書(docs/auth-guide.md)+README。commit fc876ee push済み。AC 9/9 PASS(足軽6号+軍師QC) | ✅ QC PASS |
| 03:06 | cmd_454 | 軍師提案3件実装+Codex足軽実戦テスト完了 — (1)codex-ashigaru.md skill_candidate追加(2)dashboard実装済みskill削除(3)karo.md/ashigaru.md editable_fields追記。AC 13/13 PASS(454a:4/4+454b:5/5+454c:4/4)。Codex足軽6・7号のL2実戦テスト成功。🏆cmd_454完了 | ✅ AC 13/13 |
| 03:04 | cmd_454 | subtask_454c QC PASS — editable_fieldsフィールドをkaro.md(step5 race001_check追加)/ashigaru.md(step2.5 check_editable_files追加)に追記。RACE-001予防強化。commit b819184。AC 4/4 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 03:04 | cmd_454 | subtask_454b QC PASS — dashboard🛠️スキル候補から実装済み(switch-cli-yaml-update-guard)行を削除。承認待ち2件(codex-cli-poc-verification/switch_cli-yaml-section-tracking)保持。skill_history確認済み。commit dfe9a23。AC 5/5 PASS(足軽7号+軍師QC) | ✅ QC PASS |
| 03:04 | cmd_454 | subtask_454a QC PASS — codex-ashigaru.mdレポートYAMLテンプレートにskill_candidate必須フィールド追加。通常足軽と同等ルールへ整合。commit 0ba2753。AC 4/4 PASS(足軽6号+軍師QC) | ✅ QC PASS |
| 02:57 | cmd_453 | Codex足軽起動修正完了 — shutsujin_departure.sh OPENAI_API_KEY自動設定追加(.envから読込+tmux set-environment)。足軽6・7号 codex/Codex5.3稼働確認。OPENAI_API_KEY tmux設定確認済み。commit 19d6fd0 push済み。AC 5/5 PASS。🏆cmd_453完了 | ✅ AC 5/5 |
| 02:28 | cmd_452 | cmd_450不具合修正完了 — ダッシュボード🏯自動更新バグ修正(KESSEN_MODE Opus強制+shu Sonnet+Tフォールバック)+shcエイリアス競合解消(shc→陣形管理/shx→hybrid出陣)+shogun.md shm→shc修正。AC 7/7 PASS(足軽3号+軍師QC)。commit 0f040a0 push済み。🏆cmd_452完了 | ✅ AC 7/7 |
| 02:25 | cmd_452 | subtask_452a QC PASS — ダッシュボード🏯自動更新バグ修正(KESSEN_MODE Opus強制+shu Sonnet+Tフォールバック)+shcエイリアス競合解消(shc→陣形管理/shx→hybrid出陣)。commit 0f040a0。AC 7/7 PASS(足軽3号+軍師QC) | ✅ QC PASS |
| 01:29 | cmd_451 | difference.md更新完了 — cmd_446〜450の変更反映。統計値+10409/-3112更新、shc.sh/switch_cli.sh新規追加、cli_adapter.sh/settings.yaml/shutsujin_departure.sh/shogun.md更新。commit 18eae35 push済み。AC 4/4 PASS(足軽3号直接)。🏆cmd_451完了 | ✅ AC 4/4 |
| 01:17 | cmd_450 | 出陣コマンド3種体系整備完了 — shu(all-sonnet)/shk(all-opus)/shc(hybrid)の3種整備+shcエイリアス競合解消(旧shc→shm)+shutsujin_departure.sh陣形事前適用+ダッシュボード自動更新。AC 15/15 PASS。commit beb28ea+f4354d9 push済み。Issue#26 close済み。🏆cmd_450完了 | ✅ AC 15/15 |
| 01:16 | cmd_450 | subtask_450a QC PASS — shutsujin_departure.sh --hybridフラグ追加+陣形事前適用(shu=all-sonnet/shk=all-opus/shc=hybrid)+ダッシュボード🏯自動更新(update_dashboard_formation)。bash -n OK。commit beb28ea。AC 8/8 PASS(足軽1号+軍師QC) | ✅ QC PASS |
| 01:14 | cmd_450 | subtask_450b QC PASS — shcエイリアス競合解消+出陣コマンド3種体系整備(shu/shk/shc)+旧shc→shm改名。~/.bash_aliases+~/.bashrc+instructions/shogun.md更新。Issue#26作成close。commit f4354d9。AC 7/7 PASS(足軽2号+軍師QC) | ✅ QC PASS |
| 00:58 | cmd_446 | subtask_446e_poc QC PASS — Codex足軽(ashigaru7)PoC検証。task_yaml/settings_yaml読取+report書出+cli_version(codex-cli 0.118.0)確認。全findings: true。cmd_446完了後の遅延完了分。AC 2/2 PASS(足軽7号+軍師QC) | ✅ QC PASS |
| 00:56 | cmd_449 | cli_adapter.sh cli_typeキー読み取りバグ修正完了 — L94 agent_cfg.get('cli_type', agent_cfg.get('type',''))に修正。ashigaru6/7がcodex CLIで正常起動確認。Issue #25 close済み。commit 7d4e3a6 push済み(将軍緊急介入)。🏆cmd_449完了 | ✅ AC 全通過 |
| 00:09 | cmd_448 | cmd_446残課題修正完了 — switch_cli.sh formations破壊バグ恒久修正(in_cli_agentsフラグ導入)+shc.sh L222キー名cli_type統一+settings.yaml正規化+switch-cli-yaml-update-guardスキル作成+フルサイクル検証(formations健在+cli_type統一)。全AC PASS(448a:5/5+448b:8/8+448c2:4/4)。git push済み。🏆cmd_448完了 | ✅ AC 17/17 |
| 00:07 | cmd_448 | subtask_448c2 QC PASS — switch-cli-yaml-update-guardスキル作成+Phase0修正(L185 type:→cli_type:)+フルサイクル検証(formations健在3プリセット+cli_type統一+type:キー0件)。git push済み。AC 4/4 PASS(足軽1号+軍師QC) | ✅ QC PASS |

## 🛠️ スキル候補（承認待ち）

承認待ち候補を全件表示。✅実装済みは `memory/skill_history.md` にアーカイブ済み。

| スキル名 | 発見元 | 概要 |
|---------|-------|------|
| **codex-cli-poc-verification** | cmd_446: Codex CLI足軽のPoC検証手順(起動・AGENTS.md読込・タスク実行・レポートYAML出力・inbox連携の5項目チェック)。増設・復旧時に再利用可能 | 承認待ち |
| **switch_cli-yaml-section-tracking** | cmd_448: YAML行走査時にセクション追跡フラグ(in_cli_section/in_cli_agents)で対象セクション外の誤変換防止。同名キーが複数セクションに存在するYAML部分書換に適用可能 | 承認待ち |
| **python-utf8-errors-replace** | cmd_457: Python open()でencoding="utf-8"使用時にerrors="replace"を付与し、外部ツール編集ファイル(dashboard.md等)の無効バイト列でスクリプトがクラッシュするのを防止。scripts/内12+箇所に同パターンあり横展開可能 | 承認待ち |
| **notion-session-log-section-pattern** | cmd_458: dashboard.mdのセクション見出しが日次で変わる(本日/昨日/一昨日)場合の正規表現パターン。日付照合で正確なセクションを取得し、フォールバックによる誤データ書込みを防止 | 承認待ち |
