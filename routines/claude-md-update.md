# CLAUDE.md Update

Weekday routine that scans the current state of the codebase and regenerates `CLAUDE.md` to keep it accurate and up to date.

---

## Instructions

```
Study the current state of the code and update CLAUDE.md to reflect what is currently in the code.

Rules:
- Keep everything between <!-- darkflow:start --> and <!-- darkflow:end --> exactly as-is — do not touch it
- Only update the project-specific sections outside those markers (commands, architecture, env vars, patterns)
- Commit and push the changes only if something actually changed

If CLAUDE.md has no <!-- darkflow:start --> marker, skip the run without committing — leave no comment.
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekdays (Mon–Fri) at ~9:00 |
| Folder | Project root (`/path/to/your-project`) |
| Model | **Opus** (recommended) — full codebase scan needs strong reasoning |
| Worktree | **No** — commits directly to main branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **Git** with push access — commits `CLAUDE.md` updates to main

---

## What it updates

The routine scans the entire codebase and rewrites `CLAUDE.md` to reflect:
- Current commands (`pnpm dev`, `pnpm build`, `pnpm test`, etc.)
- Architecture overview (new modules, changed patterns)
- Key files and their roles
- Environment variables in use
- Any patterns or conventions it observes in the code

The Dark Flow workflow section (docs layers, routines list) is preserved — the routine regenerates the project-specific parts around it.

---

## After completing

If `CLAUDE.md` was actually updated and committed, append a routine-log entry to `docs/overview.html`:

1. Read `docs/overview.html`
2. In the JSON inside `<script id="overview-data">`, append to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "claude-md-update", "summary": "<one-line summary, e.g. 'Updated commands section and added 2 new env vars'>" }
   ```
3. Cap the array at the 50 most recent entries (drop older ones if it exceeds 50)
4. Write `docs/overview.html` — change nothing else in the JSON

Skip this step if the routine made no changes to `CLAUDE.md`.

---

## Notes

- Use **Opus** here — this routine reads the full codebase; Sonnet may miss important context in large repos
- Weekdays only — no point running on weekends when there are no commits
- If `CLAUDE.md` grows too large, add to the instructions: "Keep CLAUDE.md under 200 lines — summarise, don't enumerate"
- The routine skips the run if there are no new commits since the last `CLAUDE.md` update
