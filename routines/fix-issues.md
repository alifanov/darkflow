# Fix Issues

The core execution routine. Runs every hour, picks up one `status:approved` GitHub issue, implements the fix, and closes it. The merge strategy (PR vs direct commit) and target branch are configured during Dark Flow installation.

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
| Schedule | Hourly at :00 |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **Yes** (PR strategy) / **No** (direct strategy) |
| Always allowed | **Act without asking** |

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
- Lint, tests, and build are run automatically before every merge — the command detects the tech stack and skips checks that don't exist. If any check fails, the issue is labelled `status:blocked` and a comment is left explaining what failed.
- The routine only picks up `status:approved` — it respects `status:blocked` and `status:in-progress`
- **PR strategy** is safer: leaves a merge trail, allows CI checks to run before merge
- **Direct strategy** is faster but bypasses review; use only when you trust the agent fully
