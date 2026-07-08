Run a production-readiness check on the interface — edge cases, i18n, error states, overflow — then create tasks for each gap.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Do the work

/impeccable:harden

After the hardening review is complete, create a task for each gap found:
- `--source design`, priority based on risk:
  - `high` — missing error states on critical flows, broken overflow, untranslated strings in production
  - `medium` — edge cases that cause layout breaks, unhandled empty states
  - **cosmetic overflow / optional i18n gaps / low-risk edge cases → do NOT create a task** — note them under Recommendations in the snapshot only
- Do not create tasks for findings already tracked or already dismissed — run `~/.darkflow/df task list --source design --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

**Task format (required):**

- **Title**: action-oriented verb — "Add error state to checkout form", "Fix text overflow in user name field at 320px", "Handle empty state on notifications panel" — never a bare observation
- **Body**:
  ```
  ## Problem
  <what is missing or broken — specific component, edge case, or locale>

  ## What to do
  <concrete change — which file, component, or copy to add/fix>

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

Write `docs/insights/design-harden/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Design Harden — YYYY-MM-DD

**Tool:** impeccable:harden
**Scope:** <pages / components reviewed>

## Gaps Found

| Category | Component / Page | Gap | Risk | Issue |
|---|---|---|---|---|
| error states | | | high / medium | #N |
| overflow | | | | |
| i18n | | | | |
| edge cases | | | | |

## Recurring Gaps

<gaps appearing in 2+ consecutive reviews — note how many in a row>

## Recommendations

<each with: component/page → what to add → acceptance criterion>
```

## Step 4 — Write metrics

Run `~/.darkflow/df task list --source design --state open`, then:
- Count → `openIssues`
- Count those with priority `critical` or `high` → `criticalOpen`
- Derive `status`: `"warning"` if `criticalOpen > 0`, `"ok"` otherwise

Write `.darkflow.d/state/metrics/design-harden.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
