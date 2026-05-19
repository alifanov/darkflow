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
| Schedule | Every day at ~8:00 |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **No** — read-only, runs on main branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **Analytics MCP** (PostHog, Mixpanel, etc.) configured in project `.claude/settings.json`
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:posthog`, `area:*`, `priority:*`, `effort:*`

The routine writes an analytics snapshot to `docs/insights/analytics/YYYY-MM-DD.md` before posting recommendations.

---

## Notes

- If no analytics MCP is available, simplify the instructions to commit review only
- Exclude topics handled by other routines (ads, infrastructure) to avoid duplicate issues
