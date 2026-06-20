# Fix Issues

The core execution routine. Runs hourly, picks up one `status:approved` GitHub issue, implements the fix, and closes it. The merge strategy (PR vs direct commit) and target branch are configured during Dark Flow installation.

---

## Instructions

```
/darkflow:fix-issues
```

The command reads `.darkflow` for branch, language, and merge strategy — no placeholders to replace. The PR vs direct-commit variant is selected automatically from `merge_strategy=` in `.darkflow`.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 * * * *` (hourly) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh fix-issues` |

---

## Required integrations

- **`gh` CLI** authenticated — for reading issues, creating PRs, merging
- **Git** configured with push access to the repository

---

## How it fits the loop

```
Human sets status:approved on an issue
  ↓
This routine picks it up (next :00)
  ↓
[PR strategy]     creates branch → implements → opens PR → merges → issue closes
[Direct strategy] implements → commits → pushes to main → closes issue
```

The routine skips issues it cannot handle and leaves a comment explaining why.

---

## Notes

- **One issue per run** — keeps each execution atomic and reviewable
- If there are no `status:approved` issues the run is skipped ("Skipped" in history)
- Lint, tests, and build are run automatically before every merge — the command detects the tech stack and skips checks that don't exist. If any check fails, the issue is labelled `needs-human` and a comment is left explaining what failed — a human needs to look since the agent can't get past it.
- If the fix changes user-visible behavior, configuration, or API, the routine updates relevant docs (README, `docs/`, changelog) before merging.
- After closing the issue, a comment is posted with a brief summary of what was changed and which files were updated (including any docs).
- If a fix requires human action (missing credentials, env variables, external services, infrastructure changes), the issue is labelled `needs-human` with a comment explaining what's needed. It appears in the **Needs Human** card in the Dark Flow webapp. Once you've taken action, click **Close** in the webapp to close the issue.
- The routine only picks up `status:approved` — it respects `status:in-progress` and `needs-human`
- **PR strategy** is safer: leaves a merge trail, allows CI checks to run before merge
- **Direct strategy** is faster but bypasses review; use only when you trust the agent fully
- **No git worktree** — the routine always works in the project root. For PR strategy the feature branch is created in place with `git checkout -b` off the configured base branch (`branch=` in `.darkflow`); it never runs `git worktree add` or checks work out into a separate directory.
