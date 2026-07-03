Run a scored design review with persona tests and automated detection, then create tasks for each finding.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/issue language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Do the work

/impeccable:critique

After the critique is complete, create a task for each significant finding:
- `--source design`, priority based on impact:
  - `high` — broken or confusing user journeys, low design score on key flows
  - `medium` — friction points, persona test failures, inconsistent patterns
  - **minor UX polish / low-impact scoring gaps → do NOT create a task** — note them under Recommendations in the snapshot only
- Do not create tasks for findings already tracked or already dismissed — run `~/.darkflow/df task list --source design --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

**Task format (required):**

- **Title**: action-oriented verb — "Fix confusing CTA hierarchy on pricing page", "Clarify empty state on projects list", "Improve onboarding flow for first-time users" — never a bare observation
- **Body**:
  ```
  ## Problem
  <what was found, which persona was tested, what friction or failure occurred>

  ## What to do
  <concrete change — specific page, flow, copy, or component>

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

## Step 3 — Write snapshot

Write `docs/insights/design-critique/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Design Critique — YYYY-MM-DD

**Tool:** impeccable:critique
**Scope:** <pages / flows reviewed>

## Score Summary

| Area | Score | vs Previous |
|---|---|---|
| | /10 | ↑ / ↓ / — |

## Persona Test Results

| Persona | Flow | Outcome | Notes |
|---|---|---|---|
| | | pass / fail / friction | |

## Findings

| Page / Component | Problem | Severity |
|---|---|---|
| | | high / medium |

## Recurring Issues

<findings appearing in 2+ consecutive critiques — note how many in a row>

## Recommendations

<each with: page/flow → what to improve → acceptance criterion>
```

## Step 4 — Write metrics

Run `~/.darkflow/df task list --source design --state open`, then:
- Count → `openIssues`
- Count those with priority `critical` or `high` → `criticalOpen`
- Derive `status`: `"warning"` if `criticalOpen > 0`, `"warning"` if `openIssues > 5`, `"ok"` otherwise

Write `.darkflow.d/state/metrics/design-critique.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
