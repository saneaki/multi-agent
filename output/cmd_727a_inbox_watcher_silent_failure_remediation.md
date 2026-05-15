# cmd_727a inbox_watcher silent failure remediation

| item | value |
|---|---|
| generated_at | 2026-05-15 14:54 JST |
| task | subtask_727a_inbox_watcher_silent_failure_remediation |
| target | scripts/inbox_watcher.sh |
| source_audit | output/cmd_717b_silent_failure_audit_so17_hardening.md |
| audit_fixture | not found; used cmd_717b output as primary evidence |

## Summary

`scripts/inbox_watcher.sh` の tmux `send-keys` 系 silent failure を、`tmux_send_keys_logged()` 経由の明示ログ化へ置換した。daemon である inbox watcher は単発の nudge/cleanup 失敗で停止すると監視全体を失うため、halt ではなく ERROR/WARN ログで destination/content/timestamp/rc/stderr を残す方針とした。

## Classification

| audit # | original area | decision | remediation |
|---:|---|---|---|
| 9-12 | Codex `/clear` -> `/new` sequence | explicit ERROR log | `codex-clear-*` contexts |
| 13-15 | Copilot `/clear` restart sequence | explicit ERROR log | `copilot-clear-*` contexts |
| 16-18 | generic CLI command send | explicit ERROR log | `cli-command-*` contexts |
| 19-22 | Codex startup prompt send | explicit ERROR log | `startup-*` contexts |
| 23-26 | Codex context reset send | explicit ERROR log | `context-reset-codex-*` contexts |
| 27-28 | non-Codex context reset send | explicit ERROR log | `context-reset-*` contexts |
| 29 | copy/scroll-mode cancel | explicit WARN log | `copy-mode-cancel`; regression coverage preserved |
| 30-34 | normal nudge and retry cleanup | explicit ERROR/WARN log | `nudge-*` contexts |
| 35-37 | Escape escalation nudge | explicit ERROR log | `escape-nudge-*` contexts |
| 39 | fast-path idle C-u cleanup | explicit WARN log | `fast-path-idle-line-clear` |
| 41 | no-unread idle C-u cleanup | explicit WARN log | `no-unread-idle-line-clear` |

Audit rows #38 and #40 in the same range are `touch ... || true` idle-flag writes, not tmux `send-keys`; they were outside cmd_727a's tmux-send remediation scope.

## Implementation Notes

- Added `tmux_send_keys_logged(timeout, severity, context, args...)`.
- The helper temporarily disables `errexit` while capturing rc so failures cannot silently terminate the watcher under `set -e`.
- Failure logs include:
  - `context=<stable-label>`
  - `destination=<PANE_TARGET>`
  - `timestamp=<ISO-like local timestamp>`
  - `rc=<exit-code>`
  - `content=<quoted tmux send-keys args>`
  - `stderr=<captured stderr or <empty>>`
- No new `2>/dev/null || true` or `|| log_info` silent continuation pattern was introduced for tmux send-keys.

## Verification

| check | result | evidence |
|---|---|---|
| syntax | PASS | `bash -n scripts/inbox_watcher.sh` |
| unit normal+failure | PASS | `bats tests/unit/test_send_wakeup.bats` -> 58/58 |
| e2e inbox delivery | PASS | `bats tests/e2e/e2e_inbox_delivery.bats` -> 5/5 |
| residual tmux suppression scan | PASS | `rg -n "tmux send-keys.*2>/dev/null \\|\\| true|timeout [0-9]+ tmux send-keys" scripts/inbox_watcher.sh` -> no matches |

## Remediation Count

- cmd_717b audit range #9-#41: 31 tmux `send-keys` calls remediated plus 2 non-tmux idle-flag rows noted out of scope.
- task AC text references 28 remediation_required items; the current audit evidence contains 31 tmux send-keys rows in that range. All current tmux send-keys rows in `inbox_watcher.sh` now route through the logging helper.
- remaining tmux send-keys silent suppressions in `scripts/inbox_watcher.sh`: 0.

## Git Preflight

Before work, `git status --short --branch` showed unrelated existing dirty files:

- `memory/global_context.md`
- `memory/skill_history.md`
- `queue/external_inbox.yaml`
- `queue/reports/ashigaru1_report.yaml`
- `queue/reports/ashigaru5_report.yaml`
- `queue/reports/gunshi_report.yaml`
- `queue/suggestions.yaml`
- `queue/tasks/ashigaru4.yaml`
- `scripts/shc.sh`

Relevant changed files for cmd_727a:

- `scripts/inbox_watcher.sh`
- `tests/unit/test_send_wakeup.bats`
- `output/cmd_727a_inbox_watcher_silent_failure_remediation.md`
- `queue/reports/ashigaru6_report.yaml`
- `queue/tasks/ashigaru6.yaml`
- `queue/inbox/ashigaru6.yaml`

Commit/push status will be recorded in `queue/reports/ashigaru6_report.yaml` after the selected-file commit and push.
