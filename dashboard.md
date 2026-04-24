# 📊 戦況報告
最終更新: 2026-04-24 19:58 JST

## 📋 記載ルール (Self-Documentation)
> **更新者必読**: このセクションのルールを遵守して dashboard を更新すること。

| 分類 | ルール概要 | 根拠 |
|------|-----------|------|
| 更新責任 | **Karo 一次責任** (全セクション編集)。🔄進行中テーブルは **Shogun が確認・修正** の役割。要対応/戦果/待機中は Karo + Gunshi。Ashigaru は禁止 | instructions/common/shogun_mandatory.md:1 (2026-04-24 殿改訂) |
| 時刻 | 全て JST。scripts/jst_now.sh を使用 (`date` 直接禁止) | instructions/karo.md:639 |
| セクション順 | 🐸→🚨→📊→🔄→🏯→✅(本日/昨日/一昨日)→🛠️ | dashboard.md:4 |
| action-N | [action-N] 採番。cmd完了時に削除して✅へ (SO-19) | instructions/common/shogun_mandatory.md:12 |
| 戦果書式 | `| 時刻 | 戦場 | 任務 | 結果 |` の4列 | instructions/karo.md:626 |
| 時刻順序 | 戦果・進行中テーブルは時刻**降順**で記載（最新が上） | output/cmd_576_dashboard_rules.md §(5) |
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
| [action-2] | cmd_585 BLOCK-1: 元帳F3修復 | 寺地淳子様 元帳スプレッドシートの**F3セルに '寺地淳子_メール一覧' を入力**。ash5がBug-C発見: sheet_name空欄→insertSheet('')例外でシート記録不能。修復後にash5 subtask_585b(backfillSheetFromDrive)を実行予定。|
| [action-3] | cmd_585 BLOCK-3: Gemini APIキー確認 | **GCP Console (kaji-487204) でGemini APIキー状態確認**。Bug-B実証: 403 API_KEY_SERVICE_BLOCKED確認済。Restrictions設定確認 or 新規APIキー発行が必要。キー再発行後 ScriptProperties GEMINI_API_KEY 更新。 |
| [action-4] | cmd_586 殿ご承認依頼: 自律判断支援 prototype 実装 | **cmd_578 QC=Go** (gunshi)。safe_window_judge.sh/py + role別分岐 + 案(c) self-notify 実装で **auto-compact頻度50-70%削減**見込み。殿ご承認後に家老が発令。依存: cmd_578 Scope E(設計doc) 完了後。優先度 high。 |
| [info-1] | Claude Code .claude/skills パーミッションバグ | **2026-04-24 16:10 将軍確認**: anthropics/claude-code#37157 (bug/has repro/area:skills, 最終更新 4/20) + #38806 (enhancement/area:permissions, 最終更新 4/2) 共に **OPEN** (公式修正なし)。暫定対処: 選択肢2で手動承認を継続。将軍が週次で修正状況を確認する。 |

## 📊 運用指標

| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 |
|-----------|------------|------|------|----------------|
| 2026-04-22 | 1 | 1 | 0 | 0 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_578 | 自律判断支援設計: Scope A/B/C完了+QC Go(gunshi AC8 4/4 PASS) | 足軽3号 | Scope E(設計doc)作業中(19:55) |
| cmd_583 | dashboard戦果 cmd単位集約+dashboard_lint.py: QC Go(gunshi AC9 3/3 PASS) | 足軽1号 | Scope D(commit)作業中(19:55) |
| cmd_584 | 軍師Concerns一元管理: AC1-AC6全完了(ash3+ash7+ash2) | 軍師 | Scope D(gunshi QC)作業中(19:55) |
| cmd_585 | 寺地淳子様backfill: backfillSheetFromDrive実装完了(ash5 AC5 PASS) | (待機) | BLOCK-1(元帳F3修復=action-2)待ち |
| cmd_568 | DriveApp案B実装完了/Bug-A連鎖解消/Bug-B実証完了(Gemini BLOCKED confirmed) | (待機) | cmd_585 BLOCK-1解消後 clasp run待ち |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | 作業中 | subtask_583d_commit(19:55): cmd_583 Scope D dashboard_lint.py+本日戦果集約 統合commit 発令済 |
| 足軽2号(Sonnet+T) | 待機 | subtask_584c完了(19:49): cmd_584 Scope C suggestions_schema.yaml作成+YAML構文652エントリ修正 AC6 PASS ✅ |
| 足軽3号(Sonnet+T) | 作業中 | subtask_578e(19:55): cmd_578 Scope E 設計doc(output/cmd_578_autonomous_context_hygiene_design.md)+commit 発令済 |
| 足軽4号(Opus+T) | 待機 | subtask_578a完了(19:46): cmd_578 Scope A safe window再構築 C1=0×4+C2 fail-safe発見 AC1/AC2 PASS ✅ |
| 足軽5号(Sonnet+T) | 待機 | subtask_585b完了(19:52): cmd_585 Scope B backfillSheetFromDrive実装+clasp push(7 files) AC5 PASS ✅ BLOCK-1待ち |
| 足軽6号(Codex5.3) | 待機 | subtask_578c完了(19:42): cmd_578 Scope C L012知見K1-K5+shogun適用評価 AC7 PASS ✅ |
| 足軽7号(Codex5.3) | 待機 | subtask_584b_instructions完了(19:28): cmd_584 Scope B gunshi.md/karo.md 運用明文化 AC3/AC4 PASS ✅ |
| 軍師(Opus+T) | 作業中 | subtask_584d_qc(19:55): cmd_584 Scope D QC north_star 3点(AC7) 発令済 |

