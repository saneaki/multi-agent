# Canonical Rule Sources

> **Purpose**: Define the single authoritative source (canonical) for every rule topic in the shogun multi-agent system.
> Phase 1 enforcement must not enforce drifted rules — when multiple files mention the same rule, this document tells you which one is the source of truth.
>
> **Created**: 2026-04-24 (cmd_570 Scope A)
> **Maintained by**: ashigaru5 via karo-issued cmd; non-trivial updates require Shogun approval.
> **Scope**: project-level rules (shogun/). User-global rules under `~/.claude/` are a separate layer and are out of scope.

---

## 1. File Type Classification

The shogun rule corpus is organised in four tiers:

| Tier | Path | Role | Mutability |
|------|------|------|------------|
| **Entry Point** (CLI auto-load) | `shogun/CLAUDE.md`, `shogun/AGENTS.md`, `.github/copilot-instructions.md`, `agents/default/system.md` | First file each CLI auto-loads. Holds session-start procedures, short rules, and pointers to Detail Sources. | `CLAUDE.md` = **SOURCE** (edit here). Others = **GENERATED** (F006 — never edit directly). |
| **Detail Source** | `instructions/common/*.md`, `instructions/roles/*.md`, `instructions/cli_specific/*.md` | Authoritative detailed definition of each topic. Referenced from Entry Points. | **SOURCE** (edit directly). |
| **Role Composite** (Claude only) | `instructions/shogun.md`, `instructions/karo.md`, `instructions/ashigaru.md`, `instructions/gunshi.md` | Top-level per-role instructions read after `CLAUDE.md`. Built from role content + scripts; historically hand-edited. | **SOURCE** (edit directly when updating role-specific policy). |
| **Generated Composite** | `instructions/generated/{cli}-{role}.md`, `instructions/generated/{role}.md` | Auto-generated combinations of role + common + cli_specific files. | **GENERATED** (F006 — never edit directly). |

**Build pipeline** (`scripts/build_instructions.sh`):

```
CLAUDE.md ─sed─▶ AGENTS.md (Codex auto-load)
CLAUDE.md ─sed─▶ .github/copilot-instructions.md (Copilot auto-load)
CLAUDE.md ─sed─▶ agents/default/system.md (Kimi auto-load)

roles/{role}_role.md + common/protocol.md + common/task_flow.md +
common/forbidden_actions.md + cli_specific/{cli}_tools.md
     ─cat─▶ instructions/generated/{cli-}{role}.md
```

Consequence: edits to `common/*.md` propagate to every generated composite on next build. Edits to `CLAUDE.md` propagate to all three CLI auto-load files.

---

## 2. Canonical Source Table

### Classification Criteria (SO scope)

- `cross-file rule`: the same SO rule is defined or referenced in 2 or more authoritative files.
- `qc-only rule`: the SO rule is listed only in `config/qc_checklist.yaml`.
- Decision procedure for newly added SO rules:
  1. Search `config/qc_checklist.yaml`, `instructions/common/shogun_mandatory.md`, and `CLAUDE.md` for the SO ID.
  2. If matches are found in 2 or more files, classify as `cross-file`; if only `qc_checklist.yaml` matches, classify as `qc-only`.
  3. Add or update the rule row in the SO scope table below.

### SO-01 to SO-24 Scope Table

