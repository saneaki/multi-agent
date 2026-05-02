# cmd_639: self_clear / self_compact / auto_clear / auto_compact 現状実装ドキュメント

**作成日**: 2026-05-03 JST
**作成者**: ashigaru5
**親 cmd**: cmd_639
**性質**: 事実・データのみ。改善案・仮説は含まない (殿令)。

---

## AC1. agent × 機構 一覧表

| agent | self_clear (手動 /clear) | self_compact (手動 /compact) | auto_clear (cron) | auto_compact 検出 | context 通知 (cron) | PreCompact hook |
|---|---|---|---|---|---|---|
| shogun | あり (殿が手動入力) | あり (殿が手動入力) | **なし (F001 禁止)** | なし | `shogun_context_notify.sh` */5 | `safe_clear_check.sh --agent-id shogun` (常時 SKIP) |
| karo | あり (`karo_self_clear_check.sh`) | あり (本人が判断、`compact_exception_check.sh` ガード経由可) | あり (`karo_auto_clear.sh` */30、`karo_self_clear_check.sh` */10) | あり (`compact_observer.sh karo` */30、`detect_compact.sh karo` */10) | `role_context_notify.sh karo` */5 | `safe_clear_check.sh --agent-id karo` |
| gunshi | あり (`gunshi_self_clear_check.sh`) | あり (本人が判断) | なし (cron に gunshi 専用 auto_clear なし。`gunshi_self_clear_check.sh` は判定のみで context_advisory 送信止まり) | あり (`compact_observer.sh gunshi` */30、`detect_compact.sh gunshi` */10) | `role_context_notify.sh gunshi` */5 | `safe_clear_check.sh --agent-id gunshi` |
| ashigaru1〜7 | あり (本人が `self_clear_check.sh $AGENT_ID` を Step 9.7 で実行) | あり (本人手動) | **なし (cron 設定なし)** | **なし (cron 設定なし)** | `role_context_notify.sh ashigaruN` */5 (各 agent ごとに 1 行) | `safe_clear_check.sh --agent-id ashigaruN` |

注:
- 「PreCompact hook」: `~/.claude/settings.json` の PreCompact 配列に登録された `safe_clear_check.sh` 呼び出し。`AGENT_ID` を tmux pane プロパティから取得し、`--tool-count 0` で実行 (snapshot 副作用とログ記録目的)。
- 「self_compact」: 多くは agent 自身の判断で `/compact` を直接打鍵。スクリプトによる強制発動はない。`compact_exception_check.sh` は preserve_across_stages 要件下での例外発動を許可するガードのみ。

---

## AC2. 各機構の詳細

### 2.1 `scripts/karo_self_clear_check.sh`
- **path**: `/home/ubuntu/shogun/scripts/karo_self_clear_check.sh`
- **cron**: `*/10 * * * * bash .../karo_self_clear_check.sh --tool-count 200 >> logs/safe_clear/karo.log 2>&1`
- **判定条件 (全 AND)**:
  - cond_1: `queue/shogun_to_karo.yaml` に `status=in_progress` の cmd がゼロ
  - cond_2: 全 `queue/tasks/ashigaru*.yaml` + `gunshi.yaml` が `status=idle`
  - cond_3: `queue/inbox/karo.yaml` の `read:false` エントリがゼロ
  - cond_4: 進行中 cmd に `context_policy=preserve_across_stages` なし
  - cond_5: `tool_count > 50`
- **発動経路**: 全 PASS → `safe_window_judge.sh --agent-id karo` 連携 → `SAFE_WINDOW_RESULT=true` なら `inbox_write.sh karo "..." context_advisory karo_self_judge` を投函 (clear_command ではなく advisory)。`safe_window_judge.sh` 不在時は旧来の `clear_command` フォールバック。
- **dedup**: `/tmp/karo_context_advisory_last_sent` で 30 分以内の重複送信を抑止。
- **log**: `logs/safe_clear/karo.log` (および `/tmp/self_clear_karo.log`)

