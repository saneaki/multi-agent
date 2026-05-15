# cmd_683 Phase3 ntfy 14件削除レポート

作成: 2026-05-15 21:42 JST / 担当: ashigaru5 / 親 cmd: cmd_683 / task: subtask_683_phase3_ntfy_deletion

---

## 1. 殿承認ログ

| 項目 | 内容 |
|------|------|
| approved_at | 2026-05-15T17:00:00+09:00 |
| approved_by | lord |
| approval_channel | discord |
| approved_items | action-8 [cmd_683-phase3-delete-approval] / cmd_683 Phase3 ntfy server-side deletion target list, 14 entries |
| decision_path | dashboard action-8 created from suggestions triage batch1 → lord approved action-8 on Discord → karo dispatched one ashigaru because F001 forbids direct execution |

Destructive Safety Tier2 (10件以上削除) の承認要件を満たす。

---

## 2. 削除対象14件・realpath 最終検証結果 (P3-1)

実行前検証 (2026-05-15 21:40 JST 時点):

| # | 対象 | realpath | 種別 | 状態 |
|---|------|---------|------|------|
| 1 | scripts/ntfy.sh | (n/a) | script | MISSING (既削除 cmd_692 1fbb1ac) |
| 2 | scripts/ntfy_wsl_template.sh | /home/ubuntu/shogun/scripts/ntfy_wsl_template.sh | script | PRESENT → 削除 ✅ |
| 3 | scripts/discord_to_ntfy.py | /home/ubuntu/shogun/scripts/discord_to_ntfy.py | script | PRESENT → 削除 ✅ |
| 4 | scripts/__pycache__/discord_to_ntfy.cpython-312.pyc | /home/ubuntu/shogun/scripts/__pycache__/discord_to_ntfy.cpython-312.pyc | cache | PRESENT → 削除 ✅ |
| 5 | lib/ntfy_auth.sh | (n/a) | lib | MISSING (既削除 cmd_692 1fbb1ac) |
| 6 | queue/ntfy_inbox.yaml | /home/ubuntu/shogun/queue/ntfy_inbox.yaml | data | PRESENT → 削除 ✅ |
| 7 | queue/ntfy_inbox.yaml.lock | /home/ubuntu/shogun/queue/ntfy_inbox.yaml.lock | lock | PRESENT → 削除 ✅ |
| 8 | queue/ntfy_inbox_archive.yaml | (n/a) | data | MISSING (履歴的に未追跡、対象外) |
| 9 | logs/ntfy_listener.log | (n/a) | log | MISSING (履歴的に未追跡、対象外) |
| 10 | logs/ntfy_inbox_corrupt/ | (n/a) | dir | MISSING (履歴的に未追跡、対象外) |
| 11 | logs/ntfy_completed_cmds.txt | (n/a) | state | MISSING (履歴的に未追跡、対象外) |
| 12 | logs/ntfy_notified_cmds.txt | (n/a) | state | MISSING (履歴的に未追跡、対象外) |
| 13 | tests/unit/test_ntfy_ack.bats | (n/a) | test | MISSING (既削除 cmd_677 297f3f4) |
| 14 | tests/unit/test_ntfy_auth.bats | (n/a) | test | MISSING (既削除 cmd_692 1fbb1ac) |

