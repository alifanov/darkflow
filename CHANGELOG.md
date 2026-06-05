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

## [2.46.0] — 2026-06-05

- **Removed routine** — dropped `coolify-check-logs` (and its `/darkflow:coolify-check-deployment` companion command stays). When SigNoz (or any observability tool) collects container stdout/stderr through its logs pipeline, the per-container `docker logs` over SSH was redundant — application errors, crashes, and OOM signals already land in the observability tool. Reading raw container logs over SSH added a fragile permission gate and SSH-key requirement for data we already have.
- **Removed command** — deleted the `templates/.claude/commands/darkflow/coolify-check-logs.md` template and the `coolify_ssh=` project setting it relied on (the SSH config lived only inside this command/routine; no installer or web-UI field collected it).
- **Installer** — removed the `coolify-check-logs` command copy, its `routines.yml` block, the post-install summary lines, and the `checklist.yml` `cmd-`/`routine-` manifest items. The Coolify module now installs a single daily routine (`coolify-check-deployment`).
- **Web UI** — removed the `coolify-check-logs` entry from the project settings routine list.
- **Docs** — README, `routines/README.md`, `coolify-check-deployment.md`, and `build-optimization.md` updated to drop all `coolify-check-logs` references.

---

## [2.45.0] — 2026-06-05

- **Updated template** — Split the single **Language** setting into two explicit buckets to stop agents from writing the communication language into the product. `.darkflow.d/claude.md` now states a **Communication language** (the configured language — for GitHub issues, comments, commits, PR descriptions, and chat only) and a **Product language** (always English — all source code, identifiers, code comments, UI copy, user-facing strings, logs, and in-product docs stay in English regardless of the communication language).
- **Updated template** — `fix-issues` command now explicitly reminds the agent that product code/strings are always English even when `language=` is set to something else.
- **Updated installer** — Reworded the interactive language prompt and `--lang` help text to "Communication language", clarifying the product itself stays English.
- **Web UI** — Project settings field relabeled "Communication language" with a hint that the product always stays English.

---

## [2.44.0] — 2026-06-05

### Updated label: priority taxonomy renamed to words

- Renamed the four priority labels from the numeric `p0`/`p1`/`p2`/`p3` scheme to words, keeping the same colors:
  - `priority:p0` → `priority:critical` (`#b60205`)
  - `priority:p1` → `priority:high` (`#d93f0b`)
  - `priority:p2` → `priority:medium` (`#fbca04`)
  - `priority:p3` → `priority:low` (`#cccccc`)
- Updated `install.sh` label definitions and the `gh label create` setup snippets in `docs/github-issues.md` (and the template copy).

### Workflow: routines no longer file `low`-priority issues

- All routines and slash commands now create GitHub issues **only for `critical` / `high` / `medium`**. `low`-priority findings are recorded in the run snapshot (`docs/insights/*`) instead of being opened as issues.
- The `priority:low` label remains valid for manually created issues (`/darkflow:add-issue`); only the automated routines skip it.
- Updated every issue-creating command template (`security-audit`, `vulnerability-check`, `observability-check`, `ads-review`, `design-audit`/`critique`/`harden`, `docs-audit`, `ux-audit`, `build-optimization`, `coolify-check-deployment`/`logs`, `mailbox-check`, `fix-issues`, `add-issue`) and the matching routine reference docs.
- `criticalOpen` metric counters now match on `priority:critical` / `priority:high`.

### Web UI

- `PRIORITY_ORDER` in the project issues view now sorts `critical → high → medium → low` (previously only `high/medium/low`, which left `critical`/legacy values unsorted).

---

## [2.43.0] — 2026-06-04

### Feature: Centralized project settings in the Web UI

**DB is now the source of truth for project settings.** The `.darkflow` file becomes a local cache; all settings are editable from the Web UI and fetched by the worker/commands before each run.

