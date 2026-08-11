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

- **Any UI/UX task** → `docs/design/components.md` (registry + UI-state patterns)
- **Changing a user flow** → `docs/spec/flows/`
- **Product / marketing decisions** → `docs/product/positioning.md` + `docs/product/product.md` + `docs/product/pricing.md`
- **Before architectural changes** → `docs/spec/architecture.md` (current map) + `docs/decisions/` (check for existing ADRs)

### When to write docs

- **Changed a user flow** → update `docs/spec/flows/*.md`
- **Added / removed a screen** → update `docs/spec/screens.md`
- **Changed data model** → update `docs/spec/data-model.md`
- **Changed system shape** (new service, integration, stack swap) → update `docs/spec/architecture.md`
- **Changed pricing / billing** → update `docs/product/pricing.md`
- **Added UI component or state pattern** → update `docs/design/components.md`
- **Made an architectural decision** → add ADR to `docs/decisions/` (context → decision → how to verify)

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

Routine commands (run any routine interactively or use as the routine prompt):
- `/darkflow:fix-issues` — pick up one approved task and close it
- `/darkflow:security-audit` — full security review (static + runtime) → tasks
- `/darkflow:build-optimization` — build + deploy optimization analysis → tasks
- `/darkflow:uptime-check` — DNS + HTTP + page-load check; site down → auto-approved critical task
