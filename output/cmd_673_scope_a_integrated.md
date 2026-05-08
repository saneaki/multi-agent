# cmd_673 Scope C — 統合判断レポート: sh 実行状況可視化対象スコープ

- 統合者: ashigaru6
- 統合日時: 2026-05-08 13:10 JST
- 親 cmd: cmd_673
- 入力: `output/cmd_673_scope_a_opus.md` (ashigaru6 Opus 視点・27 本 Tier 1) + `output/cmd_673_scope_a_codex.md` (ashigaru3 Codex 視点・22 ファミリ + Claude hooks 6)
- 文書性質: Opus / Codex 独立調査の差分照合 + Scope B-D 実装指示の最終確定。dashboard / scripts / systemd 編集は禁止 (本レポート作成のみ)。

---

## 1. Executive Summary

- **最終 Tier 1 sh リスト**: 30 ファミリ (Opus 27 + Codex 追加 6 - 重複 3) を採用。cron / supervisor / systemd unit / Claude hooks の 4 系統。
- **副次成果物 expected** (Opus 提案) を採用 — cmd_670 incident 同型再発を 1 日以内で検出可能とする。
- **二層管理** (Codex 提案・案 C) を採用 — dashboard は Tier 1 のみ、`logs/sh_health_inventory.yaml` で全 sh 棚卸し。
- **status 判定**: Codex 提案の **対象別 `red_after`** を採用 (5min/10min/hourly/daemon ごとに red 閾値を変える)。Opus 倍率閾値 (× 1.3 / × 3.0) は補助計算式として採用。
- **Claude hooks 監視** (Codex 提案) を Tier 1 に組込み。Stop hook 不発はタスク放置に直結するため除外不可。
- **既存 `## 📊 運用指標` セクションは削除** (両調査一致)。`## 📊 sh 実行状況 (週次)` を新設。
- **Scope B-D 実装着手**: **可** (本統合判断で全 AC 充足分の指示を確定)。

---

## 2. Opus / Codex 差分・収束点

| 観点 | Opus 主張 | Codex 主張 | 統合判断 (採否理由) |
|------|----------|----------|---------------------|
| 監視対象数 | Tier 1 = 27 本 (cron 17 + supervisor 8 + systemd 2) | 22 ファミリ + Claude hooks 6 = 28 | **30 sh ファミリ採用**: Opus 27 ∪ Codex (Claude hooks 6 + ntfy_listener 1 - 重複 4) |
| 全 sh 案 | Tier 0 = 39 本除外 | 案 B (全 sh) 却下 + 案 C (二層管理) 推奨 | **Codex 案 C 採用**: dashboard = Tier 1 / `logs/sh_health_inventory.yaml` = 全 sh 棚卸し。Opus も Tier 0 を `inventory` に含める方向で合流可 |
| 期待頻度設計 | 周期バンド (5min/10min/30min/hourly/6h/daily/daemon-loop) | 個別対象別 red_after マトリクス | **Codex 採用**: 同一周期でも「常駐系 5 分 vs cron 5 分」の閾値が異なるため、対象別 `red_after` が現実的。Opus バンドは初期値計算式として活用 |
| status 判定 | 倍率閾値 × 1.0/1.3/3.0 + 副次成果物 expected | 対象別 red_after + ALERT/RESULT=false の正常扱い | **両者統合**: Codex 個別 red_after + Opus 副次成果物 expected + Codex の「ALERT は failure 扱いせず」 ルール |
| success/failure pattern | sh ごとに YAML 定義 | 共通取得ルール (OK/DONE/ERROR/FAILED) + 対象別取得元 | **両者統合**: 共通 fallback (Codex) + 個別 override (Opus YAML) の二段定義 |
| daemon 検知 | pid + log mtime + systemctl OR | systemctl is-active + ps + log mtime | 同 (4 系統 OR で安全側) |
| **副次成果物 expected** | 提案あり (cmd_complete_notifier に必須適用) | 提案なし | **Opus 採用**: cmd_670 incident 同型再発防止の最重要ガード |
| **Claude hooks 監視** | Tier 0 (hook 駆動・期待頻度定義困難) | Tier 1 (Stop hook 不発 → タスク放置直結) | **Codex 採用**: hook 失敗の影響度は cron 系より高いため、頻度ではなく「7 日以内に 1 件以上 side effect」で監視 |
| ntfy_listener.sh | Tier 0 (通知系 utility) | host guard 配慮で designated host のみ Tier 1 | **Codex 採用**: 殿スマホ入力導線として重要。host 判定 ON で Tier 1 |
| cmd_kpi_observer.sh | Tier 1 (daily 09:00 cron) | 移行期間のみ 🟡 retired-candidate (運用指標削除後 retired) | **Codex 採用**: 📊 運用指標削除と整合。retired_after フィールドで自動除外 |
| 既存 dashboard 影響 | 📊 運用指標 削除 + 境界マーカー新設 | 同 | 一致 |
| 挿入位置 | ✅ 直後 / 🛠️ 直前 | 言及なし | **Opus 採用**: 運用系セクション集約として妥当 |
| dashboard 表示形式 | 🟢 件数のみ / 🟡 🔴 個別 | 6 列表 (sh 名・最終実行・7d success・7d failure・last_error・status) | **両者統合**: 🟢 は件数集計 + 折りたたみ、🟡 🔴 は 6 列表で詳細表示 |

