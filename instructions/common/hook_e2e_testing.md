# Hook E2E Testing Checklist

E2E verification steps for Hooks (PreCompact / PostToolUse etc.):

1. Before test: back up target files (snapshot etc.) with `cp -a`
2. Environment: switch target agent via TMUX_PANE
3. Execute 4 scenarios:
   (a) Active write (context_snapshot.sh write)
   (b) Hook trigger (invoke target operation)
   (c) Recovery verification (compare snapshot content)
   (d) Rollback (`diff -q` against backup)
4. Record PASS/FAIL per scenario
5. After test: restore from backup (READ-ONLY principle)
