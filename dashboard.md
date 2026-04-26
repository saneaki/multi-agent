# 📊 戦況報告
最終更新: 2026-04-26 19:51 JST

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
| 今日の完了 | 5 |
| VFタスク残り | 0件（うち今日期限: 0件） |

## 🚨 要対応 - 殿のご判断をお待ちしております

| タグ | 項目 | 詳細 |
|------|------|------|
| [action-9] | **殿ご確認: 寺地 50件 古い要約の取扱** | cmd_585 完遂済(19:33)。既処理 50 thread は cmd_589 修正前の要約が残存。(a) force=true 再実行で再要約 or (b) 現状維持。完了後 家老 inbox に通知。 |
| [action-8] | **cmd_594 発令待ち (2026-05-03 以降)** — KPI framework 1-2w 後検証 | cmd_593 KPI framework の実測値妥当性確認。2026-05-03 に家老が発令 (ash Scope A + gunshi QC)。 |
| [action-7] | **difference.md 5日間未更新** — cmd_593 Scope E で hook登録完了 | 次の 🏆🏆 commit で自動再生成予定。急ぐなら VPS で `bash scripts/cmd_squash_pub_hook.sh` 手動実行。 |
| [action-5] | cmd_588 運用開始 — 殿 12分作業 | gunshi QC=Go(06:19)確認済。(1)**GAS エディタ** script.google.com→gas-mail-manager→`setupTrigger()` 手動実行→毎日9:00 trigger登録(5分) 手順書: output/cmd_588_trigger_setup.md (2)**crontab設定** `crontab -e` で `*/30 * * * * bash /home/ubuntu/shogun/scripts/clasp_rapt_monitor.sh >> /tmp/rapt_monitor.log 2>&1` 追加(2分) 完了後 家老 inbox に「action-5完了」通知。 |
| [info-1] | Claude Code .claude/skills パーミッションバグ | **2026-04-24 16:10 将軍確認**: anthropics/claude-code#37157 (bug/has repro/area:skills, 最終更新 4/20) + #38806 (enhancement/area:permissions, 最終更新 4/2) 共に **OPEN** (公式修正なし)。暫定対処: 選択肢2で手動承認を継続。将軍が週次で修正状況を確認する。 |

## 📊 運用指標

| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 | karo auto-compact | gunshi auto-compact | safe_window発動 |
|-----------|------------|------|------|----------------|-------------------|---------------------|------------------|
| 2026-04-22 | 1 | 1 | 0 | 0 | - | - | - |
| 2026-04-26 | 0 | 0 | 0 | 0 | 1 | 0 | 79 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_595 | report.yaml per-subtask history 機構 | gunshi:QC中 | A✅+C✅(19:50:APPROVE_WITH_CONCERNS)+D(gunshi:QC発令中) |
| cmd_596 | suggestions 定期消化機構 | ash5:Scope C+D中 | A✅+B✅(19:47:digest.sh+cron)+C+D(ash5:dashboard反映+karo.md hard check中) |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | 待機 | subtask_596b完了(19:47): suggestions_digest.sh新規作成+cron登録(5 9 * * *) dry-run OK AC2 PASS ✅ |
| 足軽2号(Sonnet+T) | 待機 | subtask_592b完了(12:12): compact_observer.sh新規作成 ✅ |
| 足軽3号(Sonnet+T) | 待機 | subtask_585m完了(19:46): reality check OK。clasp logs確認 processed=43/total=93。cmd_585/cmd_568完遂=可 ✅ |
| 足軽4号(Opus+T) | 待機 | subtask_588a完了(06:15): clasp push 7files成功 AC1/AC2/AC_trigger_doc 全PASS ✅ |
| 足軽5号(Opus+T) | 作業中 | subtask_596cd発令(19:50): cmd_596 Scope C+D dashboard[提案]反映+instructions/karo.md hard check |
| 足軽6号(Codex5.3) | 待機 | subtask_595c完了(19:50): 案C Hybrid second opinion=APPROVE_WITH_CONCERNS(履歴肥大化/cleanup未定義) ✅ |
| 足軽7号(Codex5.3) | 待機 | subtask_593h完了(14:02): get_context_pct.sh作成(実測54%)+crontab動的取得更新 ✅ |
| 軍師(Opus+T) | QC中 | subtask_595d_qc発令(19:51): cmd_595 Scope D QC (Hybrid design 総合判定) |

