# cmd_694 sh_health high-failure repair

timestamp: 2026-05-09T07:34:41+09:00
worker: ashigaru1
task_id: subtask_694_sh_health_repair

## Review reconciliation

Codex and Opus agreed that `cmd_squash_pub_hook` was the only active bug. Both reviews identified duplicate hook logging and `update_dashboard.sh` failures as the high-priority issue. Codex additionally identified `gha_failure_status.json` filename false positives in the default failure regex.

For `dashboard_rotate`, both reviews classified the high `failure_7d` as historical arithmetic-error continuation lines rather than a current cron failure. The repair therefore changes health parsing so untimestamped continuation lines inherit the preceding timestamp and can fall out of the 7-day window.

For `inbox_watcher[karo]`, both reviews classified the failures as already-fixed historical events. No ignore pattern was added so future `send-keys` or YAML parse regressions remain visible until natural decay clears the old count.

## Implementation

- `scripts/cmd_squash_pub_hook.sh`
  - Fixed dashboard refresh call from `$SCRIPT_DIR/update_dashboard.sh` to `$SCRIPT_DIR/scripts/update_dashboard.sh`.
  - Changed `log()` from `tee -a "$LOG_FILE"` to direct append, preventing duplicate lines when the daemon is already stdout/stderr-redirected to the same log.
  - Added cwd/script context to future non-fatal dashboard-call failure logs.
- `config/sh_health_targets.yaml`
  - Added a target-specific `failure_pattern` for `cmd_squash_pub_hook` so filenames like `gha_failure_status.json` no longer count as failures.
  - Added `dedupe_failure_lines: true` only for this target to count old duplicated hook lines once.
- `scripts/sh_health_check.sh`
  - Added timestamp inheritance for continuation lines in `grep_count()` and `grep_last_error()`.
  - Added optional per-target failure-line dedupe.

## Verification

Before repair, `bash scripts/sh_health_check.sh --no-dashboard` reported:

| target | status | success_7d | failure_7d | last_error |
|---|---:|---:|---:|---|
| dashboard_rotate | yellow | 64 | 56 | `0: syntax error in expression...` |
| inbox_watcher[karo] | yellow | 815 | 39 | empty |
| cmd_squash_pub_hook | yellow | 20 | 11 | `update_dashboard.sh call failed (non-fatal)` |

After repair, verification commands passed:

- `bash -n scripts/cmd_squash_pub_hook.sh scripts/sh_health_check.sh`
- YAML parse for `config/sh_health_targets.yaml`, `queue/tasks/ashigaru1.yaml`, `queue/inbox/ashigaru1.yaml`
- `bash scripts/sh_health_check.sh --no-dashboard`

Final health summary:

```text
green=39 yellow=8 red=0 skip=0
```

Target results:

| target | status | success_7d | failure_7d | result |
|---|---:|---:|---:|---|
| dashboard_rotate | green | 8 | 0 | historical continuation lines no longer counted |
| inbox_watcher[karo] | yellow | 815 | 39 | unchanged by design; natural decay preserved |
| cmd_squash_pub_hook | yellow | 20 | 5 | 54.5% reduction from stricter regex + duplicate suppression |

## Residual risk

`cmd_squash_pub_hook` still has five real historical failure events in the 7-day window, mainly `flock timeout` and prior dashboard-call failures. The path fix prevents the dashboard-call class from recurring, but the currently running daemon may need its normal supervisor restart cycle before the script change is active in that process. No broad ignore was added for `flock timeout` because that would hide real lock contention.
