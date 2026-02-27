# Worktree Parallelization Guide

> Karo: worktreeを使う場合はこのファイルを参照せよ。
> Ashigaru: `target_worktree: true` タスクYAMLを受けた場合はこのファイルを参照せよ。

---

## Worktree Parallelization Checklist (mandatory during task decomposition)

After receiving a cmd, verify the following before assigning to 足軽:

1. **Verify Phase/subtask independence**
   - Design doc states "independent", "no dependencies", "no ordering constraints between Phases" → **worktree parallelization required**
   - Each Phase edits different file sets → **consider worktree parallelization first**
   - Each Phase edits different sections of the same file → RACE-001 applies, single 足軽

2. **Build a file dependency matrix**
   - List the target files for each subtask
   - No overlapping files → worktree parallelization possible
   - Overlapping files → evaluate RACE-001 risk (can sections be separated?)

3. **Decision flow**
   ```
   Independent Phases × different files → worktree parallelization (required)
   Independent Phases × same file → single 足軽 (RACE-001)
   Dependent Phases → blocked_by ordering constraint
   ```

4. **Lesson learned (cmd_144)**: Despite independent Phases being explicitly stated, sequential execution by a single 足軽 was chosen citing file dependencies. In reality, Phase splitting + worktree parallelization was possible. Use the tools you've built (worktree infrastructure from cmd_126-129) proactively.

---

## Worktree Usage Decision Criteria

| Condition | Decision | Reason |
|------|------|------|
| **Design doc specifies multiple independent Phases** | **Use (mandatory)** | Speed improvement via parallelization. Leverage the built tooling |
| Multiple Ashigaru edit same file area within one cmd | **Use** | RACE-001 avoidance (branch isolation) |
| Work on external project (non multi-agent repo) | **Use** | Prevent main worktree contamination |
| High RACE-001 risk but want parallelization | **Use** | Safe parallelization via branch isolation |
| Ashigaru edit different files (normal operation) | Do not use | Current approach is sufficient |
| Single Ashigaru assignment | Do not use | Worktree overhead unnecessary |

---

## Task YAML Notation

```yaml
task:
  task_id: subtask_XXX
  parent_cmd: cmd_XXX
  bloom_level: L3
  target_worktree: true
  branch: agent/ashigaru{N}/cmd_{CMD_ID}
```

- `target_worktree: true` → Karo runs worktree_create.sh before dispatch
- `branch:` → Follow branch naming convention

---

## Branch Naming Convention

| Pattern | Format | Example |
|---------|------|-----|
| Standard | `agent/ashigaru{N}/cmd_{CMD_ID}` | `agent/ashigaru3/cmd_130` |
| Per-subtask | `agent/ashigaru{N}/subtask_{TASK_ID}` | `agent/ashigaru1/subtask_130a` |

---

## Worktree Dispatch Procedure

Execute the following in addition to normal dispatch (Steps 5-7):

```
STEP 5.5: Create worktree
  bash scripts/worktree_create.sh ashigaru{N} agent/ashigaru{N}/cmd_{CMD_ID}
  Note: Symlinks auto-created: queue/, logs/, dashboard.md → main worktree

STEP 6: Write task YAML (as usual)
STEP 7: inbox_write (as usual)
```

---

## Karo's Merge Workflow

After receiving completion report from Ashigaru:

```
a. Review report content and quality (normal report processing)
b. cd /home/ubuntu/shogun (move to main worktree)
c. git merge <ashigaru-branch-name>
   Note: Fast-forward merge is standard (worktree branches from same commit)
d. If conflict occurs → resolve manually
e. Verify merge: git log --oneline -3
f. bash scripts/worktree_cleanup.sh <agent_id>
g. Confirm clean state with git status
```

---

## Self-Run Test Tools

Tests must be completed within the task by Ashigaru — do not request the Lord to run them.

| Tool | Purpose | Usage |
|--------|------|--------|
| `scripts/send_test_email.py` | Trigger Gmail WF | `python3 scripts/send_test_email.py` (hananoen→grace-law) |
| n8n Execution API | Check WF execution results | `GET /api/v1/executions?workflowId={id}&limit=3` |
| n8n Execution Detail | Check per-node success/failure | `GET /api/v1/executions/{id}?includeData=true` |

- Auth credentials (App Password, etc.): `/home/ubuntu/.n8n-mcp/n8n/.env`
- send_test_email.py supports `--subject` and `--body` options for customization
- After sending a test email, the Gmail Trigger polls every minute — wait up to 60 seconds before checking execution