| Rule | Topic | Canonical File | Location | Scope | Notes |
|------|-------|----------------|----------|-------|-------|
| **SO-01** | 報告YAML必須フィールド確認 | `config/qc_checklist.yaml` | Entry at line 10 | `qc-only` | QC checklist-only standing order. |
| **SO-02** | inbox処理プロトコル | `config/qc_checklist.yaml` | Entry at line 109 | `qc-only` | Conditional QC checklist rule. |
| **SO-03** | タイムスタンプJST形式 | `config/qc_checklist.yaml` | Entry at line 19 | `qc-only` | QC checklist-only standing order. |
| **SO-04** | ダッシュボード更新分担 | `config/qc_checklist.yaml` | Entry at line 118 | `qc-only` | Conditional QC checklist rule. |
| **SO-05** | 要対応ルール | `config/qc_checklist.yaml` | Entry at line 128 | `qc-only` | Conditional QC checklist rule. |
| **SO-06** | 報告フロー遵守(report_to: gunshi) | `config/qc_checklist.yaml` | Entry at line 28 | `qc-only` | QC checklist-only standing order. |
| **SO-07** | コマンドキュー管理 | `config/qc_checklist.yaml` | Entry at line 137 | `qc-only` | Conditional QC checklist rule. |
| **SO-08** | acceptance_criteria対応表 | `config/qc_checklist.yaml` | Entry at line 37 | `qc-only` | QC checklist-only standing order. |
| **SO-09** | Batch Processing Protocol | `config/qc_checklist.yaml` | Entry at line 146 | `qc-only` | Conditional QC checklist rule. |
| **SO-10** | テストSKIP=FAIL | `config/qc_checklist.yaml` | Entry at line 46 | `qc-only` | QC checklist-only standing order. |
| **SO-11** | suggestions永続化 | `config/qc_checklist.yaml` | Entry at line 155 | `qc-only` | Conditional QC checklist rule. |
| **SO-12** | コンテキストスナップショットclear | `config/qc_checklist.yaml` | Entry at line 164 | `qc-only` | Conditional QC checklist rule. |
| **SO-13** | Pre-Commit Gate | `config/qc_checklist.yaml` | Entry at line 173 | `qc-only` | Conditional QC checklist rule. |
| **SO-14** | Web検索義務 | `config/qc_checklist.yaml` | Entry at line 182 | `qc-only` | Conditional QC checklist rule. |
| **SO-15** | Stop-and-Report | `config/qc_checklist.yaml` | Entry at line 203 | `qc-only` | Conditional QC checklist rule. |
| **SO-16** | Report Delegation | `instructions/common/shogun_mandatory.md` | Rule 9 (line 13) | `cross-file` | Also in `config/qc_checklist.yaml:55` and `CLAUDE.md:212`. |
| **SO-17** | North Star Alignment | `instructions/common/shogun_mandatory.md` | Rule 10 (line 14) | `cross-file` | Also in `config/qc_checklist.yaml:64` and `CLAUDE.md:213`. |
| **SO-18** | Bug Fix Issue Tracking | `instructions/common/shogun_mandatory.md` | Rule 11 (line 15) | `cross-file` | Also in `config/qc_checklist.yaml:74` and `CLAUDE.md:214`. |
| **SO-19** | Completed Item Cleanup | `instructions/common/shogun_mandatory.md` | Rule 12 (line 16) | `cross-file` | Also in `config/qc_checklist.yaml:191` and `CLAUDE.md:215`. |
| **SO-20** | editable_files 完全性 | `config/qc_checklist.yaml` | Entry at line 84 | `qc-only` | Not in Shogun Mandatory list. Distinct from SO-24 despite historical typo. |
| **SO-21** | 成果物ファイル名prefix確認 | `config/qc_checklist.yaml` | Entry at line 95 | `qc-only` | Artifact naming check in QC only. |
| **SO-22** | n8n 機能検証 | `instructions/common/n8n_e2e_protocol.md` | §Layer A (line 23) | `cross-file` | Also in `config/qc_checklist.yaml:212`. AND-operated with SO-23. |
| **SO-23** | n8n 業務成果 | `instructions/common/n8n_e2e_protocol.md` | §Layer B (line 34) | `cross-file` | Also in `config/qc_checklist.yaml:224`. AND-operated with SO-22. |
| **SO-24** | Verification Before Report | `instructions/common/shogun_mandatory.md` | Rule 14 (line 18) | `cross-file` | Also in `CLAUDE.md:217`. |

### Dashboard Rule Registry

| Target | Rule Topic | Canonical Source | Status | Reference |
|--------|------------|------------------|--------|-----------|
| `dashboard.md` | dashboard記載ルール (8分類+時刻降順) | `output/cmd_576_dashboard_rules.md` | `active` | cmd_576+cmd_580追加済。時刻降順=戦果・進行中テーブルは最新が上。§(5)参照。進行中: Karo 一次 / Shogun 二次 (確認・修正)。 |

