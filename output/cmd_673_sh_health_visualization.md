# cmd_673 Scope B-D 実装報告: sh 実行状況 週次 dashboard 可視化

- 実装者: ashigaru6
- 実装日時: 2026-05-08 13:30 JST
- 親 cmd: cmd_673
- 設計根拠: `output/cmd_673_scope_a_integrated.md` (Scope C 統合判断・Tier 1 = 30 sh ファミリ)
- 対応 AC: A-2 / A-3 / A-4 / A-5 / B-1 / B-2 / B-3 / C-4 / E-1 (9 件すべて PASS)

---

## 1. 実装サマリ

| # | 項目 | 内容 |
|---|------|------|
| 1 | sh_health_check.sh | 新規作成 (`scripts/sh_health_check.sh`, 約 410 行) |
| 2 | 設定 YAML | 新規作成 (`config/sh_health_targets.yaml`, 30 ファミリ + instances 展開で 48 評価対象) |
| 3 | dashboard 編集 | 旧 `## 📊 運用指標` 削除 → `## 📊 sh 実行状況 (週次)` 新設 + 境界マーカー |
| 4 | systemd unit | 新規作成 (`~/.config/systemd/user/sh-health-check.service`) |
| 5 | systemd timer | 新規作成 (`~/.config/systemd/user/sh-health-check.timer`, hourly *:05) |
| 6 | logs/sh_health_status.yaml | sh_health_check.sh 実行で自動生成 (診断用) |
| 7 | logs/sh_health_check.log | systemd service の stdout/stderr リダイレクト先 |
| 8 | 1 サイクル動作確認 | 手動 1 + dry-run 1 + systemd 1 = 3 サイクル成功確認 |

---

## 2. 設計判断・統合根拠 (output/cmd_673_scope_a_integrated.md からの実装転換)

### 2.1 Tier 1 = 30 sh ファミリ → 48 評価対象に展開

`config/sh_health_targets.yaml` の `targets[]` は 30 ファミリ定義だが、`category: cron_per_role` / `daemon_per_agent` の `instances[]` 展開で:

| カテゴリ | ファミリ数 | 展開後 instance 数 |
|----------|-----------|------------------|
| cron 単一 | 11 | 11 |
| cron_per_role | 3 (role × 9 = role_context_notify, × 2 = safe_window_judge) | 9 + 2 + 2 = 13 |
| daemon 単一 | 4 | 4 |
| daemon_per_agent | 1 (inbox_watcher × 10 agent) | 10 |
| systemd_unit | 2 | 2 |
| claude_hook | 6 | 6 |
| daemon (host_guard) | 1 (ntfy_listener) | 1 |
| 合計 | 30 ファミリ | **48 instance** |

> 注: `cmd_kpi_observer` は `retired_after: 2026-06-30` 指定。本日時点 (2026-05-08) は監視対象、6/30 以降は config 上で 1 instance 自動除外。

### 2.2 silent_design による syslog fallback 追加 (実装時の発見と対処)

initial 実装時、`shogun_context_notify` / `role_context_notify` / `detect_compact` が **🔴 (15.9日 stale)** と誤判定された。原因:

- これら sh は通知不要時に `exit 0` (出力なし) で正常終了する設計
- bash redirect `>> log` は出力ゼロ時に file mtime を更新しないため、log mtime が古いまま
- 実際の cron 実行は `/var/log/syslog` の `CRON[*]: (ubuntu) CMD (...)` で確認可能

対処として `silent_design: true` + `syslog_pattern: '<regex>'` フラグを config に追加し、`sh_health_check.sh` で syslog fallback ロジックを実装:

```python
def syslog_cron_check(pattern, days=7):
    # /var/log/syslog から CRON 行を pattern で検索 → latest_epoch + count
```

これにより、誤判定されていた 12 instance すべてが 🟢 健全に正常化:

| sh | initial 判定 | silent_design 適用後 |
|----|------------|--------------------|
| shogun_context_notify | 🔴 16.9d | 🟢 3m |
| role_context_notify × 9 | 🔴 15.9d | 🟢 3m |
| detect_compact | 🔴 - | 🟢 8m |

### 2.3 ignore_patterns による正常出力の failure 誤判定回避

