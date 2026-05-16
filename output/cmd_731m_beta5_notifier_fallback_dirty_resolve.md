# cmd_731m: β-5 notifier fallback dirty 解消

**task_id**: subtask_731m_beta5_notifier_fallback_dirty_resolve
**parent_cmd**: cmd_731
**timestamp**: 2026-05-16T13:09:26+09:00
**assigned_to**: ashigaru2

---

## M-1: doc-vs-reality drift 訂正 (AC: M-1)

**対象**: `output/cmd_731j_beta5_macos_flock_skip_repair.md` J-2

**誤記内容**: 「commit 753875d の B5-3 実装で既に portable fallback 完成済み」と記載していた。

**実態**:
- `git show 753875d:scripts/shogun_inbox_notifier.sh` を確認すると **flock-only** (mkdir fallback なし)
- mkdir fallback は working tree の uncommitted dirty として存在していた

**訂正内容**: J-2 セクションに `[subtask_731m 訂正]` 注記を追加し、753875d の実際のコード (flock-only) と
subtask_731m で追加した portable fallback コードを分離して記載。

**判定**: PASS

---

## M-2: mkdir fallback の正式 commit 判断 (AC: M-2)

**決定**: **commit する** (防御的改善として有効)

**根拠**:
1. tests/unit/test_shogun_inbox_notifier.bats の T-SIN-004/T-SIN-004b は flock/mkdir fallback 両パスをテストする実装になっており、script 側に mkdir fallback が必要
2. 軍師 QC (cmd_731k §2-3) が「防御的改善のため commit 推奨」と判定
3. bash -n PASS、bats 6/6 PASS SKIP=0 確認済み
4. GHA macOS runner で flock が利用可能であっても、mkdir fallback は belt-and-suspenders として有効
5. 未関係 dirty ファイルは一切 commit しない (editable_files のみ対象)

**diff summary**:
```diff
-# B5-3: flock による原子的な二重起動防止
+# B5-3: 二重起動防止 (flock 優先、macOS 等 flock 不在時は mkdir lock にフォールバック)
 PIDFILE="${SHOGUN_NOTIFIER_PIDFILE:-...}"
 mkdir -p "$(dirname "$PIDFILE")"
-exec 200>"$PIDFILE"
-if ! flock -n 200; then
-    echo "Already running. Exiting." >&2; exit 0
+if command -v flock &>/dev/null; then
+    exec 200>"$PIDFILE"
+    if ! flock -n 200; then ...; fi
     ...
+else
+    _LOCKDIR="${PIDFILE}.lock"
+    if ! mkdir "$_LOCKDIR" 2>/dev/null; then ...; fi
+    ...
+fi
```

**判定**: PASS

---

## M-3: テスト結果 (AC: M-3)

```
$ bash -n scripts/shogun_inbox_notifier.sh
→ exit 0 (SYNTAX OK)

$ bats tests/unit/test_shogun_inbox_notifier.bats --timing
1..6
ok 1 T-SIN-001: bash -n 構文チェック in 18ms
ok 2 T-SIN-002: log() が nohup redirect と合わせて LOG_FILE に 1 回のみ書き込む in 62ms
ok 3 T-SIN-002b: tee 実装では二重書込みが発生することの対比確認 in 104ms
ok 4 T-SIN-003: STATE_FILE dedup — 登録済み cmd_id は通知しない in 351ms
ok 5 T-SIN-004: PIDFILE guard — lock取得済みなら即時終了して 'Already running' を出力 in 145ms
ok 6 T-SIN-004b: 同一 PIDFILE の 2 プロセス目はブロックされる (flock/mkdir fallback 両対応) in 201ms
PASS=6 FAIL=0 SKIP=0
```

**判定**: PASS (SKIP=0)

---

## M-4: commit 情報

commit SHA: 643a8ba
含有ファイル:
- `scripts/shogun_inbox_notifier.sh` (mkdir fallback 正式追加)
- `output/cmd_731j_beta5_macos_flock_skip_repair.md` (J-2 訂正注記)
- `output/cmd_731m_beta5_notifier_fallback_dirty_resolve.md` (本ファイル)
- `queue/reports/ashigaru2_report.yaml` (本 task report 更新)
- `queue/tasks/ashigaru2.yaml` (status → done)
- `queue/inbox/ashigaru2.yaml` (read:true 化)

Refs cmd_731 AC-9

---

## 総合判定

| AC | 結果 |
|----|------|
| M-1 doc訂正 | PASS |
| M-2 commit判断 | PASS (commit決定) |
| M-3 tests SKIP=0 | PASS (6/6) |
| M-4 commit message | 実施済み |

**overall: PASS**
