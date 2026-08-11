# Dark Flow

**A workflow layer for AI-assisted development** — structured docs, a task triage loop backed by Dark Flow's own store, and an installer that sets it all up in minutes.

---

## What problem does this solve?

When Claude Code (or any AI agent) works on your project, it generates insights and recommendations — but they evaporate between sessions. There's no handoff from "observation" to "approved task" to "merged change."

Dark Flow installs:
- A **5-layer docs structure** (`product / spec / design / logs / decisions`) with clear read/write rules for the agent
- A **task triage loop** — agent creates `proposed` tasks from insights via the `~/.darkflow/df` CLI, human approves or rejects, agent picks up `approved` tasks automatically
- A **set of task fields** (`status`, `source`, `priority`, `needsHuman`, `scheduledFor`) so you can filter with `~/.darkflow/df task list --status approved` or snooze a task until a date
- **Agent-workflow rules** baked into `docs/agent-workflow.md` (referenced from CLAUDE.md)

---

## Install

Open Claude Code in your project directory and paste this message:

```
Install Dark Flow workflow from https://github.com/alifanov/darkflow

Run the installer:
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh

Ask me which optional modules I want (analytics, observability, GSC, ads, Coolify, architecture review, design),
then run the installer with the appropriate flags.
After install, show me the routines I need to set up in Claude Code → Routines.
```

The agent will fetch the installer, ask about your stack, run it with the right flags, and walk you through setting up Routines.

### What the installer does

1. Asks which optional modules apply to your project (analytics, observability, GSC, ads, Coolify, architecture review, docs audit, design, mailbox)
2. Creates `docs/` folder structure with template files
3. Writes `.darkflow.d/claude.md` with the Dark Flow agent workflow and adds a single `@.darkflow.d/claude.md` reference to `CLAUDE.md`
4. Installs `/darkflow` and `/darkflow:*` slash commands for Claude Code
5. Creates (or updates) a `Makefile` with `df-*` shortcut targets
6. Verifies the installation against `checklist.yml` and auto-fixes any missing artifacts

---

## Web UI

Dark Flow ships a built-in web dashboard for reviewing and triaging tasks without leaving your terminal setup.

The webapp runs as a **host process** so it can launch host-side `cmux` + Claude
sessions straight from the UI (the "Fix in cmux" button on needs-human tasks).
Only Postgres runs in Docker.

**Start the server:**

```bash
# 1. Copy the env templates
cp .env.example .env
cp webapp/.env.example webapp/.env

# 2. Start Postgres (published on localhost:5432)
make up

# 3. Build and run the webapp on the host
make web          # http://localhost:5555
```

Open **http://localhost:5555** — you'll see all projects that have synced with the worker.

Prefer everything in Docker (no `cmux` launch button)? Run `make docker-up` →
the webapp comes up in a container on the same **http://localhost:5555**.

| Make target | What it does |
|---|---|
| `make up` | Start Postgres in the background |
| `make web` | Build & run the webapp on the host (port 5555) |
| `make docker-up` | Start Postgres + webapp in Docker (port 5555) |
| `make down` | Stop Docker services |
| `make logs` | Stream Docker logs (Ctrl-C to stop) |
| `make restart` | Restart Docker services |
| `make ps` | Show container status |
| `make db-shell` | Open psql inside the Postgres container |
| `make reload` | Load (first run) or restart (afterwards) webapp + worker under launchd — auto-restart, survives reboot |
| `make web-stop` / `worker-stop` | Stop one of the two launchd-supervised services |
| `make web-status` / `worker-status`, `make web-logs` / `worker-logs` | Check status / tail logs for one service |

Tasks live entirely in Dark Flow's own Postgres database — no external app or token is needed for Approve / Reject.

The worker registers projects automatically on first sync. No manual setup needed beyond starting Postgres.

---

## Structure installed

```
docs/
├── README.md               ← manifest of all files + reading order
├── agent-workflow.md        ← rules: when agent reads / writes each layer
├── tasks.md                 ← task field taxonomy + triage loop spec
│
├── state/                   ← HOW THINGS ARE RIGHT NOW — overwritten in place
│   ├── arch.md              ← system map: stack, modules, entry points
│   ├── hypotheses.md        ← bet → evidence → verdict ledger
│   ├── product/             ← what, why, for whom — quarterly
│   ├── spec/                ← flows, screens, data model — weekly
│   └── design/              ← tokens, components, assets — situational
│
├── logs/                    ← WHAT HAPPENED — appended, never rewritten
│   └── YYYY-MM-DD.md            ## Security, ## Analytics, ## Changes, …
│
├── insights/
│   └── qualitative/         ← interviews, feedback, recordings — source material
├── _archive/                ← superseded documents — one archive, never under state/
└── decisions/               ← ADRs (context → decision → verification) — as needed
    └── TEMPLATE.md
```

