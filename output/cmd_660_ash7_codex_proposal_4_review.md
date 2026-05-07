# cmd_660 Scope A-5 Codex Review: Proposal 4 Reassessment After Situation Change

- Agent: ashigaru7 (Codex)
- Parent cmd: cmd_660
- Task: subtask_660_scope_a5_codex_proposal4_review
- Scope: Proposal 4, namely the cmd_597 P1-P3 Lord decision session proposal
- Output: recommendation for whether and how to issue cmd_599
- Sources reviewed: `queue/shogun_to_karo.yaml` cmd_660 entry, `output/cmd_auto_decision_prep_2fe4475e203ff8fd.md`, `output/shogun/cmd_597_role_split_directions_integrated.md`, `dashboard.md`, issue #40, issue #45, `output/cmd_658_phase01_report.md`, `output/cmd_659_implementation_report.md`, and `output/cmd_659_risk_mitigation_plan.md`

---

## Executive Summary

Proposal 4 should no longer be treated as a neutral 30 minute decision session over three open questions. The situation has changed enough that two of the three questions are now partially decided by operational evidence. P1, the definition of dispatch completion, has been validated in favor of “verified reflection” rather than mere task YAML creation or inbox delivery. The cmd_657-659 incidents show that handoff, notification, dashboard reflection, and commit or push can each fail after the nominal implementation work is complete. P2 has also moved: cmd_659 implemented the first practical form of queue or YAML as the operational source of truth with dashboard.md as a rendered artifact, at least for Action Required and achievements. P3 should be sharpened from “quality first” to “reliability and persistence first, with observability as the immediate second weight.” The revised cmd_599 should therefore ask the Lord for one confirmation line, not a full exploratory session: approve the already-evidenced P1-C / revised P2-D / revised P3-B baseline, then issue an implementation cmd focused on automatic verified-completion gating and residual SoT migration.

---

## 1. Baseline Before The Situation Changed

The integrated cmd_597 report deliberately avoided a hard conclusion. It identified the structural problem as concentration of three roles inside Karo: manager, scribe, and state-mutator. It also extracted three prior questions that had to be settled before choosing a long-term approach.

P1 asked when dispatch is complete. The old options distinguished proposal time, inbox delivery time, and reflection time. The decision prep file recommended P1-C, meaning completion at the reflected or received-report point. At the time, this was a reasoned recommendation derived from cmd_595 and cmd_596 dispatch misses, not yet a broader empirical finding across completion, persistence, and dashboard behavior.

P2 asked what should be the single source of truth. The decision prep file recommended P2-D: queue or YAML as machine source of truth, dashboard.md as a human-readable rendered view, and one-way synchronization. This was still framed as an implementation choice. `config/dashboard.yaml` had not become the real operational center, and the existing dashboard.md still carried important direct edits.

P3 asked how to weight the six axes: reliability, flexibility, observability, cost, LLM evolution tolerance, and Lord contact preservation. The prior recommendation was P3-B, quality or reliability first. This was directionally right, but the new incidents show that “quality” is too broad. The failure mode is not poor code quality alone. It is a completion pipeline that cannot prove that work has reached all durable and visible endpoints.

Therefore the original Proposal 4 correctly named the questions, but it now overstates the degree of remaining ambiguity. The decision surface has narrowed.

---

## 2. New Evidence Since The Original Proposal

The strongest new evidence is the 2026-05-08 issue #40 comment. It records that cmd_657, cmd_658, and cmd_659 all exhibited completion-time failure symptoms. cmd_657 had Karo achievement writing and dashboard SO-19 reflection, but Shogun inbox reporting was missed. cmd_658 had no achievement entry, no Discord notification, no Shogun inbox report, no dashboard SO-19 completion, and twelve files left uncommitted. cmd_659 had no proper achievement entry, no Discord notification, no Shogun inbox report, dashboard in-progress residue, and five files left uncommitted.

Issue #45 adds the parallel verification lesson. The implementation-verifier has already shown value: it detected cmd_658 and cmd_659 commit or push gaps as PARTIAL_PASS rather than letting them silently remain invisible. This matters because it changes P1 from a policy preference into a design requirement. A completion definition that excludes verifier evidence is now known to be insufficient.

The cmd_658 report also matters. Phase 0-1 successfully moved outbound notifications toward Discord through `scripts/notify.sh` and `scripts/discord_notify.py`, but inbound remained incomplete and dual-stack observation was still pending. This means “Discord notification happened” cannot yet be a universal completion criterion. The completion gate must check the configured notification path where applicable, but it must also tolerate phases where a channel is intentionally in observation or migration.

