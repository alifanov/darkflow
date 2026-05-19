Review analytics and recent commits, then create status:proposed GitHub issues.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the default.

## Step 2 — Do the work

Check the latest commits for the last 24 hours. Check the latest analytics data (PostHog or the analytics tool configured for this project) for the last 24 hours. Check what changes (commits) happened over the last week.

Based on this, suggest improvements.

Before making recommendations, get data on: new user funnel, errors, any anomalies.

Add all recommendations as GitHub Issues to the remote GitHub repository of this project. Use labels: `status:proposed`, `source:posthog`, `area:*`, `priority:*`, `effort:*`.

Do NOT create recommendations about paid ads — that is handled in a separate routine.

Write an analytics snapshot to `docs/insights/analytics/YYYY-MM-DD.md` before posting recommendations.

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — After completing

Update `docs/overview.html` — the project status dashboard.

**Data to collect:**

1. **GitHub** — run `gh repo view --json url -q .url` to get `github.repo_url`. Then run `gh issue list --state open --json number,title,labels --limit 200`:
   - `github.open_total` — total count
   - `github.awaiting_approval` — issues with label `status:proposed` as `{ number, title, priority, area }` (strip label prefixes)
   - `github.in_progress` — issues with label `status:in-progress` as `{ number, title, priority, area }` (strip label prefixes)

2. **Analytics** — from the analytics tool already queried above:
   - `analytics.users_total` — total registered users
   - `analytics.visitors_7d` — unique visitors last 7 days
   - `analytics.revenue_7d` — revenue last 7 days (null if not applicable)
   - `analytics.ads_spend_7d` — Google Ads spend last 7 days (null if Google Ads MCP is not connected)

3. **Security and Architecture** — preserve the existing values from the current JSON. These sections are updated by the security and architecture audit routines.

4. Set `last_updated` to the current UTC timestamp (ISO 8601).

5. **Routine log** — append a new entry to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "analytics-review", "summary": "<one-line summary, e.g. 'Created 3 issues from PostHog data, no anomalies'>" }
   ```
   Keep only the most recent 50 entries (drop older ones if the array exceeds 50).

Read `docs/overview.html`, replace the JSON inside `<script id="overview-data">` with fresh data using this schema, write it back:

```json
{
  "project": "<keep existing>",
  "last_updated": "2025-01-15T08:05:00Z",
  "analytics": { "users_total": N, "visitors_7d": N, "revenue_7d": N, "ads_spend_7d": N_or_null, "currency": "USD" },
  "github": {
    "repo_url": "https://github.com/owner/repo",
    "open_total": N,
    "awaiting_approval": [ { "number": N, "title": "...", "priority": "p1", "area": "api" } ],
    "in_progress":       [ { "number": N, "title": "...", "priority": "p2", "area": "ui"  } ]
  },
  "security":     { "<keep existing values>" },
  "architecture": { "<keep existing values>" },
  "logs": [ "<last 50 entries>" ]
}
```
