# cmd_704 push discipline report

## Summary

Implemented cmd completion discipline so Karo must verify git cleanliness and pushed state before reporting `cmd=done`.

## Changes

- Updated `instructions/karo.md` Step 11.7 from seven to eight atomic completion steps.
- Added mandatory `cmd_complete_git_preflight.sh` execution before `inbox_write shogun`.
- Documented external repo handling, no-commit/no-push cases, and ignored artifact handling.
- Updated `instructions/common/task_flow.md` pre-commit gate with the same completion-time clean/pushed checks.
- Added `scripts/cmd_complete_git_preflight.sh`:
  - accepts `--repo PATH`
  - accepts optional `--ref REF`
  - reports repo, head, branch, ref, dirty_count, ahead, behind
  - exits nonzero for dirty worktree, unpushed commits, behind, divergence, or missing upstream

## Validation

Commands run:

```bash
bash -n scripts/cmd_complete_git_preflight.sh scripts/cmd_complete.sh scripts/cmd_complete_notifier.sh
bash scripts/cmd_complete_git_preflight.sh --repo /home/ubuntu/shogun
git diff -- instructions/karo.md instructions/common/task_flow.md scripts/cmd_complete_git_preflight.sh queue/inbox/ashigaru2.yaml
git status --short --branch --untracked-files=all
```

Results:

- `bash -n`: PASS.
- `cmd_complete_git_preflight.sh --repo /home/ubuntu/shogun`: expected FAIL because the current worktree has active uncommitted changes. It correctly reported `ahead: 0`, `behind: 0`, and dirty files.
- `git status --short --branch`: repo is not ahead of `origin/main`; unrelated dirty runtime files remain outside this task.

## Acceptance Criteria

- G-1: PASS. Karo completion flow now requires git status scope confirmation and pushed-state confirmation before done reporting.
- G-2: PASS. Added small preflight script for repo/ref clean/ahead/behind checks.
- G-3: PASS. Documented commit/push not required cases, external repos, and ignored artifacts.
- G-4: PASS. Ran shell syntax validation and recorded implementation plus residual risk here.

## Residual Risk

- The repository uses a whitelist `.gitignore`; the new script is currently an ignored file unless force-added or whitelisted during publication.
- Preflight uses local upstream/ref state and does not fetch by default. Karo should fetch separately when remote freshness matters.
- Existing unrelated dirty files were not modified or reverted.
