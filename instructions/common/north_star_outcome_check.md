# North Star Outcome Check

SO-17 requires Gunshi to verify `north_star` alignment before analysis, during option comparison, and in the report footer. This file extends that rule from intent alignment to outcome evidence.

## Required Outcome Evidence

For implementation, hook, cron, trigger, script, systemd, notification, or dashboard behavior changes, Gunshi QC must require one of the following before cmd completion:

1. Real dry-run evidence from the target runtime.
2. Equivalent E2E evidence that exercises the actual integration path.
3. A documented manual-verification gate when real execution is impossible in the current environment.

Unit acceptance criteria are necessary but not sufficient for `cmd_complete`. A task may pass every unit-level AC and still fail SO-17 if the north_star outcome has not been exercised in the environment where users or agents rely on it.

When the delivered behavior is intended for a final user production environment, "target runtime" means that environment, including OS, locale, shell, filesystem layout, and default encoding. Linux VPS or isolated tmux evidence is not equivalent to Japanese Windows evidence for Windows-facing tools. At least one dry-run or E2E check must cover the final user runtime, or the cmd must remain behind a manual-verification gate with a dashboard Action Required item.

Locale-specific risks must be treated as outcome risks. Examples include Windows `cp932` stdout/stderr encoding, PowerShell path resolution, Drive Desktop local path layout, and filesystem paths containing Japanese characters.

## Relationship To The Three-Point Check

The existing SO-17 three-point check answers "does this work serve the north star?" The outcome check answers "did the delivered behavior actually move the system toward that north star?" Gunshi reports must keep both:

- alignment: before analysis, option comparison, report footer.
- evidence: dry-run/E2E/manual gate proving the expected outcome is observable.

## Report Requirement

Gunshi QC reports for relevant cmds must include:

```yaml
north_star_outcome_evidence:
  status: pass | fail | manual_required | not_applicable
  evidence_type: dry_run | e2e | manual_gate | none
  command_or_artifact: "command, execution id, screenshot, log path, or manual gate"
  reason: "why this proves or fails to prove the outcome"
```

If `status` is `fail` or `manual_required`, Karo must not mark the parent cmd complete unless the cmd explicitly allows a manual verification handoff and the dashboard Action Required item is present.