The cmd_659 report is the main P2 evidence. It implemented an Action Required pipeline where YAML is the SoT and dashboard.md becomes a rendered artifact for bounded sections. The associated risk plan explicitly addressed double SoT, duplicate issue explosion, renderer breakage, responsibility drift, severe issue burial, and rotate race. This is not a full-system SoT migration, but it proves the P2-D direction is operationally feasible and already partially delivered.

The dashboard confirms the current operational reality: Proposal 4 is still listed as requiring Lord judgment, while cmd_659 is marked complete with YAML SoT plus md render artifact mitigation and 36/36 tests passing. That creates an inconsistency: the dashboard asks the Lord to decide a question whose first implementation slice has already validated the recommended direction.

---

## 3. P1/P2/P3 Reassessment Table

| Point | Before situation change | After situation change | Codex reassessment | Required cmd_599 change |
|---|---|---|---|---|
| P1: dispatch or completion definition | P1-C was recommended because cmd_595/596 showed dispatch reflection misses. Still framed as a Lord choice among A/B/C. | cmd_657-659 show completion can fail at report, notification, dashboard reflection, SO-19 cleanup, and commit or push. implementation-verifier detected gaps that manual flow missed. | P1-C is no longer merely preferred. It should be upgraded to “verified reflection plus durable persistence.” Completion is not done until required artifacts, report YAML, state update, dashboard or rendered view, notification or explicit waiver, and git persistence are verified. | Replace “choose P1” with “confirm P1-C+ as the baseline.” Add verifier evidence as a required gate and define stage-specific waivers for notification migration cases. |
| P2: source of truth | P2-D was recommended as queue/YAML SoT plus dashboard.md rendered view. It was still an architectural proposal. | cmd_659 implemented the first slice: Action Required and achievements are YAML-driven with dashboard.md bounded render artifact. Tests covered concurrency, rotate regression, and key separation. | P2-D is partly realized. The remaining question is scope, not direction: which dashboard sections and lifecycle states migrate next, and which legacy md direct edits remain temporarily allowed. | Remove the broad SoT debate. Specify residual migration: completion state, in-progress state, waiting roster, achievement registration, and Action Required resolution should all converge on YAML/event source plus renderer. |
| P3: six-axis weighting | P3-B, reliability or quality first, was recommended against equal weighting, contact-first, or cost-first alternatives. | The latest failures are persistence and observability failures more than pure implementation quality failures. A low-cost or flexibility-first approach would keep producing invisible partial completion. | Keep P3-B but rename the top weight to “reliability of durable completion.” Observability is second, because verifier and rendered SoT only help if their signals are surfaced automatically. Lord contact preservation remains important but must be structured through explicit decision gates, not manual completion chores. | Ask the Lord to approve the narrowed ordering: durable reliability > observability > recovery cost > Lord decision clarity > flexibility > LLM evolution tolerance. |

---

## 4. Is A 30 Minute Lord Decision Session Still Necessary?

My assessment is that the original 30 minute session is no longer the best default. It was valuable when P1-P3 were unresolved design questions. Today, using that full session format risks reopening issues that the system has already answered with painful evidence.

The Lord still needs a decision, but the decision should be narrower: approve the revised baseline and authorize follow-up implementation. A full exploratory meeting should be reserved only if the Lord rejects one of the three revised defaults.

The self-evident items can be removed from the session:

- Whether completion can mean task YAML creation: no. The later failures happened after task work existed.
- Whether inbox delivery alone is enough: no. Missing Shogun reports, Discord misses, and commit gaps prove that delivery is not equivalent to complete state reflection.
- Whether dashboard.md should remain the source for Action Required: no. cmd_659 already moved the critical slice to YAML with renderer protection.
- Whether reliability can be weighted equal with flexibility or cost: no. Recent failures created direct operational risk, including uncommitted files that could be lost on reboot.

The new items that should be added are more concrete:

- What are the required completion endpoints for each cmd type?
- Which endpoints are hard gates and which can be waived with an explicit reason?
- How should implementation-verifier results become automatic Phase 3 hook input?
- Which dashboard sections remain outside the cmd_659 renderer boundary, and what is the migration order?
- How should Karo avoid blocking on verification while still preventing false completion?

This is a design-for-execution agenda, not a broad strategy discussion. The Lord should not need to spend time choosing among already-discredited abstractions.

---

## 5. Revised cmd_599 Proposal

The old cmd_599 concept should be revised from “dispatch automation after Lord session” to “verified completion pipeline Phase 1, based on P1-C+ and P2-D.”

