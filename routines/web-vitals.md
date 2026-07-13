# Web Vitals

Weekly measurement of the project's **Core Web Vitals** by running **Lighthouse locally** against its URL (mobile emulation, headless Chrome). It records LCP, TBT, CLS, TTFB and FCP over time, and files a task when any metric lands in Google's **"poor"** band so `fix-issues` can pick up the regression. No API key and no external service — just local Chrome.

This is an **analysis** routine (like `build-optimization`): healthy runs only write a snapshot; a "poor" metric files a normal, **human-triaged** task — a slow page is not an emergency, so unlike `uptime-check` these tasks are not auto-approved. It complements `uptime-check` (is the site *up*) by answering: is the site *fast*.

---

## Instructions

```
/darkflow:web-vitals
```

Reads `domain` (URL to measure) and `language` from the project config — no placeholders to replace. If `domain` is unset it auto-discovers the production URL from Coolify / `vercel.json` / `netlify.toml` / `CNAME` / `package.json` and persists it back to `.darkflow`.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 6 * * 1` (weekly, Monday 06:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (mechanical — run Lighthouse + parse JSON + compare thresholds) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh web-vitals` |

Set the URL explicitly with `site_url=https://example.com` in `.darkflow`. Because it's local Chrome, `localhost`/staging URLs work too — not just public ones.

---

## Required integrations

- **Chrome / Chromium** — Lighthouse drives a local headless Chrome (`chrome-launcher` auto-detects the binary). If none is installed, the run is inconclusive and files no task.
- **`pnpm`** (or `npx`) — to fetch and run `lighthouse` on demand via `pnpm dlx lighthouse`
- A URL **reachable from this machine** (public, staging, or `localhost`)

---

## What gets measured

The **mobile** preset (Lighthouse default; mobile is what Google ranks on). This is **lab** data — a single synthetic run on this machine, not real-user field data. There is no lab **INP**, so **TBT** is used as its proxy.

| Metric | Good | Poor → task |
|---|---|---|
| LCP | ≤ 2.5 s | > 4.0 s |
| CLS | ≤ 0.1 | > 0.25 |
| TBT (lab INP proxy) | ≤ 200 ms | > 600 ms |
| TTFB | ≤ 0.8 s | > 1.8 s |
| FCP | ≤ 1.8 s | > 3.0 s |

---

## What gets created

When any metric is **poor**: a task with `source=web-vitals`, priority `high` (poor LCP/CLS/TBT — the Core Web Vitals and their proxy) or `medium` (other metrics), left for human triage (not auto-approved). Duplicate-safe: if an open `source=web-vitals` task already covers the metric, the routine comments instead of filing a new one.

Every run writes a dated snapshot at `docs/insights/web-vitals/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/web-vitals.json`.

---

## Notes

- Use **Sonnet** — the check is mechanical; the actual optimization runs separately through `fix-issues`.
- If no URL is configured or discoverable, the routine skips silently (no false-positive task) and notes the missing target in the snapshot.
- Lab metrics vary run-to-run (±10–20% is normal) — the routine only files for a clearly-poor result, not a value hovering at a boundary.
- Want real-user field data (CrUX) and true INP instead of a lab run? That needs the PageSpeed Insights API (a free API key) — this routine deliberately trades that away to stay key-free.
