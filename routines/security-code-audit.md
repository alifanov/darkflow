# Security Code Audit

Weekly static analysis of the codebase — finds security vulnerabilities, exposed secrets, insecure patterns, and outdated dependencies. Creates `status:proposed` GitHub issues for each finding.

---

## Instructions

```
/security-review

After the review is complete, create a GitHub issue for each finding:
- Labels: source:security-review, priority based on severity (p0=critical, p1=high, p2=medium, p3=low), area:api / area:auth / area:infra as appropriate
- Do not create issues for findings already tracked in open GitHub issues

Language in GitHub issues: [LANGUAGE]
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekly (e.g. Sunday at 3:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | **Opus** (recommended) — `/security-review` does deep codebase reasoning |
| Worktree | **No** — read-only analysis |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:security-review`, `area:api` / `area:auth` / `area:infra`, `priority:p0`–`p3`, `effort:*`

Critical findings (`priority:p0`) should be reviewed immediately.

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
8. Write `docs/overview.html`

Preserve `analytics.*` and `architecture.*` from the existing JSON — only update `security.*` and `github.*`.

---

## Notes

- Use **Opus** — `/security-review` reads the full codebase; Sonnet may miss subtle vulnerabilities
- For monorepos, scope the review by adding after the command: "Focus on `apps/api/` and `packages/auth/`"
- Consider running after major feature merges in addition to the weekly schedule
