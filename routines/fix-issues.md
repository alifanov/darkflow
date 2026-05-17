# Fix Issues

The core execution routine. Runs every hour, picks up one `status:approved` GitHub issue, implements the fix via a pull request, and merges to main.

---

## Instructions

```
Look at the open GitHub issues for this project in the GitHub repository. Fix them one by one, leave a comment in the GitHub issue. Close the GitHub issue after completion. Do each GitHub issue via a pull request and merge into the main branch.

1. Take only one GitHub issue, sorted by priority.
2. Make all the changes needed for it.
3. Commit and merge into the master branch and push these changes.

Language in GitHub issues: Russian
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Hourly at :00 |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Worktree | **Yes** — each issue runs in an isolated branch |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for reading issues, creating PRs, merging
- **Git** configured with push access to the repository
- Tests must pass before merge (add to instructions if needed: "Run tests before merging")

---

## How it fits the loop

```
Human sets status:approved on an issue
  ↓
This routine picks it up (next :00)
  ↓
Creates a branch, implements the fix
  ↓
Opens a PR with "Closes #N"
  ↓
Merges to main, issue auto-closes
```

The routine skips issues it cannot handle (ambiguous spec, missing context) and leaves a comment explaining why.

---

## Notes

- **One issue per run** — deliberate. Keeps each execution atomic and reviewable
- If there are no `status:approved` issues, the run is skipped (shown as "Skipped" in history)
- Add `pnpm test` or equivalent to the instructions to enforce tests before merge
- The routine only picks up issues with `status:approved` — it respects `status:blocked` and `status:in-progress`
