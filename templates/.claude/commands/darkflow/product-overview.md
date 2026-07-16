Produce a concise product overview — the current state of the product plus what we recently improved (product and technical) and what we're betting on next. This is a **narrative digest for a human**, not a checklist.

It consolidates signals that already exist (docs, git history, tasks, insight snapshots) into one executive summary. It does **not** create tasks (that's the job of the review routines) and it does **not** audit docs-vs-code drift (that's `/darkflow:docs-audit`) — it reads, synthesizes, and writes a snapshot.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the default.

## Step 2 — Gather the inputs

Read the product layer for current state:
- `docs/product/product.md`, `docs/product/positioning.md`, `docs/product/roadmap.md` (skip any that are stubs/missing)

Read recent history for what changed:

```bash
git log --oneline -40
git log --oneline -40 --grep='^fix' --grep='hotfix' --grep='bug' -i   # recent bug fixes
git diff --stat HEAD~25..HEAD 2>/dev/null
```

Read what's in flight and what was recently resolved (skip gracefully if `~/.darkflow/df` is unavailable):

```bash
~/.darkflow/df task list --state open
~/.darkflow/df task list --state closed
```

Read the latest hypotheses and signals — read the central ledger `docs/product/hypotheses.md` (if present) for the current bets and their verdicts, then scan the most recent 1–2 files in each `docs/insights/*/` folder for standout findings and any `## Hypotheses` pointers. This is where recent product bets live.

## Step 3 — Synthesize the overview

Write the overview to `docs/insights/product-overview/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists). Keep it executive-summary length — reference specifics (commit subjects, issue numbers, file paths), don't pad.

```markdown
# Product Overview — YYYY-MM-DD

**Period covered:** <date range of the history reviewed>

## Current state

<what the product does today, in 3–5 sentences, grounded in docs/product + the code>

## Recent improvements

### Product
<user-facing features/changes shipped recently — from feat: commits and closed feature issues>

### Technical
<notable refactors, infra, performance, debt paid down>

## Bugs & fixes

- **Fixed recently:** <bugs resolved — from fix:/hotfix commits and closed bug tasks>
- **Still open & notable:** <open bug tasks that matter, with #N>

## Active hypotheses

<product bets currently being tracked — pulled from docs/product/hypotheses.md (fall back to insights/*/ Hypotheses sections), each with its evidence status, e.g. "tracking, 2/3 snapshots" — plus recently closed verdicts worth noting>

## Open threads

<what's in flight or queued — approved/in-progress tasks, roadmap items>

## Recommendations — top 3 next moves

1. <move> — <why, grounded in the above>
2. ...
3. ...
```

## Step 4 — Report to the user

Return a short chat summary (current state + the top 3 next moves) and a pointer to the snapshot file you wrote. The snapshot is the source of truth; the chat response is the summary.

The overview creates no issues and changes no other files — if a recommendation is worth acting on, the human approves it and the review/fix routines pick it up.