#### Web UI (webapp)
- **New Settings tab** on the project detail page — edit all project settings in one place: name, slug, branch, language, merge strategy, modules (checkboxes), integrations (PostHog, observability), max concurrent routines, and per-routine schedule (enabled, model, cron)
- **New `GET /api/projects/by-repo?repoUrl=...`** endpoint — returns the full settings+routines snapshot for a given project; used by `get-config.sh`
- **New `PATCH /api/projects/[id]`** endpoint — saves settings and routine configs from the UI
- **`POST /api/ingest`** no longer overwrites settings fields (`branch`, `language`, `mergeStrategy`, `modules`) on update — only seeds them on first project creation. Routine configs are also seeded once and then managed exclusively by the UI
- **New DB columns** on `Project`: `slug`, `maxConcurrent` (default 3), `posthogProjectId`, `obsTool`, `obsUrl`, `settingsUpdatedAt`

#### Worker + commands
- **New `templates/darkflow/get-config.sh`** (installed to `.darkflow.d/get-config.sh`) — fetches latest settings from the Web UI and refreshes `.darkflow` + `routines.yml`; silently no-ops if the server is unreachable
- **`darkflow-run.sh`** calls `get-config.sh` before every routine so the worker always uses fresh settings
- **All 21 slash commands** now run `get-config.sh` as the first action in "Step 1 — Read project config", ensuring they always see the latest DB-backed settings

#### Installer
- `install.sh` copies `get-config.sh` alongside `darkflow-run.sh`
- `.darkflow` now includes `max_concurrent=3` on fresh installs
- `checklist.yml` includes `dispatcher-get-config` and `cfg-max-concurrent` checks so existing projects pick up `get-config.sh` on `darkflow:update`

---

## [2.42.0] — 2026-06-04

### Updated commands
- **fix-issues** — added Step 5 (update docs before merging when fix changes user-visible behavior) and expanded the closing issue comment to include a brief summary of what was changed and which files were updated

---

## [2.41.4] — 2026-06-04

### Updated commands
- **language support** — `add-issue`, `claude-md-update`, `coolify-check-deployment`, `coolify-check-logs`, `install`, `self-update` now all read `language=` from `.darkflow` and use it for all output and GitHub issues
- **coolify-check-logs** — fixed hardcoded Russian SSH permission question; now uses `language=` like all other commands

---

## [2.41.2] — 2026-06-03

### Webapp
- **"+ Task" button** — issue rows in the *Needs approval* list and the *Needs Human* section now have a `+ Task` button in the Actions column; clicking opens `https://flow.chatindex.app/tasks?title=<issue title>` in a new tab, pre-filling the task manager with the issue title

---

## [2.41.1] — 2026-06-03

### Updated routine
- **design-audit** — added `impeccable:optimize` as Step 3 (UI performance: LCP, CLS, bundle size); perf findings get `area:performance` label; snapshot now covers both quality and performance dimensions

---

## [2.41.0] — 2026-06-03

### New routine
- **design-audit** — weekly (Sat 10:00, opus) design quality check via `impeccable:audit`; five-dimension technical review with P0–P3 severity findings → `source:design` GitHub issues + `insights/design-audit/` snapshot
- **design-critique** — weekly (Sat 11:00, opus) scored design review via `impeccable:critique`; persona tests + automated detection → `source:design` GitHub issues + `insights/design-critique/` snapshot
- **design-harden** — monthly (1st 10:00, opus) production-readiness review via `impeccable:harden`; edge cases, i18n, error states, overflow → `source:design` GitHub issues + `insights/design-harden/` snapshot

### New label
- **source:design** — `#5319e7` — "From design quality routines (impeccable:audit/critique/harden)"

### Workflow
- Added `design-audit`, `design-critique`, `design-harden` snapshot paths to data-sources routing table in `agent-workflow.md`

### Installer
- New `impeccable` module (`--with-impeccable` / `--no-impeccable`); all three routines are gated on this module
- `_module_active()` handles `impeccable` module key
- `checklist.yml` — added 3 `copy-template` entries and 3 `add-routine` entries for the new commands/routines

---

## [2.40.0] — 2026-06-03

### Workflow
- **Auto-approve allowlist** — new `docs/auto-approve.md` defines categories of issues that the agent creates directly as `status:approved`, bypassing the manual triage step. Seed list: security fixes (`/darkflow:security-audit`) and Dependabot dependency updates (`/darkflow:vulnerability-check`, `area:deps`). Code-scanning and secret-scanning findings still require human review. `fix-issues` retains its full quality gate (lint → test → build) and `needs-human` escalation regardless.
- **`github-issues.md`** updated: `status:approved` row notes that agents can set it directly for auto-approved categories; link to `auto-approve.md` added under the table.

