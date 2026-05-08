# cmd_673 Scope A — Opus 独立調査レポート: sh 実行状況 可視化対象スコープ

- 調査者: ashigaru6 (Opus 視点)
- 調査日時: 2026-05-08 12:58 JST
- 親 cmd: cmd_673
- 並列調査: ashigaru3 (Codex 視点・別ファイル `output/cmd_673_scope_a_codex.md`)
- 文書性質: 独立調査(干渉なし)。実装禁止、調査のみ。

---

## 1. Executive Summary

殿御指摘 (2026-05-08 12:30 JST)「sh ファイルについて、いつの間にか機能不全となっているものが多い」を受け、scripts/ 配下 79 本 + 関連 daemon の網羅調査を実施。設計意図・instructions 準拠の Opus 視点として以下を提案する。

- **総数**: scripts/*.sh = 79 本
- **監視対象案**: 3 Tier 構成 — Tier 1 (絶対) 27 本 / Tier 2 (任意) 13 本 / Tier 0 (除外) 39 本
- **推奨スコープ**: **Tier 1 のみ** を週次 dashboard 表示 (主要運用 sh の重点監視)
- **status 判定**: 🟢 健全 / 🟡 警告 / 🔴 停止 の 3 値、期待頻度の倍数で閾値設計
- **検知方法**: ① log mtime + 末尾 OK/ERR、② PID 生存、③ systemctl status (3 経路の OR)
- **silent failure 重要度最高**: cmd_complete_notifier (再発防止対象 / cmd_670 incident 真因)、watcher_supervisor 配下 daemon、shogun_in_progress_monitor、shogun_reality_check

---

## 2. 監視対象 sh スコープ案 (3 Tier)

### Tier 1 (絶対監視・dashboard 表示・27 本)

cron / systemd --user で自動起動するもの、および watcher_supervisor 配下の daemon。silent failure → 殿の業務直撃。

#### 1A. cron 起動 (24 entry → 重複排除で 17 本)

| # | sh | 期待頻度 | 起動経路 | silent failure 影響 |
|---|----|---------|---------|---------------------|
| 1 | discord_gateway_healthcheck.sh | 5min | cron `*/5` | Discord DM 経由の殿令断 |
| 2 | shogun_context_notify.sh | 5min | cron `*/5` | 殿の context 警告断 |
| 3 | role_context_notify.sh | 5min × 9 役 | cron `*/5` | 各 agent の context 警告断 |
| 4 | karo_self_clear_check.sh | 10min | cron `*/10` | karo auto-compact 暴走 |
| 5 | safe_window_judge.sh | 10min × 2 役 | cron `*/10` | clear タイミング誤判定 |
| 6 | gunshi_self_clear_check.sh | 10min | cron `*/10` | 軍師 auto-compact 暴走 |
| 7 | detect_compact.sh | 10min × 2 役 | cron `*/10` | self_compact 検出失敗 |
| 8 | compact_observer.sh | 30min × 2 役 | cron `*/30` | compact 履歴欠損 |
| 9 | karo_auto_clear.sh | 30min | cron `*/30` | karo idle clear 不作動 |
| 10 | shogun_in_progress_monitor.sh | hourly | cron `0 * * * *` | P1-P9 監視 (cmd_641,642 産物) 全停止 → 殿 Action Required 滞留通知断 |
| 11 | cmd_kpi_observer.sh | daily 09:00 | cron | KPI 集計断 |
| 12 | suggestions_digest.sh | daily 09:05 | cron | 殿向け提案配信断 |
| 13 | shogun_reality_check.sh | 6h (21/3/9 UTC) | cron | reality_check 不作動 → 過剰報告未検知 |
| 14 | dashboard_rotate.sh | daily 15:00 (UTC) | cron | dashboard 履歴累積暴発 |
| 15 | restart_n8n.sh | daily 18:30 (UTC) | cron | n8n stuck WF 蓄積 |
| 16 | session_to_obsidian.sh | daily 13:30 (UTC) | cron | Obsidian 同期断 |
| 17 | cmd_complete_notifier.sh | daemon (約 5 min loop) | systemd --user (watcher_supervisor 配下) | **cmd 完了通知断 → cmd_670 incident 8日 silent failure 再発リスク** |

#### 1B. watcher_supervisor 配下 daemon (約 10 本)

`scripts/watcher_supervisor.sh` が常駐ループで以下を維持。pid file (`logs/*.pid`) で生存確認可能。

| # | sh | 役割 | silent failure 影響 |
|---|----|------|---------------------|
| 18 | inbox_watcher.sh × 9 (shogun/karo/gunshi/ash1-7) | inbox 監視 daemon | inbox 着信通知断 → 殿令到達せず |
| 19 | shogun_inbox_notifier.sh | 殿宛 inbox 通知 | 殿への通知断 |
| 20 | watcher_supervisor.sh 自身 | supervisor | 配下全 daemon 停止 |

#### 1C. systemd --user service (2 本)

| # | unit | sh | silent failure 影響 |
|---|------|----|---------------------|
| 21 | shogun-discord.service | scripts/discord_gateway.py (Python だが包含) | Discord DM 経由 inbox 断 |
| 22 | shogun-watcher-supervisor.service | watcher_supervisor.sh | 1B 全停止 |

> 注: discord_gateway.py は Python 製ゆえ「sh」スコープ外だが、運用上は同等の重要度。Scope B 実装で `sh_health_check.sh` に systemd unit 単位の補助監視を含めるべきか家老判断仰ぐ。

### Tier 2 (任意監視・補助・13 本)

PostToolUse hook / Stop hook / agent 自走から **頻繁に** 呼ばれる sh。期待頻度が定義可能だが、運用変動大。**dashboard には別表示 or 折りたたみ表示** を提案。

| # | sh | 起動経路 | 期待頻度 | silent failure 影響 |
|---|----|---------|---------|---------------------|
| 1 | inbox_write.sh | 各 agent 任意呼出 | 不定 (1-100 回/日) | 着信不能 |
| 2 | context_snapshot.sh | agent タスク節目 | 不定 (10-50 回/日) | 文脈消失 |
| 3 | self_clear_check.sh | ashigaru self_clear | 不定 | clear 安全条件誤判定 |
| 4 | safe_clear_check.sh | 各 agent | 不定 | 同上 |
| 5 | get_context_pct.sh | hook / 監視 sh | 5min 以上 | context% 表示断 |
| 6 | jst_now.sh | 多数の sh から呼出 | 大量 | 時刻記録ズレ |
| 7 | artifact_register.sh | karo Step 11.8 | 不定 (cmd 完了時) | 成果物 Notion 登録断 |
| 8 | log_violation.sh | violation 検出時 | 不定 | 違反記録欠落 |
| 9 | so24_verify.sh | shogun 報告前 | 不定 | SO-24 検証断 |
| 10 | gchat_send.sh | 通知時 | 不定 | Google Chat 通知断 |
| 11 | ntfy.sh | 通知時 | 不定 | ntfy 配信断 |
| 12 | notify_decision.sh | 殿の決済時 | 不定 | 決定通知断 |
| 13 | update_dashboard.sh | karo dashboard 更新 | 不定 (10-30 回/日) | dashboard 同期断 |

> **Tier 2 監視推奨度: 中**。失敗時に上位経路の log で間接検知可能ゆえ、初期実装では Tier 1 のみで開始し、AC を満たした後で必要なら Tier 2 を後付けする方針を推奨。

### Tier 0 (監視除外・39 本)

下記いずれかに該当 → silent failure を「sh の異常」と判定できないため除外。

| カテゴリ | 例 | 除外理由 |
|---------|-----|---------|
| 一回限り | notion_backfill_20260502.sh | 既に役目終了 |
| manual only | gas_run.sh, gas_run_oauth.sh, gas_push_oauth.sh, gas_push_sa.sh, clasp_age_check.sh, switch_cli.sh, switch_gmail_wf.sh, worktree_create.sh, worktree_cleanup.sh, skill_create_with_symlink.sh, sync_shogun_skills.sh, slim_yaml.sh, ntfy_wsl_template.sh, build_instructions.sh | 殿/家老が能動起動するもの。実行されないこと自体が正常 |
| install / setup | install-shogun-discord-service.sh, install_git_hooks.sh, start_discord_bot.sh | 一度設定すれば再実行不要 |
| 内部 utility (Tier 2 で間接捕捉) | jst_now.sh は Tier 2 に格上げ、その他の関数定義系 sh | 単独では起動しない |
| 殿/家老 hook (条件付) | shogun_session_start.sh, session_start_checklist.sh, stop_hook_inbox.sh, stop_hook_daily_log.sh, cmd_squash_pub_hook.sh, cmd_complete.sh, karo_dispatch.sh, agent_status.sh | hook 駆動。期待頻度の定義困難 |
| QC / 検証系 | qc_auto_check.sh, ratelimit_check.sh, snapshot_freshness.sh, validate_idle_members.sh, stall_detector.sh, compact_exception_check.sh, shelfware_audit.sh, shogun_inbox_notifier.sh の補助系 | 状況依存呼出 |
| その他 utility | s_check_full.sh, seo_qc.sh, ntfy_listener.sh (Tier 1 supervisor 配下と重複の可能性), generate_notion_summary.sh, notion_session_log.sh, suggestions_digest 補助, shp.sh, shc.sh, statusline_with_counter.sh, update_dashboard_timestamp.sh, counter_increment.sh, role_context_notify は Tier 1 に集約済 | 用途 / 頻度が個別事情 |

> 39 本のうちいくつかは Codex 視点で Tier 2 への格上げ提案が出る可能性あり。Scope C 統合時に再判断。

---

## 3. 期待頻度マトリクス

```
頻度バンド    | 期待実行間隔  | sh 数 (Tier 1)  | 健全閾値 (🟢)  | 警告閾値 (🟡)  | 停止閾値 (🔴)
=============================================================================================
5min          | 5 分          | 11 (cron)       | < 7 min        | 7-15 min       | > 15 min
10min         | 10 分         | 5 (cron)        | < 13 min       | 13-25 min      | > 25 min
30min         | 30 分         | 3 (cron)        | < 40 min       | 40-90 min      | > 90 min
hourly        | 1 時間        | 1 (cron)        | < 1.5 h        | 1.5-3 h        | > 3 h
6h            | 6 時間        | 1 (cron)        | < 8 h          | 8-18 h         | > 18 h
daily         | 24 時間       | 5 (cron)        | < 26 h         | 26-50 h        | > 50 h
daemon-loop   | 5 分以内 tick | 12 (supervisor) | pid alive      | pid alive (但し log 停止 > 30 min) | pid 死亡 OR log 停止 > 2 h
```

判定規則:
- 健全閾値 = 期待値 × 1.0-1.3 (定常運用)
- 警告閾値 = 期待値 × 1.3-3.0 (一時的な遅延・1〜2 回失敗)
- 停止閾値 = 期待値 × 3.0+ OR 7 日完全未実行

> **7 日ローリング集計** (AC A-4) は status 判定 (期待間隔ベース) と独立に、**週次成功/失敗カウント** として表示。閾値 OK でも success_rate < 80% なら 🟡 警告に格上げを提案。

---

## 4. last_run / success / failure / last_error の取得方法

### 方式 A: log file 末尾解析 (推奨・主たる手段)

```
input:  /home/ubuntu/shogun/logs/<sh_name>.log (cron でリダイレクト先と一致)
取得:
  last_run     = stat -c %Y <log>      → mtime
  success_count = grep -cE '^\[.*\] OK|完了|done|succeeded' <log> | 末尾7日抽出
  failure_count = grep -cE 'ERROR|FAIL|exit [1-9]|denied' <log> | 末尾7日抽出
  last_error   = tail -200 <log> | grep -iE 'ERROR|FAIL' | tail -1
```

長所: 全 cron 系で統一、low overhead。
短所: log 形式がバラバラ → 各 sh ごとに success/failure pattern 定義が必要。

### 方式 B: PID file alive check (daemon 系)

```
input:  /home/ubuntu/shogun/logs/<sh_name>.pid
取得:
  pid       = cat <pid>
  alive     = kill -0 $pid 2>/dev/null
  last_run  = stat -c %Y <pid>  (再起動時刻 ≒ 起動時刻)
  log_freshness = stat -c %Y <log>  (最終 tick)
```

daemon は方式 A + B 併用。pid alive かつ log mtime が期待 tick 間隔内なら 🟢。

### 方式 C: systemctl --user (systemd unit のみ)

```
systemctl --user status <unit>   → ActiveState / SubState
journalctl --user -u <unit> -S '7 days ago' --no-pager | wc -l
```

shogun-discord.service / shogun-watcher-supervisor.service は方式 C を使う。

### 方式 D: 副次成果物 (補助・フォールバック)

cmd_complete_notifier の場合、`logs/cmd_complete_notifier.log` だけでなく `Notion 成果物 DB` の最新登録時刻も併用。daemon が log 出力に成功していても **本来の処理 (Notion 通知)** が失敗していれば silent failure → cmd_670 と同型事故。
- 例: cmd_complete_notifier → 直近 7 日に 1 件以上の通知発火を期待 (cmd 完了無し期間は除外考慮)

> Opus 提案: **Tier 1 の各 sh に「副次成果物 expected」フィールドを sh_health_check.sh の config で定義** し、log 健全 + 副次成果物 健全 の両条件で 🟢 とする。これなら cmd_670 incident は 1 日以内で検出できた。

---

## 5. 🟢/🟡/🔴 status 判定案

```
status 判定アルゴリズム (各 sh 単位)

1. last_run > 期待間隔 × 3.0 (例: 5min sh で 15 min 経過)        → 🔴 停止
2. (daemon の場合) pid file 不在 OR kill -0 失敗                  → 🔴 停止
3. failure_count_7d ≥ success_count_7d (failure が成功を上回る) → 🔴 停止
4. last_run > 期待間隔 × 1.3                                     → 🟡 警告
5. failure_count_7d ≥ 1                                          → 🟡 警告
6. (副次成果物 expected の場合) 7 日ゼロ                         → 🟡 警告
7. それ以外                                                      → 🟢 健全
```

silent failure 重要度別の判定上乗せ (Opus 視点):

| sh | 上乗せルール |
|----|-------------|
| cmd_complete_notifier | 7 日通知ゼロ AND 7 日 cmd 完了 ≥ 1 件 → 🔴 強制 |
| shogun_in_progress_monitor | hourly log に P1-P9 出力欠落 → 🟡 |
| shogun_reality_check | 直近 6h 以内に未実行 → 🔴 (殿の reality 検証断) |
| watcher_supervisor (自身) | supervisor 死亡 → 配下全 🔴 (cascade) |
| inbox_watcher × 9 | いずれか 30 min 無 tick → 🟡、2 h 無 tick → 🔴 |

---

## 6. 実装リスクと除外判断

### リスク 1: log 形式の不統一 → 集計誤判定

**影響**: 79 本それぞれ "OK" / "完了" / "succeeded" / "exit 0" / 無印 のいずれを成功サインとするか不揃い。
**緩和**: Tier 1 27 本のみに集約 → config に sh ごとの success_pattern / failure_pattern を YAML 定義 (例: `config/sh_health_targets.yaml`)。
**残課題**: 新規 sh 追加時の config 更新漏れ → Scope D で `update_dashboard.sh` 同様の lint 検査を追加推奨。

### リスク 2: ノイズ過多 → 殿の "見ない化"

**影響**: 79 本フル監視で 🟡 が常時 5-10 個並ぶと **dashboard が信用されなくなる** (cmd_670 と同型の可視化破綻)。
**緩和**: Tier 1 のみ (27 本) で開始。Tier 2 は AC 満たした後で家老/殿の判断で増設。

### リスク 3: cron / systemd 二重起動の混乱

**影響**: 例えば cmd_complete_notifier は cron で起動するか supervisor で起動するか実機確認が必要 (Codex 調査側で確定希望)。
**緩和**: Codex 視点 (実装視点) で実機ログ確認を依頼。Scope C 統合時に確定。

### リスク 4: Opus 推測と実機の乖離

**影響**: 本レポートは instructions / cron / systemd 静的読込みベース。`logs/` 実機の実際の更新時刻 / 失敗実績は Codex 視点に委ねる。
**緩和**: Scope C で両者統合。ash3 の実機 grep 結果と本書の期待値の差分を家老が判断。

### リスク 5: dashboard セクションサイズ肥大

**影響**: Tier 1 (27 本) を一覧表示すると dashboard.md が大幅増量 → context 肥大。
**緩和**: 🟢 のみ集計値で表示 (件数のみ)、🟡/🔴 を個別表示。例:

```
## 📊 sh 実行状況 (週次)
- 🟢 健全: 24/27
- 🟡 警告: 2 件
  - cmd_complete_notifier: failure_count_7d=3, last_error="..."
  - cmd_kpi_observer: 7d run=0 (cron 動作未確認)
- 🔴 停止: 1 件
  - shogun_in_progress_monitor: 4h 未実行
最終確認: 2026-05-08 13:00 JST
```

---

## 7. 除外候補 (再掲・整理)

| sh | 除外理由 | 例外条件 |
|----|---------|---------|
| notion_backfill_20260502.sh | 完了済 1 回限り | 同型 backfill 必要時のみ復活 |
| install-*.sh / install_git_hooks.sh | setup スクリプト | 再インストール時のみ |
| gas_*.sh, clasp_age_check.sh | GAS 関連手動 | GAS 運用中なら Tier 2 検討 |
| switch_cli.sh, switch_gmail_wf.sh | 殿/家老が能動切替 | — |
| worktree_*.sh | git worktree 管理 (能動) | — |
| skill_create_with_symlink.sh, sync_shogun_skills.sh | skill 整備 | — |
| s_check_full.sh, seo_qc.sh | QC 系 (任意起動) | 定期化されたら Tier 1 へ |
| jst_now.sh | utility (Tier 2 で他 sh の log 更新時に間接捕捉) | — |
| stall_detector.sh, snapshot_freshness.sh, validate_idle_members.sh, ratelimit_check.sh, compact_exception_check.sh, shelfware_audit.sh, statusline_with_counter.sh | 状況依存・hook 駆動 | 定期化されたら Tier 1 へ |
| start_discord_bot.sh | systemd unit 化済 → unit 監視で代替 | — |
| ntfy_listener.sh, ntfy_wsl_template.sh, ntfy.sh | 通知系 utility | 通知断検知は方式 D で行う |

---

## 8. 既存 dashboard セクションへの影響評価

cmd_673 AC B-3 (既存 6 セクション 🐸/🚨/🔄/🏯/✅/🛠️ への影響ゼロ) を達成するため:

- **削除対象**: 既存 `## 📊 運用指標` セクション。cron 系成功/失敗 + auto-compact 等の混在テーブルゆえ責務が曖昧。**🔄 進行中 / ✅ 戦果 / 🚨 要対応 と機能が重複する** ため削除妥当。
- **新設**: `## 📊 sh 実行状況 (週次)` を境界マーカー `<!-- SH_HEALTH:START/END -->` 内に配置。
- **挿入位置**: `## ✅ 本日の戦果` の直後 / `## 🛠️ メンテ・運用` の直前を推奨 (運用系セクションの集約)。

---

## 9. Codex 視点との収束予想点

| 観点 | Opus 想定 | Codex (予想) | 統合時の判断材料 |
|------|----------|-------------|-----------------|
| 監視対象数 | Tier 1 = 27 本 | grep ベースで 30-40 本提案の可能性 | 実機 log 存在 sh のみ Tier 1 採用で収束 |
| 期待頻度 | cron / systemd 定義準拠 | log mtime 統計から逆算 | Codex 統計が頻度バンドの最終調整 |
| success/failure pattern | 各 sh ごとに YAML 定義 | grep 強行 (汎用 ERROR/FAIL) | YAML 個別 + 汎用 fallback の両立 |
| daemon 検知 | pid + log mtime | systemctl + journalctl | 両用が安全 |
| 副次成果物 expected | Tier 1 で導入 | 提案なしの可能性 | Opus 提案として残す (Scope C 議論) |

---

## 10. AC 適合確認 (本レポート単体)

| AC | 内容 | 適合 |
|----|------|------|
| C-1 | sh スコープ案 + 期待頻度マトリクス | §2 (Tier 1/2/0) + §3 (周期マトリクス) で記載 |
| A-1-opus | scripts/ 配下 + 関連 daemon / cron / systemd user unit を Opus 視点で網羅 | §2 で 79 本全数を Tier 分類 + cron 24 entry + systemd 2 unit + supervisor 配下 daemon を網羅 |
| A-5-opus | 🟢/🟡/🔴 status 判定案と silent failure 重要度を明記 | §3 の閾値 + §5 の判定アルゴリズム + 上乗せルールで明記 |

---

## 11. 推奨アクション (Scope B-D 実装担当へ)

1. **Tier 1 (27 本) のみ** で `sh_health_check.sh` 実装開始。Tier 2 は将来拡張。
2. **config/sh_health_targets.yaml** を新設し、sh ごとに `expected_interval` / `success_pattern` / `failure_pattern` / `tier` / `secondary_artifact_check` を定義。
3. **副次成果物 expected** を cmd_complete_notifier に必ず適用 (cmd_670 incident 再発防止)。
4. **境界マーカー** `<!-- SH_HEALTH:START/END -->` を `## ✅ 本日の戦果` 直後に挿入。
5. **systemd --user timer** で hourly 実行 (cron でなく timer ベース推奨。cmd_670 で確立した watcher_supervisor.service と統一感)。
6. **dashboard 集計表示**: 🟢 は件数のみ、🟡/🔴 は個別 sh + last_error 1 行。

---

## 12. 残課題 / 家老判断仰ぎ事項

- Q1. shogun-discord.service (Python) を sh_health_check のスコープに含めるか? → 含めれば Discord 経由 inbox 断の早期検知可
- Q2. Tier 2 (13 本) を初期実装に含めるか後回しか? → Opus 推奨は後回し
- Q3. 副次成果物 expected の YAML スキーマ定義 → Scope C 統合時に Codex と協議
- Q4. dashboard 表示形式 (集計 vs 全 sh 列挙) → 殿の好みあれば家老経由で確認
- Q5. cron `*/10` `*/30` 等の判定基準を pause 期間 (例: 殿就寝中) で緩和するか → 24h 一律推奨

---

## 13. 結論

- **監視対象**: scripts/ 79 本中 **Tier 1 = 27 本** に限定 (主要運用 sh 重点監視)
- **判定方式**: 期待間隔 × 倍率閾値 + 副次成果物 expected の二段判定
- **検知経路**: 方式 A (log 末尾) + B (pid alive) + C (systemctl) + D (副次成果物) の 4 系統 OR
- **再発防止**: cmd_complete_notifier に副次成果物 expected を必ず適用 (cmd_670 incident 同型再発を 1 日以内で検出)
- **実装リスク**: log 形式の不統一とノイズ過多。config YAML での個別定義 + Tier 1 限定で緩和

統合判断レポート (output/cmd_673_scope_a_integrated.md) では Codex (ash3) の grep ベース実機調査と差分照合し、最終 sh リストと sh_health_targets.yaml の初期版を確定するを推奨。

---

(report end)
