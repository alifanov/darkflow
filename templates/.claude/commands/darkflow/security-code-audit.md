Run a static security review of the codebase and create status:proposed GitHub issues for each finding.

## Step 1 — Read project config

Read `.darkflow` in the project root. Extract:
- `language=` → output/issue language (default: English)

If `.darkflow` is missing, continue with the default.

## Step 2 — Do the work

/security-review

After the review is complete, create a GitHub issue for each finding:
- Labels: `source:security-review`, priority based on severity (`p0`=critical, `p1`=high, `p2`=medium, `p3`=low), `area:api` / `area:auth` / `area:infra` as appropriate
- Do not create issues for findings already tracked in open GitHub issues

Language for all GitHub issues and output: the `language=` value from `.darkflow`.

## Step 3 — After completing

Update `docs/overview.html` with the fresh security status:

1. Read `docs/overview.html`
2. Run `gh issue list --state open --json number,title,labels --limit 200`
3. Count issues with label `source:security-review` or `area:security` → `security.open_issues`
4. Count those with `priority:p0` or `priority:p1` → `security.critical_open`
5. Set `security.last_audit` to today's date (YYYY-MM-DD)
6. Derive `security.status`: `"critical"` if critical_open > 0, `"warning"` if open > 5, `"ok"` otherwise
7. Also recalculate `github.*` from the full issue list
8. Append a new entry to the `logs` array (cap at 50 most recent):
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "security-code-audit", "summary": "<one-line summary, e.g. 'No new vulnerabilities found, 1 medium issue confirmed'>" }
   ```
9. Write `docs/overview.html`

Preserve `analytics.*` and `architecture.*` from the existing JSON — only update `security.*`, `github.*`, and `logs`.
