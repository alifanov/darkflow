Pick up one CI-failure task (`source:ci`), fix the failing lint/test, and push — with **bounded retries**. The same task is retried up to **3 times**; only after the third failed attempt is it handed to a human. This prevents an endless red-CI → task → fix → red-CI loop.

The task itself is **not closed here** — the `darkflow-ci-gate` workflow closes it automatically once CI goes green again (`close-on-green`, via the Dark Flow task store). That is what makes the retry counter reliable: one open task per failing branch, attempts accumulate on it as comments.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `branch` → main branch name (default: main)
- `mergeStrategy` → `pr` or `direct` (default: direct)
- `language` → output/comment language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the defaults.

## Step 2 — Pick the next CI task

Pick exactly **one** open task with `source:ci` and `status:approved`, skipping any that carry `needs-human` (already parked). Within the candidates, take the **oldest** (smallest number) — one open task per failing branch, FIFO:

```bash
n=$(~/.darkflow/df task list --source ci --status approved --state open | jq -r '
      [ .[] | select(.needsHuman != true) | .number ] | min // empty')
```

If `$n` is empty, stop — nothing to do this run.

## Step 3 — Count prior attempts (the retry gate)

Each attempt this command makes leaves a marker comment containing `<!-- darkflow:ci-attempt -->`. Count them from the task's comments (`df task view` returns the full comment array, or `null` when there are none):

```bash
attempts=$(~/.darkflow/df task view "$n" | jq '
  [ (.comments // [])[] | select(.body | contains("<!-- darkflow:ci-attempt -->")) ] | length')
```

- **`MAX_ATTEMPTS = 3`.**
- If `attempts >= 3` → **escalate to a human and STOP** (see Step 6). Do not attempt another fix.
- Otherwise this run is attempt **`attempts + 1`** of 3 — continue to Step 4.

## Step 4 — Reproduce and fix

Read the task with `~/.darkflow/df task view "$n"` — the body lists the failing checks (e.g. `lint`, `test`) and the captured error output, plus the CI run link and commit SHA.

1. Run the failing check(s) locally to reproduce (e.g. `pnpm lint`, `pnpm test`, `ruff check .`, `pytest`).
2. Implement a focused fix for the actual failure. Keep the change minimal and scoped to what CI flagged.
3. **Verify locally — run `lint` and `test` only.** Do **not** run `build`: the CI gate verifies the build on push. Stop if lint/test still fail and you cannot resolve them — then go to Step 6 (escalate) rather than pushing a known-bad fix.

**Product language is always English.** `language` controls only the language of task comments and commit messages — never source code, identifiers, comments, or UI strings.

**If the fix genuinely needs a human** (missing env var, external credentials, infra change, secret rotation, a flaky/environment-only failure you cannot reproduce or fix): do not push. Go straight to Step 6 with an explanation of what's needed — regardless of the attempt count.

## Step 5 — Push the fix (do NOT close the task)

**Workspace rule — never create a git worktree.** Work in the project root on the configured base branch; if you need a feature branch, create it in place with `git checkout -b` based off `branch`, never `git worktree add`.

Apply per `mergeStrategy`:

- **`direct`**: commit and push straight to the `branch` value from config.
- **`pr`**: create a feature branch in place off `branch`, commit, open a PR targeting `branch`, and merge it. **Reference the task with "Task #N" in the description, NOT "Closes #N"** — the task must stay open so the CI gate can close it only when CI is actually green (there is no GitHub issue to auto-close; the task lives in Dark Flow's own queue).

Then, on the task, post the attempt marker comment (in `language`):

```bash
~/.darkflow/df task comment "$n" --body "<!-- darkflow:ci-attempt -->
🤖 CI auto-fix **attempt $((attempts + 1))/3** — pushed \`<sha>\` to \`<branch>\`. Awaiting CI re-run; if it stays red this task will be retried, then handed to a human after attempt 3."
```

**Do not close the task and do not change its status.** If the fix worked, the CI gate's `close-on-green` step closes it on the next green run. If it didn't, the task stays `status:approved` and the next run increments the counter.

## Step 6 — Escalate to a human (after 3 attempts, or when blocked)

Only when `attempts >= 3`, or the fix needs a human — pull the task off the approved queue and flag it for a human:

```bash
~/.darkflow/df task needs-human "$n"
```

Then comment (in `language`) explaining the situation — for the attempt-cap case: that auto-fix was tried 3 times and CI is still failing, with the latest failing checks and the most recent CI run link; for the blocked case: exactly what human action is required.

Before commenting, check existing comments — if an equivalent `needs-human` explanation already exists, don't post a duplicate. Then stop the run.
