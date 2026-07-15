Review analytics and recent commits, then create tasks.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the defaults.

Analytics come from the **OpenPanel MCP** registered for this project. It uses a `read` client that is already scoped to a single project, so there is no project to select or switch — just query. If no OpenPanel MCP is available, skip the analytics part and review commits only.

## Step 2 — Do the work

Work over a **single 7-day window** for everything. Query the last 7 days of analytics from the OpenPanel MCP (`get_analytics_overview`, `query_events`, `get_funnel`). Check what commits happened over the same last 7 days.

Based on this, suggest improvements.

Before making recommendations, get data on: new user funnel, product-level friction (rage-clicks, dead-clicks, drop-offs — only if instrumented in OpenPanel), any anomalies. Do **not** chase application/server errors here — those are `/darkflow:observability-check`.

**Skip if there is no signal.** If traffic/conversions are below a meaningful threshold for the window (e.g. only a handful of visitors, funnels with near-zero entries), the data is noise: write the snapshot (Steps 3) and exit **without creating any tasks** — do not manufacture recommendations from noise.

**Avoid duplicates.** Before creating a task, list existing open tasks from this source and skip anything already filed for the same finding:
```bash
~/.darkflow/df task list --source openpanel --state open
```
If an equivalent task already exists (same metric / funnel step / page), do not create a new one — update the existing one only if the situation materially changed.

Add the remaining recommendations as tasks. Use `--source openpanel` and a priority.

**Priority rubric:**
- `critical` — active revenue/signup loss right now (funnel fully broken, conversion dropped to ~0, checkout failing)
- `high` — clear, sizeable drop-off or regression on a key flow (onboarding, activation, purchase) with material impact
- `medium` — meaningful but non-urgent optimisation (a soft drop-off, an under-performing step)
- `low` — minor polish, instrumentation gaps, nice-to-have experiments

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
  "adsSpend7d":  null,
  "currency":    "USD"
}
```

Fill in the values from the analytics data already queried in Step 2 (7-day window). Use `null`
for any metric that is not available for this project. Always leave `adsSpend7d` as `null` here —
ad spend is owned by `/darkflow:ads-review`; do not query or estimate it in this routine.

The worker will pick up this file on its next sync and forward it to the webapp API together
with the current issue list. You do not need to update any HTML files or call any API endpoints.
