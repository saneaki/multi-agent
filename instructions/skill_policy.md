# Skill Policy

> Formal policy for skill creation, management, and lifecycle in the Shogun system.
>
> Reference: cmd_143 methodology research (output/cmd_143_skill_methodology_research.md §7)
> Confirmed by Lord's directive (cmd_146).

---

## Shogun Evaluation Workflow

When evaluating or creating skills, Shogun follows this 5-step process:

1. **Research latest spec** (mandatory — do not skip)
2. **Judge as world-class Skills specialist**
3. **Create skill design doc**
4. **Record in dashboard.md for approval**
5. **After approval, instruct Karo to create**

---

## 1. Skill Creation Criteria

### Decision Flow

```
Same pattern occurs
  │
  ├─ 1st occurrence: Record as incident
  │    (cmd_xxx notes / skill_candidate: flag in ashigaru report)
  │
  └─ 2nd occurrence: Execute skill creation
```

### Reusability Assessment (all 3 must be considered)

1. **Cross-project applicability**: Can this pattern be applied across multiple projects?
2. **Longevity**: Is the pattern resistant to obsolescence over time? (Design patterns > framework-specific tricks)
3. **Agent accessibility**: Can other agents (ashigaru) effectively use this knowledge? (Tacit knowledge → formalized knowledge)

### Workflow

- **1st occurrence**: Record the incident in cmd notes. Add `skill_candidate: true` flag in ashigaru report YAML if applicable.
- **2nd occurrence**: Proceed with skill creation. Use existing patterns and verified solutions.

---

## 2. SKILL.md Constraints

| Constraint | Value | Notes |
|-----------|-------|-------|
| Maximum lines | **500 lines** | Strictly enforced |
| Description length | **400 characters max** | Per language (English + Japanese) |
| Overflow handling | Split to auxiliary files | examples.md, patterns.md, etc. |

### Overflow Strategy

When SKILL.md exceeds 500 lines:

1. Extract code examples → `examples.md`
2. Extract detailed patterns → `patterns.md`
3. Extract edge cases → `edge-cases.md`
4. Keep SKILL.md as the concise reference with links to auxiliary files

---

## 3. Language Policy (Lord's Directive)

### SKILL.md Body

- **Written in English**

### Japanese Documentation

- Create `README.ja.md` in the same directory
- Placement:

  ```
  skills/shogun-{topic}/
  ├── SKILL.md        # English
  └── README.ja.md    # Japanese
  ```

### Description (YAML Frontmatter)

- **Bilingual**: English and Japanese side by side
- Format:

  ```yaml
  description: |
    [English] Use when {trigger}. {summary}.
    [日本語] {トリガー}の時に使用。{概要}。
  ```

### Code Examples and Technical Terms

- Keep in English (no translation needed)

---

## 4. Tool Usage

### /learn

- **When**: After resolving incidents, run immediately
- **Output**: Saved to `learned/` directory
- **Promotion**: On 2nd occurrence of the same pattern, promote to `shogun-{topic}/` skill

### /skill-create

- **When**: Upon joining a new project, or periodically
- **Purpose**: Discover patterns from Git history
- **Output**: Draft skills that require review and refinement

### skill_candidate (Ashigaru Report)

- **Flow**:
    1. Ashigaru identifies a potential skill pattern during task execution
    2. Reports `skill_candidate:` field in report YAML with description
    3. Karo aggregates candidates in dashboard.md "スキル化候補" section
    4. Shogun reviews and approves/rejects
    5. Approved candidates proceed to skill design doc → creation

### Role Division

| Tool | Role | Quality | Speed |
|------|------|---------|-------|
| Manual (shogun-*) | Deep insights from critical incidents | High (verified) | Slow |
| /learn | Quick capture of moderate insights | Medium | Fast |
| /skill-create | Initial detection of cross-project patterns | Needs review | Fast |
| CL v2 + /evolve | Automatic unconscious pattern detection | Instinct-level | Automatic |

