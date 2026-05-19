# Observability Check

Daily check of application errors, slow endpoints, database query performance, and request volumes. Creates `status:proposed` GitHub issues with prioritised findings.

---

## Instructions

```
Check the observability tool for this project. Specifically:

1. Errors — new or spiking error rates in the last 24h; group by error type
2. Slow endpoints — URLs with p95 latency > 1s; note the slowest 5
3. Database queries — slow queries (> 100ms), N+1 patterns, queries without indexes, highest-volume queries per endpoint
4. Request volume — unusual spikes or drops vs the previous 7-day average
5. Integration health — are all services reporting? Any gaps in traces or missing spans?

For each finding:
- State the metric and its current value
- Compare to the previous period (yesterday / last week)
- Suggest a concrete fix (add index, cache result, paginate query, etc.)

Create a GitHub issue for each significant finding.
Language in GitHub issues: [LANGUAGE]
```

Adapt `p95 latency > 1s` and `slow queries > 100ms` thresholds to your stack.

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

## After completing

Append a routine-log entry to `docs/overview.html`:

1. Read `docs/overview.html`
2. In the JSON inside `<script id="overview-data">`, append to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "observability-check", "summary": "<one-line summary, e.g. '2 new error spikes, 1 slow endpoint → 3 issues opened'>" }
   ```
3. Cap the array at the 50 most recent entries (drop older ones if it exceeds 50)
4. Write `docs/overview.html` — change nothing else in the JSON

---

## Notes

- Schedule 30 minutes after the analytics review (8:30 vs 8:00) to avoid parallel context usage
- For database query analysis, the agent needs trace data that includes DB spans — ensure your ORM/query layer has tracing instrumented
- Adapt "slow queries > 100ms" threshold to your stack (Postgres typically 50ms, Redis < 10ms)
- If no observability MCP is available, remove the DB and trace sections from the instructions and focus on application logs only
