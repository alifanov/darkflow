---
description: Review analytics and recent commits, then create tasks.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUserQuestion
---

## Step 1 — Read project config and the canonical funnel

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `minPriority`.

Analytics come from the **OpenPanel MCP** registered for this project. It uses a `read` client that is already scoped to a single project, so there is no project to select or switch — just query. If no OpenPanel MCP is available, skip the analytics part and review commits only.

**Read the project's metrics doc before querying anything** (for most projects `docs/state/product/metrics.md`; find it via the *When to read docs* table in `.darkflow.d/claude.md`). It defines the canonical funnel and the real event names. **Never invent event names** — a query for an event that does not exist returns no series, which is indistinguishable from a real zero.

### OpenPanel MCP — actual tools and their quirks

| Tool | Use |
|---|---|
| `openpanel_get_chart` | aggregates, time series, breakdowns — the workhorse |
| `openpanel_get_events` | raw events, for inspecting individual sessions |
| `openpanel_health_check` | connectivity only |

- `range` is an **enum**: `7d`, `30d`, `6m`, `12m`, `today`, `yesterday`, … — `14d` is a 400. For any other window pass `start_date` / `end_date` (ISO) instead.
- `previous: true` gives the previous-period comparison for free — use it, do not query twice.
- Breakdowns on custom properties need the `properties.` prefix (`properties.channel`); built-in names (`path`, `country`, `device`, `browser`, `os`) go bare. A bare custom name returns 500.
- `openpanel_get_events` takes `start` / `end`; `openpanel_get_chart` rejects them (`start_date` / `end_date` there).
- Several events fire **twice per action by design** (e.g. a server + client twin on signup). Check the metrics doc before reporting a count as a number of users.
- Test/QA accounts may be filtered in code, not in OpenPanel. Verify the filter still exists before trusting a signup count.
- `openpanel_get_chart` with `interval: "month"` keeps responses short when you only need totals — use it for breakdowns, which otherwise return one array per segment per day.

## Step 2 — Build the funnel

This is the core of the routine, not one bullet among many. Work over a **single 7-day window** for everything.

Produce a table with **every step of the canonical funnel**, top to bottom, no step omitted:

| Step | 7d | Step conversion | Δ vs previous 7d |
|---|---|---|---|

Rules:
- A step that is **zero** is reported as zero, with how long it has been zero. Silence about a zero step is the most expensive thing this routine can do.
- State the **single largest drop between adjacent steps** explicitly — that is the headline finding, and everything else in the report is secondary to it.
- Convert event counts to **user counts** where an event double-fires; say which you are reporting.
- If a step cannot be measured because nothing is instrumented there, that is a finding in its own right — an unmeasurable step is a blind spot, not a zero.

## Step 3 — Segment the funnel

The aggregate funnel hides which audience is actually broken. Cut it at least three ways and report each as its own table with the same columns as Step 2:

1. **Device** — `breakdowns: [{name: "device"}]` → `mobile` / `desktop` / `tablet`. A mobile-only drop-off is usually a layout or tap-target bug, not a demand problem.
2. **Country** — `breakdowns: [{name: "country"}]`. Report the top markets by traffic separately and fold the long tail into one "rest" row; a market with traffic and zero conversion is a finding, a market with three sessions is not.
3. **Entry path / source** — `breakdowns: [{name: "path"}]` on the top-of-funnel event, so you can see which landing pages carry the traffic and which carry none.

Two constraints that decide how far each cut reaches:

- **Server-side events carry no device or country.** They come back under a `server` device and a country of two NUL bytes, which most terminals render as an empty or garbled two-character string. Any funnel step emitted server-side is therefore *not* segmentable — segment down to the last client-side step, and say explicitly where the cut stops instead of reporting a server step as "unknown country".
- **Sample size.** A segment split three ways divides an already small n. Widen the window to 30 days for the segment cuts if the 7-day slice puts segments in single digits, say which window each table uses, and label a difference resting on one or two conversions as a direction, not a result. Do not file a task off a segment difference that a single extra signup would erase.

Language is usually **not** collected by OpenPanel (a `language` breakdown returns 500) — country is the available proxy. Do not report a language cut you did not actually measure.

## Step 4 — Everything else in the window

Still in the same window: activation and feature events, retention signals, anomalies. Check what commits landed over the same 7 days (`git log --since="7 days ago"`) — a metric that moved the day a commit shipped is a causal lead, not a coincidence.

Do **not** chase application/server errors here — those are `/darkflow:observability-check`.

**Skip if there is no signal.** If traffic/conversions are below a meaningful threshold for the window (e.g. only a handful of visitors, funnels with near-zero entries), the data is noise: write the snapshot (Step 7) and exit **without creating any tasks** — do not manufacture recommendations from noise.