---

## 5. Directory Structure

```
skills/
├── (active skills)          # Active skill collection
│   ├── shogun-{topic}/      # Project-specific skills
│   │   ├── SKILL.md         # English
│   │   └── README.ja.md     # Japanese documentation
│   └── {ecc-skill}/         # ECC-derived general skills
│       └── SKILL.md
├── archived/                # Deprecated skills (recoverable)
└── learned/                 # Auto-learned (/learn, CL v2 output)
```

### Naming Conventions

| Type | Prefix | Example |
|------|--------|---------|
| Project-specific | `shogun-` | `shogun-docker-volume-recovery` |
| ECC-derived | (none) | `n8n-workflow-patterns` |
| Archived | moved to `archived/` | `archived/springboot-patterns/` |
| Learned | in `learned/` | `learned/api-retry-pattern` |

---

## 6. Format Standard

### Template (English)

```markdown
---
name: shogun-{topic}
description: |
  [English] Use when {trigger}. {summary}.
  [日本語] {トリガー}の時に使用。{概要}。
---

# {Skill Name}

## Problem Statement

{Why this skill is needed. 1-3 paragraphs.}

## Patterns

### Pattern 1: {Name}

{Specific solution with code examples.}

### Pattern 2: {Name} (if applicable)

{...}

## Verification

{Steps to confirm the pattern was correctly applied.}

## Battle-Tested Examples

| cmd | Situation | Result |
|-----|-----------|--------|
| cmd_xxx | {situation} | {outcome} |

## Source

- cmd_xxx: {summary}
```

### Section Requirements

| Section | Required | Notes |
|---------|----------|-------|
| YAML Frontmatter (name, description) | **Required** | Bilingual description |
| Problem Statement | **Required** | Why this skill exists |
| Patterns (min 1) | **Required** | Concrete solutions with code |
| Verification | Recommended | Confirmation steps |
| Battle-Tested Examples | Recommended | Real cmd_xxx usage |
| Source | Recommended | Traceability to incidents |

---

## 7. Integration Criteria

### When to Merge Skills

| Condition | Measurement | Example |
|-----------|-------------|---------|
| Always used together | Co-occurrence rate ≥ 80% in past 6 months | docker-volume-recovery + env-audit |
| Shared prerequisites | ≥ 70% overlap in prerequisite knowledge | n8n-validation-expert + n8n-node-configuration |
| Too small standalone | < 100 lines with low independent value | (evaluate case by case) |

### Integration Checklist

- [ ] Merged SKILL.md is ≤ 500 lines
- [ ] Descriptions from both source skills reflected in new description
- [ ] Consider splitting to auxiliary files (examples.md, etc.)
- [ ] No symlinks or redirects needed (complete replacement)

### Post-Integration Constraint

- Merged skill must remain ≤ 500 lines

---

## 8. Deprecation Criteria

### Deprecation Decision Flow

```
Quarterly Skill Review
  │
  ├─ Unused for 6+ months → Deprecation candidate
  │     ├─ Tech stack still active → Move to archived/ (recoverable)
  │     └─ Tech stack changed → Delete
  │
  ├─ Superior alternative exists → Create migration plan → Delete after migration
  │
  └─ Information outdated → Update or deprecate
```

### Review Schedule

- **Frequency**: Quarterly (every 3 months)
- **Scope**: All active skills
- **Reviewer**: Shogun (final decision), Karo (aggregation)

### Deprecation Actions

| Action | Target | Reversible |
|--------|--------|-----------|
| Move to `archived/` | Unused but potentially recoverable | Yes |
| Delete | Tech stack no longer in use | No |
| Update | Outdated information | N/A |

---

## Changelog

| Date | Change | cmd |
|------|--------|-----|
| 2026-02-15 | Initial creation | cmd_146 |
| 2026-02-15 | Moved to instructions/, added Shogun Evaluation Workflow | cmd_147 |