---

## 3. 最終 Tier 1 sh リスト (30 ファミリ)

### 3A. cron 起動 (17 ファミリ)

| # | sh | 引数/役 | 期待頻度 | red_after | 備考 |
|---|----|---------|---------|-----------|------|
| 1 | discord_gateway_healthcheck.sh | — | 5 min | 15 min | 失敗時自動再起動含む |
| 2 | shogun_context_notify.sh | — | 5 min | 60 min | shogun context 警告 |
| 3 | role_context_notify.sh | × 9 (shogun/karo/gunshi/ash1-7 ※将軍除く 9 名) | 5 min/role | 60 min | role 別集計必須 |
| 4 | karo_self_clear_check.sh | — | 10 min | 60 min | karo idle 判定 |
| 5 | gunshi_self_clear_check.sh | — | 10 min | 60 min | 軍師 idle 判定 |
| 6 | safe_window_judge.sh | × 2 (karo/gunshi) | 10 min/role | 60 min | RESULT=false は正常 |
| 7 | detect_compact.sh | × 2 (karo/gunshi) | 10 min/role | 60 min | self compact 検出 |
| 8 | compact_observer.sh | × 2 (karo/gunshi) | 30 min/role | 120 min | compact 統計 |
| 9 | karo_auto_clear.sh | — | 30 min | 90 min | karo idle clear |
| 10 | shogun_in_progress_monitor.sh | — | hourly | 3 h | P1-P9 監視 (cmd_641,642 産物) |
| 11 | shogun_reality_check.sh | — | 1 日 3 回 (21/3/9 UTC) | 12 h | 過剰報告検知 |
| 12 | cmd_kpi_observer.sh | — | daily 09:00 | 50 h | retired_after=2026-06-30 (📊 運用指標削除後) |
| 13 | suggestions_digest.sh | — | daily 09:05 | 50 h | YAML parse error 残存に注意 |
| 14 | dashboard_rotate.sh | — | daily 15:00 UTC (00:00 JST) | 50 h | latest date 当日チェック |
| 15 | restart_n8n.sh | — | daily 18:30 UTC | 50 h | docker/n8n health check |
| 16 | session_to_obsidian.sh | — | daily 13:30 UTC | 50 h | git push failed 監視 |
| 17 | cmd_complete_notifier.sh | — | daemon 5 min loop | 30 min | **副次成果物 expected 必須** |

### 3B. watcher_supervisor 配下 daemon (6 ファミリ)

| # | sh | 期待 | red_after | 備考 |
|---|----|-----|-----------|------|
| 18 | watcher_supervisor.sh | 常駐 5s loop | systemctl failed → red | 親 supervisor 死亡 → 配下全 cascade |
| 19 | inbox_watcher.sh | × 9 (agent 別) 常駐 | log stale 2 h | 各 agent log 個別判定 |
| 20 | shogun_inbox_notifier.sh | 常駐 + event | 60 min stale | duplicate storm 検知 |
| 21 | cmd_squash_pub_hook.sh | 常駐 + event | 60 min stale | failure_total / pending_cmds 監視 |
| 22 | cmd_complete_notifier.sh | (3A-17 と同 — supervisor 配下で起動の場合) | 同上 | 重複登録回避 |

