# Security Runtime Audit

Weekly check of the live application's security posture — HTTP headers, TLS, CSP, DNS, exposed endpoints. Creates `status:proposed` GitHub issues for each gap.

---

## Instructions

```
/security-review

After the review is complete, create a GitHub issue for each finding:
- Labels: source:security-review, priority based on severity (p0=critical, p1=high, p2=medium, p3=low), area:infra / area:api as appropriate
- Do not create issues for findings already tracked in open GitHub issues

Language in GitHub issues: [LANGUAGE]
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekly (e.g. Sunday at 4:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **No** — read-only analysis |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:security-review`, `area:infra` / `area:api`, `priority:p0`–`p3`, `effort:xs`–`m`

Most header and DNS fixes are `effort:xs` — quick wins worth fixing immediately.

---

## After completing

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
   { "timestamp": "<current UTC ISO 8601>", "routine": "security-runtime-audit", "summary": "<one-line summary, e.g. 'Headers OK, 2 CSP gaps opened as p2 issues'>" }
   ```
9. Write `docs/overview.html`

Preserve `analytics.*` and `architecture.*` from the existing JSON — only update `security.*`, `github.*`, and `logs`.

---

## Notes

- Schedule 1 hour after the code audit (Sunday 4:00 vs 3:00) so they don't run in parallel
- `/security-review` covers both static code and runtime checks — these two routines run the same command in the same project to get a full weekly snapshot
- For multi-domain setups, clone this routine per domain and note the domain in the instructions
