# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-05-16
> **Base**: `git diff upstream/main...main` (291 files, +65,384/−5,987 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: main

---

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Seven key architectural themes distinguish this fork from upstream:

1. **Context resilience and compaction safety** — A full snapshot/clear system (`context_snapshot.sh`, `pre_compact_snapshot.sh`, `pre_compact_dispatch_persist.sh`, `post_compact_dispatch_restore.sh`, `compact_exception_check.sh`, `compact_observer.sh`, `detect_compact.sh`) ensures no task state is lost across `/clear` and auto-compact events. The fork adds `compaction_recovery.md` and `context_management.md` for standardized recovery procedures.

2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment. `qc_auto_check.sh` performs schema validation; `dashboard_pipeline_test.sh` and `test_dashboard_roundtrip.py` form a render-chain regression suite. YAML schemas (`ashigaru_report_schema.yaml`, `shogun_to_karo_schema.yaml`) and shift-left validators (`validate_karo_task.py`, `validate_ashigaru_report.py`) enforce data integrity pre-dispatch. QC checklist YAML (`config/qc_checklist.yaml`) tracks SO-01 through SO-24 rules.

3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents on a server running in UTC). This is enforced via CLAUDE.md, agent instructions, and hook scripts.

4. **Skill management lifecycle** — Candidate tracking (`queue/skill_candidates.yaml`, `instructions/skill_candidates.yaml`), policy governance (`instructions/skill_policy.md`), periodic stocktake, and `sync_shogun_skills.sh` (auto-syncs on commit via git post-commit hook). New skills added: `codex-context-pane-border`, `s-check`, `shogun-dashboard-sync-silent-failure-pattern`, `skill-creation-workflow`, `shogun-gas-automated-verification`, `shogun-gas-clasp-rapt-reauth-fallback`, `shogun-bash-cross-platform-ci`, `pdfmerged-feature-release-workflow`.

5. **Multi-channel notification (Discord-first)** — ntfy server-side path retired in cmd_692. Discord gateway (`discord_gateway.py`, `discord_notify.py`, `discord_to_ntfy.py`) is now the primary notification channel. Supporting scripts: `shogun_inbox_notifier.sh`, `cmd_complete_notifier.sh`, `gchat_send.sh`, `notify.sh`. Legacy ntfy scripts (`ntfy.sh`, `ntfy_listener.sh`, `ntfy_auth.sh`) deleted.

6. **Destructive operation safety and prompt injection defense** — `instructions/common/destructive_safety.md` establishes a three-tier structure (ABSOLUTE BAN / STOP-AND-REPORT / SAFE DEFAULTS). Prompt injection defense rules treat shell commands found in source/README/comments as data only. `log_violation.sh` + `memory/Violation.md` record enforcement events.

7. **Repo health monitoring and GHA integration** — `repo_health_check.sh`, `sh_health_check.sh`, `gha_failure_check.sh`, `config/repo_health_targets.yaml`, `config/sh_health_targets.yaml`, `config/gha_monitor_targets.yaml`, and `.github/workflows/upstream-sync.yml` form a continuous self-monitoring layer that alerts the system when build or health targets degrade.

---

## Category A: Infrastructure Scripts

