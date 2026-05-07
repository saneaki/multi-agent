# cmd_663 Scope B: .claude Skill Codex Compatibility Report

## Executive Summary

Scope B conclusion: the skill asset base is mostly reusable in Codex, but not through Claude Code's native skill loader. Codex has no `/skill-name` invocation and no Claude Code Skill tool. The practical path is to treat `SKILL.md` as structured Markdown knowledge and load it explicitly via Read/mention, or to promote stable skill rules into `AGENTS.md` / generated role instructions.

Inventory result:

| Source | Entries | Unique treatment |
|---|---:|---|
| `~/.claude/skills/` direct skill dirs, including project symlinks | 232 | Primary global inventory |
| `skills/` project skill dirs | 23 | All 23 duplicate names already visible from `~/.claude/skills/` |
| Unique skill names | 232 | Compatibility matrix target |

Compatibility result:

| Rating | Count | Meaning |
|---|---:|---|
| ◎ | 197 | Usable as-is by reading Markdown; no Claude Code runtime dependency is central |
| ○ | 29 | Usable after adapting tool names, hook setup, MCP configuration, or scripts |
| × | 6 | Not directly usable because the core workflow depends on Claude Code slash/subagent orchestration |

## Category Inventory

| Category | Count | Compatibility tendency |
|---|---:|---|
| n8n / automation | 41 | Mostly ◎. n8n pattern skills are Markdown-heavy; `n8n-mcp-tools-expert` is ○ because MCP names/config need Codex mapping. |
| shogun ops | 39 | Mixed ◎/○. Operational knowledge is reusable; hook/tmux/model-switch skills need Codex-specific command mapping. |
| language / framework | 38 | Nearly all ◎. These are coding/testing patterns independent of Claude Code. |
| development workflow | 37 | Mostly ◎. Multi-backend and hook-enforced workflows are ○. |
| general knowledge / utility | 28 | Mostly ◎. Tooling/setup utilities may require path or command adaptation. |
| orchestration / agent ops | 25 | Highest risk. Several are × because they rely on slash commands or Claude Code Task/Agent semantics. |
| research / business / media | 24 | Mostly ◎/○. Research/MCP-heavy skills need configured Codex MCP servers. |

## Codex Loading Methods

| Method | Works in Codex? | Best use | Limitation |
|---|---|---|---|
| Claude Code `/skill-name` / Skill tool | No | None in Codex | Codex has no native Claude skill registry or slash skill dispatcher. |
| Read `SKILL.md` directly | Yes | One-off task execution, audits, compatibility review | Activation is manual; Codex will not auto-trigger from the skill description. |
| Mention/attach skill file | Yes | TUI workflows where a specific skill file should enter context | Still manual and context-costly for large skills. |
| Copy durable rules into `AGENTS.md` | Yes | Always-on rules, role recovery, destructive safety, communication protocol | Large AGENTS files hit context caps; use only stable high-value rules. |
| Generated role instructions from selected skills | Yes | Shogun-specific operational skills | Requires build process and ownership over update cadence. |
| Codex MCP configuration in `~/.codex/config.toml` | Yes | MCP-backed skills such as n8n, exa, firecrawl, GitHub | Tool names and auth differ from Claude Code configs. |

## Compatibility Matrix

