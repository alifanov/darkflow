Run an architectural analysis of the codebase and create status:proposed GitHub issues for each significant finding.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the default.

## Step 2 — Do the work

/improve-codebase-architecture

After the review is complete, create a GitHub issue for each significant finding:
- Labels: `status:proposed`, `source:manual`, `area:architecture` + area matching the affected module, priority based on impact, `effort:m` or `effort:l`
- Focus on actionable improvements, not style preferences
- Do not create issues for findings already tracked in open GitHub issues

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — After completing

Update `docs/overview.html` with the fresh architecture status:

1. Read `docs/overview.html`
2. Run `gh issue list --state open --json number,title,labels --limit 200`
3. Count issues with label `area:architecture` → `architecture.open_issues`
4. Set `architecture.last_review` to today's date (YYYY-MM-DD)
5. Derive `architecture.status`: `"warning"` if > 10 open, `"ok"` otherwise
6. Also recalculate `github.*` from the full issue list
7. Append a new entry to the `logs` array (cap at 50 most recent):
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "architecture-review", "summary": "<one-line summary, e.g. 'Found 4 architectural issues, opened 2 new GitHub issues'>" }
   ```
8. Write `docs/overview.html`

Preserve `analytics.*` and `security.*` from the existing JSON — only update `architecture.*`, `github.*`, and `logs`.
