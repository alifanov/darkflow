# Observability Check

Daily check of application errors, slow endpoints, and request volumes — creates `status:proposed` GitHub issues with performance recommendations.

---

## Instructions

```
Check SigNoz for this project. Specifically:
- Check for errors
- Check loaded URLs (how long they take to load)
- Check request counts to specific URLs

Based on this, give recommendations on what needs to be done with the project.
Add recommendations as GitHub issues.

Language of responses and GitHub issues: Russian.
```

Replace SigNoz with your observability tool (Datadog, Grafana, New Relic, etc.) and adjust the instruction accordingly.

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Every day at ~8:30 |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **No** — read-only, runs on main branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **Observability MCP** (SigNoz, Datadog, etc.) configured in project `.claude/settings.json`
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:signoz`, `area:api` or `area:infra`, `priority:*`, `effort:*`

---

## Notes

- Schedule 30 minutes after the analytics review routine to avoid parallel context usage
- If observability data is unavailable, the routine will skip gracefully
- Adapt "check loaded URLs" to match your tool's terminology (traces, spans, latency percentiles)
