# GSC Check

Weekly SEO routine with two halves: (1) a review of Google Search Console data — positions, CTR, impressions, indexing issues — and (2) a technical + on-page SEO audit of the codebase / live pages. Creates proposed tasks with concrete fixes.

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
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh gsc-check` |

---

## Required integrations

- **Google Search Console MCP** configured in project `.claude/settings.json`
  - Property must be verified in GSC for your domain
  - Optional: if the GSC MCP is missing, the routine skips the GSC half and still runs the SEO audit
- Optional `site_url=` in `.darkflow` — enables live-page spot-checks during the SEO audit (auto-discovered from Coolify/Vercel/Netlify/CNAME if unset)

---

## What gets created

Tasks with: `status=proposed`, `source=gsc` (GSC-data findings) or `source=seo` (audit findings), `priority=*`

The routine writes two snapshots before posting recommendations:
- `docs/insights/search-console/YYYY-MM-DD.md` — GSC data
- `docs/insights/seo-audit/YYYY-MM-DD.md` — technical/on-page audit

---

## Notes

- Weekly cadence is sufficient — GSC data updates with a 2–3 day lag
- Monday timing means the routine captures the full previous week
- SEO audit works primarily from the codebase (so it can propose exact fixes); `site_url` adds rendered-page checks
- Structured data (JSON-LD) is detected from source code, not raw `curl`/`web_fetch` (which strip `<script>` tags)
- For high-traffic sites, narrow the instructions to specific URL groups (landing pages, blog, etc.)
