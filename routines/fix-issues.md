# Fix Issues

The core execution routine. Runs every hour, picks up one `status:approved` GitHub issue, implements the fix, and closes it. The merge strategy (PR vs direct commit) and target branch are configured during Dark Flow installation.

---

## Instructions

Choose the variant that matches your project's merge strategy (the installer shows the exact instruction for your setup).

### Variant A — Pull Request (default, recommended)

```
Look at the open GitHub issues for this project. Take only one issue with status:approved,
sorted by priority (p0 first, then p1, p2, p3).

Implement all the changes needed for it.
Open a pull request targeting [MAIN_BRANCH] with "Closes #N" in the description.
Merge the pull request.
Leave a comment on the issue confirming completion.

Language in GitHub issues: [LANGUAGE]
```

### Variant B — Direct commit

```
Look at the open GitHub issues for this project. Take only one issue with status:approved,
sorted by priority (p0 first, then p1, p2, p3).

Implement all the changes needed for it.
Commit and push directly to [MAIN_BRANCH].
Leave a comment on the issue confirming completion.
Close the issue.

Language in GitHub issues: [LANGUAGE]
```

Replace `[MAIN_BRANCH]` with your actual branch name (`main`, `master`, `develop`, etc.).  
Replace the language if needed.

The Dark Flow installer generates the exact instruction for your setup at the end of installation.

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

## After completing

Append a routine-log entry to `docs/overview.html` (only if the run actually did work — skip on "no approved issues"):

1. Read `docs/overview.html`
2. In the JSON inside `<script id="overview-data">`, append to the `logs` array:
   ```json
   { "timestamp": "<current UTC ISO 8601>", "routine": "fix-issues", "summary": "<one-line summary, e.g. 'Closed #42: fixed N+1 in /api/orders, PR #44 merged'>" }
   ```
3. Cap the array at the 50 most recent entries (drop older ones if it exceeds 50)
4. Write `docs/overview.html` — change nothing else in the JSON

---

## Notes

- **One issue per run** — keeps each execution atomic and reviewable
- If there are no `status:approved` issues the run is skipped ("Skipped" in history)
- Add test commands to the instruction if your project requires them before merge:
  `"Run pnpm test before merging. If tests fail, do not merge — leave a comment on the issue instead."`
- The routine only picks up `status:approved` — it respects `status:blocked` and `status:in-progress`
- **PR strategy** is safer: leaves a merge trail, allows CI checks to run before merge
- **Direct strategy** is faster but bypasses review; use only when you trust the agent fully
