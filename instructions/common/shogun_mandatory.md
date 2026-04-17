# Shogun Mandatory Rules

These rules govern system-wide behavior across all agents. Originally in CLAUDE.md §Shogun Mandatory Rules; moved here 2026-04-17 to reduce CLAUDE.md load.

1. **Dashboard**: **Karo + Gunshi update.** Gunshi: ✅ today's achievements + 🛠️ skill candidates + [proposal]/[info] tagged items in 🚨 Action Required. Karo: everything else (🐸 Frog/streaks, 🚨 Action Required [action]/[decision], 🔄 In Progress, 🏯 Standby). 🚨 Action Required tag classification: [action] = only Lord can do it, [decision] = GO/NO-GO pending, [proposal] = improvement proposal (Lord decides), [info] = awareness item. Priority: [action] > [decision] > [proposal] > [info]. Shogun reads it, never writes it.
2. **Chain of command**: Shogun → Karo → Ashigaru/Gunshi. Never bypass Karo.
3. **Reports**: Check `queue/reports/ashigaru{N}_report.yaml` and `queue/reports/gunshi_report.yaml` when waiting.
4. **Karo state**: Before sending commands, verify karo isn't busy: `tmux capture-pane -t multiagent:0.0 -p | tail -20`
5. **Screenshots**: See `config/settings.yaml` → `screenshot.path`
6. **Skill candidates**: Ashigaru reports include `skill_candidate:`. Karo collects → dashboard. Shogun approves → creates design doc.
7. **Action Required Rule (CRITICAL)**: ALL items needing Lord's decision → dashboard.md 🚨 Action Required section. ALWAYS. Even if also written elsewhere. Forgetting = Lord gets angry.
8. **Stall Response (F006)**: Do NOT immediately send /clear to a stalled agent. Always investigate first: (1) capture-pane to identify stall point → (2) cross-reference with task YAML/reports for progress → (3) check external state (API/DB etc.) → (4) make intervention decision → (5) send clear with investigation findings attached.
9. **Report Delegation (SO-16)**: Reports and deliverables involving file generation must NOT be created directly by Shogun. Delegate via cmd to Karo, using ashigaru parallel execution + gunshi QC. Exceptions: skill-ified routine commands, short conversations with Lord (under 5 min, no file generation).
10. **North Star Alignment (SO-17)**: Gunshi MUST verify north_star in task YAML. 3-point check (before analysis, during analysis, at report end). Lesson from cmd_190.
11. **Bug Fix Issue Tracking (SO-18)**: GitHub Issue creation, tracking, and closing is mandatory for bug fixes. For history management and regression prevention.
12. **Completed Item Cleanup (SO-19)**: When a cmd is completed, if there are 🚨 Action Required items linked to that cmd, delete them and reflect as resolved in ✅ achievements. Karo executes this at Step 11.7 completion processing.
13. **decomposition_hint**: cmdにタスク分配指針を含める（parallel数・gunshi_task有無・理由）。家老は原則従い、技術的理由（RACE-001/足軽空き不足/依存関係）でオーバーライド可。オーバーライド時はダッシュボードに理由を記載。
14. **Verification Before Report (SO-20)**: 将軍は家老への指示送信後、殿に報告する前に以下3点を検証する義務がある: (a) `queue/inbox/karo.yaml` に自分のメッセージが書込まれていること(idと内容で照合) (b) 指示の対象成果物(dashboard.md等)に変更が反映されていること (c) 反映内容が指示内容と一致していること。検証せずに「完了」「反映済み」と殿に報告することは F007 違反である。
