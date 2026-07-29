# CI Watch

Every-30-minutes check that turns a broken pipeline into a task. It is the **producer** for `source:ci` tasks — `fix-ci-issue` is the consumer that fixes them.

This routine runs **entirely inside the worker as bash**. There is no agent, no command file, no LLM call and no token cost: deciding "CI is red" and writing a task is pure bookkeeping. All the reasoning happens later, in `fix-ci-issue`.

---

## What it checks

**A. GitHub Actions on the base branch.** Takes the newest run per workflow (an old red run whose workflow has since gone green must not keep a task open) and flags it when it either:

- concluded `failure`, or
- is **still queued / in progress after 45 minutes** (`CI_STUCK_MIN`).

The stuck case matters as much as the red one. When a self-hosted runner goes offline the job is never red *and* never green — it just sits in `queued` forever. Nothing else in Dark Flow would ever notice, and a repo with a dead runner looks healthy by silence.

**B. Local `lint` + `test` in the project root.** Only when `HEAD` moved since the last green run, so an idle repo costs nothing. This covers the projects that have **no GitHub workflows at all** — there, GitHub-side polling has nothing to watch.

- JS: `pnpm lint` / `pnpm test`, for whichever scripts `package.json` actually defines. Skipped when `node_modules` is absent — installing deps is not this routine's job, and a missing one would look like a code failure.
- Python: `ruff check .` when `ruff` is on PATH.

The HEAD marker (`.darkflow.d/state/ci-watch.sha`) is written **only when the local checks pass**, so a red repo keeps being re-checked until it's actually fixed.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `*/30 * * * *` (every 30 min) |
| Folder | Project root (`/path/to/your-project`) |
| Model | none — bash only, never launches an agent |
| Run manually | `~/.darkflow/darkflow-run.sh ci-watch` |

**Core routine — no module.** There is nothing to opt into: no agent, no cost, and
no setup beyond an authenticated `gh`.

The tasks it files are `status=approved`, so they are picked up either by
`fix-ci-issue` (when the `ci-gate` module is on — bounded 3-attempt retries) or,
failing that, by plain `fix-issues` along with every other approved task.

---

## Required integrations

- **`gh`** authenticated (`gh auth login`) — for part A. Without it only the local checks run.
- **`jq`**, **`python3`** — already hard dependencies of the worker.

---

## What gets created

**One deduped task per branch**, titled `CI failure on <branch>`:

- `source=ci`, `priority=high`, `status=approved` (auto-approved — a broken pipeline blocks everything downstream)
- Body lists the failing checks, the run URLs and the last 40 lines of each failure log, so `fix-ci-issue` has something concrete to reproduce.

If the task is already open, the routine adds a comment instead of filing a duplicate. When everything goes green again, it **closes the task** — that is what bounds the retry loop in `fix-ci-issue` (max 3 attempts per open task).

```
ci-watch (bash, 0 tokens)  →  source:ci task  →  fix-ci-issue (agent)  →  push
      ↑                                                                     │
      └──────────────────  green → task closed  ←──────────────────────────┘
```

---

## Notes

- **Replaces the `darkflow-ci-gate` GitHub workflow.** That workflow needed a self-hosted runner to execute the checks, and — running inside GitHub Actions — could not reach the local task store, so it filed GitHub Issues nobody read. Running the same logic in the worker removes both problems: the worker reaches `df` directly, and nothing has to be online but the machine itself.
- If a repo still has `.github/workflows/darkflow-ci-gate.yml`, delete it. Its checks are duplicated here, and a `runs-on: [self-hosted, …]` job with an offline runner is exactly the "stuck in queued" state part A now reports.
- The routine never fixes anything and never pushes. It also never files a task for a *stuck* run more than once per branch.
