# Dark Flow Routines

Routines are Claude agents that run automatically on a schedule, keeping your project healthy without manual intervention.

Each routine is a slash command (`/darkflow:<name>`) installed once into user scope (`~/.claude/commands/darkflow/`). A **single global worker** (`~/.darkflow/darkflow-run.sh`) services every project: it reads each project's YAML schedule and runs due routines via `claude -p` (or `codex exec`).

## How it works

```
~/.darkflow/darkflow-run.sh   ← ONE global worker: discovers projects, runs due routines
~/.darkflow/config            ← global config (webapp_url, version)
~/.darkflow/get-config.sh      ← fetches a project's config from the Web UI
~/.darkflow/worker.log        ← global worker log

per project (runtime only — config + schedule live in the Web UI/DB):
.darkflow.d/state/config.json ← project config fetched from the Web UI (cache)
.darkflow.d/state/            ← last-run timestamps (git-ignored, machine-local)
.darkflow.d/darkflow-run.log  ← this project's run log (git-ignored)
```

The worker discovers projects from the web UI (`GET /api/projects` — each project's
**Local path**), then for each one fires `claude -p "/darkflow:<name>"` for every due
routine — a clean, non-interactive session that starts only with the slash command. No
context is carried between runs. A machine-global semaphore caps how many agent sessions
run at once across all projects.

## Routine schedule

All routines and their default cron expressions:

| Routine | Cron | Description |
|---|---|---|
| `fix-issues` | `0 * * * *` | Hourly — picks up approved tasks, implements, commits directly to the base branch (PR mode optional per project) |
| `analytics-review` | `0 8 * * *` | Daily 8:00 — OpenPanel + recent commits → tasks |
| `observability-check` | `30 8 * * *` | Daily 8:30 — errors / latency → tasks |
| `gsc-check` | `0 8 * * 1` | Weekly Mon 8:00 — Google Search Console + technical/on-page SEO audit → tasks |
| `coolify-check-deployment` | `0 9 * * *` | Daily 9:00 — deployment status → `critical` task on failed deploy |
| `claude-md-update` | `0 9 * * 1-5` | Weekdays 9:00 — regenerates CLAUDE.md from codebase |
| `architecture-review` | `0 2 * * 0` | Weekly Sun 2:00 — architectural analysis → tasks |
| `security-audit` | `0 3 * * 0` | Weekly Sun 3:00 — full security review → tasks |
| `build-optimization` | `0 4 * * 0` | Weekly Sun 4:00 — build + deploy pipeline analysis → tasks |
| `uptime-check` | `0 */4 * * *` | Every 4 hours — DNS + HTTP + page-load check → **auto-approved** `critical` task if site down |
| `web-vitals` | `0 6 * * 1` | Weekly Mon 6:00 — Core Web Vitals via PageSpeed Insights → task if a metric is poor |
| `docs-audit` | `0 5 * * 0` | Weekly Sun 5:00 — docs ↔ code drift check → tasks |
| `code-health` | `0 7 * * 0` | Weekly Sun 7:00 — fallow audit (dead code, dupes, cycles, complexity) → tasks *(optional, TS/JS only)* |
| `product-overview` | `0 7 * * 1` | Weekly Mon 7:00 — product overview digest (writes snapshot, no tasks) |
| `vulnerability-check` | `0 6 * * *` | Daily 6:00 — GitHub Dependabot + code/secret scanning alerts → tasks |
| `ads-review` | `0 8 * * 1` | Weekly Mon 8:00 — paid ads performance → tasks |
| `design-audit` | `0 10 * * 6` | Weekly Sat 10:00 — `impeccable:audit` five-dimension quality check → tasks |
| `design-critique` | `0 11 * * 6` | Weekly Sat 11:00 — `impeccable:critique` scored review + persona tests → tasks |
| `design-harden` | `0 10 1 * *` | Monthly 1st 10:00 — `impeccable:harden` edge cases, i18n, error states → tasks |

Cron times are in the machine's local timezone.

## Running routines

The global worker runs all projects automatically. The single-project subcommands act on
the project containing the current directory:

```bash
# Run one routine immediately (ignores schedule and state) — cwd's project
~/.darkflow/darkflow-run.sh fix-issues

# Show status table (last run, enabled, cron) — cwd's project
~/.darkflow/darkflow-run.sh --list

# Preview what would run without running it — cwd's project
~/.darkflow/darkflow-run.sh --dry-run
```

## The global worker

With no arguments, `~/.darkflow/darkflow-run.sh` is a **continuous loop**: every 30s it
discovers the registered projects from the web UI and runs each one's due routines.

The installer does **not** auto-start it — you start it yourself, for full control:

```bash
# Start (runs in the background until you stop it)
nohup bash ~/.darkflow/darkflow-run.sh >/dev/null 2>> ~/.darkflow/worker.err.log &

# Stop
pkill -f ~/.darkflow/darkflow-run.sh

# Watch what it's doing
tail -f ~/.darkflow/worker.log
```

Prefer something more durable (tmux/screen, a launchd agent, or a systemd unit)? Wrap that
same command — the worker itself is just a long-running process.

A project becomes eligible the moment it has synced and has a **Local path** set in the
web UI (the installer registers this automatically on first sync).

## Editing the schedule

The schedule lives in the Web UI, not in a file. Open a project's **Settings → Routine
schedule** to change `cron`/`model`/`engine` or enable/disable any routine. The global
worker fetches the merged schedule (catalog defaults + your overrides) from
`/api/projects/by-repo` on every tick, so changes apply on the next tick — no reload.

The catalog of routines + their default cron/model lives in `webapp/src/lib/routines.ts`;
a project's per-routine overrides are stored in the `RoutineConfig` table.

## Permissions

All routines need to act autonomously. The default `bypassPermissions` mode is the
equivalent of "Always allowed: Act without asking" in the Claude Code UI. Override a
routine to `acceptEdits` per project in the Web UI for a more cautious mode that still
prompts before bash commands.

## Worktree note

By default routines **never** create a git worktree. They run in the project root (`cwd = project root`) and work directly on the configured base branch. For PR-strategy `fix-issues`, the feature branch is created **in place** with `git checkout -b` based off the configured `branch=` (`main`, `master`, `dev`, … — whatever the project is set to) — never `git worktree add`, never a separate checkout directory. The routine agent itself must still never create its own worktree.

**Opt-in isolation** (config `worktree: true`): the *dispatcher* runs each routine in a throwaway `git worktree add --detach` checkout, tears it down after the run (with an EXIT-trap backstop on crash), and symlinks the untracked build inputs (`node_modules`, `.env`/`.env.local` at every level up to 4 deep) back in so builds and env-reads work. Use this to let multiple routines run against the same project in parallel without fighting over the working tree. Caveat: a detached worktree can't `git checkout` the base branch (it's held by the root worktree), so PR-strategy `fix-issues` must merge server-side (`gh pr merge`), not via a local checkout of `main`.

## Adding a new routine

1. Add a prompt file: `templates/.claude/commands/darkflow/<name>.md`
2. Add it to the catalog in `webapp/src/lib/routines.ts` (name, default cron/model, module gate)
3. Document it here and in `routines/<name>.md`

New routines auto-propagate to every project via `/api/projects/by-repo` — no per-project edit needed.