### 2.2 `scripts/gunshi_self_clear_check.sh`
- **path**: `/home/ubuntu/shogun/scripts/gunshi_self_clear_check.sh`
- **cron**: `*/10 * * * * bash .../gunshi_self_clear_check.sh --tool-count 200 >> logs/safe_clear/gunshi.log 2>&1`
- **判定条件 (全 AND)**:
  - cond_1: `queue/inbox/gunshi.yaml` の `read:false` がゼロ
  - cond_2: `queue/tasks/gunshi.yaml` の status が `idle/done/completed` のいずれか
  - cond_3: shogun_to_karo.yaml に preserve_across_stages な in_progress cmd がゼロ
  - cond_4: `tool_count > 30`
- **発動経路**: 全 PASS → `safe_window_judge.sh --agent-id gunshi` 連携 → APPROVE 時に `inbox_write.sh gunshi "..." context_advisory gunshi_self_judge` を投函。
- **dedup**: `/tmp/gunshi_context_advisory_last_sent` で 30 分以内の重複送信を抑止。
- **log**: `logs/safe_clear/gunshi.log`

### 2.3 `scripts/karo_auto_clear.sh`
- **path**: `/home/ubuntu/shogun/scripts/karo_auto_clear.sh`
- **cron**: `*/30 * * * * /bin/bash .../karo_auto_clear.sh >> /tmp/karo_auto_clear.log 2>&1`
- **判定条件**:
  - inbox `read:false` 件数 = 0
  - ashigaru*.yaml + gunshi.yaml の `assigned/in_progress` が 0
  - E1 ガード: `compact_observer.sh karo` で `TRIGGER=pre_compact` かつ最終 compact から 300 秒未満なら skip
  - E2 ガード: ashigaru*.yaml が 1 分以内に書き換わっていれば skip
  - E3 ガード: `/tmp/karo_auto_clear.lock` flock
  - `safe_clear_check.sh --agent-id karo` 結果が PASS
  - tmux pane の最終 5 行に `│ >`/`^>`/`claude-code` のいずれか (E6 active prompt ガード)
- **発動経路**: 全 PASS → `tmux send-keys -t multiagent:0.<karo_pane> "/clear" C-m`
- **log**: `/tmp/karo_auto_clear.log`、内部判定の補助 log は `/tmp/karo_auto_clear_safe_check.log`

### 2.4 `scripts/safe_clear_check.sh`
- **path**: `/home/ubuntu/shogun/scripts/safe_clear_check.sh`
- **cron**: 直接の cron 登録なし。`karo_auto_clear.sh` および PreCompact hook から呼び出し。
- **判定条件 (全 Role 共通 AND)**:
  - C1: `queue/inbox/{agent_id}.yaml` の `read:false` = 0
  - C2: `queue/tasks/{agent_id}.yaml` の status が `idle/done/completed`
  - C3: `dispatch_debt` = 0 (karo のみ — `status:blocked` かつ `blocked_by` 全 done のタスクなし)
  - C4: shogun_to_karo.yaml に preserve_across_stages な in_progress なし
  - role 別 tool_count 閾値: shogun=0(常時 SKIP), karo=50, gunshi=30, ashigaru=30
- **発動経路**: 全 PASS で `inbox_write.sh {agent_id} "..." clear_command {agent_id}` を投函 (非 dry-run 時)。`shogun` は role 判定段階で常時 SKIP (F001)。
- **log**: `logs/safe_clear/{agent_id}.log`

### 2.5 `scripts/self_clear_check.sh` (足軽用)
- **path**: `/home/ubuntu/shogun/scripts/self_clear_check.sh`
- **cron**: 直接の cron 登録なし (足軽が手動で呼出)。
- **呼出規約 (instructions/ashigaru.md)**: タスク完了後 Step 9.7 で `bash scripts/self_clear_check.sh $AGENT_ID` を実行。
- **判定条件**:
  - `queue/tasks/{agent_id}.yaml` の status が `done/idle/completed` のいずれか (`assigned/in_progress` なら skip)
  - `tool_count > 30`
- **発動経路**: 閾値超で `inbox_write.sh {agent_id} "..." clear_command {agent_id}` を投函。
- **log**: `/tmp/self_clear_{agent_id}.log`

