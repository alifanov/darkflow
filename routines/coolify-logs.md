# Coolify Logs

Daily check of Coolify deployment logs — finds errors, fixes them, waits for a successful re-deployment, then verifies the app is healthy.

---

## Instructions

```
/darkflow:coolify-logs
```

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 9 * * *` (daily 9:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh coolify-logs` |

---

## Required integrations

- **Coolify CLI** installed and authenticated on the runner
  - The official `coolify` CLI, config at `~/.config/coolify/config.json`
  - Needs a Coolify API token with read (and deploy, for the reactive routine) permissions
- **Git** with push access — the routine commits fixes to main before triggering redeploy

---

## Notes

- Schedule after the analytics routine (9:00 vs 8:00) so deployment noise doesn't skew analytics data
- The routine makes **real production changes** — verify the `coolify` CLI is scoped to the correct Coolify project
- If the fix requires more than a trivial change, the routine should create a GitHub issue instead of auto-fixing
- Adapt step 1 if your deployment platform is different (Railway, Fly.io, etc.)