> 注: cmd_complete_notifier は cron / supervisor のいずれで起動しているか実機確認が必要 (Opus § 6 リスク 3 / Codex § 5 リスク同)。Scope B 実装時に `ps` + `crontab -l` で確定し、`config/sh_health_targets.yaml` に `start_via: cron|supervisor` を明記する。

### 3C. systemd --user service (2 unit)

| # | unit | sh | 期待 | red_after |
|---|------|----|-----|-----------|
| 23 | shogun-discord.service | discord_gateway.py (Python だが運用上 Tier 1) | active 必須 | service failed |
| 24 | shogun-watcher-supervisor.service | watcher_supervisor.sh | active 必須 | service failed |

### 3D. Claude hooks (6 ファミリ・新規 Codex 採用)

hook 系は cron/daemon と異なり「期待頻度」が定義困難ゆえ、**「7 日以内に 1 件以上 side effect」** で生存確認。

| # | sh | hook 種類 | side effect 検知 |
|---|----|----------|-----------------|
| 25 | stop_hook_inbox.sh | Stop | `logs/daily/*.md` の inbox delivery 行 |
| 26 | notion_session_log.sh | Stop | Notion session log 投稿成功 |
| 27 | stop_hook_daily_log.sh | Stop | `logs/daily/*.md` の daily summary 行 |
| 28 | pre_compact_snapshot.sh | PreCompact | `queue/snapshots/*.yaml` mtime 7 日以内 |
| 29 | update_dashboard_timestamp.sh | PostToolUse Edit/Write | `dashboard.md` 末尾 timestamp 更新 |
| 30 | ir1_editable_files_check.sh | PostToolUse Edit/Write | `logs/violations/*.md` (発火時のみ) + .claude/settings.json 登録存在 |

> hook 系は **「7 日 side effect ゼロ AND agent active」** の組合わせで 🟡 → settings.json 登録消失 OR script missing で 🔴。

### 3E. ntfy_listener.sh (host guard 付・Tier 1 / 例外)

- designated host (例: srv1121380) でのみ Tier 1 対象。それ以外のホストでは host mismatch exit が正常 → 監視除外。
- `config/sh_health_targets.yaml` に `host_guard: srv1121380` フィールドで定義し、`hostname` 不一致時に対象から自動除外。

### 3F. Tier 2 / Tier 0 (Codex 案 C: 二層管理)

- **Tier 2 (任意・dashboard 折りたたみ表示)**: Opus § 2.Tier2 の 13 本 (inbox_write, context_snapshot, jst_now 等)。Scope B 初期実装ではスキップ、AC 達成後に必要なら追加。
- **Tier 0 (除外)**: 全 sh 棚卸しを `logs/sh_health_inventory.yaml` に保存 (Codex 案 C)。`tier: 0` を持ち、dashboard には載せない。シェルウェア検知 (使用 0 件かつ最終更新 30 日以上) は別途 quarterly レビューで実施。

---

## 4. 期待頻度マトリクス (統合版)

```
バンド          | 期待間隔        | 対象 sh ファミリ                       | green                  | yellow                | red
=========================================================================================================================
5min cron       | 5 分            | discord_gateway_healthcheck,          | log mtime < 7 min      | 7-15 min stale         | > 15 min stale
                |                 | shogun_context_notify,                |                        |                        |
                |                 | role_context_notify × 9               |                        |                        |
10min cron      | 10 分           | karo_self_clear_check,                | < 13 min               | 13-60 min              | > 60 min
                |                 | gunshi_self_clear_check,              |                        |                        |
                |                 | safe_window_judge × 2,                |                        |                        |
                |                 | detect_compact × 2                    |                        |                        |
30min cron      | 30 分           | compact_observer × 2,                 | < 40 min               | 40-120 min             | > 120 min
                |                 | karo_auto_clear                       |                        |                        |
hourly cron     | 1 時間          | shogun_in_progress_monitor            | < 1.5 h                | 1.5-3 h                | > 3 h
6h cron         | 6 時間          | (該当なし — reality_check は daily 3 回扱い) | — | — | —
daily cron      | 24 時間         | shogun_reality_check (3 回/日 → 8h), | < 26 h                 | 26-50 h                | > 50 h
                |                 | cmd_kpi_observer, suggestions_digest, | (reality_check は < 8h) | (8-12h) | (> 12h)
                |                 | dashboard_rotate, restart_n8n,        |                        |                        |
                |                 | session_to_obsidian                   |                        |                        |
daemon-loop     | 5 分以内 tick   | cmd_complete_notifier,                | pid alive + log < 10 min | log 10-60 min stale  | pid dead OR log > 60 min
                |                 | inbox_watcher × 9,                    |                        |                        |
                |                 | shogun_inbox_notifier,                |                        |                        |
                |                 | cmd_squash_pub_hook,                  |                        |                        |
                |                 | watcher_supervisor                    |                        |                        |
systemd unit    | active 必須     | shogun-discord,                       | systemctl active       | active だが child 異常 | failed / inactive
                |                 | shogun-watcher-supervisor             |                        |                        |
Claude hooks    | event-driven    | stop_hook_inbox,                      | settings 登録 + side effect 7d | 14d side effect 0  | settings 消失/script 不在
                |                 | notion_session_log,                   |                        |                        |
                |                 | stop_hook_daily_log,                  |                        |                        |
                |                 | pre_compact_snapshot,                 |                        |                        |
                |                 | update_dashboard_timestamp,           |                        |                        |
                |                 | ir1_editable_files_check              |                        |                        |
```

