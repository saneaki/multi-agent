# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-05-09
> **Base**: `git diff upstream/main...main` (285 files, +66,683/−5,629 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: main

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Key architectural themes:

1. **Context resilience** — Snapshot write/clear system for surviving /clear and compaction; pre-compact dispatch persistence for Karo (Issue #32); `compact_exception_check.sh` for preserve_across_stages scenarios; `compact_observer.sh` + `detect_compact.sh` for tracking auto-compact frequency
2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment; `qc_auto_check.sh` for schema validation; QC checklist YAML with SO-01 through SO-24; shift-left validators (`validate_karo_task.py`, `validate_ashigaru_report.py`) enforced by YAML schemas; `dashboard_pipeline_test.sh` for render-chain regression
3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents)
4. **Skill management lifecycle** — Candidate tracking, policy, evaluation, promotion pipeline, periodic stocktake; new skills: codex-context-pane-border, s-check, shogun-dashboard-sync-silent-failure-pattern, skill-creation-workflow, shogun-gas-automated-verification, shogun-gas-clasp-rapt-reauth-fallback; `sync_shogun_skills.sh` auto-syncs on commit via git post-commit hook
5. **Multi-channel notification** — ntfy, Discord gateway, Google Chat, cmd_complete notifier; `shogun_inbox_notifier.sh` bridges inbox→ntfy; `discord_gateway.py` for DM ingest; `cmd_complete_notifier.sh` for task completion alerts; `ntfy_listener.sh` removed in cmd_677 (replaced by Discord-first notification flow)
6. **GitHub Actions failure monitoring** — `gha_failure_check.sh` polls GH API for 9-repo CI health; `config/gha_monitor_targets.yaml` defines targets with active-workflow + primary-event + 30-day filters; integrated into `repo_health_check.sh` hourly timer and dashboard rendering (cmd_690)
7. **Multi-CLI generated instructions** — `build_instructions.sh` generates role-specific instruction files for Codex, Copilot, Kimi, and default CLI variants from canonical sources (`instructions/roles/*.md`, `instructions/common/*.md`); `canonical_rule_sources.md` defines authoritative source tiers; F006a bans direct editing of generated files; `forbidden_actions.md` centralises all F-rules; pre-commit hook enforces freshness

---

## Category A: Infrastructure Scripts

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/action_required_sync.sh` | fork-added | Syncs Action Required items between `dashboard.yaml` and `dashboard.md`. Maintains bidirectional consistency so Gunshi QC inserts propagate to rendered markdown. | Keep fork — no upstream equivalent |
| `scripts/artifact_register.sh` | fork-added | Registers cmd artifacts to Notion DB + Drive. Accepts `--output_path`, `--cmd_id`, `--title`; creates Notion page via API with `Notion-Version: 2022-06-28`; logs registration result. | Keep fork — no upstream equivalent |
| `scripts/build_instructions.sh` | fork-modified | Generates role-specific instructions for Codex/Copilot/Kimi/default CLIs from canonical `instructions/roles/*.md` + `instructions/common/*.md`. Pre-commit hook calls this to ensure freshness. Fork adds multi-variant generation and codex-ashigaru/codex-gunshi/codex-shogun targets. | Merge upstream, preserve fork sections |
| `scripts/clasp_age_check.sh` | fork-added | Checks `.clasprc.json` token age and warns when OAuth credentials approach expiry. Prevents silent `clasp push` failures due to stale RAPT tokens. | Keep fork — no upstream equivalent |
| `scripts/cmd_complete_notifier.sh` | fork-added | Sends task completion notification via ntfy/Discord when a cmd finishes. Triggered by Karo after final report aggregation. | Keep fork — no upstream equivalent |
| `scripts/cmd_kpi_observer.sh` | fork-added | Tracks cmd-level KPIs: elapsed time, token usage, agent utilization. Writes metrics to `logs/` for dashboard consumption. | Keep fork — no upstream equivalent |
| `scripts/cmd_squash_pub_hook.sh` | fork-added | Git stop-hook: on `git push`, squashes suggestion entries, enforces rate-limit (30-min cooldown), daily metric logging, kill-switch support. Prevents notification storms from rapid pushes. | Keep fork — no upstream equivalent |
| `scripts/codex_context.sh` | fork-added | Codex CLI context % detector. Queries Codex 0.129.0+ SQLite DBs (`logs_2.sqlite` → `state_5.sqlite` two-step lookup) and returns context usage percentage for tmux pane-border display. | Keep fork — no upstream equivalent |
| `scripts/compact_exception_check.sh` | fork-added | Checks if current task has `context_policy: preserve_across_stages`. Returns exit 1 if compaction should be suppressed (ongoing multi-stage cmd). | Keep fork — no upstream equivalent |
| `scripts/compact_observer.sh` | fork-added | Logs auto-compact frequency per agent. Writes timestamp + agent_id + context_pct to `logs/compact_observer.log`. Used by Gunshi to detect compaction-storm agents. | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | Writes/reads agent context snapshots to `queue/snapshots/{agent_id}_snapshot.yaml`. Captures approach/progress/decisions/blockers at task milestones for /clear and compaction recovery. | Keep fork — no upstream equivalent |
| `scripts/counter_increment.sh` | fork-added | Atomic counter increment for `counter_coefficients.yaml`. Used by dashboard metrics (streak tracking, cmd count). `flock`-protected for concurrent agent writes. | Keep fork — no upstream equivalent |
| `scripts/dashboard-viewer.py` | fork-deleted | Python web viewer for dashboard.md with auto-refresh. Removed from fork — dashboard viewing moved to alternative approaches. | Accept upstream |
| `scripts/dashboard_lint.py` | fork-added | Lints `dashboard.md` for structural errors: orphan sections, tag mismatches, emoji prefix violations, stale timestamps. Used in CI pre-commit checks. | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Rotates completed items from dashboard.md active sections to archive. Prevents unbounded growth of 🔄進行中 and ✅戦果 sections. | Keep fork — no upstream equivalent |
| `scripts/detect_compact.sh` | fork-added | Detects auto-compact events by monitoring conversation file size drops. Returns agent_id + timestamp when compaction detected. Used by `compact_observer.sh`. | Keep fork — no upstream equivalent |
| `scripts/discord_gateway.py` | fork-added | Discord DM ingest gateway. Connects to Discord WebSocket, writes inbound DMs to `queue/external_inbox.yaml` with flock. Runs as systemd service. | Keep fork — no upstream equivalent |
| `scripts/discord_gateway_healthcheck.sh` | fork-added | Health check for `discord_gateway.py` process. Verifies PID alive, WebSocket connected, last heartbeat within threshold. Used by watcher_supervisor. | Keep fork — no upstream equivalent |
| `scripts/discord_notify.py` | fork-added | Sends notifications to Discord channel. Supports embeds, mentions, and priority-based channel routing. Companion to `discord_gateway.py` (outbound vs inbound). | Keep fork — no upstream equivalent |
| `scripts/discord_to_ntfy.py` | fork-added | Bridges Discord DM events to ntfy topics. Converts Discord message format to ntfy payload with appropriate tags and priority. | Keep fork — no upstream equivalent |
| `scripts/gas_push_oauth.sh` | fork-added | `clasp push` wrapper using OAuth flow. Validates `.clasprc.json` freshness before push. Falls back to error with RAPT reauth guidance on token expiry. | Keep fork — no upstream equivalent |
| `scripts/gas_push_sa.sh` | fork-added | `clasp push` wrapper using Service Account. Alternative to OAuth for environments where interactive login is impossible. Reads SA key from `projects/` (git-ignored). | Keep fork — no upstream equivalent |
| `scripts/gas_run.sh` | fork-added | `clasp run` wrapper: executes GAS function remotely and captures output. Used for automated GAS verification workflows. | Keep fork — no upstream equivalent |
| `scripts/gas_run_oauth.sh` | fork-added | `clasp run` with OAuth credentials. Same as `gas_run.sh` but uses OAuth token instead of SA key. | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Sends messages to Google Chat space via webhook URL. Supports card format and thread replies. Third notification channel alongside ntfy and Discord. | Keep fork — no upstream equivalent |
| `scripts/generate_dashboard_md.py` | fork-added | Renders `dashboard.yaml` → `dashboard.md`. Supports `--mode partial` (ACTION_REQUIRED only) and full render. Handles tag taxonomy (🔄/✅/🚨/🐸/📊), section ordering, emoji prefixes. Central piece of dashboard pipeline. | Keep fork — no upstream equivalent |
| `scripts/generate_notion_summary.sh` | fork-added | Generates Notion-formatted summary from dashboard state. Used for cross-platform reporting when Notion DB sync is needed. | Keep fork — no upstream equivalent |
| `scripts/get_context_pct.sh` | fork-added | Returns current Claude Code context window usage percentage. Reads from conversation metadata. Used by statusline, compact_observer, and context management hooks. | Keep fork — no upstream equivalent |
| `scripts/gha_failure_check.sh` | fork-added | GitHub Actions failure API polling monitor (cmd_690). Queries `gh api` for 9 repos defined in `config/gha_monitor_targets.yaml`. Filters active workflows + primary events (schedule/push) over 30-day lookback. Outputs JSON with red/green status per repo. Integrates with `repo_health_check.sh`. | Keep fork — no upstream equivalent |
| `scripts/git-hooks/post-commit` | fork-added | Post-commit hook: triggers `sync_shogun_skills.sh` to propagate skill file changes to `~/.claude/skills/`. Ensures skill symlinks stay fresh after every commit. | Keep fork — no upstream equivalent |
| `scripts/git-hooks/pre-commit-dashboard` | fork-added | Pre-commit hook for dashboard files: runs `dashboard_lint.py` and `build_instructions.sh` freshness check. Blocks commits with stale generated instructions or malformed dashboard. | Keep fork — no upstream equivalent |
| `scripts/gunshi_self_clear_check.sh` | fork-added | Gunshi-specific variant of `self_clear_check.sh`. Checks C1-C4 conditions + Gunshi-specific QC queue state before allowing /clear. | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | IR-1 PreToolUse hook: restricts which files each agent role can edit. Whitelist-based with glob pattern support. Prevents ashigaru from editing instructions/*.md or config files. | Keep fork — no upstream equivalent |
| `scripts/hooks/karo_session_start_check.sh` | fork-added | Karo SessionStart hook: verifies dispatch queue state and pending task assignments before Karo begins work. Prevents starting with stale dispatch context. | Keep fork — no upstream equivalent |
| `scripts/hooks/post_compact_dispatch_restore.sh` | fork-added | PostCompact hook for Karo: restores dispatch state from `queue/snapshots/karo_dispatch.yaml` after auto-compact. Prevents lost task assignments (Issue #32). | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_dispatch_persist.sh` | fork-added | PreCompact hook for Karo: saves active dispatch state to snapshot before compaction. Paired with `post_compact_dispatch_restore.sh`. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | PreCompact hook (all agents): calls `context_snapshot.sh write` to persist current work state before auto-compact triggers. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_push_difference_check.sh` | fork-added | Pre-push hook: validates `difference.md` freshness. Warns if fork diff has changed significantly since last generation. | Keep fork — no upstream equivalent |
| `scripts/inbox_watcher.sh` | fork-modified | Core inbox delivery daemon. Fork adds: flock-based atomic reads, overflow protection (50-entry cap), agent-specific routing, tmux send-keys wake, retry with backoff on lock contention. | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | Core inbox write utility. Fork adds: message ID uniqueness (UUID), flock retry, special character escaping, directory auto-creation, 50-entry overflow trim. | Merge upstream, preserve fork sections |
| `scripts/install-shogun-discord-service.sh` | fork-added | Installs `discord_gateway.py` as systemd service (`shogun-discord.service`). Copies template, sets environment, enables + starts service. | Keep fork — no upstream equivalent |
| `scripts/install_git_hooks.sh` | fork-added | Installs git hooks from `scripts/git-hooks/` to `.git/hooks/`. Symlinks post-commit and pre-commit-dashboard. Idempotent — safe to re-run. | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | JST timestamp utility. All agents must use this instead of raw `date`. Modes: default (dashboard format), `--yaml` (ISO 8601+09:00), `--date` (date only). Prevents UTC accidents. | Keep fork — no upstream equivalent |
| `scripts/karo_auto_clear.sh` | fork-added | Automated /clear trigger for Karo when idle conditions met. Checks dispatch queue empty + no active tasks + inbox clear before sending /clear via tmux. | Keep fork — no upstream equivalent |
| `scripts/karo_dispatch.sh` | fork-added | Karo's task dispatch engine. Reads `queue/tasks/` assignments, validates preconditions, sends task via inbox_write to target ashigaru/gunshi. Handles priority ordering and dependency checks. | Keep fork — no upstream equivalent |
| `scripts/karo_self_clear_check.sh` | fork-added | Karo-specific /clear safety check. Extends C1-C4 with C5 (dispatch_debt=0): ensures no pending dispatches before clearing context. | Keep fork — no upstream equivalent |
| `scripts/lib/status_check_rules.py` | fork-added | Python library: status check rule definitions for `sh_health_check.sh`. Defines threshold-based rules for agent health indicators (context %, response time, error rate). | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Logs forbidden action violations to `memory/Violation.md`. Records agent_id, timestamp, F-rule violated, context. Used by hooks that detect rule breaches. | Keep fork — no upstream equivalent |
| `scripts/n8n_feedback_append.py` | fork-added | Appends feedback entries to n8n feedback system JSON. Part of the suggestion→feedback pipeline (cmd_584). | Keep fork — no upstream equivalent |
| `scripts/notify.sh` | fork-added | Unified notification dispatcher. Routes to ntfy/Discord/gchat based on `config/settings.yaml` channel preferences. Single entry point for all agent notifications. | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | Logs session metadata to Notion DB. Records session start/end, agent_id, cmd_id, token count, compaction events. | Keep fork — no upstream equivalent |
| `scripts/ntfy.sh` | fork-modified | ntfy notification sender. Fork adds: priority mapping, tag-based routing, action buttons, hostname guard for VPS-only execution. | Merge upstream, preserve fork sections |
| `scripts/ntfy_listener.sh` | fork-deleted | ntfy streaming listener deleted in cmd_677. Upstream version streams ntfy messages to inbox; fork replaced this flow with Discord-first notification architecture. | Accept upstream |
| `scripts/ntfy_wsl_template.sh` | fork-added | WSL2-adapted template for ntfy_listener.sh. Adjusted paths and environment variables for Windows Subsystem for Linux dual-environment. | Keep fork — no upstream equivalent |
| `scripts/qc_auto_check.sh` | fork-added | Gunshi auto-QC engine. Validates task YAML against `config/qc_checklist.yaml` (SO-01 through SO-24). Returns PASS/WARN/FAIL/SKIP per rule. Self-triggered without Karo assignment. | Keep fork — no upstream equivalent |
| `scripts/ratelimit_check.sh` | fork-modified | Rate limit checker for notification channels. Fork adds per-channel cooldown tracking, burst detection, and configurable thresholds via `config/settings.yaml`. | Merge upstream, preserve fork sections |
| `scripts/repo_health_check.sh` | fork-added | Hourly repository health monitor. Checks git status, CI state (now including GHA via `gha_failure_check.sh`), dependency freshness, test pass rate across configured repos. Writes results to dashboard. | Keep fork — no upstream equivalent |
| `scripts/role_context_notify.sh` | fork-added | Notifies agents of role-relevant context changes. Watches instruction files and config for modifications, sends inbox alert to affected agents. | Keep fork — no upstream equivalent |
| `scripts/safe_clear_check.sh` | fork-added | Universal /clear safety gate. Checks C1 (inbox=0), C2 (in_progress=0), C3 (dispatch_debt=0 for Karo), C4 (context_policy=clear_between). Returns exit code + human-readable report. | Keep fork — no upstream equivalent |
| `scripts/safe_window_judge.sh` | fork-added | Judges whether current time is within safe operation window. Considers JST business hours, ongoing deployments, and Lord availability. Used before auto-clear and auto-compact decisions. | Keep fork — no upstream equivalent |
| `scripts/self_clear_check.sh` | fork-added | Ashigaru self-clear checker. After task completion, verifies safe to /clear (no pending inbox, task done, report submitted). Triggers actual /clear via tmux if conditions met. | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Sends test emails for n8n Gmail workflow E2E testing. Generates unique subject lines for trigger matching. Part of test self-sufficiency rule. | Keep fork — no upstream equivalent |
| `scripts/session_start_checklist.sh` | fork-added | Validates session start procedure completion. Checks: agent_id identified, memory loaded, instructions read, inbox processed. Returns checklist status for hook verification. | Keep fork — no upstream equivalent |
| `scripts/session_start_hook.sh` | fork-deleted | SessionStart hook deleted from fork. Previously injected Session Start procedure as additionalContext on startup/resume/clear/compact. Functionality superseded by revised session start flow. | Accept upstream |
| `scripts/session_to_obsidian.sh` | fork-added | Exports session data to Obsidian vault format. Converts YAML session logs to markdown notes with backlinks and tags. | Keep fork — no upstream equivalent |
| `scripts/sh_health_check.sh` | fork-added | Shell-level health check for shogun system. Validates tmux sessions, agent processes, watcher daemons, disk space, and system resource usage. | Keep fork — no upstream equivalent |
| `scripts/shc.sh` | fork-added | Shogun Health Check CLI. Wraps `sh_health_check.sh` + `repo_health_check.sh` with `deploy` subcommand for pre-shutsujin validation. Human-friendly output with color coding. | Keep fork — no upstream equivalent |
| `scripts/shogun-discord.service.template` | fork-added | Systemd service template for `discord_gateway.py`. Defines ExecStart, environment variables, restart policy, and logging configuration. | Keep fork — no upstream equivalent |
| `scripts/shogun_context_notify.sh` | fork-added | Shogun-specific context change notifier. Alerts Shogun when dashboard state changes require attention (new Action Required items, stale progress). | Keep fork — no upstream equivalent |
| `scripts/shogun_in_progress_monitor.sh` | fork-added | Monitors 🔄進行中 section for stale items. Alerts Shogun when tasks exceed expected duration without progress updates. Prevents silent stalls. | Keep fork — no upstream equivalent |
| `scripts/shogun_inbox_notifier.sh` | fork-added | Bridges Shogun inbox events to ntfy/Discord. Watches `queue/inbox/shogun.yaml` for new entries and sends external notification. Ensures Lord sees urgent items even when not at terminal. | Keep fork — no upstream equivalent |
| `scripts/shogun_reality_check.sh` | fork-added | Shogun reality check: cross-references dashboard claims against actual YAML state. Detects dashboard drift (items marked done but task YAML still in_progress). | Keep fork — no upstream equivalent |
| `scripts/shp.sh` | fork-added | Shogun SHP (Sengoku Headquarters Protocol) CLI. Positional commands for formation display, retreat, advance. Agent-facing operational command interface. | Keep fork — no upstream equivalent |
| `scripts/skill_create_with_symlink.sh` | fork-added | Creates new SKILL.md file and symlinks it to `~/.claude/skills/`. Handles directory creation, git add, and `skill_candidates.yaml` status update. Standard skill creation entry point. | Keep fork — no upstream equivalent |
| `scripts/slim_yaml.py` | fork-modified | YAML slimmer: strips comments and blank lines for token-efficient loading. Fork adds support for multi-document YAML and preserves front-matter boundaries. | Merge upstream, preserve fork sections |
| `scripts/so24_verify.sh` | fork-added | SO-24 verification script: after Shogun instructs Karo and before reporting to Lord, verifies inbox delivery + artifact existence + content match. Prevents premature completion reports. | Keep fork — no upstream equivalent |
| `scripts/start_discord_bot.sh` | fork-added | Discord bot starter script. Sets environment from `config/discord_bot.env.sample`, activates venv, launches `discord_gateway.py` with logging. | Keep fork — no upstream equivalent |
| `scripts/statusline_with_counter.sh` | fork-added | Tmux statusline generator with counter display. Shows agent context %, active cmd count, streak counter from `counter_coefficients.yaml`. | Keep fork — no upstream equivalent |
| `scripts/stop_hook_daily_log.sh` | fork-added | Stop hook: writes daily session summary to `logs/`. Records commands executed, errors encountered, and time spent. | Keep fork — no upstream equivalent |
| `scripts/stop_hook_inbox.sh` | fork-modified | Stop hook: processes remaining inbox items on session end. Fork adds graceful shutdown sequencing — delivers pending messages before session terminates. | Merge upstream, preserve fork sections |
| `scripts/suggestion_db.py` | fork-added | SQLite-backed suggestion database. Stores Gunshi QC suggestions with vector embeddings for deduplication. Companion to `suggestion_vectorize.py`. | Keep fork — no upstream equivalent |
| `scripts/suggestion_vectorize.py` | fork-added | Vectorizes suggestion text for semantic deduplication. Uses sentence embeddings to detect near-duplicate QC suggestions before appending to `queue/suggestions.yaml`. | Keep fork — no upstream equivalent |
| `scripts/suggestions_digest.sh` | fork-added | Generates weekly digest of accumulated suggestions. Groups by priority and category, produces summary for Shogun review. | Keep fork — no upstream equivalent |
| `scripts/switch_cli.sh` | fork-modified | CLI switcher: updates `settings.yaml` CLI section (model, cli_type, thinking toggle). Fork rewrites `update_settings_yaml()` with line-by-line parser preserving `formations` and comments. (cmd_448) | Merge upstream, preserve fork sections |
| `scripts/sync_shogun_skills.sh` | fork-added | Post-commit hook target: syncs `skills/*/SKILL.md` to `~/.claude/skills/` via symlinks. Ensures skill changes in repo are immediately available to Claude Code. | Keep fork — no upstream equivalent |
| `scripts/test_dashboard_roundtrip.py` | fork-added | Dashboard roundtrip test: YAML→MD→parse→compare. Verifies `generate_dashboard_md.py` output can be round-tripped without data loss. | Keep fork — no upstream equivalent |
| `scripts/tests/cmd_598_dispatch_test.sh` | fork-added | Integration test for Karo dispatch flow (cmd_598). Validates task assignment, inbox delivery, and acknowledgment sequence. | Keep fork — no upstream equivalent |
| `scripts/tests/test_qc_auto_check_so23.sh` | fork-added | SO-23 specific tests for `qc_auto_check.sh`. Uses fixture YAML files (fixture_a through fixture_e) to validate resource_completion rule logic. | Keep fork — no upstream equivalent |
| `scripts/update_dashboard.sh` | fork-added | Dashboard updater: partial-replace strategy for `dashboard.md`. Updates 🔄進行中/🏯待機中/最終更新/📊運用指標 sections while preserving hand-written ✅戦果/🚨要対応/🐸Frog sections. | Keep fork — no upstream equivalent |
| `scripts/update_dashboard_timestamp.sh` | fork-added | Updates 最終更新 timestamp in dashboard.md using `jst_now.sh`. Atomic write with temp file + mv. | Keep fork — no upstream equivalent |
| `scripts/validate_ashigaru_report.py` | fork-added | Shift-left validator: checks ashigaru report YAML against `config/schemas/ashigaru_report_schema.yaml`. Enforces required fields, status enum, timestamp format. | Keep fork — no upstream equivalent |
| `scripts/validate_idle_members.sh` | fork-added | Validates idle agent detection. Cross-references tmux pane state with task YAML to find truly idle agents (vs agents in /clear recovery). | Keep fork — no upstream equivalent |
| `scripts/validate_karo_task.py` | fork-added | Shift-left validator: checks Karo task YAML against `config/schemas/shogun_to_karo_schema.yaml`. Enforces decomposition_hint, output_path, priority fields. | Keep fork — no upstream equivalent |
| `scripts/watcher_supervisor.sh` | fork-modified | Supervises long-running watcher processes (inbox_watcher, discord_gateway). Fork adds: PID tracking, health check integration, automatic restart on crash, Discord-specific monitoring. | Merge upstream, preserve fork sections |
| `scripts/worktree_cleanup.sh` | fork-added | Cleans up stale git worktrees. Removes worktrees older than threshold with safety checks (no uncommitted changes). | Keep fork — no upstream equivalent |
| `scripts/worktree_create.sh` | fork-added | Creates isolated git worktrees for parallel agent work. Prevents RACE-001 concurrent file write conflicts by giving each agent its own working directory. | Keep fork — no upstream equivalent |
| `scripts/README_SA_SETUP.md` | fork-added | Setup guide for Google Service Account authentication on VPS. Covers GCP project creation, SA key generation, `clasp` configuration with SA credentials. | Keep fork — no upstream equivalent |

---

## Category B: Library Files

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `lib/agent_status.sh` | fork-modified | Agent status detection library. Fork adds: Codex CLI detection (`is_codex_running()`), context % lookup via `get_context_pct.sh`, pane metadata read (`tmux display -p '#{@agent_id}'`), idle detection heuristics. | Merge upstream, preserve fork sections |
| `lib/cli_adapter.sh` | fork-modified | CLI adapter abstraction. `build_cli_command()` generates correct invocation per CLI type (claude, codex, kimi). Fork adds: `--effort` flag support, `get_cli_type()` key reading, backward compat for missing `cli` section in settings.yaml. | Merge upstream, preserve fork sections |

---

## Category C: Agent Instructions

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `instructions/ashigaru.md` | fork-modified | Ashigaru role instructions. Fork adds: Self Clear Protocol, F004 polling prohibition, context_snapshot integration, report YAML schema compliance, Agent() tool usage accounting, GUI verification protocol, worktree support. | Merge upstream, preserve fork sections |
| `instructions/codex-ashigaru.md` | fork-added | Codex CLI variant of ashigaru instructions. Adapted for Codex execution model (no Task tool, no Memory MCP, exec mode limitations). References `instructions/ashigaru.md` as canonical source. | Keep fork — no upstream equivalent |
| `instructions/common/artifact_registration.md` | fork-added | Artifact registration protocol: Notion DB + Drive workflow. Defines responsibility matrix (karo=output_path+AR trigger, ashigaru=path compliance, gunshi=QC, shogun=YAML inclusion). File naming: `cmd_{N}_{slug}.md`. | Keep fork — no upstream equivalent |
| `instructions/common/batch_processing.md` | fork-added | Batch processing protocol for 30+ item datasets. Mandates batch1 QC gate, quality template with web search requirement, 30-items/session cap, skip detection patterns for resume. | Keep fork — no upstream equivalent |
| `instructions/common/compact_exception.md` | fork-added | Compact exception rules for `preserve_across_stages` tasks. Defines when compaction must be suppressed to maintain multi-stage cmd context continuity. | Keep fork — no upstream equivalent |
| `instructions/common/compaction_recovery.md` | fork-added | Post-compaction recovery procedure. Steps: re-read instructions → restore persona/speech_style → check snapshot → verify task YAML match → write context_snapshot.sh. | Keep fork — no upstream equivalent |
| `instructions/common/context_management.md` | fork-added | Context management policy. Threshold ladder: 50% normal → 70% WARN → 80% RE_CHECK → 85% FORCE /compact → 92% LIMIT. /clear safety conditions C1-C4. | Keep fork — no upstream equivalent |
| `instructions/common/context_snapshot.md` | fork-added | Context snapshot specification. Defines write triggers (task start, important decisions, blockers), YAML schema, read/write via `scripts/context_snapshot.sh`. | Keep fork — no upstream equivalent |
| `instructions/common/dashboard_responsibility_matrix.md` | fork-added | Dashboard update responsibility matrix. Karo=primary updater, Gunshi=QC insert, Shogun=🔄 verify only, Ashigaru=forbidden. Prevents dashboard write conflicts. | Keep fork — no upstream equivalent |
| `instructions/common/destructive_safety.md` | fork-added | Destructive operation safety tiers. Tier 1 ABSOLUTE BAN (rm -rf /, force push, sudo), Tier 2 STOP-AND-REPORT (10+ file delete, unknown URLs), Tier 3 SAFE DEFAULTS (realpath check, dry-run first). WSL2-specific Windows directory protection. | Keep fork — no upstream equivalent |
| `instructions/common/forbidden_actions.md` | fork-modified | Centralised F-rule reference for all agents. Common: F004 (polling), F005 (context skip), F006a (generated file direct edit), F007 (unapproved push). Shogun/Karo/Ashigaru role-specific F001-F003. Single source of truth replacing scattered inline definitions. | Merge upstream, preserve fork sections |
| `instructions/common/gui_verification.md` | fork-added | GUI verification protocol for tkinter apps. WSL2 cannot run tkinter — sets `gui_review_required`/`manual_verification_required` in task YAML, compensates with Gunshi review + Lord verification. | Keep fork — no upstream equivalent |
| `instructions/common/hook_e2e_testing.md` | fork-added | Hook E2E testing checklist. Covers PreToolUse/PostToolUse/SessionStart/Stop hook verification procedures with expected outcomes. | Keep fork — no upstream equivalent |
| `instructions/common/memory_policy.md` | fork-added | Memory storage policy. Layer 1: `memory/global_context.md` (git-managed learning notes). Layer 2: Memory MCP (preferences, decisions). Prohibits writing to MEMORY.md (Claude Code auto-memory). | Keep fork — no upstream equivalent |
| `instructions/common/n8n_e2e_protocol.md` | fork-added | n8n E2E test protocol. Defines `send_test_email.py` → trigger → execution verification flow. API-based result checking via `GET /api/v1/executions/{id}?includeData=true`. | Keep fork — no upstream equivalent |
| `instructions/common/protocol.md` | fork-modified | Communication protocol specification: file-based mailbox via `inbox_write.sh`, delivery by `inbox_watcher.sh`, agents never call tmux send-keys directly. Includes usage examples for shogun→karo, ashigaru→karo, karo→ashigaru flows. | Merge upstream, preserve fork sections |
| `instructions/common/self_watch_phase.md` | fork-added | Self-watch phase protocol. Defines post-deployment monitoring period where agents verify their own output quality before reporting completion. | Keep fork — no upstream equivalent |
| `instructions/common/shogun_mandatory.md` | fork-added | Shogun mandatory rules (SO-01 through SO-24). Dashboard ownership, chain of command, report checking, Karo state verification, skill candidate pipeline, stall response, north star alignment, bug fix issue tracking, decomposition_hint, verification before report. | Keep fork — no upstream equivalent |
| `instructions/common/worktree.md` | fork-added | Git worktree usage guide for parallel agent work. Documents `worktree_create.sh`/`worktree_cleanup.sh` and RACE-001 conflict avoidance strategy. | Keep fork — no upstream equivalent |
| `instructions/generated/ashigaru.md` | fork-modified | Generated ashigaru instructions (default CLI). Built by `build_instructions.sh` from `instructions/roles/ashigaru_role.md` + common modules. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-ashigaru.md` | fork-modified | Generated ashigaru instructions for Codex CLI. Includes Codex-specific limitations section (no Task tool, no Memory MCP). | Merge upstream, preserve fork sections |
| `instructions/generated/codex-gunshi.md` | fork-modified | Generated gunshi instructions for Codex CLI. Includes Codex-specific limitations and QC auto-trigger adaptations. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-karo.md` | fork-modified | Converted from full 920-line file to symlink → `../karo.md`. Upstream had standalone generated file; fork replaces with symlink to canonical source to prevent drift. Recent rebuild converted symlink back to full file. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-shogun.md` | fork-modified | Generated shogun instructions for Codex CLI. Includes Codex-specific limitations and command delegation adaptations. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-ashigaru.md` | fork-modified | Generated ashigaru instructions for Copilot CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-gunshi.md` | fork-modified | Generated gunshi instructions for Copilot CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-karo.md` | fork-modified | Generated karo instructions for Copilot CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-shogun.md` | fork-modified | Generated shogun instructions for Copilot CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/gunshi.md` | fork-modified | Generated gunshi instructions (default CLI). Built from `instructions/roles/gunshi_role.md` + common modules. | Merge upstream, preserve fork sections |
| `instructions/generated/karo.md` | fork-modified | Generated karo instructions (default CLI). Built from `instructions/roles/karo_role.md` + common modules. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-ashigaru.md` | fork-modified | Generated ashigaru instructions for Kimi CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-gunshi.md` | fork-modified | Generated gunshi instructions for Kimi CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-karo.md` | fork-modified | Generated karo instructions for Kimi CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-shogun.md` | fork-modified | Generated shogun instructions for Kimi CLI variant. | Merge upstream, preserve fork sections |
| `instructions/generated/shogun.md` | fork-modified | Generated shogun instructions (default CLI). Built from canonical sources. | Merge upstream, preserve fork sections |
| `instructions/gunshi.md` | fork-modified | Gunshi (strategist) role instructions. Fork adds: auto-QC self-trigger, north_star 3-point check (SO-17), suggestion pipeline integration, QC checklist YAML reference, batch processing QC role, critical thinking enforcement. | Merge upstream, preserve fork sections |
| `instructions/karo.md` | fork-modified | Karo (chief retainer) role instructions. Fork adds: 11-step dispatch workflow, task decomposition with RACE-001 awareness, E2E test ownership, artifact registration trigger (Step 11.8), dispatch persistence for compaction survival, context management thresholds. | Merge upstream, preserve fork sections |
| `instructions/roles/ashigaru_role.md` | fork-modified | Ashigaru role definition (canonical source for generated variants). Fork extends with self-clear protocol, Agent() tool accounting, report schema compliance, and GUI verification references. | Merge upstream, preserve fork sections |
| `instructions/roles/gunshi_role.md` | fork-modified | Gunshi role definition (canonical source). Fork extends with auto-QC trigger, north_star check, suggestion pipeline, batch QC gate responsibilities. | Merge upstream, preserve fork sections |
| `instructions/roles/karo_role.md` | fork-modified | Karo role definition (canonical source). Fork extends with dispatch workflow, RACE-001 decomposition, AR trigger, compaction dispatch persistence. | Merge upstream, preserve fork sections |
| `instructions/shogun.md` | fork-modified | Shogun (commander) role instructions. Fork adds: SO-01 through SO-24 mandatory rules, Pattern A/B environment branching, /clear recovery procedure, dashboard tag taxonomy, counter_increment tracking, F006/F007 rules, Batch Processing Protocol, Critical Thinking Rules, Self Clear Protocol, GUI Verification Protocol, n8n E2E Protocol. | Manual merge required |
| `instructions/skill_candidates.yaml` | fork-added | Skill candidate registry: tracks SC-xxx entries from dashboard with status (pending/evaluating/promoted/rejected), evaluation scores, and promotion target. Source of truth for skill pipeline. | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Skill management policy: evaluation criteria (usefulness/generality/independence 3-axis), promotion workflow (candidate→design doc→SKILL.md→symlink), periodic stocktake schedule. | Keep fork — no upstream equivalent |

---

## Category D: Configuration

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.claude/settings.json` | fork-modified | Claude Code settings. Fork adds: hook definitions (PreToolUse/PostToolUse/SessionStart/Stop), `allowedTools` whitelist, `alwaysThinkingEnabled`, model preferences, compaction triggers. | Manual merge required |
| `.githooks/pre-commit` | fork-added | Pre-commit hook: runs `build_instructions.sh --check` to verify generated instruction freshness. Blocks commit if generated files are stale vs canonical sources. | Keep fork — no upstream equivalent |
| `.github/copilot-instructions.md` | fork-modified | GitHub Copilot instructions. Fork adds shogun-specific context: agent roles, sengoku terminology, YAML schema references. | Merge upstream, preserve fork sections |
| `.github/workflows/upstream-sync.yml` | fork-added | GitHub Actions workflow: scheduled upstream sync. Fetches upstream/main, creates PR if diverged. Enables periodic integration without manual fetch. | Keep fork — no upstream equivalent |
| `.gitignore` | fork-modified | Fork adds: `projects/` (secrets), `queue/snapshots/`, `queue/inbox/`, `logs/*.log`, `logs/gha_*`, `.clasprc.json`, `config/*.env`, dashboard operational state files, GHA monitor output whitelist. | Merge upstream, preserve fork sections |
| `config/bypass_log.yaml` | fork-added | Logs instances where safety checks were bypassed (with justification). Audit trail for Tier 2 destructive operations that proceeded after explicit approval. | Keep fork — no upstream equivalent |
| `config/counter_coefficients.yaml` | fork-added | Counter coefficients for dashboard metrics. Defines streak multipliers, cmd weight factors, and agent productivity scoring parameters. | Keep fork — no upstream equivalent |
| `config/discord.env.sample` | fork-added | Sample environment file for Discord integration. Template for `DISCORD_TOKEN`, `DISCORD_CHANNEL_ID`, `DISCORD_WEBHOOK_URL`. Actual values in git-ignored `.env`. | Keep fork — no upstream equivalent |
| `config/discord_bot.env.sample` | fork-added | Sample environment file for Discord bot. Template for bot-specific settings: `BOT_TOKEN`, `GUILD_ID`, `DM_ALLOWED_USERS`. | Keep fork — no upstream equivalent |
| `config/gha_monitor_targets.yaml` | fork-added | GitHub Actions failure monitoring targets (cmd_690). Defines 9 repos with lookback_days=30, primary_events=[schedule,push], manual_events=[workflow_dispatch], red_conclusions=[failure,timed_out,action_required]. Used by `gha_failure_check.sh`. | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Project registry: maps project names to external repo paths, GAS script IDs, n8n workflow IDs. Central reference for cross-project operations. | Keep fork — no upstream equivalent |
| `config/qc_checklist.yaml` | fork-added | QC checklist: SO-01 through SO-24 rules with check_type, severity, applicability conditions. Machine-readable rules consumed by `qc_auto_check.sh`. | Keep fork — no upstream equivalent |
| `config/repo_health_targets.yaml` | fork-added | Repository health check targets. Lists repos with expected CI status, test coverage thresholds, and dependency freshness requirements. | Keep fork — no upstream equivalent |
| `config/schemas/ashigaru_report_schema.yaml` | fork-added | YAML schema for ashigaru report validation. Required fields: task_id, status, agent_id, started_at, summary. Status enum: in_progress/completed/blocked/failed. | Keep fork — no upstream equivalent |
| `config/schemas/shogun_to_karo_schema.yaml` | fork-added | YAML schema for Shogun→Karo task assignment. Required fields: cmd_id, title, decomposition_hint, priority, output_path. Enforced by `validate_karo_task.py`. | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Central settings: language, screenshot path, capability_tiers (Bloom routing), CLI config (model/type/effort), notification channels, health check thresholds. Single source for all agent configuration. | Keep fork — no upstream equivalent |
| `config/sh_health_targets.yaml` | fork-added | Shell health check targets. Defines thresholds for disk space, process count, tmux session health, memory usage. Used by `sh_health_check.sh`. | Keep fork — no upstream equivalent |
| `config/streaks_format.yaml` | fork-added | Streak display format configuration. Defines how consecutive success counts are rendered in dashboard (emoji thresholds, counter reset rules). | Keep fork — no upstream equivalent |
| `templates/karo_task_template.yaml` | fork-added | Karo task YAML template. Pre-filled structure with all required fields per `shogun_to_karo_schema.yaml`. Copy-paste starting point for new task assignments. | Keep fork — no upstream equivalent |

---

## Category E: Documentation & Memory

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `AGENTS.md` | fork-modified | Agent documentation. Fork adds: tmux pane map, Bloom routing table, CLI variant matrix (Claude/Codex/Copilot/Kimi), formation definitions, agent capability levels. | Merge upstream, preserve fork sections |
| `CHANGELOG.md` | fork-modified | Fork changelog. Tracks cmd_xxx entries, incident reports, and system evolution. Upstream may have separate changelog entries. | Merge upstream, preserve fork sections |
| `CLAUDE.md` | fork-modified | Core project instructions (auto-loaded by Claude Code). Fork adds: Pattern A/B environment branching, snapshot system, Gunshi auto-QC, SO-16 through SO-24, F006/F007, Batch Processing Protocol, Critical Thinking Rules, Self Clear Protocol, GUI Verification Protocol, n8n E2E Protocol, counter_increment tracking, dashboard tag taxonomy, forbidden_actions centralisation, dashboard_responsibility_matrix, destructive safety tiers, GHA failure monitoring. Highest-risk merge target — both sides actively modify. | Manual merge required |
| `README.md` | fork-modified | Project README. Fork adds: VPS deployment instructions, dual-environment (VPS+WSL2) setup, notification channel configuration, health check system overview. | Merge upstream, preserve fork sections |
| `README_ja.md` | fork-modified | Japanese README. Same fork additions as README.md, in Japanese. | Merge upstream, preserve fork sections |
| `agents/default/system.md` | fork-modified | Default agent system prompt. Fork adds: sengoku persona enforcement, JST timestamp rule, inbox protocol reference, context management thresholds. | Merge upstream, preserve fork sections |
| `context/gas-mail-manager.md` | fork-added | Project context file for gas-mail-manager (GAS mail automation). Architecture overview, API endpoints, deployment procedure, known issues. Loaded when task has `project: gas-mail-manager`. | Keep fork — no upstream equivalent |
| `context/n8n-operations.md` | fork-added | Project context file for n8n operations. Workflow inventory, credential management, execution monitoring patterns. Loaded when task has `project: n8n-operations`. | Keep fork — no upstream equivalent |
| `difference.md` | fork-added | This file. Fork-vs-upstream analysis with categorized file inventory, change types, intent descriptions, and merge guidance. | Keep fork — no upstream equivalent |
| `docs/DISCORD_BOT_SETUP.md` | fork-added | Discord bot setup guide. Covers: bot creation, token generation, guild permissions, systemd service installation, health check configuration. | Keep fork — no upstream equivalent |
| `docs/agent-routing-baseline.md` | fork-added | Agent routing baseline document. Defines Bloom routing algorithm: capability tier matching, model assignment rules, L1-L5 task complexity levels. | Keep fork — no upstream equivalent |
| `docs/dashboard_schema.json` | fork-added | JSON schema for `dashboard.yaml`. Defines section structure, field types, tag taxonomy. Used by `dashboard_lint.py` for structural validation. | Keep fork — no upstream equivalent |
| `docs/feedback-system-guide.md` | fork-added | Feedback system user guide. Describes suggestion→feedback pipeline: Gunshi QC → `queue/suggestions.yaml` → vectorize → dedup → digest → Shogun review. | Keep fork — no upstream equivalent |
| `docs/shogun_shell_commands.md` | fork-added | Shell command reference for shogun system. Documents `shc.sh`, `shp.sh`, `shutsujin_departure.sh` and other operator-facing CLI tools. | Keep fork — no upstream equivalent |
| `memory/MechanismSuccessLog.md` | fork-added | Success log for mechanism changes. Records which system improvements (hooks, scripts, protocols) achieved their intended effect. Evidence base for future decisions. | Keep fork — no upstream equivalent |
| `memory/Violation.md` | fork-added | Violation log. Records F-rule breaches with timestamp, agent_id, rule violated, context, resolution. Written by `log_violation.sh`. | Keep fork — no upstream equivalent |
| `memory/canonical_rule_sources.md` | fork-added | Canonical rule source registry. Defines authoritative tier: Tier 1 (CLAUDE.md), Tier 2 (instructions/*.md), Tier 3 (generated/*). F006a enforcement reference. | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Skill lifecycle history. Tracks SC-xxx candidate → evaluation → promotion/rejection with dates, evaluator, and rationale. | Keep fork — no upstream equivalent |
| `n8n/feedback-system.json` | fork-added | n8n workflow definition for feedback system. Automated pipeline: email trigger → parse → append to suggestions → notify. Exported from n8n instance. | Keep fork — no upstream equivalent |
| `originaldocs/notification_channels.md` | fork-added | Original documentation for notification channel architecture. Describes ntfy/Discord/gchat channel selection logic and priority-based routing. | Keep fork — no upstream equivalent |

---

## Category F: Output Artifacts

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Skills stocktake: evaluates skill files for compression/consolidation. 530-line evaluation artifact. | Keep fork — no upstream equivalent |
| `output/cmd_594_kpi_verification.md` | fork-added | cmd_594 KPI verification report. Validates dashboard KPI accuracy against raw YAML data. | Keep fork — no upstream equivalent |
| `output/cmd_594_scope_b_qc_report.md` | fork-added | cmd_594 Scope B QC report by Gunshi. Quality assessment of KPI implementation. | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_integrated.md` | fork-added | cmd_611 integrated self-improvement report. Synthesizes research findings into actionable system improvements. | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research.md` | fork-added | cmd_611 self-improvement research. Multi-agent research on system optimization opportunities. | Keep fork — no upstream equivalent |
| `output/cmd_611_self_improvement_research_codex.md` | fork-added | cmd_611 self-improvement research (Codex variant). Same research scope executed via Codex CLI for comparison. | Keep fork — no upstream equivalent |
| `output/cmd_658_phase01_report.md` | fork-added | cmd_658 Phase 1 report. Initial implementation phase deliverable. | Keep fork — no upstream equivalent |
| `output/cmd_658_phase2_report.md` | fork-added | cmd_658 Phase 2 report. Second implementation phase deliverable. | Keep fork — no upstream equivalent |
| `output/cmd_659_implementation_report.md` | fork-added | cmd_659 implementation report. Action Required Pipeline (Scope E) + dashboard observation queue implementation details. | Keep fork — no upstream equivalent |
| `output/cmd_659_risk_mitigation_plan.md` | fork-added | cmd_659 risk mitigation plan. Identifies risks in Action Required Pipeline and proposes countermeasures. | Keep fork — no upstream equivalent |
| `output/cmd_660_ash1_role_split_review.md` | fork-added | cmd_660 ashigaru1 role split review. Analysis of role separation effectiveness. | Keep fork — no upstream equivalent |
| `output/cmd_660_ash4_role_split_review.md` | fork-added | cmd_660 ashigaru4 role split review. Analysis of role separation effectiveness (ashigaru4 perspective). | Keep fork — no upstream equivalent |
| `output/cmd_660_ash5_verification_phase3.md` | fork-added | cmd_660 ashigaru5 Phase 3 verification report. | Keep fork — no upstream equivalent |
| `output/cmd_660_ash6_codex_pattern_analysis.md` | fork-added | cmd_660 ashigaru6 Codex pattern analysis. Documents Codex CLI behavior patterns observed during role split testing. | Keep fork — no upstream equivalent |
| `output/cmd_660_ash7_codex_proposal_4_review.md` | fork-added | cmd_660 ashigaru7 Codex Proposal 4 review. Evaluates fourth iteration of Codex integration proposal. | Keep fork — no upstream equivalent |
| `output/cmd_660_gunshi_integrated_strategy.md` | fork-added | cmd_660 Gunshi integrated strategy. Strategist's comprehensive analysis of role split outcomes and recommendations. | Keep fork — no upstream equivalent |
| `output/cmd_660_integrated_report.md` | fork-added | cmd_660 integrated report. Synthesizes all ashigaru + gunshi findings into unified deliverable. | Keep fork — no upstream equivalent |
| `output/cmd_662_shp_command_report.md` | fork-added | cmd_662 SHP command implementation report. Documents `shp.sh` positional command system design and testing. | Keep fork — no upstream equivalent |
| `output/cmd_663_codex_role_compatibility.md` | fork-added | cmd_663 Codex role compatibility analysis. Evaluates which shogun roles can effectively use Codex CLI. | Keep fork — no upstream equivalent |
| `output/cmd_663_integrated.md` | fork-added | cmd_663 integrated report. Synthesizes Codex compatibility + skill analysis findings. | Keep fork — no upstream equivalent |
| `output/cmd_663_skill_codex_compat.md` | fork-added | cmd_663 skill-Codex compatibility matrix. Maps skills to Codex CLI capability gaps. | Keep fork — no upstream equivalent |
| `output/cmd_664_discord_proactive_reaction.md` | fork-added | cmd_664 Discord proactive reaction implementation. Documents Discord bot reaction-based interaction patterns. | Keep fork — no upstream equivalent |
| `output/cmd_665_shp_positional_report.md` | fork-added | cmd_665 SHP positional report. `shp.sh` command positional argument implementation details. | Keep fork — no upstream equivalent |
| `output/cmd_666_shp_retreat_report.md` | fork-added | cmd_666 SHP retreat report. Documents `shp.sh retreat` subcommand for graceful agent shutdown. | Keep fork — no upstream equivalent |
| `output/cmd_667_codex_context_display.md` | fork-added | cmd_667 Codex context display implementation. Documents `codex_context.sh` SQLite-based context % detection. | Keep fork — no upstream equivalent |
| `output/cmd_668_codex_0129_upgrade.md` | fork-added | cmd_668 Codex 0.129.0 upgrade report. Documents breaking changes and migration (logs_2.sqlite → state_5.sqlite). | Keep fork — no upstream equivalent |
| `output/cmd_669_instructions_unification.md` | fork-added | cmd_669 instructions unification report. Documents consolidation of scattered role instructions into `instructions/roles/*.md` canonical sources. | Keep fork — no upstream equivalent |
| `output/cmd_670_missed_cmds.md` | fork-added | cmd_670 missed commands analysis. Identifies commands that were lost or unexecuted due to notification failures. | Keep fork — no upstream equivalent |
| `output/cmd_670_notifier_recovery.md` | fork-added | cmd_670 notifier recovery report. Documents `shogun_inbox_notifier.sh` fix and notification pipeline recovery. | Keep fork — no upstream equivalent |
| `output/cmd_671_codex_context_fix.md` | fork-added | cmd_671 Codex context fix report. Documents v2 fix for `codex_context.sh` after Codex 0.129.0 SQLite schema change. | Keep fork — no upstream equivalent |
| `output/cmd_672_shp_design_unification.md` | fork-added | cmd_672 SHP design unification. Consolidates `shp.sh` command design across formation/retreat/advance subcommands. | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_integrated.md` | fork-added | cmd_673 Scope A integrated report. Shell health visualization implementation. | Keep fork — no upstream equivalent |
| `output/cmd_673_scope_a_opus.md` | fork-added | cmd_673 Scope A Opus analysis. Deep reasoning analysis of shell health architecture by Opus model. | Keep fork — no upstream equivalent |
| `output/cmd_673_sh_health_visualization.md` | fork-added | cmd_673 shell health visualization report. Documents `sh_health_check.sh` dashboard integration and visual indicators. | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_audit.md` | fork-added | cmd_674 skill candidate audit. Reviews all SC-xxx entries for accuracy, duplicates, and promotion readiness. | Keep fork — no upstream equivalent |
| `output/cmd_674_skill_candidate_strict_process.md` | fork-added | cmd_674 strict process enforcement report. Documents tightened skill candidate evaluation criteria. | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_candidate_integration.md` | fork-added | cmd_675 skill candidate integration report. Merges approved candidates into existing SKILL.md files. | Keep fork — no upstream equivalent |
| `output/cmd_675_skill_integration_audit.md` | fork-added | cmd_675 skill integration audit. Post-integration verification of merged skill content quality. | Keep fork — no upstream equivalent |
| `output/cmd_675b_skill_integration_implementation.md` | fork-added | cmd_675b skill integration implementation. Detailed execution log of skill file merges. | Keep fork — no upstream equivalent |
| `output/cmd_676_gas_mail_manager_per_customer_workbook.md` | fork-added | cmd_676 GAS mail manager per-customer workbook. Implementation report for customer-specific spreadsheet generation in gas-mail-manager. | Keep fork — no upstream equivalent |
| `output/cmd_677_sh_warning_consolidation.md` | fork-added | cmd_677 shell warning consolidation. Documents warning message cleanup and `ntfy_listener.sh` removal rationale. | Keep fork — no upstream equivalent |
| `output/cmd_677_tier2_audit.md` | fork-added | cmd_677 Tier 2 audit. Reviews all Tier 2 (STOP-AND-REPORT) operations for compliance. | Keep fork — no upstream equivalent |
| `output/cmd_678_repo_health_check.md` | fork-added | cmd_678 repo health check implementation report. Documents `repo_health_check.sh` design and dashboard integration. | Keep fork — no upstream equivalent |
| `output/cmd_681_dashboard_observation_queue.md` | fork-added | cmd_681 dashboard observation queue. Implements observation queue for tracking dashboard state changes over time. | Keep fork — no upstream equivalent |
| `output/cmd_682_legacy_audit.md` | fork-added | cmd_682 legacy audit. Identifies deprecated scripts, stale config, and dead code across the codebase. | Keep fork — no upstream equivalent |
| `output/cmd_682_skill_legacy_integration.md` | fork-added | cmd_682 skill legacy integration. Merges legacy skill knowledge into current SKILL.md files. | Keep fork — no upstream equivalent |
| `output/cmd_684_repo_health_red_runbook.md` | fork-added | cmd_684 repo health red runbook. Step-by-step remediation guide for each red-status repo health check finding. | Keep fork — no upstream equivalent |
| `output/cmd_690_phase2_api_polling_monitor.md` | fork-added | cmd_690 Phase 2: GHA API polling monitor implementation report. Documents `gha_failure_check.sh` + `gha_monitor_targets.yaml` design, filter logic (active workflow + primary event + 30-day), dashboard integration, and 9-repo verification results. | Keep fork — no upstream equivalent |
| `projects/artifact-standardization/review_cmd519.md` | fork-added | cmd_519 artifact standardization review. Evaluates artifact naming, Notion registration compliance, and Drive folder structure. | Keep fork — no upstream equivalent |
| `projects/skill-triage-cmd521/skill_triage.md` | fork-added | cmd_521 skill candidate triage report by Gunshi: classifies 12 dashboard candidates into 4 categories (new/integrate/CLAUDE.md/reject) with priority and rationale. Includes north_star verification. | Keep fork — no upstream equivalent |

---

## Category G: Tests

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/cmd_544_test.sh` | fork-added | 17 test cases for cmd_squash_pub_hook.sh safety mechanisms: kill-switch (KS-1/2/3), rate-limit (RL-1/2/3 + TTL), daily metric (DM-1/2/3/4), integration scenarios (S1/S2/S5/S7), sug_003, supervisor restart. Uses jst_now.sh stub for deterministic time. | Keep fork — no upstream equivalent |
| `tests/dashboard_pipeline_test.sh` | fork-added | 6-group integration test for Action Required Pipeline (cmd_659 Scope E + cmd_681): E-1 unit+golden, E-2 integration (gunshi→dashboard.md in 5min), E-3 concurrency (10 parallel x 100 cycles), E-4 文言整合, E-5 AUTO_CMD key coexistence, E-6 rotate regression. | Keep fork — no upstream equivalent |
| `tests/dashboard_update_preserve_test.sh` | fork-added | Regression test (cmd_649 Scope C): verifies `update_dashboard.sh` preserves hand-written sections (✅戦果/🚨要対応/🐸Frog) while correctly updating auto-generated sections (🔄進行中/🏯待機中/最終更新/📊運用指標) via partial-replace. | Keep fork — no upstream equivalent |
| `tests/dim_d_quality_comparison.sh` | fork-modified | Bloom Dimension D quality comparison experiment: runs identical L5 task on Haiku 4.5 vs Sonnet 4.6, scores via Gunshi (Opus). Pass criteria: Sonnet >= 70, Haiku <= 50, delta >= 15. Fork updates test parameters and scoring thresholds. | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_bloom_routing.bats` | fork-modified | Adds `setup()` guard: skips suite when `capability_tiers` absent from settings. Prevents false failures in unconfigured environments. | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_codex_startup.bats` | fork-modified | Minor formatting/whitespace changes. No functional modification. | Accept upstream changes |
| `tests/qc_auto_check/.gitkeep` | fork-added | Directory placeholder for `tests/qc_auto_check/` fixture directory. | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_a.yaml` | fork-added | SO-23 test fixture A: `resource_completion` 5-field complete → expected PASS. | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_b.yaml` | fork-added | SO-23 test fixture B: scenario for expected WARN disposition. | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_c.yaml` | fork-added | SO-23 test fixture C: scenario for expected FAIL disposition. | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_d.yaml` | fork-added | SO-23 test fixture D: non-n8n task → expected SKIP (SO-23 not applicable). | Keep fork — no upstream equivalent |
| `tests/qc_auto_check/fixture_e.yaml` | fork-added | SO-23 test fixture E: additional edge case scenario. | Keep fork — no upstream equivalent |
| `tests/specs/dynamic_model_routing_spec.md` | fork-modified | Dynamic Model Routing test specification (DMR-SPEC-001). Covers Phase 1-4 TDD test-first approach for FR/NFR from requirements doc. Fork updates spec references and test IDs. | Merge upstream, preserve fork sections |
| `tests/test_artifact_register.sh` | fork-added | 3-case unit tests for artifact_register.sh: validates argument parsing, dry-run output, and error handling with expected exit codes. | Keep fork — no upstream equivalent |
| `tests/test_inbox_write.bats` | fork-modified | 12-case BATS unit tests (T-001~T-012) for inbox_write.sh: argument validation, normal write (new/append), message ID uniqueness, default values, overflow protection (50-entry limit), flock retry, special character escaping, directory auto-creation. Fork updates test assertions for revised inbox_write behavior. | Merge upstream, preserve fork sections |
| `tests/unit/test_cli_adapter.bats` | fork-modified | Unit tests for cli_adapter.sh: validates `build_cli_command()` with effort field, `get_cli_type()` key reading, backward compatibility with missing cli section. Fork updates fixtures for revised CLI adapter. | Merge upstream, preserve fork sections |
| `tests/unit/test_dashboard_timestamp.bats` | fork-added | 4 tests (T-DT-001-004) for `update_dashboard_timestamp.sh`: happy path, missing file, format regex, syntax check. Part of JST enforcement. | Keep fork — no upstream equivalent |
| `tests/unit/test_dynamic_model_routing.bats` | fork-modified | Adds tmux mocking around TC-FAM-001-009 tests. Fixes test isolation: real tmux pane data was interfering with `find_agent_for_model()`. | Merge upstream, preserve fork sections |
| `tests/unit/test_ir1_editable_files.bats` | fork-added | 12-case unit tests for IR-1 hook: agent exemptions, whitelist enforcement, implicit allowances, glob patterns. | Keep fork — no upstream equivalent |
| `tests/unit/test_ntfy_ack.bats` | fork-deleted | 8-case unit tests for ntfy ACK auto-reply removed. Tests deleted alongside `ntfy_listener.sh` removal in cmd_677 (notification flow migrated to Discord-first architecture). | Accept upstream |
| `tests/unit/test_send_wakeup.bats` | fork-modified | Extends mock layer: adds MOCK_PANE_PID, MOCK_CLI_RUNNING, MOCK_STAT_MTIME, MOCK_GIT_STATUS + mock functions. Enables testing `is_cli_running()` without real processes. | Merge upstream, preserve fork sections |
| `tests/unit/test_switch_cli.bats` | fork-modified | Unit tests for switch_cli.sh: validates settings.yaml CLI section updates, model switching, and formation preservation. Tests `update_settings_yaml()` line-by-line parser. Fork updates test cases for revised parser. | Merge upstream, preserve fork sections |

---

## Category H: Screenshots & Startup

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `images/screenshots/ntfy_bloom_oc_test.jpg` | fork-added | Binary screenshot: ntfy notification for bloom OC test. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_cmd043_progress.jpg` | fork-added | Binary screenshot: ntfy cmd043 progress notification. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_persona_eval_complete.jpg` | fork-added | Binary screenshot: ntfy persona evaluation completion. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_saytask_rename.jpg` | fork-added | Binary screenshot: ntfy saytask rename notification. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_final.jpg` | fork-added | Binary screenshot: ntfy tasklist final state. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v1_before.jpg` | fork-added | Binary screenshot: ntfy tasklist v1 before state. | Keep fork — no upstream equivalent |
| `images/screenshots/ntfy_tasklist_v2_aligned.jpg` | fork-added | Binary screenshot: ntfy tasklist v2 aligned state. | Keep fork — no upstream equivalent |
| `first_setup.sh` | fork-modified | Initial setup script. Fork adds: JST timezone configuration, git hook installation, Discord service setup, VPS-specific PATH adjustments, notification channel initialization. | Merge upstream, preserve fork sections |
| `shutsujin_departure.sh` | fork-modified | Additions: (1) kessen mode applies Opus to karo with `--effort max`, (2) `tmux set-environment TZ "Asia/Tokyo"`, (3) model display name fix, (4) `--hybrid` flag with mutex check, (5) `shc.sh deploy` pre-apply, (6) `update_dashboard_formation()` auto-update. (cmd_450) | Keep fork — no upstream equivalent |

---

## Category I: Skills

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `skills/codex-context-pane-border/SKILL.md` | fork-added | Codex CLI context usage % in tmux pane-border-format. Documents Codex 0.129.0+ SQLite-based detection pattern (logs_2.sqlite → state_5.sqlite two-step lookup) and `#()` tmux embedding. Born from cmd_671 v2 fix. | Keep fork — no upstream equivalent |
| `skills/pdfmerged-feature-release-workflow/SKILL.md` | fork-added | pdfmerged release workflow skill (386 lines): cmd_495c (docs/TEST_GUIDE.md update leak) incident prevention. A/B/C/D 4-category checklist, change-type x artifact sync matrix, Karo task YAML template, Gunshi QC grep checkpoints, ashigaru report required fields, 26 reference URLs. (cmd_501d) | Keep fork — no upstream equivalent |
| `skills/s-check/SKILL.md` | fork-added | S-check (status check) skill for Shogun. 3-source triangulation (tasks/reports/inbox/tmux/git log) triggered by situation/progress/health-check keywords. Returns 4-block structured report. Prevents silent-success acceptance and blind dashboard trust. | Keep fork — no upstream equivalent |
| `skills/shogun-bash-cross-platform-ci/SKILL.md` | fork-added | Bash cross-platform CI pattern collection: flock BSD fallback, sed -i compatibility, python3 .venv resolution, hostname guard opt-in, SHOGUN_ROOT self-resolve. Born from cmd_532 Phase B (14 test failures across Linux + macOS). | Keep fork — no upstream equivalent |
| `skills/shogun-bloom-config/SKILL.md` | fork-modified | Interactive wizard skill: guided multiple-choice questions about subscriptions, outputs ready-to-paste `capability_tiers` YAML + fixed agent model assignments for Bloom routing setup. Fork updates model list and subscription tiers. | Merge upstream, preserve fork sections |
| `skills/shogun-dashboard-sync-silent-failure-pattern/SKILL.md` | fork-added | Dashboard.yaml → dashboard.md sync silent failure patterns (P1-P5): manual dependency, field name mismatch, rotation bugs, schema validation absence. 4 incident root cause analysis (cmd_607/615/619/agent-assignee mismatch). 3-layer prevention strategy. (cmd_621 Scope B) | Keep fork — no upstream equivalent |
| `skills/shogun-gas-automated-verification/SKILL.md` | fork-added | GAS automated verification on Ubuntu VPS: clasp 3.x OAuth setup, GCP Standard Cloud Project config, `clasp run` + `clasp logs` automation pattern, Logger.log vs console.log compatibility. Battle-tested setup procedure with pitfall documentation. (cmd_567) | Keep fork — no upstream equivalent |
| `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` | fork-added | clasp push RAPT reauth fallback skill. Documents `invalid_rapt`/`invalid_grant` error recovery: Plan A (local `clasp login` → scp `.clasprc.json` to VPS), Plan B (GAS editor direct edit). Includes `clasp_age_check.sh` integration and VPS-specific token refresh limitations. Battle-tested across cmd_486/cmd_564/cmd_565. | Keep fork — no upstream equivalent |
| `skills/shogun-model-list/SKILL.md` | fork-modified | Reference table skill: all AI CLI tools x available models x required subscriptions x Bloom max capability level. Fork updates model entries and capability mappings. | Merge upstream, preserve fork sections |
| `skills/shogun-model-switch/SKILL.md` | fork-modified | Agent CLI live switcher skill: updates settings.yaml, triggers /exit, starts new CLI, updates pane metadata. Supports model, CLI type, and Thinking toggle switching. Fork updates switch procedures for new CLI variants. | Merge upstream, preserve fork sections |
| `skills/skill-creation-workflow/SKILL.md` | fork-added | Standard process for converting skill candidates (SC-xxx) to SKILL.md files. 3-axis evaluation (usefulness/generality/independence), integration vs new decision, SKILL.md scaffold, `skill_candidates.yaml` + `memory/skill_history.md` update, git push via `skill_create_with_symlink.sh`. | Keep fork — no upstream equivalent |

---

## Category J: Operational State & Logs

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `logs/cmd_squash_pub_hook.daily.yaml` | fork-added | Daily metric log for `cmd_squash_pub_hook.sh`. Records per-day trigger count for rate-limit and kill-switch monitoring. | Keep fork — no upstream equivalent |
| `logs/cmd_squash_pub_hook.rate_limit_at` | fork-added | Rate limit timestamp file for `cmd_squash_pub_hook.sh`. Holds last trigger time to enforce 30-min minimum interval. | Keep fork — no upstream equivalent |
| `logs/safe_clear/.gitkeep` | fork-added | Directory placeholder for safe_clear log output. Ensures `logs/safe_clear/` directory exists in git. | Keep fork — no upstream equivalent |
| `queue/external_inbox.yaml` | fork-added | External input mailbox for Discord DM inbound events. Written atomically by `discord_gateway.py` with flock. Read by shogun for `discord_received` events. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru1_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru4_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru5_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/gunshi_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/skill_candidates.yaml` | fork-added | Runtime skill candidate registry (distinct from `instructions/skill_candidates.yaml`). Tracks candidates discovered during task execution awaiting evaluation. | Keep fork — no upstream equivalent |
| `queue/suggestions.yaml` | fork-added | Gunshi QC suggestion accumulation file. Entries from gunshi QC reports with id/status/priority/content/action_needed/cmd_ref/from/created_at fields per `schemas/suggestions_schema.yaml`. | Keep fork — no upstream equivalent |
| `queue/tasks/ashigaru4.yaml` | fork-added | Live task assignment for ashigaru4. Active operational state. | Keep fork — no upstream equivalent |
| `schemas/suggestions_schema.yaml` | fork-added | Schema definition for `queue/suggestions.yaml` entries. Defines required fields (id/status/priority/content/action_needed/cmd_ref/from/created_at), status enum (pending/accepted/deferred/rejected/resolved), priority tiers. (cmd_584 AC6) | Keep fork — no upstream equivalent |

---

## Merge Guidance Summary

| Guidance | Count | Files |
|----------|-------|-------|
| Keep fork — no upstream equivalent | 223 | All fork-added files + fork-specific operational state |
| Merge upstream, preserve fork sections | 54 | `build_instructions.sh`, `inbox_watcher.sh`, `inbox_write.sh`, `ntfy.sh`, `ratelimit_check.sh`, `slim_yaml.py`, `stop_hook_inbox.sh`, `switch_cli.sh`, `watcher_supervisor.sh`, `lib/agent_status.sh`, `lib/cli_adapter.sh`, `AGENTS.md`, `CHANGELOG.md`, `.github/copilot-instructions.md`, `.gitignore`, `README.md`, `README_ja.md`, `agents/default/system.md`, `first_setup.sh`, `instructions/ashigaru.md`, `instructions/gunshi.md`, `instructions/karo.md`, `instructions/common/forbidden_actions.md`, `instructions/common/protocol.md`, `instructions/roles/ashigaru_role.md`, `instructions/roles/gunshi_role.md`, `instructions/roles/karo_role.md`, `instructions/generated/ashigaru.md`, `instructions/generated/codex-ashigaru.md`, `instructions/generated/codex-gunshi.md`, `instructions/generated/codex-karo.md`, `instructions/generated/codex-shogun.md`, `instructions/generated/copilot-ashigaru.md`, `instructions/generated/copilot-gunshi.md`, `instructions/generated/copilot-karo.md`, `instructions/generated/copilot-shogun.md`, `instructions/generated/gunshi.md`, `instructions/generated/karo.md`, `instructions/generated/kimi-ashigaru.md`, `instructions/generated/kimi-gunshi.md`, `instructions/generated/kimi-karo.md`, `instructions/generated/kimi-shogun.md`, `instructions/generated/shogun.md`, `tests/e2e/e2e_bloom_routing.bats`, `tests/dim_d_quality_comparison.sh`, `tests/specs/dynamic_model_routing_spec.md`, `tests/test_inbox_write.bats`, `tests/unit/test_cli_adapter.bats`, `tests/unit/test_dynamic_model_routing.bats`, `tests/unit/test_send_wakeup.bats`, `tests/unit/test_switch_cli.bats`, `skills/shogun-bloom-config/SKILL.md`, `skills/shogun-model-list/SKILL.md`, `skills/shogun-model-switch/SKILL.md` |
| Accept upstream | 5 | `tests/e2e/e2e_codex_startup.bats`, `scripts/dashboard-viewer.py` (fork-deleted), `scripts/ntfy_listener.sh` (fork-deleted), `scripts/session_start_hook.sh` (fork-deleted), `tests/unit/test_ntfy_ack.bats` (fork-deleted) |
| Manual merge required | 3 | `CLAUDE.md` (core config, both sides actively modify), `.claude/settings.json` (hook definitions, both sides modify), `instructions/shogun.md` (core shogun instructions, both sides modify) |

**CLAUDE.md** is the highest-risk merge target: both fork and upstream actively modify this file. On merge, preserve fork's Pattern A/B branch, snapshot system, Gunshi auto-QC, SO-16 through SO-24, F006/F007, Batch Processing Protocol, Critical Thinking Rules, Self Clear Protocol, GUI Verification Protocol, n8n E2E Protocol, counter_increment context tracking, dashboard tag taxonomy, forbidden_actions centralisation, dashboard_responsibility_matrix references, destructive safety tiers, and GHA failure monitoring (cmd_690) while accepting upstream structural/procedural updates.

**Notable changes since last analysis (2026-05-08 → 2026-05-09):**
- **Added**: `config/gha_monitor_targets.yaml`, `scripts/gha_failure_check.sh`, `output/cmd_690_phase2_api_polling_monitor.md` (GHA failure monitoring, cmd_690), `skills/shogun-gas-clasp-rapt-reauth-fallback/SKILL.md` (clasp RAPT recovery skill)
- **Deleted**: `scripts/ntfy_listener.sh`, `tests/unit/test_ntfy_ack.bats` (cmd_677 ntfy listener removal), `scripts/dashboard-viewer.py` (replaced), `scripts/session_start_hook.sh` (superseded)
- **Type corrections**: 18 files previously marked fork-added are now fork-modified (upstream added equivalent files since last analysis)
