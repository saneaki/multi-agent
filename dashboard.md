# 📊 戦況報告
最終更新: 2026-04-24 12:23 JST

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
| (完了待ち) | なし | - | - |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | 待機 | subtask_565a完了: cmd_565 clasp push成功(7ファイル)+殿手順書+commit 37f7c7f |
| 足軽2号(Sonnet+T) | 待機 | subtask_565b完了: skill shogun-gas-clasp-rapt-reauth-fallback 作成(shogun/skills/) |
| 足軽3号(Sonnet+T) | 待機 | subtask_566a完了: Rule Inventory 54 Rule IDs/62 defs 不整合2件(F006/SO-20)検出 |
| 足軽4号(Opus+T) | 待機 | subtask_566b完了: shogun_to_karo.yaml 364cmd scan — field欠落集計完了 |
| 足軽5号(Opus+T) | 待機 | subtask_566c完了: violations 12件抽出(means偽陽性/検証ゲート欠如/RACE-001) |
| 足軽6号(Codex5.3) | 待機 | subtask_566d完了: GitHub Issue 36件scan + violations 16件 SO-01/SO-03 9連続違反確認 |
| 足軽7号(Codex5.3) | 待機 | subtask_566f完了: Violation.md 16件作成 + dashboard action-3 + commit a3a6e5c |
| 軍師(Opus+T) | 待機 | subtask_566e完了(QC Go): 分類7軸+解決策3案+Recommendation / Violation.md 99L→318L |

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
