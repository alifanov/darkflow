# Coolify Check Deployment

Daily check of the Coolify deployment pipeline — detects failed/red deploys and opens a `priority:critical` GitHub issue. Passive: it never triggers a deploy or fixes anything.

---

## Instructions

```
/darkflow:coolify-check-deployment
```

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 9 * * *` (daily 9:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `~/.darkflow/darkflow-run.sh coolify-check-deployment` |

---

## Required integrations

- **Coolify CLI** installed and authenticated on the runner
  - The official `coolify` CLI, config at `~/.config/coolify/config.json`
  - Needs a Coolify API token with read permissions

---

## Notes

- Passive check — it creates a `priority:critical` issue on a failed deploy rather than auto-fixing.
- Adapt step 1 if your deployment platform is different (Railway, Fly.io, etc.)
