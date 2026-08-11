# Deckbook merge — decision log

Working document for folding [Deckbook](https://github.com/alifanov/deckbook) into Dark Flow.
Dark Flow is the base. Deckbook contributes its ideas, and its live content — documents and open tasks —
moves across; its code does not.

**Status — 2026-08-11: COMPLETE.** All eleven steps are done (v4.23.0 → v4.30.1). Deckbook is
disconnected: no scheduled task calls it, no MCP server points at it, no `/deckbook:*` command exists.
This file is kept as the record of what was decided and where the decisions turned out to be wrong.

| # | Step | |
|---|---|---|
| 1 | Modules — M1 | ✅ v4.23.0 |
| 2 | Prune — C5 · D1–D4 · A9 | ✅ v4.23.0 |
| 3 | Extract — P2 · P9 · P1 | ✅ v4.24.0 |
| 4 | Merge — C1 · C2 · C4 · P5 · P7 | ✅ v4.25.0 |
| 5 | Lock — A10 | ✅ v4.25.1 — premise was wrong, the lock already existed |
| 6 | Log — A3 · A7 · P3 · P4 | ✅ v4.26.0 |
| 7 | State — A4 | ✅ v4.27.0 |
| 8 | Reconcile — I1 · A8 · A11 | ✅ v4.28.0 |
| 9 | Worker — H | ✅ v4.29.0 |
| 10 | Move the eight projects over | ✅ v4.30.0 — content · v4.30.1 — disconnect |
| 11 | Retire the `/deckbook:*` commands | ✅ v4.30.1 |

**What step 10 actually took.** Two assumptions in the "Moving off Deckbook" section below were
wrong, and both made the job easier than written:

1. **No MCP client is needed.** The hosted Deckbook (`deckbook.chatindex.app`) answers JSON-RPC over
   plain HTTP; the per-project bearer token is already in `~/.claude.json`. The local `deckbook-db-1`
   container is a *decoy* — a dev database with two test projects. Read the hosted one.
2. **Seven of the eight projects were already installed and registered.** Step 10.1 was therefore not
   an install but a *layout migration* — exactly what `install.sh` does now (I1).

**Done:** all eight projects, ~420 documents and all **34** open tasks (verified per project: the
count in Deckbook equals the count in Dark Flow). The `deckbook` repo itself got documents only — it
stays read-only history, so no Dark Flow install and no routines.

**The disconnect (10.4 + 11).** 138 scheduled tasks, 8 MCP servers and 21 slash commands deleted.
Selection was by **content**, never by slug prefix — exactly as this file warned: four secscanner
tasks (`improve-codebase-architecture`, `posthog-analytics`, `security-review`, `update-claude-md`)
carry the prefix but never called Deckbook, and all four survived. A backup of everything deleted is
in `~/.darkflow/deckbook-retire-backup-2026-08-11/` (tarball, MCP config, commands, `.claude.json`).

Three entries below were **disproved while implementing** — A10's premise, half of A11's, and H's
claim that no stuck-task recovery existed. All are marked inline; the corrections are the useful part
of this file now.

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
| A7 | **Routines commit what they write** — but never push to a protected base branch. Today's audits write snapshots and never commit, so they pile up uncommitted and leak into whatever branch `fix-issues` opens next. New rule, split by the project's merge strategy: **direct** — the routine stages exactly its own paths, commits and pushes; **pr** (the default) — the routine commits nothing and pushes nothing; it leaves the file, and the next PR takes it along. `fix-issues` is extended for this: alongside its own files it also stages `docs/logs/` and `docs/state/` if they changed. "Never `git add -A`" still holds — the list is explicit, just longer. Two hard preconditions in both modes: HEAD is on the base branch, and the routine only ever touches its own paths | gap found while reviewing |
| A8 | **One archive: `docs/_archive/`.** Superseded layouts, retired documents and the existing `docs/insights/` snapshots move there. Nothing is archived under `state/` | gap found while reviewing |
| A9 | **Dropping a command drops its routine with it** — the catalog entry in `webapp/src/lib/routines.ts` *and* the `RoutineConfig` rows in every project. A schedule that outlives its command has the worker firing `claude -p "/darkflow:<gone>"` on cron forever. Same for the merges: C1/C2/C4 retire the old names, so those rows go too, and the surviving routine keeps one name | gap found while reviewing |
| A10 | **One session per project.** ~~The machine-wide semaphore caps total sessions (3 by default) but lets two routines of the *same* project run at once~~ — **wrong: the lock already existed.** `.darkflow.d/state/.lock` is taken before the global slot by every entry point (watch-loop dispatch subshell, `--dry-run`, manual run), claimed atomically with `mkdir`, reclaimed on a dead owner PID; routines run sequentially inside it, so a busy project already skipped the tick. The only real gap was a manual run exiting **silently** on contention — fixed. Requirement satisfied, no new lock added | gap found while reviewing — premise disproved on implementation |
| A11 | **Metrics survive the merges, one per surviving routine.** ⚠️ **Premise half wrong, found while implementing:** fifteen commands write these files, but `darkflow-run.sh` forwards exactly **three** — `analytics.json`, `security.json`, `architecture.json`. The other twelve are write-only; nothing reads them. So `design.json` / `ux.json` were deliberately **not** created (`check-design` and `check-ux` write no metrics at all), and stripping the dead writes from the ten other commands is still open. Everything below holds for the three files that are real. — Fifteen commands write `.darkflow.d/state/metrics/*.json`, which the worker forwards to the webapp — that is what feeds `SecurityStatus`, `ArchitectureStatus`, the alerts and the project-row widgets. It is a separate channel from `docs/insights/`, untouched by A3/A4: **`.darkflow.d/state/` is not `docs/state/`**, and the two must not be confused while reading this plan. The merges collapse the files along with the commands — `security.json` absorbs `vulnerabilities.json`, `architecture.json` absorbs `code-health.json`, and the three design files become `design.json` + `ux.json`. A file nobody writes any more leaves a widget frozen on its last value, so I1 deletes orphaned `metrics/*.json` while it reconciles a project | gap found while reviewing |

## Not doing

| # | Not doing | Why |
|---|---|---|
| R1 | MCP server on top of Dark Flow tasks | `df` CLI + HTTP API already cover it. Lost with Deckbook — accepted |
| R2 | Subtask tree (`parent`/`children` on tasks) | flat tasks have been enough so far |
| R3 | Due-day + recurrence (task hidden from the agent until its date) | `--after` snooze covers the same need |
| R4 | Agent tokens + assignee | one worker, one machine, no ambiguity about who took the task |
| R5 | Owner authentication in the webapp | runs on localhost only |
| R6 | Port Deckbook's vitest suite | 28 test files that die with it — Dark Flow has none. Worth doing on its own terms, not as part of the merge |
| R7 | Move comments out of the `Issue.comments` JSON column into their own table | no use case behind it. One worker means one author; stuck-task recovery reads `updatedAt`, not the feed. A migration for tidiness only |
| R8 | Delta against the previous run | `RoutineLog` records no success/failure, so "since last run" would happily start from a crashed run and skip a window. Adding a status column to make one optimisation work is not worth it |
| R9 | Rotate the daily log | a file a day is small, and rotation was the only thing that made the observation threshold (P4) unreliable: the history it counts against would have been moved away. Logs stay in `docs/logs/` |

## Moving off Deckbook

Eight projects run on it today — eight MCP servers and **138 scheduled tasks** calling `/deckbook:*`:

| Project | Tasks calling `/deckbook:*` |
|---|---|
| mailmonitor | 20 |
| secscanner | 19 |
| pageradar | 19 |
| qabot | 18 |
| mystize | 17 |
| sqlformatter | 17 |
| deckbook | 14 |
| scopegate | 14 |

Those eight prefixes cover 142 scheduled tasks in total, so **selecting by `<slug>-*` is wrong** — it
would also delete four of secscanner's own tasks that have nothing to do with Deckbook
(`improve-codebase-architecture`, `posthog-analytics`, `security-review`, `update-claude-md`). Select by
what the prompt actually calls: `rg -l '/deckbook:' ~/.claude/scheduled-tasks/*/SKILL.md`.

(A ninth server, `deckbook-private`, had no scheduled tasks and has already been removed.)

Per project, in this order — install first so the content lands in a layout the installer has already
approved, and disconnect last, while the MCP server is still there to read from:

1. **Install Dark Flow** (`install.sh`), register the project in the Web UI, pick its modules, set the
   schedule for the equivalent routines. This is what creates the `docs/` layout; doing it *after* the
   content move would have I1 offer to archive the documents that were just imported.
2. **Documents → files.** Read the whole tree (`read_document_tree` / `read_document`) and write it into
   the layout that now exists: `state/*` documents to `docs/state/`, daily logs to `docs/logs/`,
   anything superseded to `docs/_archive/`. Commit.
3. **Open tasks → Dark Flow.** Every task in `todo` / `in_progress` / `needs_human` becomes a Dark Flow
   task with its title, body and priority. Assumed status mapping, unless a project says otherwise:
   `todo` and `in_progress` → `approved`, `needs_human` → `proposed`. Existing comments are folded into
   the body — Dark Flow has no comment history to import into (R7). Closed and cancelled tasks are not
   moved; they stay in the Deckbook database as history.
4. **Disconnect** — delete that project's scheduled tasks *that call `/deckbook:*`* (see the selection
   note above) and its `deckbook-<slug>` MCP server.