### Updated routine
- **`security-audit`** — now creates issues as `status:approved` (was `status:proposed`). Findings go straight to the fix queue.
- **`vulnerability-check`** — Dependabot `area:deps` issues now created as `status:approved`; `area:code` and `area:secrets` remain `status:proposed`.

### Installer
- `docs/auto-approve.md` added to `smart_update_template` install list and to the `@`-include chain in `.darkflow.d/claude.md`.
- `checklist.yml`: added `file-auto-approve` copy-template entry (existing installs self-heal on next update) and `routine-vulnerability-check` add-routine entry (closes gap where existing installs never received the daily `vulnerability-check` routine via self-update).

---

## [2.39.0] — 2026-06-01

### New routine
- **`build-optimization`** — weekly Sunday 4:00 audit of the project's build and deploy pipeline. Maps the full toolchain (Docker, CI, bundler, package manager), finds bottlenecks and inefficiencies (layer ordering, missing caches, bloated images, redundant install steps), and creates `status:proposed` GitHub issues with measurable acceptance criteria. Proposal-only: does not apply changes; implementation goes through the standard approve → `fix-issues` path.

### New label
- **`source:build`** — added to `setup_labels` for issues created by the `build-optimization` routine.

### Installer
- `build-optimization` routine added to the always-on routines.yml block (cron `0 4 * * 0`, model opus), alongside `security-audit` and `vulnerability-check`.
- `smart_update_template` call added so the command template ships to all installed projects.
- Active Routines and Dark Flow command list in the generated `.darkflow.d/claude.md` now include `build-optimization`.

### Manifest
- `checklist.yml`: added `cmd-build-optimization` (copy-template) and `routine-build-optimization` (add-routine, cron `0 4 * * 0`) so existing installs catch the new command + routine on next `self-update`.

### Docs
- `README.md`: routine table, Weekly loop diagram, and routine commands table updated.
- `routines/build-optimization.md`: new routine reference page.
- `routines/README.md`: schedule table updated.
- `templates/docs/agent-workflow.md` + `docs/agent-workflow.md`: snapshot routing table updated with `insights/build-optimization/YYYY-MM-DD.md`.

## [2.38.0] — 2026-05-30

- **Installer** — anchor the `.claude/` gitignore rule to the repo root (`/.claude/`) so it only ignores the repo's own working dir, not `templates/.claude/`. All `/darkflow:*` command templates are now tracked in git and ship to installs (previously only the working copy had them, so remote/curl installs couldn't fetch most commands).

## [2.37.1] — 2026-05-30

- **Installer** — force-track the `coolify-check-logs` command template (it was caught by the `.claude/` gitignore rule), so the SSH-based per-container log workflow actually ships and can be fetched by remote installs.

## [2.37.0] — 2026-05-30

- **Updated routine** — `coolify-check-logs` now reads per-container logs over SSH (`docker logs`) instead of the `coolify` CLI, which cannot target a specific container. It requires explicit permission before opening any SSH connection: interactive runs ask the user and abort if denied; unattended runs need `coolify_ssh=` configured in `.darkflow` or they skip log fetching. The CLI is still used for app discovery.
- **Docs** — README and the `coolify-check-logs` routine doc updated for the SSH log workflow.

## [2.36.0] — 2026-05-30

### Renamed routine
- **`coolify-logs` split into `coolify-check-deployment` + `coolify-check-logs`** — the single combined command did both deployment-status checking and log review under a name that only hinted at logs. It is now two explicitly-named commands/routines:
  - **`/darkflow:coolify-check-deployment`** (`0 9 * * *`) — checks the deployment pipeline only; opens a `priority:p0` issue on a failed/red deploy.
  - **`/darkflow:coolify-check-logs`** (`30 9 * * *`) — reviews runtime logs only. **Now explicitly handles multi-container apps:** it first determines how many containers/replicas the app runs (`coolify app get`), raises `-n` so every container is represented in the log window, and scans the aggregated output per-container instead of stopping at the first one.
