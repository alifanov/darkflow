Measure this project's **Core Web Vitals** on the live production URL via the Google PageSpeed Insights (PSI) API, compare them against Google's thresholds, and file a task when any metric lands in the **"poor"** band. This tracks real user-facing performance (LCP, INP, CLS, TTFB, FCP) over time and turns regressions into actionable work for `fix-issues`.

This is an **analysis** routine: healthy runs only write a snapshot; runs with a "poor" metric file a normal (human-triaged) task — a slow page is not an emergency, so unlike `uptime-check` these tasks are **not** auto-approved.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to refresh `.darkflow.d/state/config.json` from the Web UI (silently falls back to cache if the server is unreachable). Read it and extract:
- `domain` → the public production URL to measure (e.g. `https://example.com`)
- `language` → output/task language (default: English)
- `psi_api_key` (optional) → PSI API key; unauthenticated calls work but are rate-limited

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Resolve the URL to measure

If `domain` is set, use it. Otherwise auto-discover the production URL the same way `uptime-check` does (first match wins): Coolify FQDN, `vercel.json` / `.vercel/project.json`, `netlify.toml`, `CNAME`, `package.json` → `homepage`, or a production URL stated in `README.md` / `docs/`. If found, persist it:
```bash
grep -q "^site_url=" .darkflow || echo "site_url=<discovered-url>" >> .darkflow
```

PSI needs a **publicly reachable** URL. If no URL can be determined, or the target is a `localhost` / private / staging URL Google can't reach, **do not create a task** — output `web-vitals: no public site_url — skipping` and write a snapshot (Step 5) noting the target is unknown/unreachable. Done.

## Step 3 — Run PageSpeed Insights

Measure the **mobile** strategy (Google ranks on mobile). Add `&key=<psi_api_key>` if configured.

```bash
KEY_PARAM=""; [ -n "$PSI_API_KEY" ] && KEY_PARAM="&key=$PSI_API_KEY"
curl -sS --max-time 90 -o /tmp/psi.json \
  "https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$URL")&strategy=mobile&category=performance${KEY_PARAM}"
```

If curl fails, or the response has a top-level `.error` (invalid URL, unreachable, quota), treat the run as **inconclusive**: do not file a task, record the error in the snapshot, and stop.

Extract from `/tmp/psi.json` (use `python3 -c` or `jq` if available):

- **Lab metrics** — `lighthouseResult.audits.metrics.details.items[0]`:
  - `largestContentfulPaint` (ms) → LCP
  - `cumulativeLayoutShift` → CLS
  - `totalBlockingTime` (ms) → TBT (INP proxy in lab — there is no lab INP)
  - `firstContentfulPaint` (ms) → FCP
  - `interactive` (ms) → TTI
- **Performance score** — `lighthouseResult.categories.performance.score` (0–1, ×100).
- **Field data (CrUX, real users)** — `loadingExperience.metrics` if present (only for sites with enough traffic). Each entry has `percentile` + `category` (`FAST`/`AVERAGE`/`SLOW` or `GOOD`/`NEEDS_IMPROVEMENT`/`POOR`):
  - `LARGEST_CONTENTFUL_PAINT_MS`, `INTERACTION_TO_NEXT_PAINT` (real INP!), `CUMULATIVE_LAYOUT_SHIFT_SCORE`, `EXPERIENCE_TIME_TO_FIRST_BYTE`.

**Prefer field data when present** (it's real users); fall back to lab otherwise. Field data is the source of truth for INP — lab only has TBT as a proxy.

## Step 4 — Classify against Google thresholds

| Metric | Good | Needs improvement | **Poor → task** |
|---|---|---|---|
| LCP | ≤ 2.5 s | 2.5–4.0 s | **> 4.0 s** |
| INP (field) | ≤ 200 ms | 200–500 ms | **> 500 ms** |
| CLS | ≤ 0.1 | 0.1–0.25 | **> 0.25** |
| TTFB | ≤ 0.8 s | 0.8–1.8 s | **> 1.8 s** |
| FCP | ≤ 1.8 s | 1.8–3.0 s | **> 3.0 s** |
| TBT (lab, INP proxy) | ≤ 200 ms | 200–600 ms | **> 600 ms** |

A metric is **poor** if it exceeds the last column. If **no** metric is poor → healthy: snapshot only, no task. If one or more are poor → Step 4b.

## Step 4b — File a task if any metric is poor

First check for an already-open web-vitals task to avoid duplicates:
```bash
~/.darkflow/df task list --source web-vitals --state open
```
If an open task already covers the same poor metric, add a comment with the new run's numbers instead of opening a duplicate.

Otherwise create a task (priority `high` if LCP/INP/CLS — the three Core Web Vitals — are poor, else `medium`):

- `--source web-vitals --priority <high|medium>` (no `--status approved` — human triages it)
- Title: e.g. "Web Vitals: LCP 5.2s on / (poor, target ≤2.5s)"
- Body:
  ```
  ## What's slow
  <URL> (mobile) as of <timestamp>. Source: <field (CrUX) | lab (Lighthouse)>.

  | Metric | Value | Band | Target |
  |---|---|---|---|
  | LCP | 5.2 s | poor | ≤ 2.5 s |
  | INP | 240 ms | needs-improvement | ≤ 200 ms |
  | CLS | 0.03 | good | ≤ 0.1 |
  Performance score: <NN>/100

  ## Likely causes
  <best-effort hypothesis tied to the poor metric(s): e.g. LCP → unoptimized hero
  image / render-blocking CSS / slow TTFB; CLS → images without dimensions / injected
  content; INP/TBT → heavy JS on main thread / hydration.>

  ## Acceptance criteria
  - [ ] <poor metric> back under its "good" threshold on the next web-vitals run
  - [ ] No new metric regressed into "poor"
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source web-vitals \
  --priority <high|medium> --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 5 — Write snapshot and metrics

Write `docs/insights/web-vitals/YYYY-MM-DD.md` (append a timestamped section if today's file exists):

```markdown
# Web Vitals — YYYY-MM-DD

**Target:** <URL or "unknown">  ·  **Strategy:** mobile  ·  **Source:** field/lab

## Metrics
| Time | LCP | INP | CLS | TTFB | FCP | Score | Result | Task |
|---|---|---|---|---|---|---|---|---|
| HH:MM | 2.1s | 180ms | 0.04 | 0.6s | 1.4s | 92 | ok / poor | #N |

## Notes
<which metric(s) were poor; whether field or lab data; trend vs prior snapshots>
```

Write `.darkflow.d/state/metrics/web-vitals.json` (create parent dirs if needed):

```json
{
  "url":        "<URL or empty>",
  "strategy":   "mobile",
  "source":     "field" | "lab",
  "score":      <0-100 or null>,
  "lcpMs":      <integer or null>,
  "inpMs":      <integer or null>,
  "cls":        <number or null>,
  "ttfbMs":     <integer or null>,
  "fcpMs":      <integer or null>,
  "status":     "ok" | "poor"
}
```

The worker picks up this file on its next sync. You do not need to update any HTML files.