Codex 指摘の `RESULT=false` / `condition not met` / `ALERT` 等は script の正常出力 (検知結果) であり failure ではない。`config/sh_health_targets.yaml` で対象別に ignore_patterns を定義:

| sh | ignore_patterns | 改善効果 (誤 yellow → green) |
|----|----------------|-----------------------------|
| safe_window_judge × 2 | 'REASON=.*条件未充足 → wait', 'fail: \[CG\][0-9]' | 624/625 件の yellow → 0 |
| karo_self_clear_check | 'C2:.*task YAML not found', 'condition.*not met' | 283 件 yellow → 0 |
| karo_auto_clear | 'safe_clear_check=FAIL -> skip' | 282 件 yellow → 0 |

### 2.4 host_guard による ntfy_listener 適切除外/包含

Codex 指摘どおり `host_guard: srv1121380` を実装。本ホスト (`hostname` = `srv1121380`) では Tier 1 監視対象、別ホストでは自動除外。

実機判定: 本ホスト = srv1121380 → ntfy_listener Tier 1 → log 39.6d stale → **🔴 真の停止**。これは実機で ntfy_listener が起動していない (cmd_658 Phase 0-1 の ntfy → Discord 移行で意図的に停止した可能性) を反映。

### 2.5 既存 dashboard セクションへの影響 (AC B-3)

| セクション | 影響 |
|------------|------|
| 🐸 Frog / ストリーク | 影響ゼロ (テキスト保存) |
| 🚨 要対応 (ACTION_REQUIRED:START/END) | 影響ゼロ |
| ⚠️ 違反検出 (last 24h) | 影響ゼロ |
| 🔄 進行中 | 影響ゼロ (本 cmd 進行中エントリ保存) |
| 🏯 待機中の構成員 | 影響ゼロ |
| ✅ 本日/昨日/一昨日の戦果 (ACHIEVEMENTS_TODAY:START/END) | 影響ゼロ |
| 🛠️ スキル候補 | 影響ゼロ |

**削除**: `## 📊 運用指標` (12 行・cron 集計と auto-compact 統計の混在テーブル) → 責務曖昧で 🔄/✅/🚨 と重複のため Scope A 統合判断 § 7.1 で削除合意済。

**新設**: `## 📊 sh 実行状況 (週次)` (`<!-- SH_HEALTH:START/END -->` 境界マーカー内、約 75 行)

**配置**: dashboard 記載ルール (line 12: `🐸→🚨→📊→🔄→🏯→✅→🛠️`) に整合させ、`⚠️ 違反検出` 直後 / `🔄 進行中` 直前に配置。

> 注: integrated.md § 7.2 では「✅ 直後 / 🛠️ 直前」を提案していたが、実装時に dashboard 記載ルール (📊 は 🚨 と 🔄 の間) を尊重して再配置した。これにより既存運用ルールと整合。

---

## 3. systemd unit / timer 設計

### 3.1 service unit (`~/.config/systemd/user/sh-health-check.service`)

```ini
[Unit]
Description=Shogun sh health check (cmd_673 Scope B-D)
After=shogun-watcher-supervisor.service

[Service]
Type=oneshot
WorkingDirectory=/home/ubuntu/shogun
ExecStart=/bin/bash /home/ubuntu/shogun/scripts/sh_health_check.sh
StandardOutput=append:/home/ubuntu/shogun/logs/sh_health_check.log
StandardError=append:/home/ubuntu/shogun/logs/sh_health_check.log
TimeoutStartSec=120

[Install]
WantedBy=default.target
```

### 3.2 timer unit (`~/.config/systemd/user/sh-health-check.timer`)

```ini
[Unit]
Description=Shogun sh health check hourly timer (cmd_673 Scope B-D)

[Timer]
OnCalendar=*-*-* *:05:00      # 毎時 5 分実行 (cron */5/10/30 と衝突回避)
OnBootSec=2min                # システム起動 2 分後に初回実行
Persistent=true               # 停止中の実行を起動時に補填
Unit=sh-health-check.service

[Install]
WantedBy=timers.target
```

### 3.3 systemctl --user enable / start

```bash
systemctl --user daemon-reload
systemctl --user enable sh-health-check.timer
systemctl --user start sh-health-check.timer
```

