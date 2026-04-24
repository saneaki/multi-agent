# 📊 戦況報告
最終更新: 2026-04-24 13:18 JST

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
| [info-1] | Claude Code .claude/skills パーミッションバグ | v2.1.78以降 .claude/skills がprotected directory exemptionから漏れている(anthropics/claude-code#37157, #38806)。セッション起動時に足軽がskills/操作でprompt停止する。暫定: 選択肢2で手動承認。公式修正待ち。将軍がセッション開始時に修正状況を確認する。 |
| [info-2] | cmd_528 SO-01/SO-03 KPI観測 2026-04-17〜04-24 | 三層防御(Plan A/B/C)完成後の効果測定。7日間ashigaru reportでSO-01/SO-03違反ゼロ目標(sug_cmd_528_003)。違反発生時はPlan A/C設計再評価。 |
| [action-1] | gas-mail-manager processAllCustomers 実行+OAuth承認(cmd_565) | **clasp push完了(7ファイル, 2026-04-24)**。殿の次アクション: https://script.google.com/home/projects/1a7zxw0jBja2hzR6BPnkX2XT_z9ys19Afrat6PK3TovSuVqQWkTBdkzkS/edit を開き→エディタ左上で `processAllCustomers` を選択→実行→OAuth承認ダイアログで「許可」(spreadsheets/script.scriptapp/userinfo.email の新scope)→実行ログ(表示→ログ)で結果確認。 |
| [action-2] | gas-mail-manager appsscript.json OAuth scope拡大承認(OBS-486-001) | spreadsheets.currentonly→spreadsheets への変更が必要。殿の承認後、appsscript.json更新→clasp push→OAuth再承認が必要。 |
| [action-3] | Violation.md 解決策の殿決裁待ち (cmd_566) | `memory/Violation.md` (318L) に Rule Inventory 18+54件 + Violation 16件 + AC3必須5事例 + **分類深化7軸 + 根本解決策3案 + Phase 1-3 ロードマップ** 完備 (gunshi QC Go)。案A(自動Enforcement,2w,50%) + 案B(Dispatch Gate,1w,25%) + 案C(Retrospective,continuous,31%)。案A+B ハイブリッド推奨。Phase 1-3 どれを採択/優先するかご判断願う。 |
| [action-4] | clasp run 追加認証設定 (cmd_567) | **GAS API有効化✅完了**。次の追加設定が必要 (所要時間: **10-15分**): `clasp run` は Standard GCPプロジェクト連携+OAuth2デスクトップ認証が別途必要。手順: ⓪ **Standard Cloud Project 確認 (必須)**: GASエディタ → 歯車(設定) → 「Googleクラウドプロジェクト」→ プロジェクト番号を記録 (clasp run は script/caller が同一 Standard GCP Project である必要あり。デフォルトプロジェクトではNG) → ① GCPコンソール (console.cloud.google.com) → ⓪で確認した同プロジェクトを選択 → 「APIとサービス」→「認証情報」→ 「認証情報を作成」→「OAuthクライアントID」→ アプリの種類=「デスクトップアプリ」→ JSON ダウンロード → ② JSONファイルを VPS `/home/ubuntu/gas-mail-manager/creds.json` に配置 → ③ VPS で `cd /home/ubuntu/gas-mail-manager && clasp login --creds creds.json` 実行 → ④ 完了後、将軍へ通知 |
| [提案] | F006 重複意義の分割定義 (cmd_566 sug_001) | ash3 発見: F006 は「generated file 禁止」vs「Stall Response 違反」の 2 意義が分散定義。QC 誤認定リスク。Option 1=F006a/F006b 分割 / Option 2=Stall Response を F009 等に切出。Phase 1 前提ゆえ先行解消推奨 (0.5d)。 |
| [提案] | SO-20 重複定義の分離 (cmd_566 sug_002) | ash3 発見: SO-20 は「editable_files 完全性」vs「三点照合 (inbox/artifact/content)」の 2 定義分散。案B (Dispatch Gate) の P1.4 前提ゆえ解消必須。SO-20a/SO-20b 分離 or 新 ID 付与 (0.5d)。 |
| [情報] | cmd_566 Phase 1 着手順推奨 (sug_003) | 殿 Phase 1 採択時の着手順: (1) P1.1 karo.md checklist追補 0.3w → (2) P1.4 gunshi SO-20三点照合自動化 0.3w (F006/SO-20 分離後) → (3) P1.2 shogun_to_karo schema validator 0.5w → (4) P1.3 report YAML validator 0.5w。計 1.6w で 44-50% 予防。 |

## 📊 運用指標

| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 |
|-----------|------------|------|------|----------------|
| 2026-04-22 | 1 | 1 | 0 | 0 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_567 | 手順書更新(GCP関連付け+10-15min+Logger.log確認) SUP2/3/5a注入済 | 足軽1号 | blocked_pending_action |
| cmd_567 | gas_verify.py identity-level検証拡張 SUP1/5b注入済 | 足軽2号 | 拡張作業中 |
| cmd_567 | 顧客数 bug 調査 (b)activeフラグ/key衝突 優先 SUP4注入済 | 足軽3号 | blocked(殿GCP OAuth待ち) |
| cmd_567 | skill資産化+dashboard整理+commit SUP5c注入済 | 足軽4号 | blocked(567a/b/c待ち) |
| cmd_567 | QC 4点 | 軍師 | blocked(567a-d待ち) |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | blocked_pending_action | subtask_567a: 手順書SUP2/3/5a反映+殿GCP OAuth設定完了待ち |
| 足軽2号(Sonnet+T) | 拡張作業中 | subtask_567b: AC5_ext — identity-level検証(--identity-check)実装中 |
| 足軽3号(Sonnet+T) | blocked | subtask_567c: 顧客数bug — (b)activeフラグ/key衝突を優先検証、殿GCP OAuth待ち |
| 足軽4号(Opus+T) | blocked | subtask_567d: skill shogun-gas-automated-verification+SUP5c設計方針反映 |
| 足軽5号(Opus+T) | 待機 | subtask_566c完了: violations 12件抽出(means偽陽性/検証ゲート欠如/RACE-001) |
| 足軽6号(Codex5.3) | 待機 | subtask_566d完了: GitHub Issue 36件scan + violations 16件 SO-01/SO-03 9連続違反確認 |
| 足軽7号(Codex5.3) | 待機 | subtask_566f完了: Violation.md 16件作成 + dashboard action-3 + commit a3a6e5c |
| 軍師(Opus+T) | blocked | subtask_567e: QC 4点(OAuth/再利用性/regression/水平展開) — 567a-d待ち |

## ✅ 本日の戦果（4/24 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 12:00 | gas-mail-manager | cmd_565: clasp push完遂(7ファイル)+skill資産化 / 殿GAS editor action待ち | ✅ means完了 commit 37f7c7f (ash1/ash2) + 565g QC Go(gunshi) |
| 12:21 | memory/ | cmd_566: ルール遵守違反体系調査 Violation.md 318L / 殿のPhase選択待ち | ✅ means完了 commit a3a6e5c (ash3-7) + 566e QC Go(gunshi) |

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
