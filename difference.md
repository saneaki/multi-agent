# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-04-15
> **Base**: `git diff upstream/main...original` (82 files, +14054/−3121 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: original

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Key architectural themes:

1. **Context resilience** — Snapshot write/clear system for surviving /clear and compaction
2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment; `qc_auto_check.sh` for schema validation
3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents)
4. **Skill management lifecycle** — Candidate tracking, policy, evaluation, promotion pipeline, and periodic stocktake (cmd_390: 16 candidates reviewed, 5 new + 4 integrated)
5. **Operational safety** — F006 blind-clear ban, F007 unverified-report ban (SO-20 3-point verification), IR-1 editable-files whitelist guard, SO-19 completion cleanup enforcement, stall response protocol, Agent() tool governance, self-clear mechanism (`self_clear_check.sh`), git pre-push difference.md enforcement
6. **Notification integration** — ntfy push (with cmd_complete tag) + Discord Bot → ntfy relay (`discord_to_ntfy.py`) + Google Chat (`gchat_send.sh`) + Notion session logging. Dual-channel input (ntfy app + Discord DM) unified via ntfy_inbox.yaml
7. **VPS/WSL2 environment** — Paths, tmux TZ, hostname guards, dual-environment settings
8. **Rule enforcement automation** — Hook-based violation detection (IR-1/IR-2/IR-5), qc_auto_check.sh schema validation, cmd_complete.sh for SO-19 compliance, daily log stop hook, karo SessionStart hook, git pre-push difference.md date check
9. **Feedback system** — n8n workflow-based feedback collection, `n8n_feedback_append.py`, agent routing baseline docs, feedback system guide

