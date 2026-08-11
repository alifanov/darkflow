---
description: Check Coolify deployment status; file a high-priority task on a failed deploy. Passive — fixes nothing.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

Check the Coolify **deployment status** for this project: detect failed/red deploys and create a high-priority task. This is a passive health check — it does not auto-fix or trigger anything.

This command only looks at the deployment pipeline status. Runtime container errors, crashes, and OOM signals are covered by your observability tool (SigNoz/Datadog/Grafana) via `/darkflow:observability-check`, since container logs already ship there.

All Coolify data is fetched via the official `coolify` CLI (not an MCP server). Config lives at `~/.config/coolify/config.json`.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `coolify_app`, `language`.

## Step 2 — Resolve the app UUID

If `coolify_app` is not set, list apps and find the UUID by name/project:

```bash
coolify app list
```

## Step 3 — Check deployment status

Check the deployment history for failed/red deploys:

```bash
coolify app deployments list APP_UUID
```

- If the latest deployment is in a **failed or error state**: create a critical-priority task:
  - `--source infra --priority critical --status proposed`
  - Title: "Fix failed deployment: <error summary>"
  - Body: the deployment metadata + identified error. For details of the failed deploy:
    ```bash
    coolify deploy get DEPLOYMENT_UUID --format pretty
    ```
  - Create with:
    ```bash
    ~/.darkflow/df task create --title "Fix failed deployment: <error summary>" \
      --source infra --priority critical --status proposed --body "<deployment metadata + error>"
    ```

If the latest deployment succeeded, output: `Coolify deployment OK — latest deploy succeeded.`

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Guardrails

- Never trigger a new deployment — this is a passive check.
- Never expose secrets from deployment output — redact anything that looks like a key/token.
