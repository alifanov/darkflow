# CLAUDE.md Update

Weekday routine that scans the current state of the codebase and regenerates `CLAUDE.md` to keep it accurate and up to date.

---

## Instructions

```
/darkflow:claude-md-update
```

The command reads `.darkflow` for the target branch — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 9 * * 1-5` (weekdays 9:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh claude-md-update` |

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

## Notes

- Use **Opus** here — this routine reads the full codebase; Sonnet may miss important context in large repos
- Weekdays only — no point running on weekends when there are no commits
- If `CLAUDE.md` grows too large, add to the instructions: "Keep CLAUDE.md under 200 lines — summarise, don't enumerate"
- The routine skips the run if there are no new commits since the last `CLAUDE.md` update
