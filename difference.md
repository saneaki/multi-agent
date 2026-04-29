# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-04-29
> **Base**: `git diff upstream/main...main` (148 files, +21,029 / −3,591 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: main

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Key architectural themes:

1. **Context resilience** — Snapshot write/clear system for surviving /clear and compaction; pre-compact dispatch persistence for Karo (Issue #32); `compact_exception_check.sh` for preserve_across_stages scenarios
2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment; `qc_auto_check.sh` for schema validation; QC checklist YAML with SO-01 through SO-23
3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents)
4. **Skill management lifecycle** — Candidate tracking, policy, evaluation, promotion pipeline, and periodic stocktake (cmd_390: 16 candidates reviewed, 5 new + 4 integrated); 4 fork-specific skills (bloom-config, model-list, model-switch, bash-cross-platform-ci)
5. **Operational safety** — F006 blind-clear ban, F007 unverified-report ban (SO-20 3-point verification), IR-1 editable-files whitelist guard, SO-19 completion cleanup enforcement, stall response protocol, Agent() tool governance, self-clear mechanism (`self_clear_check.sh` / `karo_self_clear_check.sh` / `gunshi_self_clear_check.sh`), git pre-push difference.md enforcement, destructive operation 3-tier safety, shellcheck pre-commit hook
6. **Notification integration** — ntfy push (with cmd_complete tag) + Discord Bot → ntfy relay (`discord_to_ntfy.py`, systemd service + healthcheck) + Google Chat (`gchat_send.sh`) + Notion session logging. Dual-channel input (ntfy app + Discord DM) unified via ntfy_inbox.yaml. Shogun inbox auto-notifier as safety net.
7. **VPS/WSL2 environment** — Paths, tmux TZ, hostname guards, dual-environment settings
8. **Rule enforcement automation** — Hook-based violation detection (IR-1/IR-2/IR-5), qc_auto_check.sh schema validation, cmd_complete.sh for SO-19 compliance, daily log stop hook, karo SessionStart hook, git pre-push difference.md date check, counter_increment.sh for tool-call tracking with per-agent alpha coefficients
9. **Feedback system** — n8n workflow-based feedback collection, `n8n_feedback_append.py`, agent routing baseline docs, feedback system guide
10. **Context management** — 3-layer standard (/clear > self /compact > auto-compact), safe_clear_check.sh with C1-C4 conditions, role-specific thresholds (50%/70%/80%/85%/92%), counter_increment.sh + counter_coefficients.yaml for context percentage estimation
11. **Multi-CLI generated instructions** — `build_instructions.sh` generates role-specific instruction files for Codex, Copilot, Kimi, and default CLI variants; pre-commit hook enforces generated/ freshness
12. **Squash-pub automation** — `cmd_squash_pub_hook.sh` detects cmd completion in dashboard, triggers squash + pub with 3 safety mechanisms (kill-switch, rate-limit, daily metric)

**Merge strategy**: Most fork files have no upstream equivalent. For files that both fork and upstream modify (CLAUDE.md, instructions/*.md, tests/), manual merge is required — preserve fork sections while accepting upstream structural changes.

---

## Category A: Infrastructure Scripts

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/artifact_register.sh` | fork-added | Registers cmd artifacts to Notion DB + Drive on completion. Accepts `--cmd-id`, `--project`, `--date`, `--files`, `--dry-run`. Uses Notion API v2022-06-28. Called by Karo at Step 11.8. | Keep fork — no upstream equivalent |
| `scripts/cmd_complete_notifier.sh` | fork-added | Watches dashboard.md with inotifywait; sends ntfy push to Lord's phone on new cmd completion. Pre-seeds state to prevent startup flood. | Keep fork — no upstream equivalent |
| `scripts/cmd_squash_pub_hook.sh` | fork-added | Watches dashboard.md for `cmd_NNN COMPLETE` markers; triggers squash + /pub-us. Three safety mechanisms: kill-switch file, rate-limit (30 min default), daily metric logging. (cmd_539/544) | Keep fork — no upstream equivalent |
| `scripts/compact_exception_check.sh` | fork-added | Guards /compact exception usage (cmd_531 Phase 4). Validates 3 AND-conditions: preserve_across_stages cmd in progress, context > 80%, /clear infeasible. Writes snapshot + log on pass. | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | CLI (write/clear/read) to persist agent work-in-progress context to `queue/snapshots/<agent_id>_snapshot.yaml` with flock concurrency. Enables post-compaction recovery. | Keep fork — no upstream equivalent |
| `scripts/counter_increment.sh` | fork-added | PostToolUse hook: increments per-agent tool call counter and estimates context_pct using alpha coefficients from `config/counter_coefficients.yaml`. Transparent stdin passthrough. Graceful degradation on any failure. (cmd_555d) | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Daily midnight JST cron: renames "本日の戦果"→"昨日の戦果", resets streak/frog/completion fields, trims skill section to 5 entries via FIFO archive to `memory/skill_history.md`. | Keep fork — no upstream equivalent |
| `scripts/discord_bot_healthcheck.sh` | fork-added | Cron-based (5 min) healthcheck for Discord Bot systemd user service. Reads ntfy topic from settings.yaml, sends alert on failure with 15 min cooldown dedup. Sets XDG_RUNTIME_DIR for cron context. | Keep fork — no upstream equivalent |
| `scripts/discord_to_ntfy.py` | fork-added | Discord Bot (204 lines): receives DMs from whitelisted users via discord.py, POSTs to ntfy.sh with `[discord]` title prefix. Security: DM-only processing, user ID whitelist, `--dry-run` mode. Uses httpx for HTTP. (cmd_489) | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Google Chat Webhook wrapper (9 lines): sources `.env` for `GCHAT_WEBHOOK_URL`, sends JSON-escaped message via curl, enforces `sleep 5` between calls to avoid 429 rate-limit errors. | Keep fork — no upstream equivalent |
| `scripts/gunshi_self_clear_check.sh` | fork-added | Gunshi-specific self /clear check: verifies task status idle/done, no unread inbox, no preserve_across_stages cmd, tool count threshold exceeded. Logs decision to `/tmp/self_clear_gunshi.log`. | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | PostToolUse hook enforcing IR-1 editable-files whitelist for ashigaru agents. Reads task YAML, resolves globs, implicit allowlist (own inbox, SKILL.md), logs violations via `log_violation.sh`. Non-ashigaru exempt. | Keep fork — no upstream equivalent |
| `scripts/hooks/karo_session_start_check.sh` | fork-added | SessionStart hook (karo-only): checks `$TMUX_PANE` and `agent_id`, outputs environment confirmation + F003 reminder (Agent() deliverable prohibition). Prevents environment misidentification. | Keep fork — no upstream equivalent |
| `scripts/hooks/post_compact_dispatch_restore.sh` | fork-added | PostCompact/SessionStart hook: restores Karo's dispatch debt after compaction. Detects `pre_compact_marker=true` in `karo_pending.yaml`, promotes blocked→assigned subtasks where dependencies are met, notifies Karo inbox. (Issue #32, cmd_535 Phase 4) | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_dispatch_persist.sh` | fork-added | PreCompact hook: persists Karo's dispatch debt (status=blocked tasks) to `karo_pending.yaml` before compaction. Writes snapshot reference and log entry. (Issue #32, cmd_535 Phase 4) | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | PreCompact hook that auto-captures task metadata and uncommitted file list before context compaction. Handles nested task YAML structure. Preserves existing `agent_context`. Always exits 0. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_push_difference_check.sh` | fork-added | Git pre-push hook: verifies `difference.md` was updated today (JST date check) before allowing push to shogun repo. Prevents upstream diff documentation drift. | Keep fork — no upstream equivalent |
| `scripts/inbox_watcher.sh` | fork-modified | Bug fix: after sending `/clear`, sets `NEW_CONTEXT_SENT=1` (was 0) preventing spurious CONTEXT-RESET loop. Two cosmetic blank-line changes. | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | After writing shogun inbox with `cmd_complete`/`cmd_milestone` type, auto-calls `ntfy.sh` with formatted title. Non-blocking; ntfy errors logged to stderr only. | Keep fork — no upstream equivalent |
| `scripts/install-shogun-discord-service.sh` | fork-added | Installs Discord Bot as systemd user service. Stops any existing tmux Bot, places service file, enables and starts via `systemctl --user`. Includes DI-01 cleanup and DI-02 cron instructions. | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | Tiny utility outputting JST time in three formats (dashboard, YAML ISO-8601, date-only). Required by all timestamp-producing scripts to avoid UTC accidents (L006 lesson). | Keep fork — no upstream equivalent |
| `scripts/karo_self_clear_check.sh` | fork-added | Karo-specific self /clear check (cmd_531 Phase 3). Five AND conditions: no in_progress cmd, all agents idle, no unread inbox, no preserve_across_stages, tool_count > 50. Higher threshold than ashigaru due to coordination role. | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Appends pipe-delimited violation entries to daily log `logs/daily/YYYY-MM-DD.md` with flock. Used by IR-1 hook and other enforcement points. | Keep fork — no upstream equivalent |
| `scripts/n8n_feedback_append.py` | fork-added | Python script to append user feedback entries to Notion database via n8n webhook. Processes feedback form submissions into structured records. (cmd_478) | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | 914-line Stop-hook: extracts dashboard data (streak, completed count, project breakdown) and upserts to Notion Activity Log DB + owner's diary page. Idempotent per day. | Keep fork — no upstream equivalent |
| `scripts/ntfy.sh` | fork-modified | Supports 3rd argument for extra tags (e.g., `cmd_complete`). Adds `Markdown: yes` header and optional `Title:` header. Tags combine as `outbound,{extra}`. Backward-compatible. | Keep fork — no upstream equivalent |
| `scripts/ntfy_listener.sh` | fork-modified | Hostname guard (`NTFY_ALLOWED_HOST=srv1121380`): exits if host doesn't match. Recognizes `cmd_complete` tag — instead of skipping outbound, wakes Shogun pane with completion notification. | Keep fork — no upstream equivalent |
| `scripts/ntfy_wsl_template.sh` | fork-added | WSL2-adapted template for ntfy_listener.sh. Adjusted paths and environment variables for Windows Subsystem for Linux dual-environment. | Keep fork — no upstream equivalent |
| `scripts/qc_auto_check.sh` | fork-added | Automated QC validation: schema checks for ashigaru report YAML mandatory fields (worker_id, parent_cmd, timestamp, result). Auto-triggered by gunshi during QC workflow. (cmd_488) | Keep fork — no upstream equivalent |
| `scripts/ratelimit_check.sh` | fork-added | CLI rate limit monitor: deduplicates by CLI type to show shared quota consumption. Supports `--lang en/ja` output modes. Used for capacity planning across multi-CLI deployments. | Keep fork — no upstream equivalent |
| `scripts/safe_clear_check.sh` | fork-added | Universal /clear safety check for all roles (cmd_535 Phase 2). Validates 4 common conditions (C1-C4: inbox=0, in_progress=0, dispatch_debt=0, context_policy=clear_between) plus role-specific tool_count thresholds. Shogun always SKIP (F001). | Keep fork — no upstream equivalent |
| `scripts/self_clear_check.sh` | fork-added | Ashigaru self-clear mechanism: after task completion, checks tool count threshold (30) and pending task status. If threshold exceeded and no pending task, triggers self `/clear` via inbox_write to prevent auto-compact cascades. (cmd_488) | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Python script: sends test email via Gmail SMTP (TLS) to trigger n8n Gmail WF tests. Reads creds from `.env`. Supports `--subject`/`--body` overrides. | Keep fork — no upstream equivalent |
| `scripts/session_start_checklist.sh` | fork-added | Ashigaru session start validation: checks inbox unread count and task YAML consistency. Detects mismatches between inbox task_assigned entries and actual task YAML state. | Keep fork — no upstream equivalent |
| `scripts/shc.sh` | fork-added | 陣形管理コマンド (Shogun Formation Controller): deploy/status/restore/list サブコマンド。`config/settings.yaml` → `formations` セクションから陣形プリセットを読み込み、`switch_cli.sh` でCLI切替を実行。(cmd_446/448) | Keep fork — no upstream equivalent |
| `scripts/shogun_context_notify.sh` | fork-added | Shogun context usage monitor: when context > 70% and no in_progress cmd, sends `compact_suggestion` to shogun inbox. Idempotent (1-hour dedup). Never auto-clears (Lord approval required). | Keep fork — no upstream equivalent |
| `scripts/shogun_inbox_notifier.sh` | fork-added | Dashboard `COMPLETE` watcher → shogun inbox auto-notifier. Detects cmd completion markers, writes `cmd_complete` to shogun inbox as safety net when Karo forgets manual notification. Dedup via `shogun_inbox_notified.txt`. (Fix B: cmd_538) | Keep fork — no upstream equivalent |
| `scripts/slim_yaml.py` | fork-modified | Adds `clean_old_snapshots()`: removes `queue/snapshots/*.yaml` older than 24h by mtime. Runs in `slim --all` path. Prevents unbounded snapshot accumulation. | Keep fork — no upstream equivalent |
| `scripts/start_discord_bot.sh` | fork-added | Startup script for Discord Bot → ntfy relay. Creates tmux window `shogun-discord` in multiagent session. Uses venv python (`/.venv/discord-bot/bin/python3`) with system python fallback. (cmd_489) | Keep fork — no upstream equivalent |
| `scripts/stop_hook_daily_log.sh` | fork-added | Stop hook: checks if today's daily log exists and contains cmd entries. Warns on missing/empty log to enforce daily log generation. | Keep fork — no upstream equivalent |
| `scripts/switch_cli.sh` | fork-modified | `update_settings_yaml()` rewritten: line-by-line parsing with `in_cli_section`/`in_cli_agents` flags to preserve `formations` and other sections. `cli_type` key write bug fix. yaml.safe_dump removed for comment preservation. (cmd_448) | Keep fork — no upstream equivalent |
| `scripts/update_dashboard.sh` | fork-modified | Dashboard update orchestration script. Coordinates section updates across multiple dashboard writers. | Merge upstream, preserve fork sections |
| `scripts/update_dashboard_timestamp.sh` | fork-added | PostToolUse hook / manual script: rewrites `最終更新:` line in dashboard.md to current JST. Skips silently when edited file is not dashboard.md. | Keep fork — no upstream equivalent |
| `scripts/watcher_supervisor.sh` | fork-modified | Three additions: (1) flock-based PID-lock guard, (2) auto-start `cmd_complete_notifier.sh`, (3) `roll_call_check()` every 5 min detecting agents stuck on welcome screen and reviving them. | Merge upstream, preserve fork sections |
| `scripts/worktree_cleanup.sh` | fork-added | Safely removes git worktree for agent under `.trees/<agent_id>`: checks uncommitted changes, unlinks symlinks, prunes metadata. | Keep fork — no upstream equivalent |
| `scripts/worktree_create.sh` | fork-added | Creates git worktree at `.trees/<agent_id>` on new branch, symlinks shared runtime dirs (queue, logs, projects, dashboard.md) from main worktree. | Keep fork — no upstream equivalent |

## Category B: Library Files

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `lib/agent_status.sh` | fork-modified | Adds `is_cli_running()`: resolves pane's shell PID via `tmux list-panes`, checks for `claude` child process with `pgrep -P`. Used by watcher logic. | Merge upstream, preserve fork sections |
| `lib/cli_adapter.sh` | fork-modified | Adds `effort` field support to `build_cli_command()`: reads `cli.agents.<id>.effort` from settings YAML, prepends `CLAUDE_CODE_EFFORT_LEVEL=<value>` to command. Also fixes `get_cli_type()` to read `cli_type` key instead of `type` key. (cmd_449) | Merge upstream, preserve fork sections |

## Category C: Agent Instructions

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `instructions/ashigaru.md` | fork-modified | Adds: context snapshot steps, expanded skill_candidate guidance, JST timestamp rule, report target switched to Gunshi, editable_files whitelist section, GChat Webhook guidelines, Fork Extensions (output naming, n8n fix protocol, internal parallelization), Agent() tool usage permission, mandatory report schema fields (worker_id, parent_cmd, timestamp, result). (cmd_488 schema fix) | Keep fork — no upstream equivalent |
| `instructions/codex-ashigaru.md` | fork-added | Codex CLI-specific ashigaru instructions. Adapted from ashigaru.md for OpenAI Codex CLI tool descriptions and constraints. | Keep fork — no upstream equivalent |
| `instructions/common/artifact_registration.md` | fork-added | Shared artifact registration protocol: Notion DB + Drive placement rules, cmd naming conventions (`cmd_{N}_{slug}.md`), role responsibilities (karo=output_path+AR, ashigaru=compliance, gunshi=QC), Notion-Version 2022-06-28 fixed. | Keep fork — no upstream equivalent |
| `instructions/common/batch_processing.md` | fork-added | Mandatory protocol for large dataset processing (30+ items). Enforces batch1 QC gate, 30 items/session limit, detection pattern for restart, quality template with web search mandate, state verification on NG retry, Gunshi review scope. | Keep fork — no upstream equivalent |
| `instructions/common/compact_exception.md` | fork-added | /compact exception policy for preserve_across_stages scenarios. Defines 3 AND conditions (cond_1-3), procedure (check → /compact → snapshot), and fallback to /clear when conditions not met. | Keep fork — no upstream equivalent |
| `instructions/common/compaction_recovery.md` | fork-added | Shared post-compaction recovery steps for all agents. Extracted from duplicated sections in shogun/karo/gunshi/ashigaru to a single source of truth. | Keep fork — no upstream equivalent |
| `instructions/common/context_management.md` | fork-added | 3-layer context management standard (cmd_535 Phase 3). Defines priority order (/clear > self /compact > auto-compact), 5-stage threshold matrix (50%/70%/80%/85%/92%) per role, and safe_clear_check.sh integration. | Keep fork — no upstream equivalent |
| `instructions/common/context_snapshot.md` | fork-added | Context snapshot guide for all agents. Defines timing triggers (task start, decisions, blockers, substep completion, 10+ min work) and `context_snapshot.sh` CLI usage with approach/progress/decisions/blockers fields. | Keep fork — no upstream equivalent |
| `instructions/common/destructive_safety.md` | fork-added | Unconditional destructive operation safety rules. Tier 1 absolute bans (D001-D008: rm -rf, force push, sudo, kill, etc.), Tier 2 stop-and-report triggers, Tier 3 safe defaults. WSL2-specific /mnt/c protection. Prompt injection defense. | Keep fork — no upstream equivalent |
| `instructions/common/gui_verification.md` | fork-added | GUI verification protocol for tkinter in WSL2 (no live GUI). Compensates with `gui_review_required`/`manual_verification_required` task YAML flags, Gunshi frame review, py_compile static check, Lord manual verification via dashboard [action]. | Keep fork — no upstream equivalent |
| `instructions/common/hook_e2e_testing.md` | fork-added | Hook E2E testing checklist: backup, environment switch via TMUX_PANE, 4 scenarios (active write, hook trigger, recovery verification, rollback diff), PASS/FAIL recording, restore-from-backup principle. | Keep fork — no upstream equivalent |
| `instructions/common/memory_policy.md` | fork-added | Shared Memory MCP write policy for all agents (what to write vs not write). Extracted from karo/gunshi duplication. | Keep fork — no upstream equivalent |
| `instructions/common/n8n_e2e_protocol.md` | fork-added | n8n E2E test protocol distinguishing test_file (SO-22 functional verification) vs production_file (SO-23 business outcome). Prevents semantic gap where "function works" but "business is incomplete". Born from cmd_553→cmd_554 incident. | Keep fork — no upstream equivalent |
| `instructions/common/protocol.md` | fork-added | Communication protocol specification: file-based mailbox via `inbox_write.sh`, delivery by `inbox_watcher.sh`, agents never call tmux send-keys directly. Includes usage examples for shogun→karo, ashigaru→karo, karo→ashigaru flows. | Keep fork — no upstream equivalent |
| `instructions/common/self_watch_phase.md` | fork-added | Shared Agent Self-Watch Phase 1/2/3 delivery model (cmd_107). Extracted from duplicated sections in shogun/ashigaru. | Keep fork — no upstream equivalent |
| `instructions/common/shogun_mandatory.md` | fork-added | 14 mandatory rules extracted from CLAUDE.md: dashboard ownership, chain of command, report checks, F006 stall response, SO-16 report delegation, SO-17 north star alignment, SO-18 bug fix tracking, SO-19 completion cleanup, SO-20 verification before report, decomposition_hint requirement. | Keep fork — no upstream equivalent |
| `instructions/common/worktree.md` | fork-added | Guide for git worktree-based parallel execution. Defines when to create worktrees, branch naming, dispatch procedure, merge workflow. From cmd_144 lesson. | Keep fork — no upstream equivalent |
| `instructions/generated/ashigaru.md` | fork-modified | Generated default-CLI ashigaru instructions with report format, language check, and role definition. Built by `build_instructions.sh`. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-ashigaru.md` | fork-modified | Generated Codex-CLI ashigaru instructions. Same role definition adapted for Codex CLI tool constraints. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-gunshi.md` | fork-modified | Generated Codex-CLI gunshi instructions. Thinker role definition with Codex-specific tool constraints. | Merge upstream, preserve fork sections |
| `instructions/generated/codex-karo.md` | fork-modified | Prepends 144-line YAML front-matter (role, F001-F006 forbidden actions, full workflow, pane map, inbox rules). Machine-readable config for Codex-based Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/codex-shogun.md` | fork-modified | Generated Codex-CLI shogun instructions. Strategic role with agent structure table and report flow delegation. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-ashigaru.md` | fork-modified | Generated Copilot-CLI ashigaru instructions. Same role definition adapted for GitHub Copilot CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-gunshi.md` | fork-modified | Generated Copilot-CLI gunshi instructions. Thinker role adapted for Copilot CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/copilot-karo.md` | fork-modified | Same YAML front-matter as codex-karo.md. Config for Copilot-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/generated/copilot-shogun.md` | fork-modified | Generated Copilot-CLI shogun instructions. Strategic role adapted for Copilot CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/gunshi.md` | fork-modified | Generated default-CLI gunshi instructions. Thinker role with analysis/design/evaluation scope, not implementation. | Merge upstream, preserve fork sections |
| `instructions/generated/karo.md` | fork-modified | Same YAML front-matter. Config for default generated Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/kimi-ashigaru.md` | fork-modified | Generated Kimi-CLI ashigaru instructions. Same role definition adapted for Kimi Code CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-gunshi.md` | fork-modified | Generated Kimi-CLI gunshi instructions. Thinker role adapted for Kimi Code CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/kimi-karo.md` | fork-modified | Same YAML front-matter. Config for Kimi-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/generated/kimi-shogun.md` | fork-modified | Generated Kimi-CLI shogun instructions. Strategic role adapted for Kimi Code CLI context. | Merge upstream, preserve fork sections |
| `instructions/generated/shogun.md` | fork-modified | Generated default-CLI shogun instructions. Strategic role with cmd_157 agent structure and delegated report flow. | Merge upstream, preserve fork sections |
| `instructions/gunshi.md` | fork-modified | Adds: context snapshot steps, Autonomous QC Protocol, expanded F006 dashboard permissions, Bloom Analysis support, JST rule, Memory MCP write policy, QC checklist with auto_check integration, Fork Extensions (n8n QC criteria, Bloom routing docs), daily log responsibility, monthly karo.md review cycle. | Keep fork — no upstream equivalent |
| `instructions/karo.md` | fork-modified | Major restructuring: F006 added, workflow expanded with `yaml_slim` (1.5), `bloom_routing` (6.5), dashboard cleanup rules, SO-19 cmd_complete.sh, autonomous QC notes, skill suggestions, snapshot recovery, JST enforcement, editable_files mandatory in task YAML, Agent() tool usage criteria (F003 expansion). Context optimization (cmd_399). | Keep fork — no upstream equivalent |
| `instructions/shogun.md` | fork-modified | Restructured to 2 core missions (translate intent + proactive detection). F006 blind_clear ban, F007 unverified_report ban (SO-20), stall_response_protocol (5-step), Proactive Detection & Reporting, Memory MCP write policy. shm/shc command system reflected. (cmd_450/488) | Keep fork — no upstream equivalent |
| `instructions/skill_candidates.yaml` | fork-added | Registry of 46 skill candidates (SC-001 to SC-046) from cmd_134 to cmd_344. Tracks id, source, occurrences, status, evaluation, skill_path. | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Formal skill lifecycle policy: creation criteria (2-occurrence threshold), reusability assessment, integration-vs-new decision matrix, file structure standards. | Keep fork — no upstream equivalent |
| `templates/karo_task_template.yaml` | fork-added | Extracted from karo.md (S2 optimization): Task YAML template with full field reference. Reduces karo.md inline context by ~400 tokens. | Keep fork — no upstream equivalent |

## Category D: System Configuration

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `CLAUDE.md` | fork-modified | Major evolution: English-base with JA persona zones, VSCode/Pattern B branch, snapshot integration, Gunshi auto-QC protocol, dashboard tag taxonomy, SO-16 through SO-23, F006/F007, Batch Processing Protocol, Critical Thinking Rules, test self-sufficiency, Destructive Operation Safety tiers, Agent() tool usage criteria, Self Clear Protocol, GUI Verification Protocol, n8n E2E Protocol, counter_increment context tracking. | Manual review required |
| `AGENTS.md` | fork-modified | Same conceptual changes as CLAUDE.md adapted for Codex CLI context. VSCode branch identifies as "Codex CLI". | Merge upstream, preserve fork sections |
| `agents/default/system.md` | fork-modified | Same delta as CLAUDE.md adapted for Kimi K2 CLI context. | Merge upstream, preserve fork sections |
| `.github/copilot-instructions.md` | fork-modified | Same delta as CLAUDE.md adapted for GitHub Copilot CLI context. | Merge upstream, preserve fork sections |
| `.github/workflows/upstream-sync.yml` | fork-added | GitHub Actions workflow for automated upstream sync checks. Monitors upstream/main for new commits and creates tracking issues or PRs. | Keep fork — no upstream equivalent |
| `.githooks/pre-commit` | fork-added | Git pre-commit hook: runs shellcheck on all `scripts/*.sh`, then verifies `instructions/generated/` is up to date via `build_instructions.sh`. Aborts commit on shellcheck failure or stale generated files. | Keep fork — no upstream equivalent |
| `README.md` | fork-modified | Updated project README: multi-CLI support (Claude Code, Codex, Copilot, Kimi Code), "Talk Coding" tagline, v3.5 Dynamic Model Routing badge, hero screenshots. | Merge upstream, preserve fork sections |
| `README_ja.md` | fork-modified | Japanese translation of README.md with same multi-CLI and Talk Coding updates. | Merge upstream, preserve fork sections |

## Category E: Config & Settings

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.claude/settings.json` | fork-modified | Project-level settings: PreCompact hook, PostToolUse hooks (dashboard timestamp, IR-1, violation log, counter_increment), SessionStart hook (karo). VPS-specific absolute paths. | Keep fork — no upstream equivalent |
| `.gitignore` | fork-modified | Allow-lists fork-added files (config/, scripts/hooks/, skills/, originaldocs/, discord_bot.env.sample, etc.) in whitelist-based .gitignore. | Keep fork — no upstream equivalent |
| `config/counter_coefficients.yaml` | fork-added | Per-agent alpha coefficients for tool_count→context_pct conversion. Generated from 7-day JSONL regression analysis (220 files, 53 compact markers). Agents with < 3 samples use fallback alpha=0.50. (cmd_555d) | Keep fork — no upstream equivalent |
| `config/discord_bot.env.sample` | fork-added | Sample configuration for Discord Bot → ntfy relay. Contains placeholder `DISCORD_BOT_TOKEN` and `DISCORD_ALLOWED_USER_IDS`. Actual env file is git-ignored. (cmd_489) | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Project registry: sample entry with id, name, path, priority, status, current_project fields. | Keep fork — no upstream equivalent |
| `config/qc_checklist.yaml` | fork-added | QC checklist for Gunshi T2 Standing Orders. Defines SO-01 through SO-23 check items with id, name, frequency (required/conditional), check_method (auto/manual), and descriptions. Used by `qc_auto_check.sh` and manual review. | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Runtime config: language, shell, skill paths, logging, bloom routing mode, ntfy topic, screenshot path, per-agent effort levels, `formations` section (hybrid/all-opus/all-sonnet presets). | Keep fork — no upstream equivalent |
| `config/streaks_format.yaml` | fork-added | Extracted from karo.md (S2 optimization): streaks.yaml format specification. Referenced by karo.md to reduce inline context. | Keep fork — no upstream equivalent |

## Category F: Documentation & Output

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `context/n8n-operations.md` | fork-added | n8n operational runbook: error notification WF architecture, ntfy topic, per-WF error workflow IDs, new-WF checklist. | Keep fork — no upstream equivalent |
| `docs/DISCORD_BOT_SETUP.md` | fork-added | Discord Bot setup guide: systemd user service installation via `install-shogun-discord-service.sh`, cron healthcheck registration, DI-01 through DI-06 operational notes. (cmd_497) | Keep fork — no upstream equivalent |
| `docs/agent-routing-baseline.md` | fork-added | Agent routing baseline documentation: hybrid routing analysis, capability tier definitions, model assignment strategy. (cmd_463) | Keep fork — no upstream equivalent |
| `docs/feedback-system-guide.md` | fork-added | Feedback system setup and usage guide: n8n workflow configuration, Notion DB schema, feedback form integration, troubleshooting. (cmd_478) | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Skill candidate archive: tracks creation/integration status and source cmd references. Managed by dashboard_rotate.sh and stocktake cmds. | Keep fork — no upstream equivalent |
| `originaldocs/notification_channels.md` | fork-added | Full ntfy + Discord notification channel specification (197 lines): architecture diagram, ntfy primary channel (send/receive flows, scripts, auth), Discord secondary channel (Bot→ntfy relay, setup steps, security), troubleshooting matrix. (cmd_490) | Keep fork — no upstream equivalent |
| `output/cmd_462_feedback_system_research.md` | fork-added | フィードバック収集システム方法論調査レポート(336行): 9選択肢比較表、主推奨=Notion Forms+n8nハイブリッド、実装ロードマップ。 | Keep fork — no upstream equivalent |
| `output/cmd_463_hybrid_routing_baseline.md` | fork-added | Hybrid routing baseline analysis report: model capability tiers, cost/performance tradeoffs, routing decision matrix. (cmd_463) | Keep fork — no upstream equivalent |
| `output/cmd_466_hybrid_routing_baseline_extended.md` | fork-added | Extended hybrid routing baseline with additional scenarios, edge case analysis, and performance benchmarks. (cmd_466) | Keep fork — no upstream equivalent |
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Skills stocktake: evaluates skill files for compression/consolidation. 530-line evaluation artifact. | Keep fork — no upstream equivalent |
| `projects/artifact-standardization/review_cmd519.md` | fork-added | cmd_519 retrospective review by Gunshi: evaluates sug_cmd_509_001/002/003 recovery and artifact_register.sh adoption maturity. Documents unrecoverable suggestion data and recommends retention policy improvements. | Keep fork — no upstream equivalent |
| `projects/skill-triage-cmd521/skill_triage.md` | fork-added | cmd_521 skill candidate triage report by Gunshi: classifies 12 dashboard candidates into 4 categories (new/integrate/CLAUDE.md/reject) with priority and rationale. Includes north_star verification. | Keep fork — no upstream equivalent |
| `queue/n8n/feedback-system.json` | fork-added | n8n workflow definition (JSON export) for feedback collection system. Configures webhook trigger, data transformation, Notion API integration. (cmd_478) | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru1_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru3_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/gunshi_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |

## Category G: Tests

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/cmd_544_test.sh` | fork-added | 17 test cases for cmd_squash_pub_hook.sh safety mechanisms: kill-switch (KS-1/2/3), rate-limit (RL-1/2/3 + TTL), daily metric (DM-1/2/3/4), integration scenarios (S1/S2/S5/S7), sug_003, supervisor restart. Uses jst_now.sh stub for deterministic time. | Keep fork — no upstream equivalent |
| `tests/dim_d_quality_comparison.sh` | fork-added | Bloom Dimension D quality comparison experiment: runs identical L5 task on Haiku 4.5 vs Sonnet 4.6, scores via Gunshi (Opus). Pass criteria: Sonnet >= 70, Haiku <= 50, delta >= 15. | Keep fork — no upstream equivalent |
| `tests/e2e/e2e_bloom_routing.bats` | fork-modified | Adds `setup()` guard: skips suite when `capability_tiers` absent from settings. Prevents false failures in unconfigured environments. | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_codex_startup.bats` | fork-modified | No functional change. Line-ending normalization (CRLF→LF) or whitespace reformat. | Accept upstream changes |
| `tests/specs/dynamic_model_routing_spec.md` | fork-added | Dynamic Model Routing test specification (DMR-SPEC-001). Covers Phase 1-4 TDD test-first approach for FR/NFR from requirements doc. References Issue #53. | Keep fork — no upstream equivalent |
| `tests/test_artifact_register.sh` | fork-added | 3-case unit tests for artifact_register.sh: validates argument parsing, dry-run output, and error handling with expected exit codes. | Keep fork — no upstream equivalent |
| `tests/unit/test_cli_adapter.bats` | fork-added | Unit tests for cli_adapter.sh: validates `build_cli_command()` with effort field, `get_cli_type()` key reading, backward compatibility with missing cli section. Uses temp settings YAML fixtures. | Keep fork — no upstream equivalent |
| `tests/unit/test_dashboard_timestamp.bats` | fork-added | 4 tests (T-DT-001-004) for `update_dashboard_timestamp.sh`: happy path, missing file, format regex, syntax check. Part of JST enforcement. | Keep fork — no upstream equivalent |
| `tests/unit/test_dynamic_model_routing.bats` | fork-modified | Adds tmux mocking around TC-FAM-001-009 tests. Fixes test isolation: real tmux pane data was interfering with `find_agent_for_model()`. | Merge upstream, preserve fork sections |
| `tests/unit/test_ir1_editable_files.bats` | fork-added | 12-case unit tests for IR-1 hook: agent exemptions, whitelist enforcement, implicit allowances, glob patterns. | Keep fork — no upstream equivalent |
| `tests/unit/test_ntfy_ack.bats` | fork-added | 8-case unit tests (T-ACK-001-008) for ntfy ACK auto-reply: normal message → inbox_write, outbound tag skip, auto-ACK removal, failure handling, empty message skip, keepalive skip, append failure, special character preservation. | Keep fork — no upstream equivalent |
| `tests/unit/test_send_wakeup.bats` | fork-modified | Extends mock layer: adds MOCK_PANE_PID, MOCK_CLI_RUNNING, MOCK_STAT_MTIME, MOCK_GIT_STATUS + mock functions. Enables testing `is_cli_running()` without real processes. | Merge upstream, preserve fork sections |
| `tests/unit/test_switch_cli.bats` | fork-added | Unit tests for switch_cli.sh: validates settings.yaml CLI section updates, model switching, and formation preservation. Tests `update_settings_yaml()` line-by-line parser. | Keep fork — no upstream equivalent |

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
| `shutsujin_departure.sh` | fork-modified | Additions: (1) kessen mode applies Opus to karo with `--effort max`, (2) `tmux set-environment TZ "Asia/Tokyo"`, (3) model display name fix, (4) `--hybrid` flag with mutex check, (5) `shc.sh deploy` pre-apply, (6) `update_dashboard_formation()` auto-update. (cmd_450) | Keep fork — no upstream equivalent |

## Category I: Skills

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `skills/pdfmerged-feature-release-workflow/SKILL.md` | fork-added | pdfmerged リリース工程の体系化スキル(386行): cmd_495c (docs/TEST_GUIDE.md更新漏れ)事故の再発防止。A/B/C/D 4区分チェックリスト、変更種別×成果物の同期対象マトリクス、家老タスクYAMLテンプレート、軍師QC grep チェックポイント、足軽レポート必須項目、参考URL26件。(cmd_501d) | Keep fork — no upstream equivalent |
| `skills/shogun-bash-cross-platform-ci/SKILL.md` | fork-added | Bash cross-platform CI pattern collection: flock BSD fallback, sed -i compatibility, python3 .venv resolution, hostname guard opt-in, SHOGUN_ROOT self-resolve. Born from cmd_532 Phase B (14 test failures across Linux + macOS). | Keep fork — no upstream equivalent |
| `skills/shogun-bloom-config/SKILL.md` | fork-added | Interactive wizard skill: guided multiple-choice questions about subscriptions, outputs ready-to-paste `capability_tiers` YAML + fixed agent model assignments for Bloom routing setup. | Keep fork — no upstream equivalent |
| `skills/shogun-model-list/SKILL.md` | fork-added | Reference table skill: all AI CLI tools x available models x required subscriptions x Bloom max capability level. Used before configuring `capability_tiers` in settings.yaml. | Keep fork — no upstream equivalent |
| `skills/shogun-model-switch/SKILL.md` | fork-added | Agent CLI live switcher skill: updates settings.yaml, triggers /exit, starts new CLI, updates pane metadata. Supports model, CLI type, and Thinking toggle switching. | Keep fork — no upstream equivalent |

## Category J: Operational State & Logs

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `logs/safe_clear/.gitkeep` | fork-added | Directory placeholder for safe_clear log output. Ensures `logs/safe_clear/` directory exists in git. | Keep fork — no upstream equivalent |
| `scripts/shogun-discord.service.template` | fork-added | Systemd user service unit template for Discord Bot. Configures WorkingDirectory, EnvironmentFile, ExecStart with venv python, on-failure restart (10s), rate limit (5 starts / 600s), log paths. | Keep fork — no upstream equivalent |

---

## Merge Guidance Summary

| Guidance | Count | Files |
|----------|-------|-------|
| Keep fork — no upstream equivalent | 120 | All fork-added files + fork-modified files with no upstream counterpart |
| Merge upstream, preserve fork sections | 25 | `inbox_watcher.sh`, `watcher_supervisor.sh`, `update_dashboard.sh`, `lib/agent_status.sh`, `lib/cli_adapter.sh`, `AGENTS.md`, `agents/default/system.md`, `.github/copilot-instructions.md`, `README.md`, `README_ja.md`, `instructions/generated/ashigaru.md`, `instructions/generated/codex-ashigaru.md`, `instructions/generated/codex-gunshi.md`, `instructions/generated/codex-shogun.md`, `instructions/generated/copilot-ashigaru.md`, `instructions/generated/copilot-gunshi.md`, `instructions/generated/copilot-shogun.md`, `instructions/generated/gunshi.md`, `instructions/generated/kimi-ashigaru.md`, `instructions/generated/kimi-gunshi.md`, `instructions/generated/kimi-shogun.md`, `instructions/generated/shogun.md`, `tests/e2e/e2e_bloom_routing.bats`, `tests/unit/test_dynamic_model_routing.bats`, `tests/unit/test_send_wakeup.bats` |
| Accept upstream changes | 1 | `tests/e2e/e2e_codex_startup.bats` |
| Manual review required | 1 | `CLAUDE.md` (core config, both sides actively modify) |

**CLAUDE.md** is the highest-risk merge target: both fork and upstream actively modify this file. On merge, preserve fork's Pattern B branch, snapshot system, Gunshi auto-QC, SO-16 through SO-23, F006/F007, Batch Processing Protocol, Critical Thinking Rules, Self Clear Protocol, GUI Verification Protocol, n8n E2E Protocol, counter_increment context tracking, and dashboard tag taxonomy while accepting upstream structural/procedural updates.
