# Fix CI Issue

Picks up one CI-failure task (`source:ci`, `status:approved`), reproduces the failing lint/test, fixes it, and pushes — with **bounded retries**. The same task is retried up to **3 times**; after the third failed attempt it is handed to a human. This prevents an endless red-CI → task → fix → red-CI loop.

Gated on the `ci-gate` module. The tasks it consumes are produced by **`ci-watch`** (see `routines/ci-watch.md`) — enable both, or neither.

---

## Instructions

```
/darkflow:fix-ci-issue
```

The command reads `.darkflow.d/state/config.json` for branch, language, and merge strategy — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `*/15 * * * *` (every 15 min) |
| Module | `ci-gate` |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh fix-ci-issue` |

---

## Required integrations

- **Git** configured with push access to the repository
- **`gh` CLI** authenticated — only when the project's merge strategy is PR mode (for creating PRs)
- **`ci-watch` routine enabled** — it is the only producer of `source:ci` tasks, and the only thing that closes them again on green. Without it this routine has an empty queue forever.

---

## The retry gate

```
CI red / stuck → ci-watch files a source:ci task (status:approved)
  ↓
This routine picks the oldest such task (next :00/:15/:30/:45)
  ↓
attempt 1 → fix → push → comment «attempt 1/3»   (task stays open)
  ↓
CI green?  → ci-watch closes the task ✓  (retry counter reset)
CI red?    → next run: attempt 2/3, then 3/3
  ↓
after attempt 3 still red → needs-human (pulled off the approved queue)
```

The counter is reliable because the task is **never closed by this routine** — only `ci-watch` closes it, and only once the checks actually pass. Attempts accumulate as marker comments (`<!-- darkflow:ci-attempt -->`) on the one open task.

---

## Notes

- **One task per run** — the oldest open `source:ci` + `status:approved` task, skipping `needs-human`.
- Verifies with **lint + test only** — never `build`; the project's own build/deploy workflow covers that, and `ci-watch` reports it when it goes red.
- The task store lives in Dark Flow's own Postgres (via `~/.darkflow/df`), not GitHub Issues — the routine never calls `gh issue`.
- **No git worktree** — always works in the project root; PR-mode feature branches are created in place with `git checkout -b` off the configured base branch.
- If a fix genuinely needs a human (missing env var, credentials, infra, a flaky/environment-only failure), it is moved to `needs-human` immediately with an explanation — regardless of attempt count.
