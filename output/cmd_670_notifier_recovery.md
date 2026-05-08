# cmd_670 notifier recovery report

Generated: 2026-05-08 11:38 JST

## Summary

`cmd_complete_notifier.sh` and `shogun_inbox_notifier.sh` are now supervised by `systemd --user` through `shogun-watcher-supervisor.service`.
The service is enabled and active, and both notifier processes are running under the service cgroup.

## Root Cause

Karo's pre-work investigation was confirmed:

- `logs/cmd_complete_notifier.log` stopped at `2026-04-30 09:09:23 UTC`.
- `logs/shogun_inbox_notifier.log` stopped at the same time.
- Existing pid files and `logs/watcher_supervisor.lock` pointed at dead PIDs.
- No `systemd --user` notifier unit existed before this task.
- The previous startup path depended on a nohup-started supervisor, so once the supervisor died, notifier recovery did not happen.

## systemd Unit

Path: `~/.config/systemd/user/shogun-watcher-supervisor.service`

```ini
[Unit]
Description=Shogun watcher supervisor
After=default.target

[Service]
Type=simple
WorkingDirectory=/home/ubuntu/shogun
ExecStart=/home/ubuntu/shogun/scripts/watcher_supervisor.sh
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
```

Verification:

- `systemctl --user daemon-reload`: PASS
- `systemctl --user enable shogun-watcher-supervisor.service`: PASS
- `systemctl --user start shogun-watcher-supervisor.service`: PASS
- `systemctl --user is-enabled shogun-watcher-supervisor.service`: `enabled`
- `systemctl --user is-active shogun-watcher-supervisor.service`: `active`
- `systemctl --user status shogun-watcher-supervisor.service`: `Active: active (running)`

## Supervisor Changes

File: `scripts/watcher_supervisor.sh`

Added:

- `cleanup_stale_runtime_files`
- `cleanup_stale_pid_file`
- `cleanup_stale_lock_file`
- `pid_is_alive`
- JST-aware supervisor logging through `scripts/jst_now.sh`

Startup cleanup now scans:

- `logs/*.pid`
- `logs/watcher_supervisor.lock`

If the recorded PID is empty, non-numeric, or fails `kill -0`, the stale file is removed before the supervisor lock is acquired.

Healthcheck behavior:

- `cmd_complete_notifier.sh` is checked with `pgrep -f`.
- `shogun_inbox_notifier.sh` is checked with `pgrep -f`.
- Missing notifier processes are restarted with `nohup bash scripts/... >> logs/... 2>&1 &`.
- Journal evidence at recovery: stale pid/lock files were removed and both notifiers were started.

## Process Verification

`ps -ef` confirmed:

```text
bash /home/ubuntu/shogun/scripts/watcher_supervisor.sh
bash scripts/cmd_complete_notifier.sh
bash scripts/shogun_inbox_notifier.sh
```

`systemctl --user status` confirmed the notifier processes are children of `shogun-watcher-supervisor.service`.

## E2E Verification

Temporary dashboard row:

```text
| 11:36 | shogun | 🏆🏆cmd_670999 COMPLETE: notifier systemd E2E test | temporary verification row ✅ |
```

Observed results:

- `logs/cmd_complete_notifier.log`: `Sending notify for cmd_670999`
- `logs/cmd_complete_notifier.log`: `notify sent: cmd_670999`
- `logs/discord_notify.log`: delivered `tag=cmd_complete` for the notifier test
- `logs/shogun_inbox_notifier.log`: shogun inbox send fired for `cmd_670999`

Cleanup:

- Temporary dashboard row removed.
- `cmd_670999` removed from `logs/ntfy_completed_cmds.txt`.
- `cmd_670999` removed from `logs/shogun_inbox_notified.txt`.
- Temporary shogun inbox message removed.

## Missed List

Backfill candidate list was written to `output/cmd_670_missed_cmds.md`.

No backfill notifications were sent.

## Acceptance Criteria

| id | status | evidence |
|---|---|---|
| A-1 | PASS | user service file created with `ExecStart=/home/ubuntu/shogun/scripts/watcher_supervisor.sh` |
| A-2 | PASS | `Restart=always`, `RestartSec=30`, `systemctl --user status` active/running |
| A-3 | PASS | `enable`, `start`, `is-enabled=enabled`, `is-active=active` |
| A-4 | PASS | stale `logs/*.pid` and `logs/watcher_supervisor.lock` cleanup added and observed in journal |
| A-5 | PASS | `pgrep` healthcheck starts both notifier scripts when absent |
| B-1 | PASS | `ps -ef` shows both notifier scripts resident |
| B-2 | PASS | temporary `🏆🏆cmd_670999` dashboard row triggered notify + Discord delivery, then was reverted |
| C-1 | PASS | missed/backfill list created; no backfill sent |
| E-1 | PASS | this report records root cause, unit, healthcheck, verification, and missed list |
