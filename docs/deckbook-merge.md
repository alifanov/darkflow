# Deckbook merge — decision log

Working document for folding [Deckbook](https://github.com/alifanov/deckbook) into Dark Flow.
Dark Flow is the base; Deckbook contributes ideas, not code.

**Status:** deciding. Nothing is implemented yet — this file only records what we agreed to do.
Each decision moves `open → accepted / rejected`; implementation happens later, in its own tasks.

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

## Accepted

| # | Decision | Source |
|---|---|---|
| A1 | **Docs stay plain text in the repository.** Deckbook's document tree lives in the DB and is edited over MCP; we keep files under `docs/` and take only the *shape* from Deckbook. | owner |
| A2 | **Comments become their own table** (`human` / `system`) instead of the `Issue.comments` JSON column. | Deckbook `Comment` |
| A3 | **Daily log** — one document per day, sections per source (`## Security`, `## Analytics`, `## Changes`, …), append-only. As files: `docs/logs/YYYY-MM-DD.md`. Replaces the per-routine snapshot files under `docs/insights/<area>/`. | Deckbook `logs/` |
| A4 | **`state/` layout for docs** — "how things are right now", overwritten in place: `arch` · `hypotheses` · `spec/` · `product/` · `design/` · `_archive/`, plus a `README` that carries the rules. | Deckbook `state/` |
| A5 | **Behaviour rules move into the commands**: the observation → task threshold, the incident-vs-proposal rule, and the terseness rule. | Deckbook command preamble |
| A6 | **Scheduling stays on Dark Flow's own worker** (launchd, cron in the DB). Cloud scheduled-tasks are not adopted. | owner |

## Rejected (not now)

| # | Not doing | Why |
|---|---|---|
| R1 | MCP server on top of Dark Flow tasks | `df` CLI + HTTP API already cover it |
| R2 | Subtask tree (`parent`/`children` on tasks) | flat tasks have been enough so far |
| R3 | Due-day + recurrence (task hidden from the agent until its date) | `--after` snooze covers the same need |
| R4 | Agent tokens + assignee | one worker, one machine, no ambiguity about who took the task |
| R5 | Owner authentication in the webapp | runs on localhost only |
| R6 | Port Deckbook's vitest suite | worth doing, but not part of the merge |

## Open — commands and installer

Findings from comparing 27 Dark Flow commands + `install.sh` against 21 Deckbook commands.

### Merge overlapping commands

| # | Proposal | Status |
|---|---|---|
| C1 | `security-audit` + `vulnerability-check` → one command | open |
| C2 | `architecture-review` + `code-health` → one command | open |
| C3 | `observability-check` + `web-vitals` → one command | open |
| C4 | three design commands (`design-audit` / `design-critique` / `design-harden`) → `check-design` (visual) + `check-ux` (flows) | open |
| C5 | collapse `routines/*.md` into the command files' frontmatter — one artefact per routine instead of two that drift | open |

`routines/` and `templates/.claude/commands/darkflow/` have already diverged: 6 commands have no routine
card (`add-issue`, `csp-setup`, `grill`, `install`, `self-update`, `update-config`), and 2 cards have no
command (`ci-watch` — pure bash inside the worker — and `README`).

### Drop

| # | Proposal | Status |
|---|---|---|
| D1 | Drop `grill` — generic skill, duplicates `mattpocock-skills:grilling`, unrelated to Dark Flow | open |
| D2 | Drop `claude-md-update` — duplicates `claude-md-management:claude-md-improver` | open |
| D3 | Move `csp-setup` out of the commands into an installer module (it is one-time setup, not a routine) | open |
| D4 | Drop `product-overview` — `state/` plus the daily log carry that role once A3/A4 land | open |

### Adopt from Deckbook

| # | Proposal | Status |
|---|---|---|
| P1 | Frontmatter on every command (`description`, `allowed-tools`) — Dark Flow commands currently have none, so they are neither described in the listing nor tool-restricted | open |
| P2 | Terseness block in every command (bullets and tables, 1–3 sentence comments, no "looks fine overall") | open |
| P3 | Incident-vs-proposal rule inside the commands: broken now → fixed without a gate; improvement → `needs-human`, silence is not consent | open |
| P4 | Observation → task threshold: 3 consecutive logs or 2 independent sources | open |
| P5 | Product passport (name · domain · staging · repo) at the top of `docs/state/product/product.md`; commands read the URL from there instead of hardcoding it | open |
| P6 | Delta against the previous run — find the last log carrying this section, diff from that date — instead of re-deriving everything from scratch | open |
| P7 | Deduplicate against a full task inventory, not just `--source X` | open |
| P8 | `check-ux` — walk the key flows in a real browser at mobile and desktop viewports | open |
| P9 | Shared include for the "Step 1 — Read project config" block, copy-pasted verbatim into ~20 commands | open |

### Installer

| # | Proposal | Status |
|---|---|---|
| I1 | `install.sh` gains a step that reconciles `docs/` against the reference layout: create what is missing, offer to move an old layout into `_archive/`, never delete silently | open |

Everything else about `install.sh` stays — project registration in the webapp, launchd plists, legacy
cleanup, `--dry-run` / `--force`, the `@`-include into `CLAUDE.md`, the checklist, and the 12 optional
modules are all ahead of what `/deckbook:init` does.

### Housekeeping routines

| # | Proposal | Status |
|---|---|---|
| H1 | `unstick-tasks` — `in_progress` untouched for 4h goes back to the queue with a comment | open |
| H2 | `clean-worktrees` — drop spent worktree checkouts and merged branches | open |
| H3 | `rotate-logs` — daily logs older than 4 weeks move to `_archive/logs/`; required once A3 lands, otherwise `docs/logs/` grows without bound | open |
