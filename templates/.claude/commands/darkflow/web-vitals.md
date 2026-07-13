Measure this project's **Core Web Vitals** by running **Lighthouse locally** against its URL (mobile emulation), compare the lab metrics against Google's thresholds, and file a task when any metric lands in the **"poor"** band. This tracks user-facing performance (LCP, CLS, TBT, FCP, TTFB) over time and turns regressions into actionable work for `fix-issues`. No API key and no external service — Lighthouse drives a local headless Chrome.

This is an **analysis** routine: healthy runs only write a snapshot; runs with a "poor" metric file a normal (human-triaged) task — a slow page is not an emergency, so unlike `uptime-check` these tasks are **not** auto-approved.

> **Lab, not field.** Local Lighthouse produces **lab** data (a single synthetic run on this machine), not real-user field data. There is no lab **INP** — **TBT** (Total Blocking Time) is used as its proxy. Because it's local Chrome, it can measure `localhost`/staging/private URLs too, not just public ones.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to refresh `.darkflow.d/state/config.json` from the Web UI (silently falls back to cache if the server is unreachable). Read it and extract:
- `domain` → the URL to measure (e.g. `https://example.com`)
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Resolve the URL to measure

If `domain` is set, use it. Otherwise auto-discover the production URL the same way `uptime-check` does (first match wins): Coolify FQDN, `vercel.json` / `.vercel/project.json`, `netlify.toml`, `CNAME`, `package.json` → `homepage`, or a production URL stated in `README.md` / `docs/`. If found, persist it:
```bash
grep -q "^site_url=" .darkflow || echo "site_url=<discovered-url>" >> .darkflow
```

The URL just has to be reachable **from this machine** (public, staging, or `localhost` all work). If no URL can be determined at all, **do not create a task** — output `web-vitals: no site_url — skipping` and write a snapshot (Step 5) noting the target is unknown. Done.

## Step 3 — Run Lighthouse locally

Lighthouse needs a Chrome/Chromium binary on this machine (`chrome-launcher` auto-detects it). Run the **mobile** preset (Lighthouse's default form factor — mobile is what Google ranks on):

```bash
pnpm dlx lighthouse "$URL" \
  --only-categories=performance \
  --output=json --output-path=/tmp/lh.json \
  --chrome-flags="--headless=new --no-sandbox --disable-gpu" \
  --quiet --max-wait-for-load=45000
```

- If the command fails because **no Chrome is found** (`chrome-launcher` error / "No Chrome installations found") → treat as **inconclusive**: do not file a task, note "Chrome not installed — cannot run Lighthouse" in the snapshot, and stop.
- If it fails for any other reason (URL unreachable, load timeout, non-zero exit with no JSON) → also **inconclusive**: record the error in the snapshot and stop. No task on a failed measurement.

Extract from `/tmp/lh.json` (use `python3 -c` or `jq` if available) — all `numericValue`s are in **ms** except CLS which is unitless:

- `audits["largest-contentful-paint"].numericValue` → **LCP** (ms)
- `audits["cumulative-layout-shift"].numericValue` → **CLS**
- `audits["total-blocking-time"].numericValue` → **TBT** (ms; INP proxy — there is no lab INP)
- `audits["first-contentful-paint"].numericValue` → **FCP** (ms)
- `audits["server-response-time"].numericValue` → **TTFB** (ms)
- `categories.performance.score` → **score** (0–1, ×100)

## Step 4 — Classify against Google thresholds

| Metric | Good | Needs improvement | **Poor → task** |
|---|---|---|---|
| LCP | ≤ 2.5 s | 2.5–4.0 s | **> 4.0 s** |
| CLS | ≤ 0.1 | 0.1–0.25 | **> 0.25** |
| TBT (lab INP proxy) | ≤ 200 ms | 200–600 ms | **> 600 ms** |
| TTFB | ≤ 0.8 s | 0.8–1.8 s | **> 1.8 s** |
| FCP | ≤ 1.8 s | 1.8–3.0 s | **> 3.0 s** |

A metric is **poor** if it exceeds the last column. If **no** metric is poor → healthy: snapshot only, no task. If one or more are poor → Step 4b.

> Note lab metrics vary run-to-run (±10–20% is normal). Only file for a clearly-poor result; a value hovering right at a boundary is not worth a task.

## Step 4b — File a task if any metric is poor

First check for an already-open web-vitals task to avoid duplicates:
```bash
~/.darkflow/df task list --source web-vitals --state open
```
If an open task already covers the same poor metric, add a comment with the new run's numbers instead of opening a duplicate.

Otherwise create a task (priority `high` if LCP/CLS/TBT — the Core Web Vitals and their proxy — are poor, else `medium`):

- `--source web-vitals --priority <high|medium>` (no `--status approved` — human triages it)
- Title: e.g. "Web Vitals: LCP 5.2s on / (poor, target ≤2.5s)"
- Body:
  ```
  ## What's slow
  <URL> (mobile, local Lighthouse lab run) as of <timestamp>.

  | Metric | Value | Band | Target |
  |---|---|---|---|
  | LCP | 5.2 s | poor | ≤ 2.5 s |
  | TBT | 240 ms | needs-improvement | ≤ 200 ms |
  | CLS | 0.03 | good | ≤ 0.1 |
  Performance score: <NN>/100

  ## Likely causes
  <best-effort hypothesis tied to the poor metric(s): e.g. LCP → unoptimized hero
  image / render-blocking CSS / slow TTFB; CLS → images without dimensions / injected
  content; TBT → heavy JS on the main thread / hydration.>

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

**Target:** <URL or "unknown">  ·  **Strategy:** mobile  ·  **Source:** lab (local Lighthouse)

## Metrics
| Time | LCP | TBT | CLS | TTFB | FCP | Score | Result | Task |
|---|---|---|---|---|---|---|---|---|
| HH:MM | 2.1s | 180ms | 0.04 | 0.6s | 1.4s | 92 | ok / poor | #N |

## Notes
<which metric(s) were poor; trend vs prior snapshots; note lab runs vary run-to-run>
```

Write `.darkflow.d/state/metrics/web-vitals.json` (create parent dirs if needed):

```json
{
  "url":        "<URL or empty>",
  "strategy":   "mobile",
  "source":     "lab",
  "score":      <0-100 or null>,
  "lcpMs":      <integer or null>,
  "tbtMs":      <integer or null>,
  "cls":        <number or null>,
  "ttfbMs":     <integer or null>,
  "fcpMs":      <integer or null>,
  "status":     "ok" | "poor"
}
```

The worker picks up this file on its next sync. You do not need to update any HTML files.
