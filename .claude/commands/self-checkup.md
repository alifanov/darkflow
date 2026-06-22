---
description: Audit Dark Flow itself — repo consistency, all installed projects, routine configs, leftover worktrees, logs, DB, GitHub labels — and emit recommendations grouped by priority
---

Run a full control-plane health audit of Dark Flow. You are running this **from the Dark
Flow repo** (`/Users/vampire/code/darkflow`) as the maintainer. This is NOT a per-project
command — it inspects this repo's own consistency AND every project registered in the
central Postgres database.

Do the eight audits below **in order**, collect findings as you go, then synthesize the
recommendations grouped by priority. **Print the whole report to the console — do not write
any file.**

**Язык вывода: весь отчёт и рекомендации печатай на русском языке.** Команды, SQL-запросы,
имена полей БД, имена лейблов (`status:approved` и т.п.) и пути к файлам оставляй как есть —
не переводи их. Переводи только пояснения, заголовки разделов, описания проблем и действия.

---

## Step 0 — Setup

- Read `DATABASE_URL` from `webapp/.env` (default
  `postgresql://darkflow:darkflow@localhost:5432/darkflow`). Run all DB queries with:
  ```bash
  psql "$DATABASE_URL" -At -c '<SQL>'
  ```
  If Postgres is unreachable, print a clear note and still run Step 1 (static, no DB) and
  Step 5 (GitHub via `gh`). Suggest `make up` to start Postgres.
- Read the current version from `VERSION` — this is the source of truth for "outdated".
- Confirm `gh auth status` works; if not, note that Step 5 will be skipped.

---

## Step 1 — Prompt ↔ settings consistency (this repo, static)

Cross-check that the repo's own pieces don't contradict each other. Report every mismatch.

- **Routines**: every routine in the catalog `webapp/src/lib/routines.ts` (`ALL_ROUTINES`)
  must have (a) a command template at `templates/.claude/commands/darkflow/<name>.md` and
  (b) a reference doc at `routines/<name>.md`. List any catalog routine missing either, and
  any command/doc with no catalog entry. (Schedule + per-project overrides live in the DB;
  there is no `routines.yml` anymore.)
- **Commands**: every command in `install.sh`'s `ALL_DF_COMMANDS` array must have an
  existing template at `templates/.claude/commands/darkflow/<name>.md`, and vice-versa.
  Flag any command listed with no template file, and any template with no array entry.
- **Labels**: grep the command templates and `routines/` docs for label references
  (`source:*`, `status:*`, `action:*`, `priority:*`, `needs-human`, `area:db`, `ci-retry`).
  Every referenced label must be created by a `_do_label` call in `install.sh`. The
  canonical set is:
  `action:fix, action:reply, area:db, ci-retry, needs-human, priority:critical,
  priority:high, priority:low, priority:medium, source:ads, source:build, source:ci,
  source:code-health, source:design, source:gsc, source:mailbox, source:manual,
  source:posthog, source:security-review, source:seo, source:signoz, source:uptime,
  source:user-feedback, status:approved, status:in-progress, status:proposed,
  status:rejected`.
  Flag labels referenced but never created, and labels created but referenced nowhere.
- **Modules**: the `_module_active()` case statement in `install.sh` must list every
  `MOD_*` module flag defined in the script (a known past gotcha — docs-audit and
  product-overview were once missing from it). Diff the two sets.
- **Version**: `VERSION` must equal the most recent `## [X.Y.Z]` heading in `CHANGELOG.md`.

---

## Step 2 — Install correctness across all registered projects (DB)

Query the `Project` table and, for each project, evaluate install health:

```bash
psql "$DATABASE_URL" -At -F$'\t' -c '
  SELECT p.name, p."repoUrl", p."lastSyncedAt", p.modules, p."localPath"
  FROM "Project" p
  ORDER BY p.name;'
```

