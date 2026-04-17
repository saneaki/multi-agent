# Agent Self-Watch Phase Rules (cmd_107)

Delivery model for inbox wake-up, phased rollout across all agents.

| Phase | Rule |
|-------|------|
| **Phase 1 (baseline)** | Self-watch standardized: `process_unread_once` at startup recovers unread messages; `inotifywait` event-driven loop + timeout fallback continues the watch. |
| **Phase 2** | Normal nudge suppressed (`disable_normal_nudge`). Self-watch is the primary delivery path; inbox YAML unread state is the operational source of truth. |
| **Phase 3** | `FINAL_ESCALATION_ONLY` — `send-keys` nudge is reserved for final recovery only (stall >4 min → `/clear` escalation path). |
| **Always** | Honor `summary-first` (unread_count fast-path) and `no_idle_full_read` (avoid unnecessary full-file reads on every wake). |

**Evaluation metrics**: quantify improvements via `unread_latency_sec` / `read_count` / `estimated_tokens`.

**Agent-specific notes**: see individual instructions files if an agent has exceptions.
