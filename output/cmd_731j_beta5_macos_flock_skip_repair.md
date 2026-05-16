# cmd_731j: β-5 macOS flock SKIP補修

**task_id**: subtask_731j_beta5_macos_flock_skip_repair  
**parent_cmd**: cmd_731  
**timestamp**: 2026-05-16T12:11:42+09:00  
**assigned_to**: ashigaru2  

---

## J-1: 失敗根因 (GHA run 25950319231)

- **失敗CI**: Multi-CLI Test Suite / Unit Tests (macos-latest) / Verify zero unexpected SKIPs
- **失敗TC**:
  - TC-348 T-SIN-004: skipped "flock not available"
  - TC-349 T-SIN-004b: skipped "flock not available"
- **根因**: macOS runner に `flock` が未搭載。tests/unit/test_shogun_inbox_notifier.bats の T-SIN-004/T-SIN-004b が `command -v flock || skip "flock not available"` でスキップしていた。
- **スクリプト本体**: scripts/shogun_inbox_notifier.sh の PID ロック実装は commit 753875d (B5-3) で既に flock/mkdir fallback 両対応済み。テストがそれを追従できていなかった。

---

## J-2: scripts/shogun_inbox_notifier.sh (変更なし)

commit 753875d の B5-3 実装で既に portable fallback 完成済み:

```bash
if command -v flock &>/dev/null; then
    exec 200>"$PIDFILE"
    if ! flock -n 200; then
        echo "Already running. Exiting." >&2; exit 0
    fi
    echo $$ >&200
    trap 'rm -f "$PIDFILE"' EXIT
else
    _LOCKDIR="${PIDFILE}.lock"
    if ! mkdir "$_LOCKDIR" 2>/dev/null; then
        echo "Already running. Exiting." >&2; exit 0
    fi
    echo $$ > "$PIDFILE"
    trap 'rm -f "$PIDFILE"; rmdir "$_LOCKDIR" 2>/dev/null || true' EXIT
fi
```

Linux既存挙動 (flock) は維持。macOS等は mkdir lock にフォールバック。

---

## J-3: tests/unit/test_shogun_inbox_notifier.bats (変更あり)

T-SIN-004 / T-SIN-004b から `command -v flock || skip "flock not available"` を除去し、
flock/mkdir fallback の両パスを platform 適応でテストするよう書き換え:

- **flock 利用可能時 (Linux CI)**: flock でロックを先取り → スクリプト実行 → flock 取得失敗 → "Already running"
- **flock 不在時 (macOS CI)**: mkdir でロック先取り → スクリプト実行 → mkdir 失敗 → "Already running"

両ケースで SKIP なし。macOS CI が mkdir fallback path を、Linux CI が flock path を検証。

---

## J-4: テスト結果

```
bats tests/unit/test_shogun_inbox_notifier.bats
1..6
ok 1 T-SIN-001: bash -n 構文チェック
ok 2 T-SIN-002: log() が nohup redirect と合わせて LOG_FILE に 1 回のみ書き込む
ok 3 T-SIN-002b: tee 実装では二重書込みが発生することの対比確認
ok 4 T-SIN-003: STATE_FILE dedup — 登録済み cmd_id は通知しない
ok 5 T-SIN-004: PIDFILE guard — lock取得済みなら即時終了して 'Already running' を出力
ok 6 T-SIN-004b: 同一 PIDFILE の 2 プロセス目はブロックされる (flock/mkdir fallback 両対応)
PASS=6 FAIL=0 SKIP=0
```

bash -n scripts/shogun_inbox_notifier.sh → SYNTAX OK

---

## J-5: commit情報

commit SHA: (次ステップで記録)  
含有ファイル:
- tests/unit/test_shogun_inbox_notifier.bats (T-SIN-004/004b skip除去)
- output/cmd_731j_beta5_macos_flock_skip_repair.md

Refs cmd_731 AC-9 GHA run 25950319231
