# Security Audit

Weekly security review — static analysis of the codebase and live application check (HTTP headers, TLS, CSP, exposed endpoints). Creates `status:proposed` GitHub issues for each finding.

---

## Instructions

```
/darkflow:security-audit
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 3 * * 0` (weekly Sun 3:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Opus (recommended — deep security reasoning) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh security-audit` |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:security-review`, `priority:p0`–`p3`

Critical findings (`priority:p0`) should be reviewed immediately.

---

## Notes

- Use **Opus** — `/security-review` reads the full codebase and checks the live app; Sonnet may miss subtle vulnerabilities
- For monorepos, add to instructions: "Focus on `apps/api/` and `packages/auth/`"
- Consider running after major feature merges in addition to the weekly schedule