For each row, classify:
- **Sync staleness**: `lastSyncedAt` older than 24h = stale; null = never synced (warning).
- **Modules sanity**: empty `modules` array, or values not recognized by `install.sh`.

Worker version + liveness are now **global** (one worker for all projects), stored on the
`Settings` row — check them once, not per project:

```bash
psql "$DATABASE_URL" -At -F$'\t' -c '
  SELECT "workerVersion", "workerLastSeen", "workerRoutine" FROM "Settings" WHERE id = '"'"'global'"'"';'
```
- **Version**: `workerVersion` vs `VERSION` → `missing` (null) / `outdated` (lower) / `current`.
  Outdated → run `install.sh --self-update`.
- **Worker liveness**: offline if `workerLastSeen` is older than **90 seconds** (matches
  `GlobalWorkerStatus.tsx`).

---

## Step 3 — Logs / runtime errors (DB `RoutineLog`)

Surface recent failing routine runs:

```bash
psql "$DATABASE_URL" -At -F$'\t' -c $'
  SELECT p.name, rl.routine, rl.model, rl.timestamp, rl.summary
  FROM "RoutineLog" rl
  JOIN "Project" p ON p.id = rl."projectId"
  WHERE rl.timestamp > now() - interval \'7 days\'
    AND (rl.summary ILIKE \'%error%\' OR rl.summary ILIKE \'%fail%\'
      OR rl.summary ILIKE \'%crash%\' OR rl.summary ILIKE \'%exception%\'
      OR rl.summary ILIKE \'%timeout%\' OR rl.output ILIKE \'%traceback%\')
  ORDER BY rl.timestamp DESC
  LIMIT 40;'
```

Group by project + routine. For repeated failures of the same routine, call it out as a
pattern (likely a systemic break, not a one-off).

---

## Step 4 — Database integrity

Run these checks:

- **Stuck approvals** — decisions the worker never synced back to GitHub:
  ```bash
  psql "$DATABASE_URL" -At -F$'\t' -c $'
    SELECT p.name, i.number, i.title, i."pendingStatus", i."pendingStatusAt"
    FROM "Issue" i JOIN "Project" p ON p.id = i."projectId"
    WHERE i."pendingStatus" IS NOT NULL
      AND i."pendingStatusAt" < now() - interval \'1 hour\'
    ORDER BY i."pendingStatusAt";'
  ```
- **Stale human review** — `Issue.needsHuman = true AND updatedAt < now() - interval '24 hours'`.
- **Alert buildup** — group `ProjectAlert` by `severity`; flag any `error`/`critical`:
  ```bash
  psql "$DATABASE_URL" -At -F$'\t' -c '
    SELECT p.name, pa.severity, count(*)
    FROM "ProjectAlert" pa JOIN "Project" p ON p.id = pa."projectId"
    GROUP BY p.name, pa.severity ORDER BY p.name;'
  ```
- **Dead registrations** — projects with zero issues, zero routine logs, and no worker
  heartbeat (likely an abandoned or misconfigured install).
- **Inactive repos** — newest `Commit.committedAt` older than 7 days.

---

## Step 5 — Leftover git worktrees across all projects (filesystem)

Dark Flow launches `cmux` + Claude sessions in **git worktrees**; each session's worktree
should be removed when it ends. Leftover worktrees accumulate disk, hold branch refs, and
usually signal a crashed or abandoned session. Audit every project that has a local checkout.

Reuse the `name` + `localPath` columns from Step 2's query. For each project:

- If `localPath` is **null** → note `нет localPath — проверка невозможна` and skip.
- If `localPath` does **not exist** on disk, or is not a git repo → note it and skip:
  ```bash
  [ -d "<localPath>/.git" ] || git -C "<localPath>" rev-parse --git-dir >/dev/null 2>&1
  ```
- Otherwise list worktrees (porcelain is stable for parsing) and the prunable ones:
  ```bash
  git -C "<localPath>" worktree list --porcelain
  git -C "<localPath>" worktree prune --dry-run --verbose
  ```