`state/` and `logs/` are the whole idea: a routine that *observes* something appends to
`logs/`; a routine that learns the system *changed* rewrites `state/`. Neither touches the
other's ground, so neither can quietly overwrite the other's work.

Re-running `install.sh` on a project laid out by an older version brings it forward: the old
top-level `spec/` · `product/` · `design/` move under `state/`, the old per-routine snapshot
folders move to `_archive/`, and metrics files no routine writes any more are deleted. Documents
are only ever **moved** — `git status` shows every one of them before you commit.

---

## The triage loop

```
Agent runs an audit → appends to docs/logs/YYYY-MM-DD.md
  → creates task with status=proposed
Human reviews
  → sets status=approved or status=rejected
Agent starts next session
  → ~/.darkflow/df task list --status approved --state open
  → picks up matching tasks
  → sets status=in-progress, comments with branch name
  → closes after landing the fix (direct commit to the base branch by default, or PR referencing "Task #N" if PR mode is enabled)
```

Some categories skip the human review step — security fixes, Dependabot dependency updates, and additive database index additions are created directly as `status=approved` and flow straight to `fix-issues`. See [`docs/auto-approve.md`](./docs/auto-approve.md) for the full allowlist.

The loop runs automatically — see [Routines](#routines-automated-agents) below.

---

## Routines (automated agents)

The real power comes from scheduling Claude agents that run the loop automatically. Dark Flow ships a **self-hosted dispatcher** — no Claude Code Routines UI required.

**Which routines exist, whether they're on, and on what schedule — all of that lives in
the Web UI** (Settings → Routine schedule), per project. Defaults come from the catalog
in [`webapp/src/lib/routines.ts`](./webapp/src/lib/routines.ts); each routine's prompt is
its command file in [`templates/.claude/commands/darkflow/`](./templates/.claude/commands/darkflow).
There is deliberately no table here — a hand-written one goes stale the moment a schedule
changes in the UI, which is exactly what happened to the one this replaced.

The one routine with no command file is [**ci-watch**](./docs/ci-watch.md): pure bash
inside the worker, no agent and no token cost.

Cron times are in the machine's local timezone.

### Running routines

A **single global worker** (`~/.darkflow/darkflow-run.sh`) services every project on
the machine. You start it manually (no auto-start), and it runs until you stop it:

```bash
nohup bash ~/.darkflow/darkflow-run.sh >/dev/null 2>> ~/.darkflow/worker.err.log &   # start
pkill -f ~/.darkflow/darkflow-run.sh                                       # stop
```

It discovers projects from the web UI (each project's **Local path**), so a project
appears once it has synced.

Run routines manually at any time (from inside the project directory):

```bash
~/.darkflow/darkflow-run.sh fix-issues      # run one routine now (cwd's project)
~/.darkflow/darkflow-run.sh --list           # show status table (cwd's project)
~/.darkflow/darkflow-run.sh --dry-run        # preview what's due (cwd's project)
```

See [`docs/agent-workflow.md`](./docs/agent-workflow.md) for how a routine run is put together.

### Makefile shortcuts

The installer creates (or updates) a `Makefile` with `df-*` targets so you don't have to remember the full command paths:

```bash
make df-help                          # list all df-* targets
make df-run                           # start the dispatcher loop (every 60s)
make df-sync                          # push tasks + project metadata to the web UI
```

If your project already has a `Makefile`, the installer appends the `df-*` block between `# darkflow:start` / `# darkflow:end` markers — your existing targets are untouched. Running `install.sh` again regenerates only that block.

### How the loop fits together

```
Daily
  8:00  analytics-review     → proposed tasks + analytics snapshot → syncs to web UI
  8:30  observability-check  → proposed tasks
  9:00  coolify-check-deployment → deploy status, critical task on failure
  */4h  uptime-check         → DNS + HTTP + page-load; site down → status=approved critical task

Weekly
  Mon 8:00  gsc-check (GSC + SEO) → proposed tasks
  Mon 8:00  ads-review            → proposed tasks + ads snapshot (optional)
  Sun 2:00  architecture-review   → proposed tasks (Opus) + arch snapshot → syncs to web UI
  Sun 3:00  security-audit        → GitHub alerts + code review → auto-approved tasks (Opus) → syncs to web UI
  Sun 4:00  build-optimization    → proposed tasks (Opus) + build snapshot
  Sat 10:00 check-design          → visual quality, UI perf, production readiness (optional)
  Sat 11:00 check-ux              → key flows walked in a real browser, mobile + desktop (optional)

Continuous
  :00   fix-issues (hourly)       → picks up an approved task → implements → commits directly (PR mode optional)

Human
       Reviews proposed tasks in web UI (localhost:5555) → Approve / Reject
       or: ~/.darkflow/df task set-status N approved
```

These are the defaults. The real schedule is per project, in the Web UI.

### Setup checklist

- [ ] Run `install.sh`
- [ ] Verify `gh auth status` works in the project folder (only needed for `security-audit`'s GitHub alert reads, and for `gh pr create` if a project opts into PR mode)
- [ ] Configure required MCP servers (see each routine's page for details)
- [ ] Run `~/.darkflow/darkflow-run.sh --dry-run` from the project to confirm the worker works

---

## Slash commands

All `/darkflow:*` commands are installed automatically and available inside Claude Code.

### Workflow commands

| Command | What it does |
|---|---|
| `/darkflow` | Health check: docs structure, task fields, approved queue |
| `/darkflow:add-issue [title]` | Create a task for a manually identified item |
| `/darkflow:update` | Update Dark Flow to the latest version |
| `/darkflow:install` | Re-run the Dark Flow installer |

### Routine commands

| Command | What it does |
|---|---|
| `/darkflow:fix-issues` | Pick up one approved task, implement, close |
| `/darkflow:analytics-review` | OpenPanel + commits → tasks + analytics snapshot |
| `/darkflow:observability-check` | Errors / slow queries / latency → tasks |
| `/darkflow:gsc-check` | Google Search Console + technical/on-page SEO audit → tasks |
| `/darkflow:coolify-check-deployment` | Deployment status check → `critical` task on failed deploy |
| `/darkflow:architecture-review` | Module boundaries + fallow code health → tasks + architecture snapshot |
| `/darkflow:security-audit` | GitHub alerts (Dependabot, code + secret scanning) + code review → tasks + security snapshot |
| `/darkflow:build-optimization` | Build + deploy pipeline analysis → optimization tasks |
| `/darkflow:uptime-check` | DNS + HTTP + page-load check → **auto-approved** `critical` task if the site is down |
| `/darkflow:check-design` | Visual quality, UI performance, production readiness → tasks *(optional)* |
| `/darkflow:check-ux` | Key flows walked in a real browser, mobile + desktop → tasks *(optional)* |

Routine commands automatically call `bash ~/.darkflow/get-config.sh` before running — this fetches the latest project settings (branch, language, merge strategy, modules, routine schedule) from the **Web UI Settings tab** into `.darkflow.d/state/config.json`. If the server is unreachable, commands fall back to the last fetched copy silently.

**To edit project settings:** open the Web UI → project detail → **Settings** tab. Changes take effect the next time a routine or command runs. The database is the single source of truth — projects no longer carry a `.darkflow` config file.

---

## Updating Dark Flow

Run the same install command — it detects your installed version and updates automatically:

```
Update Dark Flow in this project:
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh

After updating, commit the changes.
```

The installer:
1. Compares your installed version (from `.darkflow`) against the latest and shows the changelog
2. Smart-updates template files: skips unchanged, warns + shows diff if locally modified
3. Regenerates `.darkflow.d/claude.md` (Dark Flow instructions for Claude)
4. Regenerates the `df-*` block in `Makefile` between `# darkflow:start/end` markers
5. Bumps the version in `.darkflow`
6. Runs the built-in checklist against the latest `checklist.yml` — interactively restores any missing artifacts

If already on the latest version, the installer exits immediately with "Already up to date." Use `--force` to re-apply all templates regardless.

### Repairing a partial install

If something is missing or broken, run the installer with `--force`:

```bash
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh --force
```

The installer verifies every artifact defined in `checklist.yml` and auto-fixes what's missing.

---

## Customization

After install, edit:
- `docs/agent-workflow.md` — add project-specific read/write rules
- `docs/tasks.md` — adjust the task field taxonomy if needed

---

## Requirements

- `git` — any version
- `gh` (GitHub CLI) — for `security-audit`'s Dependabot/code-scanning/secret-scanning alert reads, and for `gh pr create` if a project opts into PR mode; [install](https://cli.github.com/)
- `yq` — YAML parser used by the routine dispatcher; `brew install yq` / [install](https://github.com/mikefarah/yq#install)
- `python3` — used by the routine dispatcher to isolate process groups and clean up dev servers after each run
- Claude Code — the workflow is designed around it, but works with any AI agent that follows markdown instructions
