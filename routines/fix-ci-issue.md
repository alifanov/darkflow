# Fix CI Issue

Picks up one CI-failure task (`source:ci`, `status:approved`), reproduces the failing lint/test, fixes it, and pushes — with **bounded retries**. The same task is retried up to **3 times**; after the third failed attempt it is handed to a human. This prevents an endless red-CI → task → fix → red-CI loop.

Gated on the `ci-gate` module (self-hosted CI runner + `darkflow-ci-gate` workflow — see `docs/ci-runner.md`).

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
- **`darkflow-ci-gate` workflow** on a self-hosted runner — files `source:ci` tasks on red CI and closes them on green (`close-on-green`) via the Dark Flow task store

---

## The retry gate

```
CI goes red → ci-gate files a source:ci task (status:approved)
  ↓
This routine picks the oldest such task (next :00/:15/:30/:45)
  ↓
attempt 1 → fix → push → comment «attempt 1/3»   (task stays open)
  ↓
CI green?  → close-on-green closes the task ✓  (retry counter reset)
CI red?    → next run: attempt 2/3, then 3/3
  ↓
after attempt 3 still red → needs-human (pulled off the approved queue)
```

The counter is reliable because the task is **never closed by this routine** — only the CI gate closes it when the build is actually green. Attempts accumulate as marker comments (`<!-- darkflow:ci-attempt -->`) on the one open task.

---

## Notes

- **One task per run** — the oldest open `source:ci` + `status:approved` task, skipping `needs-human`.
- Verifies with **lint + test only** — never `build`; the CI gate verifies the build on push.
- The task store lives in Dark Flow's own Postgres (via `~/.darkflow/df`), not GitHub Issues — the routine never calls `gh issue`.
- **No git worktree** — always works in the project root; PR-mode feature branches are created in place with `git checkout -b` off the configured base branch.
- If a fix genuinely needs a human (missing env var, credentials, infra, a flaky/environment-only failure), it is moved to `needs-human` immediately with an explanation — regardless of attempt count.
