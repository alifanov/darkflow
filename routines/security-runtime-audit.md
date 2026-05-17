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

## Notes

- Schedule 1 hour after the code audit (Sunday 4:00 vs 3:00) so they don't run in parallel
- `/security-review` covers both static code and runtime checks — these two routines run the same command in the same project to get a full weekly snapshot
- For multi-domain setups, clone this routine per domain and note the domain in the instructions
