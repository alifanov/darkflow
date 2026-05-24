# Analytics Review

Daily review of product analytics and recent commits — creates `status:proposed` GitHub issues with prioritised recommendations.

---

## Instructions

```
/darkflow:analytics-review
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 8 * * *` (daily 8:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh analytics-review` |

---

## Required integrations

- **Analytics MCP** (PostHog, Mixpanel, etc.) configured in project `.claude/settings.json`
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:posthog`, `priority:*`

The routine writes an analytics snapshot to `docs/insights/analytics/YYYY-MM-DD.md` before posting recommendations.

---

## Notes

- If no analytics MCP is available, simplify the instructions to commit review only
- Exclude topics handled by other routines (ads, infrastructure) to avoid duplicate issues