---

## 5. success / failure / last_error 取得方法 (統合)

### 5.1 共通取得ルール (Codex 採用)

```yaml
last_run:        log file mtime (一次) OR log 内最新 timestamp (二次)
success_count:   7 日以内 success_pattern (デフォ: OK|完了|done|succeeded|PASS|exit 0)
failure_count:   7 日以内 failure_pattern (デフォ: ERROR|FAIL|exit [1-9]|Traceback|denied|FAILED)
last_error:      tail -200 <log> | grep -iE "<failure_pattern>" | tail -1
```

### 5.2 対象別 override (Opus YAML 採用)

`config/sh_health_targets.yaml` で sh ごとに以下を定義:

```yaml
# 例: cmd_complete_notifier 専用 override
cmd_complete_notifier:
  log: logs/cmd_complete_notifier.log
  success_pattern: 'dashboard\.md changed|notify sent'
  failure_pattern: 'notify FAILED|inotifywait not found'
  secondary_artifact:                          # ← Opus 提案 (副次成果物 expected)
    type: notion_db_query
    query: "成果物 DB created_at >= now() - 7d"
    expected_min: 1
    note: 7 日 cmd 完了 ≥ 1 件かつ Notion 登録 ゼロ → 🔴 強制
```

### 5.3 alert / RESULT=false の正常扱い (Codex 採用)

- `safe_window_judge.sh RESULT=false` → 安全窓判定の正常出力。failure_pattern にマッチしないよう除外。
- `shogun_reality_check.sh ALERT` → 検知結果の正常出力。同上。
- `shogun_in_progress_monitor.sh ALERT` → 同上。

### 5.4 daemon 検知 (両者統合)

```
🟢: pid file 存在 + kill -0 成功 + log mtime < 期待 tick × 2
🟡: pid alive + log mtime > 期待 tick × 2 (但し < red_after)
🔴: pid 不在 OR kill -0 失敗 OR log mtime > red_after
```

### 5.5 systemd 検知 (Codex 採用)

```
🟢: systemctl --user is-active = active + child daemon 揃い
🟡: active だが期待 child 数 (例: inbox_watcher × 9) 未達
🔴: failed / inactive
```

### 5.6 Claude hooks 検知 (Codex 採用)

```
🟢: .claude/settings.json に登録あり + 7 日以内に side effect log/file 更新あり
🟡: 14 日 side effect ゼロ (但し agent も idle なら除外検討)
🔴: settings.json から登録消失 OR script ファイル不在
```

---

## 6. status 判定アルゴリズム (統合・最終版)

```
status 判定 (各 sh ファミリ単位)

# 第 1 段: 致命判定
1. (daemon) pid file 不在 OR kill -0 失敗                       → 🔴
2. (systemd) systemctl is-active != active                      → 🔴
3. (Claude hook) settings 登録消失 OR script 不在                → 🔴
4. log mtime > red_after (対象別)                               → 🔴
5. **副次成果物 expected あり** AND 7 日条件不成立              → 🔴 (cmd_670 同型 incident 防止)

# 第 2 段: 警告判定
6. log mtime > 期待間隔 × 1.3 AND ≤ red_after                   → 🟡
7. failure_count_7d ≥ 1                                          → 🟡
8. (Claude hook) 14 日 side effect ゼロ                          → 🟡
9. (daemon) child daemon 期待数未達                              → 🟡
10. success_count_7d < 期待回数 / 2                              → 🟡 (cron 系のみ)

# 第 3 段: 健全
11. それ以外                                                     → 🟢
```

