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
