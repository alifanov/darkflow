# Coolify Check Logs

Daily check of Coolify runtime logs — scans the logs of **every container** the app runs, finds errors/crashes/OOM kills, and opens GitHub issues for significant problems. Passive: it never triggers a deploy or restart.

---

## Instructions

```
/darkflow:coolify-check-logs
```

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `30 9 * * *` (daily 9:30) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh coolify-check-logs` |

---

## Required integrations

- **Coolify CLI** installed and authenticated on the runner — used to **discover** apps
  - The official `coolify` CLI, config at `~/.config/coolify/config.json`
  - Needs a Coolify API token with read permissions
- **SSH access** to the Coolify host (host/user/key) — required to read **per-container** logs
  - The `coolify` CLI cannot return the logs of a specific container, so logs are read over SSH via `docker logs`
  - Reading logs always needs explicit permission to use the SSH connection: interactive runs ask the user first; unattended/scheduled runs need `coolify_ssh=` pre-configured in `.darkflow`, otherwise log fetching is skipped

---

## Notes

- Pairs with `coolify-check-deployment` (deploy status). This routine only looks at runtime container logs.
- **Multi-container apps:** if the app runs more than one container (replicas or a compose stack), the routine reads `docker logs` for every matching container over SSH — not just one.
- **SSH required:** per-container logs are fetched over SSH (`docker logs`), since the `coolify` CLI can't target a single container. The connection always needs explicit approval — see Required integrations.
- Runs at 9:30, after `coolify-check-deployment` (9:00), so a failed-deploy p0 is filed before log noise is reviewed.
- Adapt step 1 if your deployment platform is different (Railway, Fly.io, etc.)