| Skill / category | Rating | Codex handling |
|---|---|---|
| language/framework skills: `python-patterns`, `python-testing`, `django-*`, `go-*`, `kotlin-*`, `springboot-*`, `swift-*`, `cpp-*`, `perl-*` | ◎ | Read the Markdown and apply the patterns directly. No skill runtime needed. |
| n8n pattern skills: `n8n-expression-syntax`, `n8n-code-javascript`, `n8n-validation-expert`, `shogun-n8n-*` | ◎ | Mostly procedural/reference Markdown; Codex can use them after reading. |
| shogun incident/pattern skills: `shogun-dashboard-sync-silent-failure-pattern`, `shogun-snapshot-schema-multi-source-fallback`, `shogun-switch-cli-yaml-update-guard` | ◎ | Directly reusable as operational knowledge. |
| development workflow skills: `tdd-workflow`, `security-review`, `quality-gate`, `test-coverage`, `deployment-patterns`, `github-actions-*` | ◎ | Directly usable; map Claude tool examples to Codex shell/read/edit operations when needed. |
| research/business Markdown skills: `market-research`, `article-writing`, `seo-content-audit`, `visa-doc-translate`, `fact-check-with-notebooklm` | ◎ | Usable as checklists/workflows; current-data claims still require live source verification. |
| `n8n-mcp-tools-expert` | ○ | Valuable, but tool names and n8n MCP availability must be mapped to Codex MCP config. |
| `deep-research` | ○ | Use the research plan, but replace Claude Code Task-subagent parallelism with Codex local workflow or explicit delegated agents only when allowed. |
| `continuous-learning-v2`, `strategic-compact`, `shogun-precompact-snapshot-e2e-pattern` | ○ | Hook/session logic is Claude-oriented; concepts transfer, implementation needs Codex hook or file-based equivalent. |
| `shogun-model-switch`, `shogun-agent-status`, `shogun-tmux-busy-aware-send-keys`, `shogun-screenshot` | ○ | Project scripts can run in Codex, but CLI idle detection, send-keys behavior, and tool names need Codex-aware branches. |
| `multi-plan`, `multi-execute`, `multi-frontend`, `multi-backend` | ○ | Prompt/workflow structure is useful; wrappers under `~/.claude/bin` and `/ccg:*` references require adaptation. |
| `skill-creator`, `skill-create`, `skill-creation-workflow` | ○ | SKILL.md design knowledge is reusable; Claude-specific frontmatter such as `allowed-tools`, slash invocation, `context: fork`, and `agent:` should be documented as non-Codex fields. |
| `orchestrate` | × | Core operation is `/orchestrate` plus sequential Claude agents; Codex has no equivalent skill slash dispatcher. |
| `multi-workflow` | × | Core operation depends on Claude-managed multi-agent workflow commands and wrappers. |
| `dmux-workflows` | × | Assumes Claude Code-style dmux/workflow command integration. |
| `autonomous-loops` | × | Core value depends on Claude Code loop automation semantics rather than portable Markdown instructions. |
| `skill-stocktake` | × | Designed as a slash command audit flow with Agent invocation; requires redesign for Codex. |
| Claude Code hook/debug skills as a class, e.g. `shogun-claude-code-posttooluse-hook-guard` | × for direct use, ○ for concepts | Direct debugging target is Claude Code hooks; Codex can reuse only the diagnostic pattern, not the hook mechanics. |

## Top 10 Immediately Useful Skills for Codex

1. `codex-cli-poc-verification` — already documents Codex startup/integration checks.
2. `shogun-agent-status` — useful operational script wrapper; Codex-aware by description.
3. `shogun-n8n-wf-analyzer` — high-value n8n workflow analysis pattern, pure Markdown.
4. `n8n-expression-syntax` — frequent n8n failure class, directly reusable.
5. `n8n-validation-expert` — validation checklist remains valuable with Codex.
6. `python-testing` — direct unit-test guidance with no Claude runtime dependency.
7. `security-review` — review rubric transfers directly to Codex review work.
8. `github-actions-docs-check-template` — GHA troubleshooting pattern, shell-friendly.
9. `shogun-dashboard-sync-silent-failure-pattern` — local incident knowledge, Codex can read and apply.
10. `skill-creator` — useful for designing portable future skills, with Codex compatibility notes.

## Skills Not Directly Usable and Why

| Skill | Reason |
|---|---|
| `orchestrate` | Depends on `/orchestrate` and Claude Code agent chaining. |
| `multi-workflow` | Depends on Claude command/wrapper workflow and planned handoff files under `.claude/plan`. |
| `dmux-workflows` | Assumes dmux/Claude workflow integration rather than portable Codex steps. |
| `autonomous-loops` | Automation semantics are bound to Claude Code loop behavior. |
| `skill-stocktake` | Slash command and Agent invocation are core to the workflow. |
| `shogun-claude-code-posttooluse-hook-guard` | Direct target is Claude Code PostToolUse hook behavior; Codex can reuse only lessons by analogy. |

