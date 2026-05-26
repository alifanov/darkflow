# Dark Flow

**A workflow layer for AI-assisted development** — structured docs, a GitHub Issues triage loop, and an installer that sets it all up in minutes.

---

## What problem does this solve?

When Claude Code (or any AI agent) works on your project, it generates insights and recommendations — but they evaporate between sessions. There's no handoff from "observation" to "approved task" to "merged PR."

Dark Flow installs:
- A **5-layer docs structure** (`product / spec / design / insights / decisions`) with clear read/write rules for the agent
- A **GitHub Issues triage loop** — agent creates `status:proposed` issues from insights, human approves or rejects, agent picks up `status:approved` tasks automatically
- A **taxonomy of labels** (`status:*`, `source:*`, `priority:*`, `effort:*`) so you can filter with `gh issue list --label "status:approved"`
- **Agent-workflow rules** baked into `docs/agent-workflow.md` (referenced from CLAUDE.md)

---

## Install

Open Claude Code in your project directory and paste this message:

```
Install Dark Flow workflow from https://github.com/alifanov/darkflow

Run the installer:
curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh

Ask me which optional modules I want (analytics, observability, GSC, ads, Coolify, CLAUDE.md update),
then run the installer with the appropriate flags.
After install, show me the routines I need to set up in Claude Code → Routines.
```

The agent will fetch the installer, ask about your stack, run it with the right flags, and walk you through setting up Routines.

### What the installer does

1. Asks which optional modules apply to your project (analytics, observability, GSC, ads, Coolify, CLAUDE.md update, architecture review)
2. Creates `docs/` folder structure with template files
3. Creates `.github/ISSUE_TEMPLATE/recommendation.yml`
4. Sets up GitHub issue labels via `gh` (if authenticated)
5. Writes `.darkflow.d/claude.md` with the Dark Flow agent workflow and adds a single `@.darkflow.d/claude.md` reference to `CLAUDE.md`
6. Installs `/darkflow` and `/darkflow:*` slash commands for Claude Code
7. Creates (or updates) a `Makefile` with `df-*` shortcut targets
8. Verifies the installation against `checklist.yml` and auto-fixes any missing artifacts

---

## Web UI

Dark Flow ships a built-in web dashboard for reviewing and triaging GitHub issues without leaving your terminal setup.

**Start the server:**

```bash
# 1. Copy the env template and fill in your GitHub App credentials
cp .env.example .env

# 2. Start Postgres + webapp
make up          # docker compose up -d
```

Open **http://localhost:5555** — you'll see all projects that have synced with the worker.

| Make target | What it does |
|---|---|
| `make up` | Start services in the background |
| `make down` | Stop all services |
| `make build` | Rebuild the webapp image |
| `make logs` | Stream logs (Ctrl-C to stop) |
| `make restart` | Restart all services |
| `make ps` | Show container status |
| `make db-shell` | Open psql inside the Postgres container |

**GitHub App setup** (one-time, required for Approve / Reject):

1. Go to **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**
2. Grant **Issues: Read & Write** permission, no webhook needed
3. Install the App on your repositories
4. Copy **App ID** and generate a **Private key** → paste into `.env`

The worker registers projects automatically on first sync. No manual setup needed once the App is configured.

---

## Structure installed

```
docs/
├── README.md               ← manifest of all files + reading order
├── agent-workflow.md        ← rules: when agent reads / writes each layer
├── github-issues.md         ← labels taxonomy + triage loop spec
├── product/                 ← business layer (what, why, for whom) — quarterly
├── spec/                    ← product/UX layer (flows, screens, data model) — weekly
├── design/                  ← visual identity, tokens, patterns — situational
├── insights/                ← time-stamped snapshots (analytics, GSC, ads) — daily
│   ├── analytics/
│   ├── search-console/
│   ├── ads/
│   └── qualitative/
└── decisions/               ← ADRs (context → decision → verification) — as needed
    └── TEMPLATE.md
```

---

## The triage loop

```
Agent analyzes insights/* 
  → creates issue with status:proposed
Human reviews
  → sets status:approved or status:rejected
Agent starts next session
  → gh issue list --label "status:approved"
  → picks up matching tasks
  → sets status:in-progress, comments with branch name
  → closes via PR with "Closes #N"
```

The loop runs automatically via **Claude Code Routines** — see [routines/README.md](./routines/README.md).

---

## Routines (automated agents)

The real power comes from scheduling Claude agents that run the loop automatically. Dark Flow ships a **self-hosted dispatcher** — no Claude Code Routines UI required.

| Routine | Cron | What it does |
|---|---|---|
| [**Fix issues**](routines/fix-issues.md) | `*/15 * * * *` | Every 15 min — picks up `status:approved` → PR → merge |
| [Analytics review](routines/analytics-review.md) | `0 8 * * *` | Daily 8:00 — PostHog + commits → `status:proposed` issues |
| [Observability check](routines/observability-check.md) | `30 8 * * *` | Daily 8:30 — SigNoz/errors/slow URLs → issues |
| [GSC check](routines/gsc-check.md) | `0 8 * * 1` | Weekly Mon 8:00 — Google Search Console → issues |
| [Coolify logs](routines/coolify-logs.md) | `0 9 * * *` | Daily 9:00 — deployment logs → fixes errors → verifies |
| [CLAUDE.md update](routines/claude-md-update.md) | `0 9 * * 1-5` | Weekdays 9:00 — re-generates CLAUDE.md from codebase |
| [Architecture review](routines/architecture-review.md) | `0 2 * * 0` | Weekly Sun 2:00 — `/improve-codebase-architecture` → issues |
| [Security audit](routines/security-audit.md) | `0 3 * * 0` | Weekly Sun 3:00 — full security review → issues |
| [Vulnerability check](routines/vulnerability-check.md) | `0 6 * * *` | Daily 6:00 — GitHub Dependabot + code/secret scanning alerts → issues |
| [Mailbox check](routines/mailbox-check.md) | `0 * * * *` | Hourly — IMAP inbox → issues; approved `action:reply` issues → SMTP reply *(optional)* |
| [**Deployment failure fix**](routines/deployment-failure.md) | *(manual/webhook)* | Diagnoses → fixes → redeploys on failure |

