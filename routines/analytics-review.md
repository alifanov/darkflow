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

## After completing

Update `docs/overview.html` — the project status dashboard. Read the file, replace the JSON inside `<script id="overview-data">` with fresh data, write it back.

**Data to collect:**

1. **GitHub** — run `gh issue list --state open --json number,title,labels --limit 200`:
   - `github.open_total` — total count
   - `github.by_priority` — count per `priority:p0/p1/p2/p3` label
   - `github.by_area` — count per `area:*` label (strip the `area:` prefix)
   - `github.critical_issues` — all P0+P1 issues as `{ number, title, priority, area }`

2. **Analytics** — from the analytics tool already queried above:
   - `analytics.users_total` — total registered users
   - `analytics.visitors_7d` — unique visitors last 7 days
   - `analytics.revenue_7d` — revenue last 7 days (null if not applicable)

3. **Security and Architecture** — preserve the existing values from the current JSON. These sections are updated by the security and architecture audit routines.

4. Set `last_updated` to the current UTC timestamp (ISO 8601).

**JSON schema:**
```json
{
  "project": "<keep existing>",
  "last_updated": "2025-01-15T08:05:00Z",
  "analytics": { "users_total": N, "visitors_7d": N, "revenue_7d": N, "currency": "USD" },
  "github": {
    "open_total": N,
    "by_priority": { "p0": N, "p1": N, "p2": N, "p3": N },
    "by_area": { "api": N, "ui": N, ... },
    "critical_issues": [ { "number": N, "title": "...", "priority": "p0", "area": "api" } ]
  },
  "security":     { "<keep existing values>" },
  "architecture": { "<keep existing values>" }
}
```

---

## Notes

- If no analytics MCP is available, simplify the instructions to commit review only
- Exclude topics handled by other routines (ads, infrastructure) to avoid duplicate issues