Once no project is left: delete the `/deckbook:*` slash commands (`~/.claude/commands/deckbook/`,
21 files). Per A9 commands and the schedules that call them go together — a leftover cron entry whose
prompt is a single `/deckbook:<name>` line fires at a command that no longer exists.

The Deckbook database and repository are kept as they are, read-only history after the move.

**Known risk, accepted:** all of this load lands on one local worker capped at 3 concurrent sessions
(A10 makes it one per project on top of that). Eight more projects on Dark Flow's default schedule is a
large step up in runs per day. If it turns out to be too much, the fix is a lower `maxConcurrent`, a
thinner set of enabled routines, or rarer crons — tuned after the move, not guessed before it.

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
| P1 | Frontmatter on every command: `description` (one line) + `allowed-tools`. The dividing line is **push, not write**: every audit writes and commits (A3, A7), so `Write` and `git commit` are on everyone's list — restricting them would be theatre, and `allowed-tools` cannot scope `Write` to a directory anyway. `git push` belongs only to the fix routines. That also matches A7: under the `pr` strategy an audit has nothing to push | do |
| P2 | Terseness rule — bullets, numbers and tables over prose; 1–3 sentence task comments; no "looks fine overall". Written **once** in `.darkflow.d/claude.md`, not copied into every command | do |
| P3 | Incident-vs-proposal rule: broken right now → filed straight to `approved`; improvement beyond the finding → `proposed`, where the triage queue in the Web UI already waits for the owner. **Not `needsHuman`** — in Dark Flow that flag means "the agent is stuck: no access, no config, checks failed", and it is mutually exclusive with `approved`. Deckbook's `needs_human` carries both meanings; ours does not | do |
| P4 | Observation → task threshold: the same observation in **3 consecutive runs**, or 2 independent sources. Applies to observations only (logs, analytics, performance); incidents file a task on first sight. A clean run writes no section at all — silence means "nothing found", so the count is over *runs*, not over log files: `RoutineLog` says how many times the routine ran, the logs say which of those runs carried the observation. A run that left no section breaks the streak | do |
| P5 | No product passport document and no "key pages" column that nobody would fill in. `Project` + `config.json` gain **one** field — the staging URL. Commands that need pages to walk read `sitemap.xml` | do |
| P7 | Deduplicate against all project tasks, not just `--source X` — otherwise the same problem lands twice from two different audits. This is a `--format compact` flag on the existing `df task list --state all`, not a new command | do |
| P8 | `check-ux` — walk the key flows in a real browser at mobile and desktop viewports | do (via C4) |
| P9 | Drop the copy-pasted "Step 1 — Read project config" block (~15 lines × ~20 commands). The config contract is described once in `.darkflow.d/claude.md`; commands keep a one-line instruction | do |

