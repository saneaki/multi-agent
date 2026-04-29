# Communication Protocol

## Mailbox System (inbox_write.sh)

Agent-to-agent communication uses file-based mailbox:

```bash
bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>
```

Examples:
```bash
# Shogun → Karo
bash scripts/inbox_write.sh karo "cmd_048を書いた。実行せよ。" cmd_new shogun

# Ashigaru → Karo
bash scripts/inbox_write.sh karo "足軽5号、任務完了。報告YAML確認されたし。" report_received ashigaru5

# Karo → Ashigaru
bash scripts/inbox_write.sh ashigaru3 "タスクYAMLを読んで作業開始せよ。" task_assigned karo
```

Delivery is handled by `inbox_watcher.sh` (infrastructure layer).
**Agents NEVER call tmux send-keys directly.**

## Delivery Mechanism

Two layers:
1. **Message persistence**: `inbox_write.sh` writes to `queue/inbox/{agent}.yaml` with flock. Guaranteed.
2. **Wake-up signal**: `inbox_watcher.sh` detects file change via `inotifywait` → wakes agent:
   - **Priority 1**: Agent self-watch (agent's own `inotifywait` on its inbox) → no nudge needed
   - **Priority 2**: `tmux send-keys` — short nudge only (text and Enter sent separately, 0.3s gap)

The nudge is minimal: `inboxN` (e.g. `inbox3` = 3 unread). That's it.
**Agent reads the inbox file itself.** Message content never travels through tmux — only a short wake-up signal.

Safety note (shogun):
- If the Shogun pane is active (the Lord is typing), `inbox_watcher.sh` must not inject keystrokes. It should use tmux `display-message` only.
- Escalation keystrokes (`Escape×2`, context reset, `C-u`) must be suppressed for shogun to avoid clobbering human input.

Special cases (CLI commands sent via `tmux send-keys`):
- `type: clear_command` → sends context reset command via send-keys (Claude Code: `/clear`, Codex: `/new` — auto-converted to /new for Codex)
- `type: model_switch` → sends the /model command via send-keys

## Agent Self-Watch Phase Policy (cmd_107)

Phase migration is controlled by watcher flags:

- **Phase 1 (baseline)**: `process_unread_once` at startup + `inotifywait` event-driven loop + timeout fallback.
- **Phase 2 (normal nudge off)**: `disable_normal_nudge` behavior enabled (`ASW_DISABLE_NORMAL_NUDGE=1` or `ASW_PHASE>=2`).
- **Phase 3 (final escalation only)**: `FINAL_ESCALATION_ONLY=1` (or `ASW_PHASE>=3`) so normal `send-keys inboxN` is suppressed; escalation lane remains for recovery.

Read-cost controls:

- `summary-first` routing: unread_count fast-path before full inbox parsing.
- `no_idle_full_read`: timeout cycle with unread=0 must skip heavy read path.
- Metrics hooks are recorded: `unread_latency_sec`, `read_count`, `estimated_tokens`.

**Escalation** (when nudge is not processed):

| Elapsed | Action | Trigger |
|---------|--------|---------|
| 0〜2 min | Standard pty nudge | Normal delivery |
| 2〜4 min | Escape×2 + nudge | Cursor position bug workaround |
| 4 min+ | Context reset sent (max once per 5 min, skipped for Codex) | Force session reset + YAML re-read |

## Inbox Processing Protocol (karo/ashigaru/gunshi)

When you receive `inboxN` (e.g. `inbox3`):
1. `Read queue/inbox/{your_id}.yaml`
2. Find all entries with `read: false`
3. Process each message according to its `type`
4. Update each processed entry: `read: true` (use Edit tool)
5. Resume normal workflow

### MANDATORY Post-Task Inbox Check

**After completing ANY task, BEFORE going idle:**
1. Read `queue/inbox/{your_id}.yaml`
2. If any entries have `read: false` → process them
3. Only then go idle

This is NOT optional. If you skip this and a redo message is waiting,
you will be stuck idle until the next nudge escalation or task reassignment.

## Redo Protocol

When Karo determines a task needs to be redone:

1. Karo writes new task YAML with new task_id (e.g., `subtask_097d` → `subtask_097d2`), adds `redo_of` field
2. Karo sends `clear_command` type inbox message (NOT `task_assigned`)
3. inbox_watcher delivers context reset to the agent（Claude Code: `/clear`, Codex: `/new`）→ session reset
4. Agent recovers via Session Start procedure, reads new task YAML, starts fresh

Race condition is eliminated: context reset wipes old context. Agent re-reads YAML with new task_id.

## Report Flow (interrupt prevention)

| Direction | Method | Reason |
|-----------|--------|--------|
| Ashigaru → Gunshi | Report YAML + inbox_write | Quality check (Gunshi auto-starts QC. No task YAML from Karo needed) |
| Gunshi → Karo | Report YAML + inbox_write | QC result + strategic reports. On QC PASS, Gunshi also writes dashboard ✅ entry |
| Karo → Shogun/Lord | dashboard.md update only | **inbox to shogun FORBIDDEN** — prevents interrupting Lord's input |
| Karo → Gunshi | YAML + inbox_write | Strategic tasks only. Standard QC auto-triggered, no assignment needed |
| Top → Down | YAML + inbox_write | Standard wake-up |

**Gunshi Autonomous QC**: Ashigaru sends report_received to Gunshi inbox → Gunshi auto-starts QC.
Karo does NOT need to assign QC task YAML (for standard QC). On QC PASS, Gunshi writes ✅ entry directly to dashboard.md.

<!-- File Operation Rule moved to CLAUDE.md §Common Rules (canonical). See memory/canonical_rule_sources.md -->

## Inbox Communication Rules

### Sending Messages

```bash
bash scripts/inbox_write.sh <target> "<message>" <type> <from>
```

**No sleep interval needed.** No delivery confirmation needed. Multiple sends can be done in rapid succession — flock handles concurrency.

### Report Notification Protocol

After writing report YAML, notify Karo:

```bash
bash scripts/inbox_write.sh karo "足軽{N}号、任務完了でござる。報告書を確認されよ。" report_received ashigaru{N}
```

That's it. No state checking, no retry, no delivery verification.
The inbox_write guarantees persistence. inbox_watcher handles delivery.

---

## F009: Communication Channel Mirror Rule (返信チャネル整合)

**Definition**: When a message from the Lord arrives via an external channel (ntfy, Discord, Gmail, etc.), the reply MUST be sent via the same channel. tmux/Claude output is supplementary (for detail and history), not a substitute.

**Applies to**: All agents (Shogun, Karo, Ashigaru, Gunshi).

**Rationale**: The Lord's current location is invisible to agents. The entry channel is the only reliable signal of where the Lord is listening. Replying only in Claude when the Lord is on a smartphone means the message is never seen — a silent delivery failure.

**Forbidden (F009 violation)**:
- Receiving a ntfy message and responding only in Claude tmux output
- Receiving a Gmail/Discord message and replying only in shogun_to_karo.yaml without ntfy push to Lord

**Required behavior**:
| Entry channel | Reply channel (mandatory) | Claude output |
|---------------|--------------------------|---------------|
| ntfy (smartphone) | `bash scripts/ntfy.sh "..."` | Also echo in Claude |
| Discord | Discord message | Also log in Claude |
| Gmail | Gmail reply or ntfy summary | Also log in Claude |
| Claude terminal (tmux) | Claude terminal output | Only (no ntfy needed) |

**Root cause of violation (2026-04-28 殿指摘)**:
- A: 入口=返信チャネルのルールが未明文化だった
- B: エージェントが tmux 本流前提で動く慣性バイアス
- C: 殿への届読 feedback ループ欠如
- D: cmd dispatch 漏れ (cmd_595/596) と同根 — 人為的注意力依存の構造

See `memory/global_context.md §Communication Channel Mismatch` for full 4-layer analysis.

---

## Test Execution Rule: Dual-Model Parallel (L017)

**Definition**: When a cmd's Acceptance Criteria include "test" (smoke test, integration test, E2E test, etc.), the test scope MUST be dispatched in parallel to both a Claude-series ashigaru and a Codex-series ashigaru.

**Applies to**: All agents. Karo is responsible for dual dispatch at decomposition time.

**Rationale**: cmd_597/cmd_598 single-model tests caused silent failures and overlooked edge cases. cmd_602 dual-model analysis demonstrated clear quality improvement (script.run SA constraint found only by Codex). Same principle applied to test execution.

**Rule**:
- AC with "test" keyword → dual dispatch (Claude ash + Codex ash) mandatory
- Single-model test is **prohibited** unless the exception below applies
- Exception (Karo judgment): trivial smoke test (< 5 commands, 1 binary pass/fail) may use single model; document reason in task YAML

**Dispatch pattern**:
```
Claude ash (ash4/ash5): test suite execution + pass/fail report
Codex ash (ash6/ash7): independent re-run + edge case detection
Gunshi: consolidate results, flag discrepancies
```

Task YAML notes field: `"L017 test dual-model: Claude=ashN, Codex=ashM"` to be recorded.

See also: L016 (Investigation Tasks dual-model) in `instructions/karo.md`.

---

## L018: Context Percentage Primary Source Rule (shogun専用)

**Definition**: Shogun MUST use the tmux statusbar (`tmux capture-pane -t $TMUX_PANE -p | tail`) as the primary source for context% judgment. The inbox `compact_suggestion` / `shogun_context_notify` entries are auxiliary information only — they MUST NOT be the sole basis for proposing `/clear`.

**Applies to**: Shogun only. Karo / Ashigaru / Gunshi can directly view their own pane statusbar, so this rule does not apply to them.

**Rationale**: 2026-04-29 reality check — Shogun trusted stale `compact_suggestion` entries in inbox (4/26 86% etc.) and repeatedly proposed 「限界」 / 「/clear 推奨」 while the actual context for Opus 4.7 was 57% used (43% remaining — ample margin). This was the 4th occurrence of the notification-blind-trust pattern on the same day (notion 漏れ / 86%誤報 / obsidian skip / 本件 context 限界誤連呼) — a structural weakness that demands a codified rule.

**Required behavior**:
1. **Before any context% judgment** (cmd dispatch / 節目 / /clear consideration), run:
   ```bash
   tmux capture-pane -t $TMUX_PANE -p | tail
   ```
   and read the statusbar context% directly.
2. **Propose `/clear` only when the live statusbar shows ≥ 70%**. Below 70%, do not propose `/clear` based on notification entries — continue work.
3. **Treat `compact_suggestion` / `shogun_context_notify` as advisory**. Cross-check against the live statusbar before acting.

**Note on `shogun_context_notify`**: The script was fixed in cmd_603 to prevent stale data emission, but the LLM (Shogun) itself MUST still read the primary signal directly rather than relying on physical sensation or notifications.

**Forbidden (L018 violation)**:
- Proposing `/clear` solely on the basis of an inbox `compact_suggestion` entry
- Reporting 「context 限界」 to the Lord without verifying the live tmux statusbar
- Treating `shogun_context_notify` output as authoritative truth

See `memory/global_context.md §Context % Reality Check Lapse — 4回目再発 (2026-04-29)` for the incident analysis.

---

## L019: Cross-Source Verification Rule (s-check Rule) (shogun専用)

**Definition**: Shogun MUST cross-verify multiple primary sources before reporting state ("状況" / "進捗" / "完了報告" / "確認してくれ" / "動いてるか" 等) to the Lord. Replies based solely on `dashboard.md` are forbidden — `dashboard.md` is a Secondary source (Karo's summary) and may lag actual state.

**Applies to**: Shogun only. Karo / Ashigaru / Gunshi are not in scope (they have direct access to the relevant primary sources by role).

**Trigger phrases (mandatory `/s-check` invocation)**:
- 「状況」 / 「進捗」 / 「完了報告」 / 「確認してくれ」 / 「動いてるか」
- ntfy 経由でも terminal 経由でも同様に発動する

**Primary sources to cross-check (must read before replying)**:
1. `queue/tasks/*.yaml` — assigned task state (status / assigned_to / acceptance_criteria)
2. `queue/reports/*_report.yaml` — agent reports (most recent timestamp + outcome)
3. `queue/inbox/*.yaml` — pending / unread messages per agent
4. `dashboard.yaml` — strategic state (machine-readable counterpart of dashboard.md)
5. `tmux capture-pane -t <pane> -p | tail` — live pane state per relevant agent
6. `git log -n 10` — recent commits (verifies "implemented" claims)

**Required behavior**:
1. **silent success 防止**: Replies MUST list `checked sources` + `last verified timestamp` so the Lord can audit which signals were used.
2. **inconclusive 容認**: When some primary source cannot be read (sandbox / permission / timeout), report partial results explicitly — do not pad with assumptions.
3. **dashboard-only 禁止**: A reply that cites only `dashboard.md` is a L019 violation. `dashboard.md` may be quoted as supplementary context but never as the sole evidence.
4. **Implementation**: detailed procedure in `skills/s-check/SKILL.md` (Scope A) + `scripts/status_check_rules.py` shared module (Scope B).

**Forbidden (L019 violation)**:
- Replying to 「状況」/「進捗」 without reading `queue/tasks/*.yaml`, `queue/reports/*_report.yaml`, `queue/inbox/*.yaml`
- Reporting 「正常」 / 「進行中」 with no `checked sources` enumeration
- Citing only `dashboard.md` ("dashboard.md には◯◯と書いてある") as the basis for a reply
- Silent success: claiming "OK" / "完了" without primary-source verification

**Rationale**: 2026-04-29 reality check — five consecutive lapses on the same day (notion 漏れ / 86%誤報 / obsidian skip / context%誤連呼 / dashboard 盲信). Pattern (4) was already covered by L018; pattern (5) (dashboard-only blind trust) demands its own structural rule. L019 codifies cross-source verification as the canonical defense against single-signal blindness.

See `memory/global_context.md §Reality Check 5度連発 — 構造解消 (2026-04-29)` for the incident analysis and structural defense design.
