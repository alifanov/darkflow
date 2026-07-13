Review analytics and recent commits, then create tasks.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the defaults.

Analytics come from the **OpenPanel MCP** registered for this project. It uses a `read` client that is already scoped to a single project, so there is no project to select or switch — just query. If no OpenPanel MCP is available, skip the analytics part and review commits only.

## Step 2 — Do the work

Check the latest commits for the last 24 hours. Query the last 24 hours of analytics from the OpenPanel MCP (`get_analytics_overview`, `query_events`, `get_funnel`). Check what changes (commits) happened over the last week.

Based on this, suggest improvements.

Before making recommendations, get data on: new user funnel, errors, any anomalies.

Add all recommendations as tasks. Use `--source openpanel` and a priority.

**Task format (required):**

- **Title**: action-oriented verb — "Add X to onboarding funnel", "Fix drop-off on Y step", "Instrument Z event" — never just a statement of observation ("Low conversion on step 2", "Anomaly detected in signups")
- **Body**:
  ```
  ## Problem
  <what the data shows and why it matters>

  ## What to do
  <concrete action — specific page, flow, component, or event to change>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "Step 2 → Step 3 conversion rises above 60%">
  - [ ] <additional criterion if needed>
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source openpanel \
  --priority <critical|high|medium|low> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Do NOT create recommendations about paid ads — that is handled by `/darkflow:ads-review`.

Do NOT create OpenPanel dashboards, saved reports, or any other OpenPanel artifacts. OpenPanel access is read-only here: only query data. All recommendations go out as tasks — never as analytics alerts on changes/anomalies.

Write an analytics snapshot to `docs/insights/analytics/YYYY-MM-DD.md` before posting recommendations.

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 3 — After completing

Save an analytics snapshot so the Dark Flow worker can forward it to the web UI.

Write `.darkflow.d/state/metrics/analytics.json` with the following structure (create parent
directories if they don't exist):

```json
{
  "usersTotal":  <integer or null>,
  "visitors7d":  <integer or null>,
  "revenue7d":   <float or null>,
  "adsSpend7d":  <float or null>,
  "currency":    "USD"
}
```

Fill in the values from the analytics data already queried in Step 2. Use `null` for any
metric that is not available for this project.

The worker will pick up this file on its next sync and forward it to the webapp API together
with the current issue list. You do not need to update any HTML files or call any API endpoints.
