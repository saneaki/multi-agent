# cmd_728c: Lord Approval Instruction Update

作成: 2026-05-15 15:24 JST  
担当: ashigaru6  
範囲: `instructions/shogun.md` / `instructions/karo.md` / 本 output / ashigaru6 report。

## Summary

cmd_728 γとして、cmd_728a の承認依頼 best practice、cmd_728b の skill draft、cmd_728e の Discord 長文分割対応を `instructions/shogun.md` と `instructions/karo.md` に反映した。

変更点:

- `instructions/shogun.md`
  - `Lord Approval Request` 節を追加。
  - 標準 skill path `/home/ubuntu/shogun/skills/shogun-lord-approval-request-pattern/SKILL.md` を明記。
  - 必須8フィールド、Discord 詳細通知 + dashboard 要対応短縮 entry、terminal-only / inbox-only 禁止を明記。
  - cmd_716 gate registry、`shogun-error-fix-dual-review`、`skill-creation-workflow` との役割分担を記載。
- `instructions/karo.md`
  - `Lord Approval Request` 節を追加。
  - 家老が dashboard `Action Required` と Discord 詳細通知を二系統で用意する責務を明記。
  - dashboard 短縮 entry template と `NOTIFY_CHUNKED=1 bash scripts/notify.sh ...` / `scripts/discord_notify.py --dry-run --chunked ...` usage を記載。
  - terminal-only / inbox-only 禁止、truncate 放置禁止、関連 workflow 参照を明記。

## Acceptance Criteria

| ID | Status | Evidence |
|---|---|---|
| C-1 | PASS | `instructions/shogun.md` に `Lord Approval Request` 節を追加し、skill path、必須8フィールド、Discord 詳細通知 + dashboard 短縮 entry、terminal-only / inbox-only 禁止を記載。 |
| C-2 | PASS | `instructions/karo.md` に同節を追加し、家老が `Action Required` と Discord 詳細通知を二系統で用意する責務を記載。 |
| C-3 | PASS | `NOTIFY_CHUNKED=1 bash /home/ubuntu/shogun/scripts/notify.sh ...` と `python3 /home/ubuntu/shogun/scripts/discord_notify.py --dry-run --chunked ...` を cmd_728e output と矛盾なく記載。 |
| C-4 | PASS | cmd_716 gate registry、`shogun-error-fix-dual-review`、`skill-creation-workflow` への参照と役割分担を両 instruction に記載。 |
| C-5 | PASS | `rg` による要件確認、`bash -n scripts/notify.sh`、`python3 -m py_compile scripts/discord_notify.py` を実施。明白な bash / Python 構文破損なし。Markdown は追記節の fence 閉じを目視確認。 |
| C-6 | PASS | git preflight を本 output に記録。commit / push は実施せず、cmd_728 統合判断に委ねる。 |

## Verification

```text
rg -n "Lord Approval Request|shogun-lord-approval-request-pattern|NOTIFY_CHUNKED|--chunked|terminal-only|inbox-only|cmd_716 gate registry|shogun-error-fix-dual-review|skill-creation-workflow|Action Required" instructions/shogun.md instructions/karo.md
=> PASS

bash -n scripts/notify.sh
=> PASS

python3 -m py_compile scripts/discord_notify.py
=> PASS
```

## Git Preflight

作業前 `git status --short`:

```text
 M docs/dashboard_schema.json
 M memory/global_context.md
 M queue/external_inbox.yaml
 M queue/reports/ashigaru1_report.yaml
 M queue/reports/ashigaru4_report.yaml
 M queue/reports/ashigaru5_report.yaml
 M queue/reports/gunshi_report.yaml
 M queue/suggestions.yaml
 M queue/tasks/ashigaru4.yaml
 M queue/tasks/ashigaru6.yaml
 M scripts/discord_notify.py
 M scripts/notify.sh
 M scripts/shc.sh
 M tests/unit/test_notify_discord.bats
?? tests/unit/test_discord_notify.py
```

本 task の変更:

```text
instructions/shogun.md
instructions/karo.md
output/cmd_728c_lord_approval_instruction_update.md
queue/inbox/ashigaru6.yaml
queue/reports/ashigaru6_report.yaml
queue/tasks/ashigaru6.yaml
```

commit / push:

- 未実施。
- cmd_728 統合判断に委ねる。

## Remaining Notes

- 共有3源同期 (`queue/skill_candidates.yaml` / `memory/skill_history.md` / `dashboard.md`) と軍師QCは後段 subtask_728d / 統合判断の領域。
- `scripts/discord_notify.py` / `scripts/notify.sh` 自体は cmd_728e で変更済み。本 task では instruction 反映のみ。
