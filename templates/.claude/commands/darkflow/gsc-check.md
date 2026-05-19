Review Google Search Console data for the last week and create status:proposed GitHub issues with SEO recommendations.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the default.

## Step 2 — Do the work

Check Google Search Console data for the last week. Analyse positions, CTR, impressions, and indexing issues. Suggest what to do to improve them.

Add all recommendations as GitHub Issues to the remote GitHub repository of this project. Use labels: `status:proposed`, `source:gsc`, `area:landing`, `priority:*`, `effort:*`.

Write a GSC snapshot to `docs/insights/search-console/YYYY-MM-DD.md` before posting recommendations.

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — After completing

Append a routine-log entry to `docs/overview.html`:

1. Read `docs/overview.html`
2. In the JSON inside `<script id="overview-data">`, append to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "gsc-check", "summary": "<one-line summary, e.g. 'CTR down on /pricing, 2 SEO issues opened'>" }
   ```
3. Cap the array at the 50 most recent entries (drop older ones if it exceeds 50)
4. Write `docs/overview.html` — change nothing else in the JSON
