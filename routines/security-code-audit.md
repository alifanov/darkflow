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

## Notes

- Use **Opus** — `/security-review` reads the full codebase; Sonnet may miss subtle vulnerabilities
- For monorepos, scope the review by adding after the command: "Focus on `apps/api/` and `packages/auth/`"
- Consider running after major feature merges in addition to the weekly schedule