**集計**: 本タスクでの削除実行 5 件 / 既削除 4 件 (cmd_677 / cmd_692) / 履歴的に未追跡 5 件 (logs/queue/* state)。

全 PRESENT 対象の realpath は `/home/ubuntu/shogun/` 配下を確認 (Destructive Safety Tier3 SAFE DEFAULTS 遵守)。

---

## 3. 削除実行ログ (P3-3, P3-4)

```
$ rm -v scripts/ntfy_wsl_template.sh scripts/discord_to_ntfy.py \
    scripts/__pycache__/discord_to_ntfy.cpython-312.pyc \
    queue/ntfy_inbox.yaml queue/ntfy_inbox.yaml.lock
removed 'scripts/ntfy_wsl_template.sh'
removed 'scripts/discord_to_ntfy.py'
removed 'scripts/__pycache__/discord_to_ntfy.cpython-312.pyc'
removed 'queue/ntfy_inbox.yaml'
removed 'queue/ntfy_inbox.yaml.lock'
```

- 全 5 件を `rm -v` 実行し削除ログを取得。
- `logs/ntfy_inbox_corrupt/` は存在しなかったため `rm -rf` は未実施 (P3-4 後段: realpath 確認は対象不在で不要)。
- `sudo` / `git reset --hard` / `force push` は未使用。

### git preflight (P3-3)

- 作業開始時の git dirty 6 件 (`docs/dashboard_schema.json` / `memory/global_context.md` / `queue/alert_state.yaml` / `queue/external_inbox.yaml` / `queue/reports/ashigaru1_report.yaml` / `scripts/shc.sh`) は本タスクの editable_files 範囲外。
- 選択 `git add` で巻き込みを防ぎ、本cmdの変更対象 (削除 2 + 新規 output + report + task + inbox) のみを commit。
- 1 commit ahead of `origin/main` (ashigaru1 commit `ae2b289`) は別件で本 commit 前に rebase 不要 (linear append)。

---

## 4. 削除後の残存検査 (P3-5)

```
$ for f in (14 targets); do test -e "$f" && echo PRESENT; done
missing(deleted_or_never_existed)=14 present(残存)=0
```

**結論**: 14 対象すべて残存なし。存在しなかった 9 件は本セクション 2 の表に理由を記載済 (対象外削除で補わない)。

---

## 5. ntfy 参照残存スキャン (P3-6)

`rg -t sh -t py -g '!docs/**' -g '!output/**' -g '!images/**' -g '!projects/**' -g '!*.sample' -g '!config/**'` で `\bntfy\b` を検索:

| ファイル | 種別 | 残存内容 | 分類 |
|---------|------|----------|------|
| scripts/discord_gateway.py | コメント | "ntfy 互換" docstring | 歴史的記述 (実害なし) |
| scripts/inbox_watcher.sh | コメント | "ntfy must be delivered" 3行 | 歴史的記述 (Discord 経路の名残) |
| scripts/notify.sh | ガード | `NOTIFY_BACKEND=ntfy was retired in cmd_692` | 防御コード (削除すべきでない) |
| scripts/discord_notify.py | コメント | "ntfy.sh 互換代替" | 歴史的記述 |
| scripts/clasp_age_check.sh | コメント | "ntfy 通知" 1 行。実体は `notify.sh` 呼出 (Discord backend) | 歴史的記述 (実体は Discord) |
| scripts/inbox_write.sh | 変数名 | `NTFY_TOPIC` / `NTFY_TITLE` (line 136-) | 変数名 legacy、実体は `notify.sh` (Discord) |
| scripts/start_discord_bot.sh | コメント | "ntfy 中継" 起動メッセージ | 歴史的記述 |
| scripts/shogun_in_progress_monitor.sh | 変数名 + path | `~/.cache/shogun/ntfy_sent.txt` dedup file (line 106) / コメント | 変数名 legacy、実体は `notify.sh` 呼出 (Discord) |
| **shutsujin_departure.sh** | **実行** | **L1116-1128: `bash scripts/ntfy_listener.sh` を `nohup` で起動** | **⚠️ 実行系参照: 削除済 script を呼出** |

### 5.1. 報告すべき実行系参照 (AC P3-6)

**`shutsujin_departure.sh` STEP 6.8** に削除済 `scripts/ntfy_listener.sh` を起動するブロックが残存:

```bash
# shutsujin_departure.sh:1116-1128
NTFY_TOPIC=$(grep 'ntfy_topic:' ./config/settings.yaml ...)
if [ -n "$NTFY_TOPIC" ]; then
    pkill -f "ntfy_listener.sh" 2>/dev/null || true
    [ ! -f ./queue/ntfy_inbox.yaml ] && echo "inbox:" > ./queue/ntfy_inbox.yaml
    nohup bash "$SCRIPT_DIR/scripts/ntfy_listener.sh" &>/dev/null &  # ← 存在しないスクリプト
    disown
    log_info "📱 ntfy入力リスナー起動 (topic: $NTFY_TOPIC)"
fi
```

加えて `config/settings.yaml:77` に `ntfy_topic: "hananoen"` が設定済のため、出陣時にこのブロックが発火し silent fail する (`nohup ... &>/dev/null &` のため検知困難)。

**取り扱い**: 本タスク scope は「削除のみ」のため修正は実施せず、後続 cmd として家老へ起案を委ねる (修復案: STEP 6.8 ブロック削除 + `ntfy_topic` config 廃止)。本レポートおよび karo 完了報告で明示申し送りする。

### 5.2. legacy 変数名残存 (実害なし)

`scripts/inbox_write.sh` / `scripts/shogun_in_progress_monitor.sh` の `NTFY_TOPIC` / `NTFY_TITLE` / `~/.cache/shogun/ntfy_sent.txt` などは、機能的には Discord backend 経路で動作しており削除不要。歴史的変数名のリネームは別タスクで扱う。

---

## 6. テスト・preflight 実施結果 (P3-7)

### 6.1. unit test (`tests/unit/test_notify_discord.bats`)

```
1..5
ok 1 notify.sh dispatches body title and type to Discord backend
ok 2 notify.sh passes --chunked when NOTIFY_CHUNKED is enabled
ok 3 notify.sh rejects missing body
ok 4 notify.sh rejects retired ntfy backend
ok 5 notify.sh rejects unknown backend
```

5/5 PASS, SKIP=0, FAIL=0。

### 6.2. cmd_complete_git_preflight

- exit=0 (script 自体は正常実行)
- `status: FAIL` (作業前 dirty 6 件に起因、本 cmd の editable_files 範囲外、別件由来)
- 本 cmd の commit は選択 add で隔離

### 6.3. SKIP混在の有無

SKIP=0。AC P3-7 の「SKIP が 1 件でもあれば incomplete」要件を満たし、test 系統は PASS と判定。

---

## 7. AC 達成状況

| AC | 内容 | 結果 |
|----|------|------|
| P3-1 | 削除対象 14 件と一致 + realpath が shogun 配下 | PASS (§2) |
| P3-2 | 殿承認ログ approved_at/approved_by/approval_channel/approved_items/decision_path を report/output に記録 | PASS (§1 + report YAML) |
| P3-3 | cmd_704 git preflight + 未関係dirty 巻き込まず | PASS (§3 git preflight + 選択add) |
| P3-4 | rm 前存在確認 + rm 時 `-v` ログ + corrupt は realpath 確認後 | PASS (§3, corrupt は不在につき対象外) |
| P3-5 | 削除後 14 対象残存なし、不在対象に理由記録 + 対象外削除なし | PASS (§4) |
| P3-6 | ntfy 参照スキャン + 実行系参照残存を報告 | PASS (§5、`shutsujin_departure.sh:1116-1128` を実行系残存として報告) |
| P3-7 | 関連 unit/preflight 実行 + SKIP 1 件以上は incomplete | PASS (§6, SKIP=0) |
| P3-8 | 削除 commit + `origin/main` push + commit message に cmd_683 含む | 本セクション完了後に実施 (§8) |

---

## 8. 変更ファイル一覧

### 8.1. 本 cmd の commit 対象 (選択 add)

| ファイル | 種別 |
|---------|------|
| scripts/ntfy_wsl_template.sh | D (deletion, tracked) |
| scripts/discord_to_ntfy.py | D (deletion, tracked) |
| output/cmd_683_phase3_ntfy_deletion.md | A (new) |
| queue/reports/ashigaru5_report.yaml | M |
| queue/tasks/ashigaru5.yaml | M (status=done) |
| queue/inbox/ashigaru5.yaml | M (msg_20260515_123752_b5598aaa read:true) |

`scripts/__pycache__/discord_to_ntfy.cpython-312.pyc` / `queue/ntfy_inbox.yaml` / `queue/ntfy_inbox.yaml.lock` の 3 件は untracked で git の追跡なし、ファイルシステム上のみ削除済。

### 8.2. 本 cmd の commit 対象外 (別件 dirty, 巻き込まない)

`docs/dashboard_schema.json` / `memory/global_context.md` / `queue/alert_state.yaml` / `queue/external_inbox.yaml` / `queue/reports/ashigaru1_report.yaml` / `scripts/shc.sh` — それぞれ別 cmd / 別 ashigaru の作業中変更につき、本 commit へは追加しない。

---

## 9. 申し送り事項

1. **shutsujin_departure.sh STEP 6.8 残存**: 削除済 `scripts/ntfy_listener.sh` を `nohup` で起動するブロックが残る。`config/settings.yaml:77 ntfy_topic: "hananoen"` も併存。次の cmd (家老起案) で除去推奨。
2. **legacy 変数名**: `NTFY_TOPIC` / `~/.cache/shogun/ntfy_sent.txt` 等は機能上 Discord backend で動作。rename タスクは別系統で扱う。
3. **dirty 別件**: 作業開始時に 6 件の不関係 dirty を確認。本タスクでは巻き込まず、各担当者の cmd で commit される想定。
4. **SKIP 0 / FAIL 0**: notify_discord bats 5/5 PASS。

---

## 10. 結論

cmd_683 Phase3 ntfy server-side 削除を完了。本 cmd 削除対象 5 件 / 既削除/未追跡 9 件 = 14 件すべて残存なし。AC P3-1〜P3-7 PASS、P3-8 は本レポート完了後の commit/push で satisfy。実行系参照残存 (`shutsujin_departure.sh:1116-1128`) は §5.1 のとおり申し送りとして残す。