### 2.6 `scripts/safe_window_judge.sh`
- **path**: `/home/ubuntu/shogun/scripts/safe_window_judge.sh`
- **cron**:
  - `*/10 * * * * bash .../safe_window_judge.sh --agent-id karo --context-pct "$(get_context_pct.sh karo)" >> logs/safe_window/karo.log 2>&1`
  - `*/10 * * * * bash .../safe_window_judge.sh --agent-id gunshi --context-pct "$(get_context_pct.sh gunshi)" >> logs/safe_window/gunshi.log 2>&1`
- **判定条件**:
  - karo (C1-C5): C1 `context_pct≥70`、C2 `actionable_unread=0` (type ∈ {task_assigned, blocked, escalate})、C3 dashboard.md 🔄 行数=0、C4 `dispatch_debt=0`、C5 karo idle 秒数 ≥ 閾値 (`/tmp/shogun_idle_karo` mtime 起点。context_pct ≥80→30s、≥70→60s、それ以下→300s)
  - gunshi (G1-G4): G1 `context_pct≥60`、G2 `queue/tasks/gunshi.yaml` status=done/completed/idle、G3 inbox の type=task_assigned read=false が 0、G4 actionable_unread=0
  - ashigaru: `safe_clear_check.sh --dry-run` に委譲
- **推奨選択**:
  - context_pct ≥85: 強制 `/compact`
  - karo C1-C5 全 PASS: `/clear` 推奨
  - karo C3 (in_progress≥1) かつ context≥70%: `/compact` 推奨
  - gunshi G1-G4 全 PASS: `/clear` 推奨
  - gunshi G2/G3 NG かつ context≥60: `/compact` のみ可
  - 他: wait
- **副作用**: karo 宛のみ `compact_suggestion` 通知を inbox 送信 (`/tmp/safe_window_judge_notify_karo.ts` で 600 秒 dedup)。
- **log**: `logs/safe_window/{agent_id}.log`

### 2.7 `scripts/compact_observer.sh`
- **path**: `/home/ubuntu/shogun/scripts/compact_observer.sh`
- **cron**:
  - `*/30 * * * * bash .../compact_observer.sh karo >> logs/compact_observer.log 2>&1`
  - `*/30 * * * * bash .../compact_observer.sh gunshi >> logs/compact_observer.log 2>&1`
- **判定条件**: `~/.claude/sessions/compaction-log.txt` を grep。`queue/snapshots/{agent_id}_snapshot.yaml` の `trigger=pre_compact` を agent 固有 compaction として検知。
- **発動経路**: 統計を `/tmp/compact_stats_{role}.json` に書込み + stdout に `ROLE=... COUNT_TODAY=... COUNT_7D=... AGENT_TODAY=... TOTAL=... LAST=... TRIGGER=...`。
- **日次 rotate**: `compact_history.log` に前日 stats を退避。
- **log**: `logs/compact_observer.log`、`logs/compact_history.log`

### 2.8 `scripts/detect_compact.sh`
- **path**: `/home/ubuntu/shogun/scripts/detect_compact.sh`
- **cron**:
  - `*/10 * * * * bash .../detect_compact.sh karo >> logs/compact_log/cron.log 2>&1`
  - `*/10 * * * * bash .../detect_compact.sh gunshi >> logs/compact_log/cron.log 2>&1`
- **判定条件**: `tmux capture-pane -t <agent_pane> -p -S -200` で取得。3 マーカーを検出:
  - `❯ /compact` (user 入力痕跡)
  - `Compacting conversation` (Claude Code 表示)
  - `[Compaction occurred at` (session 保存ログマーカー)
- **冪等性**: 1 時間粒度 (`HOUR_KEY`) + 同一 ROLE + 同一 MARKERS の重複行を skip。
- **log 出力先**: `logs/compact_log/{agent_id}.log` (cron 実行ログは `logs/compact_log/cron.log`)

