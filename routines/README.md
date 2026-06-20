# Dark Flow Routines

Routines are Claude agents that run automatically on a schedule, keeping your project healthy without manual intervention.

Each routine is a slash command (`/darkflow:<name>`) installed once into user scope (`~/.claude/commands/darkflow/`). A **single global worker** (`~/.darkflow/darkflow-run.sh`) services every project: it reads each project's YAML schedule and runs due routines via `claude -p` (or `codex exec`).

## How it works

```
~/.darkflow/darkflow-run.sh   ← ONE global worker: discovers projects, runs due routines
~/.darkflow/config            ← global config (webapp_url, version)
~/.darkflow/worker.log        ← global worker log

per project:
.darkflow.d/routines.yml      ← schedule: which cron, which model, enabled?
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
| `fix-issues` | `0 * * * *` | Hourly — picks up `status:approved` issues, implements, merges |
| `fix-ci-issue` | `*/15 * * * *` | Every 15 min — picks up a `source:ci` issue, pushes a fix; retries up to 3x, then `needs-human` *(optional, `ci-gate` module)* |
| `analytics-review` | `0 8 * * *` | Daily 8:00 — PostHog + recent commits → GitHub issues |
| `observability-check` | `30 8 * * *` | Daily 8:30 — errors / latency → GitHub issues |
| `gsc-check` | `0 8 * * 1` | Weekly Mon 8:00 — Google Search Console + technical/on-page SEO audit → GitHub issues |
| `coolify-check-deployment` | `0 9 * * *` | Daily 9:00 — deployment status → `critical` issue on failed deploy |
| `claude-md-update` | `0 9 * * 1-5` | Weekdays 9:00 — regenerates CLAUDE.md from codebase |
| `architecture-review` | `0 2 * * 0` | Weekly Sun 2:00 — architectural analysis → GitHub issues |
| `security-audit` | `0 3 * * 0` | Weekly Sun 3:00 — full security review → GitHub issues |
| `build-optimization` | `0 4 * * 0` | Weekly Sun 4:00 — build + deploy pipeline analysis → GitHub issues |
| `uptime-check` | `0 */4 * * *` | Every 4 hours — DNS + HTTP + page-load check → **auto-approved** `critical` issue if site down |
| `docs-audit` | `0 5 * * 0` | Weekly Sun 5:00 — docs ↔ code drift check → GitHub issues |
| `code-health` | `0 7 * * 0` | Weekly Sun 7:00 — fallow audit (dead code, dupes, cycles, complexity) → GitHub issues *(optional, TS/JS only)* |
| `product-overview` | `0 7 * * 1` | Weekly Mon 7:00 — product overview digest (writes snapshot, no issues) |
| `vulnerability-check` | `0 6 * * *` | Daily 6:00 — GitHub Dependabot + code/secret scanning alerts → GitHub issues |
| `ads-review` | `0 8 * * 1` | Weekly Mon 8:00 — paid ads performance → GitHub issues |
| `design-audit` | `0 10 * * 6` | Weekly Sat 10:00 — `impeccable:audit` five-dimension quality check → GitHub issues |
| `design-critique` | `0 11 * * 6` | Weekly Sat 11:00 — `impeccable:critique` scored review + persona tests → GitHub issues |
| `design-harden` | `0 10 1 * *` | Monthly 1st 10:00 — `impeccable:harden` edge cases, i18n, error states → GitHub issues |

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
nohup bash ~/.darkflow/darkflow-run.sh >> ~/.darkflow/worker.log 2>&1 &

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

Open `.darkflow.d/routines.yml` and change `cron`, `model`, or `enabled` for any routine:

```yaml
routines:
  fix-issues:
    cron: "0 * * * *"   # change frequency here
    model: sonnet
    enabled: true        # set false to disable without deleting
```

The dispatcher picks up YAML changes immediately on its next tick — no reload needed.

## Permissions

All routines need to act autonomously. The default `permission_mode: bypassPermissions` in `routines.yml` is the equivalent of "Always allowed: Act without asking" in the Claude Code Routines UI. Change to `acceptEdits` for a more cautious mode that still prompts before bash commands.

## Worktree note

Routines **never** create a git worktree. They always run in the project root (`cwd = project root`, enforced by the dispatcher) and work directly on the configured base branch. For PR-strategy `fix-issues`, the feature branch is created **in place** with `git checkout -b` based off the configured `branch=` (`main`, `master`, `dev`, … — whatever the project is set to) — never `git worktree add`, never a separate checkout directory.

## Adding a new routine

1. Add a prompt file: `templates/.claude/commands/darkflow/<name>.md`
2. Add an entry to `routines.yml` in the installed project
3. Document it here and in `routines/<name>.md`