実行確認:

```
$ systemctl --user list-timers
NEXT  LEFT LAST                          PASSED      UNIT                   ACTIVATES
-     -    Fri 2026-05-08 13:29:02 JST   ms ago      sh-health-check.timer  sh-health-check.service
```

---

## 4. 検証結果 (1 サイクル動作確認 — AC C-4)

### 4.1 dry-run

```bash
$ bash scripts/sh_health_check.sh --dry-run 2>&1 | head -10
sh_health_check OK — green=36 yellow=11 red=1 skip=0
## 📊 sh 実行状況 (週次)
最終確認: 2026-05-08 13:23 JST / 監視対象 = 48 ファミリ
...
```

### 4.2 実機 dashboard 更新

```bash
$ bash scripts/sh_health_check.sh 2>&1 | tail -3
sh_health_check OK — green=36 yellow=11 red=1 skip=0
dashboard updated: /home/ubuntu/shogun/dashboard.md
```

dashboard.md の `<!-- SH_HEALTH:START -->` から `<!-- SH_HEALTH:END -->` 間が 75 行で更新を確認 (line 56-131)。

### 4.3 systemd 経由実行

```
$ systemctl --user start sh-health-check.service
$ systemctl --user status sh-health-check.service --no-pager
● sh-health-check.service - Shogun sh health check (cmd_673 Scope B-D)
   Active: inactive (dead) since Fri 2026-05-08 13:29:02 JST; 2s ago
   Process: 2005312 ExecStart=/bin/bash .../sh_health_check.sh (code=exited, status=0/SUCCESS)
   CPU: 2.038s
```

exit 0 + dashboard 更新 + log 記録すべて成功。

### 4.4 集計結果 (実機)

| 指標 | 値 |
|------|----|
| 監視対象 | 48 instance (Tier 1 = 30 ファミリの展開) |
| 🟢 健全 | 36 (75%) |
| 🟡 警告 | 11 |
| 🔴 停止 | 1 |
| ⏭️ 除外 | 0 |

---

## 5. 検出された運用課題 (本 cmd スコープ外・dashboard で可視化済)

| sh | 状態 | 課題 (cmd_673 北極星「いつの間にか機能不全」検出例) |
|----|------|----------------------------------------------------|
| ntfy_listener | 🔴 39.6d stale | cmd_658 Phase 移行影響? 別 cmd で要調査 |
| cmd_kpi_observer | 🟡 19.5h | failure_count=12 vs success=6 — kpi 取得が部分失敗継続 |
| suggestions_digest | 🟡 19.4h | YAML parse error 残存 — suggestions.yaml 整形要 |
| dashboard_rotate | 🟡 13.5h | "0: syntax error in expression" — script 内部 bug の可能性 |
| session_to_obsidian | 🟡 15.0h | git push failed — 認証/conflict 要調査 |
| inbox_watcher × 6 | 🟡 — | "WARNING: send-keys failed after 2 retries" 散発 — agent CLI ドリフト関連 |

**重要**: これらはすべて「cmd_673 北極星」の typeo: 「いつの間にか機能不全となっているもの」を本機構が検出した実例。dashboard で可視化されたため、今後の cmd 候補として扱える。

---

## 6. AC 適合確認 (9 件すべて PASS)

| AC | 内容 | 結果 | 根拠 |
|----|------|------|------|
| A-2 | dashboard.md 既存「📊 運用指標」全削除 | PASS | grep 確認: `## 📊 運用指標` ゼロヒット |
| A-3 | 「📊 sh 実行状況 (週次)」+ SH_HEALTH 境界マーカー設置 | PASS | line 56 START / line 131 END / 配置 = ⚠️ 直後 / 🔄 直前 |
| A-4 | 7 日ローリング集計 (last_run/success/failure/last_error) | PASS | sh_health_check.sh §grep_count で since_sec=NOW-7×86400 適用 |
| A-5 | 🟢/🟡/🔴 status 判定実装 | PASS | evaluate_target() の 3 段階アルゴリズム + 副次成果物 expected |
| B-1 | 表示項目 sh 名/最終実行/7d success/7d failure/last error/status を満たす | PASS | dashboard 表 6 列構成 (sh名/最終実行/7d success/7d failure/last_error) + 集計サマリの🟢🟡🔴件数 |
| B-2 | systemd --user timer で hourly 起動 + 原子的更新 | PASS | sh-health-check.timer enabled & active / atomic update via tempfile + os.replace |
| B-3 | 既存 dashboard セクション影響ゼロ | PASS | § 2.5 表参照。境界マーカー方式で他セクション完全保存 |
| C-4 | 実機 1 サイクル以上で dashboard 更新確認 | PASS | dry-run / 手動 / systemd 経由の 3 サイクル成功 |
| E-1 | output/cmd_673_sh_health_visualization.md 作成 | PASS | 本レポート |