- **Fixed stale `checklist.yml` entries** — the manifest referenced a non-existent `coolify-check` command/routine; replaced with the two real `coolify-check-*` items.

### Removed routine
- **`deployment-failure`** — dropped the on-demand "diagnose → fix → redeploy" routine and its `/darkflow:deployment-failure` command template. Coolify deployment health is still covered by the passive `coolify-logs` routine, which surfaces failed deploys as `priority:p0` issues. Removed the command template, `routines/deployment-failure.md`, its `routines.yml` block (the only `MOD_COOLIFY`-gated routine entry), its `checklist.yml` manifest item, and all README / routine-doc references.

## [2.34.1] — 2026-05-30

### New routine
- **`docs-audit`** — weekly check that the `docs/` knowledge base still matches the code. Compares `spec/data-model.md`, `spec/screens/inventory.md`, `spec/flows/`, `product/metrics.md`, `design/components.md`, `product/pricing.md`, documented commands, and `decisions/` against the real codebase, then creates `status:proposed` / `source:docs` / `area:docs` issues for each significant drift. Writes `docs/insights/docs-audit/YYYY-MM-DD.md` + `.darkflow.d/state/metrics/docs-audit.json`. Cron Sun 5:00, model opus, opt-in.
- **`product-overview`** — weekly product digest consolidating current state, recent product + technical improvements, recent bugs/fixes, and tracked hypotheses into `docs/insights/product-overview/YYYY-MM-DD.md`. A narrative report for a human — creates no issues. Cron Mon 7:00, model opus, opt-in.

### Installer
- **Wired both into `install.sh` as opt-in modules** — new `MOD_DOCS_AUDIT` / `MOD_PRODUCT_OVERVIEW` flags (off by default; enable via `--with-docs-audit` / `--with-product-overview`, `--all`, or the interactive module menu). Command templates always copy; the routine entries (`docs-audit` `0 5 * * 0`, `product-overview` `0 7 * * 1`, both `opus`) are written to `routines.yml` only when the module is enabled.

### Manifest
- **Added `checklist.yml` entries** — command + routine items for both, so verify/repair (`darkflow-run.sh`, `/darkflow:install`) recognizes them and can self-heal a missing entry.

### Docs
- **Routine docs added** — `routines/docs-audit.md` and `routines/product-overview.md`; both added to the schedule table in `routines/README.md`.
- **Snapshot source table updated** — `templates/docs/agent-workflow.md` now lists the `insights/docs-audit/` and `insights/product-overview/` snapshot folders.

---

## [2.33.0] — 2026-05-30

### Updated routine
- **Coolify routines now use the `coolify` CLI instead of an MCP server** — the `coolify-logs` and `deployment-failure` command templates (`templates/.claude/commands/darkflow/`) now call the official `coolify` CLI (`coolify app list`, `coolify app deployments list`, `coolify deploy get`, `coolify app logs`, `coolify app get`) with concrete commands instead of abstract "check in Coolify" steps. Config lives at `~/.config/coolify/config.json`.

### Docs
- **Routine docs updated** — `routines/coolify-logs.md` and `routines/deployment-failure.md` now list the Coolify CLI as the required integration instead of `@alifanov/coolify-mcp` / a deployment-platform MCP.

---

## [2.22.3] — 2026-05-26

### Dispatcher
- **Routine/command consistency check in preflight** — on startup, `darkflow-run.sh` now verifies that every enabled routine in `routines.yml` has a matching command file at `.claude/commands/darkflow/<name>.md`. A mismatch prints a clear error and blocks the dispatcher from starting, preventing silent "routine defined but never executes" bugs.

### Webapp
- **Auto-expire stale `pendingStatus`** — optimistic UI states (approve/reject clicks) are now automatically cleared after 2 hours if the worker hasn't applied them to GitHub. Previously a crashed or paused worker could leave issues stuck in a phantom "pending" state indefinitely.