## ✅ 本日の戦果（4/24 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 19:08 | scripts/ git | cmd_582完了(ash6/ash1/ash2/ash7): wait_until_idle+pane整合+統合テスト commit 62d101a | ✅ ends完了 |
| 18:46 | instructions/ memory/ CLAUDE.md | cmd_581完了(ash1): Rule1 Karo primary/Shogun確認修正 sync commit 5cdb3c5 | ✅ ends完了 |
| 18:46 | instructions/ memory/ | cmd_571完了(ash6): F006a/F006b分割16箇所+Violation.md更新 commit 5cdb3c5 | ✅ ends完了 |
| 18:40 | (analysis) | cmd_577完了(ash2/ash6/ash7): 家老context分析+karo_self_clear改善提案5案 Conditional Go(gunshi) | ✅ means完了 |
| 18:26 | gas-mail-manager | cmd_568完了(ash5/ash6/ash7): DriveApp案B+Bug-A解消/Bug-B実証困難 commit 825aeeb | ✅ means完了 (殿action-7/8待ち) |
| 18:21 | dashboard.md memory/ output/ | cmd_580完了(ash1): 時刻降順ルール追加+テーブル是正+canonical同期 AC1-3 PASS | ✅ means完了 |
| 18:20 | queue/reports/ | cmd_579完了(ash5): ash3/ash4 YAML parse error修復 AC1-3 PASS | ✅ means完了 |
| 17:50 | dashboard.md memory/ instructions/ | cmd_576完了(ash1/ash6/ash7): dashboard記載ルール8分類+自己記載化 commit 402b44a | ✅ ends完了 |
| 17:50 | instructions/ config/ scripts/ memory/ | cmd_573/574/575完了(ash1/ash5/ash6/ash7): Phase1 P1.1-P1.4+SO-21+Gap C2 commit d068cbd | ✅ ends完了 |
| 17:05 | memory/ | cmd_570: Phase 0 rule-source統合 — canonical_rule_sources.md(165L) + INC-1/2解消 | ✅ commit 353489c (ash1/ash5) / gunshi QC Conditional Go / Phase 0 完全クローズ |
| 16:59 | memory/ | cmd_572: SO-20重複分離 — SO-24新設(三点照合) + 参照補修3箇所 (sug_002解消) | ✅ commit 5ad403f (ash1 572a+572b) / gunshi QC Conditional Go / P1.4前提クリア |
| 16:15 | memory/plans/ | cmd_569: Violation.md根本解決策 plan.md起草(499L/Phase 0-3/Codex4指摘) + Issue #37 作成 | ✅ commit d23a18f (AC11) / 殿決裁待ち(action-3) |
| 16:10 | KPI観測 | cmd_528 SO-01/SO-03 KPI観測 (2026-04-17〜04-24, 7日間): ashigaru report 集計で違反ゼロ達成 | ✅ sug_cmd_528_003 effectiveness 検証完了 (将軍集計) — 三層防御 Plan A/B/C 実効確認 |
| 13:55 | gas-mail-manager | cmd_567: clasp run 自動検証基盤 (gas_run.sh + gas_verify.py + skill) + 顧客数 bug fix (H列 active 型揺れ) | ✅ commit 304edfc (AC11) / 殿実地検証(顧客数2確認) / gunshi QC Go(4点全PASS) |
| 12:21 | memory/ | cmd_566: ルール遵守違反体系調査 Violation.md 318L | ✅ means完了 commit a3a6e5c (ash3-7) + 566e QC Go(gunshi) + cmd_569 にて plan.md + Issue #37 artifact 化 |
| 12:00 | gas-mail-manager | cmd_565: clasp push完遂(7ファイル)+skill資産化 | ✅ means完了 commit 37f7c7f (ash1/ash2) + 565g QC Go(gunshi) + 殿 GAS editor action 13:55 完了 |