**Merge strategy**: Most fork files have no upstream equivalent. For files that both fork and upstream modify (CLAUDE.md, instructions/*.md, tests/), manual merge is required — preserve fork sections while accepting upstream structural changes.

---

## Category A: Infrastructure Scripts

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/cmd_complete_notifier.sh` | fork-added | Watches dashboard.md with inotifywait; sends ntfy push to Lord's phone on new cmd completion. Pre-seeds state to prevent startup flood. | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | CLI (write/clear/read) to persist agent work-in-progress context to `queue/snapshots/<agent_id>_snapshot.yaml` with flock concurrency. Enables post-compaction recovery. | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Daily midnight JST cron: renames "本日の戦果"→"昨日の戦果", resets streak/frog/completion fields, trims skill section to 5 entries via FIFO archive to `memory/skill_history.md`. | Keep fork — no upstream equivalent |
| `scripts/discord_to_ntfy.py` | fork-added | Discord Bot (204 lines): receives DMs from whitelisted users via discord.py, POSTs to ntfy.sh with `[discord]` title prefix. Security: DM-only processing, user ID whitelist, `--dry-run` mode. Uses httpx for HTTP. (cmd_489) | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Google Chat Webhook wrapper (9 lines): sources `.env` for `GCHAT_WEBHOOK_URL`, sends JSON-escaped message via curl, enforces `sleep 5` between calls to avoid 429 rate-limit errors. | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | PostToolUse hook enforcing IR-1 editable-files whitelist for ashigaru agents. Reads task YAML, resolves globs, implicit allowlist (own inbox, SKILL.md), logs violations via `log_violation.sh`. Non-ashigaru exempt. | Keep fork — no upstream equivalent |
| `scripts/hooks/karo_session_start_check.sh` | fork-added | SessionStart hook (karo-only): checks `$TMUX_PANE` and `agent_id`, outputs environment confirmation + F003 reminder (Agent() deliverable prohibition). Prevents environment misidentification. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | PreCompact hook that auto-captures task metadata and uncommitted file list before context compaction. Handles nested task YAML structure. Preserves existing `agent_context`. Always exits 0. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_push_difference_check.sh` | fork-added | Git pre-push hook: verifies `difference.md` was updated today (JST date check) before allowing push to shogun repo. Prevents upstream diff documentation drift. | Keep fork — no upstream equivalent |
| `scripts/inbox_watcher.sh` | fork-modified | Bug fix: after sending `/clear`, sets `NEW_CONTEXT_SENT=1` (was 0) preventing spurious CONTEXT-RESET loop. Two cosmetic blank-line changes. | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | After writing shogun inbox with `cmd_complete`/`cmd_milestone` type, auto-calls `ntfy.sh` with formatted title. Non-blocking; ntfy errors logged to stderr only. | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | Tiny utility outputting JST time in three formats (dashboard, YAML ISO-8601, date-only). Required by all timestamp-producing scripts to avoid UTC accidents (L006 lesson). | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Appends pipe-delimited violation entries to daily log `logs/daily/YYYY-MM-DD.md` with flock. Used by IR-1 hook and other enforcement points. | Keep fork — no upstream equivalent |
| `scripts/n8n_feedback_append.py` | fork-added | Python script to append user feedback entries to Notion database via n8n webhook. Processes feedback form submissions into structured records. (cmd_478) | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | 914-line Stop-hook: extracts dashboard data (streak, completed count, project breakdown) and upserts to Notion Activity Log DB + owner's diary page. Idempotent per day. | Keep fork — no upstream equivalent |
| `scripts/ntfy.sh` | fork-modified | Supports 3rd argument for extra tags (e.g., `cmd_complete`). Adds `Markdown: yes` header and optional `Title:` header. Tags combine as `outbound,{extra}`. Backward-compatible. | Keep fork — no upstream equivalent |
| `scripts/ntfy_listener.sh` | fork-modified | Hostname guard (`NTFY_ALLOWED_HOST=srv1121380`): exits if host doesn't match. Recognizes `cmd_complete` tag — instead of skipping outbound, wakes Shogun pane with completion notification. | Keep fork — no upstream equivalent |
| `scripts/ntfy_wsl_template.sh` | fork-added | WSL2-adapted template for ntfy_listener.sh. Adjusted paths and environment variables for Windows Subsystem for Linux dual-environment. | Keep fork — no upstream equivalent |
| `scripts/qc_auto_check.sh` | fork-added | Automated QC validation: schema checks for ashigaru report YAML mandatory fields (worker_id, parent_cmd, timestamp, result). Auto-triggered by gunshi during QC workflow. (cmd_488) | Keep fork — no upstream equivalent |
| `scripts/self_clear_check.sh` | fork-added | Ashigaru self-clear mechanism: after task completion, checks tool count threshold (30) and pending task status. If threshold exceeded and no pending task, triggers self `/clear` via inbox_write to prevent auto-compact cascades. (cmd_488) | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Python script: sends test email via Gmail SMTP (TLS) to trigger n8n Gmail WF tests. Reads creds from `.env`. Supports `--subject`/`--body` overrides. | Keep fork — no upstream equivalent |
| `scripts/shc.sh` | fork-added | 陣形管理コマンド (Shogun Formation Controller): deploy/status/restore/list サブコマンド。`config/settings.yaml` → `formations` セクションから陣形プリセットを読み込み、`switch_cli.sh` でCLI切替を実行。(cmd_446/448) | Keep fork — no upstream equivalent |
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
| `instructions/common/worktree.md` | fork-added | Guide for git worktree-based parallel execution. Defines when to create worktrees, branch naming, dispatch procedure, merge workflow. From cmd_144 lesson. | Keep fork — no upstream equivalent |
| `instructions/generated/codex-karo.md` | fork-modified | Prepends 144-line YAML front-matter (role, F001-F006 forbidden actions, full workflow, pane map, inbox rules). Machine-readable config for Codex-based Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/copilot-karo.md` | fork-modified | Same YAML front-matter as codex-karo.md. Config for Copilot-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/generated/karo.md` | fork-modified | Same YAML front-matter. Config for default generated Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/kimi-karo.md` | fork-modified | Same YAML front-matter. Config for Kimi-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/gunshi.md` | fork-modified | Adds: context snapshot steps, Autonomous QC Protocol, expanded F006 dashboard permissions, Bloom Analysis support, JST rule, Memory MCP write policy, QC checklist with auto_check integration, Fork Extensions (n8n QC criteria, Bloom routing docs), daily log responsibility, monthly karo.md review cycle. | Keep fork — no upstream equivalent |
| `instructions/karo.md` | fork-modified | Major restructuring: F006 added, workflow expanded with `yaml_slim` (1.5), `bloom_routing` (6.5), dashboard cleanup rules, SO-19 cmd_complete.sh, autonomous QC notes, skill suggestions, snapshot recovery, JST enforcement, editable_files mandatory in task YAML, Agent() tool usage criteria (F003 expansion). Context optimization (cmd_399). | Keep fork — no upstream equivalent |
| `instructions/shogun.md` | fork-modified | Restructured to 2 core missions (translate intent + proactive detection). F006 blind_clear ban, F007 unverified_report ban (SO-20), stall_response_protocol (5-step), Proactive Detection & Reporting, Memory MCP write policy. shm/shc command system reflected. (cmd_450/488) | Keep fork — no upstream equivalent |
| `instructions/skill_candidates.yaml` | fork-added | Registry of 46 skill candidates (SC-001 to SC-046) from cmd_134 to cmd_344. Tracks id, source, occurrences, status, evaluation, skill_path. | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Formal skill lifecycle policy: creation criteria (2-occurrence threshold), reusability assessment, integration-vs-new decision matrix, file structure standards. | Keep fork — no upstream equivalent |
| `templates/karo_task_template.yaml` | fork-added | Extracted from karo.md (S2 optimization): Task YAML template with full field reference. Reduces karo.md inline context by ~400 tokens. | Keep fork — no upstream equivalent |

## Category D: System Configuration

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `CLAUDE.md` | fork-modified | Major evolution: English-base with JA persona zones, VSCode/Pattern B branch, snapshot integration, Gunshi auto-QC protocol, dashboard tag taxonomy, SO-16 through SO-20, F006/F007, Batch Processing Protocol, Critical Thinking Rules, test self-sufficiency, Destructive Operation Safety tiers, Agent() tool usage criteria, Self Clear Protocol, GUI Verification Protocol. | Manual review required |
| `AGENTS.md` | fork-modified | Same conceptual changes as CLAUDE.md adapted for Codex CLI context. VSCode branch identifies as "Codex CLI". | Merge upstream, preserve fork sections |
| `agents/default/system.md` | fork-modified | Same delta as CLAUDE.md adapted for Kimi K2 CLI context. | Merge upstream, preserve fork sections |
| `.github/copilot-instructions.md` | fork-modified | Same delta as CLAUDE.md adapted for GitHub Copilot CLI context. | Merge upstream, preserve fork sections |
| `.github/workflows/upstream-sync.yml` | fork-added | GitHub Actions workflow for automated upstream sync checks. Monitors upstream/main for new commits and creates tracking issues or PRs. | Keep fork — no upstream equivalent |

## Category E: Config & Settings

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.claude/settings.json` | fork-modified | Project-level settings: PreCompact hook, PostToolUse hooks (dashboard timestamp, IR-1, violation log), SessionStart hook (karo). VPS-specific absolute paths. | Keep fork — no upstream equivalent |
| `.gitignore` | fork-modified | Allow-lists fork-added files (config/, scripts/hooks/, skills/, originaldocs/, discord_bot.env.sample, etc.) in whitelist-based .gitignore. | Keep fork — no upstream equivalent |
| `config/discord_bot.env.sample` | fork-added | Sample configuration for Discord Bot → ntfy relay. Contains placeholder `DISCORD_BOT_TOKEN` and `DISCORD_ALLOWED_USER_IDS`. Actual env file is git-ignored. (cmd_489) | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Project registry: sample entry with id, name, path, priority, status, current_project fields. | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Runtime config: language, shell, skill paths, logging, bloom routing mode, ntfy topic, screenshot path, per-agent effort levels, `formations` section (hybrid/all-opus/all-sonnet presets). | Keep fork — no upstream equivalent |
| `config/streaks_format.yaml` | fork-added | Extracted from karo.md (S2 optimization): streaks.yaml format specification. Referenced by karo.md to reduce inline context. | Keep fork — no upstream equivalent |

## Category F: Documentation & Output

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `context/n8n-operations.md` | fork-added | n8n operational runbook: error notification WF architecture, ntfy topic, per-WF error workflow IDs, new-WF checklist. | Keep fork — no upstream equivalent |
| `docs/agent-routing-baseline.md` | fork-added | Agent routing baseline documentation: hybrid routing analysis, capability tier definitions, model assignment strategy. (cmd_463) | Keep fork — no upstream equivalent |
| `docs/feedback-system-guide.md` | fork-added | Feedback system setup and usage guide: n8n workflow configuration, Notion DB schema, feedback form integration, troubleshooting. (cmd_478) | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Skill candidate archive: tracks creation/integration status and source cmd references. Managed by dashboard_rotate.sh and stocktake cmds. | Keep fork — no upstream equivalent |
| `originaldocs/notification_channels.md` | fork-added | Full ntfy + Discord notification channel specification (197 lines): architecture diagram, ntfy primary channel (send/receive flows, scripts, auth), Discord secondary channel (Bot→ntfy relay, setup steps, security), troubleshooting matrix. (cmd_490) | Keep fork — no upstream equivalent |
| `output/cmd_462_feedback_system_research.md` | fork-added | フィードバック収集システム方法論調査レポート(336行): 9選択肢比較表、主推奨=Notion Forms+n8nハイブリッド、実装ロードマップ。 | Keep fork — no upstream equivalent |
| `output/cmd_463_hybrid_routing_baseline.md` | fork-added | Hybrid routing baseline analysis report: model capability tiers, cost/performance tradeoffs, routing decision matrix. (cmd_463) | Keep fork — no upstream equivalent |
| `output/cmd_466_hybrid_routing_baseline_extended.md` | fork-added | Extended hybrid routing baseline with additional scenarios, edge case analysis, and performance benchmarks. (cmd_466) | Keep fork — no upstream equivalent |
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Skills stocktake: evaluates skill files for compression/consolidation. 530-line evaluation artifact. | Keep fork — no upstream equivalent |
| `queue/n8n/feedback-system.json` | fork-added | n8n workflow definition (JSON export) for feedback collection system. Configures webhook trigger, data transformation, Notion API integration. (cmd_478) | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru3_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru4_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |

## Category G: Tests

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `tests/e2e/e2e_bloom_routing.bats` | fork-modified | Adds `setup()` guard: skips suite when `capability_tiers` absent from settings. Prevents false failures in unconfigured environments. | Merge upstream, preserve fork sections |
| `tests/e2e/e2e_codex_startup.bats` | fork-modified | No functional change. Line-ending normalization (CRLF→LF) or whitespace reformat. | Accept upstream changes |
| `tests/unit/test_dashboard_timestamp.bats` | fork-added | 4 tests (T-DT-001-004) for `update_dashboard_timestamp.sh`: happy path, missing file, format regex, syntax check. Part of JST enforcement. | Keep fork — no upstream equivalent |
| `tests/unit/test_dynamic_model_routing.bats` | fork-modified | Adds tmux mocking around TC-FAM-001-009 tests. Fixes test isolation: real tmux pane data was interfering with `find_agent_for_model()`. | Merge upstream, preserve fork sections |
| `tests/unit/test_ir1_editable_files.bats` | fork-added | 12-case unit tests for IR-1 hook: agent exemptions, whitelist enforcement, implicit allowances, glob patterns. | Keep fork — no upstream equivalent |
| `tests/unit/test_send_wakeup.bats` | fork-modified | Extends mock layer: adds MOCK_PANE_PID, MOCK_CLI_RUNNING, MOCK_STAT_MTIME, MOCK_GIT_STATUS + mock functions. Enables testing `is_cli_running()` without real processes. | Merge upstream, preserve fork sections |

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

---

## Merge Guidance Summary

| Guidance | Count | Files |
|----------|-------|-------|
| Keep fork — no upstream equivalent | 68 | All fork-added files + fork-modified files with no upstream counterpart |
| Merge upstream, preserve fork sections | 8 | `inbox_watcher.sh`, `watcher_supervisor.sh`, `update_dashboard.sh`, `lib/agent_status.sh`, `lib/cli_adapter.sh`, `AGENTS.md`, `agents/default/system.md`, `.github/copilot-instructions.md`, `tests/e2e/e2e_bloom_routing.bats`, `tests/unit/test_dynamic_model_routing.bats`, `tests/unit/test_send_wakeup.bats` |
| Accept upstream changes | 1 | `tests/e2e/e2e_codex_startup.bats` |
| Manual review required | 1 | `CLAUDE.md` (core config, both sides actively modify) |

**CLAUDE.md** is the highest-risk merge target: both fork and upstream actively modify this file. On merge, preserve fork's Pattern B branch, snapshot system, Gunshi auto-QC, SO-16 through SO-20, F006/F007, Batch Processing Protocol, Critical Thinking Rules, Self Clear Protocol, GUI Verification Protocol, and dashboard tag taxonomy while accepting upstream structural/procedural updates.
