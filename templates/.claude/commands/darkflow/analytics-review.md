---
description: Review analytics and recent commits, then create tasks.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, AskUserQuestion
---

## Step 1 — Config, funnel definition, signal gate

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `minPriority`.

Analytics come from the **OpenPanel MCP** registered for this project — a `read` client already
scoped to one project, so there is nothing to select. **No OpenPanel MCP → stop here**: write the
snapshot (Step 6) with `null` values and exit without tasks.

**Read the project's metrics doc before querying anything** (usually
`docs/state/product/metrics.md`; find it via *When to read docs* in `.darkflow.d/claude.md`). It
defines the canonical funnel, the real event names, and any project quirk that changes how a
number is read — events that fire twice per action, test accounts filtered in code rather than in
OpenPanel. **Never invent event names**: a query for an event that does not exist returns no
series, which is indistinguishable from a real zero.

**Then the gate, before any other query.** Pull visitors and top-of-funnel entries for the 7-day
window. If either is under **100 visitors** or **10 funnel entries**, the window is noise: write
the snapshot (Step 6), append nothing to the log, create no tasks, and say in one line which
number failed the gate. Everything below assumes the gate passed.

Query notes that change the data rather than the call: `previous: true` returns the
previous-period comparison in the same call — always use it instead of querying twice. Custom
properties in a breakdown need the `properties.` prefix; built-ins (`path`, `country`, `device`,
`browser`, `os`) go bare. Keep the whole run inside **one 7-day window** and under ~15 chart
calls; if a cut needs more, drop the cut.

## Step 2 — The funnel

The core of the routine. A table with **every step of the canonical funnel**, top to bottom, no
step omitted:

| Step | 7d | Step conversion | Δ vs previous 7d |
|---|---|---|---|

- A step that is **zero** is reported as zero, with how long it has been zero.
- State the **single largest drop between adjacent steps** explicitly — that is the headline
  finding, everything else is secondary to it.
- Convert event counts to **user counts** where an event double-fires; say which you report.
- A step nothing is instrumented for is a blind spot, not a zero — that is a finding in itself.

## Step 3 — Segment the largest drop

Do **not** cut the whole funnel three ways by default. Take the step with the largest drop and cut
**that step** by `device`, then by `country`, then by entry `path` — stopping as soon as a cut
leaves segments in single digits. Widen to 30 days if that rescues the sample; say which window
each table uses. A difference resting on one or two conversions is a direction, never a result,
and never a task.

**Server-side events carry no device or country** (they return device `server` and a two-NUL
country). Segment down to the last client-side step and say where the cut stops, rather than
reporting a server step as "unknown".

## Step 4 — Everything else in the window

Same window: activation and feature events, retention signals, anomalies. Check what shipped over
the same 7 days (`git log --since="7 days ago"`) — a metric that moved the day a commit landed is
a causal lead.

Application and server errors are `/darkflow:observability-check`; paid ads are
`/darkflow:ads-review`; OpenPanel access here is read-only — never create dashboards or saved
reports.

## Step 5 — Findings → recommendations → delivery

**Threshold.** Check the streak before proposing anything (*Observation → task* in
`.darkflow.d/claude.md`):

```bash
~/.darkflow/df runs analytics-review --limit 5     # how many times this routine actually ran
rg -l '^## Analytics' docs/logs/                   # which days carried the observation
```
A finding below the threshold goes to `docs/state/hypotheses.md` and the daily log, not into a
recommendation. Read that ledger first — a refuted bet does not come back without new data.

**Blocked by an experiment.** If a pre-registered experiment is open on the same surface, acting
now destroys the measurement: say so, name the date the window closes, and hold.

**Duplicates.** A funnel finding is often already filed by another routine on the same page or
flow, so check wider than your own source:

```bash
~/.darkflow/df task list --state open
```
Same metric / funnel step / page → do not file again; update the existing task only if the
situation materially changed.

**Priority:** `critical` — revenue or signup loss right now · `high` — sizeable drop-off on a key
flow · `medium` — non-urgent optimisation · `low` — polish, instrumentation gaps. **Never inflate
a priority to clear `minPriority`.** If `df task create` is rejected (`priority <x> below project
minPriority <y>`), keep the honest priority, log the finding, and surface the rejection in the
output so the owner can raise it by hand.

**Delivery.** Every run ends with recommendations addressed to the owner, ranked by expected
impact and numbered so they can be picked by number — never on "tasks created" alone, never on a
metrics dump with no conclusion. `$DARKFLOW_HEADLESS` is set when the worker runs this routine:

- **Set** — no one is there to answer: file each recommendation that cleared the threshold, then
  print the ranked list with its task number next to each.
- **Unset** (a human typed `/darkflow:analytics-review`) — file nothing unasked: present the
  ranked list, then one `AskUserQuestion` (`multiSelect: true`, one option per recommendation
  labelled with its priority) and file exactly what is chosen.

**Task format (required):**

- **Title**: action-oriented verb — "Fix drop-off on Y step", "Instrument Z event" — never a
  statement of observation ("Low conversion on step 2")
- **Body**:
  ```
  ## Problem
  <what the data shows and why it matters — numbers, the segment it applies to, file:line>

  ## What to do
  <concrete action — specific page, flow, component, or event>

  ## Acceptance criteria
  - [ ] <measurable outcome, e.g. "Step 2 → Step 3 conversion rises above 60%">
  ```

```bash
~/.darkflow/df task create --title "<title>" --source openpanel \
  --priority <critical|high|medium|low> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

## Step 6 — Snapshot, then the daily log

**Write the snapshot first** — a run that dies later still leaves the web UI a fresh number.
`.darkflow.d/state/metrics/analytics.json` (create parent directories):

```json
{
  "usersTotal":  <integer or null>,
  "visitors7d":  <integer or null>,
  "revenue7d":   <float or null>,
  "adsSpend7d":  null,
  "currency":    "USD"
}
```

`visitors7d` comes from the gate query in Step 1. `usersTotal` and `revenue7d` are **not** part of
the funnel window — fill them only if the metrics doc names the event that carries them (a
lifetime user count, a purchase event with a value property); otherwise `null`. Never estimate.
`adsSpend7d` stays `null` here — ad spend is owned by `/darkflow:ads-review`.

Then append a `## Analytics` section to `docs/logs/$(date +%F).md`, reusing the exact heading
previous runs used so the streak stays greppable. It carries: the funnel table, the headline drop,
the segment tables, activation and feature counts, ledger updates, and — when a finding did not
become a task — **why not** (below threshold / open experiment / priority floor).

**Found nothing? Append nothing.** No section, no "all clear" line. Silence is the clean result,
and the observation threshold counts on it.

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

The worker picks the snapshot up on its next sync — no HTML to update, no API to call.
