## Documentation & Agent Workflow

@docs/agent-workflow.md
@docs/github-issues.md
@docs/auto-approve.md

**Language:** English — use this language for GitHub issues, comments, commit messages, and all agent-facing text.
**Main branch:** `main`
**Fix Issues strategy:** open a pull request, then merge into `main` with `Closes #N`.

### Before each session

Check approved task queue:
```bash
gh issue list --label "status:approved" --state open --json number,title,labels,body --limit 20
```
If there are approved issues matching the current context — pick them first.
Before starting: set `status:in-progress`, leave a comment with the branch name.

### When to read docs

- **Any UI/UX task** → `docs/design/voice-and-tone.md` + `docs/design/tokens.md` + `docs/design/patterns.md` + `docs/design/components.md`
- **Changing a user flow** → `docs/spec/flows/`
- **Product / marketing decisions** → `docs/product/positioning.md` + `docs/product/audience.md` + `docs/product/pricing.md`
- **Before architectural changes** → `docs/decisions/` (check for existing ADRs)

### When to write docs

- **Changed a user flow** → update `docs/spec/flows/*.md`
- **Added / removed a screen** → update `docs/spec/screens/inventory.md`
- **Changed data model** → update `docs/spec/data-model.md`
- **Changed pricing / billing** → update `docs/product/pricing.md`
- **Added UI component or pattern** → update `docs/design/components.md` / `docs/design/patterns.md`
- **Made an architectural decision** → add ADR to `docs/decisions/` (context → decision → how to verify)

### Active Routines

Scheduled Claude Code agents that run this workflow automatically:

- **Fix issues** (Hourly) — picks up `status:approved` issues → PR → merge to main

Schedule: `.darkflow.d/routines.yml`  |  Dispatcher: `bash .darkflow.d/darkflow-run.sh`
Run any routine manually: `bash .darkflow.d/darkflow-run.sh <name>`

### Dark Flow commands

Use `/darkflow` inside Claude Code to check workflow health and review the approved queue.

Workflow commands: `/darkflow:add-issue`, `/darkflow:install`.

Routine commands (run any routine interactively or use as the routine prompt):
- `/darkflow:fix-issues` — pick up one approved issue and close it
- `/darkflow:security-audit` — full security review (static + runtime) → GitHub issues
