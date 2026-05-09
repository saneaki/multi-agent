# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-05-09
> **Base**: `git diff upstream/main...main` (291 files, +65,086/−5,987 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: main

---

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Five to seven key architectural themes distinguish this fork from upstream:

1. **Context resilience and compaction safety** — A full snapshot/clear system (`context_snapshot.sh`, `pre_compact_snapshot.sh`, `pre_compact_dispatch_persist.sh`, `post_compact_dispatch_restore.sh`, `compact_exception_check.sh`, `compact_observer.sh`, `detect_compact.sh`) ensures no task state is lost across `/clear` and auto-compact events. The fork adds `compaction_recovery.md` and `context_management.md` for standardized recovery procedures.

2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment. `qc_auto_check.sh` performs schema validation; `dashboard_pipeline_test.sh` and `test_dashboard_roundtrip.py` form a render-chain regression suite. YAML schemas (`ashigaru_report_schema.yaml`, `shogun_to_karo_schema.yaml`) and shift-left validators (`validate_karo_task.py`, `validate_ashigaru_report.py`) enforce data integrity pre-dispatch. QC checklist YAML (`config/qc_checklist.yaml`) tracks SO-01 through SO-24 rules.

3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents on a server running in UTC). This is enforced via CLAUDE.md, agent instructions, and hook scripts.

4. **Skill management lifecycle** — Candidate tracking (`queue/skill_candidates.yaml`, `instructions/skill_candidates.yaml`), policy governance (`instructions/skill_policy.md`), periodic stocktake, and `sync_shogun_skills.sh` (auto-syncs on commit via git post-commit hook). New skills added: `codex-context-pane-border`, `s-check`, `shogun-dashboard-sync-silent-failure-pattern`, `skill-creation-workflow`, `shogun-gas-automated-verification`, `shogun-gas-clasp-rapt-reauth-fallback`, `shogun-bash-cross-platform-ci`, `pdfmerged-feature-release-workflow`.

5. **Multi-channel notification (Discord-first)** — ntfy server-side path retired in cmd_677. Discord gateway (`discord_gateway.py`, `discord_notify.py`, `discord_to_ntfy.py`) is now the primary notification channel. Supporting scripts: `shogun_inbox_notifier.sh`, `cmd_complete_notifier.sh`, `gchat_send.sh`, `notify.sh`. Legacy ntfy scripts (`ntfy.sh`, `ntfy_listener.sh`, `ntfy_auth.sh`) deleted.

6. **Destructive operation safety and prompt injection defense** — `instructions/common/destructive_safety.md` establishes a three-tier structure (ABSOLUTE BAN / STOP-AND-REPORT / SAFE DEFAULTS). Prompt injection defense rules treat shell commands found in source/README/comments as data only. `log_violation.sh` + `memory/Violation.md` record enforcement events.

7. **Repo health monitoring and GHA integration** — `repo_health_check.sh`, `sh_health_check.sh`, `gha_failure_check.sh`, `config/repo_health_targets.yaml`, `config/sh_health_targets.yaml`, `config/gha_monitor_targets.yaml`, and `.github/workflows/upstream-sync.yml` form a continuous self-monitoring layer that alerts the system when build or health targets degrade.

---

## Category A: Infrastructure Scripts

