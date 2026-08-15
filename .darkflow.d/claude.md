## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/tasks.md
@docs/auto-approve.md
@.darkflow.d/constraints.md

### Project constraints

Before proposing or making **any** change — especially in analysis/optimization routines that
file tasks — honor every constraint in `.darkflow.d/constraints.md`. If a finding would violate
a constraint, drop it: do not file the task and do not make the change.

**Communication language:** Russian — use it ONLY for human-facing text you write *about* the work: tasks, comments, commit messages, PR descriptions, and console/chat output.
**Product language:** English — everything shipped *inside* the product is always written in English, regardless of the communication language: source code, identifiers, code comments, UI copy, user-facing strings, logs, and in-product docs. Setting the communication language to anything other than English never changes this.
**Main branch:** `main`
**Fix Issues strategy:** open a pull request referencing "Task #N", then merge into `main`.
**Workspace rule:** never create a git worktree (`git worktree add`) — always work in the project root on `main`. If the PR strategy needs a feature branch, create it in place with `git checkout -b` based off `main`.

### Project config

Every routine command starts by loading this — the contract is here, once, instead of
being copy-pasted into each command:

```bash
bash ~/.darkflow/get-config.sh          # pulls the latest settings from the Web UI
cat .darkflow.d/state/config.json       # and caches them here
```

`get-config.sh` falls back to the cached file silently when the server is unreachable.
If the file is missing entirely, carry on with the defaults below — never stop for it.

| Key | Meaning | Default |
|---|---|---|
| `language` | language for tasks, comments and console output | English |
| `branch` | base branch | `main` |
| `mergeStrategy` | `pr` or `direct` — how a fix lands | `direct` |
| `domain` | public production URL | none — auto-discover or skip live checks |
| `stagingUrl` | pre-production URL, when the project has one | none |
| `coolify_app` | Coolify app UUID | none — resolve it at run time |

A command names only the keys it actually uses; everything else about this step is here.

### How to write

Terse. Bullets, numbers and tables carry more than paragraphs do, and a routine's output
is read at a glance, not studied.

- No preamble, no restating the task, no summary of what you are about to do.
- Task comments: 1–3 sentences. What changed, and where.
- **Never write "looks fine overall", "no major issues", or an empty section to prove you
  ran.** A clean run says nothing at all — silence *is* the clean result.
- Findings get a number, a file and a line. "Some components could be improved" is not a finding.

### The daily log

One document per day: `docs/logs/YYYY-MM-DD.md`. Every routine appends its own section to
today's file — `## Security`, `## Analytics`, `## Performance`, `## Changes`, `## UX`, one per
source. Create the file if it is not there yet; **never rewrite a section someone else wrote**,
and never rewrite yesterday's file.

One file a day beats one file per routine per day: the whole day is read at once, and a routine
that found nothing leaves no trace at all instead of a file saying "nothing found".

**A clean run appends nothing.** No section, no heading, no "no issues this run". That silence
is what makes the threshold below work.

Logs are never rotated. A file a day is small, and moving old ones away would break the streak
count — the history the threshold reads is exactly the history that would have been archived.

### Observation → task

Two different things arrive at this decision, and they are not treated the same.

**An incident** — something is broken *right now*: the site is down, a deploy failed, an error is
firing in production, a dependency has a known exploit. File it on **first sight**, `--status
approved`, so `fix-issues` takes it on the next tick. No threshold, no waiting.

**An observation** — something that might be worth improving: a metric drifting, a page getting
slower, a pattern that looks wrong. File it only once it has shown up in **3 consecutive runs**,
or in **2 independent sources** on the same run. Anything less is noise; a one-off number is a
one-off number.

Counting is over *runs*, not over log files. A clean run writes no section, so:

```bash
~/.darkflow/df runs <routine> --limit 5   # how many times this routine actually ran, and when
rg -l '^## <Section>' docs/logs/          # which days carried the observation
```

A run that left no section **breaks the streak** — it is evidence the thing was not there, not a
gap in the record.

**Improvements are `proposed`, never `needs-human`.** In Dark Flow `needs-human` is the status
meaning "the agent is stuck: no access, no config, the checks failed" — one status value, so a
task is never both. The triage queue in the Web UI is already where a proposal waits for the owner.

### What a routine commits