### 2.9 `scripts/compact_exception_check.sh`
- **path**: `/home/ubuntu/shogun/scripts/compact_exception_check.sh`
- **cron**: 登録なし (agent が手動呼出)
- **判定条件 (全 AND)**:
  - cond_1: shogun_to_karo.yaml に `status=in_progress` かつ `context_policy=preserve_across_stages` の cmd が 1 件以上
  - cond_2: `context_pct > 80`
  - cond_3: cond_1 を満たすため /clear 実施不能
- **発動経路**: 全 PASS で `context_snapshot.sh write` を強制実行 + `logs/compact_exceptions.log` に記録 + stdout 構造化行 (`compact_exception=approved` 等)。`/compact` の発動自体は呼出元 agent が行う。
- **log**: `logs/compact_exceptions.log`

### 2.10 `scripts/shogun_in_progress_monitor.sh`
- **path**: `/home/ubuntu/shogun/scripts/shogun_in_progress_monitor.sh`
- **cron**: `0 * * * * cd .../shogun && bash scripts/shogun_in_progress_monitor.sh >> logs/in_progress_monitor.log 2>&1`
- **検出パターン (P1〜P6)**:
  - P1: shogun→karo 送信済 + task YAML 不在 (家老 dispatch 漏れ)
  - P2: dashboard.yaml.in_progress 空 + task YAML active
  - P3: ashigaru task YAML status=assigned/in_progress + promoted_at 60min 超 + ファイル mtime 30min 超
  - P4: dashboard.yaml.last_updated 90min 超
  - P5: shogun inbox 未処理 action_required > 30min
  - P6: dashboard.md `最終更新:` 行 120min 超
- **発動経路**: 検出時 `inbox_write.sh shogun "..." in_progress_monitor_alert shogun_in_progress_monitor` + `ntfy.sh`。1 時間内同 key dedup。
- **log**: `logs/in_progress_monitor.log`

### 2.11 `scripts/safe_window_judge.sh` 内ヘルパ呼出: `dashboard.md 🔄`
- karo C3 判定では `dashboard.md` の `## 🔄 進行中` 見出しから次の `## ` までを抽出し、`| cmd_XXX |` の行数を集計。

### 2.12 PreCompact hook 経由の `safe_clear_check.sh`
- **設定箇所**: `~/.claude/settings.json` PreCompact 配列。
- **コマンド**: `AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p "#{@agent_id}" 2>/dev/null || echo "unknown"); bash .../safe_clear_check.sh --agent-id "$AGENT_ID" --tool-count 0 2>/dev/null || true`
- **挙動**: `--tool-count 0` 指定のため、role 別閾値 (karo 50 / gunshi 30 / ashigaru 30) を必ず下回り `tool_count_below` で SKIP となる。実質的には log 副作用のみ。

---

## AC3. 24h 発動実績 (集計対象 cutoff: 2026-05-02T00:59 UTC = 2026-05-02T09:59 JST)