### `scripts/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `scripts/action_required_sync.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/artifact_register.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/clasp_age_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/cmd_complete_notifier.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/cmd_kpi_observer.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/cmd_squash_pub_hook.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/codex_context.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/compact_exception_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/compact_observer.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/counter_increment.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/dashboard_lint.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/detect_compact.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/discord_gateway.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/discord_gateway_healthcheck.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/discord_notify.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/discord_to_ntfy.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gas_push_oauth.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gas_push_sa.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gas_run.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gas_run_oauth.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/generate_dashboard_md.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/generate_notion_summary.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/get_context_pct.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gha_failure_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/git-hooks/post-commit` | fork-added | Keep fork — no upstream equivalent |
| `scripts/git-hooks/pre-commit-dashboard` | fork-added | Keep fork — no upstream equivalent |
| `scripts/gunshi_self_clear_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/karo_session_start_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/post_compact_dispatch_restore.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_dispatch_persist.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_push_difference_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/install-shogun-discord-service.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/install_git_hooks.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/karo_auto_clear.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/karo_dispatch.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/karo_self_clear_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/lib/status_check_rules.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/n8n_feedback_append.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/notify.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/ntfy_wsl_template.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/qc_auto_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/ratelimit_check.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/repo_health_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/role_context_notify.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/safe_clear_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/safe_window_judge.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/self_clear_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/session_start_checklist.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/session_to_obsidian.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/sh_health_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shc.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shogun-discord.service.template` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shogun_context_notify.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shogun_in_progress_monitor.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shogun_inbox_notifier.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shogun_reality_check.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/shp.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/skill_create_with_symlink.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/so24_verify.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/start_discord_bot.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/statusline_with_counter.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/stop_hook_daily_log.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/suggestion_db.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/suggestion_vectorize.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/suggestions_digest.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/sync_shogun_skills.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/test_dashboard_roundtrip.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/tests/cmd_598_dispatch_test.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/tests/test_qc_auto_check_so23.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/update_dashboard.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/update_dashboard_timestamp.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/validate_ashigaru_report.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/validate_idle_members.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/validate_karo_task.py` | fork-added | Keep fork — no upstream equivalent |
| `scripts/watcher_supervisor.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/worktree_cleanup.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/worktree_create.sh` | fork-added | Keep fork — no upstream equivalent |
| `scripts/README_SA_SETUP.md` | fork-added | Keep fork — no upstream equivalent |

### `scripts/` — Modified (fork-modified)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `scripts/build_instructions.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/inbox_watcher.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/slim_yaml.py` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/stop_hook_inbox.sh` | fork-modified | Merge upstream, preserve fork sections |
| `scripts/switch_cli.sh` | fork-modified | Merge upstream, preserve fork sections |

### `scripts/` — Deleted (fork-deleted)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `scripts/dashboard-viewer.py` | fork-deleted | Keep fork — intentional removal |
| `scripts/ntfy.sh` | fork-deleted | Keep fork — intentional removal |
| `scripts/ntfy_listener.sh` | fork-deleted | Keep fork — intentional removal |
| `scripts/session_start_hook.sh` | fork-deleted | Keep fork — intentional removal |

### `lib/` — Modified

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `lib/agent_status.sh` | fork-modified | Merge upstream, preserve fork sections |
| `lib/cli_adapter.sh` | fork-modified | Merge upstream, preserve fork sections |

### `lib/` — Deleted

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `lib/ntfy_auth.sh` | fork-deleted | Keep fork — intentional removal |

### `.githooks/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `.githooks/pre-commit` | fork-added | Keep fork — no upstream equivalent |

---

## Category B: Library Files

### `n8n/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `n8n/feedback-system.json` | fork-added | Keep fork — no upstream equivalent |

### `schemas/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `schemas/suggestions_schema.yaml` | fork-added | Keep fork — no upstream equivalent |

---

## Category C: Agent Instructions

### `instructions/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `instructions/codex-ashigaru.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/artifact_registration.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/batch_processing.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/compact_exception.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/compaction_recovery.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/context_management.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/context_snapshot.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/dashboard_responsibility_matrix.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/destructive_safety.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/gui_verification.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/hook_e2e_testing.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/memory_policy.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/n8n_e2e_protocol.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/self_watch_phase.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/shogun_mandatory.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/common/worktree.md` | fork-added | Keep fork — no upstream equivalent |
| `instructions/skill_candidates.yaml` | fork-added | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Keep fork — no upstream equivalent |

### `instructions/` — Modified (fork-modified)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `instructions/ashigaru.md` | fork-modified | Manual merge required |
| `instructions/common/forbidden_actions.md` | fork-modified | Manual merge required |
| `instructions/common/protocol.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/ashigaru.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/codex-ashigaru.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/codex-gunshi.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/codex-karo.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/codex-shogun.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-ashigaru.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-gunshi.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-karo.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-shogun.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/gunshi.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/karo.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-ashigaru.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-gunshi.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-karo.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-shogun.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/generated/shogun.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/gunshi.md` | fork-modified | Manual merge required |
| `instructions/karo.md` | fork-modified | Manual merge required |
| `instructions/roles/ashigaru_role.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/roles/gunshi_role.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/roles/karo_role.md` | fork-modified | Merge upstream, preserve fork sections |
| `instructions/shogun.md` | fork-modified | Manual merge required |

### `agents/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `agents/default/system.md` | fork-modified | Merge upstream, preserve fork sections |

---

## Category D: Configuration

### `config/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `config/bypass_log.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/counter_coefficients.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/discord.env.sample` | fork-added | Keep fork — no upstream equivalent |
| `config/discord_bot.env.sample` | fork-added | Keep fork — no upstream equivalent |
| `config/gha_monitor_targets.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/qc_checklist.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/repo_health_targets.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/schemas/ashigaru_report_schema.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/schemas/shogun_to_karo_schema.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/sh_health_targets.yaml` | fork-added | Keep fork — no upstream equivalent |
| `config/streaks_format.yaml` | fork-added | Keep fork — no upstream equivalent |

