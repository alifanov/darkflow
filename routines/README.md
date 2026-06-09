# Dark Flow Routines

Routines are Claude agents that run automatically on a schedule, keeping your project healthy without manual intervention.

Each routine is a slash command (`/darkflow:<name>`) that Dark Flow installs into `.claude/commands/darkflow/`. The **dispatcher** (`darkflow-run.sh`) reads a YAML schedule and runs due routines via `claude -p`.

## How it works

```
.darkflow.d/routines.yml     ← schedule: which cron, which model, enabled?
.darkflow.d/darkflow-run.sh  ← dispatcher: reads YAML, runs due routines
.darkflow.d/state/           ← last-run timestamps (git-ignored, machine-local)
.darkflow.d/darkflow-run.log ← dispatcher log (git-ignored)
```

The dispatcher fires `claude -p "/darkflow:<name>"` for each due routine — a clean, non-interactive session that starts only with the slash command. No context is carried between runs.

## Routine schedule

All routines and their default cron expressions:

| Routine | Cron | Description |
|---|---|---|
| `fix-issues` | `0 * * * *` | Hourly — picks up `status:approved` issues, implements, merges |
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

```bash
# Start the dispatcher loop (checks every minute — default)
bash .darkflow.d/darkflow-run.sh

# Run one routine immediately (ignores schedule and state)
bash .darkflow.d/darkflow-run.sh fix-issues

# Show status table (last run, enabled, cron)
bash .darkflow.d/darkflow-run.sh --list

# Preview what would run without running it
bash .darkflow.d/darkflow-run.sh --dry-run
```

## Running in the foreground

The default no-argument mode is a **continuous loop** — it checks for due routines every minute, runs them, and sleeps until the next check. No system scheduler needed:

```bash
bash .darkflow.d/darkflow-run.sh
```

Recommended: run inside `tmux` or `screen` so it survives terminal disconnect:

```bash
tmux new-session -d -s darkflow 'bash .darkflow.d/darkflow-run.sh'
```

Press Ctrl-C (or `kill`) to stop cleanly.

## Setting up a system scheduler

For background operation without a persistent terminal, install a system scheduler:

```bash
bash .darkflow.d/install-scheduler.sh
```

This installs a **launchd job** (macOS) or **crontab entry** (Linux) that fires the dispatcher every 15 minutes. To remove it:

```bash
bash .darkflow.d/uninstall-scheduler.sh
```

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

Routines run in the project root. Branch isolation (for PR-strategy `fix-issues`) is handled by the slash-command prompt itself — it creates and pushes a branch, opens a PR, and merges. The dispatcher always uses `cwd = project root`.

## Adding a new routine

1. Add a prompt file: `templates/.claude/commands/darkflow/<name>.md`
2. Add an entry to `routines.yml` in the installed project
3. Document it here and in `routines/<name>.md`