## Full Inventory by Category

### n8n / automation (41)

`n8n-api-deploy`, `n8n-code-javascript`, `n8n-code-python`, `n8n-credential-oauth-refresh`, `n8n-daily-guard-pattern`, `n8n-drive-ai-text-injection`, `n8n-expression-syntax`, `n8n-gcal-api-pagination-guard`, `n8n-gmail-subject-case-sensitivity`, `n8n-google-sheets-rate-limit`, `n8n-http-credential-patterns`, `n8n-mcp-tools-expert`, `n8n-node-configuration`, `n8n-pipeline-cut-guard`, `n8n-trigger-stuck-recovery`, `n8n-validation-expert`, `n8n-workflow-patterns`, `shogun-n8n-api-field-constraints`, `shogun-n8n-cron-stagger`, `shogun-n8n-docx-text-extraction`, `shogun-n8n-env-access-guard`, `shogun-n8n-expression-brace-guard`, `shogun-n8n-filesystem-v2-binary`, `shogun-n8n-gemini-pdf-analysis`, `shogun-n8n-gmail-id-archive-pattern`, `shogun-n8n-gmail-trigger-cron-step-guard`, `shogun-n8n-http-request-version-guard`, `shogun-n8n-jq-false-alternative-guard`, `shogun-n8n-manual-execution-api`, `shogun-n8n-merge-either-or-branch`, `shogun-n8n-notion-property-sync`, `shogun-n8n-notion-trigger-v1-flat-access`, `shogun-n8n-sib-trigger-incompatibility`, `shogun-n8n-telegram-digest`, `shogun-n8n-telegram-markdown-escape`, `shogun-n8n-telegram-plaintext-fallback`, `shogun-n8n-trigger-stuck-recovery`, `shogun-n8n-wf-analyzer`, `shogun-n8n-wf-version-switch-checklist`, `shogun-n8n-wf-versioning`, `shogun-n8n-workflow-upgrade`.

### shogun ops (39)

`pdfmerged-feature-release-workflow`, `s-check`, `semantic-gap-diagnosis`, `shogun-agent-status`, `shogun-bash-cross-platform-ci`, `shogun-bash-daemon-restart-subcommand-pattern`, `shogun-bloom-config`, `shogun-claude-code-posttooluse-hook-guard`, `shogun-compaction-log-analysis`, `shogun-dashboard-sync-silent-failure-pattern`, `shogun-decision-notify-pattern`, `shogun-docker-volume-recovery`, `shogun-error-fix-dual-review`, `shogun-gas-automated-verification`, `shogun-gas-backfill-pattern`, `shogun-gas-clasp-rapt-reauth-fallback`, `shogun-gas-jsdoc-reference`, `shogun-gas-release-workflow`, `shogun-gemini-thinking-token-guard`, `shogun-github-issue-knowledge-base`, `shogun-ir1-implicit-allowlist-pattern`, `shogun-labor-status-case-analysis`, `shogun-model-list`, `shogun-model-switch`, `shogun-notion-db-id-validator`, `shogun-notion-dual-property-relation`, `shogun-notion-github-issue-sync`, `shogun-notion-inline-db-api-version`, `shogun-notion-multi-source-db`, `shogun-obsidian-legal-templater-design`, `shogun-precompact-snapshot-e2e-pattern`, `shogun-readme-sync`, `shogun-repo-workspace-setup`, `shogun-screenshot`, `shogun-snapshot-schema-multi-source-fallback`, `shogun-switch-cli-yaml-update-guard`, `shogun-systemd-user-cron-healthcheck-pattern`, `shogun-tmux-busy-aware-send-keys`, `shogun-traefik-docker-label-guard`.

### language / framework (38)