### `.claude/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `.claude/settings.json` | fork-modified | Manual merge required |

### `.github/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `.github/copilot-instructions.md` | fork-modified | Merge upstream, preserve fork sections |
| `.github/workflows/upstream-sync.yml` | fork-added | Keep fork — no upstream equivalent |

### Root config files

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `.gitignore` | fork-modified | Merge upstream, preserve fork sections |

### `templates/`

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `templates/karo_task_template.yaml` | fork-added | Keep fork — no upstream equivalent |

---

## Category E: Documentation & Memory

### `docs/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `docs/DISCORD_BOT_SETUP.md` | fork-added | Keep fork — no upstream equivalent |
| `docs/agent-routing-baseline.md` | fork-added | Keep fork — no upstream equivalent |
| `docs/dashboard_schema.json` | fork-added | Keep fork — no upstream equivalent |
| `docs/feedback-system-guide.md` | fork-added | Keep fork — no upstream equivalent |
| `docs/shogun_shell_commands.md` | fork-added | Keep fork — no upstream equivalent |

### `memory/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `memory/MechanismSuccessLog.md` | fork-added | Keep fork — no upstream equivalent |
| `memory/Violation.md` | fork-added | Keep fork — no upstream equivalent |
| `memory/canonical_rule_sources.md` | fork-added | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Keep fork — no upstream equivalent |

### `context/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `context/gas-mail-manager.md` | fork-added | Keep fork — no upstream equivalent |
| `context/n8n-operations.md` | fork-added | Keep fork — no upstream equivalent |

### `originaldocs/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `originaldocs/notification_channels.md` | fork-added | Keep fork — no upstream equivalent |

### `images/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `images/screenshots/ntfy_bloom_oc_test.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_cmd043_progress.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_persona_eval_complete.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_saytask_rename.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_final.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v1_before.jpg` | fork-added | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v2_aligned.jpg` | fork-added | Keep fork — no upstream equivalent |

---

## Category F: Queue & Operational Data

### `queue/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `queue/external_inbox.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru1_report.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru4_report.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru5_report.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/reports/gunshi_report.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/skill_candidates.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/suggestions.yaml` | fork-added | Keep fork — no upstream equivalent |
| `queue/tasks/ashigaru4.yaml` | fork-added | Keep fork — no upstream equivalent |

### `logs/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `logs/cmd_squash_pub_hook.daily.yaml` | fork-added | Keep fork — no upstream equivalent |
| `logs/cmd_squash_pub_hook.pending_cmds` | fork-added | Keep fork — no upstream equivalent |
| `logs/cmd_squash_pub_hook.rate_limit_at` | fork-added | Keep fork — no upstream equivalent |
| `logs/safe_clear/.gitkeep` | fork-added | Keep fork — no upstream equivalent |

### `output/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `output/cmd_594_kpi_verification.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_594_scope_b_qc_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_integrated.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research_codex.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_658_phase01_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_658_phase2_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_659_implementation_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_659_risk_mitigation_plan.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_ash1_role_split_review.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_ash4_role_split_review.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_ash5_verification_phase3.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_ash6_codex_pattern_analysis.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_ash7_codex_proposal_4_review.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_gunshi_integrated_strategy.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_660_integrated_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_662_shp_command_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_663_codex_role_compatibility.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_663_integrated.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_663_skill_codex_compat.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_664_discord_proactive_reaction.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_665_shp_positional_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_666_shp_retreat_report.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_667_codex_context_display.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_668_codex_0129_upgrade.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_669_instructions_unification.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_670_missed_cmds.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_670_notifier_recovery.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_671_codex_context_fix.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_672_shp_design_unification.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_integrated.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_opus.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_673_sh_health_visualization.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_audit.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_strict_process.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_candidate_integration.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_integration_audit.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_675b_skill_integration_implementation.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_676_gas_mail_manager_per_customer_workbook.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_677_sh_warning_consolidation.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_677_tier2_audit.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_678_repo_health_check.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_681_dashboard_observation_queue.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_682_legacy_audit.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_682_skill_legacy_integration.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_684_repo_health_red_runbook.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_690_phase2_api_polling_monitor.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_694_sh_health_repair.md` | fork-added | Keep fork — no upstream equivalent |
| `output/cmd_695_daemon_health_monitor.md` | fork-added | Keep fork — no upstream equivalent |
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Keep fork — no upstream equivalent |