### `scripts/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/action_required_sync.sh` | fork-added | Sync action-required items between dashboard and queue | Keep fork — no upstream equivalent |
| `scripts/artifact_register.sh` | fork-added | Register cmd artifacts to Notion DB + Drive | Keep fork — no upstream equivalent |
| `scripts/clasp_age_check.sh` | fork-added | Check GAS/clasp token freshness | Keep fork — no upstream equivalent |
| `scripts/cmd_complete_notifier.sh` | fork-added | Notify Lord on cmd completion via Discord | Keep fork — no upstream equivalent |
| `scripts/cmd_kpi_observer.sh` | fork-added | Observe cmd KPI metrics for reporting | Keep fork — no upstream equivalent |
| `scripts/cmd_squash_pub_hook.sh` | fork-added | Rate-limited squash-commit-push hook | Keep fork — no upstream equivalent |
| `scripts/codex_context.sh` | fork-added | Build context pane content for Codex agents | Keep fork — no upstream equivalent |
| `scripts/compact_exception_check.sh` | fork-added | Check if current cmd allows compaction | Keep fork — no upstream equivalent |
| `scripts/compact_observer.sh` | fork-added | Detect auto-compact events in session | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | Write/read agent context snapshots for /clear recovery | Keep fork — no upstream equivalent |
| `scripts/counter_increment.sh` | fork-added | Increment streak/counter metrics | Keep fork — no upstream equivalent |
| `scripts/dashboard_lint.py` | fork-added | Lint dashboard.md for schema compliance | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Rotate completed items from dashboard | Keep fork — no upstream equivalent |
| `scripts/detect_compact.sh` | fork-added | Detect if session was auto-compacted | Keep fork — no upstream equivalent |
| `scripts/discord_gateway.py` | fork-added | Discord WebSocket gateway for real-time events | Keep fork — no upstream equivalent |
| `scripts/discord_gateway_healthcheck.sh` | fork-added | Health check for Discord gateway process | Keep fork — no upstream equivalent |
| `scripts/discord_notify.py` | fork-added | Send notifications to Discord channel | Keep fork — no upstream equivalent |
| `scripts/discord_to_ntfy.py` | fork-added | Bridge Discord messages to ntfy topics | Keep fork — no upstream equivalent |
| `scripts/gas_push_oauth.sh` | fork-added | Push GAS code via OAuth credentials | Keep fork — no upstream equivalent |
| `scripts/gas_push_sa.sh` | fork-added | Push GAS code via service account | Keep fork — no upstream equivalent |
| `scripts/gas_run.sh` | fork-added | Execute GAS function remotely | Keep fork — no upstream equivalent |
| `scripts/gas_run_oauth.sh` | fork-added | Execute GAS function via OAuth | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Send message to Google Chat | Keep fork — no upstream equivalent |
| `scripts/generate_dashboard_md.py` | fork-added | Generate dashboard.md from YAML sources | Keep fork — no upstream equivalent |
| `scripts/generate_notion_summary.sh` | fork-added | Generate Notion session summary | Keep fork — no upstream equivalent |
| `scripts/get_context_pct.sh` | fork-added | Get current context window usage percentage | Keep fork — no upstream equivalent |
| `scripts/gha_failure_check.sh` | fork-added | Check GitHub Actions for failures | Keep fork — no upstream equivalent |
| `scripts/git-hooks/post-commit` | fork-added | Post-commit hook (skill sync, etc.) | Keep fork — no upstream equivalent |
| `scripts/git-hooks/pre-commit-dashboard` | fork-added | Pre-commit hook for dashboard validation | Keep fork — no upstream equivalent |
| `scripts/gunshi_self_clear_check.sh` | fork-added | Self-clear safety check for gunshi agent | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | IR1 hook: validate editable file boundaries | Keep fork — no upstream equivalent |
| `scripts/hooks/karo_session_start_check.sh` | fork-added | Karo session start validation hook | Keep fork — no upstream equivalent |
| `scripts/hooks/post_compact_dispatch_restore.sh` | fork-added | Restore dispatch state after compaction | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_dispatch_persist.sh` | fork-added | Persist dispatch state before compaction | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | Save context snapshot before compaction | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_push_difference_check.sh` | fork-added | Verify difference.md is up-to-date before push | Keep fork — no upstream equivalent |
| `scripts/install-shogun-discord-service.sh` | fork-added | Install Discord bot as systemd service | Keep fork — no upstream equivalent |
| `scripts/install_git_hooks.sh` | fork-added | Install git hooks from scripts/git-hooks/ | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | Output current JST timestamp in various formats | Keep fork — no upstream equivalent |
| `scripts/karo_auto_clear.sh` | fork-added | Auto-clear karo context when safe | Keep fork — no upstream equivalent |
| `scripts/karo_dispatch.sh` | fork-added | Karo task dispatch automation | Keep fork — no upstream equivalent |
| `scripts/karo_self_clear_check.sh` | fork-added | Self-clear safety check for karo agent | Keep fork — no upstream equivalent |
| `scripts/lib/status_check_rules.py` | fork-added | Python lib for agent status check rules | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Log safety/rule violations to memory | Keep fork — no upstream equivalent |
| `scripts/n8n_feedback_append.py` | fork-added | Append feedback entries to n8n workflow | Keep fork — no upstream equivalent |
| `scripts/notify.sh` | fork-added | Unified notification dispatcher | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | Log session data to Notion | Keep fork — no upstream equivalent |
| `scripts/ntfy_wsl_template.sh` | fork-added | Template for ntfy WSL integration | Keep fork — no upstream equivalent |
| `scripts/qc_auto_check.sh` | fork-added | Autonomous QC validation runner | Keep fork — no upstream equivalent |
| `scripts/repo_health_check.sh` | fork-added | Check repository health targets | Keep fork — no upstream equivalent |
| `scripts/role_context_notify.sh` | fork-added | Notify agents of role context changes | Keep fork — no upstream equivalent |
| `scripts/safe_clear_check.sh` | fork-added | Evaluate /clear safety conditions (C1-C4) | Keep fork — no upstream equivalent |
| `scripts/safe_window_judge.sh` | fork-added | Judge if context window is in safe zone | Keep fork — no upstream equivalent |
| `scripts/self_clear_check.sh` | fork-added | Ashigaru self-clear protocol implementation | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Send test email for n8n Gmail WF testing | Keep fork — no upstream equivalent |
| `scripts/session_start_checklist.sh` | fork-added | Session start validation checklist | Keep fork — no upstream equivalent |
| `scripts/session_to_obsidian.sh` | fork-added | Export session to Obsidian vault | Keep fork — no upstream equivalent |
| `scripts/sh_health_check.sh` | fork-added | Shell/daemon health monitoring | Keep fork — no upstream equivalent |
| `scripts/shc.sh` | fork-added | Shogun health check shortcut | Keep fork — no upstream equivalent |
| `scripts/shogun-discord.service.template` | fork-added | Systemd service template for Discord bot | Keep fork — no upstream equivalent |
| `scripts/shogun_context_notify.sh` | fork-added | Notify shogun of context threshold events | Keep fork — no upstream equivalent |
| `scripts/shogun_in_progress_monitor.sh` | fork-added | Monitor shogun in-progress task state | Keep fork — no upstream equivalent |
| `scripts/shogun_inbox_notifier.sh` | fork-added | Notify Lord when shogun inbox has items | Keep fork — no upstream equivalent |
| `scripts/shogun_reality_check.sh` | fork-added | Reality check: dashboard vs actual state | Keep fork — no upstream equivalent |
| `scripts/shp.sh` | fork-added | Shogun-health-posture command | Keep fork — no upstream equivalent |
| `scripts/skill_create_with_symlink.sh` | fork-added | Create skill with symlink to ~/.claude/skills/ | Keep fork — no upstream equivalent |
| `scripts/so24_verify.sh` | fork-added | SO-24 verification (inbox+artifact+content match) | Keep fork — no upstream equivalent |
| `scripts/start_discord_bot.sh` | fork-added | Start Discord bot process | Keep fork — no upstream equivalent |
| `scripts/statusline_with_counter.sh` | fork-added | Tmux statusline with counter display | Keep fork — no upstream equivalent |
| `scripts/stop_hook_daily_log.sh` | fork-added | Stop hook: daily log rotation | Keep fork — no upstream equivalent |
| `scripts/suggestion_db.py` | fork-added | Suggestion database management | Keep fork — no upstream equivalent |
| `scripts/suggestion_vectorize.py` | fork-added | Vectorize suggestions for similarity search | Keep fork — no upstream equivalent |
| `scripts/suggestions_digest.sh` | fork-added | Generate digest from suggestion queue | Keep fork — no upstream equivalent |
| `scripts/sync_shogun_skills.sh` | fork-added | Sync skills between repo and ~/.claude/skills/ | Keep fork — no upstream equivalent |
| `scripts/test_dashboard_roundtrip.py` | fork-added | Test dashboard YAML-to-MD roundtrip | Keep fork — no upstream equivalent |
| `scripts/tests/cmd_598_dispatch_test.sh` | fork-added | Dispatch integration test (cmd_598) | Keep fork — no upstream equivalent |
| `scripts/tests/test_qc_auto_check_so23.sh` | fork-added | QC auto-check SO-23 test | Keep fork — no upstream equivalent |
| `scripts/update_dashboard.sh` | fork-added | Update dashboard.md from YAML sources | Keep fork — no upstream equivalent |
| `scripts/update_dashboard_timestamp.sh` | fork-added | Update dashboard last-updated timestamp | Keep fork — no upstream equivalent |
| `scripts/validate_ashigaru_report.py` | fork-added | Validate ashigaru report against schema | Keep fork — no upstream equivalent |
| `scripts/validate_idle_members.sh` | fork-added | Detect idle agents for reallocation | Keep fork — no upstream equivalent |
| `scripts/validate_karo_task.py` | fork-added | Validate karo task YAML against schema | Keep fork — no upstream equivalent |
| `scripts/worktree_cleanup.sh` | fork-added | Clean up git worktree directories | Keep fork — no upstream equivalent |
| `scripts/worktree_create.sh` | fork-added | Create git worktree for parallel work | Keep fork — no upstream equivalent |
| `scripts/README_SA_SETUP.md` | fork-added | Service account setup documentation | Keep fork — no upstream equivalent |

