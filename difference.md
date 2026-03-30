# Fork Difference Analysis: shogun vs upstream

> **Generated**: 2026-03-31
> **Base**: `git diff upstream/main...original` (63 files, +8047/−2024 lines)
> **Upstream**: https://github.com/yohey-w/multi-agent-shogun.git
> **Fork branch**: original

## Summary

This fork extends the upstream multi-agent-shogun system with production-grade operational infrastructure for a VPS (Ubuntu) + WSL2 dual-environment deployment. Key architectural themes:

1. **Context resilience** — Snapshot write/clear system for surviving /clear and compaction
2. **Autonomous QC pipeline** — Gunshi self-triggers quality checks without Karo assignment
3. **JST timestamp enforcement** — All timestamps use `jst_now.sh` (prevents UTC accidents)
4. **Skill management lifecycle** — Candidate tracking, policy, evaluation, promotion pipeline, and periodic stocktake (cmd_390: 16 candidates reviewed, 5 new + 4 integrated)
5. **Operational safety** — F006 blind-clear ban, IR-1 editable-files whitelist guard, SO-19 completion cleanup enforcement, stall response protocol
6. **Notification integration** — ntfy push (with cmd_complete tag for Shogun auto-wake) + Google Chat (`gchat_send.sh` with rate-limit sleep) + Notion session logging
7. **VPS/WSL2 environment** — Paths, tmux TZ, hostname guards, dual-environment settings
8. **Rule enforcement automation** — Hook-based violation detection (IR-1/IR-2/IR-5), qc_auto_check.sh, cmd_complete.sh for SO-19 compliance

