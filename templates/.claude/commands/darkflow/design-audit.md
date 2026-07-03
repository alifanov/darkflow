Run a five-dimension technical design quality check + UI performance audit, then create tasks for each finding.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/issue language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Design quality audit

/impeccable:audit

After the audit is complete, create a task for each significant finding:
- `--source design`, priority based on severity:
  - `high` — broken layouts, inaccessible elements, missing critical states
  - `medium` — visual inconsistency, spacing issues, unclear hierarchy
  - **polish / minor refinements → do NOT create a task** — note them under Recommendations in the snapshot only
- Do not create tasks for findings already tracked or already dismissed — run `~/.darkflow/df task list --source design --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

**Task format (required):**

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

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source design \
  --priority <high|medium> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 3 — UI performance audit

/impeccable:optimize

After the performance audit is complete, create a task for each significant finding:
- `--source design`, priority based on impact:
  - `high` — LCP > 2.5s, CLS > 0.1, or bundle size regressions blocking interaction
  - `medium` — measurable slowdowns, large unoptimized assets, render-blocking resources
  - **minor / nice-to-have optimizations → do NOT create a task** — note them under Recommendations in the snapshot only
- Do not create tasks for findings already tracked, already dismissed, or covered by `build-optimization` — run `~/.darkflow/df task list --source design --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

**Task format (required):**

- **Title**: action-oriented verb — "Reduce LCP on /landing from 4s to <2.5s", "Lazy-load hero image on /home", "Remove render-blocking font on checkout page" — never a bare observation
- **Body**:
  ```
  ## Problem
  <metric / current value / target — specific page and element>

  ## What to do
  <concrete change — specific file, asset, or config>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "LCP drops below 2.5s on Lighthouse mobile">
  - [ ] <secondary check if needed>
  ```

Create the same way as Step 2, with `--priority <high|medium>`.

## Step 4 — Write snapshot

Write `docs/insights/design-audit/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Design Audit — YYYY-MM-DD

**Tools:** impeccable:audit + impeccable:optimize
**Scope:** <pages / components checked>

## Quality Findings

| Dimension | Finding | Severity | Page / Component |
|---|---|---|---|
| | | P0 / P1 / P2 / P3 | |

## Performance Findings

| Metric | Current | Target | Page | Issue |
|---|---|---|---|---|
| LCP | | < 2.5s | | #N |
| CLS | | < 0.1 | | |
| Bundle | | | | |

## Recurring Issues

<findings appearing in 2+ consecutive audits — note how many audits in a row>

## Recommendations

<each with: page/component → what to fix → acceptance criterion>
```

## Step 5 — Write metrics

Run `~/.darkflow/df task list --source design --state open`, then:
- Count → `openIssues`
- Count those with priority `critical` or `high` → `criticalOpen`
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
