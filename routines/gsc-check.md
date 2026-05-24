# GSC Check

Weekly review of Google Search Console data — positions, CTR, impressions, indexing issues — creates `status:proposed` GitHub issues with SEO recommendations.

---

## Instructions

```
/darkflow:gsc-check
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 8 * * 1` (weekly Mon 8:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh gsc-check` |

---

## Required integrations

- **Google Search Console MCP** configured in project `.claude/settings.json`
  - Property must be verified in GSC for your domain
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:gsc`, `priority:*`

The routine writes a GSC snapshot to `docs/insights/search-console/YYYY-MM-DD.md` before posting recommendations.

---

## Notes

- Weekly cadence is sufficient — GSC data updates with a 2–3 day lag
- Monday timing means the routine captures the full previous week
- For high-traffic sites, narrow the instructions to specific URL groups (landing pages, blog, etc.)
