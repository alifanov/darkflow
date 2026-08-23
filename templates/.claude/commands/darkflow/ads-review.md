---
description: Review paid ads performance (Google Ads, Meta Ads, or equivalent) and create tasks.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `minPriority`.

## Step 2 — Do the work

Check the paid ads account configured for this project for the last 7 days. Specifically:

1. **Campaign performance** — impressions, clicks, CTR, CPC, conversions, CPA, ROAS per campaign
2. **Budget utilisation** — daily budget vs actual spend; underspending or overspending campaigns
3. **Keyword performance** — top and bottom keywords by conversion rate; wasted-spend keywords
4. **Audience and placement** — which audiences/placements drive CPA below target vs above
5. **Trends** — week-over-week change in spend, conversions, CPA, ROAS

For each finding:
- State the metric and its current value
- Compare to the previous 7-day period
- Suggest a concrete action (pause keyword, increase budget, adjust bid, add negative keyword, etc.)

Create a task for each significant finding. Use `--source ads` and a priority.

Priority vocabulary: `critical` / `high` / `medium` / `low`. **Never inflate a priority to clear
the project's `minPriority` floor** — the floor decides what gets filed, not you. If `df task
create` is rejected (`priority <x> below project minPriority <y>`), keep the honest priority,
record the finding under Hypotheses in the snapshot, and surface the rejection in the output.

**Task format (required):**

- **Title**: action-oriented verb — "Pause wasted-spend keyword X", "Increase budget on campaign Y", "Add negative keyword Z" — never just a description of the observation
- **Body**:
  ```
  ## Problem
  <metric, current value, comparison to previous period>

  ## Plan
  - [ ] 1. <concrete action — specific campaign, ad group, keyword, or audience to change>
  - [ ] 2. <next step, if the fix needs one>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "CPA on campaign X drops below $15">
  - [ ] <additional criterion if needed>
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source ads \
  --priority <critical|high|medium|low> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 3 — Write docs snapshot

Append a `## Ads` section to today's daily log, `docs/logs/$(date +%F).md` — create the
file if it is not there yet, and never touch a section another routine wrote.

**Found nothing? Append nothing.** No section, no "all clear" line. Silence is the clean
result, and the observation threshold counts on it (see `.darkflow.d/claude.md`).

```markdown
## Ads

**Account:** <Google Ads / Meta Ads / other>
**Period:** last 7 days

### Key Metrics

| Metric | Value | vs previous 7d |
|---|---|---|
| Spend | | |
| Conversions | | |
| CPA | | |
| ROAS | | |
| CTR | | |

### Campaign Breakdown

<table or bullet list of campaign-level performance>

### Findings

<list of significant observations — wasted spend, outperforming segments, budget issues>

### Recurring Issues

<patterns appearing in 2+ consecutive reviews — note how many reviews in a row>

### Hypotheses

<one pointer line per bet: H-NNN + evidence status — the entry itself lives in docs/state/hypotheses.md (see agent-workflow.md)>

### Recommendations

<each with: metric-basis → specific action → expected impact>
```

## Step 4 — After completing

Save an ads snapshot so the Dark Flow worker can forward it to the web UI.

Run `~/.darkflow/df task list --source ads --state open`, then:
- Count → `openIssues`
- Count those with priority `critical` or `high` → `criticalOpen`
- Derive `status`: `"warning"` if criticalOpen > 0, `"ok"` otherwise

Write `.darkflow.d/state/metrics/ads.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
