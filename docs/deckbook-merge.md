# Deckbook merge — decision log

Working document for folding [Deckbook](https://github.com/alifanov/deckbook) into Dark Flow.
Dark Flow is the base; Deckbook contributes ideas, not code.

**Status:** every decision is settled. Nothing is implemented yet — this file records what we agreed to
do; implementation happens later, in its own tasks.

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
| A2 | **Comments become their own table** (`human` / `system`) instead of the `Issue.comments` JSON column. | Deckbook `Comment` |
| A3 | **Daily log** — one document per day, sections per source (`## Security`, `## Analytics`, `## Changes`, …), append-only. As files: `docs/logs/YYYY-MM-DD.md`. Replaces the per-routine snapshot files under `docs/insights/<area>/`. | Deckbook `logs/` |
| A4 | **`state/` layout for docs** — "how things are right now", overwritten in place: `arch` · `hypotheses` · `spec/` · `product/` · `design/` · `_archive/`, plus a `README` that carries the rules. | Deckbook `state/` |
| A5 | **Behaviour rules move into the commands**: the observation → task threshold, the incident-vs-proposal rule, and the terseness rule. | Deckbook command preamble |
| A6 | **Scheduling stays on Dark Flow's own worker** (launchd, cron in the DB). Cloud scheduled-tasks are not adopted. | owner |

## Not doing

| # | Not doing | Why |
|---|---|---|
| R1 | MCP server on top of Dark Flow tasks | `df` CLI + HTTP API already cover it |
| R2 | Subtask tree (`parent`/`children` on tasks) | flat tasks have been enough so far |
| R3 | Due-day + recurrence (task hidden from the agent until its date) | `--after` snooze covers the same need |
| R4 | Agent tokens + assignee | one worker, one machine, no ambiguity about who took the task |
| R5 | Owner authentication in the webapp | runs on localhost only |
| R6 | Port Deckbook's vitest suite | worth doing, but not part of the merge |

## Commands

Findings from comparing 27 Dark Flow commands + `install.sh` against 21 Deckbook commands.

### Merge overlapping commands

| # | Decision | |
|---|---|---|
| C1 | `security-audit` + `vulnerability-check` → one command | do |
| C2 | `architecture-review` + `code-health` → one command. The fallow step stays optional — it only covers TS/JS, the rest of the review does not | do |
| C3 | `observability-check` + `web-vitals` → one command | **no** — different sources and different cadence (logs daily, Lighthouse weekly). They do share one `## Performance` section in the daily log |
| C4 | three design commands (`design-audit` / `design-critique` / `design-harden`) → `check-design` (visual) + `check-ux` (flows) | do — also delivers P8 |
| C5 | **delete `routines/` entirely** | do |

On C5: the schedule is currently written by hand in five places — `routines/<name>.md`,
`routines/README.md`, `README.md`, the summary `install.sh` echoes at the end, and the catalog. Only the
catalog (`webapp/src/lib/routines.ts`) and the DB (`RoutineConfig`) are real; the cards go stale the
moment a schedule changes in the Web UI, which is exactly why they drifted from the commands. After C5
the repository keeps one file per routine — the prompt — and the tables in `README.md` and `install.sh`
are generated from the catalog. `routines/ci-watch.md` is the one card worth keeping: that routine is
pure bash inside the worker and has no command file, so its text moves to `docs/`.

### Drop

| # | Decision | |
|---|---|---|
| D1 | Drop `grill` — generic skill, duplicates `mattpocock-skills:grilling`, unrelated to Dark Flow | do |
| D2 | Drop `claude-md-update`, together with the `MOD_CLAUDE_UPDATE` installer module | do |
| D3 | Drop `csp-setup` — one-time setup, done by hand once per project | do |
| D4 | Drop `product-overview` — `state/` plus the daily log carry that role once A3/A4 land | do |

### Adopt from Deckbook

| # | Decision | |
|---|---|---|
| P1 | Frontmatter on every command: `description` (one line) + `allowed-tools`. Audits get read-only tool sets; only the fix routines get `Edit`/`Write` | do |
| P2 | Terseness rule — bullets, numbers and tables over prose; 1–3 sentence task comments; no "looks fine overall". Written **once** in `.darkflow.d/claude.md`, not copied into every command | do |
| P3 | Incident-vs-proposal rule: broken right now → fixed without a gate; improvement beyond the finding → `needs-human`, silence is not consent. **In addition to** `docs/auto-approve.md`, not replacing it — the source decides whether auto-approval is allowed at all, the nature of the finding decides the individual task | do |
| P4 | Observation → task threshold: 3 consecutive logs or 2 independent sources. Applies to observations only (logs, analytics, performance); incidents file a task on first sight. Depends on A3 — without a log history there is nothing to compare against | do |
| P5 | No separate product passport document. Extend `Project` + `config.json` instead with what is missing today: staging URL and the key pages to walk (`check-ux`, `web-vitals` currently guess). The production domain is already there | do |
| P6 | Delta against the previous run, with the date taken from `RoutineLog` in the DB rather than parsed out of Markdown. Applies to code review; dependency vulnerabilities and live headers are still checked in full every time | do |
| P7 | Deduplicate against a compact inventory of **all** project tasks (id + title + status, open plus closed in the last 3 months) instead of `--source X` only — otherwise the same problem lands twice from two different audits | do |
| P8 | `check-ux` — walk the key flows in a real browser at mobile and desktop viewports | do (via C4) |
| P9 | Drop the copy-pasted "Step 1 — Read project config" block (~15 lines × ~20 commands). The config contract is described once in `.darkflow.d/claude.md`; commands keep a one-line instruction | do |

### Installer

| # | Decision | |
|---|---|---|
| I1 | `install.sh` reconciles `docs/` against the reference layout: create what is missing, offer to move an old layout into `_archive/`, never delete silently. Required by A4 — every already-installed project carries the current layout and has to be migrated | do |

Everything else about `install.sh` stays — project registration in the webapp, launchd plists, legacy
cleanup, `--dry-run` / `--force`, the `@`-include into `CLAUDE.md`, the checklist, and the optional
modules are all ahead of what `/deckbook:init` does.

### Housekeeping routines

| # | Decision | |
|---|---|---|
| H1 | `unstick-tasks` — a task left `in-progress` for 4h with no activity gets a comment saying why it came back and returns to `approved`. Dark Flow has no such mechanism today: a task abandoned by a killed session stays `in-progress` forever and no later run picks it up | do, as an agent routine |
| H2 | `clean-worktrees` — drop spent worktree checkouts and merged branches; leave anything doubtful and say why. Dark Flow's own rule forbids worktrees, but cmux and cloud sessions create them anyway (~40 MB each) | do, as an agent routine |
| H3 | `rotate-logs` — daily logs older than 4 weeks move to `docs/_archive/logs/`. Logs referenced from `state/hypotheses` or the decision table stay put. Required by A3, otherwise `docs/logs/` grows by a file a day | do |

## What this adds up to

- **Commands:** 27 → ~20. Four dropped (`grill`, `claude-md-update`, `csp-setup`, `product-overview`),
  four merged into two (C1, C2), three design commands into two (C4), three housekeeping routines added.
- **Files:** `routines/` (24 files) deleted; the "read the config" block and the terseness rule stop
  being duplicated across commands.
- **Docs:** `docs/insights/<area>/` snapshots give way to one daily log plus `state/`; the installer
  migrates existing projects.
- **DB:** comments become a table (A2); `Project` gains staging URL and key pages (P5); `RoutineLog`
  starts being read, not just written (P6).
