# Changelog

All notable changes to Dark Flow are listed here.
Format: `## [version] — YYYY-MM-DD` followed by categorised changes.

Categories:
- **New routine** — new routine file added to `routines/`
- **Updated routine** — existing routine instruction changed
- **New label** — new GitHub label added to taxonomy
- **Updated label** — label color or description changed
- **Workflow** — changes to `agent-workflow.md` or `github-issues.md`
- **Installer** — changes to `install.sh` or `update.sh`
- **Docs** — README, CLAUDE.md template, or other documentation

---

## [2.8.0] — 2026-05-24

### Installer
- **Added `checklist.yml` + `check.sh`** — declarative manifest of every artifact the installer must leave in a project (files, dirs, scheduler, config keys, per-module dirs). `check.sh` verifies them and supports `--fix` for interactive auto-restore
- **`install.sh` runs `check.sh --quiet`** at the end as a sanity check after installation
- **`update.sh` fetches the *latest* `check.sh` and `checklist.yml`** from `main` and runs `check.sh --fix` so an old installation picks up any artifacts added between its version and the current one — fixes the recurring "not everything stayed after update" issue

### Docs
- **README troubleshooting section** mentions `bash check.sh` for repairing partial installs

---

## [2.4.0] — 2026-05-22

### Updated label
- **Removed the `area:*` label group** from the taxonomy — `setup-labels.sh`, `docs/github-issues.md`, the issue template, and the worker dispatcher no longer create or parse `area:*`. The webapp `Issue.area` column is dropped via migration `20260522000002_drop_issue_area`

---

## [2.2.3] — 2026-05-22

### Installer
- **Fixed stale template downloads in `update.sh`** — `smart_update_template()` fetched template files without a cache-buster, so GitHub's raw CDN could serve content up to ~5 min old after a push. Added `?t=$(date +%s)` to both curl calls, matching `fetch_raw()`

---

## [2.2.1] — 2026-05-22

### Worker
- **Issue sync moved to every 5 minutes** — the watch loop now runs the full web UI sync (GitHub issues + metadata) every 5th tick instead of every minute, to cut down on `gh` API calls. The worker-alive heartbeat still pings every 60 s

---

## [2.2.0] — 2026-05-22

### Worker
- **Issues sync every minute** — the watch loop now pushes GitHub issues + project metadata to the web UI on every 60 s tick, not just after a routine runs. `--once` syncs on every invocation too
- **`--sync` mode** — `darkflow-run.sh --sync` pushes issues + metadata to the web UI without running any routine

### Web UI
- **Heartbeat auto-registers the project** — `POST /api/worker/heartbeat` now upserts the project instead of returning 404, so a restarted worker shows up even if install/update never reached the UI. The worker sends the project name with each heartbeat

### Installer
- **`make df-sync` target** — manual web UI sync without running a routine
- **Install/update run a full sync** — `install.sh` and `update.sh` now call `darkflow-run.sh --sync`, so the project *and* its open GitHub issues appear in the UI immediately

---

## [2.1.1] — 2026-05-22

### Installer
- **`df-update` asks about `--force`** — prompts "Force overwrite locally modified files? [y/N]" before running `update.sh`, so you can choose to preserve or overwrite local edits

---

## [2.1.0] — 2026-05-22

### Web UI
- **Worker status indicator** — projects list and detail page now show a live dot: pulsing green while a routine is running, grey when the worker is online/idle, nothing when offline
- **Worker heartbeat API** — new `POST /api/worker/heartbeat` endpoint; worker updates its status once per minute so the UI stays accurate

### Installer
- **Auto-register on install/update** — `install.sh` and `update.sh` now call `/api/ingest` at the end so the project appears in the web UI immediately, without waiting for the first routine run

### Worker
- **Heartbeat in watch loop** — `darkflow-run.sh` sends an "idle" ping every 60 s so the web UI can tell the worker is alive even between routines
- **Running status** — before each routine starts, the worker sends `status=running + routine=<name>`; after it completes, sends `status=idle`
- **Background heartbeat loop** — a background process keeps sending `running` pings every 60 s for long-running routines

