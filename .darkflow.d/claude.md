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

### Before each session

Check approved task queue:
```bash
~/.darkflow/df task list --status approved --state open
```
If there are approved tasks matching the current context — pick them first.
Before starting: set status to `in-progress`, leave a comment with the branch name.

### When to read docs

- **Any UI/UX task** → `docs/design/patterns.md` + `docs/design/components.md`
- **Changing a user flow** → `docs/spec/flows/`
- **Product / marketing decisions** → `docs/product/positioning.md` + `docs/product/product.md` + `docs/product/pricing.md`
- **Before architectural changes** → `docs/spec/architecture.md` (current map) + `docs/decisions/` (check for existing ADRs)

### When to write docs

- **Changed a user flow** → update `docs/spec/flows/*.md`
- **Added / removed a screen** → update `docs/spec/screens/inventory.md`
- **Changed data model** → update `docs/spec/data-model.md`
- **Changed system shape** (new service, integration, stack swap) → update `docs/spec/architecture.md`
- **Changed pricing / billing** → update `docs/product/pricing.md`
- **Added UI component or pattern** → update `docs/design/components.md` / `docs/design/patterns.md`
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
- `/darkflow:csp-setup` — wire CSP violation reporting → PostHog or internal endpoint (one-time setup)
- `/darkflow:uptime-check` — DNS + HTTP + page-load check; site down → auto-approved critical task

Interactive commands (planning/design, human-in-the-loop — no tasks or snapshots):
- `/darkflow:grill` — pressure-test a plan against the domain model; updates glossary + ADRs inline
