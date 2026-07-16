Pick up one approved task, implement the fix, and close it.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `branch` → main branch name (default: main)
- `mergeStrategy` → `pr` or `direct` (default: direct)
- `language` → output/task language (default: English)

If `.darkflow.d/state/config.json` is missing, continue with the defaults.

## Step 2 — Pick the next task

Pick exactly **one** open task with `status:approved`, choosing strictly by priority. The priority order, highest first, is:

1. `priority:critical`
2. `priority:high`
3. `priority:medium`
4. `priority:low`
5. `status:approved` with no priority set (treat as lowest)

Within a level, take the **oldest** task (smallest number).

Skip tasks that are not actually actionable here, even if they still carry `status:approved`:
- `action:reply` — handled exclusively by `mailbox-check`.
- `needs-human` — already parked for a human (failed checks or an external blocker); re-running only posts duplicate comments.
- `scheduledFor` in the future — the task is snoozed ("don't pick up before this date"); it becomes eligible automatically once the date passes.

Rank every selectable task and take the single best one — pipe `df task list`'s JSON through `jq`:

```bash
n=$(~/.darkflow/df task list --status approved | jq -r '
        def prio($p):
          if   $p == "critical" then 0
          elif $p == "high"     then 1
          elif $p == "medium"   then 2
          elif $p == "low"      then 3
          else 4 end;
        [ .[] | select(.action != "reply" and .needsHuman != true
                       and (.scheduledFor == null or .scheduledFor <= (now | todate)))
              | {number, rank: prio(.priority)} ]
        | sort_by([.rank, .number]) | .[0].number // empty')
```

If `$n` is empty, stop — skip the run.

## Step 3 — Read the task

Fetch the full task content before touching any code:

```bash
~/.darkflow/df task view $n
```

Read the title, body, and all comments carefully. If the task references other tasks, read those too.

## Step 4 — Do the work

Implement all the changes needed for it.

**Product language is always English.** The `language` setting is the *communication* language (issues, comments, commits, chat) — it never changes what you write inside the product. All source code, identifiers, code comments, UI copy, user-facing strings, and logs you add must be in English, even when `language` is set to something else.

**Before merging or pushing — run quality checks:**

Detect the project's tech stack and run all available checks. Stop at the first failure.

| Stack | Commands to run (in order) |
|---|---|
| Node / pnpm | `pnpm lint` (if script exists) → `pnpm test` (if script exists) → `pnpm build` (if script exists) |
| Node / npm | `npm run lint` → `npm test` → `npm run build` (skip any that aren't defined) |
| Python | `ruff check .` (if ruff installed) → `pytest` (if pytest installed) |
| Rust | `cargo clippy` → `cargo test` → `cargo build` |
| Go | `go vet ./...` → `go test ./...` → `go build ./...` |
| Other | Check for `Makefile` targets `lint`, `test`, `build` and run those that exist |

**If the fix requires human intervention** (examples: missing environment variable, external credentials, third-party service setup, infrastructure change, secret rotation, manual config change that the agent cannot perform):
- Do NOT attempt the fix
- Leave a comment on the task explaining exactly what human action is needed
- **Before commenting, check the existing comments — if you (the bot) already left an equivalent `needs-human` explanation, do NOT post another one; just stop.**
- Move the task out of the queue so the next run does not re-pick it: `~/.darkflow/df task needs-human $n`
- Stop the run

**If any check fails:**
- Do NOT merge or push
- Leave a comment on the task: what failed and the relevant error output (truncated to ~20 lines)
- Failed checks need a human to look — the agent can't get past them on its own. Move the task out of the queue: `~/.darkflow/df task needs-human $n`
- Stop the run

**If all checks pass (or no checks apply), proceed:**

## Step 5 — Update documentation

Before merging, check whether the fix changes any user-visible behavior, configuration, API, or interface. If yes, update the relevant documentation files:

- If the project has a `README.md` that describes the changed behavior — update it.
- If the project has a `docs/` directory with relevant pages — update them.
- If a changelog exists (`CHANGELOG.md`, `HISTORY.md`, etc.) — add an entry.

Skip this step if the fix is purely internal (refactor, test, build config) with no user-visible effect.

## Step 6 — Land the fix

**Workspace rule — never create a git worktree:**
Always work in the project root on the configured base branch — never run `git worktree add` or check work out into a separate directory. The dispatcher runs you in `cwd = project root`; keep it that way. If the PR strategy needs a feature branch, create it **in place** with `git checkout -b <branch>` on top of the configured base branch, then switch back when done — do not spin up a worktree.

**Branch rule — never cherry-pick to main/master on your own:**
The base branch is the `branch` value from `.darkflow.d/state/config.json` (it may be `main`, `master`, `dev`, `develop`, or anything else — always read it from config, never assume `main`). If it is a non-main/non-master branch, land the fix **only** on that branch. Do NOT cherry-pick, merge, or push to `main` or `master` independently — that is a human decision. Leave the fix in the configured branch and close the task.

**If `merge_strategy=direct` (the default):**
Commit and push directly to the `branch` value from `.darkflow.d/state/config.json`. Every commit message must reference the task — include `Task #N` in the subject or body — so the task is findable from `git log`.

**If `merge_strategy=pr`:**
From the project root, create a feature branch in place with `git checkout -b` based off the `branch` value from `.darkflow.d/state/config.json`, implement and commit there, then open a pull request targeting `branch` referencing "Task #N" in the description (there is no GitHub issue to auto-close — the task lives in Dark Flow's own queue) and merge it into that branch. Commit messages reference `Task #N` too. No worktree — the branch lives in the same working directory.

After landing, leave a comment on the task with a brief summary of what was done. It **must** link the code: the PR URL (with `merge_strategy=pr`) or the commit SHA(s) (with `direct`) — this is the only place the task → code link is recorded:
```bash
~/.darkflow/df task comment $n --body "<summary: what was broken/missing, files changed, docs updated>
Landed: <PR URL | commit SHA(s)>"
```

Then close it:
```bash
~/.darkflow/df task close $n
```

Language for task comments and output: the `language` value from `.darkflow.d/state/config.json`. Code and everything shipped inside the product stays in English regardless of this value.