Classify, **excluding the main working tree** (the entry whose path equals `localPath`):

- **count** of leftover worktrees per project (0 = `✓ чисто`).
- For each leftover, report its **path**, **branch** (or `detached`), and short HEAD.
- **prunable** — listed by `worktree prune --dry-run` because its directory is already gone;
  these are safe to clear with `git -C "<localPath>" worktree prune`.
- **stale** — directory still present but its branch is already merged into `branch` (the
  project's default branch from the `Project` row), or its last commit is older than 7 days.
  Check merge status with:
  ```bash
  git -C "<localPath>" branch --merged "<branch>" | grep -F "<worktree-branch>"
  ```

For removable leftovers suggest the concrete cleanup command
(`git -C "<localPath>" worktree remove <path>` for a live dir, or `… worktree prune` for
gone dirs). Never run removals here — this command only reads and reports.

---

## Step 6 — GitHub issues & label problems (per repo, `gh`)

For each project's `repoUrl`, derive `owner/repo`, then with `gh`:

- **Label taxonomy**: `gh label list --repo <owner/repo> --limit 200 --json name -q '.[].name'`
  and diff against the canonical set from Step 1. **`--limit 200` is mandatory** — `gh label
  list` silently caps at 30 labels by default, so omitting it makes every repo look like it's
  missing `priority:*` / `needs-human` / `action:*` (false positives). Report **missing
  required labels** (Dark Flow routines depend on them) and note stray extras separately
  (lower priority).
- **Untriaged / stuck issues**:
  ```bash
  gh issue list --repo <owner/repo> --state open --json number,title,labels,updatedAt --limit 100
  ```
  Flag open issues with **no `status:*` label**, open issues missing any `source:*`, and
  issues that have been `status:approved` for a long time (pipeline stuck — worker not
  picking them up).
- **Conflicting labels**: any single issue carrying contradictory states (e.g.
  `status:approved` + `status:rejected`, or `status:proposed` + `status:in-progress`).
- **Invariant violation — approved must be actionable** (`high`): flag any open issue with
  `status:approved` AND (`needs-human` OR `status:blocked`). These are mutually exclusive by
  design — a park label silently drops the issue from the `fix-issues` queue, so it shows as
  "approved" in the UI yet never runs. Every write path is supposed to strip `status:approved`
  when adding a park label (and strip the park label on approve); a survivor means a path
  missed it. Fix per issue: `gh issue edit <n> --repo <owner/repo> --remove-label needs-human`
  (approve wins) **or** `--remove-label status:approved` (genuinely needs a human) — decide by
  whether a human still must act. (`status:approved` + `action:reply` is **not** a violation —
  those are mailbox-owned and handled by `mailbox-check`.)
- **Worker log ↔ queue mismatch** (`high`) — the symptom the maintainer asked to catch:
  the worker keeps logging that it has nothing to do while the queue actually has work. Read
  the global log `~/.darkflow/worker.log` and each project's `<localPath>/.darkflow.d/darkflow-run.log`
  (tail ~200 lines), and cross-check the **recent** entries against the live GitHub queue:
  - `SKIP fix-issues — no actionable status:approved issues` recurring **while** the repo has
    ≥1 open `status:approved` issue without `action:reply` → the issue is being parked
    invisibly (almost always the approved+needs-human invariant above). Name the issue #s.
  - `SKIP <path> — not a registered project or config fetch failed` recurring for a project
    that **is** in the `Project` table → config-fetch is flaky. Check the repo URL match: the
    worker looks the project up by `gh repo view --json url -q .url` against `Project.repoUrl`
    (exact); a `git@…`/`.git`-suffixed origin or a stale `gh` auth makes every tick skip it.
  - `WATCH skipped (another dispatch is running, PID …)` for the **same PID** across many
    minutes → a dispatch is wedged (or a stale lock). Note the PID and whether it's still alive.
  For each, report the project, the log line (with timestamp), and the contradicting queue
  fact, plus the concrete fix.
- If `gh` is unauthenticated or a repo is inaccessible, note it and skip that repo (don't
  fail the whole audit).

---

## Step 7 — Routine configuration health (DB `RoutineConfig`)

Check that every project's scheduled routines are sanely configured. The source of truth for
the **per-project actual config** is the `RoutineConfig` table; the **canonical baseline**
(what `install.sh` ships) is the reference to compare against.

Pull each project's routine config:

```bash
psql "$DATABASE_URL" -At -F$'\t' -c '
  SELECT p.name, rc.name, rc.cron, rc.model, rc.engine, rc.enabled,
         rc."permissionMode", rc."updatedAt"
  FROM "RoutineConfig" rc JOIN "Project" p ON p.id = rc."projectId"
  ORDER BY p.name, rc.name;'
```

**Canonical baseline** (name → default cron → default model), from the catalog
`webapp/src/lib/routines.ts` (`ALL_ROUTINES`). `RoutineConfig` rows are per-project
*overrides*; a row that differs from the baseline is intentional (set in the UI), not a
drift — only flag rows whose routine name is absent from the catalog (orphaned).

| routine | cron | model | gating |
|---|---|---|---|
| fix-issues | `0 * * * *` (hourly) | sonnet | core |
| mailbox-check | `0 * * * *` (hourly) | sonnet | MOD_MAILBOX |
| fix-ci-issue | `*/15 * * * *` (every 15m) | sonnet | MOD_CI_GATE |
| uptime-check | `0 */4 * * *` (every 4h) | sonnet | core |
| analytics-review | `0 8 * * *` (daily) | sonnet | MOD_ANALYTICS |
| observability-check | `30 8 * * *` (daily) | sonnet | MOD_OBSERVABILITY |
| coolify-check-deployment | `0 9 * * *` (daily) | sonnet | MOD_COOLIFY |
| vulnerability-check | `0 6 * * *` (daily) | sonnet | core |
| claude-md-update | `0 9 * * 1-5` (weekdays) | sonnet | MOD_CLAUDE_UPDATE |
| gsc-check | `0 8 * * 1` (weekly Mon) | sonnet | MOD_GSC |
| ads-review | `0 8 * * 1` (weekly Mon) | sonnet | MOD_ADS |
| product-overview | `0 7 * * 1` (weekly Mon) | opus | MOD_PRODUCT_OVERVIEW |
| architecture-review | `0 2 * * 0` (weekly Sun) | opus | MOD_ARCH_REVIEW |
| security-audit | `0 3 * * 0` (weekly Sun) | opus | core |
| build-optimization | `0 4 * * 0` (weekly Sun) | opus | core |
| docs-audit | `0 5 * * 0` (weekly Sun) | opus | MOD_DOCS_AUDIT |
| code-health | `0 7 * * 0` (weekly Sun) | sonnet | MOD_FALLOW |
| design-audit | `0 10 * * 6` (weekly Sat) | opus | MOD_IMPECCABLE |
| design-critique | `0 11 * * 6` (weekly Sat) | opus | MOD_IMPECCABLE |
| design-harden | `0 10 1 * *` (monthly) | opus | MOD_IMPECCABLE |

For each project's routines, classify and report:

- **Runs too often** (the headline check the maintainer asked for). Estimate each routine's
  real frequency from its cron and flag anything heavier than its baseline or heavy in
  absolute terms:
  - `* * * * *` (every minute) or any `*/N * * * *` with **N < 15** → `critical` — almost
    always a misconfiguration that will hammer the worker and burn tokens.
  - effective frequency **meaningfully higher than the baseline** (e.g. a weekly routine like
    `architecture-review` or `docs-audit` set to daily/hourly, or a daily routine set to
    hourly) → `high`. Expensive `opus` routines running far more often than baseline are the
    worst offenders — call out the model + frequency together.
  - sub-hourly for any routine whose baseline is daily-or-rarer → `high`.
- **Frequency drift (lower)** — runs *less* often than baseline (e.g. a daily routine set to
  weekly, or `enabled: false` on a core routine like `fix-issues` / `security-audit` /
  `vulnerability-check`). A disabled core routine is `high`; a slowed-down optional routine
  is `medium`.
- **Cron parse errors** — `cron` is null, empty, or not a valid 5-field expression → the
  routine will never fire. `high`.
- **Model drift** — `model` differs from baseline. Note both directions: an `opus` baseline
  downgraded to `sonnet` (quality risk, `medium`) and a `sonnet` baseline upgraded to `opus`
  (cost risk, especially combined with high frequency, `medium`).
- **Orphan / unknown routine** — a `RoutineConfig.name` not in the canonical table above →
  either a renamed/removed routine left behind, or a typo the dispatcher can't run. `medium`.
- **Module mismatch** — a routine configured for a project whose `Project.modules` (Step 2)
  doesn't include the gating `MOD_*`, or vice-versa (an active module with no matching
  routine config). `medium`.