## ✅ 昨日の戦果（4/23 JST）— 0cmd完了 🔥ストリーク32日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| （まだなし） | | | |

## ✅ 一昨日の戦果（4/18 JST）— 3cmd完了 🔥ストリーク32日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 23:16 | scripts/tests/ | cmd_546-BC: tests commit + daily metric dashboard反映 | ✅ commit eb0a165 (ash3) |
| 21:00 | scripts/ | cmd_542: head -c UTF-8切断バグ修正 Fixes #123 | ✅ commit 375faa3 (ash1) |
| 18:57 | scripts/ | cmd_544: squash_pub_hook 3安全装置(kill-switch/rate-limit/daily-metric)追加 | ✅ commit dc31f31 (ash5) |

## 🛠️ スキル候補（承認待ち）

承認待ち候補を全件表示。✅実装済みは `memory/skill_history.md` にアーカイブ済み。

| スキル名 | 発見元 | 概要 |
|---------|-------|------|
| **shogun-bash-daemon-restart-subcommand-pattern** | cmd_546 gunshi(Opus+T): bash daemon に安全な restart サブコマンドを追加するパターン。mode="${1:-daemon}"で引数解釈/lockfile PID+pgrep二段フォールバック/kill-TERM+5秒deadline/nohup spawn後PID再検証/stale lockfile回復実証済み。systemd非依存の軽量bash daemon・常駐watcher・hook runnerに汎用展開可。1w運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-clasp-rapt-reauth-fallback** | cmd_565 gunshi(Opus+T): clasp push invalid_grant/invalid_rapt 復旧プロトコル。VPS 側 ~/.clasprc.json の refresh token が RAPT 再認証境界を越えた場合、リモート(VPS)からは再認証不能(ブラウザ必須)のため、案A=殿ローカル clasp login → scp 転送 (最短経路) / 案B=GAS editor 直接編集 (代替、複数ファイル同期には非効率)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md)。battle_tested=cmd_486/cmd_564/cmd_565 (3回再現、cmd_565 で実地復旧検証済)。cmd_562 AC5 準拠配置。GAS 運用全般に汎用展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-automated-verification** | cmd_567 ashigaru1(Sonnet+T): GAS (clasp 3.x) 自動検証基盤スキル。VPS/Ubuntu 上で `clasp run` + `clasp logs` による自動テストを実現。battle_tested 5点: (1) clasp 3.x --creds は --use-project-scopes + --include-clasp-scopes 必須 (2) OAuth クライアントは「デスクトップアプリ」必須 (ウェブアプリは Invalid redirect URL) (3) .clasp.json に projectId 追加必須 (clasp logs 使用時) (4) Google アカウント承諾削除は myaccount.google.com/permissions (5) Logger.log は clasp 3.x + Cloud Logging 経由で INFO レベル取得可 (console.log 置換不要)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-automated-verification/SKILL.md)。cmd_562 AC5 準拠配置。他 GAS プロジェクト展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-karo-task-validator** | cmd_573 Scope B ash5(Opus+T): shogun_to_karo.yaml のshift-left検証パターン。entry-anchor正規表現分割+entry-wise yaml.safe_load+required/recommended/conditional/optional 4層フィールド分類+CRITICAL/HIGH/MEDIUM/LOW severity tier+bypass audit log YAML append。--all で374 entry一括/--bypass でaudit証跡。他config(report YAML/dashboard.md等)へ横展開可。 | 承認待ち |
| **shogun-tmux-busy-aware-send-keys** | cmd_582 ash6(Sonnet+T): tmux send-keys で Enter 前に Claude idle を待つ wait_until_idle() パターン。A-3 race condition 解消。poll 0.5s / timeout configurable / WARN+fallback。pane整合チェック+stale pane 自動再検出。cmd_complete 通知 reliability 強化。battle-tested 条件: 1w 後 3 cmd_complete 通知で実測確認後に正式スキル化推奨。 | 承認待ち |
