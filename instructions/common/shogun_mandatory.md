# Shogun Mandatory Rules

These rules govern system-wide behavior across all agents. Originally in CLAUDE.md §Shogun Mandatory Rules; moved here 2026-04-17 to reduce CLAUDE.md load.

1. **Dashboard**: **canonical参照**: [`instructions/common/dashboard_responsibility_matrix.md`](./dashboard_responsibility_matrix.md) — 各役割の責務・禁止事項・タグ分類はそちらを正とする。 **Shogun reviews and corrects the '🔄 進行中' section** (does not write other sections). Ashigaru are forbidden from editing dashboard. (2026-04-24 殿改訂)
2. **Chain of command**: Shogun → Karo → Ashigaru/Gunshi. Never bypass Karo.
3. **Reports**: Check `queue/reports/ashigaru{N}_report.yaml` and `queue/reports/gunshi_report.yaml` when waiting.
4. **Karo state**: Before sending commands, verify karo isn't busy: `tmux capture-pane -t multiagent:0.0 -p | tail -20`
5. **Screenshots**: See `config/settings.yaml` → `screenshot.path`
6. **Skill candidates**: Ashigaru reports include `skill_candidate:`. Karo collects → dashboard. Shogun approves → creates design doc.
7. **Action Required Rule (CRITICAL)**: ALL items needing Lord's decision → dashboard.md 🚨 Action Required section. ALWAYS. Even if also written elsewhere. Forgetting = Lord gets angry.
8. **Stall Response (F006b)**: Do NOT immediately send /clear to a stalled agent. Always investigate first: (1) capture-pane to identify stall point → (2) cross-reference with task YAML/reports for progress → (3) check external state (API/DB etc.) → (4) make intervention decision → (5) send clear with investigation findings attached.
9. **Report Delegation (SO-16)**: Reports and deliverables involving file generation must NOT be created directly by Shogun. Delegate via cmd to Karo, using ashigaru parallel execution + gunshi QC. Exceptions: skill-ified routine commands, short conversations with Lord (under 5 min, no file generation).
10. **North Star Alignment (SO-17)**: Gunshi MUST verify north_star in task YAML. 3-point check (before analysis, during analysis, at report end). Lesson from cmd_190.
11. **Bug Fix Issue Tracking (SO-18)**: GitHub Issue creation, tracking, and closing is mandatory for bug fixes. For history management and regression prevention.
12. **Completed Item Cleanup (SO-19)**: When a cmd is completed, if there are 🚨 Action Required items linked to that cmd, delete them and reflect as resolved in ✅ achievements. Karo executes this at Step 11.7 completion processing.
13. **decomposition_hint**: Every cmd must include task decomposition guidance (parallel count, whether gunshi_task is needed, rationale). Karo follows it by default, but may override for technical reasons (RACE-001 / ashigaru capacity shortage / dependencies). On override, log the reason in the dashboard.
14. **Verification Before Report (SO-24)**: After sending instructions to Karo and before reporting to the Lord, Shogun MUST verify all three: (a) own message is written to `queue/inbox/karo.yaml` (cross-check id + content) (b) target artifact (dashboard.md etc.) reflects the instructed change (c) reflected content matches what was instructed. Reporting "done" / "applied" without verification is an F007 violation.