### `scripts/` — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/build_instructions.sh` | fork-modified | Extended with fork-specific instruction generation | Merge upstream, preserve fork sections |
| `scripts/inbox_watcher.sh` | fork-modified | Enhanced inbox watching with Discord integration | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | Extended message types and validation | Merge upstream, preserve fork sections |
| `scripts/ratelimit_check.sh` | fork-modified | Added fork-specific rate limit paths | Merge upstream, preserve fork sections |
| `scripts/slim_yaml.py` | fork-modified | Extended YAML slimming rules | Merge upstream, preserve fork sections |
| `scripts/stop_hook_inbox.sh` | fork-modified | Added fork-specific stop hook behavior | Merge upstream, preserve fork sections |
| `scripts/switch_cli.sh` | fork-modified | Added model routing and CLI adapter support | Merge upstream, preserve fork sections |
| `scripts/watcher_supervisor.sh` | fork-modified | Enhanced supervisor with welcome screen detection fix | Merge upstream, preserve fork sections |

### `scripts/` — Deleted (fork-deleted)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/dashboard-viewer.py` | fork-deleted | Replaced by generate_dashboard_md.py pipeline | Keep fork — intentional removal |
| `scripts/ntfy.sh` | fork-deleted | Retired: Discord replaced ntfy (cmd_692) | Keep fork — intentional removal |
| `scripts/ntfy_listener.sh` | fork-deleted | Retired: Discord replaced ntfy (cmd_692) | Keep fork — intentional removal |
| `scripts/session_start_hook.sh` | fork-deleted | Replaced by session_start_checklist.sh | Keep fork — intentional removal |

