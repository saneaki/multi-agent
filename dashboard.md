# 📊 戦況報告
最終更新: 2026-04-24 12:10 JST

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
| [action-3] | Violation.md 解決策の殿決裁待ち (cmd_566) | `memory/Violation.md` に .mdルール遵守違反の体系調査ドラフトを作成済み（Rule Inventory + Violation 16件 + AC3必須5事例）。gunshi QC後、抜本解決策案の採択をご判断願う。 |

## 📊 運用指標

| 日付(JST) | /pub-us起動 | 成功 | 失敗 | kill-switch発動 |
|-----------|------------|------|------|----------------|
| 2026-04-22 | 1 | 1 | 0 | 0 |

## 🔄 進行中 - 只今、戦闘中でござる

| cmd | 内容 | 担当 | 状態 |
|-----|------|------|------|
| cmd_566 | ルール遵守違反体系調査 (Rule Inventory / cmd scan / reports scan / GitHub scan) | 足軽3-6号(並列) | 調査中 |
| cmd_566 | Violation.md統合+dashboard+commit | 足軽7号 | blocked(566a-d待ち) |
| cmd_566 | 分類+根本解決策3案+Recommendation+QC | 軍師 | blocked(566f待ち) |

## 🏯 待機中の構成員

| 構成員 | 状態 | 最終タスク |
|------|------|-----------|
| 足軽1号(Sonnet+T) | 待機 | subtask_565a完了: cmd_565 clasp push成功(7ファイル)+殿手順書+commit 37f7c7f |
| 足軽2号(Sonnet+T) | 待機 | subtask_565b完了: skill shogun-gas-clasp-rapt-reauth-fallback 作成(shogun/skills/) |
| 足軽3号(Sonnet+T) | 調査中 | subtask_566a: Rule Inventory — instructions/*.md + rules/common/*.md 棚卸 |
| 足軽4号(Opus+T) | 調査中 | subtask_566b: shogun_to_karo.yaml 364cmd scan — field欠落集計 |
| 足軽5号(Opus+T) | 調査中 | subtask_566c: reports/50件 + global_context.md scan |
| 足軽6号(Codex5.3) | 調査中 | subtask_566d: GitHub Issues全件scan + dashboard過去履歴 |
| 足軽7号(Codex5.3) | blocked | subtask_566f: 統合(Violation.md作成) — 566a-d完了待ち |
| 軍師(Opus+T) | blocked | subtask_566e: 分類+解決策+QC — 565g Go済・566f完了待ち |

## ✅ 本日の戦果（4/24 JST）

| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|
| 12:00 | gas-mail-manager | cmd_565: clasp push完遂(7ファイル)+skill資産化 / 殿GAS editor action待ち | ✅ means完了 commit 37f7c7f (ash1/ash2) + 565g QC Go(gunshi) |

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