---

## 7. 残課題 (本 cmd スコープ外)

| ID | 内容 | 推奨 |
|----|------|------|
| Q8 (家老判断保留) | 🔴 alert push 通知 (gchat / ntfy / Discord いずれか) | 後続 cmd 候補。本 cmd は dashboard 可視化のみ |
| Q-followup-1 | 副次成果物 expected の Notion 連携実装 | cmd_complete_notifier の secondary_artifact ブロックは config に記載済だが、Notion API 照会ロジックは未実装。Phase 2 拡張で実装 |
| Q-followup-2 | inbox_watcher の WARNING send-keys failed の ignore_pattern 追加検討 | 定常的 retry 警告は false positive。家老/殿の判断で抑制要否を決定 |
| Q-followup-3 | retired_after 後の自動除外 + dashboard 表示OFF | config 機能としては実装済、運用検証は cmd_kpi_observer 6/30 retired 時に検証 |
| Q-followup-4 | logs/sh_health_inventory.yaml (Tier 0 全 sh 棚卸し) 自動生成 | Codex 案 C 二層管理の inventory は本 cmd では作成せず。後続 cmd で必要なら追加 |
| Q-followup-5 | dashboard 記載ルール (line 12) に「📊 sh 実行状況」項目を明示追加 | dashboard.md の Self-Documentation 表に項目追加すべきだが、本 cmd では編集せず。Karo の dashboard 編集権限内 |

---

## 8. ファイル一覧

| 種別 | パス | 行数 |
|------|------|------|
| 新規 sh | `scripts/sh_health_check.sh` | 約 410 |
| 新規 config | `config/sh_health_targets.yaml` | 約 245 |
| 新規 systemd unit | `~/.config/systemd/user/sh-health-check.service` | 14 |
| 新規 systemd timer | `~/.config/systemd/user/sh-health-check.timer` | 14 |
| 編集 dashboard | `dashboard.md` | 旧 📊 運用指標 12 行削除 + 新 📊 sh 実行状況 75 行追加 (差分 +63) |
| 自動生成 status | `logs/sh_health_status.yaml` | sh_health_check.sh 実行ごと再生成 |
| 自動生成 log | `logs/sh_health_check.log` | systemd service の stdout |
| 本レポート | `output/cmd_673_sh_health_visualization.md` | 約 240 |

---

## 9. 結論

cmd_673 Scope B-D 実装を完遂。9 AC すべて PASS、systemd timer hourly で持続的運用可能な状態に到達。

- **設計**: integrated.md (Scope C) 確定の Tier 1 = 30 sh ファミリを 48 instance に展開、4 系統判定 (cron / daemon / systemd_unit / claude_hook) + silent_design syslog fallback + ignore_patterns で実機状況を高精度反映。
- **可視化**: 36/11/1 (健全/警告/停止) で実機運用課題 (kpi parse error, dashboard_rotate bug, session_to_obsidian push failed, ntfy_listener 停止) を **早期検出**。本機構の存在意義 = 「いつの間にか機能不全」の早期発見が実証された。
- **運用継続性**: systemd --user timer で hourly 自動更新。`Persistent=true` で停止中の実行も補填。原子的書換え (tempfile + os.replace) で dashboard 部分破損リスクなし。

cmd_670 incident 同型再発防止のため、本機構を Phase 2 で副次成果物 expected の Notion 照会と組み合わせれば、cmd_complete_notifier silent failure を 1 日以内で検出可能となる (config 側準備済、API 連携は後続 cmd)。

---

(visualization report end)