### Docs
- **Clarify VERSION mount in `docker-compose.yml`** — added inline comment explaining that the mounted `VERSION` file contains the darkflow release version used to flag outdated project installs, not the webapp's own version. Override via `DARKFLOW_LATEST_VERSION` env var if needed.

---

## [2.20.0] — 2026-05-25

### Workflow
- **Worker auto-updates Dark Flow** — on every `--once` invocation (and at startup + every 15 min in `mode_watch`) the worker fetches the latest `VERSION` from GitHub. If it differs from the installed version, it automatically runs `/darkflow:self-update` via Claude, which calls `install.sh --force --yes` non-interactively. In watch mode, the dispatcher reloads itself via `exec` after a successful update. Check is throttled to once per minute.

### New routine
- **`/darkflow:self-update`** — slash command that runs the Dark Flow installer in non-interactive mode and reports the result in one line. Invoked automatically by the worker; can also be called manually.

---

## [2.19.2] — 2026-05-25

### Installer
- **Download `install.sh` to `/tmp` before running** — replaces `bash <(curl ...)` process substitution with `curl ... -o /tmp/darkflow-install.sh && bash /tmp/darkflow-install.sh`. Avoids agent classifier blocks that flag process substitution as suspicious.

---

## [2.19.0] — 2026-05-25

### Installer
- **Prompt to remove stale Dark Flow commands after install/update** — `install.md` and `update.md` slash commands now include a cleanup step that checks for outdated slash commands left over from older versions and prompts the user to remove them.

---

## [2.18.0] — 2026-05-25

### Workflow
- **Markdown rendering in routine log output** — the log output field on the project page now renders Markdown (via `react-markdown`). Routine summaries with lists, headings, and inline code are displayed formatted instead of as raw text.

---

## [2.17.0] — 2026-05-25

### New routine
- **`mailbox-check`** — optional IMAP+SMTP integration. Reads unseen messages from the project inbox every hour and creates `status:proposed` GitHub issues tagged `source:mailbox`. Human chooses `action:reply` (agent sends email reply via SMTP after approve) or `action:fix` (issue flows through normal `fix-issues`). Credentials are saved to `.env.darkflow` (already git-ignored).

### New label
- **`source:mailbox`** — marks issues created from incoming email
- **`action:reply`** — approved mailbox issue where agent should send an email reply
- **`action:fix`** — approved mailbox issue where agent should make a code/product change

### Updated routine
- **`fix-issues`** — now skips issues with `action:reply` label (those are handled by `mailbox-check`)

### Installer
- New **Mailbox** module (`--mod-mailbox`): adds IMAP/SMTP credential prompts, writes to `.env.darkflow`, copies `fetch.py` / `send.py` to `.darkflow.d/mailbox/`

---

## [2.16.0] — 2026-05-25

### Workflow
- **Dark Flow version badge in project list** — each project card in the webapp now shows the installed Dark Flow version (e.g. `v2.16.0`). Badge is green when up to date, yellow with an upgrade arrow when behind. Worker sends `darkflowVersion` from `.darkflow` in both the ingest payload and heartbeat.

---

## [2.15.0] — 2026-05-25

### Workflow
- **Need Attention tab on project page** — worker reads `.darkflow.d/attention.json` (written by any routine or script) and syncs its entries to the webapp as alerts with key, title, severity, and details. The project page shows a new "Need Attention" tab with severity-coloured cards and a badge counter. Alerts whose keys disappear from `attention.json` on the next sync are automatically removed.

---

## [2.14.0] — 2026-05-25

### Installer
- **Single idempotent `install.sh`** — `update.sh`, `setup-labels.sh`, and `check.sh` have been merged into `install.sh`. Running `install.sh` on an existing project now auto-detects whether to update or verify (fresh install, update, or same-version quick exit). Old curl one-liners for `update.sh` / `setup-labels.sh` / `check.sh` are no longer valid — use `install.sh` for everything.
- **`--dry-run` flag** — preview all changes without writing anything (ported from `update.sh`).
- **`--force` skips the version check** — re-applies all templates even when already up to date.
- **CLAUDE.md is no longer rewritten** — Dark Flow instructions now live in `.darkflow.d/claude.md` (auto-updated on every install/update). `CLAUDE.md` only receives a single `@.darkflow.d/claude.md` include line, appended once if absent. User content in `CLAUDE.md` is never touched.
- **GitHub labels inlined** — `setup-labels.sh` logic is now inside `install.sh`; no external script fetch needed.
- **Verification inlined** — `check.sh` + `checklist.yml` logic is embedded in `install.sh` as `run_checklist()`. `checklist.yml` remains the declarative source of truth.

