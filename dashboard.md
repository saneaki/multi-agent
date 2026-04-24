# 📊 戦況報告
最終更新: 2026-04-24 17:45 JST

## 📋 記載ルール (Self-Documentation)
> **更新者必読**: このセクションのルールを遵守して dashboard を更新すること。

| 分類 | ルール概要 | 根拠 |
|------|-----------|------|
| 更新責任 | Karo/Gunshi のみ編集可。Shogun/Ashigaru は禁止 | instructions/common/shogun_mandatory.md:1 |
| 時刻 | 全て JST。scripts/jst_now.sh を使用 (`date` 直接禁止) | instructions/karo.md:639 |
| セクション順 | 🐸→🚨→📊→🔄→🏯→✅(本日/昨日/一昨日)→🛠️ | dashboard.md:4 |
| action-N | [action-N] 採番。cmd完了時に削除して✅へ (SO-19) | instructions/common/shogun_mandatory.md:12 |
| 戦果書式 | `| 時刻 | 戦場 | 任務 | 結果 |` の4列 | instructions/karo.md:626 |
| ステート遷移 | 受領→🔄進行中、完了→🔄から削除→✅戦果 | instructions/karo.md:625-627 |
| アーカイブ | 本日/昨日/一昨日の3世代保持。日付変更時に rotation | instructions/karo.md:641-647 |
| スキル候補 | 承認待ちを全件表示。採択後は skill_history.md へ | instructions/karo.md:688-701 |

## 🐸 Frog / ストリーク

| 項目 | 値 |
|------|-----|
| 今日のFrog | 未設定 |
| Frog状態 | 🐸 未撃破 |
| ストリーク | 🔥 32日目継続中 (最長: 32日) |
| 今日の完了 | 0 |
| VFタスク残り | 0件（うち今日期限: 0件） |

## 🚨 要対応 - 殿のご判断をお待ちしております

| タグ | 項目 | 詳細 |
|------|------|------|
| [action-8] | **【殿アクション必要】寺地淳子様 GAS DriveApp OAuth consent 未完了** | 仮説τ確定(subtask_568_followup2): GAS script-level DriveApp の Drive scope 承認が未実施。**修正案A(推奨,5分,low risk)**: script.google.com → mailmanager プロジェクト → processAllCustomers を手動実行 → Drive scope を含む全scope 承認。**修正案B(30分,medium risk)**: pdf.gs DriveApp.getFolderById → Drive Advanced Service v2 置換。承認後 clasp run で 93件処理確認予定。 |
| [info-1] | Claude Code .claude/skills パーミッションバグ | **2026-04-24 16:10 将軍確認**: anthropics/claude-code#37157 (bug/has repro/area:skills, 最終更新 4/20) + #38806 (enhancement/area:permissions, 最終更新 4/2) 共に **OPEN** (公式修正なし)。暫定対処: 選択肢2で手動承認を継続。将軍が週次で修正状況を確認する。 |

## 📊 運用指標

| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 |
|-----------|------------|------|------|----------------|
| 2026-04-22 | 1 | 1 | 0 | 0 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_573+576 | commit作業中 (gunshi QC Go受領) | 足軽1号 | commit中(subtask_573_576_commit) |
| cmd_571 | F006重複意義分割(F006a/F006b) — Option 1採用 | 足軽3号 | 作業中(subtask_571a) |
| cmd_567 | subtask_567d: skill+SUP5c設計方針反映 | 足軽4号 | blocked(依存解消待ち) |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | cmd_573+576 commit作業中 | subtask_573_576_commit: 2件commit (gunshi QC Go) |
| 足軽2号(Sonnet+T) | 待機 | subtask_568_followup2完了(17:33): 仮説τ確定(GAS DriveApp OAuth consent未完了) ✅ |
| 足軽3号(Sonnet+T) | cmd_571作業中 | subtask_571a: F006a/F006b分割実装 |
| 足軽4号(Opus+T) | blocked | subtask_567d: skill shogun-gas-automated-verification+SUP5c設計方針反映 |
| 足軽5号(Opus+T) | 待機 | subtask_573c完了(17:38): report YAML schema(283L)+validator(505L)+warn-only ✅ |
| 足軽6号(Codex5.3) | 待機 | subtask_576c完了(17:34): dashboard.md冒頭📋記載ルールセクション追加 ✅ |
| 足軽7号(Codex5.3) | 待機 | subtask_576d完了(17:34): canonical_rule_sources.md登録+karo.md参照追記 ✅ |
| 軍師(Opus+T) | 待機 | subtask_573e_576e_qc完了(17:44): cmd_573 Go + cmd_576 Go / commit許可 ✅ |

