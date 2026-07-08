Run an architectural analysis of the codebase and create tasks for each significant finding.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the default.

## Step 2 — Do the work

/improve-codebase-architecture

After the review is complete, create a task for each significant finding:
- `--source arch-review`, priority based on impact
- Focus on actionable improvements, not style preferences
- Do not create tasks for findings already tracked or already dismissed — run `~/.darkflow/df task list --source arch-review --state all` and skip any finding that matches an existing task **or** one a human already closed without a merged fix (rejected). Re-file only if a previously-fixed problem has demonstrably regressed.

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source arch-review \
  --priority <critical|high|medium|low> --status proposed --body "<problem/what-to-do/acceptance criteria>"
```

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 3 — After completing

Save an architecture snapshot so the Dark Flow worker can forward it to the web UI.

Run `~/.darkflow/df task list --source arch-review --state open`, then:
- Count the returned tasks → `openIssues`
- Derive `status`: `"warning"` if openIssues > 10, `"ok"` otherwise

Write `.darkflow.d/state/metrics/architecture.json` (create parent directories if needed):

```json
{
  "openIssues": <integer>,
  "status":     "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