| 機構 | 集計値 | log path |
|---|---|---|
| `karo_self_clear_check.sh` | START=112 / SKIP=112 / ALL_PASSED=0 / clear_command 送信=0 / context_advisory 送信=0 | `logs/safe_clear/karo.log` |
| `gunshi_self_clear_check.sh` | START=98 / SKIP=10 / ALL_PASSED=88 / clear_command 送信=0 / context_advisory 送信=88 / safe_window_no_approve=88 | `logs/safe_clear/gunshi.log` |
| `safe_window_judge.sh karo` | START=90 / RESULT=true=0 / RESULT=false=90 (内訳: REC=/compact=5、REC=wait=85) | `logs/safe_window/karo.log` |
| `safe_window_judge.sh gunshi` | START=134 / RESULT=true=32 / RESULT=false=102 (内訳: REC=/clear=32、REC=/compact=17、REC=wait=85) | `logs/safe_window/gunshi.log` |
| `karo_auto_clear.sh` | 行数=102 (24h+α 累積)。最近 24h は cron 約 48 回実行内訳で idle=false skip と safe_clear_check=FAIL skip がほぼすべて。clear 送信=0 | `/tmp/karo_auto_clear.log` |
| `compact_observer.sh` (karo+gunshi) | START≒620 / END≒460 (snapshot 読込: snapshot_found=62) / new compaction detected=4 | `logs/compact_observer.log` |
| `detect_compact.sh karo` | **ログなし (`logs/compact_log/karo.log` ファイル自体不在)** | `logs/compact_log/karo.log` |
| `detect_compact.sh gunshi` | **ログなし (`logs/compact_log/gunshi.log` ファイル自体不在)** | `logs/compact_log/gunshi.log` |
| `detect_compact.sh` cron 実行ログ | `logs/compact_log/cron.log` サイズ=0 byte | `logs/compact_log/cron.log` |
| `shogun_in_progress_monitor.sh` | 全行=5 / アラート=2 (P2 dashboard 鮮度乖離 ×2) / 異常なし=1 | `logs/in_progress_monitor.log` |
| ashigaru × `safe_clear_check.sh` (PreCompact hook) | ashigaru1=0、ashigaru4=0、ashigaru5=5、ashigaru7=0 (24h 内ログ行) | `logs/safe_clear/ashigaru{N}.log` |
| ashigaru × `self_clear_check.sh` (手動) | ashigaru5 で 5 行記録あり (うち全て C2 NG `task status='assigned'` で SKIP)。他 ashigaru は 24h 内更新なし | `logs/safe_clear/ashigaru{N}.log` (兼用) / `/tmp/self_clear_ashigaru{N}.log` |
| auto_compact 発生 (`~/.claude/sessions/compaction-log.txt`) | 2026-05-02 (UTC date) 8 件 / 2026-05-03 (UTC date) 0 件 | `~/.claude/sessions/compaction-log.txt` |

参考集計値:
- `compact_observer.sh` stdout: `COUNT_TODAY=0 COUNT_7D=34` (TODAY=2026-05-03 JST、grep 対象は UTC 日付文字列)。
- `karo_auto_clear.log` 末尾 6 件 (2026-05-02 22:30 〜 05-03 00:30 JST): 4 件が safe_clear_check=FAIL、2 件が idle=false。

---

## AC4. 運用問題点 (事実列挙)

1. **shogun_to_karo.yaml に長期 in_progress 残置**
   - 2026-05-03 00:55 JST 時点で `status=in_progress` の cmd が 3 件: cmd_624 (timestamp=2026-05-01T23:34、約 25 時間滞留)、cmd_634 (2026-05-03T00:19)、cmd_639 (2026-05-03T00:54)。
   - `karo_self_clear_check.sh` の cond_1 (`shogun_to_karo.yaml に in_progress 0 件`) が常に NG となり、過去 24h で 112/112 が SKIP、`ALL_PASSED=0`。
2. **detect_compact のログファイル不在**
   - `logs/compact_log/karo.log` および `logs/compact_log/gunshi.log` のファイル自体が存在しない。
   - 同 dir にある `cron.log` のサイズは 0 byte (cron stdout/stderr が空)。
   - cron は `*/10` で実行されているが、過去 24h 内の検出記録ゼロ。
3. **dashboard.yaml と task YAML の鮮度乖離**
   - `dashboard.yaml.in_progress` は 1 件のプレースホルダ (`{cmd: '—', content: '進行中なし'}`) のみ、`last_updated=2026-05-03 00:10 JST`。
   - 実際の進行中 task YAML (例: `ashigaru1.yaml` の `subtask_638_followup_commit`) は dashboard 未反映。
   - `shogun_in_progress_monitor.sh` が同問題を P2 アラートとして 22:00、23:00 JST に検出済 (`logs/in_progress_monitor.log`)。
4. **gunshi 自律 /clear が実行に至らない**
   - 24h で `gunshi_self_clear_check.sh` の cond_1〜4 が 88 回 ALL_PASSED、`context_advisory` を 88 回送信。
   - 一方 `clear_command` 送信=0。理由: 該当コードパスは `safe_window_judge.sh` 連携時に `clear_command` を送らず `context_advisory` のみ送る設計のため。
   - `safe_window_judge.sh gunshi` 24h 集計: REC=/clear=32 件発生したが、これらは `gunshi_self_clear_check.sh` 経由ではなく `safe_window_judge.sh` 直接 cron 実行のログ集計 (受信側 inbox に直接 clear が届く経路ではない)。
