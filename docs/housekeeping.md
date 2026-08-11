# Housekeeping

One daily bookkeeping pass over each project. It runs **entirely inside the worker as bash** —
no agent, no command file, no LLM call, no token cost. Nothing it does needs reasoning; it is
three mechanical repairs that would otherwise cost two agent routines a day, per project.

Same pattern as `ci-watch`, and for the same reason: deciding "this task has been in-progress
for four hours" is bookkeeping, not judgement.

---

## What it repairs

### 1. Stuck tasks

A task in `in-progress` whose `updatedAt` is older than **4 hours** is one whose session is
gone — killed, crashed, or the machine slept. Nothing else would ever pick it up: `fix-issues`
only looks at `approved`.

Housekeeping leaves a comment saying why, then puts it back to `approved`.

> There is a faster path too: `fix-issues` calls a 1-hour revive at the start of every run. That
> one only fires when `fix-issues` is due and has work. Housekeeping is the net underneath — it
> runs whether or not there are approved tasks, and whether or not `fix-issues` is enabled.

### 2. Stuck `HEAD`

`fix-issues` is supposed to switch the checkout back to the base branch when it finishes, so a
`HEAD` left on a feature branch means a session was killed mid-flight.

This is not cosmetic. Under A7 every routine writes into the repo, and until `HEAD` is back on
the base branch **every one of those writes lands on the wrong branch**. Recovering the task
without recovering the checkout fixes half the damage.

So: if `HEAD` is off the base branch and the working copy has nothing unexpected in it, switch
back. If there *is* unexpected work, leave everything alone and say so — a killed session's
half-finished edits are not ours to throw away.

### 3. Worktrees and merged branches

`git worktree prune`, then delete every branch already merged into the base branch. Anything
unmerged stays.

---

## The one subtlety: what counts as "dirty"

The uncommitted-changes test **ignores `docs/logs/` and `docs/state/`**.

Under the `pr` merge strategy an audit commits nothing (A7): it writes its daily-log section and
leaves it in the working copy for the next pull request to carry. Those files are *supposed* to
be sitting there.

Without the exemption the whole pass would be dead on arrival:

```
no open tasks  →  no PR for weeks  →  the daily log stays uncommitted
               →  the checkout always looks dirty
               →  HEAD is never recovered, nothing is ever cleaned up
```

— and that is precisely the situation in which recovery is needed.

Anything else uncommitted is reported and **left alone**. Housekeeping never commits, never
pushes, and never discards a change.

---

## Schedule

Daily at 05:00 by default. Change it per project in the Web UI → Settings → Routine schedule,
same as any other routine.

Run it by hand from a project directory:

```bash
~/.darkflow/darkflow-run.sh housekeeping
```