| Topic | Canonical File | Location | Notes |
|-------|----------------|----------|-------|
| **F001–F003** (role-specific forbidden actions) | `instructions/common/forbidden_actions.md` | §Shogun / §Karo / §Ashigaru tables (lines 12–34) | Each role has a different F001/F002/F003 meaning; the table is the single source. |
| **F004** Polling Prohibited | `instructions/common/forbidden_actions.md` | §Common table row (line 7) | Brief restatement in `CLAUDE.md §Common Rules` (line 227) is a reminder, not a definition. |
| **F005** Context Loading Skip Prohibited | `instructions/common/forbidden_actions.md` | §Common table row (line 8) | Brief restatement in `CLAUDE.md §Common Rules` (line 231) is a reminder. |
| **F006** Generated-file direct edit prohibited | `instructions/common/forbidden_actions.md` | §Common table row (line 9) | ⚠️ See Known Issues §6 — "F006" is currently overloaded. |
| **F007** `git push` without approval | `instructions/common/forbidden_actions.md` | §Common table row (line 10) | |
| **F008** GitHub scope restriction | `memory/global_context.md` | §F008 section | saneaki/obsidian 等 殿明示指示は例外適用可 |
| **F009** Communication Channel Mirror | `instructions/common/protocol.md` | §F009 section | 入口チャネル=返信チャネル。ntfy受信→ntfy返信必須。2026-04-28 追加 |
| **L016** Investigation Tasks dual-model | `instructions/karo.md` | §Investigation Tasks — Dual-Model Parallel Rule (L016) | 調査・設計分析は Opus+Codex 並列必須 |
| **L017** Test Execution dual-model | `instructions/common/protocol.md` | §Test Execution Rule: Dual-Model Parallel (L017) | テスト AC = Claude+Codex 並列必須。2026-04-28 追加 |
| **SO-16** Report Delegation | `instructions/common/shogun_mandatory.md` | Rule 9 (line 13) | Also enumerated in `config/qc_checklist.yaml:55`. |
| **SO-17** North Star Alignment | `instructions/common/shogun_mandatory.md` | Rule 10 (line 14) | Also `config/qc_checklist.yaml:64`. |
| **SO-18** Bug Fix Issue Tracking | `instructions/common/shogun_mandatory.md` | Rule 11 (line 15) | Also `config/qc_checklist.yaml:74`. |
| **SO-19** Completed Item Cleanup | `instructions/common/shogun_mandatory.md` | Rule 12 (line 16) | Also `config/qc_checklist.yaml:191`. |
| **SO-20** editable_files 完全性 | `config/qc_checklist.yaml` | Entry at line 84 | QC-only rule — not in Shogun Mandatory list. Distinct from SO-24 despite historical typo. |
| **SO-21** 成果物ファイル名prefix確認 | `config/qc_checklist.yaml` | Entry at line 95 | Artifact filenames must use `cmd_{N}_` prefix per QC naming check. |
| **SO-22** n8n 機能検証 | `instructions/common/n8n_e2e_protocol.md` | §Layer A (line 23) | Also `config/qc_checklist.yaml:212`. AND-operated with SO-23. |
| **SO-23** n8n 業務成果 | `instructions/common/n8n_e2e_protocol.md` | §Layer B (line 34) | Also `config/qc_checklist.yaml:224`. AND-operated with SO-22. |
| **SO-24** Verification Before Report | `instructions/common/shogun_mandatory.md` | Rule 14 (line 18) | Defines Shogun's three-way pre-report verification (inbox / artifact / content). |
| **D001–D008** Destructive Operations | `instructions/common/destructive_safety.md` | Table lines 9–16 | Tier-1 absolute ban list. |
| **RACE-001** Concurrent file write | `shogun/CLAUDE.md` §Common Rules | Lines 235–243 | No dedicated common/ file — definition lives inline in the Entry Point. `instructions/karo.md` and `instructions/ashigaru.md` reference it. |
| **Chain of Command** | `shogun/CLAUDE.md` frontmatter (line 7) + `instructions/common/shogun_mandatory.md` Rule 2 (line 6) | | Frontmatter declares the hierarchy; shogun_mandatory declares the "never bypass Karo" rule. |
| **Communication Protocol** | `instructions/common/protocol.md` | Full file | `CLAUDE.md §Communication Protocol` (line 146) is a pointer. `scripts/inbox_write.sh` usage is canonical here. |
| **Timestamp Rule** (UTC → JST, `jst_now.sh`) | `shogun/CLAUDE.md` §Common Rules | Lines 245–255 | No dedicated common/ file. |
| **File Operation Rule** (Read before Write/Edit) | `shogun/CLAUDE.md` §Common Rules | Lines 265–267 | Duplicate in `instructions/common/protocol.md` **removed 2026-04-24 (cmd_570 Scope A)**. |
| **Test Rules** (SKIP=FAIL / preflight / E2E = Karo / test self-sufficiency) | `shogun/CLAUDE.md` §Common Rules | Lines 269–278 | No dedicated common/ file — lives inline. |
| **Critical Thinking Rules** | `shogun/CLAUDE.md` §Common Rules | Lines 293–300 | No dedicated common/ file. Six enumerated rules including mandatory web search on 2nd-attempt failures. |
| **Agent() Tool Usage** (per role) | `shogun/CLAUDE.md` §Common Rules | Lines 221–225 | Ashigaru allowed; Karo artifact-generation forbidden (extends F003); Gunshi/Shogun role-specific. |
| **Artifact Registration Protocol** | `instructions/common/artifact_registration.md` | Full file | `CLAUDE.md §AR` (line 257) is a pointer. |
| **Context Snapshot** | `instructions/common/context_snapshot.md` | Full file | `CLAUDE.md §Context Snapshot` (line 151) is a pointer. |
| **Post-Compaction Recovery** | `instructions/common/compaction_recovery.md` | Full file | `CLAUDE.md §Post-Compaction Recovery` (line 141) is a pointer. |
| **Context Management Policy** (50 / 70 / 80 / 85 / 92%) | `instructions/common/context_management.md` | Full file | `CLAUDE.md §Context Management Policy` (lines 173–194) is a summary. |
| **Batch Processing** | `instructions/common/batch_processing.md` | Full file | `CLAUDE.md §Batch Processing Protocol` (line 284) is a pointer. |
| **Hook E2E Testing** | `instructions/common/hook_e2e_testing.md` | Full file | `CLAUDE.md §Hook E2E Testing Checklist` (line 280) is a pointer. |
| **Self Clear Protocol** (ashigaru) | `instructions/ashigaru.md` §Self Clear Protocol | Inline | `CLAUDE.md §Self Clear Protocol` (line 302) is a pointer. |
| **GUI Verification Protocol** (tkinter) | `instructions/common/gui_verification.md` | Full file | `CLAUDE.md §GUI Verification Protocol` (line 307) is a pointer. |
| **Memory Policy** | `instructions/common/memory_policy.md` | Full file | Governs `memory/global_context.md` vs Memory MCP usage. |
| **Compact Exception** | `instructions/common/memory_policy.md` + `instructions/common/compact_exception.md` | | Lists compaction-exempt files. |
| **Self-Watch Phase** | `instructions/common/self_watch_phase.md` | Full file | Gunshi/Karo self-observation protocol. |
| **Task Flow (status definitions)** | `instructions/common/task_flow.md` | Full file | Authoritative list of task status values (assigned / in_progress / done / blocked / etc.). `CLAUDE.md` L43 points here. |
| **Worktree usage** | `instructions/common/worktree.md` | Full file | |
| **Role-specific policy** (shogun / karo / gunshi / ashigaru) | `instructions/roles/{role}_role.md` + `instructions/{role}.md` | | `{role}_role.md` = core role. `{role}.md` = top-level role entry file (composes role + common sections for Claude CLI). |
| **CLI-specific tools** | `instructions/cli_specific/{cli}_tools.md` | | Per-CLI tool availability and constraints. |