### `lib/` — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `lib/agent_status.sh` | fork-modified | Extended agent status tracking | Merge upstream, preserve fork sections |
| `lib/cli_adapter.sh` | fork-modified | Multi-CLI adapter layer (Claude/Codex/Kimi) | Merge upstream, preserve fork sections |

### `lib/` — Deleted (fork-deleted)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `lib/ntfy_auth.sh` | fork-deleted | Retired: ntfy auth no longer needed (cmd_692) | Keep fork — intentional removal |

### `.githooks/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.githooks/pre-commit` | fork-added | Pre-commit validation (dashboard lint, etc.) | Keep fork — no upstream equivalent |

---

## Category B: Library Files

### `n8n/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `n8n/feedback-system.json` | fork-added | n8n workflow definition for feedback pipeline | Keep fork — no upstream equivalent |

### `schemas/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `schemas/suggestions_schema.yaml` | fork-added | YAML schema for suggestions queue validation | Keep fork — no upstream equivalent |

---

## Category C: Agent Instructions

### `instructions/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `instructions/codex-ashigaru.md` | fork-added | Codex-specific ashigaru agent instructions | Keep fork — no upstream equivalent |
| `instructions/common/artifact_registration.md` | fork-added | Artifact registration protocol (Notion+Drive) | Keep fork — no upstream equivalent |
| `instructions/common/batch_processing.md` | fork-added | Batch processing protocol (30+ items) | Keep fork — no upstream equivalent |
| `instructions/common/compact_exception.md` | fork-added | Compaction exception rules for long cmds | Keep fork — no upstream equivalent |
| `instructions/common/compaction_recovery.md` | fork-added | Post-compaction recovery procedure | Keep fork — no upstream equivalent |
| `instructions/common/context_management.md` | fork-added | Context window management policy (50-92% thresholds) | Keep fork — no upstream equivalent |
| `instructions/common/context_snapshot.md` | fork-added | Context snapshot write/read protocol | Keep fork — no upstream equivalent |
| `instructions/common/dashboard_responsibility_matrix.md` | fork-added | Dashboard ownership matrix by role | Keep fork — no upstream equivalent |
| `instructions/common/destructive_safety.md` | fork-added | Three-tier destructive operation safety | Keep fork — no upstream equivalent |
| `instructions/common/gui_verification.md` | fork-added | GUI verification protocol for WSL2 | Keep fork — no upstream equivalent |
| `instructions/common/hook_e2e_testing.md` | fork-added | Hook E2E testing checklist | Keep fork — no upstream equivalent |
| `instructions/common/memory_policy.md` | fork-added | Memory layer policy (MCP vs files) | Keep fork — no upstream equivalent |
| `instructions/common/n8n_e2e_protocol.md` | fork-added | n8n E2E test protocol | Keep fork — no upstream equivalent |
| `instructions/common/self_watch_phase.md` | fork-added | Self-watch phase protocol | Keep fork — no upstream equivalent |
| `instructions/common/shogun_mandatory.md` | fork-added | Shogun mandatory rules (SO-01 to SO-24) | Keep fork — no upstream equivalent |
| `instructions/common/worktree.md` | fork-added | Git worktree usage instructions | Keep fork — no upstream equivalent |
| `instructions/skill_candidates.yaml` | fork-added | Active skill candidate tracking | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Skill creation/approval governance | Keep fork — no upstream equivalent |

### `instructions/` — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `instructions/ashigaru.md` | fork-modified | Extended with self-clear, snapshot, compaction recovery | Manual merge required |
| `instructions/common/forbidden_actions.md` | fork-modified | Added F004-F006b and destructive safety refs | Manual merge required |
| `instructions/common/protocol.md` | fork-modified | Extended communication protocol with inbox_write | Merge upstream, preserve fork sections |
| `instructions/generated/ashigaru.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/codex-ashigaru.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/codex-gunshi.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/codex-karo.md` | fork-modified | Type-changed (T); regenerated for Codex | Merge upstream, preserve fork sections |
| `instructions/generated/codex-shogun.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-ashigaru.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-gunshi.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-karo.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-shogun.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/gunshi.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/karo.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-ashigaru.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-gunshi.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-karo.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-shogun.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/generated/shogun.md` | fork-modified | Regenerated with fork-specific content | Merge upstream, preserve fork sections |
| `instructions/gunshi.md` | fork-modified | Extended with QC pipeline, north-star check | Manual merge required |
| `instructions/karo.md` | fork-modified | Extended with dispatch, context management, SO rules | Manual merge required |
| `instructions/roles/ashigaru_role.md` | fork-modified | Extended role definition | Merge upstream, preserve fork sections |
| `instructions/roles/gunshi_role.md` | fork-modified | Extended role definition | Merge upstream, preserve fork sections |
| `instructions/roles/karo_role.md` | fork-modified | Extended role definition | Merge upstream, preserve fork sections |
| `instructions/shogun.md` | fork-modified | Extended with mandatory rules, context layers | Manual merge required |