5. **karo_self_clear_check.sh と karo_auto_clear.sh の二重 cron 登録**
   - `karo_self_clear_check.sh` が `*/10`、`karo_auto_clear.sh` が `*/30` で別々に cron 登録。
   - 双方とも `safe_clear_check.sh` 相当の判定を内包し、clear 送信経路を持つ。
   - 過去 24h: `karo_self_clear_check.sh` 由来 clear=0、`karo_auto_clear.sh` 由来 clear=0。
6. **shogun の auto_clear / auto_compact 機構が不在**
   - `safe_clear_check.sh` が role=shogun を常時 SKIP (F001 による)。
   - cron 上に shogun 専用の self_clear/compact 機構なし。`shogun_context_notify.sh` が */5 で稼働するが、これは通知のみ。
7. **ashigaru の auto_clear / auto_compact 機構が不在**
   - cron 設定上、`self_clear_check.sh ashigaru{N}` および `safe_clear_check.sh --agent-id ashigaru{N}` の登録なし。
   - 起動経路は (a) ashigaru 本人が Step 9.7 で `self_clear_check.sh` を呼出、(b) PreCompact hook 経由の `safe_clear_check.sh` の 2 経路のみ。
   - `safe_clear/ashigaru1.log`, `ashigaru4.log`, `ashigaru7.log` の最終更新: 2026-04-24〜04-27。24h 内更新は ashigaru5 のみ (5 行、うち全 SKIP)。
8. **PreCompact hook 経由の `safe_clear_check.sh` は実質ログ用**
   - `--tool-count 0` 固定で呼出されるため、role 別閾値 (karo=50 / gunshi=30 / ashigaru=30) を必ず下回り、`tool_count_below` で常時 SKIP。
   - clear_command 送信に至った実例は 24h 内ゼロ。
9. **`compact_observer.sh` の TODAY 集計と compaction-log タイムスタンプの timezone 不一致**
   - `compact_observer.sh` の `TODAY` は `jst_now.sh --date` 由来 (2026-05-03 JST)。
   - `~/.claude/sessions/compaction-log.txt` のタイムスタンプは UTC 表記 (例: `[2026-05-02 15:33:44]` は実際には JST 2026-05-03 00:33:44 に相当)。
   - そのため `compact_observer` の出力は `COUNT_TODAY=0`、一方 24h 直近では 8 件発生 (UTC 日付 5/2)。
10. **ashigaru `self_clear_check.sh` の status NG SKIP 集中**
    - 24h 内 ashigaru5 の 5 回実行はすべて C2 NG (`task status='assigned'`) で SKIP。
    - clear 送信=0。
11. **`logs/safe_clear/ashigaru{2,3,6}.log` がそもそも存在しない**
    - `ls logs/safe_clear/` 結果に ashigaru2/ashigaru3/ashigaru6 のログファイルが含まれない。
    - 既存ログが残るのは ashigaru1, ashigaru4, ashigaru5, ashigaru7 のみ (ashigaru1/4/7 は 4/24〜4/27 で更新停止)。

---

## AC5. 改善案禁止 確認

本ドキュメントには「〜すべき」「〜を改善する」「〜が望ましい」「〜したほうがよい」等の改善案・仮説・提案を記載していない。事実とデータのみで構成。

---

## 出典 (生データ確認コマンド)

```
crontab -l | grep -E "clear|compact|safe"
ls scripts/*clear* scripts/*compact* scripts/*safe*
ls -la logs/safe_clear/ logs/safe_window/ logs/compact_log/
cat logs/in_progress_monitor.log
tail -30 ~/.claude/sessions/compaction-log.txt
.venv/bin/python3 -c "import yaml; d=yaml.safe_load(open('dashboard.yaml')); print(d.get('in_progress'))"
grep "REC=/clear" logs/safe_window/gunshi.log | tail -5
grep "REC=/compact" logs/safe_window/karo.log | tail -5
```

各 grep / awk / wc コマンドで集計した値は AC3 表中に記載。