Proposed purpose:

> Implement a verified completion gate for high-risk cmd types so that a cmd cannot be reported as complete until required report, artifact, dashboard or renderer reflection, notification, and git persistence checks are either PASS or explicitly waived with a machine-readable reason.

Proposed scope:

1. Define cmd completion endpoint schema.
   - Fields should include report YAML path, output artifacts, task YAML status, parent cmd status, dashboard/action_required reflection state, notification expectation, implementation-verifier result, git status, unpushed commit check, and waiver list.
   - The schema should be YAML-first and designed for renderer or dashboard display later.

2. Integrate implementation-verifier as the automatic validator for completion.
   - The issue #45 evidence shows the verifier works. The missing part is automatic launch and gating.
   - It should run on task completion reports and produce structured PASS / CONDITIONAL_PASS / PARTIAL_PASS / FAIL output.

3. Add completion gate behavior to Karo workflow.
   - Karo may accept an ashigaru task as technically complete, but parent cmd completion should remain blocked until endpoint verification passes.
   - This avoids making ashigaru wait on every global system concern while still preventing false parent completion.

4. Extend P2-D beyond Action Required.
   - cmd_659 covered Action Required and achievements. The next migration slice should include in-progress completion cleanup and waiting roster updates, because those were part of cmd_659 dashboard residue.
   - Direct dashboard.md edits should be treated as emergency exceptions with a reason.

5. Define notification migration waivers.
   - During cmd_658 Phase 1-2 dual-stack transition, some Discord or ntfy checks may be transitional.
   - A completion gate should not require an unavailable channel blindly. It should require either delivery evidence or a declared migration waiver tied to the relevant phase.

Acceptance criteria for revised cmd_599 should be concrete:

- A completion endpoint schema exists and is documented.
- A verifier-trigger path runs from task_completed or report_received events without polling.
- At least two historical fixtures reproduce cmd_658 and cmd_659 commit or dashboard reflection misses and are detected.
- Parent cmd completion is blocked on FAIL or PARTIAL_PASS unless an explicit waiver is recorded.
- Dashboard or a generated report displays blocked completion reasons.
- Tests include git dirty state, untracked file, unpushed commit, missing artifact, missing report, and notification waiver cases.

This revised cmd_599 is more useful than a pure dispatch automation task because the new failures are broader than dispatch. Dispatch misses remain one manifestation, but the higher-order failure is “declaring done before durable, visible, verified completion.”

---

## 6. Alternative If cmd_599 Is Not Issued

If the Lord does not want to issue cmd_599 immediately, the minimum alternative is an explicit policy update plus manual enforcement:

1. Mark Proposal 4 resolved in dashboard as “P1-C+ / P2-D / P3-B adopted provisionally.”
2. Require Shogun or Karo to run implementation-verifier before every parent cmd completion report.
3. Require `git status --short` and unpushed commit checks in every completion report for code-changing cmd.
4. Keep cmd_659 renderer boundaries as the canonical Action Required path and forbid md direct edits except emergency repair.
5. Create a smaller follow-up cmd only for issue #45 Phase 3 hook.

This alternative is cheaper but weaker. It still relies on humans remembering to invoke verifier and git checks. It is acceptable only as a short bridge for one or two days, not as a long-term answer to issue #40.

---

## 7. Recommended Action

Recommended action is:

> Do not hold the original 30 minute exploratory Proposal 4 session. Ask the Lord for a one-line confirmation: “Approve P1-C+ verified completion, P2-D YAML/event SoT plus rendered dashboard, and P3 durable reliability first; issue revised cmd_599 for verified completion gating.” Then dispatch revised cmd_599.

The reasoning is direct. P1 has been empirically validated by repeated post-dispatch failures. P2 has been partially implemented by cmd_659 and should now be expanded rather than reopened. P3 has been strengthened by the cost of uncommitted work, missed notifications, and stale dashboard state. The remaining work is not more debate over A-D. It is to turn the confirmed direction into a completion pipeline that cannot silently skip durable state, visibility, or persistence.

The only caveat is sequencing with issue #45. Revised cmd_599 and issue #45 Phase 3 are tightly coupled. If the organization wants smaller commands, split them as follows:

- cmd_599a: completion endpoint schema plus historical fixtures.
- cmd_599b: implementation-verifier automatic hook and Karo gate.
- cmd_599c: dashboard/rendered blocked-completion visibility plus P2-D residual migration.

However, splitting should not weaken the invariant: parent cmd completion must require verified reflection and durable persistence, or an explicit recorded waiver.
