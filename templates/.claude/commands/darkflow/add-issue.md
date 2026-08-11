---
description: Help the user create a task for a manually identified item (bug, feature, or improvement).
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`.

If `$ARGUMENTS` contains text (e.g. `/darkflow:add-issue fix login button on mobile`), use that text as the **title** — do not ask for a title again.

Walk through **only the missing fields** conversationally — skip any field already clear from the title:

1. **What is it?** (if not already clear) — bug, feature, or improvement? (just for your own framing — there's no separate type field)

2. **Title** (if not provided in $ARGUMENTS) — short action-oriented ("Fix X", "Add Y")

3. **Priority:**
   - critical — breaks revenue or a key feature right now
   - high — this week
   - medium — this month
   - low — someday / nice-to-have (allowed for manual tasks; scheduled routines never auto-create `low`)

4. **Description** — "Briefly describe the problem and what done looks like." Use the answer to write a context paragraph and 1–3 acceptance criteria checkboxes.

5. **Timing** (only if the user mentioned a date/"not before" constraint) — add `--after <ISO date>` to the create command so fix-issues won't pick the task up before that moment. Don't ask about this proactively.

Then construct and run:

```bash
~/.darkflow/df task create \
  --title "<title>" \
  --priority <p> --source manual --status approved \
  --body "$(cat <<'EOF'
## Context

<description>

## Acceptance criteria

- [ ] <criterion 1>
- [ ] <criterion 2 if needed>
EOF
)"
```

**Important rules:**
- Language for all conversation and task text: the `language` value from `.darkflow.d/state/config.json` (default: English)
- Always use `--status approved` — the user already decided to do it
- After creating, show the task number the command prints. The fix-issues routine will pick it up automatically.