## ✅ 本日の戦果（4/24 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 12:00 | gas-mail-manager | cmd_565: clasp push完遂(7ファイル)+skill資産化 | ✅ means完了 commit 37f7c7f (ash1/ash2) + 565g QC Go(gunshi) + 殿 GAS editor action 13:55 完了 |
| 12:21 | memory/ | cmd_566: ルール遵守違反体系調査 Violation.md 318L | ✅ means完了 commit a3a6e5c (ash3-7) + 566e QC Go(gunshi) + cmd_569 にて plan.md + Issue #37 artifact 化 |
| 13:55 | gas-mail-manager | cmd_567: clasp run 自動検証基盤 (gas_run.sh + gas_verify.py + skill) + 顧客数 bug fix (H列 active 型揺れ) | ✅ commit 304edfc (AC11) / 殿実地検証(顧客数2確認) / gunshi QC Go(4点全PASS) |
| 15:58 | gas-mail-manager | cmd_568: DriveApp.getFolderById エラー修正 (pdf.gs P2ガード + main.gs P3 early return) + 仮説ε確定(D列空文字) | ✅ commit 825aeeb (AC8) / P3 guard動作確認(16:15) / gunshi QC Go(3点全PASS) / 残: D列設定(action-7) |
| 16:15 | memory/plans/ | cmd_569: Violation.md根本解決策 plan.md起草(499L/Phase 0-3/Codex4指摘) + Issue #37 作成 | ✅ commit d23a18f (AC11) / 殿決裁待ち(action-3) |
| 16:10 | KPI観測 | cmd_528 SO-01/SO-03 KPI観測 (2026-04-17〜04-24, 7日間): ashigaru report 集計で違反ゼロ達成 | ✅ sug_cmd_528_003 effectiveness 検証完了 (将軍集計) — 三層防御 Plan A/B/C 実効確認 |
| 16:59 | memory/ | cmd_572: SO-20重複分離 — SO-24新設(三点照合) + 参照補修3箇所 (sug_002解消) | ✅ commit 5ad403f (ash1 572a+572b) / gunshi QC Conditional Go / P1.4前提クリア |
| 17:05 | memory/ | cmd_570: Phase 0 rule-source統合 — canonical_rule_sources.md(165L) + INC-1/2解消 | ✅ commit 353489c (ash1/ash5) / gunshi QC Conditional Go / Phase 0 完全クローズ |
| 17:17 | instructions/ memory/ | cmd_573 Scope A + cmd_574: P1.1 karo.md SO-24 checklist(ash7) + SO-21 canonical登録(ash6) | ✅ means完了 / cmd_575発令済 |
| 17:22 | scripts/ instructions/ memory/ | cmd_573 Scope D + cmd_575: P1.4 so24_verify.sh三点照合自動化(ash1) + Gap C2 分類基準明示化(ash6) | ✅ means完了 / Scope B(ash5)作業中 |
| 17:25 | config/ scripts/ | cmd_573 Scope B: P1.2 shogun_to_karo schema(196L)+validator(427L)+shift-left+severity tier+bypass audit | ✅ means完了 (ash5 Opus+T) / Scope C発令済 / skill候補: shogun-karo-task-validator |
| 17:27 | queue/ instructions/ | cmd_576 Scope A: dashboard記載ルール8分類 grep収集完了 | ✅ means完了 (ash7) / Scope B(ash1)作業中 |
| 17:32 | output/ | cmd_576 Scope B: dashboard記載ルール仕様策定 (output/cmd_576_dashboard_rules.md, 8分類+例+根拠) | ✅ means完了 (ash1) / Scope C/D発令済 |
| 17:33 | memory/ | cmd_568 action-8 再調査: 仮説τ確定(GAS DriveApp OAuth consent未完了) | ✅ means完了 (ash2) / 殿アクション必要([action-8]参照) |
| 17:34 | dashboard.md memory/ instructions/ | cmd_576 Scope C/D: 📋記載ルールセクション追加(ash6) + canonical登録+karo.md参照追記(ash7) | ✅ means完了 / Scope E(gunshi 統合QC)発令済 |
| 17:38 | config/ scripts/ | cmd_573 Scope C: P1.3 report YAML schema(283L)+validator(505L)+warn-only+hook設計 (ash5) | ✅ means完了 / gunshi 統合QC発令済(573e+576e) |
| 17:44 | instructions/ config/ scripts/ dashboard.md | cmd_573 Scope E + cmd_576 Scope E: gunshi 統合QC Go (north_star 4点全PASS) | ✅ Go (gunshi) / cmd_573+576 commit 発令済(ash1) |