`android-clean-architecture`, `compose-multiplatform-patterns`, `cpp-coding-standards`, `cpp-testing`, `django-patterns`, `django-security`, `django-tdd`, `django-verification`, `go-build`, `go-review`, `go-test`, `golang-patterns`, `golang-testing`, `java-coding-standards`, `jpa-patterns`, `kotlin-build`, `kotlin-coroutines-flows`, `kotlin-exposed-patterns`, `kotlin-ktor-patterns`, `kotlin-patterns`, `kotlin-review`, `kotlin-testing`, `perl-patterns`, `perl-security`, `perl-testing`, `python-patterns`, `python-testing`, `python-utf8-errors-replace`, `springboot-patterns`, `springboot-security`, `springboot-tdd`, `springboot-verification`, `swift-actor-persistence`, `swift-concurrency-6-2`, `swift-protocol-di-testing`, `swiftui-patterns`, `tkinter-help-system`, `tkinter-segment-operation`.

### development workflow (37)

`api-design`, `backend-patterns`, `build-fix`, `codex-cli-poc-verification`, `coding-standards`, `database-migrations`, `deployment-patterns`, `docker-patterns`, `docs-up`, `e2e-testing`, `frontend-patterns`, `frontend-slides`, `github-actions-docs-check-template`, `github-actions-powershell-continueonerror`, `github-actions-release-artifact`, `github-release-notes-best-practices`, `github-release-version-migration`, `gradle-build`, `multi-backend`, `multi-frontend`, `pandoc-gha-multiformat-docs`, `plankton-code-quality`, `postgres-patterns`, `pub`, `pub-us`, `pull-build`, `pull-merge-pub`, `pyinstaller-exe-smoke-test-pattern`, `pytest-migration`, `quality-gate`, `quality-nonconformance`, `security-review`, `security-scan`, `tdd-workflow`, `test-coverage`, `update-docs`, `verification-loop`.

### general knowledge / utility (28)

`ai-first-engineering`, `aside`, `bash-crlf-write-tool-guard`, `blueprint`, `bypass-permissions-write-fix`, `claude-api`, `claude-md-improver`, `clickhouse-io`, `configure-ecc`, `cost-aware-llm-pipeline`, `crosspost`, `eval-harness`, `foundation-models-on-device`, `iterative-retrieval`, `learn-eval`, `liquid-glass-design`, `nanoclaw-repl`, `notion-session-log-section-pattern`, `nutrient-document-processing`, `pm2`, `prompt-optimizer`, `pyinstaller-pymupdf-dll-bundling`, `ralphinho-rfc-pipeline`, `regex-vs-llm-structured-text`, `search-first`, `shift-left-validation-pattern`, `update-codemaps`, `usc`.

### orchestration / agent ops (25)

`agent-harness-construction`, `agentic-engineering`, `autonomous-loops`, `checkpoint`, `continuous-agent-loop`, `continuous-learning-v2`, `dmux-workflows`, `enterprise-agent-ops`, `loop-start`, `loop-status`, `model-route`, `multi-execute`, `multi-plan`, `multi-workflow`, `orchestrate`, `plan`, `resume-session`, `save-session`, `sessions`, `skill-create`, `skill-creation-workflow`, `skill-creator`, `skill-stocktake`, `strategic-compact`, `inventory-demand-planning`.

### research / business / media (24)

`article-writing`, `carrier-relationship-management`, `content-engine`, `content-hash-cache-pattern`, `customs-trade-compliance`, `deep-research`, `energy-procurement`, `exa-search`, `fact-check-with-notebooklm`, `fal-ai-media`, `investor-materials`, `investor-outreach`, `legal-document-namer`, `legal-ivr-flow-design-pattern`, `logistics-exception-management`, `market-research`, `production-scheduling`, `project-guidelines-example`, `returns-reverse-logistics`, `seo-content-audit`, `video-editing`, `videodb`, `visa-doc-translate`, `x-api`.

## Recommendation

Do not copy all 232 skills into `AGENTS.md`. Use a two-tier Codex strategy:

1. Keep the complete skill library as files and load per task by explicit Read/mention.
2. Promote only high-frequency, safety-critical shogun skills into generated Codex role instructions.
3. Create a small Codex skill index file mapping trigger phrases to `SKILL.md` paths, because Codex lacks Claude Code's automatic skill activation.
4. Convert the 6 direct-incompatible skills only if their workflows remain strategically important; otherwise leave them Claude-only.