**Merge strategy**: Most fork files have no upstream equivalent. For files that both fork and upstream modify (CLAUDE.md, instructions/*.md, tests/), manual merge is required — preserve fork sections while accepting upstream structural changes.

---

## Category A: Infrastructure Scripts

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `scripts/cmd_complete_notifier.sh` | fork-added | Watches dashboard.md with inotifywait; sends ntfy push to Lord's phone on new cmd completion. Pre-seeds state to prevent startup flood. | Keep fork — no upstream equivalent |
| `scripts/context_snapshot.sh` | fork-added | CLI (write/clear/read) to persist agent work-in-progress context to `queue/snapshots/<agent_id>_snapshot.yaml` with flock concurrency. Enables post-compaction recovery. | Keep fork — no upstream equivalent |
| `scripts/dashboard_rotate.sh` | fork-added | Daily midnight JST cron: renames "本日の戦果"→"昨日の戦果", resets streak/frog/completion fields, trims skill section to 5 entries via FIFO archive to `memory/skill_history.md`. | Keep fork — no upstream equivalent |
| `scripts/gchat_send.sh` | fork-added | Google Chat Webhook wrapper (9 lines): sources `.env` for `GCHAT_WEBHOOK_URL`, sends JSON-escaped message via curl, enforces `sleep 5` between calls to avoid 429 rate-limit errors (lesson from cmd_386 18-part send). | Keep fork — no upstream equivalent |
| `scripts/hooks/ir1_editable_files_check.sh` | fork-added | PostToolUse hook enforcing IR-1 editable-files whitelist for ashigaru agents. Reads task YAML, resolves globs, implicit allowlist (own inbox, SKILL.md), logs violations via `log_violation.sh`. Non-ashigaru exempt. | Keep fork — no upstream equivalent |
| `scripts/hooks/pre_compact_snapshot.sh` | fork-added | PreCompact hook that auto-captures task metadata and uncommitted file list before context compaction. Handles nested task YAML structure. Preserves existing `agent_context`. Always exits 0. | Keep fork — no upstream equivalent |
| `scripts/inbox_watcher.sh` | fork-modified | Bug fix: after sending `/clear`, sets `NEW_CONTEXT_SENT=1` (was 0) preventing spurious CONTEXT-RESET loop. Two cosmetic blank-line changes. | Merge upstream, preserve fork sections |
| `scripts/inbox_write.sh` | fork-modified | After writing shogun inbox with `cmd_complete`/`cmd_milestone` type, auto-calls `ntfy.sh` with formatted title. Non-blocking; ntfy errors logged to stderr only. | Keep fork — no upstream equivalent |
| `scripts/jst_now.sh` | fork-added | Tiny utility outputting JST time in three formats (dashboard, YAML ISO-8601, date-only). Required by all timestamp-producing scripts to avoid UTC accidents (L006 lesson). | Keep fork — no upstream equivalent |
| `scripts/log_violation.sh` | fork-added | Appends pipe-delimited violation entries to daily log `logs/daily/YYYY-MM-DD.md` with flock. Used by IR-1 hook and other enforcement points. | Keep fork — no upstream equivalent |
| `scripts/notion_session_log.sh` | fork-added | 914-line Stop-hook: extracts dashboard data (streak, completed count, project breakdown) and upserts to Notion Activity Log DB + owner's diary page. Idempotent per day. | Keep fork — no upstream equivalent |
| `scripts/ntfy.sh` | fork-modified | Supports 3rd argument for extra tags (e.g., `cmd_complete`). Adds `Markdown: yes` header and optional `Title:` header. Tags combine as `outbound,{extra}`. Backward-compatible. | Keep fork — no upstream equivalent |
| `scripts/ntfy_listener.sh` | fork-modified | Hostname guard (`NTFY_ALLOWED_HOST=srv1121380`): exits if host doesn't match. Recognizes `cmd_complete` tag — instead of skipping outbound, wakes Shogun pane with completion notification. | Keep fork — no upstream equivalent |
| `scripts/send_test_email.py` | fork-added | Python script: sends test email via Gmail SMTP (TLS) to trigger n8n Gmail WF tests. Reads creds from `.env`. Supports `--subject`/`--body` overrides. | Keep fork — no upstream equivalent |
| `scripts/slim_yaml.py` | fork-modified | Adds `clean_old_snapshots()`: removes `queue/snapshots/*.yaml` older than 24h by mtime. Runs in `slim --all` path. Prevents unbounded snapshot accumulation. | Keep fork — no upstream equivalent |
| `scripts/update_dashboard_timestamp.sh` | fork-added | PostToolUse hook / manual script: rewrites `最終更新:` line in dashboard.md to current JST. Skips silently when edited file is not dashboard.md. | Keep fork — no upstream equivalent |
| `scripts/watcher_supervisor.sh` | fork-modified | Three additions: (1) flock-based PID-lock guard, (2) auto-start `cmd_complete_notifier.sh`, (3) `roll_call_check()` every 5 min detecting agents stuck on welcome screen and reviving them. | Merge upstream, preserve fork sections |
| `scripts/worktree_cleanup.sh` | fork-added | Safely removes git worktree for agent under `.trees/<agent_id>`: checks uncommitted changes, unlinks symlinks, prunes metadata. | Keep fork — no upstream equivalent |
| `scripts/worktree_create.sh` | fork-added | Creates git worktree at `.trees/<agent_id>` on new branch, symlinks shared runtime dirs (queue, logs, projects, dashboard.md) from main worktree. | Keep fork — no upstream equivalent |

## Category B: Library Files

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `lib/agent_status.sh` | fork-modified | Adds `is_cli_running()`: resolves pane's shell PID via `tmux list-panes`, checks for `claude` child process with `pgrep -P`. Used by watcher logic. | Merge upstream, preserve fork sections |
| `lib/cli_adapter.sh` | fork-modified | Adds `effort` field support to `build_cli_command()`: reads `cli.agents.<id>.effort` from settings YAML, prepends `CLAUDE_CODE_EFFORT_LEVEL=<value>` to command. Non-conflicting additive feature. | Merge upstream, preserve fork sections |

## Category C: Agent Instructions

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `instructions/ashigaru.md` | fork-modified | Adds: context snapshot steps (4.5, 6.3), expanded skill_candidate guidance with n8n heuristics, JST timestamp rule, report target switched to Gunshi, `suggestions.yaml` persistence, editable_files whitelist section, GChat Webhook send guidelines (`gchat_send.sh` usage), Fork Extensions (output naming, n8n fix protocol, internal parallelization). | Keep fork — no upstream equivalent |
| `instructions/common/worktree.md` | fork-added | Guide for git worktree-based parallel execution. Defines when to create worktrees, branch naming, dispatch procedure, merge workflow. From cmd_144 lesson. | Keep fork — no upstream equivalent |
| `instructions/generated/codex-karo.md` | fork-modified | Prepends 144-line YAML front-matter (role, F001-F006 forbidden actions, full workflow, pane map, inbox rules). Machine-readable config for Codex-based Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/copilot-karo.md` | fork-modified | Same YAML front-matter as codex-karo.md. Config for Copilot-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/generated/karo.md` | fork-modified | Same YAML front-matter. Config for default generated Karo. | Keep fork — no upstream equivalent |
| `instructions/generated/kimi-karo.md` | fork-modified | Same YAML front-matter. Config for Kimi-based Karo variant. | Keep fork — no upstream equivalent |
| `instructions/gunshi.md` | fork-modified | Adds: context snapshot steps, Autonomous QC Protocol (auto-QC on `report_received`), expanded F006 dashboard permissions, `suggestions.yaml` persistence (step 8.5), Bloom Analysis support, JST rule, Memory MCP write policy, QC checklist reference with auto_check integration, Fork Extensions (n8n QC criteria, Bloom routing docs). | Keep fork — no upstream equivalent |
| `instructions/karo.md` | fork-modified | Major restructuring: F006 added, workflow expanded with `yaml_slim` (1.5), `bloom_routing` (6.5), dashboard cleanup rules (descending order), SO-19 cmd_complete.sh at Step 11.7, `cmd_complete` tag ntfy, autonomous QC notes, skill suggestions, snapshot recovery, JST enforcement, editable_files mandatory in task YAML, `report_to: gunshi` default rule. | Keep fork — no upstream equivalent |
| `instructions/shogun.md` | fork-modified | Restructured to 2 core missions (translate intent + proactive detection). F006 blind_clear ban, stall_response_protocol (5-step), Proactive Detection & Reporting (3 triggers: session start, post-ntfy, idle), Memory MCP write policy. 477→331 lines. | Keep fork — no upstream equivalent |
| `instructions/skill_candidates.yaml` | fork-added | Registry of 46 skill candidates (SC-001 to SC-046) from cmd_134 to cmd_344. Tracks id, source, occurrences, status (created/merged/hold), evaluation, skill_path. | Keep fork — no upstream equivalent |
| `instructions/skill_policy.md` | fork-added | Formal skill lifecycle policy: creation criteria (2-occurrence threshold), reusability assessment, integration-vs-new decision matrix, file structure standards, maintenance rules. | Keep fork — no upstream equivalent |

## Category D: System Configuration

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `CLAUDE.md` | fork-modified | Major evolution: English-base with JA persona zones, VSCode/Pattern B branch, snapshot integration, global_context.md as Layer 1, Gunshi auto-QC protocol, dashboard tag taxonomy, SO-16 through SO-19, F006 stall response, Batch Processing Protocol, Critical Thinking Rules, test self-sufficiency, web-search obligation, Destructive Operation Safety tiers. | Manual review required |
| `AGENTS.md` | fork-modified | Same conceptual changes as CLAUDE.md adapted for Codex CLI context. VSCode branch identifies as "Codex CLI". | Merge upstream, preserve fork sections |
| `agents/default/system.md` | fork-modified | Same delta as CLAUDE.md adapted for Kimi K2 CLI context. | Merge upstream, preserve fork sections |
| `.github/copilot-instructions.md` | fork-modified | Same delta as CLAUDE.md adapted for GitHub Copilot CLI context. | Merge upstream, preserve fork sections |

## Category E: Config & Settings

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `.claude/settings.json` | fork-modified | Project-level settings: PreCompact hook (pre_compact_snapshot.sh), PostToolUse hooks moved from global (update_dashboard_timestamp.sh, ir1_editable_files_check.sh, log_violation.sh). VPS-specific absolute paths. | Keep fork — no upstream equivalent |
| `config/projects.yaml` | fork-added | Project registry: sample entry with id, name, path, priority, status, current_project fields. Referenced in CLAUDE.md `files:` map. | Keep fork — no upstream equivalent |
| `config/settings.yaml` | fork-added | Runtime config: language, shell, skill paths, logging, bloom routing mode, ntfy topic, screenshot path (WSL2), per-agent effort levels (max). VPS/WSL2-specific. | Keep fork — no upstream equivalent |
| `.gitignore` | fork-modified | Allow-lists newly added fork files (config/, scripts/hooks/, memory/skill_history.md, etc.) that would otherwise be git-ignored. | Keep fork — no upstream equivalent |

## Category F: Operational Data

| File | Change Type | Intent | Upstream Merge Guidance |
|------|-------------|--------|------------------------|
| `context/n8n-operations.md` | fork-added | n8n operational runbook: error notification WF architecture, ntfy topic, per-WF error workflow IDs, new-WF checklist. | Keep fork — no upstream equivalent |
| `memory/global_context.md` | fork-added | Persistent cross-session learning ledger (L001-L006): inbox atomicity, googlechat integration, UTC→JST, stall response, n8n technical notes. | Keep fork — no upstream equivalent |
| `memory/skill_history.md` | fork-added | Skill candidate archive: tracks creation/integration status and source cmd references. Managed by dashboard_rotate.sh and cmd_390 stocktake. | Keep fork — no upstream equivalent |
| `output/cmd_307_upstream_merge_plan.md` | fork-added | Planning doc for upstream v4.4.x merge. Now superseded by commit 7573f2c. | Keep fork — no upstream equivalent |
| `output/スキル/cmd_320_skills_evaluation_update.md` | fork-added | Skills stocktake: evaluates skill files for compression/consolidation. 530-line evaluation artifact. | Keep fork — no upstream equivalent |
| `queue/reports/ashigaru3_report.yaml` | fork-added | Live task report. Active operational state. | Keep fork — no upstream equivalent |
| `queue/reports/phase1_cleanup_broken_slugs.txt` | fork-added | File list output from SEO content batch job. Runtime artifact. | Keep fork — no upstream equivalent |
| `queue/tasks/ashigaru2.yaml` | fork-added | Live task YAML for ashigaru2. Active operational state, not a template. | Keep fork — no upstream equivalent |

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
| `shutsujin_departure.sh` | fork-modified | Three changes: (1) kessen mode applies Opus to karo with `--effort max`, (2) `tmux set-environment TZ "Asia/Tokyo"` for all panes, (3) model display name fix for kessen startup banner. | Keep fork — no upstream equivalent |

---

## Merge Guidance Summary

| Guidance | Count | Files |
|----------|-------|-------|
| Keep fork — no upstream equivalent | 51 | All fork-added files + fork-modified files with no upstream counterpart |
| Merge upstream, preserve fork sections | 8 | `inbox_watcher.sh`, `watcher_supervisor.sh`, `lib/agent_status.sh`, `lib/cli_adapter.sh`, `AGENTS.md`, `agents/default/system.md`, `.github/copilot-instructions.md`, `tests/e2e/e2e_bloom_routing.bats`, `tests/unit/test_dynamic_model_routing.bats`, `tests/unit/test_send_wakeup.bats` |
| Accept upstream changes | 1 | `tests/e2e/e2e_codex_startup.bats` |
| Manual review required | 1 | `CLAUDE.md` (core config, both sides actively modify) |

**CLAUDE.md** is the highest-risk merge target: both fork and upstream actively modify this file. On merge, preserve fork's Pattern B branch, snapshot system, Gunshi auto-QC, SO-16 through SO-19, F006, Batch Processing Protocol, Critical Thinking Rules, and dashboard tag taxonomy while accepting upstream structural/procedural updates.