## [2.11.1] — 2026-05-24

### Installer
- **`make df-check-fix` now actually fixes missing marker blocks** — marker items (`CLAUDE.md` Dark Flow section, `Makefile` Dark Flow block) had no fix handler, so check.sh would just print "run: bash update.sh --force" and exit 1. Added an `update-force` handler that runs `update.sh --force` (local copy if available, otherwise fetched from the remote). Runs at most once per check.sh invocation even if both markers are missing.

## [2.11.0] — 2026-05-24

### Updated routine
- **`fix-issues` now picks the next issue strictly by priority** — replaced the vague "sorted by priority" instruction with an explicit walk through `priority:p0 → p1 → p2 → p3`, taking the oldest issue at the first non-empty level. Added a fallback for `status:approved` issues that have no priority label (treated as lowest). Included concrete `gh issue list` snippets so the agent doesn't have to invent the query.

## [2.10.3] — 2026-05-24

### Workflow
- **Worker-online detection is now purely cache-based** — reverted the `status="stopped"` shutdown signal from 2.10.2 (an extra protocol that didn't help with crashes). Instead, worker heartbeats every 30 s (was 60 s) and the web UI considers the worker offline after 75 s of silence (was 120 s). One missed beat is tolerated; two flips it offline. After Ctrl-C the UI now reflects offline within ~75 s on next page render. The watch loop's full sync cadence is unchanged (still ~5 min, now every 10th tick).

## [2.10.2] — 2026-05-24

### Workflow
- **Worker now marks itself offline immediately on Ctrl-C** — `darkflow-run.sh watch` sends a final heartbeat with `status="stopped"` when receiving SIGINT/SIGTERM, instead of leaving the UI to wait out the 2-minute liveness window. Web UI (`/` and `/projects/[id]`) treats `stopped` as offline regardless of timestamp freshness.

## [2.10.1] — 2026-05-24

### Installer
- **Fixed `make df-check` hanging silently** — removed the `mod-arch-review-skill` item from `checklist.yml` whose check (`npx --no-install skills list`) could hang on network. Also added a `▸ Fetching check.sh from darkflow/main...` progress echo so users see activity during the curl download

## [2.10.0] — 2026-05-24

### Removed label
- **Removed the `effort:*` label group** (`effort:xs/s/m/l`) — used in practice nowhere, just noise on every issue. `setup-labels.sh`, the recommendation issue template, the worker dispatcher (`darkflow-run.sh`), the docs (`github-issues.md`, `agent-workflow.md`, routine prompts), and the webapp `Issue.effort` column are all dropped. Migration `20260524110000_drop_issue_effort` removes the column from existing DBs

### Installer
- **`setup-labels.sh --prune-effort`** — optional flag that calls `gh label delete` for each `effort:*` label, since `setup-labels.sh` itself is additive and doesn't remove labels from existing repos

## [2.9.1] — 2026-05-24

### Installer
- **Fixed `make df-check` / `make df-check-fix` failing under `/bin/sh`** — replaced `bash <(curl …)` (bash-only process substitution) with `mktemp` + `curl -o` + `bash $tmp`. Also keeps stdin attached to the TTY so the `--fix` prompt works

## [2.9.0] — 2026-05-24

### Installer
- **New Makefile targets `df-check` and `df-check-fix`** — standalone way to run the verifier without going through `update.sh`. `df-check-fix` interactively restores any missing artifacts

## [2.8.1] — 2026-05-24

### Installer
- **Routine entries in `.darkflow.d/routines.yml` are now part of the checklist** (`type: routine`). When a new Dark Flow version introduces a new routine, old installs detect the gap via `check.sh` and interactive `--fix` adds the cron/model/enabled block via `yq -i`. Replaces the old non-actionable "New routines available" announcement in `update.sh`

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