An audit writes into the repo — its daily-log section, sometimes a `docs/state/` file. Left
uncommitted those pile up and leak into whatever branch the next `fix-issues` run opens.

Two preconditions hold in **every** mode, and they are not negotiable:

1. **`HEAD` is on the base branch.** If it is not, the previous run left the checkout dirty:
   write nothing, commit nothing, say so, and stop. Committing onto someone else's feature
   branch is worse than doing nothing.
2. **A routine stages only its own paths.** Explicitly listed, one by one. `git add -A` is never
   correct here — it sweeps up whatever else happens to be in the working copy.

This project is on the **pr** strategy, so a routine **commits nothing and pushes nothing**. It
leaves the file in the working copy; the next pull request carries it along. Pushing straight to
`main` would bypass the review the strategy exists for.

`fix-issues` is what closes that loop: alongside the files of the task it is fixing, it also
stages `docs/logs/` and `docs/state/` when they changed. Still an explicit list — just a longer one.

An audit's own daily-log section therefore sits uncommitted until the next PR. That is expected,
and `housekeeping` knows it: its "uncommitted changes" check ignores those two paths.

### Before each session

Check approved task queue:
```bash
~/.darkflow/df task list --status approved --state open
```
If there are approved tasks matching the current context — pick them first.
Before starting: set status to `in-progress`, leave a comment with the branch name.

### After each push

Confirm CI is green in the same session — don't push and walk away:
```bash
~/.darkflow/ci-wait.sh; echo "ci-wait exit: $?"
```
`0` = green (or no CI) · `2` = no run for this commit · `1` = **red — fix it or hand it to a human before finishing**.

### When to read docs

- **Any UI/UX task** → `docs/state/spec/screens.md` + `docs/state/spec/flows/`
- **Changing a user flow** → `docs/state/spec/flows/`
- **Product / marketing decisions** → `docs/state/product/positioning.md` + `docs/state/product/product.md` + `docs/state/product/pricing.md`
- **Context on what's working / broken right now** → the last 2–3 files in `docs/logs/`
- **Before architectural changes** → `docs/state/arch.md` — the current map and its `## Decisions` table

### When to write docs

- **Changed a user flow** → update `docs/state/spec/flows/*.md`
- **Added / removed a screen** → update `docs/state/spec/screens.md`
- **Changed data model** → update `docs/state/spec/data-model.md`
- **Changed system shape** (new service, integration, stack swap) → update `docs/state/arch.md`
- **Changed pricing / billing** → update `docs/state/product/pricing.md`
- **Made an architectural decision** → add a line to `## Decisions` in `docs/state/arch.md` (date · decision · why · where it shows)
- **Anything a data run observed** → your section of today's `docs/logs/YYYY-MM-DD.md` — one file a day, one section per source; a clean run writes nothing

### Active Routines

Scheduled Claude Code agents that run this workflow automatically:

- **Fix issues** (Hourly) — picks up an approved task → PR → merge to main
- **Build optimization** (Weekly Sun 4:00) — build + deploy pipeline analysis → tasks
- **Uptime check** (Every 4h) — DNS + HTTP + page-load check; site down → auto-approved critical task

Schedule: managed in the Web UI (Settings → Routine schedule)  |  Worker: one global `~/.darkflow/darkflow-run.sh` services every project
Run any routine manually (from this project dir): `~/.darkflow/darkflow-run.sh <name>`
List status (from this project dir): `~/.darkflow/darkflow-run.sh --list`

### Dark Flow commands

Use `/darkflow` inside Claude Code to check workflow health and review the approved queue.

Workflow commands: `/darkflow:add-issue`, `/darkflow:update`, `/darkflow:install`.

Manual commands (run by hand, never scheduled):
- `/darkflow:checklist-review [group]` — score the product against the readiness checklists in `~/.darkflow/checklists/`; report only, files no tasks
- `/darkflow:submit-to-directories [n|name]` — submit the product to the directories in `~/.darkflow/directories.csv` through a real browser; state in `docs/state/directories.md`, never pays

Routine commands (run any routine interactively or use as the routine prompt):
- `/darkflow:fix-issues` — pick up one approved task and close it
- `/darkflow:security-audit` — GitHub alerts + code review + live check → tasks
- `/darkflow:build-optimization` — build + deploy optimization analysis → tasks
- `/darkflow:uptime-check` — DNS + HTTP + page-load check; site down → auto-approved critical task
