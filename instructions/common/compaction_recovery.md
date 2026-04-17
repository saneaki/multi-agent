# Compaction Recovery (all agents)

When compaction/auto-compact fires, work context is lost. Use the following procedure to recover from primary data sources.

## Common Steps

1. **Confirm Agent ID**: `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` (shogun can skip — identity is known)
2. **Read Snapshot**: `queue/snapshots/{your_id}_snapshot.yaml` (if exists)
   - Restore approach / progress / decisions / blockers from `agent_context`
   - Verify `task.task_id` matches current task YAML — on mismatch, discard snapshot
3. **Read Task YAML**: `queue/tasks/{your_id}.yaml` (shogun uses `queue/shogun_to_karo.yaml`)
   - `assigned` → resume work using recovered context
   - `done` / `idle` → await next instruction
4. **Memory MCP** (shogun / karo / gunshi): `mcp__memory__read_graph` to restore Lord's preferences + incident lessons
5. **Project context**: if task has `project:` field → read `context/{project}.md`
6. **dashboard.md is secondary** — may be stale after compaction. YAML is ground truth

## Role-Specific Additions

- **shogun**: Check every cmd status in `queue/shogun_to_karo.yaml` + read `config/projects.yaml`
- **karo**: Scan all ashigaru assignments in `queue/tasks/` + unprocessed reports in `queue/reports/` + reconcile dashboard.md with YAML
- **ashigaru** / **gunshi**: Common steps above are sufficient

## After Resuming Work

Run `scripts/context_snapshot.sh write {your_id} "<approach>" "<progress>" "<decisions>" "<blockers>"` to write a fresh agent_context snapshot.