### Installer

| # | Decision | |
|---|---|---|
| M1 | Rebuild the module list first. C2 merges two routines that sit behind **different** modules (`arch-review`, `fallow`); D2/D4 remove `claude-update` and `product-overview`. Nothing else can be pruned safely until the module list, `install.sh` and the Web UI agree on what modules exist | do, first |
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
stuck HEAD    working copy left on a feature branch, nothing running → back to the base branch
worktrees     git worktree prune; delete merged branches

"uncommitted changes" ignores docs/logs/ and docs/state/ — under the pr strategy those are
expected to sit there waiting for the next PR (A7). Anything else uncommitted → leave it alone
and say so.
```

Without that exemption the whole pass would be dead on arrival: a project with no open tasks opens no
PR for weeks, so the log stays uncommitted, so the checkout always looks dirty, so nothing is ever
cleaned up or recovered — precisely when recovery is needed.

Dark Flow has no stuck-task recovery at all today: a task abandoned by a killed session stays
`in-progress` forever and no later run picks it up. The checkout has the same problem — `fix-issues`
is supposed to switch back to the base branch when it finishes, so a killed session leaves HEAD on a
feature branch, and every A7 write after that lands on the wrong branch. Recovering the task without
recovering the checkout fixes half the damage.

## Order of work

Sequence matters in four places: the module list has to agree with itself **before** anything is pruned;
shared text has to be extracted **before** commands are merged (otherwise the same boilerplate is merged
twice); the per-project lock has to land **before** routines start committing; and no project moves off
Deckbook until Dark Flow itself is in its final shape.

```
1. Modules    M1 — settle what modules exist after C1/C2/D2/D4
2. Prune      C5 (delete routines/ + schedule tables) · D1–D4
              A9 applies throughout: every dropped or renamed routine leaves the catalog and the DB
