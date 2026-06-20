# Uptime Check

Every-4-hours health check of the project's public website — resolves DNS, hits the production URL, verifies the HTTP status is healthy, and confirms the page actually loads (not a blank, error, or maintenance page). If the site is **down or broken**, it files an auto-approved `priority:critical` GitHub issue so `fix-issues` restores it without waiting for human triage.

This is an **active** routine: healthy runs only write a snapshot; broken runs create a critical, auto-approved issue. It complements `coolify-check-deployment` (which watches the *deploy pipeline* status) by checking the *live site from the outside* — a deploy can go green while the site still serves 502s.

**Cost optimization — cheap pre-flight.** The dispatcher runs a fast bash `curl` probe before spending a Sonnet agent run. If the site responds 2xx with a real body, the dispatcher writes the snapshot + metrics itself and **skips the agent** (logged as `SKIP uptime-check — uptime ok …`). The agent is launched **only** when the probe finds the site down/broken or can't decide (no `site_url`, DNS failure, connection error, 4xx/5xx, empty/error body) — logged as `ESCALATE uptime-check — …`. On a healthy site this turns ~6 agent runs/day into zero LLM cost while keeping the every-4h cadence and the snapshot/metrics output.

---

## Instructions

```
/darkflow:uptime-check
```

The command reads `.darkflow` for `site_url` (the URL to monitor) and `language` (output language) — no placeholders to replace. If `site_url` is not set, it auto-discovers the production URL from Coolify / `vercel.json` / `netlify.toml` / `CNAME` / `package.json` and persists it back to `.darkflow`.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 */4 * * *` (every 4 hours) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (mechanical check — curl + status + body inspection) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh uptime-check` |

Set the URL to monitor explicitly with `site_url=https://example.com` in `.darkflow` (recommended; otherwise it is auto-discovered on first run).

---

## Required integrations

- **`curl`** — for the HTTP check (present on virtually all systems)
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

When the site is **down**: an issue with labels `status:approved`, `source:uptime`, `priority:critical`.

Outage issues are **auto-approved** — a down production site is an emergency, so `fix-issues` picks them up without a manual review step. `fix-issues` still runs all quality checks and escalates anything requiring infrastructure access or credentials (DNS, deploy keys, cert renewal) to `needs-human`.

Every run writes a dated snapshot at `docs/insights/uptime/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/uptime.json`.

---

## What it checks

1. **DNS** — does the hostname resolve? (expired domain, broken DNS provider)
2. **HTTP status** — `2xx`/`3xx` healthy; `4xx`/`5xx`, connection refused, TLS failure, or timeout → down
3. **Page loads** — body is non-empty and not an obvious error/maintenance/default page (502/503/504, `Application error`, default nginx welcome, empty body)

Slow-but-`200` responses are recorded as **degraded** in the snapshot and do **not** file a critical issue.

---

## Notes

- Use **Sonnet** — the check is mechanical; no deep reasoning required. The actual repair runs separately through `fix-issues`.
- Duplicate-safe: if an open `source:uptime` issue already describes the outage, the routine comments on it instead of filing a new one.
- If no URL is configured and none can be discovered, the routine skips silently (no false-positive issue) and notes the missing target in the snapshot.
