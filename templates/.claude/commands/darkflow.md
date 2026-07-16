Check the Dark Flow workflow status for this project and help the user manage it.

## What to do

1. **Check docs/ structure** — verify all expected folders exist (`docs/product/`, `docs/spec/`, `docs/design/`, `docs/insights/`, `docs/decisions/`). List any that are missing.

2. **Show approved task queue** — run:
   ```bash
   ~/.darkflow/df task list --status approved --state open
   ```
   Summarize them by priority. Flag snoozed tasks separately (`scheduledFor` in the future) — fix-issues skips those until the date passes. Do not offer to start working — the fix-issues routine handles that.

3. **Check for proposed tasks** — run:
   ```bash
   ~/.darkflow/df task list --status proposed --state open
   ```
   Summarize what's waiting for human review.

4. **Report** — give a short health summary:
   - ✓/✗ docs/ structure present
   - N approved tasks ready to work on
   - N proposed tasks waiting for review

## Available subcommands

- `/darkflow:add-issue [title]` — create a task for a manually identified item
- `/darkflow:install` — re-run the Dark Flow installer
- `/darkflow:update-config [lang=...] [branch=...]` — update language and/or main branch settings