3. Extract    P2 · P9 · P1 — shared rules into .darkflow.d/claude.md, frontmatter on every command
4. Merge      C1 · C2 · C4 (+ P5, P7 while touching the commands)
5. Lock       A10 — one session per project, before anything starts committing on a schedule
6. Log        A3 · A7 · P3 · P4 — the daily log exists, routines write and commit sections
7. State      A4 — the new docs layout and its templates
8. Reconcile  I1 · A8 — installer fixes up docs/, old snapshots into docs/_archive/
9. Worker     H — the daily housekeeping pass, including HEAD recovery
10. Move over the eight projects, one at a time: install, documents → files, open tasks → Dark Flow,
              then delete that project's scheduled tasks and MCP server
11. Retire    once none are left — delete the /deckbook:* commands
```

Step 10 is the long one: 138 scheduled tasks across eight projects, each needing its content moved, its
modules chosen and its schedule checked. One project at a time, verified before the next.

This plan stays a file rather than becoming tasks in Dark Flow itself: it is finite and gets deleted when
the work is done, and eleven planning tasks in the queue would only compete with real ones.

## What this adds up to

- **Commands:** 27 → ~20. Four dropped (`grill`, `claude-md-update`, `csp-setup`, `product-overview`),
  four merged into two (C1, C2), three design commands into two (C4). Housekeeping adds no commands —
  it runs in the worker.
- **Files:** `routines/` (24 files) deleted, along with the schedule tables in `README.md` and
  `install.sh`; the "read the config" block and the terseness rule stop being duplicated across commands.
- **Docs:** `docs/insights/<area>/` snapshots give way to one daily log plus `state/`; one archive at
  `docs/_archive/`; the installer reconciles existing projects; Deckbook's documents land as files.
- **DB:** one new field — the staging URL on `Project`. No new tables, no schema churn.
- **Metrics:** `.darkflow.d/state/metrics/` keeps working; the merged routines collapse their files
  (15 → 12) and the installer deletes the orphans.
- **Worker:** a per-project lock on top of the existing semaphore.
- **What is lost with Deckbook:** its MCP interface to tasks (R1) and its 28 vitest files (R6).