---

## [1.5.3] — 2026-05-20

### Installer
- **Removed `df-dry-run` and `df-routine` targets from Makefile** — these were redundant for typical use.

---

## [1.5.2] — 2026-05-20

### Installer
- **Fix: CLAUDE.md update no longer crashes on BSD awk** — passing multiline `new_section` via `awk -v` is undefined behaviour in POSIX awk and causes exit code 1 on some implementations. Replaced with a temp-file approach (same pattern as `inject_makefile_block`) that is safe on all awk variants.

---

## [1.5.1] — 2026-05-20

### Installer
- **Fix: update.sh and install.sh no longer crash when `darkflow-overview.html` has no `darkflow-overview-data` block** — Python `sys.exit(1)` inside a `$()` substitution was propagated by `set -euo pipefail`, aborting the script before the Makefile step and version bump. Fixed by moving the substitution into an `if result=$(...)` condition, which suppresses `set -e` for the command.

---

## [1.5.0] — 2026-05-20

### Installer
- **Makefile generation** — `install.sh` and `update.sh` now create (or update) a `Makefile` with `df-*` shortcut targets for all dispatcher and scheduler commands. If a `Makefile` already exists, the block is injected between `# darkflow:start` / `# darkflow:end` markers without touching existing targets.

### Docs
- **README** — added "Makefile shortcuts" section with `make df-*` usage examples.

---

## [1.4.3] — 2026-05-20

### Installer
- **Removed `--watch` flag** — custom interval removed; no-arg loop always ticks every 60 s.

---

## [1.4.2] — 2026-05-20

### Installer
- **`darkflow-run.sh` default changed to loop** — no-argument invocation now runs continuously, checking for due routines every 60 s instead of doing a single-shot dispatch and exiting.
- **`--once` flag added** — single-shot dispatch for use by system schedulers (launchd plist and crontab entries now call `darkflow-run.sh --once`).
- **`--watch [seconds]`** default interval changed from 900 to 60 s (consistent with no-arg default).

---

## [1.4.1] — 2026-05-20

### Installer
- **`darkflow-run.sh --watch [seconds]`** — foreground loop mode; runs dispatch every N seconds (default 900) in the terminal without requiring launchd or cron. Safe to run alongside a system scheduler (lock prevents concurrent dispatches). Minimum interval: 60 s.

### Docs
- **`routines/README.md`** — added "Running in the foreground (watch mode)" section with `--watch` usage, tmux example, and note on concurrency.

---

## [1.4.0] — 2026-05-20

### Installer
- **Self-hosted routine scheduler** — replaces Claude Code Routines UI dependency. Three new files installed into `.darkflow.d/`: `darkflow-run.sh` (Bash dispatcher), `routines.yml` (cron schedule, generated and filtered by modules), `uninstall-scheduler.sh` (removes system job).
- **`--with-scheduler` / `--no-scheduler` flags** — install.sh optionally sets up a launchd job (macOS) or crontab entry (Linux) that fires the dispatcher every 15 min.
- **Interactive scheduler prompt** — during `install.sh`, user is asked whether to set up the system scheduler.
- **`slug=` field** added to `.darkflow` config — used to name the launchd/crontab job per-project to avoid collisions.
- **`update.sh`** — now copies `darkflow-run.sh` and `uninstall-scheduler.sh`; preserves existing `routines.yml`; adds `.darkflow.d/state/` and `.darkflow.d/*.log` to `.gitignore`.

### Docs
- **`routines/README.md`** — created (was missing, linked from README). Describes the dispatcher, YAML schedule, manual invocation, scheduler setup, and state files.
- **`routines/*.md`** — Configuration tables updated: `Schedule` → `Cron` (cron expression), `Always allowed: Act without asking` → `Permission mode: bypassPermissions`.
- **`README.md`** — Routines section rewritten for self-hosted scheduler model; added `--with-scheduler` flag docs and `darkflow-run.sh` usage examples.

---

## [1.3.1] — 2026-05-19

