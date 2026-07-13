# Web Vitals

Weekly measurement of the project's **Core Web Vitals** on the live production URL via the Google **PageSpeed Insights (PSI) API**. It records LCP, INP, CLS, TTFB and FCP over time, and files a task when any metric lands in Google's **"poor"** band so `fix-issues` can pick up the regression.

This is an **analysis** routine (like `build-optimization`): healthy runs only write a snapshot; a "poor" metric files a normal, **human-triaged** task — a slow page is not an emergency, so unlike `uptime-check` these tasks are not auto-approved. It complements `uptime-check` (is the site *up*) by answering: is the site *fast*.

---

## Instructions

```
/darkflow:web-vitals
```

Reads `domain` (URL to measure), `language`, and optional `psi_api_key` from the project config — no placeholders to replace. If `domain` is unset it auto-discovers the production URL from Coolify / `vercel.json` / `netlify.toml` / `CNAME` / `package.json` and persists it back to `.darkflow`.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 6 * * 1` (weekly, Monday 06:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (mechanical — curl PSI + parse + compare thresholds) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh web-vitals` |

Set the URL explicitly with `site_url=https://example.com` in `.darkflow`. Optional `psi_api_key=<key>` raises the PSI rate limit (unauthenticated calls work but are throttled).

---

## Required integrations

- **`curl`** — to call the PSI API (present on virtually all systems)
- A **publicly reachable** production URL — PSI runs Chrome on Google's side, so `localhost`/private/staging URLs are skipped (no task)

---

## What gets measured

The **mobile** strategy (Google ranks on mobile). Prefers **field data (CrUX, real users)** when available, falling back to **lab data (Lighthouse)**. INP comes only from field data; lab uses TBT as a proxy.

| Metric | Good | Poor → task |
|---|---|---|
| LCP | ≤ 2.5 s | > 4.0 s |
| INP (field) | ≤ 200 ms | > 500 ms |
| CLS | ≤ 0.1 | > 0.25 |
| TTFB | ≤ 0.8 s | > 1.8 s |
| FCP | ≤ 1.8 s | > 3.0 s |
| TBT (lab INP proxy) | ≤ 200 ms | > 600 ms |

---

## What gets created

When any metric is **poor**: a task with `source=web-vitals`, priority `high` (poor LCP/INP/CLS — the three Core Web Vitals) or `medium` (other metrics), left for human triage (not auto-approved). Duplicate-safe: if an open `source=web-vitals` task already covers the metric, the routine comments instead of filing a new one.

Every run writes a dated snapshot at `docs/insights/web-vitals/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/web-vitals.json`.

---

## Notes

- Use **Sonnet** — the check is mechanical; the actual optimization runs separately through `fix-issues`.
- If no public URL is configured or discoverable, the routine skips silently (no false-positive task) and notes the missing/unreachable target in the snapshot.
- The PSI free tier (~25k requests/day) is far above a weekly per-project cadence; add `psi_api_key` only if you run it very frequently across many projects.
