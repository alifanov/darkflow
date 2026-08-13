---
description: Score the product against the Dark Flow readiness checklists by group. Report only — files no tasks.
allowed-tools: Bash, Read, Write, Glob, Grep, WebFetch
---

Scores this product against the readiness checklists shipped with Dark Flow — the accumulated
knowledge of what the portfolio has already got wrong, grouped by discipline.

The other audit routines hunt for *new* findings. This one asks a narrower question: of the
things we already learned the expensive way, which ones does this product still get wrong?

**Report-only.** No tasks are created, nothing is committed. The output is a score and a table.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses:
`language`, `domain`, `stagingUrl`.

Check `stagingUrl` when it is set, otherwise `domain`. **Never take a step that writes real
data** — no live payments, no real emails, no destructive account actions. Items that would
require one are `n/a`, and the report says which and why.

## Step 2 — Resolve the group

`$ARGUMENTS` selects the group. Empty → `all` (the worker always invokes with no argument).

Valid: `code`, `architecture`, `ux`, `seo`, `ads`, `security`, `analytics`, `ops`, `all`.

Anything else: print the valid list and stop. Do not guess at what was meant.

## Step 3 — Load the checklists

```bash
ls ~/.darkflow/checklists/
```

Read the `.yml` file for each selected group. Each carries two lists:

- `items` — what must hold. Fields: `id`, `severity`, `title`, `applies_when`, `check`, `source`.
- `never_flag` — known false positives, verified not worth fixing.

If the directory is missing, say so and stop: this Dark Flow install predates the checklists,
and re-running the installer fixes it. **Never invent items.** The checklists are the contract;
a check that is not in them does not belong in this report.

## Step 4 — Evaluate

For each item, decide `applies_when` first. If it does not apply, mark `n/a` and move on.

Then gather evidence and follow the item's `check` literally:

- repo evidence — Grep, Glob, Read. Cite `file:line`.
- live evidence — WebFetch against the URL from Step 1. Cite the URL and what came back.

Verdict per item:

| Verdict | Means |
|---|---|
| `pass` | verified against concrete evidence |
| `fail` | verified broken, with the evidence that shows it |
| `n/a` | does not apply, or could not be checked without writing real data |

**No evidence → `n/a`, never `pass`.** An item nobody verified must not inflate the score.
Say plainly which items could not be checked and why — a report that hides its own gaps is
worse than a short one.

## Step 5 — Apply `never_flag`

Anything matching a `never_flag` entry is **suppressed**: never a `fail`, never a
recommendation, never counted. List them separately so it is visible that they were considered
and deliberately dropped.

This is the point of the group. Each entry is a rule that was learned once and then kept being
re-discovered by audits — a lesson that never reached the agent stays a lesson that keeps
costing time.

## Step 6 — Report

Print, in the `language` from the project config:

- one line per group: `passed / applicable` and the score
- every `fail`, with its severity, its evidence, and its `source`
- items that came back `n/a` because they could not be verified
- suppressed `never_flag` matches

`n/a` is excluded from the denominator. No weighting — a score is a reading, not a verdict.

**Everything passed? Say exactly that, in one line, and write the file anyway.** This routine is
not subject to the silence rule: unlike an observation stream, a readiness score is only useful
when it is current, and a missing file cannot be told apart from a run that never happened.

## Step 7 — Write the snapshot

Write `docs/state/readiness.md`, overwriting in place — `docs/state/` is "how things are right
now" (A4). **Do not touch `docs/logs/`**: that is append-only history, and this is a snapshot.

When the run covered a single group, replace only that group's section and leave the rest of the
file as it was.

```markdown
# Readiness

**Checked:** <date> · groups: <groups> · target: <URL or "repo only">

| Group | Score | Passed | Failed | N/A |
|---|---|---|---|---|
| | 8/11 | 8 | 3 | 3 |

## <Group>

| Item | Verdict | Evidence | Source |
|---|---|---|---|
| | fail | `src/app/sitemap.ts:14` | seo/0028 |

### Could not verify

<item → why>

### Suppressed (never_flag)

<rule → why it is not a finding>
```

**Commit nothing and push nothing.** The file stays in the working copy; the next pull request
carries it, and `fix-issues` already stages `docs/state/`.