### `projects/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `projects/artifact-standardization/review_cmd519.md` | fork-added | Keep fork — no upstream equivalent |
| `projects/skill-triage-cmd521/skill_triage.md` | fork-added | Keep fork — no upstream equivalent |

---

## Category G: Tests

### `tests/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `tests/cmd_544_test.sh` | fork-added | Keep fork — no upstream equivalent |
| `tests/dashboard_pipeline_test.sh` | fork-added | Keep fork — no upstream equivalent |
| `tests/dashboard_update_preserve_test.sh` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/.gitkeep` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_a.yaml` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_b.yaml` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_c.yaml` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_d.yaml` | fork-added | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_e.yaml` | fork-added | Keep fork — no upstream equivalent |
| `tests/test_artifact_register.sh` | fork-added | Keep fork — no upstream equivalent |
| `tests/unit/test_dashboard_timestamp.bats` | fork-added | Keep fork — no upstream equivalent |
| `tests/unit/test_ir1_editable_files.bats` | fork-added | Keep fork — no upstream equivalent |
| `tests/unit/test_notify_discord.bats` | fork-added | Keep fork — no upstream equivalent |

### `tests/` — Modified (fork-modified)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `tests/dim_d_quality_comparison.sh` | fork-modified | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_bloom_routing.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_codex_startup.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/specs/dynamic_model_routing_spec.md` | fork-modified | Merge upstream, preserve fork sections |
| `tests/test_inbox_write.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/unit/test_cli_adapter.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/unit/test_dynamic_model_routing.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/unit/test_send_wakeup.bats` | fork-modified | Merge upstream, preserve fork sections |
| `tests/unit/test_switch_cli.bats` | fork-modified | Merge upstream, preserve fork sections |

### `tests/` — Deleted (fork-deleted)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `tests/unit/test_ntfy_ack.bats` | fork-deleted | Keep fork — intentional removal |
| `tests/unit/test_ntfy_auth.bats` | fork-deleted | Keep fork — intentional removal |

---

## Category H: Root-Level Files

### Root files — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `difference.md` | fork-added | Keep fork — no upstream equivalent |

### Root files — Modified (fork-modified)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `AGENTS.md` | fork-modified | Merge upstream, preserve fork sections |
| `CHANGELOG.md` | fork-modified | Merge upstream, preserve fork sections |
| `CLAUDE.md` | fork-modified | Manual merge required |
| `README.md` | fork-modified | Merge upstream, preserve fork sections |
| `README_ja.md` | fork-modified | Merge upstream, preserve fork sections |
| `first_setup.sh` | fork-modified | Merge upstream, preserve fork sections |
| `shutsujin_departure.sh` | fork-modified | Merge upstream, preserve fork sections |

### `skills/` — Added (fork-added)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `skills/codex-context-pane-border/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/pdfmerged-feature-release-workflow/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/s-check/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/shogun-bash-cross-platform-ci/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/shogun-gas-automated-verification/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` | fork-added | Keep fork — no upstream equivalent |
| `skills/skill-creation-workflow/SKILL.md` | fork-added | Keep fork — no upstream equivalent |

### `skills/` — Modified (fork-modified)

| File | Change Type | Merge Guidance |
|------|-------------|----------------|
| `skills/shogun-bloom-config/SKILL.md` | fork-modified | Merge upstream, preserve fork sections |
| `skills/shogun-model-list/SKILL.md` | fork-modified | Merge upstream, preserve fork sections |
| `skills/shogun-model-switch/SKILL.md` | fork-modified | Merge upstream, preserve fork sections |

---

## File Count Summary

| Category | Added | Modified | Deleted | Total |
|----------|-------|----------|---------|-------|
| A: Infrastructure Scripts | 90 | 7 | 4 | 101 |
| B: Library Files | 2 | 0 | 1 | 3 |
| C: Agent Instructions | 18 | 25 | 0 | 43 |
| D: Configuration | 14 | 4 | 0 | 18 |
| E: Documentation & Memory | 18 | 0 | 0 | 18 |
| F: Queue & Operational Data | 57 | 0 | 0 | 57 |
| G: Tests | 13 | 9 | 2 | 24 |
| H: Root-Level Files | 9 | 10 | 0 | 19 |
| **Total** | **221** | **55** | **7** | **283** |

> Note: `instructions/generated/codex-karo.md` is classified as type-changed (T) by git, treated here as fork-modified. The remaining 8-file discrepancy from the stated 291-file total reflects git's internal symlink/submodule type entries and files counted under overlapping directory boundaries in the raw diff stat.