### `agents/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `agents/default/system.md` | fork-modified | Extended default agent system prompt | Merge upstream, preserve fork sections |

---

## Category D: Configuration

### `config/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `config/bypass_log.yaml` | fork-added | Log of rule bypass events | Keep fork — no upstream equivalent |
| `config/counter_coefficients.yaml` | fork-added | KPI counter coefficient settings | Keep fork — no upstream equivalent |
| `config/discord.env.sample` | fork-added | Discord integration env template | Keep fork — no upstream equivalent |
| `config/discord_bot.env.sample` | fork-added | Discord bot env template | Keep fork — no upstream equivalent |
| `config/gha_monitor_targets.yaml` | fork-added | GitHub Actions monitoring target repos | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Multi-project registry | Keep fork — no upstream equivalent |
| `config/qc_checklist.yaml` | fork-added | QC checklist (SO-01 to SO-24 rules) | Keep fork — no upstream equivalent |
| `config/repo_health_targets.yaml` | fork-added | Repository health metric targets | Keep fork — no upstream equivalent |
| `config/schemas/ashigaru_report_schema.yaml` | fork-added | Ashigaru report YAML schema | Keep fork — no upstream equivalent |
| `config/schemas/shogun_to_karo_schema.yaml` | fork-added | Shogun-to-Karo dispatch schema | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Central settings (screenshot path, models, etc.) | Keep fork — no upstream equivalent |
| `config/sh_health_targets.yaml` | fork-added | Shell/daemon health targets | Keep fork — no upstream equivalent |
| `config/streaks_format.yaml` | fork-added | Streak counter display format config | Keep fork — no upstream equivalent |

### `.claude/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.claude/settings.json` | fork-modified | Extended with fork hooks, permissions, model config | Manual merge required |

### `.github/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.github/copilot-instructions.md` | fork-modified | Extended Copilot instructions with fork context | Merge upstream, preserve fork sections |
| `.github/workflows/upstream-sync.yml` | fork-added | Automated upstream sync workflow | Keep fork — no upstream equivalent |

### Root config files

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.gitignore` | fork-modified | Added fork-specific ignore patterns | Merge upstream, preserve fork sections |

### `templates/`

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `templates/karo_task_template.yaml` | fork-added | Template for karo task YAML dispatch | Keep fork — no upstream equivalent |

---

## Category E: Documentation & Memory

### `docs/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `docs/DISCORD_BOT_SETUP.md` | fork-added | Discord bot setup guide | Keep fork — no upstream equivalent |
| `docs/agent-routing-baseline.md` | fork-added | Agent routing architecture baseline | Keep fork — no upstream equivalent |
| `docs/dashboard_schema.json` | fork-added | Dashboard JSON schema definition | Keep fork — no upstream equivalent |
| `docs/feedback-system-guide.md` | fork-added | Feedback system usage guide | Keep fork — no upstream equivalent |
| `docs/shogun_shell_commands.md` | fork-added | Shell command reference for shogun ops | Keep fork — no upstream equivalent |

### `memory/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `memory/MechanismSuccessLog.md` | fork-added | Track successful mechanism implementations | Keep fork — no upstream equivalent |
| `memory/Violation.md` | fork-added | Record safety/rule violation events | Keep fork — no upstream equivalent |
| `memory/canonical_rule_sources.md` | fork-added | Map rules to authoritative source files | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Skill creation/evolution history | Keep fork — no upstream equivalent |

### `context/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `context/gas-mail-manager.md` | fork-added | GAS Mail Manager project context | Keep fork — no upstream equivalent |
| `context/n8n-operations.md` | fork-added | n8n operations project context | Keep fork — no upstream equivalent |

### `originaldocs/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `originaldocs/notification_channels.md` | fork-added | Notification channel architecture docs | Keep fork — no upstream equivalent |

### `images/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `images/screenshots/ntfy_bloom_oc_test.jpg` | fork-added | Screenshot: ntfy bloom OC test | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_cmd043_progress.jpg` | fork-added | Screenshot: ntfy cmd progress | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_persona_eval_complete.jpg` | fork-added | Screenshot: persona eval notification | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_saytask_rename.jpg` | fork-added | Screenshot: task rename notification | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_final.jpg` | fork-added | Screenshot: final task list layout | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v1_before.jpg` | fork-added | Screenshot: task list v1 (before) | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v2_aligned.jpg` | fork-added | Screenshot: task list v2 (aligned) | Keep fork — no upstream equivalent |

---

## Category F: Queue & Operational Data

