# cmd_695 daemon health監視強化

作成: 2026-05-09 15:12 JST
担当: ashigaru3

## 結論

sh_health の daemon 判定を「停止」と「idle による個別 log stale」に分離した。
inbox_watcher は idle 時に個別 log を更新しない設計のため、`process_alive` と
`watcher_supervisor` の roll-call (`logs/roll_call.log`) を一次/二次証跡として扱う。

最終検証:

- `bash -n scripts/sh_health_check.sh scripts/watcher_supervisor.sh`: PASS
- `bash scripts/sh_health_check.sh --no-dashboard`: `green=41 yellow=6 red=0 skip=0`
- `systemctl --user restart shogun-watcher-supervisor.service`: active
- restart 後 log 再開:
  - `logs/cmd_complete_notifier.log`: 2026-05-09 15:12:20 JST
  - `logs/shogun_inbox_notifier.log`: 2026-05-09 15:12:21 JST
  - `logs/roll_call.log`: 2026-05-09 15:12:20 JST

## 実装内容

### 1. daemon 停止と idle log stale の分離

`scripts/sh_health_check.sh` の daemon 判定へ `health_evidence` を追加した。
停止は `process_alive=false` または `pid_alive=false` の場合のみ RED とし、
live process の log stale は target 設定の policy に従って GREEN/YELLOW へ分類する。

`config/sh_health_targets.yaml` の `inbox_watcher` には以下を明示した。

- `health_policy: process_alive_primary_with_supervisor_roll_call`
- `heartbeat_note`: idle 時は個別 log を更新しない
- `supervisor_roll_call: true`
- `supervisor_roll_call_log: roll_call.log`
- `supervisor_roll_call_green_after: 900`
- `alive_log_stale_status: green_with_roll_call`

これにより、idle な inbox_watcher は個別 log mtime だけでは RED にならず、
`process_alive=True` と `supervisor_roll_call=ALIVE/REVIVED` が sh_health に表示される。

### 2. supervisor roll-call 対象補正

`scripts/watcher_supervisor.sh` の roll-call 対象を補正した。

- `ashigaru1`: `multiagent:agents.9` から実体の `multiagent:agents.1` へ修正
- `shogun`: `shogun:main.0` を roll-call 対象へ追加

restart 後、`logs/roll_call.log` で `shogun` から `gunshi` まで ALIVE が記録された。

### 3. sh_health 表示

Yellow/Red/Green の各表に `health_evidence` 列を追加した。
daemon 系では以下の形式で判定根拠が出る。

```text
process_alive=True; pid_alive=True; log_age=7.6h; supervisor_roll_call=ALIVE age=26s
```

## cmd_694 c3471a5 再評価

対象 commit:

```text
c3471a5 fix: repair sh health high failure counts (Refs cmd_694)
```

変更内容は主に以下だった。

- `cmd_squash_pub_hook` の二重 tee 書き込み解消
- `update_dashboard.sh` 呼び出し path 修正
- sh_health の failure count を 7日 window / continuation timestamp / dedupe に対応
- `cmd_squash_pub_hook` の failure_pattern 明確化

再評価結果:

- c3471a5 は daemon 停止の直接原因ではない。
- 直接原因は `sh_health_check.sh` が daemon の log mtime stale を停止相当 RED と扱っていたこと。
- c3471a5 により sh_health の集計精度が上がり、既存の判定モデル不備が顕在化した。
- 家老の一次復旧で live process + stale log を YELLOW にした判断は妥当。
- 今回の恒久化では、inbox_watcher のような idle daemon について supervisor roll-call を health source として明文化した。

## 再発防止

- daemon health は process/systemd 生存と log mtime を同一視しない。
- idle daemon には `health_policy` と `heartbeat_note` を target config に明示する。
- supervisor 配下 daemon は roll-call の対象 pane と実体 pane の drift を health evidence で検出できるようにする。
- `systemctl --user restart shogun-watcher-supervisor.service` 後は、対象 daemon の process と log mtime 再開を確認する。

## 残リスク

- `suggestions_digest` / `session_to_obsidian` / `cmd_squash_pub_hook` の yellow は本 task 範囲外の既存 failure log によるもの。
- `inbox_watcher[karo]` / `inbox_watcher[ashigaru3]` / `inbox_watcher[ashigaru6]` は過去 failure count により yellow だが、health_evidence 上は process と roll-call が alive。

## REDO対応 2026-05-09 15:19 JST

家老REDO/追撃で指摘された `scripts/watcher_supervisor.sh` の `start_daemon` 経路を再確認した。
`roll_call_check` 側は既に `ashigaru1="multiagent:agents.1"` だったが、
`start_daemon` loop 内の `start_watcher_if_missing "ashigaru1"` だけ
旧 pane `multiagent:agents.9` のまま残存していた。

修正:

- `start_watcher_if_missing "ashigaru1" "multiagent:agents.9"` を
  `start_watcher_if_missing "ashigaru1" "multiagent:agents.1"` へ修正
- `rg -n "agents\.9|multiagent:agents\.1|ashigaru1" scripts/watcher_supervisor.sh` で
  `agents.9` が残らず、roll-call と start_daemon がどちらも `multiagent:agents.1` であることを確認

REDO後の検証:

- `bash -n scripts/watcher_supervisor.sh scripts/sh_health_check.sh`: PASS
- `systemctl --user restart shogun-watcher-supervisor.service && systemctl --user is-active shogun-watcher-supervisor.service`: `active`
- `bash scripts/sh_health_check.sh --no-dashboard`: `green=41 yellow=6 red=0 skip=0`
- restart 後 log 再開:
  - `logs/cmd_complete_notifier.log`: 2026-05-09 15:19:20 JST
  - `logs/shogun_inbox_notifier.log`: 2026-05-09 15:19:21 JST
  - `logs/roll_call.log`: 2026-05-09 15:19:21 JST

REDO結論:

- ashigaru1 inbox_watcher が将来停止した場合も、supervisor は実体 pane
  `multiagent:agents.1` を検出して再起動経路に入れる。
- `agents.9` 残存による再起動不能リスクは解消済み。