### Updated commands
- **Merged** `/darkflow:security-code-audit` + `/darkflow:security-runtime-audit` → `/darkflow:security-audit` — both called the same `/security-review` skill; one command is cleaner. Schedule: weekly Sun 3:00.

---

## [1.3.0] — 2026-05-19

### New commands
- **10 new `/darkflow:*` routine commands** — each routine's prompt now lives in a slash command under `.claude/commands/darkflow/`:
  - `/darkflow:fix-issues` — pick up one approved issue, implement, close (reads `merge_strategy=` from `.darkflow` for PR vs direct)
  - `/darkflow:analytics-review` — PostHog + recent commits → GitHub issues + overview update
  - `/darkflow:observability-check` — errors / slow queries / latency → GitHub issues
  - `/darkflow:gsc-check` — Google Search Console → GitHub issues
  - `/darkflow:coolify-logs` — deployment log monitoring → fix errors
  - `/darkflow:deployment-failure` — diagnose and fix a failed deployment
  - `/darkflow:claude-md-update` — regenerate CLAUDE.md from codebase
  - `/darkflow:architecture-review` — architectural analysis → GitHub issues + overview update
  - `/darkflow:security-code-audit` — static `/security-review` → GitHub issues + overview update
  - `/darkflow:security-runtime-audit` — runtime `/security-review` → GitHub issues + overview update

### Updated routines
- **All 10 routine pages** — `Instructions` block collapsed to a single line (`/darkflow:<name>`); `After completing` section removed (moved into the command). Configuration, integrations, and notes preserved.
- **No more `[LANGUAGE]` / `[MAIN_BRANCH]` placeholders** — commands read `language=`, `branch=`, `merge_strategy=` from `.darkflow` automatically.

### Installer
- `install.sh` — fetches all 10 new command files; routine setup footer simplified to one-line prompts; CLAUDE.md `### Dark Flow commands` section updated to list routine commands.
- `update.sh` — fetches all 10 new command files on update; CLAUDE.md section updated to list all routine commands.

---

## [1.2.2] — 2026-05-18

### Installer
- **Renamed command** `/darkflow:new` → `/darkflow:add-issue` — clearer intent

---

## [1.2.1] — 2026-05-18

### Installer
- **Removed command** `/darkflow:labels` — redundant; `/darkflow:update` already re-runs label setup as its first step

---

## [1.2.0] — 2026-05-18

### Installer
- **Refactored commands** — `/darkflow <cmd>` split into namespaced subcommands: `/darkflow:new`, `/darkflow:install`, `/darkflow:update`; `/darkflow` now shows status only

---

## [1.1.0] — 2026-05-17

### Installer
- **Updated command** `/darkflow:new` — interactive issue creator for manually identified bugs and features

---

## [1.0.0] — 2026-05-17

Initial release.

### Routines
- **New routine** `analytics-review` — daily PostHog + commits → GitHub issues
- **New routine** `observability-check` — daily SigNoz/errors/DB queries → GitHub issues
- **New routine** `gsc-check` — weekly Google Search Console → GitHub issues
- **New routine** `fix-issues` — hourly status:approved → PR/direct → merge
- **New routine** `coolify-logs` — daily deployment log monitoring
- **New routine** `claude-md-update` — weekday CLAUDE.md regeneration
- **New routine** `security-code-audit` — weekly /security-review on codebase
- **New routine** `security-runtime-audit` — weekly /security-review on live app
- **New routine** `architecture-review` — weekly /improve-codebase-architecture
- **New routine** `deployment-failure` — API-triggered deployment failure fix

### Labels
- Full taxonomy: `status:*`, `source:*`, `area:*`, `priority:*`, `effort:*`

### Installer
- Interactive module selection (analytics, observability, GSC, ads, Coolify, CLAUDE.md update, architecture review)
- Language selection (injected into CLAUDE.md and routine reminders)
- Branch name + merge strategy configuration
- Observability integration wizard (URL + API key → `.env.darkflow`)
- Architecture review skill installer (`improve-codebase-architecture`)
- `/darkflow` slash command for Claude Code
