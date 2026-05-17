# Analytics Review

Daily review of product analytics and recent commits — creates `status:proposed` GitHub issues with prioritised recommendations.

---

## Instructions

```
Check the latest commits for the last 24 hours. Check the latest PostHog analytics data for this project for the last 24 hours. Check what changes (commits) happened over the last week.

Based on this, suggest improvements.

Before making recommendations, get data on: new user funnel, errors, any anomalies.

Add all recommendations as GitHub Issues to the remote GitHub repository of this project.

Do NOT create recommendations about paid ads — that is handled in a separate routine.

Language in GitHub issues: [LANGUAGE]
```

Replace `[LANGUAGE]` with your project language (e.g. English, Russian). Adapt the "do not create" exclusions to your project.

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
