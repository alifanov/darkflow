Run a five-dimension technical design quality check, then create `status:proposed` GitHub issues for each finding.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with defaults.

## Step 2 — Do the work

/impeccable:audit

After the audit is complete, create a GitHub issue for each significant finding:
- Labels: `status:proposed`, `source:design`, priority based on severity:
  - `priority:p1` — P0/P1 findings (broken layouts, inaccessible elements, missing critical states)
  - `priority:p2` — P2 findings (visual inconsistency, spacing issues, unclear hierarchy)
  - `priority:p3` — P3 findings (polish, minor refinements)
- Do not create issues for findings already tracked in open GitHub issues

**Issue format (required):**

- **Title**: action-oriented verb — "Fix broken grid on /dashboard at 375px", "Add error state to payment form", "Fix contrast ratio on primary button" — never a bare observation
- **Body**:
  ```
  ## Problem
  <what was found, which page/component, why it matters>

  ## What to do
  <concrete change — specific file, component, or CSS>

  ## Acceptance criteria
  - [ ] <verifiable outcome 1>
  - [ ] <verifiable outcome 2 if needed>
  ```

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — Write snapshot

Write `docs/insights/design-audit/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Design Audit — YYYY-MM-DD

**Tool:** impeccable:audit
**Scope:** <pages / components checked>

## Findings

| Dimension | Finding | Severity | Page / Component |
|---|---|---|---|
| | | P0 / P1 / P2 / P3 | |

## Recurring Issues

<findings appearing in 2+ consecutive audits — note how many audits in a row>

## Recommendations

<each with: page/component → what to fix → acceptance criterion>
```

## Step 4 — Write metrics

Run `gh issue list --state open --json number,labels --limit 200`, then:
- Count issues with label `source:design` → `openIssues`
- Count those with `priority:p1` → `criticalOpen`
- Derive `status`: `"warning"` if `criticalOpen > 0`, `"warning"` if `openIssues > 5`, `"ok"` otherwise

Write `.darkflow.d/state/metrics/design-audit.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