## Step 5 — Turn findings into recommendations

Before proposing anything, check the observation threshold in `.darkflow.d/claude.md` (*Observation → task*) and the hypotheses ledger. A finding that has not cleared the threshold belongs in the ledger and the daily log, **not** in a recommendation.

**Also check what a recommendation would break.** If a pre-registered experiment is open on the same surface, acting now destroys the measurement — say so, name the date the window closes, and hold. That is a legitimate outcome, not a non-answer.

**Avoid duplicates.** List existing open tasks from this source and skip anything already filed for the same finding:
```bash
~/.darkflow/df task list --source openpanel --state open
```
If an equivalent task already exists (same metric / funnel step / page), do not create a new one — update the existing one only if the situation materially changed.

**Priority rubric:**
- `critical` — active revenue/signup loss right now (funnel fully broken, conversion dropped to ~0, checkout failing)
- `high` — clear, sizeable drop-off or regression on a key flow (onboarding, activation, purchase) with material impact
- `medium` — meaningful but non-urgent optimisation (a soft drop-off, an under-performing step)
- `low` — minor polish, instrumentation gaps, nice-to-have experiments

**Never inflate a priority to clear the project's `minPriority` floor.** If `df task create` is rejected (`priority <x> below project minPriority <y>`), keep the honest priority: record the finding in the daily log and the ledger, and surface the rejection in Step 6 so the owner can raise it by hand. A task filed at a priority it does not deserve corrupts the whole queue.

Do NOT create recommendations about paid ads — that is handled by `/darkflow:ads-review`.

Do NOT create OpenPanel dashboards, saved reports, or any other OpenPanel artifacts. OpenPanel access is read-only here: only query data.

## Step 6 — Deliver the recommendations

**Every run ends with recommendations addressed to the owner** — ranked by expected impact, numbered so they can be picked by number. Never end on "tasks created" alone, and never end on a metrics dump with no conclusion.

How they are delivered depends on the mode:

**Headless** (the routine runner: `darkflow-run.sh` → `claude -p`). No one is there to answer, so decide yourself: file each recommendation that cleared the threshold as a task (format below), then print the ranked list with the task number next to each.

**Interactive** (a human typed `/darkflow:analytics-review`). Do **not** file tasks unasked. Present the ranked recommendations, then use `AskUserQuestion` to let the owner pick which ones to file — one question, `multiSelect: true`, one option per recommendation, each labelled with its priority. File exactly what is chosen and nothing else.

Detect the mode by using `AskUserQuestion`: it is unavailable in headless runs. If the call fails or the tool is missing, you are headless — file the tasks and print the list.

**Task format (required):**

- **Title**: action-oriented verb — "Add X to onboarding funnel", "Fix drop-off on Y step", "Instrument Z event" — never just a statement of observation ("Low conversion on step 2", "Anomaly detected in signups")
- **Body**:
  ```
  ## Problem
  <what the data shows and why it matters — with the numbers, the segment it applies to, and the file:line where the code is>

  ## What to do
  <concrete action — specific page, flow, component, or event to change>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "Step 2 → Step 3 conversion rises above 60%">
  - [ ] <additional criterion if needed>
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source openpanel \
  --priority <critical|high|medium|low> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

## Step 7 — Daily log and snapshot

Append a `## Analytics` section to today's daily log, `docs/logs/$(date +%F).md` — create the
file if it is not there yet, and never touch a section another routine wrote. Reuse the exact
section heading previous runs used in this project, so the streak stays greppable.

The section carries: the funnel table, the headline drop, the segment tables (device / country /
entry path), activation and feature counts, ledger updates, and — when a finding did not become
a task — **why not** (below threshold / blocked by an open experiment / rejected by the priority
floor).

**Found nothing? Append nothing.** No section, no "all clear" line. Silence is the clean
result, and the observation threshold counts on it (see `.darkflow.d/claude.md`).

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

Then save an analytics snapshot so the Dark Flow worker can forward it to the web UI.

Write `.darkflow.d/state/metrics/analytics.json` with the following structure (create parent
directories if they don't exist):

```json
{
  "usersTotal":  <integer or null>,
  "visitors7d":  <integer or null>,
  "revenue7d":   <float or null>,
  "adsSpend7d":  null,
  "currency":    "USD"
}
```

Fill in the values from the analytics data already queried above (7-day window). Use `null`
for any metric that is not available for this project. Always leave `adsSpend7d` as `null` here —
ad spend is owned by `/darkflow:ads-review`; do not query or estimate it in this routine.

The worker will pick up this file on its next sync and forward it to the webapp API together
with the current issue list. You do not need to update any HTML files or call any API endpoints.