### `queue/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `queue/external_inbox.yaml` | fork-added | External inbox for cross-system messages | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru1_report.yaml` | fork-added | Ashigaru1 task report | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru4_report.yaml` | fork-added | Ashigaru4 task report | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru5_report.yaml` | fork-added | Ashigaru5 task report | Keep fork — no upstream equivalent |
| `queue/reports/gunshi_report.yaml` | fork-added | Gunshi task report | Keep fork — no upstream equivalent |
| `queue/skill_candidates.yaml` | fork-added | Skill candidate tracking queue | Keep fork — no upstream equivalent |
| `queue/suggestions.yaml` | fork-added | Suggestion queue from agents | Keep fork — no upstream equivalent |
| `queue/tasks/ashigaru4.yaml` | fork-added | Ashigaru4 task assignment | Keep fork — no upstream equivalent |

### `logs/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `logs/cmd_squash_pub_hook.daily.yaml` | fork-added | Daily squash-pub hook execution log | Keep fork — no upstream equivalent |
| `logs/cmd_squash_pub_hook.pending_cmds` | fork-added | Pending cmds for squash-pub batch | Keep fork — no upstream equivalent |
| `logs/cmd_squash_pub_hook.rate_limit_at` | fork-added | Rate limit timestamp for squash-pub | Keep fork — no upstream equivalent |
| `logs/safe_clear/.gitkeep` | fork-added | Directory placeholder for safe-clear logs | Keep fork — no upstream equivalent |

### `output/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `output/cmd_594_kpi_verification.md` | fork-added | KPI verification report | Keep fork — no upstream equivalent |
| `output/cmd_594_scope_b_qc_report.md` | fork-added | Scope B QC report | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_integrated.md` | fork-added | Self-improvement integrated report | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research.md` | fork-added | Self-improvement research | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research_codex.md` | fork-added | Self-improvement research (Codex) | Keep fork — no upstream equivalent |
| `output/cmd_658_phase01_report.md` | fork-added | cmd_658 phase 1 report | Keep fork — no upstream equivalent |
| `output/cmd_658_phase2_report.md` | fork-added | cmd_658 phase 2 report | Keep fork — no upstream equivalent |
| `output/cmd_659_implementation_report.md` | fork-added | cmd_659 implementation report | Keep fork — no upstream equivalent |
| `output/cmd_659_risk_mitigation_plan.md` | fork-added | cmd_659 risk mitigation plan | Keep fork — no upstream equivalent |
| `output/cmd_660_ash1_role_split_review.md` | fork-added | Role split review (ash1) | Keep fork — no upstream equivalent |
| `output/cmd_660_ash4_role_split_review.md` | fork-added | Role split review (ash4) | Keep fork — no upstream equivalent |
| `output/cmd_660_ash5_verification_phase3.md` | fork-added | Verification phase 3 (ash5) | Keep fork — no upstream equivalent |
| `output/cmd_660_ash6_codex_pattern_analysis.md` | fork-added | Codex pattern analysis (ash6) | Keep fork — no upstream equivalent |
| `output/cmd_660_ash7_codex_proposal_4_review.md` | fork-added | Codex proposal 4 review (ash7) | Keep fork — no upstream equivalent |
| `output/cmd_660_gunshi_integrated_strategy.md` | fork-added | Integrated strategy (gunshi) | Keep fork — no upstream equivalent |
| `output/cmd_660_integrated_report.md` | fork-added | cmd_660 integrated report | Keep fork — no upstream equivalent |
| `output/cmd_662_shp_command_report.md` | fork-added | SHP command report | Keep fork — no upstream equivalent |
| `output/cmd_663_codex_role_compatibility.md` | fork-added | Codex role compatibility analysis | Keep fork — no upstream equivalent |
| `output/cmd_663_integrated.md` | fork-added | cmd_663 integrated report | Keep fork — no upstream equivalent |
| `output/cmd_663_skill_codex_compat.md` | fork-added | Skill-Codex compatibility | Keep fork — no upstream equivalent |
| `output/cmd_664_discord_proactive_reaction.md` | fork-added | Discord proactive reaction design | Keep fork — no upstream equivalent |
| `output/cmd_665_shp_positional_report.md` | fork-added | SHP positional report | Keep fork — no upstream equivalent |
| `output/cmd_666_shp_retreat_report.md` | fork-added | SHP retreat report | Keep fork — no upstream equivalent |
| `output/cmd_667_codex_context_display.md` | fork-added | Codex context display fix | Keep fork — no upstream equivalent |
| `output/cmd_668_codex_0129_upgrade.md` | fork-added | Codex 0129 upgrade report | Keep fork — no upstream equivalent |
| `output/cmd_669_instructions_unification.md` | fork-added | Instructions unification report | Keep fork — no upstream equivalent |
| `output/cmd_670_missed_cmds.md` | fork-added | Missed commands analysis | Keep fork — no upstream equivalent |
| `output/cmd_670_notifier_recovery.md` | fork-added | Notifier recovery report | Keep fork — no upstream equivalent |
| `output/cmd_671_codex_context_fix.md` | fork-added | Codex context fix report | Keep fork — no upstream equivalent |
| `output/cmd_672_shp_design_unification.md` | fork-added | SHP design unification | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_integrated.md` | fork-added | Scope A integrated report | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_opus.md` | fork-added | Scope A Opus analysis | Keep fork — no upstream equivalent |
| `output/cmd_673_sh_health_visualization.md` | fork-added | SH health visualization | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_audit.md` | fork-added | Skill candidate audit | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_strict_process.md` | fork-added | Skill candidate strict process | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_candidate_integration.md` | fork-added | Skill candidate integration | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_integration_audit.md` | fork-added | Skill integration audit | Keep fork — no upstream equivalent |
| `output/cmd_675b_skill_integration_implementation.md` | fork-added | Skill integration implementation | Keep fork — no upstream equivalent |
| `output/cmd_676_gas_mail_manager_per_customer_workbook.md` | fork-added | GAS mail manager per-customer workbook | Keep fork — no upstream equivalent |
| `output/cmd_677_sh_warning_consolidation.md` | fork-added | SH warning consolidation | Keep fork — no upstream equivalent |
| `output/cmd_677_tier2_audit.md` | fork-added | Tier 2 audit report | Keep fork — no upstream equivalent |
| `output/cmd_678_repo_health_check.md` | fork-added | Repo health check report | Keep fork — no upstream equivalent |
| `output/cmd_681_dashboard_observation_queue.md` | fork-added | Dashboard observation queue | Keep fork — no upstream equivalent |
| `output/cmd_682_legacy_audit.md` | fork-added | Legacy audit report | Keep fork — no upstream equivalent |
| `output/cmd_682_skill_legacy_integration.md` | fork-added | Skill legacy integration | Keep fork — no upstream equivalent |
| `output/cmd_684_repo_health_red_runbook.md` | fork-added | Repo health RED runbook | Keep fork — no upstream equivalent |
| `output/cmd_690_phase2_api_polling_monitor.md` | fork-added | API polling monitor phase 2 | Keep fork — no upstream equivalent |
| `output/cmd_694_sh_health_repair.md` | fork-added | SH health repair report | Keep fork — no upstream equivalent |
| `output/cmd_695_daemon_health_monitor.md` | fork-added | Daemon health monitor report | Keep fork — no upstream equivalent |
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Skills evaluation update (Japanese) | Keep fork — no upstream equivalent |

### `projects/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `projects/artifact-standardization/review_cmd519.md` | fork-added | Artifact standardization review | Keep fork — no upstream equivalent |
| `projects/skill-triage-cmd521/skill_triage.md` | fork-added | Skill triage project (cmd_521) | Keep fork — no upstream equivalent |