Cron times are in the machine's local timezone. Schedule is defined in `.darkflow.d/routines.yml` — edit it to change frequency, model, or enable/disable a routine.

### Running routines

Run routines manually at any time:

```bash
bash .darkflow.d/darkflow-run.sh fix-issues      # run one routine now
bash .darkflow.d/darkflow-run.sh --list           # show status table
bash .darkflow.d/darkflow-run.sh --dry-run        # preview what's due
```

See [routines/README.md](./routines/README.md) for full dispatcher docs.

### Makefile shortcuts

The installer creates (or updates) a `Makefile` with `df-*` targets so you don't have to remember the full command paths:

```bash
make df-help                          # list all df-* targets
make df-run                           # start the dispatcher loop (every 60s)
make df-sync                          # push GitHub issues + project metadata to the web UI
```

If your project already has a `Makefile`, the installer appends the `df-*` block between `# darkflow:start` / `# darkflow:end` markers — your existing targets are untouched. Running `install.sh` or `update.sh` again regenerates only that block.

### How the loop fits together

```
Daily
  6:00  vulnerability-check  → status:proposed issues from GitHub Dependabot / code / secret scanning
  8:00  analytics-review     → status:proposed issues + analytics snapshot → syncs to web UI
  8:30  observability-check  → status:proposed issues
  9:00  coolify-logs         → verifies deploy, fixes errors
  9:00  claude-md-update     → keeps agent context in sync

On-demand
  deployment-failure         → diagnoses → fixes → redeploys

Weekly
  Mon 8:00  gsc-check             → status:proposed issues
  Sun 2:00  architecture-review   → status:proposed issues (Opus) + arch snapshot → syncs to web UI
  Sun 3:00  security-audit        → status:proposed issues (Opus) + security snapshot → syncs to web UI

Continuous
  :00/:15/:30/:45  fix-issues (every 15 min)   → picks up status:approved → PR → merge

Human
       Reviews status:proposed in web UI (localhost:5555) → Approve / Reject
       or: gh issue edit N --add-label status:approved
```

### Setup checklist

- [ ] Run `install.sh`
- [ ] Verify `gh auth status` works in the project folder
- [ ] Configure required MCP servers (see each routine's page for details)
- [ ] Run `bash .darkflow.d/darkflow-run.sh --dry-run` to confirm the dispatcher works

---

## Slash commands

All `/darkflow:*` commands are installed automatically and available inside Claude Code.

### Workflow commands

| Command | What it does |
|---|---|
| `/darkflow` | Health check: docs structure, labels, approved queue |
| `/darkflow:add-issue [title]` | Create a GitHub issue for a manually identified task |
| `/darkflow:update` | Update Dark Flow to the latest version |
| `/darkflow:install` | Re-run the Dark Flow installer |

### Routine commands

| Command | What it does |
|---|---|
| `/darkflow:fix-issues` | Pick up one `status:approved` issue, implement, close |
| `/darkflow:analytics-review` | PostHog + commits → GitHub issues + analytics snapshot |
| `/darkflow:observability-check` | Errors / slow queries / latency → GitHub issues |
| `/darkflow:gsc-check` | Google Search Console → GitHub issues |
| `/darkflow:coolify-logs` | Deployment log monitoring → fix errors |
| `/darkflow:deployment-failure` | Diagnose and fix a failed deployment |
| `/darkflow:claude-md-update` | Regenerate CLAUDE.md from codebase |
| `/darkflow:architecture-review` | Architectural analysis → GitHub issues + architecture snapshot |
| `/darkflow:security-audit` | Full security review (static + runtime) → GitHub issues + security snapshot |
| `/darkflow:vulnerability-check` | GitHub Dependabot + code/secret scanning alerts → GitHub issues |

Routine commands read `language=`, `branch=`, and `merge_strategy=` from `.darkflow` automatically — no configuration needed at invocation time. They can also be run interactively at any time, not just on a schedule.

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
3. Re-runs label setup (additive — never removes existing labels)
4. Regenerates `.darkflow.d/claude.md` (Dark Flow instructions for Claude)
5. Regenerates the `df-*` block in `Makefile` between `# darkflow:start/end` markers
6. Bumps the version in `.darkflow`
7. Runs the built-in checklist against the latest `checklist.yml` — interactively restores any missing artifacts

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
- `docs/github-issues.md` — adjust the label taxonomy if needed
- `.github/ISSUE_TEMPLATE/recommendation.yml` — adjust dropdown options

---

## Requirements

- `git` — any version
- `gh` (GitHub CLI) — for label setup and issue management; [install](https://cli.github.com/)
- `yq` — YAML parser used by the routine dispatcher; `brew install yq` / [install](https://github.com/mikefarah/yq#install)
- `python3` — used by the routine dispatcher to isolate process groups and clean up dev servers after each run
- Claude Code — the workflow is designed around it, but works with any AI agent that follows markdown instructions
