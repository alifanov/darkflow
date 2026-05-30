# Deployment Failure Fix

Reactive routine triggered by a webhook when a deployment fails. Fetches the failure logs, diagnoses the root cause, fixes the code, and redeploys. No schedule — fires on demand via API.

---

## Instructions

```
/darkflow:deployment-failure
```

The command reads `.darkflow` for branch, language, and merge strategy — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | *(none — triggered manually or by webhook)* |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh deployment-failure` |

In `.darkflow.d/routines.yml`, `deployment-failure` has `cron: ""` and `enabled: false` — the dispatcher never fires it automatically. Run it on demand or trigger it via a webhook script.

---

## Setting up the webhook trigger

### Step 1 — create a trigger script

Create a small script at `.darkflow.d/trigger-deployment-failure.sh`:

```bash
#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")/.." && bash .darkflow.d/darkflow-run.sh deployment-failure
```

Make it executable: `chmod +x .darkflow.d/trigger-deployment-failure.sh`

### Step 2 — add it to your deployment platform

### Step 2 — add it to your deployment platform

**Coolify**  
Settings → Webhooks → Add webhook → select "Deployment Failed" event → paste URL

**Vercel**  
Project → Settings → Git → Deploy Hooks → add hook → trigger on deployment failure via Vercel's notification integrations or use a GitHub Actions step on failure

**Railway**  
Project → Settings → Webhooks → add URL → filter by `DEPLOYMENT_FAILED` event

**Generic (GitHub Actions)**
```yaml
- name: Notify Dark Flow on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.DARKFLOW_WEBHOOK_URL }}" \
      -H "Content-Type: application/json" \
      -d '{"event": "deployment_failed", "ref": "${{ github.ref }}"}'
```

Store the webhook URL as a secret (`DARKFLOW_WEBHOOK_URL`) — it gives write access to your project.

---

## Required integrations

- **Coolify CLI** (the official `coolify` CLI, config at `~/.config/coolify/config.json`) — to fetch logs and deployment status; other platforms use their own CLI
- **`gh` CLI** authenticated — for creating GitHub issues if fix is unclear
- **Git** with push access — for committing the fix

---

## Safety guardrails in the instruction

The instruction includes a hard stop: if root cause is unclear or the fix is large, the routine opens a `priority:p0` issue instead of guessing. This prevents the agent from making things worse under pressure.

Consider also adding to the instructions:
```
Do not modify database migrations, environment variables, or infrastructure config
without explicit approval — create a priority:p0 issue instead.
```

---

## Notes

- This routine overlaps intentionally with [Coolify Logs](coolify-logs.md) — the daily check is proactive, this one is reactive and fires within seconds of a failure
- Webhook payload from Coolify includes the application name and deployment ID — the routine can use these to fetch the exact failing deployment logs
- If you have multiple projects on Coolify, create one routine per project and use separate webhook URLs