> **重要**: 副次成果物 expected (Step 5) は cmd_complete_notifier に必須適用。**他 sh への適用は段階的拡張** (Scope B 初期は cmd_complete_notifier のみ、AC 達成後に拡大)。

---

## 7. dashboard セクション設計

### 7.1 削除

```
## 📊 運用指標
... (既存テーブル)
```

→ 完全削除。理由: cron 成功/失敗 + auto-compact + その他混在で責務曖昧 (両調査一致)。

### 7.2 新設

挿入位置: `## ✅ 本日の戦果` 直後 / `## 🛠️ メンテ・運用` 直前。

境界マーカー:

```markdown
<!-- SH_HEALTH:START -->
## 📊 sh 実行状況 (週次)

最終確認: <JST timestamp>

### サマリー
- 🟢 健全: <count>/30
- 🟡 警告: <count> 件
- 🔴 停止: <count> 件

### 警告詳細 (🟡)

| sh ファミリ | 最終実行 | 7d success | 7d failure | last_error |
|------------|---------|-----------|-----------|-----------|
| ... (🟡 のみ) | | | | |

### 停止詳細 (🔴)

| sh ファミリ | 最終実行 | 7d success | 7d failure | last_error |
|------------|---------|-----------|-----------|-----------|
| ... (🔴 のみ) | | | | |

### 健全 (🟢) — 折りたたみ

<details>
<summary>🟢 健全 sh 一覧 (<count>)</summary>

(全 🟢 sh の 1 行サマリ)

</details>
<!-- SH_HEALTH:END -->
```

### 7.3 設計理由

- **🟢 を折りたたみ**: ノイズ抑制 (Opus § 6 リスク 2)。
- **6 列表 (Codex)**: 🟡 🔴 のみ詳細表示で殿の確認負荷低減。
- **境界マーカー**: 原子的更新で部分破損を防止 (両調査一致)。
- **最終確認 timestamp**: sh_health_check.sh 起動時刻 (JST)。

---

## 8. config/sh_health_targets.yaml スキーマ提案