## ✅ 本日の戦果（4/26 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 19:33 | GAS/shogun | cmd_585完遂(ash3/5/gunshi)+cmd_568連鎖完遂: 寺地11年分全93thread backfill完了(processed=43/skipped=50/errors=0)。5x並列化稼働3m47s完遂 | ✅ ends完了 |
| 17:00 | scripts/shogun | cmd_593完遂(ash1/2/5/6/7/gunshi): shelf-ware監査51件+防止体系(deploy&verify/KPI observer/context_pct動的化) commit b2ec328。gunshi QC=Go | ✅ ends完了 |
| 14:27 | scripts/shogun | cmd_592完遂(ash1/2/7/gunshi): shelf-ware解消 cron実稼働(compact_observer/safe_window動的/karo_self_clear) commit 02bb5d7 | ✅ ends完了 |
| 12:27 | GAS/shogun | cmd_590完遂(ash5/gunshi): 寺地backfill 5x高速化 Fix2+3+4+callGeminiApiBatch chunk=5並列化 commit 4e1f955/853f58c。殿 backfillTerachi 実行待ち | ✅ ends完了 |
| 06:26 | GAS/shogun | cmd_588完遂(ash4/1/2/6/gunshi): clasp RAPT自動運用化 Time-driven trigger+RAPT monitor commit d36aef7/3f32704 | ✅ ends完了 |

## ✅ 昨日の戦果（4/25 JST）— 1cmd完了 🔥ストリーク32日目

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 04:50 | output/ git | cmd_587完了(ash3/ash5/ash6/ash7/gunshi): Gemini 403全経緯Issue#38+consumer=kaji-487204確定+次アクション5案 commit 8347a04 | ✅ ends完了 |

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
| **shogun-gas-backfill-pattern** | cmd_585/590 ash5+gunshi: GAS UrlFetchApp.fetchAll による 11年分 thread 並列 backfill パターン。force=false(新規のみ)/chunk=5並列/resume省略/完遂検出→trigger削除。battle_tested: 寺地93thread 3m47s完遂 (5x高速化)。1w運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-bash-daemon-restart-subcommand-pattern** | cmd_546 gunshi(Opus+T): bash daemon に安全な restart サブコマンドを追加するパターン。mode="${1:-daemon}"で引数解釈/lockfile PID+pgrep二段フォールバック/kill-TERM+5秒deadline/nohup spawn後PID再検証/stale lockfile回復実証済み。systemd非依存の軽量bash daemon・常駐watcher・hook runnerに汎用展開可。1w運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-clasp-rapt-reauth-fallback** | cmd_565 gunshi(Opus+T): clasp push invalid_grant/invalid_rapt 復旧プロトコル。VPS 側 ~/.clasprc.json の refresh token が RAPT 再認証境界を越えた場合、リモート(VPS)からは再認証不能(ブラウザ必須)のため、案A=殿ローカル clasp login → scp 転送 (最短経路) / 案B=GAS editor 直接編集 (代替、複数ファイル同期には非効率)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md)。battle_tested=cmd_486/cmd_564/cmd_565 (3回再現、cmd_565 で実地復旧検証済)。cmd_562 AC5 準拠配置。GAS 運用全般に汎用展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-gas-automated-verification** | cmd_567 ashigaru1(Sonnet+T): GAS (clasp 3.x) 自動検証基盤スキル。VPS/Ubuntu 上で `clasp run` + `clasp logs` による自動テストを実現。battle_tested 5点: (1) clasp 3.x --creds は --use-project-scopes + --include-clasp-scopes 必須 (2) OAuth クライアントは「デスクトップアプリ」必須 (ウェブアプリは Invalid redirect URL) (3) .clasp.json に projectId 追加必須 (clasp logs 使用時) (4) Google アカウント承諾削除は myaccount.google.com/permissions (5) Logger.log は clasp 3.x + Cloud Logging 経由で INFO レベル取得可 (console.log 置換不要)。**SKILL.md 資産化完了** (/home/ubuntu/shogun/skills/shogun-gas-automated-verification/SKILL.md)。cmd_562 AC5 準拠配置。他 GAS プロジェクト展開可。1w 運用観測後に正式スキル化推奨。 | 承認待ち |
| **shogun-karo-task-validator** | cmd_573 Scope B ash5(Opus+T): shogun_to_karo.yaml のshift-left検証パターン。entry-anchor正規表現分割+entry-wise yaml.safe_load+required/recommended/conditional/optional 4層フィールド分類+CRITICAL/HIGH/MEDIUM/LOW severity tier+bypass audit log YAML append。--all で374 entry一括/--bypass でaudit証跡。他config(report YAML/dashboard.md等)へ横展開可。 | 承認待ち |
| **shogun-tmux-busy-aware-send-keys** | cmd_582 ash6(Sonnet+T): tmux send-keys で Enter 前に Claude idle を待つ wait_until_idle() パターン。A-3 race condition 解消。poll 0.5s / timeout configurable / WARN+fallback。pane整合チェック+stale pane 自動再検出。cmd_complete 通知 reliability 強化。battle-tested 条件: 1w 後 3 cmd_complete 通知で実測確認後に正式スキル化推奨。 | 承認待ち |
