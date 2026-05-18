# Overview Update

Daily refresh of `docs/overview.html` — pulls GitHub issues, analytics metrics, and security/architecture status into a single project status dashboard.

Open `docs/overview.html` in any browser to see the current state of the project.

---

## Instructions

```
Read the file docs/overview.html.

Find the JSON object inside the element:
  <script id="overview-data" type="application/json">

Gather fresh data for each section below, then replace that JSON object with an updated one and write the file back.

---

1. GITHUB ISSUES

Run:
  gh issue list --state open --json number,title,labels --limit 200

From the result:
- Count total open issues → github.open_total
- Count by priority label (priority:p0 / p1 / p2 / p3) → github.by_priority
- Count by area label (area:*) — strip the "area:" prefix → github.by_area
- Collect all P0 and P1 issues as the critical_issues list:
    { "number": N, "title": "...", "priority": "p0", "area": "api" }
  (area = first area:* label found, or omit if none)

---

2. ANALYTICS (if PostHog or analytics MCP is configured)

Query the analytics tool for:
- Total registered users (all time) → analytics.users_total
- Unique visitors in the last 7 days → analytics.visitors_7d
- Revenue / MRR for the last 7 days → analytics.revenue_7d
  (set currency: "USD" or "EUR" as appropriate)

If analytics is unavailable, preserve the existing values from the current JSON.

---

3. SECURITY STATUS

From the GitHub issue list:
- Count issues with label source:security-review or area:security → security.open_issues
- Count of those that are priority:p0 or priority:p1 → security.critical_open
- Find the most recent audit date from the issue timestamps or docs/insights/ filenames → security.last_audit (YYYY-MM-DD)
- Derive status:
    "critical" if critical_open > 0
    "warning"  if open_issues > 5
    "ok"       otherwise
    "unknown"  if no security issues exist at all

---

4. ARCHITECTURE STATUS

From the GitHub issue list:
- Count issues with label area:architecture → architecture.open_issues
- Find the most recent review date from issue timestamps → architecture.last_review (YYYY-MM-DD)
- Derive status:
    "warning" if open_issues > 10
    "ok"      otherwise
    "unknown" if no arch issues exist at all

---

5. BUILD THE UPDATED JSON

{
  "project": "<keep the existing value — do not change>",
  "last_updated": "<current UTC timestamp in ISO 8601, e.g. 2025-01-15T09:30:00Z>",
  "analytics": {
    "users_total": <number or null>,
    "visitors_7d": <number or null>,
    "revenue_7d":  <number or null>,
    "currency": "USD"
  },
  "github": {
    "open_total": <number>,
    "by_priority": { "p0": N, "p1": N, "p2": N, "p3": N },
    "by_area": { "api": N, "ui": N, ... },
    "critical_issues": [
      { "number": N, "title": "...", "priority": "p0", "area": "api" },
      ...
    ]
  },
  "security": {
    "open_issues": <number or null>,
    "critical_open": <number>,
    "last_audit": "<YYYY-MM-DD or null>",
    "status": "ok|warning|critical|unknown"
  },
  "architecture": {
    "open_issues": <number or null>,
    "last_review": "<YYYY-MM-DD or null>",
    "status": "ok|warning|unknown"
  }
}

Replace the <script id="overview-data"> content in docs/overview.html with the new JSON and write the file.
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Daily at 9:30 |
| Folder | Project root |
| Model | Sonnet (default) |
| Worktree | **No** — writes to main branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for reading GitHub issues
- **Analytics MCP** (optional) — for user / visitor / revenue metrics; skipped gracefully if absent

---

## What gets updated

`docs/overview.html` — open with any browser

---

## Schedule relative to other routines

Runs after the daily data-gathering routines so today's issues are already created:

```
8:00  Analytics review     → creates status:proposed issues
8:30  Observability check  → creates status:proposed issues
9:30  Overview update      ← this routine — reads all current data, writes overview.html
```

Weekly audit routines (Architecture review Sun 2:00, Security audits Sun 3:00–4:00) create GitHub issues; the next morning's 9:30 run picks them up automatically.

---

## Notes

- Can be triggered manually at any time to get an instant snapshot
- If `gh` is unavailable the routine should abort — all data depends on GitHub issues
- Analytics fields that cannot be determined are written as `null` and render as `—` in the dashboard