---

## 3. Non-Canonical File Roles

Files in the system that are **references / summaries**, not authoritative sources:

| File | Role |
|------|------|
| `shogun/CLAUDE.md` §Shogun Mandatory Rules (lines 200–217) | Summary of `instructions/common/shogun_mandatory.md`. Use the shogun_mandatory.md version when wording conflicts. |
| `shogun/CLAUDE.md` §Communication Protocol (lines 146–149) | Pointer to `instructions/common/protocol.md`. |
| `shogun/CLAUDE.md` §Destructive Operation Safety (lines 312–325) | Summary of `instructions/common/destructive_safety.md`. |
| `shogun/AGENTS.md` | **Generated from CLAUDE.md** — edit CLAUDE.md (or the relevant common/ file) and re-run `scripts/build_instructions.sh`. |
| `.github/copilot-instructions.md` | Generated from CLAUDE.md (Copilot auto-load). F006 protected. |
| `agents/default/system.md`, `agents/default/agent.yaml` | Generated from CLAUDE.md (Kimi auto-load). F006 protected. |
| `instructions/generated/*.md` | Generated composites (role + common + cli_specific). F006 protected. |
| `memory/Violation.md` | Historical incident log. Not a rule source; cross-references canonical files by F/SO/D IDs. |
| `memory/global_context.md` | Learning notes (append-only). Not a rule source. |

