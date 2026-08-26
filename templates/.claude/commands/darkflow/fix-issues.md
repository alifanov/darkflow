---
description: Pick up one approved task, implement the fix, and close it.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, Bash(git push:*)
---

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `branch`, `mergeStrategy`, `language`.

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
        [ .[] | select(.action != "reply"
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

The body carries a `## Plan` — it is a starting point written when the finding was filed, not a
contract. Follow it where it still holds; where the code has moved on, rewrite it and say so in
the closing comment. The `## Acceptance criteria` are the contract: each one names the command,
report or URL that decides it, and every one must pass before the task closes.

### Tasks that land one step per run

A `## Plan` heading written as **`## Plan (one step per run)`** means the task is too big for a
single run and was deliberately split. Everything else about the section is unchanged — the same
numbered checkboxes.

```markdown
## Plan (one step per run)

- [ ] 1. Extract the shared helper
- [ ] 2. Migrate the three call sites
- [ ] 3. Delete the old copies
```

The body is not editable from the CLI, so **progress lives in the comments**. Count the comments
whose first line starts with `Step K/M` — that is how many steps are already done. This run does
step `K+1` and nothing else: one step, one commit or PR, one comment, task stays open. Only the
last step closes it.

A plain `## Plan` heading means what it always did: the whole task is finished in this run.

Such a task keeps winning Step 2's ranking until it is done — that is the point: it lands one
piece per tick instead of competing with itself.

## Step 4 — Do the work

Implement all the changes needed for it — or, under `## Plan (one step per run)`, everything
step `K+1` names and nothing beyond it.

**If you stop half-way** — escalating to `needs-human`, or handing the task back — say which plan
steps are done and which are not in the comment. The plan in the body is not editable from the
CLI, so the comment is the only record of how far it got.

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

Then append a `## Changes` entry to today's daily log, `docs/logs/$(date +%F).md` — one line per
task, not a report:

```markdown
## Changes

- Task #N — <what changed, in one line> (<PR URL or commit SHA>)
```

## Step 6 — Land the fix

**Workspace rule — never create a git worktree:**
Always work in the project root on the configured base branch — never run `git worktree add` or check work out into a separate directory. The dispatcher runs you in `cwd = project root`; keep it that way. If the PR strategy needs a feature branch, create it **in place** with `git checkout -b <branch>` on top of the configured base branch, then switch back when done — do not spin up a worktree.

**Branch rule — never cherry-pick to main/master on your own:**
The base branch is the `branch` value from `.darkflow.d/state/config.json` (it may be `main`, `master`, `dev`, `develop`, or anything else — always read it from config, never assume `main`). If it is a non-main/non-master branch, land the fix **only** on that branch. Do NOT cherry-pick, merge, or push to `main` or `master` independently — that is a human decision. Leave the fix in the configured branch and close the task.

**If `merge_strategy=direct` (the default):**
Commit and push directly to the `branch` value from `.darkflow.d/state/config.json`. Every commit message must reference the task — include `Task #N` in the subject or body — so the task is findable from `git log`.

**If `merge_strategy=pr`:**
From the project root, create a feature branch in place with `git checkout -b` based off the `branch` value from `.darkflow.d/state/config.json`, implement and commit there, then open a pull request targeting `branch` referencing "Task #N" in the description (there is no GitHub issue to auto-close — the task lives in Dark Flow's own queue) and merge it into that branch. Commit messages reference `Task #N` too. No worktree — the branch lives in the same working directory.

**Carry the audits' files with you (A7).** Under the `pr` strategy the audit routines commit
nothing — their daily-log sections and `docs/state/` edits sit in the working copy waiting for
the next pull request, and this is it. Alongside the files of your own fix, stage:

```bash
git add docs/logs/ docs/state/       # only if they actually changed
```

Still an explicit list, just a longer one. **Never `git add -A`** — it would sweep in whatever
else happens to be lying in the working copy.

**After pushing — confirm CI is green before closing the task:**

Do not close a task on a hope. Wait for the GitHub Actions run of the commit you just pushed and read the verdict in this session:

```bash
~/.darkflow/ci-wait.sh; echo "ci-wait exit: $?"
```

Act on the exit code:

| Exit | Meaning | What to do |
|---|---|---|
| `0` | CI green (or the project has no CI) | Continue — comment and close the task |
| `2` | No workflow run appeared for this commit | Continue — treat as "no CI on this push", but say so in the task comment |
| `1` | **CI red** | Do NOT close the task. Comment with the failing job's URL and the error output `ci-wait.sh` printed, then `~/.darkflow/df task needs-human $n` and stop |

`ci-wait.sh` blocks until the run finishes (10 min cap by default; override with `CI_WAIT_TIMEOUT`). It is the synchronous counterpart to the `ci-watch` routine — same signal, but reported while the session that caused it is still open.

After landing, leave a comment on the task with a brief summary of what was done. It **must** link the code: the PR URL (with `merge_strategy=pr`) or the commit SHA(s) (with `direct`) — this is the only place the task → code link is recorded:
```bash
~/.darkflow/df task comment $n --body "<summary: what was broken/missing, files changed, docs updated>
Landed: <PR URL | commit SHA(s)>"
```

Under `## Plan (one step per run)` the comment's **first line** is the progress marker, and the
step number is what the next run reads:

```bash
~/.darkflow/df task comment $n --body "Step 2/3 — <what this step changed>
Landed: <PR URL | commit SHA(s)>"
```

Then close it — **only when no unchecked step is left**:
```bash
~/.darkflow/df task close $n
```

With steps still open, leave the status alone: `approved` is what brings the task back on the
next tick.

Language for task comments and output: the `language` value from `.darkflow.d/state/config.json`. Code and everything shipped inside the product stays in English regardless of this value.