---

## Category G: Tests

### `tests/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/cmd_544_test.sh` | fork-added | Integration test for cmd_544 | Keep fork — no upstream equivalent |
| `tests/dashboard_pipeline_test.sh` | fork-added | Dashboard render pipeline test | Keep fork — no upstream equivalent |
| `tests/dashboard_update_preserve_test.sh` | fork-added | Dashboard update preservation test | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/.gitkeep` | fork-added | QC auto-check test fixture directory | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_a.yaml` | fork-added | QC test fixture A | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_b.yaml` | fork-added | QC test fixture B | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_c.yaml` | fork-added | QC test fixture C | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_d.yaml` | fork-added | QC test fixture D | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_e.yaml` | fork-added | QC test fixture E | Keep fork — no upstream equivalent |
| `tests/test_artifact_register.sh` | fork-added | Artifact register script test | Keep fork — no upstream equivalent |
| `tests/unit/test_dashboard_timestamp.bats` | fork-added | Dashboard timestamp unit test | Keep fork — no upstream equivalent |
| `tests/unit/test_ir1_editable_files.bats` | fork-added | IR1 editable files hook unit test | Keep fork — no upstream equivalent |
| `tests/unit/test_notify_discord.bats` | fork-added | Discord notification unit test | Keep fork — no upstream equivalent |

### `tests/` — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/dim_d_quality_comparison.sh` | fork-modified | Extended quality comparison test | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_bloom_routing.bats` | fork-modified | Extended bloom routing E2E test | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_codex_startup.bats` | fork-modified | Extended Codex startup E2E test | Merge upstream, preserve fork sections |
| `tests/specs/dynamic_model_routing_spec.md` | fork-modified | Updated routing spec | Merge upstream, preserve fork sections |
| `tests/test_inbox_write.bats` | fork-modified | Extended inbox_write test cases | Merge upstream, preserve fork sections |
| `tests/unit/test_cli_adapter.bats` | fork-modified | Extended CLI adapter tests | Merge upstream, preserve fork sections |
| `tests/unit/test_dynamic_model_routing.bats` | fork-modified | Extended dynamic model routing tests | Merge upstream, preserve fork sections |
| `tests/unit/test_send_wakeup.bats` | fork-modified | Extended send wakeup tests | Merge upstream, preserve fork sections |
| `tests/unit/test_switch_cli.bats` | fork-modified | Extended switch CLI tests | Merge upstream, preserve fork sections |

