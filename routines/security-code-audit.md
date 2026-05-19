# Security Code Audit

Weekly static analysis of the codebase — finds security vulnerabilities, exposed secrets, insecure patterns, and outdated dependencies. Creates `status:proposed` GitHub issues for each finding.

---

## Instructions

```
/darkflow:security-code-audit
```

The command reads `.darkflow` for the output language — no placeholders to replace.

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
