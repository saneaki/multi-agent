# n8n Operations Guide

## Error Notification System

### Error Workflow

| Item | Value |
|------|-------|
| WF ID | `v7PvNrBhRhUFQ0xN` |
| WF Name | Error Notification (ntfy) |
| ntfy Topic | `hananoen` |
| ntfy URL | `https://ntfy.sh/hananoen` |
| Status | Active |
| Created | 2026-02-15 |

### Architecture

```
[Any Active WF fails]
        |
        v
[Error Trigger] → [Format Error Message (Code)] → [Send ntfy (HTTP Request)]
```

- Error Trigger: n8n built-in node, receives execution error data
- Format Error Message: Extracts WF name, node, error message (200 char), execution ID, timestamp
- Send ntfy: POST JSON to ntfy.sh (handles Unicode/emoji properly)

### Notification Format

```
Title: n8n Error: {WF名}
Body:
  WF: {workflow name}
  Node: {last node executed}
  Error: {error message, max 200 chars}
  Execution ID: {id}
  Timestamp: {ISO 8601}
Tags: warning
```

### Applied Workflows

All active WFs have `settings.errorWorkflow: v7PvNrBhRhUFQ0xN` set (as of 2026-02-15):

| WF ID | WF Name |
|-------|---------|
| 6HfrbcXoujQSfSQC | Gmail自動化ワークフロー v4.0 |
| RmAon5taDYVjgb8w | Claude Code Docs 同期 WF1 v1.0 |
| XgI1VYV2oDZyGKhf | Gmail ダイジェスト通知 v1.0 |
| XjYci5rlyNx2ckcD | 案件タスク完了→対応履歴同期 Webhook版 v2.0 |
| calendar-sync-v32 | Googleカレンダー同期フロー v4.1 |
| d7Dvt9sup1nA2B4j | RSSから情報取得し続けーる |
| hLccoUa8o9RAaRs0 | 倉敷駅 不動産物件監視 |
| ukPGDtU5ZqPxNg7X | GitHub Docs 同期 WF2 v1.0 |
| vabz2zkr5rl4gPxK | 領収書自動転記システム v8.1 |

### New WF Checklist

When creating a new active workflow, add the following to its settings:

```json
{
  "settings": {
    "errorWorkflow": "v7PvNrBhRhUFQ0xN"
  }
}
```

### Important Notes

- Error Notification WF itself does NOT have errorWorkflow set (infinite loop prevention)
- Only production executions (cron, webhook) trigger errorWorkflow; manual test executions do not
- ntfy topic `hananoen` is public (no authentication required)