- **Configured-but-silent** — routine is `enabled: true` but has **zero** `RoutineLog` rows
  in the last 14 days while other routines on the same project logged normally (cross-check
  against Step 3's data). Suggests the schedule never matches or the dispatcher skips it.
  `medium`.

Group findings by project. Where a routine runs too often, always print **actual cron vs
baseline cron** side by side and the concrete fix (e.g. `set cron to "0 2 * * 0"` or
`disable it in the Web UI → Settings → Routine schedule`). This command only reads — never edit configs here.

---

## Step 8 — Recommendations grouped by priority

Synthesize everything above into recommendations. **No cap on the number** — include every
real finding worth acting on. Each recommendation:

- a one-line statement of the problem
- a concrete action to fix it
- where it was found (repo file, project name, or issue #)

**Group by priority into three buckets — `critical`, `high`, `medium` — in that order.**
**Never show `low`-priority items at all** (drop them silently; do not list or count them).
Within each bucket, order by impact (most impactful first). If a bucket is empty, write
`✓ нет` under its heading.

---

## Report format (console only — write nothing)

Print one markdown report **на русском языке**:

```
## Self-checkup Dark Flow — <YYYY-MM-DD>

### 1. Согласованность промптов и настроек
<находки, или «✓ проблем нет»>

### 2. Корректность установки (N проектов)
<таблица или список по проектам>

### 3. Ошибки выполнения (за 7 дней)
<сгруппированные находки, или «✓ упавших запусков нет»>

### 4. Целостность БД
<находки, или «✓ чисто»>

### 5. Незакрытые git worktree
<по проектам: кол-во + пути/ветки, или «✓ чисто»>

### 6. GitHub: issues и лейблы
<находки по репозиториям, или «✓ проблем нет»>

### 7. Конфигурация рутин
<по проектам: слишком частые / дрейф расписания / дрейф модели / неизвестные / молчащие,
или «✓ проблем нет». Для слишком частых — actual cron vs baseline cron>

## Рекомендации

### critical
1. … (где найдено) — действие
2. …

### high
1. … (где найдено) — действие

### medium
1. … (где найдено) — действие
```

Для каждого чистого раздела явно пиши «✓ проблем нет» (или подходящий аналог из шаблона выше).
Названия приоритетов (`critical` / `high` / `medium`) оставляй на английском. Показывай **только**
три бакета `critical` / `high` / `medium`; рекомендации с приоритетом `low` не выводи вообще
(пустой бакет помечай «✓ нет»). Ограничения на количество рекомендаций нет. Не создавай
файлы, issues или коммиты — команда только читает и печатает отчёт в консоль.
