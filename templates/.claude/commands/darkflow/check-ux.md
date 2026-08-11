---
description: Walk the key flows in a real browser at mobile and desktop viewports, then a task per friction point.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

The **behavioural** half of design review. `check-design` looks at surfaces; this one *uses the
product* — clicks through the real flows in a real browser, at a phone width and a desktop width,
and reports where a person would get stuck.

A screenshot of a page proves the page renders. It proves nothing about whether the third step
of checkout can be completed. Only walking it does.

**Proposal-only.** Findings become tasks; nothing is changed here.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `stagingUrl`, `domain`.

Walk `stagingUrl` when it is set, otherwise `domain`. **Never walk a production flow that writes
real data** — no live payments, no real emails, no destructive account actions. If only `domain`
is set, stop before any irreversible step and note in the snapshot which step you could not take.

If neither URL is set, there is nothing to walk: write nothing and stop. Do not substitute a
code reading — that is `check-design`'s job, and a flow that was never walked must not be
reported as if it had been.

## Step 2 — Pick the flows

Read `docs/spec/flows/` when it exists — those are the flows the product says it has.
Otherwise derive them from `sitemap.xml` and the navigation: the entry path (landing → signup),
the core job the product exists for, and the money path (pricing → checkout) when there is one.
Three to five flows. More than that and nothing gets walked properly.

## Step 3 — Walk them

Use the `ego-browser` skill (fall back to `agent-browser`) at two viewports:

- **mobile** — 390 × 844
- **desktop** — 1440 × 900

For every flow, at both widths, record what actually happened at each step:

- Does each step complete, and is the next one obvious without hunting?
- Loading, empty, and error states — trigger them: submit the form empty, use a bad value, open a
  list with no items. A state nobody can reach is not a state.
- Anything that only breaks at one width — a tap target too small, a modal that traps scroll, a
  sticky bar covering the submit button.
- Where you had to stop and think. That hesitation is the finding.

## Step 4 — Scored critique

/impeccable:critique

## Step 5 — Deduplicate, then file

Read **every** task in the project, not just this routine's own:

```bash
~/.darkflow/df task list --state all --format compact
```

`check-design` and this routine see the same screens; filtering by `--source` would file the same
problem twice. Skip anything already tracked **or** already dismissed (closed without a merged
fix — rejected). Re-file only when a previously-fixed problem has demonstrably regressed.

- `--source ux`, `--status proposed`
- Priority:
  - `high` — a flow that cannot be completed at one of the viewports, a dead end with no way back, a missing error state on a critical path
  - `medium` — friction that costs a step or a guess, an unclear empty state, an inconsistent pattern between two flows
  - **minor polish → no task.** Snapshot Recommendations, nowhere else.

**Title**: action-oriented verb naming the flow and the viewport where it broke — "Fix checkout
step 3 unreachable on mobile (390px)", "Add error state to signup form on invalid email",
"Clarify empty state on projects list". Never a bare observation.

**Body:**

```
## Problem
<flow, step, viewport. What you did, what happened, what you expected>

## What to do
<concrete change — specific page, component, copy or flow step>

## Acceptance criteria
- [ ] <verifiable outcome — the flow completes at 390px, the error message appears, …>
```

```bash
~/.darkflow/df task create --title "<title>" --source ux \
  --priority <high|medium> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from the project config.

## Step 6 — Docs snapshot

Write `docs/insights/ux/YYYY-MM-DD.md` (today's date; append a section if it exists):

```markdown
# UX — YYYY-MM-DD

**Walked:** <URL> · mobile 390×844, desktop 1440×900

## Flows

| Flow | Mobile | Desktop | Where it broke |
|---|---|---|---|
| | pass / friction / fail | pass / friction / fail | |

## States checked

| Screen | Loading | Empty | Error |
|---|---|---|---|
| | ok / missing | ok / missing | ok / missing |

## Not walked

<steps skipped because they would write real data, and why>

## Recurring

<findings appearing in 2+ consecutive walks — note how many in a row>

## Recommendations

<flow → what to improve → acceptance criterion>
```

No metrics file: nothing in the worker forwards a UX metric today, and writing one nobody reads
only freezes a widget on a stale value.
