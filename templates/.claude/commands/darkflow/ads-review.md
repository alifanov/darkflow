Review paid ads performance (Google Ads, Meta Ads, or equivalent) and create status:proposed GitHub issues.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the default.

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

Create a GitHub issue for each significant finding. Use labels: `status:proposed`, `source:ads`, `priority:*`.

**Issue format (required):**

- **Title**: action-oriented verb — "Pause wasted-spend keyword X", "Increase budget on campaign Y", "Add negative keyword Z" — never just a description of the observation
- **Body**:
  ```
  ## Problem
  <metric, current value, comparison to previous period>

  ## What to do
  <concrete action — specific campaign, ad group, keyword, or audience to change>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "CPA on campaign X drops below $15">
  - [ ] <additional criterion if needed>
  ```

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — Write docs snapshot

Write `docs/insights/ads/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Ads Review — YYYY-MM-DD

**Account:** <Google Ads / Meta Ads / other>
**Period:** last 7 days

## Key Metrics

| Metric | Value | vs previous 7d |
|---|---|---|
| Spend | | |
| Conversions | | |
| CPA | | |
| ROAS | | |
| CTR | | |

## Campaign Breakdown

<table or bullet list of campaign-level performance>

## Findings

<list of significant observations — wasted spend, outperforming segments, budget issues>

## Recurring Issues

<patterns appearing in 2+ consecutive reviews — note how many reviews in a row>

## Hypotheses

<pre-threshold signals that aren't yet ready for a GitHub issue — see agent-workflow.md>

## Recommendations

<each with: metric-basis → specific action → expected impact>
```

## Step 4 — After completing

Save an ads snapshot so the Dark Flow worker can forward it to the web UI.

Run `gh issue list --state open --json number,labels --limit 200`, then:
- Count issues with label `source:ads` → `openIssues`
- Count those with `priority:p0` or `priority:p1` → `criticalOpen`
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