---

## 4. Update Policy

When a rule changes, follow this order:

1. **Identify the canonical file** from §2. If the rule is not listed, add a row to the table first.
2. **Edit only the canonical file.** Do not duplicate text into reminders or pointers unless the wording is trivially short (one sentence).
3. **Update summaries / pointers** (e.g. `CLAUDE.md §X`) only if the wording or section number changed. Never restate the definition in a summary.
4. **Regenerate** downstream files:
   - `CLAUDE.md` change → `bash scripts/build_instructions.sh` (regenerates AGENTS.md, copilot-instructions.md, system.md).
   - `common/*.md` change → `bash scripts/build_instructions.sh` (regenerates `instructions/generated/*.md`).
5. **Commit** both source + generated changes in the same commit so CI "Build Instructions Check" passes.
6. **If you renumber a rule** (e.g. SO-20 → SO-24), search-replace across all referencing files including pointers, incident logs, and QC checklists. Leave a redirect note in this file if the old number is still referenced historically.

**Never** edit F006-protected generated files directly. Even a one-character fix in `AGENTS.md` or `instructions/generated/*.md` will be overwritten on the next build.

---

## 5. Inconsistencies resolved by cmd_570 Scope A

| ID | Issue | Resolution |
|----|-------|------------|
| INC-1 | `shogun/AGENTS.md:217` said "SO-20" while `CLAUDE.md:217` and `shogun_mandatory.md:18` said "SO-24". Stale after CLAUDE.md update, AGENTS.md never regenerated. | Re-ran `scripts/build_instructions.sh`. AGENTS.md, `.github/copilot-instructions.md`, `agents/default/system.md` now all show SO-24. |
| INC-2 | "File Operation Rule" (Always Read before Write/Edit) duplicated in three places: `CLAUDE.md:265-267`, `AGENTS.md:265-267`, `instructions/common/protocol.md:110-112`. The protocol.md copy was topically out of place (Communication Protocol file). | Removed the section from `protocol.md`; replaced with an HTML-comment pointer to CLAUDE.md §Common Rules. CLAUDE.md and AGENTS.md retain their CLI-variant copies (Claude Code vs Codex CLI wording). |

---

## 6. Known Issues (deferred)

| ID | Issue | Owner / Deferral |
|----|-------|------------------|
| **KI-1: "F006" dual definition** | `instructions/common/forbidden_actions.md:9` defines **F006 = "Edit generated files directly"**, while `instructions/common/shogun_mandatory.md:12` and `CLAUDE.md:211` label **"Stall Response"** as F006. Two different rules share the same ID. | **Deferred to cmd_571** (task_570a scope explicitly excludes this). cmd_571 will renumber one of them and update all references. |
| **KI-2: SO-20 in `config/qc_checklist.yaml`** | SO-20 = "editable_files 完全性" lives in `config/qc_checklist.yaml:84`, which is conceptually different from the SO-24 (Verification Before Report) rule once mistakenly labelled SO-20 in AGENTS.md. | **Deferred to cmd_572** (task_570a scope explicitly excludes this). cmd_572 will verify qc_checklist's SO-20 is the only meaning of SO-20 going forward. |

---

## 7. Verification Queries (for regression checks)

Run these greps to detect drift after any rule edit:

```bash
# 1) SO-xx consistency between entry point and source of truth
grep -n "SO-[0-9]\{2\}" shogun/CLAUDE.md shogun/AGENTS.md \
  instructions/common/shogun_mandatory.md config/qc_checklist.yaml

# 2) F001-F007 cross-file references
grep -rn "F00[1-7]" shogun/CLAUDE.md shogun/AGENTS.md \
  instructions/common/ instructions/roles/

# 3) Generated-file staleness (CI also runs this)
bash scripts/build_instructions.sh
git diff --stat instructions/generated/ AGENTS.md .github/copilot-instructions.md agents/default/

# 4) Orphan topics in CLAUDE.md §Common Rules with no canonical file
grep -nE "^## " shogun/CLAUDE.md | grep -v "See \["
```

If (3) prints any diff after a clean run, generated files are stale: commit the rebuild before merging.

---

## 8. Version Log

| Date | cmd | Change |
|------|-----|--------|
| 2026-04-24 | cmd_570 Scope A (ashigaru5) | Document created. §5 INC-1 / INC-2 resolved. §6 KI-1 / KI-2 deferred to cmd_571 / cmd_572. |