```yaml
# config/sh_health_targets.yaml
# Tier 1 監視対象定義 (30 sh ファミリ)

version: 1
last_updated: '2026-05-08'

defaults:
  success_pattern: 'OK|完了|done|succeeded|PASS|exit 0'
  failure_pattern: 'ERROR|FAIL|exit [1-9]|Traceback|denied|FAILED'
  ignore_patterns: []          # ALERT / RESULT=false など
  log_dir: /home/ubuntu/shogun/logs

targets:
  # === 3A. cron 起動 ===
  - name: discord_gateway_healthcheck
    tier: 1
    category: cron
    expected_interval: 300       # 5 min in seconds
    red_after: 900               # 15 min
    log: discord_gateway_health.log
    start_via: cron
    schedule: '*/5 * * * *'

  - name: role_context_notify
    tier: 1
    category: cron
    expected_interval: 300
    red_after: 3600
    log_pattern: 'role_context_notify_{role}.log'
    instances:
      - role: shogun
      - role: karo
      - role: gunshi
      - role: ashigaru1
      - role: ashigaru2
      - role: ashigaru3
      - role: ashigaru4
      - role: ashigaru5
      - role: ashigaru6
      - role: ashigaru7

  - name: cmd_kpi_observer
    tier: 1
    category: cron
    expected_interval: 86400
    red_after: 180000
    log: kpi_observer.log
    start_via: cron
    retired_after: '2026-06-30'  # 📊 運用指標削除後 retired

  - name: safe_window_judge
    tier: 1
    category: cron
    expected_interval: 600
    red_after: 3600
    log_pattern: 'safe_window/{role}.log'
    instances:
      - role: karo
      - role: gunshi
    ignore_patterns: ['RESULT=false']      # 正常出力扱い

  # === 3B. supervisor 配下 daemon ===
  - name: cmd_complete_notifier
    tier: 1
    category: daemon
    expected_tick: 300
    red_after: 1800
    log: cmd_complete_notifier.log
    pid: cmd_complete_notifier.pid
    start_via: supervisor          # 実機確認後決定
    secondary_artifact:            # Opus 提案 (cmd_670 incident 再発防止)
      type: notion_db_query
      query: "成果物 DB created_at >= now() - 7d"
      expected_min: 1
      condition: "cmd 完了件数 >= 1 件のとき"

  - name: inbox_watcher
    tier: 1
    category: daemon
    expected_tick: 300
    red_after: 7200
    log_pattern: 'inbox_watcher_{agent}.log'
    pid_pattern: 'inbox_watcher_{agent}.pid'
    instances:
      - agent: shogun
      - agent: karo
      - agent: gunshi
      - agent: ashigaru1
      - agent: ashigaru2
      - agent: ashigaru3
      - agent: ashigaru4
      - agent: ashigaru5
      - agent: ashigaru6
      - agent: ashigaru7

  # === 3C. systemd unit ===
  - name: shogun-discord
    tier: 1
    category: systemd_unit
    unit: shogun-discord.service
    journal_lookback: '7 days ago'

  - name: shogun-watcher-supervisor
    tier: 1
    category: systemd_unit
    unit: shogun-watcher-supervisor.service
    journal_lookback: '7 days ago'
    expected_children:             # supervisor 配下子 daemon 数
      - inbox_watcher: 9
      - cmd_complete_notifier: 1
      - shogun_inbox_notifier: 1
      - cmd_squash_pub_hook: 1

  # === 3D. Claude hooks ===
  - name: stop_hook_inbox
    tier: 1
    category: claude_hook
    hook_type: Stop
    side_effect_pattern: 'logs/daily/*.md'
    side_effect_window_days: 7
    yellow_window_days: 14

  - name: pre_compact_snapshot
    tier: 1
    category: claude_hook
    hook_type: PreCompact
    side_effect_pattern: 'queue/snapshots/*.yaml'
    side_effect_window_days: 7
    yellow_window_days: 14

  # === 3E. ntfy_listener (host guard) ===
  - name: ntfy_listener
    tier: 1
    category: daemon
    host_guard: srv1121380       # designated host のみ
    expected_tick: 60
    red_after: 600
    log: ntfy_listener.log

# (略 — 全 30 ファミリ・149 instances 同様に定義)
```

---

## 9. Scope B-D 実装指示案

### Scope B: scripts/sh_health_check.sh 実装

**目的**: § 8 の `config/sh_health_targets.yaml` を読み、各 sh ファミリの status を集計して `logs/sh_health_status.yaml` に保存。

**入力**: `config/sh_health_targets.yaml`
**出力**: `logs/sh_health_status.yaml` (タイムスタンプ + 全 sh の status + 集計値)
**呼出元**: systemd --user timer (hourly) — cron でなく timer 推奨 (Opus § 11.5)

**主要ロジック**:
1. YAML を読み込む。
2. 各 target について category 別判定 (cron / daemon / systemd_unit / claude_hook)。
3. 共通取得ルール (§ 5.1) + 対象別 override (§ 5.2) で success/failure/last_error 算出。
4. § 6 のアルゴリズムで 🟢/🟡/🔴 判定。
5. 結果を `logs/sh_health_status.yaml` に書き出し。
6. 副次成果物 expected の Notion 照会は `secondary_artifact.type` 別に分岐 (Phase 2 拡張点)。

**想定行数**: 250-400 行 (config 駆動で簡潔に)

### Scope C: 副次成果物 expected 適用 (cmd_complete_notifier)

**目的**: cmd_670 同型 silent failure を 1 日以内で検出。

**作業**:
1. `config/sh_health_targets.yaml` の `cmd_complete_notifier` に `secondary_artifact` ブロックを追加 (§ 8 例参照)。
2. `sh_health_check.sh` で Notion 成果物 DB を query (Notion API + 環境変数 `NOTION_API_KEY`)。
3. 「7 日 cmd 完了 ≥ 1 件 AND Notion 登録 ゼロ」を 🔴 強制判定。
4. 既存 `Notion-Version: 2022-06-28` 固定。

### Scope D: dashboard 統合

**目的**: dashboard.md に `📊 sh 実行状況` セクションを境界マーカー付きで追加 + `📊 運用指標` 削除。