## ✅ 昨日の戦果（4/23 JST）— 0cmd完了 🔥ストリーク32日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| （まだなし） | | | |

## ✅ 一昨日の戦果（4/18 JST）— 3cmd完了 🔥ストリーク32日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 18:57 | scripts/ | cmd_544: squash_pub_hook 3安全装置(kill-switch/rate-limit/daily-metric)追加 | ✅ commit dc31f31 (ash5) |
| 21:00 | scripts/ | cmd_542: head -c UTF-8切断バグ修正 Fixes #123 | ✅ commit 375faa3 (ash1) |
| 23:16 | scripts/tests/ | cmd_546-BC: tests commit + daily metric dashboard反映 | ✅ commit eb0a165 (ash3) |

## 🛠️ スキル候補（承認待ち）

承認待ち候補を全件表示。✅実装済みは `memory/skill_history.md` にアーカイブ済み。

| スキル名 | 発見元 | 概要 |
|---------|-------|------|
| **shogun-bash-daemon-restart-subcommand-pattern** | cmd_546 gunshi(Opus+T): bash daemon に安全な restart サブコマンドを追加するパターン。mode="${1:-daemon}"で引数解釈/lockfile PID+pgrep二段フォールバック/kill-TERM+5秒deadline/nohup spawn後PID再検証/stale lockfile回復実証済み。systemd非依存の軽量bash daemon・常駐watcher・hook runnerに汎用展開可。1w運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-clasp-rapt-reauth-fallback** | cmd_565 gunshi(Opus+T): clasp push invalid_grant/invalid_rapt 復旧プロトコル。VPS 側 ~/.clasprc.json の refresh token が RAPT 再認証境界を越えた場合、リモート(VPS)からは再認証不能(ブラウザ必須)のため、案A=殿ローカル clasp login → scp 転送 (最短経路) / 案B=GAS editor 直接編集 (代替、複数ファイル同期には非効率)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md)。battle_tested=cmd_486/cmd_564/cmd_565 (3回再現、cmd_565 で実地復旧検証済)。cmd_562 AC5 準拠配置。GAS 運用全般に汎用展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-automated-verification** | cmd_567 ashigaru1(Sonnet+T): GAS (clasp 3.x) 自動検証基盤スキル。VPS/Ubuntu 上で `clasp run` + `clasp logs` による自動テストを実現。battle_tested 5点: (1) clasp 3.x --creds は --use-project-scopes + --include-clasp-scopes 必須 (2) OAuth クライアントは「デスクトップアプリ」必須 (ウェブアプリは Invalid redirect URL) (3) .clasp.json に projectId 追加必須 (clasp logs 使用時) (4) Google アカウント承諾削除は myaccount.google.com/permissions (5) Logger.log は clasp 3.x + Cloud Logging 経由で INFO レベル取得可 (console.log 置換不要)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-automated-verification/SKILL.md)。cmd_562 AC5 準拠配置。他 GAS プロジェクト展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-karo-task-validator** | cmd_573 Scope B ash5(Opus+T): shogun_to_karo.yaml のshift-left検証パターン。entry-anchor正規表現分割+entry-wise yaml.safe_load+required/recommended/conditional/optional 4層フィールド分類+CRITICAL/HIGH/MEDIUM/LOW severity tier+bypass audit log YAML append。--all で374 entry一括/--bypass でaudit証跡。他config(report YAML/dashboard.md等)へ横展開可。 | 承認待ち |
