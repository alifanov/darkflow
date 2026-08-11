## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/tasks.md
@docs/auto-approve.md

**Communication language:** English — use it ONLY for human-facing text you write *about* the work: tasks, comments, commit messages, PR descriptions, and console/chat output.
**Product language:** English — everything shipped *inside* the product is always written in English, regardless of the communication language: source code, identifiers, code comments, UI copy, user-facing strings, logs, and in-product docs. Setting the communication language to anything other than English never changes this.
**Main branch:** `main`
**Fix Issues strategy:** commit and push directly to `main` — no pull requests.
**Workspace rule:** never create a git worktree (`git worktree add`) — always work in the project root on `main`. If the PR strategy needs a feature branch, create it in place with `git checkout -b` based off `main`.

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

- **Any UI/UX task** → `docs/state/design/components.md` (registry + UI-state patterns)
- **Changing a user flow** → `docs/state/spec/flows/`
- **Product / marketing decisions** → `docs/state/product/positioning.md` + `docs/state/product/product.md` + `docs/state/product/pricing.md`
- **Before architectural changes** → `docs/state/arch.md` (current map) + `docs/decisions/` (check for existing ADRs)

### When to write docs

- **Changed a user flow** → update `docs/state/spec/flows/*.md`
- **Added / removed a screen** → update `docs/state/spec/screens.md`
- **Changed data model** → update `docs/state/spec/data-model.md`
- **Changed system shape** (new service, integration, stack swap) → update `docs/state/arch.md`
- **Changed pricing / billing** → update `docs/state/product/pricing.md`
- **Added UI component or state pattern** → update `docs/state/design/components.md`
- **Made an architectural decision** → add ADR to `docs/decisions/` (context → decision → how to verify)

### Active Routines

Scheduled Claude Code agents that run this workflow automatically:

- **Fix issues** (Hourly) — picks up an approved task → commit → push to main

Schedule: managed in the Web UI (Settings → Routine schedule)  |  Worker: one global `~/.darkflow/darkflow-run.sh` services every project
Run any routine manually (from this project dir): `~/.darkflow/darkflow-run.sh <name>`

### Dark Flow commands

Use `/darkflow` inside Claude Code to check workflow health and review the approved queue.

Workflow commands: `/darkflow:add-issue`, `/darkflow:install`.

Routine commands (run any routine interactively or use as the routine prompt):
- `/darkflow:fix-issues` — pick up one approved task and close it
- `/darkflow:security-audit` — full security review (static + runtime) → tasks
