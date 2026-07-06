# CLAUDE.md — Dark Flow

Dark Flow is a workflow installer for AI-assisted development projects.

> **Never start, restart, or relaunch the global worker yourself — always ask the user to do it from their own terminal.** The worker's `claude`/`codex` engine authenticates from the user's interactive/login session (keychain / env credentials that a Claude Code session does **not** have). A worker you launch inherits your credential-less environment, so every routine fails with `Not logged in · Please run /login` until the user relaunches it themselves. This holds even for `launchctl bootstrap`/`kickstart` — loading a launchd agent still needs to happen from the user's own session for keychain access to work. A running worker also holds the old script in memory, so after a self-update tell the user to restart it:
> ```bash
> # the USER runs this in their own terminal:
> make reload           # loads (first run) or restarts (afterwards) web + worker under launchd
> # or, if the worker is still a bare background process (pre-launchd):
> pkill -f ~/.darkflow/darkflow-run.sh
> nohup /usr/local/bin/bash ~/.darkflow/darkflow-run.sh >/dev/null 2>> ~/.darkflow/worker.err.log &
> ```
> Stopping/killing the worker on request is fine (no credentials needed). Starting or restarting it is always the user's action — do not run it for them, not even in the background, not even when explicitly asked to "restart it"; instead, print the command above and ask them to run it.

## What's in this repo

```
install.sh              ← main installer (copies templates, sets up labels)
update.sh               ← upgrader
setup-labels.sh         ← standalone GitHub labels setup
docker-compose.yml      ← runs the web UI + Postgres database
checklist.yml           ← issue acceptance checklist used by darkflow-run.sh
docs/                   ← project documentation
routines/               ← scheduled routines run by the worker
webapp/                 ← Next.js web app (projects list, issue triage, approve/reject)
  prisma/               ← database schema and migrations (Postgres via Prisma)
  src/app/              ← App Router pages and API routes
  src/components/       ← shared React components (ProjectRow, LogRow, etc.)
  src/lib/              ← prisma client, darkflow-version helper
templates/
  darkflow/             ← global worker + helpers (darkflow-run.sh, get-config.sh, mailbox/ → ~/.darkflow/)
  docs/                 ← generic docs structure templates
  .github/              ← GitHub issue template (darkflow/recommendation.yml)
  .claude/commands/     ← slash commands installed into user scope (~/.claude/commands/darkflow/)
README.md               ← user-facing documentation
VERSION                 ← semver, bumped on every release
```

## Running locally

Copy `.env.example` to `.env` before first run.

The webapp now runs as a **host process** (not in Docker) so it can launch host-side
`cmux` + Claude sessions from the UI. Only Postgres runs in Docker:

```bash
docker compose up -d        # starts Postgres only (port 5432 published to host)
cd webapp && pnpm install
pnpm build && PORT=5555 pnpm start   # UI at http://localhost:5555 (reads DATABASE_URL → localhost:5432)
```

The webapp reads `DATABASE_URL` from `webapp/.env` (defaults to
`postgresql://darkflow:darkflow@localhost:5432/darkflow`).

To run the webapp in Docker anyway (no `cmux` launch button), use the `docker` profile:

```bash
docker compose --profile docker up -d   # webapp at http://localhost:5555
```

### Make targets (shorthand for docker compose)

```bash
make up          # = docker compose up -d
make down        # stop all services
make logs        # tail all logs
make db-shell    # open psql shell in Postgres container
make help        # list all targets
```

For webapp development (hot reload):
```bash
cd webapp
pnpm install
pnpm dev                    # http://localhost:3000
```

### Database / Prisma

```bash
cd webapp
pnpm exec prisma migrate dev --name <description>   # create + apply migration
pnpm exec prisma studio                              # visual DB browser
```

Migrations live in `webapp/prisma/migrations/`. Never delete or truncate data — always ask before destructive migrations.

## Deploying webapp changes

The webapp runs on the host, so after any change to files under `webapp/` rebuild and
restart the host process:

```bash
cd webapp && pnpm build && PORT=5555 pnpm start
```

(If you run the webapp via the `docker` profile instead, use
`docker compose --profile docker up -d --build`.)

## Working on this repo

When improving the workflow templates, edit files in `templates/docs/` — those are what gets installed into other projects.

When the installer logic changes, test it locally:
```bash
mkdir /tmp/test-project && cd /tmp/test-project && git init
bash /path/to/darkflow/install.sh --name "Test Project" --no-labels
```

After changes, always verify the install script runs end-to-end without errors.

**After every task — mandatory steps (in order):**
1. Bump `VERSION` (patch for fixes/copy, minor for new features or template changes, major for breaking installer changes)
2. Add a `CHANGELOG.md` entry under a new `## [X.Y.Z] — YYYY-MM-DD` heading
3. Commit and push everything (VERSION, CHANGELOG.md, and all changed files) in one go

Never skip the version bump — the install one-liner fetches raw files from `main`, so the version must always reflect the current state.

## Releases

No build process — just commit and push. The install one-liner fetches from `main` branch raw files via GitHub CDN.

After every change, bump the version in `VERSION` (semver: patch for fixes/copy, minor for new features or template changes, major for breaking installer changes).

@.darkflow.d/claude.md
