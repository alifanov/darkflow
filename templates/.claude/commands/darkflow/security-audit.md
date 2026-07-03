Run a full security review — static code analysis and live app check — then create tasks for each finding.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/issue language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the default.

## Step 2 — Do the work

/security-review

After the review is complete, create a task for each finding:
- `--source security-review`, `--status approved`, priority = severity (`critical` / `high` / `medium`)
- **`low`-severity findings: do NOT create a task** — note them in the snapshot only
- Security findings are auto-approved — see `docs/auto-approve.md`
- Do not create tasks for findings already tracked or already dismissed — run `~/.darkflow/df task list --source security-review --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

**Task format (required):**

- **Title**: action-oriented verb — "Fix X", "Restrict Y", "Add Z" — never just a statement of the finding ("X is vulnerable", "Found Y")
- **Body**:
  ```
  ## Problem
  <what was found and why it is a risk>

  ## What to do
  <concrete steps to resolve it — specific files, configs, or APIs to change>

  ## Acceptance criteria
  - [ ] <verifiable outcome 1>
  - [ ] <verifiable outcome 2 if needed>
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source security-review \
  --priority <critical|high|medium> --status approved --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 3 — Write docs snapshot

Write `docs/insights/security/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Security Audit — YYYY-MM-DD

**Period:** <date range reviewed>

## Findings

| Category | Finding | Severity | File / Config |
|---|---|---|---|
| | | critical / high / medium / low | |

## Recurring Issues

<vulnerabilities appearing in 2+ consecutive audits — note how many audits in a row>

## Hypotheses

<pre-threshold signals that aren't yet ready for a task — see agent-workflow.md>

## Recommendations

<each with: what was found → specific fix → acceptance criterion>
```

## Step 4 — After completing

Save a security snapshot so the Dark Flow worker can forward it to the web UI.

Run `~/.darkflow/df task list --source security-review --state open`, then:
- Count → `openIssues`
- Count those with priority `critical` or `high` → `criticalOpen`
- Derive `status`: `"critical"` if criticalOpen > 0, `"warning"` if openIssues > 5, `"ok"` otherwise

Write `.darkflow.d/state/metrics/security.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning" | "critical"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
