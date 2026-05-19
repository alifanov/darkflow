# Observability Check

Daily check of application errors, slow endpoints, database query performance, and request volumes. Creates `status:proposed` GitHub issues with prioritised findings.

---

## Instructions

```
/darkflow:observability-check
```

The command reads `.darkflow` for the output language — no placeholders to replace. Adapt the threshold notes below to your stack if needed.

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

- **Observability MCP** configured in project `.claude/settings.json`
- **`gh` CLI** authenticated — for creating GitHub issues

---

## Setting up the integration

If not yet configured, the Dark Flow installer can collect credentials for you. To set up manually:

### SigNoz

Add to your project `.claude/settings.json`:

```json
{
  "mcpServers": {
    "signoz": {
      "command": "npx",
      "args": ["-y", "@signoz/mcp-server"],
      "env": {
        "SIGNOZ_URL": "https://your-signoz-instance.com",
        "SIGNOZ_API_KEY": "your-api-key"
      }
    }
  }
}
```

### Datadog

```json
{
  "mcpServers": {
    "datadog": {
      "command": "npx",
      "args": ["-y", "@datadog/mcp-server"],
      "env": {
        "DD_API_KEY": "your-api-key",
        "DD_APP_KEY": "your-app-key",
        "DD_SITE": "datadoghq.com"
      }
    }
  }
}
```

### Grafana

```json
{
  "mcpServers": {
    "grafana": {
      "command": "npx",
      "args": ["-y", "@grafana/mcp-server"],
      "env": {
        "GRAFANA_URL": "https://your-grafana.com",
        "GRAFANA_API_KEY": "your-service-account-token"
      }
    }
  }
}
```

Store credentials in your project `.env` (referenced by the env block above), never commit them directly.

---

## What gets created

Issues with labels: `status:proposed`, `source:signoz` (or relevant), `area:api` / `area:worker` / `area:infra`, `priority:*`, `effort:*`

---

## Notes

- Schedule 30 minutes after the analytics review (8:30 vs 8:00) to avoid parallel context usage
- For database query analysis, the agent needs trace data that includes DB spans — ensure your ORM/query layer has tracing instrumented
- Adapt "slow queries > 100ms" threshold to your stack (Postgres typically 50ms, Redis < 10ms)
- If no observability MCP is available, remove the DB and trace sections from the instructions and focus on application logs only
