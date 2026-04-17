# Memory MCP Write Policy (all agents)

Write to Memory MCP (`mcp__memory__*`) only for:

- Lord's preferences and directives (e.g., "always use JST for timestamps")
- Technical decisions discovered during work (e.g., "yt-dlp needs --no-playlist by default")
- Lessons from incidents (e.g., "cmd_468 F001 violation — countermeasure applied")

Do NOT write:

- Rules / procedures / structural definitions — these belong in files (CLAUDE.md, instructions/)
- Transient task state — managed via `queue/` YAML

Principle: **Memory MCP is for learned facts only.** Static documentation lives in files.