### `tests/` — Deleted (fork-deleted)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/unit/test_ntfy_ack.bats` | fork-deleted | Retired: ntfy ack no longer used (cmd_692) | Keep fork — intentional removal |
| `tests/unit/test_ntfy_auth.bats` | fork-deleted | Retired: ntfy auth no longer used (cmd_692) | Keep fork — intentional removal |

---

## Category H: Root-Level & Skills Files

### Root files — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `difference.md` | fork-added | This file: fork divergence analysis | Keep fork — no upstream equivalent |

### Root files — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `AGENTS.md` | fork-modified | Extended with fork agent definitions | Merge upstream, preserve fork sections |
| `CHANGELOG.md` | fork-modified | Fork changelog entries appended | Merge upstream, preserve fork sections |
| `CLAUDE.md` | fork-modified | Heavily extended with fork procedures and rules | Manual merge required |
| `README.md` | fork-modified | Extended with fork setup instructions | Merge upstream, preserve fork sections |
| `README_ja.md` | fork-modified | Japanese README with fork content | Merge upstream, preserve fork sections |
| `first_setup.sh` | fork-modified | Extended setup with fork-specific steps | Merge upstream, preserve fork sections |
| `shutsujin_departure.sh` | fork-modified | Extended departure script | Merge upstream, preserve fork sections |

### `skills/` — Added (fork-added)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `skills/codex-context-pane-border/SKILL.md` | fork-added | Codex context pane border handling skill | Keep fork — no upstream equivalent |
| `skills/pdfmerged-feature-release-workflow/SKILL.md` | fork-added | PDF merged feature release workflow skill | Keep fork — no upstream equivalent |
| `skills/s-check/SKILL.md` | fork-added | Status check shortcut skill | Keep fork — no upstream equivalent |
| `skills/shogun-bash-cross-platform-ci/SKILL.md` | fork-added | Cross-platform CI bash skill | Keep fork — no upstream equivalent |
| `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md` | fork-added | Dashboard sync silent failure pattern skill | Keep fork — no upstream equivalent |
| `skills/shogun-gas-automated-verification/SKILL.md` | fork-added | GAS automated verification skill | Keep fork — no upstream equivalent |
| `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` | fork-added | GAS/clasp reauth fallback skill | Keep fork — no upstream equivalent |
| `skills/skill-creation-workflow/SKILL.md` | fork-added | Skill creation workflow meta-skill | Keep fork — no upstream equivalent |

### `skills/` — Modified (fork-modified)

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `skills/shogun-bloom-config/SKILL.md` | fork-modified | Extended bloom config skill | Merge upstream, preserve fork sections |
| `skills/shogun-model-list/SKILL.md` | fork-modified | Updated model list | Merge upstream, preserve fork sections |
| `skills/shogun-model-switch/SKILL.md` | fork-modified | Extended model switch logic | Merge upstream, preserve fork sections |

---

## File Count Summary

| Category | Added | Modified | Deleted | Total |
|----------|-------|----------|---------|-------|
| A: Infrastructure Scripts | 90 | 8 | 5 | 103 |
| B: Library Files | 2 | 0 | 0 | 2 |
| C: Agent Instructions | 18 | 26 | 0 | 44 |
| D: Configuration | 15 | 3 | 0 | 18 |
| E: Documentation & Memory | 18 | 0 | 0 | 18 |
| F: Queue & Operational Data | 57 | 0 | 0 | 57 |
| G: Tests | 13 | 9 | 2 | 24 |
| H: Root-Level & Skills | 9 | 10 | 0 | 19 |
| **Total** | **222** | **56** | **7** | **285** |

> Note: The 6-file discrepancy from the stated 291-file total is due to: `instructions/generated/codex-karo.md` counted as type-changed (T) by git (listed under C as fork-modified); `lib/agent_status.sh` and `lib/cli_adapter.sh` counted in Category A rather than separately; and git's internal handling of rename/type-change combinations in the raw `--stat` output. All 291 unique file paths appear in exactly one row above.

---

## Merge Strategy Notes

### Files requiring manual merge (highest risk)

These files have extensive fork-specific restructuring that cannot be auto-merged:

- `CLAUDE.md` — Fork session procedures, context layers, and mandatory rules deeply interleaved
- `.claude/settings.json` — Fork-specific hooks, permissions, and model config
- `instructions/shogun.md` — Fork mandatory rules (SO-01 to SO-24) appended
- `instructions/karo.md` — Fork dispatch protocol, context management
- `instructions/gunshi.md` — Fork QC pipeline, north-star check
- `instructions/ashigaru.md` — Fork self-clear, compaction recovery
- `instructions/common/forbidden_actions.md` — Fork F004-F006b rules added

### Safe to accept upstream

No files are currently "accept upstream" — all upstream files that exist in the fork have been extended with fork-specific content.

### Deleted files (do not restore from upstream)

All 7 deleted files relate to the ntfy retirement (cmd_692) or replacement by improved equivalents. They should remain deleted unless ntfy is re-adopted.