**作業**:
1. `📊 運用指標` セクション削除 (lines を確認後にカット)。
2. `## ✅ 本日の戦果` 直後に `<!-- SH_HEALTH:START --><!-- SH_HEALTH:END -->` マーカー新設。
3. `scripts/update_dashboard.sh` (既存) を拡張 — マーカー間に `logs/sh_health_status.yaml` から生成した markdown を流し込む (原子的書換え)。
4. `template/dashboard_template.md` に sh_health セクションを追加。

**注意**: dashboard 編集は cmd_674 本体と RACE-001 になり得るため、**Scope D は cmd_674 完了後に着手**。家老が次発令を出すまで待つこと (本タスクの notes で確認済)。

---

## 10. 残課題 / 家老判断仰ぎ事項

| ID | 内容 | 統合判断 / 家老判断必要 |
|----|------|----------------------|
| Q1 | shogun-discord.service (Python) を sh_health_check スコープに含めるか? | **含める** (両調査推奨)。Discord 経由 inbox 断は致命的 |
| Q2 | Tier 2 (13 本) を初期実装に含めるか? | **後回し** (Opus 推奨)。AC 達成後に必要なら追加 |
| Q3 | 副次成果物 expected を全 Tier 1 に拡大するか段階的か? | **段階的** (cmd_complete_notifier のみで開始 → 効果確認後に拡大) |
| Q4 | dashboard 表示形式 (集計 vs 全列挙) | **両者統合済**: 🟢 折りたたみ + 🟡🔴 詳細表示 |
| Q5 | cron `*/10` `*/30` 等を pause 期間 (殿就寝中) で緩和? | **24h 一律** (Opus 推奨。例外運用は混乱の元) |
| Q6 | cmd_complete_notifier 起動経路 (cron / supervisor) は? | **Scope B 実装時に実機 ps + crontab で確定** |
| Q7 | Tier 0 全 sh 棚卸し (`logs/sh_health_inventory.yaml`) 作成タイミングは? | **Scope B と同時** (sh_health_check.sh 初回起動時に自動生成) |
| Q8 | 殿向け alert (🔴 検知時) の通知経路は? | **既存通知統合**: gchat_send.sh + ntfy.sh + Discord (家老判断仰ぎ) |
| Q9 | systemd --user timer 採用は確定? | **確定** (両調査一致。watcher_supervisor.service と統一感) |
| Q10 | retired_after 後の sh は config からも削除するか保持か? | **保持 + tier: retired** (履歴トレース用)。dashboard 表示はオフ |

---

## 11. AC 適合確認 (本統合レポート単体)

| AC | 内容 | 適合 |
|----|------|------|
| C-3 | output/cmd_673_scope_a_integrated.md に両調査の差分・収束点・最終 sh リスト作成 | § 2 (差分・収束点) + § 3 (30 sh ファミリ) で記載 |
| C-3a | Scope B-D 実装用の対象リスト・期待頻度・判定閾値が明確 | § 4 (期待頻度マトリクス) + § 6 (判定アルゴリズム) + § 8 (config スキーマ) + § 9 (Scope B-D 指示) で明記 |

---

## 12. 結論

- **最終 Tier 1 = 30 sh ファミリ** (cron 17 + supervisor 4 + systemd 2 + Claude hooks 6 + ntfy_listener 1)。重複 cmd_complete_notifier は 1 ファミリで集約。
- **設計骨子** (両調査統合):
  - 期待頻度 = Opus バンド初期値 + Codex 対象別 red_after で確定。
  - status 判定 = 第 1 段致命 / 第 2 段警告 / 第 3 段健全の三段ロジック。
  - 副次成果物 expected (Opus) を cmd_complete_notifier に必須適用 (cmd_670 incident 同型再発防止)。
  - 二層管理 (Codex 案 C): dashboard = Tier 1 / `logs/sh_health_inventory.yaml` = 全 sh 棚卸し。
- **dashboard 表示**: 🟢 件数 + 🟡 🔴 個別 6 列表 (両者統合)。境界マーカー `<!-- SH_HEALTH:START/END -->` で原子的更新。
- **既存 📊 運用指標 削除** (両調査一致)。挿入位置 = ✅ 直後 / 🛠️ 直前。
- **Scope B-D 実装着手可否**: **可**。ただし Scope D は cmd_674 本体と RACE-001 になり得るため、家老の次発令を待つこと。
- **実装順序推奨**: Scope B (sh_health_check.sh) → Scope C (副次成果物 expected) → Scope D (dashboard 統合・cmd_674 後)。

---

(integrated report end)
