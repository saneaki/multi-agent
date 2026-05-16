# cmd_731h β-4 将軍 dual-verification 漏れ検知 hook 実装報告

**timestamp**: 2026-05-16T11:14:40+09:00
**task**: subtask_731h_beta4_shogun_dual_verification_hook
**parent_cmd**: cmd_731
**verdict**: PASS

## 実装内容

- `instructions/shogun.md` の `cmd_complete` 受信時 MUST USE 規律を強化し、`implementation-verifier(run_in_background=true)` と `Codex arm(effort=xhigh)` の二系統を将軍が起動する責務として明文化した。
- `dual_verification_started` 証跡を将軍自身の inbox に記録する運用を追加した。
- `scripts/shogun_completion_hook.sh` を新設し、`queue/inbox/shogun.yaml` の `cmd_complete` を走査して、猶予時間後も dual-verification 証跡が無い cmd だけ `dual_verification_alert` を 1 cmd 1 回投函するようにした。
- alert 生成時のみ Discord 通知も試行する。ただし `implementation-verifier` や Codex arm は起動しない。hook は alert 専用で、将軍の最終判断を奪わない。
- `tests/unit/test_shogun_completion_hook.bats` を追加し、alert生成、dedup、cooldown、証跡抑制、cmd_complete本文の誤証跡化防止を検証した。

## Acceptance Criteria

| ID | Status | Evidence |
| --- | --- | --- |
| B4-1 | PASS | `instructions/shogun.md` に implementation-verifier + Codex arm の起動責務、`dual_verification_started` 証跡、hook alert 規律を追記。 |
| B4-2 | PASS | `scripts/shogun_completion_hook.sh` 新設。`cmd_complete` 後、未起動なら `dual_verification_alert` を将軍 inbox へ 1 cmd 1 回投函。 |
| B4-3 | PASS | `tests/unit/test_shogun_completion_hook.bats` 5 tests PASS、SKIP=0。dedup/cooldown/alert生成を含む。 |
| B4-4 | PASS | hook は `inbox_write.sh` と `notify.sh` のみ呼び出し、implementation-verifier/Codex を自動起動しない。 |
| B4-5 | PASS | `bash -n scripts/shogun_completion_hook.sh` PASS。`bats tests/unit/test_shogun_completion_hook.bats` PASS。commit message は `Refs cmd_731 AC-6` を含める予定。 |

## Verification

```text
bash -n scripts/shogun_completion_hook.sh
PASS

bats tests/unit/test_shogun_completion_hook.bats
1..5
ok 1 alert generation: old cmd_complete without dual verification creates one alert
ok 2 dedup: repeated runs keep one alert per cmd
ok 3 cooldown: recent cmd_complete does not alert before cooldown expires
ok 4 evidence: dual_verification_started marker suppresses alert
ok 5 evidence: cmd_complete text itself is not counted as Codex proof
```

## Notes

- `scripts/shogun_completion_hook.sh` は repo の `.gitignore` 全体除外に掛かるため、commit 時は `git add -f scripts/shogun_completion_hook.sh` が必要。
- `inbox_watcher.sh` は本タスク範囲外のため編集していない。hook の runtime wiring は後続担当または家老統合判断に委ねる。
