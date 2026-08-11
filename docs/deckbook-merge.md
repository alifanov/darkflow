# Deckbook merge — decision log

Working document for folding [Deckbook](https://github.com/alifanov/deckbook) into Dark Flow.
Dark Flow is the base; Deckbook contributes ideas, not code.

**Status:** every decision is settled. Nothing is implemented yet — this file records what we agreed to
do; the order of the work is at the bottom.

## Why

The two projects answer the same question — "agents run on a schedule and keep the tasks themselves" —
with ~80% overlapping surface: Postgres + Prisma + Next.js, a task store, one `fix` routine that takes a
task to a merged PR, and a set of periodic audits (security, architecture, build, uptime, logs,
performance, SEO, ads, analytics, docs, design, mail) that differ mostly in wording.

Where they genuinely differ:

| | Dark Flow | Deckbook |
|---|---|---|
| Agent ↔ tasks | `df` CLI over HTTP API | MCP server per project, token = access boundary |
| Scheduling | own global worker under launchd | Claude Code cloud scheduled-tasks |
| Task model | flat `Issue`, comments as JSON | task tree, due-day, recurrence, assignee, comments table |
| Docs | plain Markdown in the repo (`docs/`) | documents stored in the app DB, edited over MCP |
| Distribution | `install.sh` as the product | one deployed app + `/deckbook:init` |

## Architecture

| # | Decision | Source |
|---|---|---|
| A1 | **Docs stay plain text in the repository.** Deckbook's document tree lives in the DB and is edited over MCP; we keep files under `docs/` and take only the *shape* from Deckbook. | owner |
| A3 | **Daily log** — one document per day, sections per source (`## Security`, `## Analytics`, `## Changes`, …), append-only. As files: `docs/logs/YYYY-MM-DD.md`. Replaces the per-routine snapshot files under `docs/insights/<area>/`. | Deckbook `logs/` |
| A4 | **`state/` layout for docs** — "how things are right now", overwritten in place: `arch` · `hypotheses` · `spec/` · `product/` · `design/`. | Deckbook `state/` |
| A5 | **Behaviour rules move into the commands**: the observation → task threshold, the incident-vs-proposal rule, and the terseness rule. | Deckbook command preamble |
| A6 | **Scheduling stays on Dark Flow's own worker** (launchd, cron in the DB). Cloud scheduled-tasks are not adopted. | owner |
| A7 | **Routines commit what they write.** Every routine that produces a file — the daily log, a `state/` update — stages exactly those paths and commits them itself. Today's audits write snapshots and never commit, so they pile up uncommitted in the working copy and leak into whatever branch `fix-issues` opens next | gap found while reviewing |
| A8 | **One archive: `docs/_archive/`.** Superseded layouts, retired documents and the existing `docs/insights/` snapshots move there. Nothing is archived under `state/` | gap found while reviewing |

## Not doing

| # | Not doing | Why |
|---|---|---|
| R1 | MCP server on top of Dark Flow tasks | `df` CLI + HTTP API already cover it |
| R2 | Subtask tree (`parent`/`children` on tasks) | flat tasks have been enough so far |
| R3 | Due-day + recurrence (task hidden from the agent until its date) | `--after` snooze covers the same need |
| R4 | Agent tokens + assignee | one worker, one machine, no ambiguity about who took the task |
| R5 | Owner authentication in the webapp | runs on localhost only |
| R6 | Port Deckbook's vitest suite | worth doing, but not part of the merge |
| R7 | Move comments out of the `Issue.comments` JSON column into their own table | no use case behind it. One worker means one author; stuck-task recovery reads `updatedAt`, not the feed. A migration for tidiness only |
| R8 | Delta against the previous run | `RoutineLog` records no success/failure, so "since last run" would happily start from a crashed run and skip a window. Adding a status column to make one optimisation work is not worth it |
| R9 | Rotate the daily log | a file a day is small, and rotation was the only thing that made the observation threshold (P4) unreliable: the history it counts against would have been moved away. Logs stay in `docs/logs/` |

## Retiring Deckbook

Deckbook stops being an operating tool once this lands.

- Delete the `/deckbook:*` slash commands (`~/.claude/commands/deckbook/`, 21 files).
- Delete the `deckbook-*` scheduled tasks with them — each one's prompt is a single `/deckbook:<name>`
  line, so leaving them behind means fifteen cron entries firing at a command that no longer exists.
- The Deckbook database and repository are left alone. What happens to the tasks and documents already
  in it is a separate decision, not part of this merge.

## Commands

Findings from comparing 27 Dark Flow commands + `install.sh` against 21 Deckbook commands.

### Merge overlapping commands

| # | Decision | |
|---|---|---|
| C1 | `security-audit` + `vulnerability-check` → one command, **weekly on Opus** | do |
| C2 | `architecture-review` + `code-health` → one command. The fallow step stays optional — it only covers TS/JS, the rest of the review does not | do |
| C3 | `observability-check` + `web-vitals` → one command | **no** — different sources and different cadence (logs daily, Lighthouse weekly). They do share one `## Performance` section in the daily log |
| C4 | three design commands (`design-audit` / `design-critique` / `design-harden`) → `check-design` (visual) + `check-ux` (flows) | do — also delivers P8 |
| C5 | **delete `routines/` entirely**, and delete the schedule tables it duplicates | do |

On C1: the two routines run on different budgets today — `vulnerability-check` daily on Sonnet (a GitHub
API call), `security-audit` weekly on Opus (a full code review). The merged routine takes the expensive
side: weekly, Opus. The cost is response time on dependency alerts — a Dependabot advisory can now sit
for up to seven days instead of one. Accepted knowingly.

On C5: the schedule is currently written by hand in five places — `routines/<name>.md`,
`routines/README.md`, `README.md`, the summary `install.sh` echoes at the end, and the catalog. Only the
catalog (`webapp/src/lib/routines.ts`) and the DB (`RoutineConfig`) are real; the cards go stale the
moment a schedule changes in the Web UI, which is exactly why they drifted from the commands.

The repository ends up with one file per routine — the prompt. The hand-written tables in `README.md`
and the `install.sh` summary are **deleted, not regenerated**: generating them would mean a script plus a
CI check to keep them honest, all for a table that the Web UI already shows. `README.md` links there
instead. `routines/ci-watch.md` is the one card worth keeping — that routine is pure bash inside the
worker and has no command file, so its text moves to `docs/`.

### Drop

| # | Decision | |
|---|---|---|
| D1 | Drop `grill` — generic skill, duplicates `mattpocock-skills:grilling`, unrelated to Dark Flow | do |
| D2 | Drop `claude-md-update`, together with the `MOD_CLAUDE_UPDATE` installer module | do |
| D3 | Drop `csp-setup` outright — one-time setup, done by hand once per project. Its instructions are not kept anywhere; git history has them if they are ever needed | do |
| D4 | Drop `product-overview` — `state/` plus the daily log carry that role once A3/A4 land | do |

### Adopt from Deckbook

| # | Decision | |
|---|---|---|
| P1 | Frontmatter on every command: `description` (one line) + `allowed-tools`. **Not read-only audits** — A3 has every audit append to the daily log and A7 has it commit, and `allowed-tools` cannot restrict `Write` to one directory. The list only keeps out what a routine has no business doing at all | do |
| P2 | Terseness rule — bullets, numbers and tables over prose; 1–3 sentence task comments; no "looks fine overall". Written **once** in `.darkflow.d/claude.md`, not copied into every command | do |
| P3 | Incident-vs-proposal rule: broken right now → filed straight to `approved`; improvement beyond the finding → `proposed`, where the triage queue in the Web UI already waits for the owner. **Not `needsHuman`** — in Dark Flow that flag means "the agent is stuck: no access, no config, checks failed", and it is mutually exclusive with `approved`. Deckbook's `needs_human` carries both meanings; ours does not | do |
| P4 | Observation → task threshold: 3 consecutive logs or 2 independent sources. Applies to observations only (logs, analytics, performance); incidents file a task on first sight. Depends on A3 — without a log history there is nothing to compare against | do |
| P5 | No product passport document and no "key pages" column that nobody would fill in. `Project` + `config.json` gain **one** field — the staging URL. Commands that need pages to walk read `sitemap.xml` | do |
| P7 | Deduplicate against all project tasks, not just `--source X` — otherwise the same problem lands twice from two different audits. This is a `--format compact` flag on the existing `df task list --state all`, not a new command | do |
| P8 | `check-ux` — walk the key flows in a real browser at mobile and desktop viewports | do (via C4) |
| P9 | Drop the copy-pasted "Step 1 — Read project config" block (~15 lines × ~20 commands). The config contract is described once in `.darkflow.d/claude.md`; commands keep a one-line instruction | do |

### Installer

| # | Decision | |
|---|---|---|
| I1 | `install.sh` reconciles `docs/` against the reference layout: create what is missing, move a superseded layout and the old `docs/insights/` snapshots into `docs/_archive/` after confirmation, never delete silently | do |

Everything else about `install.sh` stays — project registration in the webapp, launchd plists, legacy
cleanup, `--dry-run` / `--force`, the `@`-include into `CLAUDE.md`, the checklist, and the optional
modules are all ahead of what `/deckbook:init` does.

### Housekeeping

| # | Decision | |
|---|---|---|
| H | **One `housekeeping` pass in the worker, in bash, once a day — not two agent routines.** Neither job needs reasoning, and `ci-watch` already proves the pattern: pure bookkeeping runs in the worker at zero token cost | do |

```
stuck tasks   status=in-progress AND updatedAt < now()-4h  → comment + back to approved
worktrees     git worktree prune; delete merged branches
              skip anything with uncommitted changes — the one judgement call, made by a rule
```

Dark Flow has no stuck-task recovery at all today: a task abandoned by a killed session stays
`in-progress` forever and no later run picks it up.

## Order of work

Sequence matters in two places: shared text has to be extracted **before** commands are merged (otherwise
the same boilerplate is merged twice), and the docs migration has to come **after** the new layout is
settled.

```
1. Prune      C5 (delete routines/ + schedule tables) · D1–D4 (drop four commands and their modules)
2. Extract    P2 · P9 · P1 — shared rules into .darkflow.d/claude.md, frontmatter on every command
3. Merge      C1 · C2 · C4 (+ P5, P7 while touching the commands)
4. Log        A3 · A7 · P3 · P4 — the daily log exists, routines write and commit sections
5. State      A4 — the new docs layout and its templates
6. Migrate    I1 · A8 — installer reconciles docs/, old snapshots into docs/_archive/
7. Worker     H — the daily housekeeping pass
8. Retire     delete /deckbook:* commands and the deckbook-* scheduled tasks
```

## What this adds up to

- **Commands:** 27 → ~20. Four dropped (`grill`, `claude-md-update`, `csp-setup`, `product-overview`),
  four merged into two (C1, C2), three design commands into two (C4). Housekeeping adds no commands —
  it runs in the worker.
- **Files:** `routines/` (24 files) deleted, along with the schedule tables in `README.md` and
  `install.sh`; the "read the config" block and the terseness rule stop being duplicated across commands.
- **Docs:** `docs/insights/<area>/` snapshots give way to one daily log plus `state/`; one archive at
  `docs/_archive/`; the installer migrates existing projects.
- **DB:** one new field — the staging URL on `Project`. No new tables, no schema churn.

## Known gap

C2 merges two routines that sit behind **different installer modules** (`arch-review` and `fallow`), and
D2/D4 remove the `claude-update` and `product-overview` modules. The module list in `install.sh` and the
Web UI has to be rebuilt to match — how, is not decided here.
