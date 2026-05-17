# GSC Check

Weekly review of Google Search Console data — positions, CTR, impressions, indexing issues — creates `status:proposed` GitHub issues with SEO recommendations.

---

## Instructions

```
Check Google Search Console data for the last week. Suggest what to do to improve it.
Output language: Russian. Add all recommendations as GitHub Issues.
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Every Monday at ~8:00 |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **No** — read-only, runs on main branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **Google Search Console MCP** configured in project `.claude/settings.json`
  - Property must be verified in GSC for your domain
- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:gsc`, `area:landing`, `priority:*`, `effort:*`

The routine writes a GSC snapshot to `docs/insights/search-console/YYYY-MM-DD.md` before posting recommendations.

---

## Notes

- Weekly cadence is sufficient — GSC data updates with a 2–3 day lag
- Monday timing means the routine captures the full previous week
- For high-traffic sites, narrow the instructions to specific URL groups (landing pages, blog, etc.)
