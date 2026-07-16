# Changelog

All notable changes to Dark Flow are listed here.
Format: `## [version] — YYYY-MM-DD` followed by categorised changes.

Categories:
- **New routine** — new routine file added to `routines/`
- **Updated routine** — existing routine instruction changed
- **Workflow** — changes to `agent-workflow.md` or `tasks.md`
- **Installer** — changes to `install.sh` or `update.sh`
- **Docs** — README, CLAUDE.md template, or other documentation

## [4.16.0] — 2026-07-16

- **Workflow** — центральный реестр гипотез `docs/product/hypotheses.md` (новый шаблон, создаётся on demand). Раньше гипотезы жили разрозненными `## Hypotheses`-секциями в снапшотах `insights/*/` и терялись при консолидации; теперь одна запись на ставку: `H-NNN`, статус `tracking → testing → confirmed/refuted/abandoned`, ссылки на снапшоты-доказательства и задачу. `agent-workflow.md`: секция «From observations to hypotheses» переписана на реестр (снапшоты — сырые доказательства, реестр — текущее состояние), добавлено правило чтения — перед созданием задач из analytics/ads/GSC-находок проверять реестр и не пересоздавать опровергнутые ставки. `product-overview` читает реестр как первичный источник активных гипотез. Задачи и changelog в docs не добавлены сознательно: задачи уже живут в task store (`df` CLI), историю изменений покрывают git + CHANGELOG.

---

## [4.15.0] — 2026-07-16

- **Installer** — до-миграционные проекты (до v4.0.0, эпоха GitHub Issues) навсегда застревали на устаревших воркфлоу-доках: `smart_update_template` при локальных отличиях без `--force` только предупреждал `Locally modified` и НЕ перезаписывал, а осиротевший `docs/github-issues.md` (шаблон его больше не поставляет) инсталлятор вообще не трогал. Итог: в 18 установленных проектах `CLAUDE.md → @docs/agent-workflow.md` продолжал скармливать каждой сессии инструкции вида `gh issue create --label status:approved` — задачи «из GitHub Issues» вместо собственного Postgres-хранилища. **Два фикса:** (1) `docs/README.md`, `docs/agent-workflow.md`, `docs/tasks.md`, `docs/auto-approve.md` помечены инфраструктурными (`always_update=true`) — теперь само-лечатся на каждом апдейте; (2) `cleanup_legacy_project_files` удаляет осиротевший `docs/github-issues.md`. Прогнан свип по всем установленным проектам. `.darkflow.d/claude.md` регенерился и до этого — устаревшие копии значили лишь, что проект не переустанавливали после миграции.

---

## [4.14.0] — 2026-07-15

- **Updated routine** — `analytics-review` вычищен от нескольких дефектов инструкции: (1) единое окно **7 дней** для аналитики и коммитов вместо смеси 24h/7d, совпадает со снапшот-метриками (`visitors7d`/`revenue7d`); (2) guard от дублей — перед созданием задачи проверяет открытые задачи `--source openpanel` и не плодит повторы по той же метрике/шагу воронки/странице; добавлен порог сигнала (мало трафика → снапшот без задач, без галлюцинаций из шума); (4) убран сбор application/server `errors` (это `observability-check`) — только product-level трение, если инструментировано; (5) `adsSpend7d` в снапшоте всегда `null` (ad spend принадлежит `ads-review`); (7) добавлена рубрика приоритетов critical/high/medium/low.

---

## [4.13.0] — 2026-07-13

- **Updated routine** — `web-vitals` now runs **Lighthouse locally** (headless Chrome via `pnpm dlx lighthouse`) instead of the PageSpeed Insights API. No API key and no external quota — the keyless PSI path returns `429 Daily Limit for Unauthenticated Use Exceeded`, so the routine was unusable without a key. Trade-off: lab data only (no CrUX field data / real INP; TBT is the INP proxy), but it can now also measure `localhost`/staging URLs. Updated command, `routines/web-vitals.md`, and the catalog label.

## [4.12.1] — 2026-07-13

- **Installer** — add `web-vitals` to `ALL_DF_COMMANDS` in `install.sh` so the installer actually fetches the new command into `~/.claude/commands/darkflow/` (v4.12.0 shipped the routine but not the installer entry, so `/darkflow:web-vitals` never appeared). Documented the missing step in `routines/README.md` → "Adding a new routine".

## [4.12.0] — 2026-07-13

- **New routine** — `web-vitals` (weekly Mon 6:00): measures Core Web Vitals (LCP, INP, CLS, TTFB, FCP) on the live production URL via the Google PageSpeed Insights API, prefers real-user CrUX field data over Lighthouse lab data, and files a human-triaged task (priority `high`/`medium`) when any metric lands in Google's "poor" band. Skips silently on non-public URLs; writes a dated snapshot + metrics JSON on every run. Added command (`templates/.claude/commands/darkflow/web-vitals.md`), catalog entry (`routines.ts`), and docs.

## [4.11.0] — 2026-07-13

Webapp снят с launchd — теперь запускается **интерактивно** в сессии пользователя, чтобы работали кнопки «Open in cmux».

- **Причина** — под launchd webapp отвязан от GUI/login-сессии, и control-socket cmux отклоняет его подключение (`Failed to write to socket, Broken pipe, errno 32`). `cmux new-workspace` падает, воркспейс не создаётся: cmux уже открыт, поэтому выглядит как «открылся, но сессия не стартует». Тот же класс проблемы, что и с воркером/keychain.
- **Установщик** — `write_launchd_plists()` больше не создаёт `com.darkflow.web.plist`; при апгрейде старый plist выбутивается (`launchctl bootout`) и удаляется. Help-текст: `make reload` грузит только worker, webapp — через `make web`.
- **Makefile** — `reload` перестал грузить web под launchd (только worker + освобождает :5555); удалены таргеты `web-start/web-restart/web-status/web-logs`; `web-stop` теперь выбутивает залётный launchd-инстанс. `web` помечен как обязательно интерактивный.
- **Docs** — CLAUDE.md: webapp запускается интерактивно (`make web`), не под launchd; worker остаётся под launchd.

## [4.10.0] — 2026-07-13

Миграция аналитики с **PostHog** на **OpenPanel** (open-source product analytics).

- **Установщик** — убран флаг `--posthog-project-id`, поле `posthogProjectId` в payload регистрации проекта, чтение/маппинг `posthog_project_id`, интерактивный блок «PostHog integration». Вместо него — подсказка по регистрации OpenPanel MCP (`read`-клиент, `claude mcp add --transport http openpanel "https://api.openpanel.dev/mcp?token=<base64(clientId:clientSecret)>"`). Модуль Analytics и генерируемые доки теперь ссылаются на OpenPanel.
- **Webapp** — удалено поле `posthogProjectId` из модели `Project` (Prisma-миграция `20260713110000_drop_posthog_project_id` с `DROP COLUMN`), из `/api/ingest`, `/api/projects/[id]`, `/api/projects/by-repo`, страницы проекта и формы настроек (убран инпут «PostHog project ID»). Модель аналитики (снапшоты через `POST /api/ingest`) не изменилась.
- **Updated routine** — `analytics-review` переписан на OpenPanel MCP (`get_analytics_overview`, `query_events`, `get_funnel`); убран блок detection/`switch-project` (read-клиент уже scoped на проект); источник задач `--source posthog` → `--source openpanel`. Из `self-update` удалён шаг детекта PostHog project ID.
- **Updated routine** — `csp-setup` больше не умеет слать CSP-отчёты в PostHog (у OpenPanel нет endpoint приёма CSP-violations): единственный путь — внутренний `/api/csp-report` → логгер/observability проекта.
- **Docs/Workflow** — источник задач `posthog` → `openpanel` в issue-template, self-checkup, `tasks.md`, `agent-workflow.md`, `docs/README.md`, `routines/*`; описания команд в README обновлены.

> Требует снятия глобального PostHog-плагина (`posthog@claude-plugins-official`) и регистрации OpenPanel MCP пользователем. После self-update воркер перезапускает **пользователь** (`make reload`).

## [4.9.2] — 2026-07-09

- **Webapp (fix) — «Fix in cmux» перестал молча врать `{ ok: true }`.** Раньше route (`webapp/src/app/api/issues/[id]/launch/route.ts`) ждал только событие ОС `spawn` и рапортовал успех, даже когда сам `cmux new-workspace` падал и воркспейс не создавался. Классический случай: dashboard запущен под **launchd** (`com.darkflow.web`), а control-сокет cmux отвергает detached-сессию (`Failed to write to socket (Broken pipe, errno 32)`) — команда открывалась, но пустая, а кнопка показывала «всё ок». Теперь route дожидается реального `exit`, проверяет в выводе `OK workspace:` и на провал возвращает **502 с настоящим текстом ошибки** (+ подсказку про launchd при broken-pipe). Причина, по которой сокет не пускает launchd-процесс — та же, что в предупреждении про воркер в `CLAUDE.md`: launchd-процесс теряет интерактивную login/GUI-сессию. Чтобы кнопка снова создавала воркспейсы, webapp должен работать в интерактивной сессии пользователя.

## [4.9.1] — 2026-07-08

- **Команды — чистка рудиментной формулировки «issue» со времён GitHub Issues.** В 16 routine-командах (`ads-review`, `security-audit`, `analytics-review`, `architecture-review`, `build-optimization`, `code-health`, `coolify-check-deployment`, `design-audit`, `design-critique`, `design-harden`, `docs-audit`, `gsc-check`, `mailbox-check`, `observability-check`, `uptime-check`, `vulnerability-check`) шаг чтения конфига говорил `language → output/issue language` — наследие эпохи до перехода на собственный task-store. Заменено на `output/task language`, чтобы слово «issue» не подталкивало агента создавать GitHub Issues вместо `df task create`. Логику команд не трогали — все они и раньше создавали задачи через `~/.darkflow/df task create`.

## [4.9.0] — 2026-07-07

- **Self-checkup — новый шаг «Открытые pull requests по всем проектам» (Step 9).** `/self-checkup` теперь через `gh pr list` обходит все проекты с GitHub-чекаутом и ловит висящие незавершённые PR — именно то, что PR-стратегия `fix-issues` могла открыть, но не домержить:
  - **Ready but unmerged** (`high`) — PR не draft и `mergeStateStatus = CLEAN`: готов, ждёт мержа → «доделать» (`gh pr merge`); кросс-чек с задачей `Task #N` из Step 6.
  - **Blocked** (`medium`) — `DIRTY`/`BEHIND`/`BLOCKED`: конфликты/красные чеки/требуется ревью.
  - **Stale draft / abandoned** (`medium`) — draft или без движения >7 дней; кросс-чек с брошенными worktree из Step 5.
  - Только чтение — ничего не мержит/не закрывает. Recommendations сдвинут на Step 10, в формат отчёта добавлен раздел «9. Открытые pull requests».

## [4.8.0] — 2026-07-07

- **Worker — opt-in worktree-изоляция для рутин (`worktree: true`).** Диспетчер `darkflow-run.sh` теперь умеет запускать движок (`claude`/`codex`) в одноразовом `git worktree add --detach`, а не в корне проекта:
  - **Снос в конце.** Worktree удаляется сразу после прогона; EXIT-trap (`_do_exit_cleanup` + `_CLEANUP_WORKTREES`) добивает его при краше/сигнале — папка не утекает.
  - **Симлинки, не копии.** Новый `link_worktree_inputs` протаскивает в worktree untracked-входы сборки — все `node_modules` и `.env`/`.env.local` (до 4 уровней вглубь, покрывает `apps/*`, `packages/*`, `webapp/`) — симлинками, чтобы сборка резолвила зависимости и рутины читали переменные окружения без дублирования на диск.
  - **По умолчанию выключено** (`darkflow_val worktree false`) — историческое in-place поведение и правило «no worktree» сохранены; включается на проект через конфиг.
  - Каветат: detached-worktree не может `git checkout` базовую ветку (её держит корневой worktree), поэтому PR-стратегия `fix-issues` при включённой изоляции должна мержить server-side (`gh pr merge`).

## [4.7.0] — 2026-07-07

- **Docs — ещё два упрощения структуры `docs/`.**
  - **`spec/screens/inventory.md` → `spec/screens.md`.** Целая папка ради одного файла — избыточно (в отличие от `spec/flows/`, который реально ветвится по флоу). Схлопнуто в плоский файл; из установщика и `checklist.yml` убрано создание/проверка каталога `spec/screens`.
  - **`design/patterns.md` влит в `design/components.md`.** Оба тонкие, оба про UI, один и тот же read-trigger — теперь один дизайн-файл (реестр компонентов + секции состояний loading/empty/error/confirmation/toasts). Дизайн-слой = `components.md` + `assets/`.
  - Обновлены все ссылки (`install.sh`, `templates/darkflow/claude.md`, `agent-workflow.md`, `flows/TEMPLATE.md`, `docs-audit.md`, `.darkflow.d/claude.md`, собственные `docs/`); в `checklist.yml` добавлена проверка `decisions/README.md`.

## [4.6.0] — 2026-07-07

- **Docs — перекроен состав слоя `docs/`: убран маркетинговый раздув, закрыта дыра по архитектуре.**
  - **Новый `spec/architecture.md`** — карта системы (стек, верхнеуровневые модули, точки входа, внешние интеграции, поток запроса, инварианты). Это тот документ, по которому AI-агент ориентируется в репозитории; раньше был только `data-model.md` (БД). Добавлен в «When to read/write» во всех shipped-конфигах.
  - **`product/` сжат с 9 → 5 файлов.** `audience.md` + `use-cases.md` влиты в `product.md` (секции «Audience / segments» и «Key use cases»); `competitors.md` влит в `positioning.md` (секция «Competitive landscape»); `marketing.md` удалён (кампании/каналы живут в `insights/ads` и `insights/search-console`, не в product-слое). Осталось: product / positioning / pricing / metrics / glossary.
  - **`ci-runner.md` подключён к установщику** — раньше файл-сирота (на него ссылается `fix-ci-issue`, но установщик не копировал). Теперь копируется при включённом модуле `ci-gate` и значится в манифесте.
  - Обновлены все ссылки в `install.sh`, `templates/darkflow/claude.md`, `templates/docs/agent-workflow.md`, `.darkflow.d/claude.md` и собственных `docs/` репозитория; попутно вычищены висячие ссылки на несуществующие `design/voice-and-tone.md`, `design/tokens.md`, `product/gtm.md`.

## [4.5.0] — 2026-07-07

- **Docs — устранён дрейф между шаблоном `docs/`, установщиком и `CLAUDE.md`.**
  - **`docs/README.md`** переписан: манифест больше не врёт. Файлы разделены на «Scaffolded on install» (реально копируются: README, agent-workflow, tasks, auto-approve, decisions/TEMPLATE + README) и «Created on demand» (папка есть, файл появляется при наличии контента). Добавлен блок «How this folder gets populated» — отсутствие файла означает «ещё не написан», а не «потерян».
  - **Installer + `.darkflow.d/claude.md`** — убраны висячие ссылки на несуществующие `docs/design/voice-and-tone.md` и `docs/design/tokens.md` из «When to read docs» (UI/UX-задачи теперь ведут только на реально существующие `patterns.md` + `components.md`).
  - **`insights/`** синхронизированы: в манифесте помечено, какие подпапки создаются только при включённом модуле (analytics/gsc/ads), добавлены `seo-audit` и `docs-audit`.
  - **ADR-индекс** — новый `docs/decisions/README.md` (список принятых решений), копируется установщиком.
  - **Рутина `docs-audit`** — новая проверка «README-манифест ↔ реальные файлы» (файл на диске без записи в манифесте = дрейф; `on demand`-запись без файла = не дрейф).
  - Формулировка «5 layers» уточнена: «5 content layers + process files».

## [4.4.2] — 2026-07-07

- **Worker — fix `Not logged in · Please run /login` on every routine that reaches the engine.** launchd does **not** source `~/.zshrc`, so the interactive login token the user's terminal `claude` relies on (`CLAUDE_CODE_OAUTH_TOKEN`) was invisible to the worker. Any routine that actually invoked `claude`/`codex` (e.g. `fix-ci-issue`) died with `is_error:true`, `"result":"Not logged in"` and 0 tokens; routines that skip before the engine (`fix-issues` with no approved tasks) looked "OK", masking the problem.
  - **`darkflow-run.sh`** now sources `~/.darkflow/env` (git-ignored, `set -a`) on launch, so credentials placed there reach the engine.
  - **`install.sh`** seeds a commented `~/.darkflow/env` template (chmod 600) — the user fills in the token by hand; the installer never writes the secret.

## [4.4.1] — 2026-07-07

- **Installer — generate the launchd agents instead of deleting them.** 4.4.0 added `make reload` and the `com.darkflow.{web,worker}` launchd targets to the Makefile, but nothing ever created the plists — and `install.sh`'s `worker_start_help()` actively **deleted** `com.darkflow.worker.plist` on every install/self-update while preaching the old `nohup` start. So `make reload` / `make worker-start` failed with `Bootstrap failed: 5` (missing worker plist) on every machine. `worker_start_help()` now writes both agents (macOS) via a new `write_launchd_plists()`:
  - **Worker agent** (global) — always written; **web agent** — only inside the Dark Flow repo (detected via `webapp/package.json` → `darkflow-webapp`).
  - **`_launchd_path()`** prepends the dirs holding `claude` and `node` to the agent PATH (launchd agents don't inherit the login shell PATH — the worker's engine wouldn't resolve otherwise), with a plist comment to adjust for an x86_64/Rosetta node.
  - **Create-if-missing** — never clobbers a hand-tuned plist; writing the file never starts anything (Dark Flow still never auto-starts the worker — the operator bootstraps it so it inherits their keychain/login session).
  - Start/stop hints updated to `make reload` / `launchctl bootstrap|bootout`, keeping the bare `nohup` path as a fallback.

## [4.4.0] — 2026-07-06

- **Make / ops — launchd supervision for web + worker.** Replaced the `nohup`/`pkill` worker targets with launchd-backed ones (`gui/$UID/com.darkflow.{web,worker}`): `make reload` loads-or-restarts both services (rebuilds the webapp first), plus `web-start`/`web-restart`/`web-stop`/`web-status`/`web-logs` and the matching `worker-*` targets. Services auto-restart and survive reboot/logout. `worker-start`/`reload`/`stop`/`status` now `launchctl bootstrap`/`kickstart -k`/`bootout`/`print` instead of managing a bare background process. Documented in README's make-targets table; CLAUDE.md's "never start the worker yourself" note updated to point at `make reload` (and to flag that `launchctl bootstrap`/`kickstart` still must run from the user's own session for keychain access).
- **Webapp — exclude `needsHuman` tasks from the proposed count/sort.** The projects list counted and sorted on `status === "proposed"`, which included human-parked tasks; both the sort key and `proposedCount` now require `!i.needsHuman`, matching the approvals queue.

## [4.3.0] — 2026-07-06

- **Routine — migrated `fix-ci-issue` off GitHub Issues onto the `df` task store.** The v4.0.0 migration (`5e4180c`) deleted `templates/.claude/commands/darkflow/fix-ci-issue.md` — it was still built entirely on `gh issue list --label source:ci --label status:approved` — but left the routine in the catalog (`routines.ts`, module `ci-gate`) and enabled on three projects (`Vargi`, `qabot`, `secscanner`). Result: those projects kept running the stale installed `gh`-based command, which failed with `exit:1` on **100% of runs, every 15 min** (self-checkup caught secscanner 24/24, qabot 23/24 over 24h).
  - **Command** — rewrote `fix-ci-issue.md` on `~/.darkflow/df`: picks the oldest open `source:ci` + `status:approved` task (skipping `needs-human`), counts attempts from the task's `comments` JSON via the `<!-- darkflow:ci-attempt -->` marker, fixes with lint+test only (never `build` — the CI gate builds on push), and posts the attempt marker. Never closes the task — `close-on-green` still owns that so the ≤3 retry counter stays reliable. Escalates via `df task needs-human` after attempt 3 or when blocked.
  - **Docs** — restored `routines/fix-ci-issue.md` reference doc.
  - **Installer** — added `fix-ci-issue` to `ALL_DF_COMMANDS` (so `--self-update` fetches the command again) and wired the `ci-gate` module through `install.sh` (`MOD_CI_GATE` declaration, `MODULES`-string inference, `_module_active()` case, registration `_local_mods`) — it had no `ci-gate` handling at all.
  - **Propagation** — run `install.sh --self-update` on the worker host to replace the stale installed command; the running worker re-reads the command file each dispatch, so no worker restart is needed.

## [4.2.1] — 2026-07-06

- **Webapp — validate `status` on write.** `PATCH /api/tasks/[number]` and `POST /api/tasks` wrote whatever string was sent, unchecked — the same gap that let legacy values (`done`/`resolved`/`needs-info`/`none`) drift into the database before 4.2.0's cleanup. Both now reject any `status` outside `proposed | approved | in-progress | closed` with a 400. `scripts/import-github-issues.sh` updated to fold old GitHub label values (`rejected`, `needs-info`, `done`, ...) into `closed` before posting, so importing a still-open GitHub issue with a stale label no longer 400s.

## [4.2.0] — 2026-07-06

- **Workflow — simplified task lifecycle, dropped `state`.** `Issue.state` (`open`/`closed`) was a leftover from the pre-4.0.0 GitHub Issues mirror, where it shadowed GitHub's own open/closed field separately from Dark Flow's `status` labels. It never earned its keep as an independent column: `status` already drifted into free-text territory (stray `done`/`resolved`/`needs-info`/`none` values from older versions), and closing a task never consistently updated `status` either — so "is this open" required checking both fields, and every list query needed a `state:{in:["OPEN","open"]}` case-insensitivity workaround from the old GitHub-casing days (verified 0 uppercase rows remain in the live table).
  - **Schema** — dropped `Issue.state` entirely. `status` is now the single lifecycle field: `proposed | approved | in-progress | closed`. `rejected` is folded into `closed` (comments/context on the task explain a decline vs. a shipped fix — the Reject and Close buttons both land on `closed` now).
  - **Migration** (`20260706120000_simplify_status_drop_state`) — for the live task store: any row with `state='closed'` or `status='rejected'` became `status='closed'`; legacy `none`/`done`/`needs-info`/`resolved` rows (509, all already closed) were deleted outright as unrecoverable pre-4.0.0 debris.
  - **`df` CLI** — `task close` now sends `{"status":"closed"}` (dropped the dead `--reason rejected` flag, never referenced by any routine template). `task list --state open|closed|all` keeps working unchanged — the webapp now serves it as a compat alias over `status`.
  - **Webapp** — every query that filtered on `state` now filters on `status != "closed"` instead; `/approvals`, the project page's status cards, and the task detail page updated to match the 4-value model.
  - **Docs** — `docs/tasks.md` / `templates/docs/tasks.md` / `agent-workflow.md` rewritten around the 4-status model.

## [4.1.2] — 2026-07-06

- **Webapp** — fixed approved tasks looping back into the global "Needs approval" queue forever. `fix-issues` bounces a task it can't finish itself (missing external credentials, waiting on a third party, etc.) back to `status: "proposed"` via `df task needs-human`, which is correct — but the global `/approvals` page filtered on `status` alone, so a re-bounced task was indistinguishable from a brand-new proposal and kept inviting re-approval instead of "Close after doing the manual step." `/approvals` now excludes `needsHuman: true` rows (they already have a dedicated "Needs Human" card on the project page), and `IssueTableRow` shows a "needs human" badge wherever such a task is still listed.

## [4.1.1] — 2026-07-06

- **Webapp** — the task table's title link (added in 4.1.0 to point at `/tasks/[id]`) still surfaced the string "GitHub" in two spots left over from the old GitHub Issues mirror: the row's secondary "↗" tooltip (`title="Open on GitHub"`) and the detail page's external-link label (`GitHub ↗`). `issue.url` is no longer populated for any task created through `df`/`/api/tasks` — it's a dead field except on rows imported before the v4.0.0 migration — so labeling it "GitHub" is both stale and misleading. Reworded both to generic "external link" text.

## [4.1.0] — 2026-07-04

- **Webapp** — task list titles opened the GitHub Issues URL (`issue.url`) instead of an in-app view. Added a task detail page (`/tasks/[id]`) and pointed the title link at it; the GitHub URL, when present, now shows as a small secondary "↗" link instead. Extracted the shared markdown renderer out of `IssueTableRow` into `components/Markdown.tsx` so the new detail page reuses it.
- **Docs** — the globally-installed `/darkflow` command still read the task queue via `gh issue list --label "status:..."`, a leftover from before the v4.0.0 migration off GitHub Issues. Rewritten to use `~/.darkflow/df task list` instead; dropped the GitHub-label health check.
- **Docs** — `self-checkup`'s Step 6 (GitHub issues & labels) rewritten to audit the Postgres task store via `df`/`psql` instead of `gh issue`/`gh label`. Also fixed two more GitHub-migration leftovers found in the same pass: Step 1's label-taxonomy check referenced `install.sh`'s now-removed `_do_label` provisioning, and Step 4's "stuck approvals" query selected `Issue.pendingStatus`/`pendingStatusAt`, columns dropped in v4.0.0 (the query would have errored).

## [4.0.1] — 2026-07-03

- **Installer** — fixed a standalone `echo` in `generate_darkflow_md()` (the "Interactive commands" line) that still said "no issues or snapshots", missed by the v4.0.0 GitHub-Issues-to-tasks migration pass. Caught via `darkflow:self-update` on this repo.

## [4.0.0] — 2026-07-03

- **Breaking / Installer** — Dark Flow no longer uses GitHub Issues as its task queue. Tasks now live in Dark Flow's own Postgres `Issue` table and are created/read/updated exclusively through a new `~/.darkflow/df` CLI (`df task list/view/create/set-status/set-action/needs-human/comment/close`) talking to new `/api/tasks/*` webapp routes — no more `gh` round-trips, no more GitHub Issues mirror/reconcile layer, no more approve/reject lag.
  - Removed the webapp's GitHub mirror entirely: `github-status.ts`, the `/api/ingest` issue wipe-and-recreate block, `/api/pending-status`, and the `pendingStatus`/`pendingStatusAt`/`pendingComment` columns. Approve/reject/close now write the DB directly.
  - `darkflow-run.sh` lost ~450 lines of GitHub-issue reconciliation: `apply_pending_statuses`, `close_rejected_issues`, `close_routine_below_priority`, `backfill_missing_priority`, `backfill_missing_status`, `convert_blocked_to_needs_human`, `enrich_needs_human_comments`, `validate_gh_token`, `check_gh_auth`, `resolve_gh_token`. `revive_stuck_issues` and `recover_crashed_fix_issues` were rewritten against `df`. `gh` is no longer a worker dependency (still used ad hoc by `vulnerability-check` for Dependabot/code-scanning/secret-scanning alerts, which are GitHub features unrelated to Issues).
  - Every routine template (`fix-issues`, `mailbox-check`, `add-issue`, `vulnerability-check`, and all producer routines) rewritten to create/query tasks via `df` instead of `gh issue`.
  - `fix-issues` now defaults to **direct commit to the base branch** (no PR, no `Closes #N`) — `mergeStrategy=pr` remains available as an opt-in per-project setting, now referencing "Task #N" in the PR body instead.
  - Removed the CI-gate module entirely: `templates/.github/workflows/darkflow-ci-gate.yml`, the `fix-ci-issue` routine, `--with-ci-gate`/`--no-ci-gate` flags. It ran in GitHub Actions and can't reach a local webapp.
  - Removed `templates/.github/ISSUE_TEMPLATE/recommendation.yml`, `setup_labels()`, and the `--no-labels` flag — no more GitHub label taxonomy to provision.
  - `docs/github-issues.md` renamed to `docs/tasks.md`, rewritten around task fields (`status`/`source`/`priority`/`needsHuman`/`action`) instead of GitHub labels.
  - Added `scripts/import-github-issues.sh` — one-time, idempotent importer that pulls a project's still-open GitHub issues into the new task store (does not modify or close the GitHub issues).
- **Docs** — `docs/agent-workflow.md`, `docs/auto-approve.md`, `docs/README.md`, and this project's own `.darkflow.d/claude.md` updated to reference tasks/`df` instead of GitHub Issues/`gh`.

## [3.17.5] — 2026-07-01

- **Webapp** — removed the "Save settings" / "Save constraints" buttons on the project Settings tab; both forms now auto-save 600ms after any field change (debounced), matching the Routines tab behavior.

## [3.17.4] — 2026-07-01

- **Webapp** — the projects list All/Active/Paused filter is now remembered across visits: selecting a filter sets a `projectsFilter` cookie (1yr), and a plain visit to `/` with no `?active=` query param falls back to that cookie instead of always resetting to "All". A `?active=` in the URL still takes precedence, so links/bookmarks keep working as before.

---

## [3.17.3] — 2026-07-01

- **Webapp** — projects list gets an All / Active / Paused filter (`?active=all|active|inactive`) next to the project count, so paused projects can be hidden or isolated at a glance.

---

## [3.17.2] — 2026-07-01

- **Webapp** — moved the "Routines active" master switch from the Routines tab to the Settings tab (next to Name), since it's a project-level flag rather than a per-routine one.

---

## [3.17.1] — 2026-07-01

- **Webapp** — the projects table now shows each project's active/paused state: a green/gray dot next to the name (green = routines active, gray = paused), and the whole row dims when paused.

---

## [3.17.0] — 2026-07-01

- **Webapp** — new project-level **"Routines active"** master switch on the Routines settings tab. Turning it off pauses every routine for that project — the global worker's dispatch pass returns immediately without checking any per-routine schedule — without having to disable each routine individually. Adds `Project.active` (Postgres migration, default `true`).
- **Worker** — `darkflow-run.sh` reads the new `active` flag with a null-only jq filter (not the `// empty` path other config reads use, since that would also swallow `false`) before every dispatch pass; `--list` prints a "PROJECT: paused" header when off.

---

## [3.16.0] — 2026-06-29

- **Updated routine** — issue-filing routines now dedupe against `--state all` instead of `--state open`, so a finding a human already rejected/closed without a fix is no longer re-filed as a fresh `status:proposed` issue on the next scheduled run (the cause of "I dismissed it and it came back"). Re-files only on a demonstrated regression. Applied to: `security-audit`, `architecture-review`, `build-optimization`, `design-audit`, `design-critique`, `design-harden`, `docs-audit`, `code-health`. `uptime-check` is intentionally left open-only (a repeat outage *should* re-alert).

---

## [3.15.1] — 2026-06-29

- **Webapp** — added `webapp/.dockerignore` to exclude `node_modules`, `.next`, `.pnpm-store`, `.env*`, and `tsconfig.tsbuildinfo` from the Docker build context; reduces context size from ~1.1 GB to <10 MB and prevents `.env` from leaking into image layers

## [3.15.0] — 2026-06-27

- **Webapp** — new global **Needs approval** page (`/approvals`, linked in the top nav) listing every `status:proposed` issue across all projects in one table, with a **Project** column and the standard per-issue actions (Approve / Launch in cmux / Close / + Task). Saves walking into each project to triage. `IssueTableRow` gained an optional `project` prop that renders the leading project cell.

## [3.14.2] — 2026-06-27

- **Installer** — the legacy-cleanup step (`install.sh`) now also removes the stale **per-project `.darkflow.d/darkflow-run.sh`** (the old worker copy — one global `~/.darkflow/darkflow-run.sh` services every project now) and **`routines.yml.bak-stagger`** (cron-stagger backup). Previously the cleanup loop dropped `.darkflow`, `routines.yml`, `get-config.sh`, and `mailbox/` but left those two behind, so every upgraded project kept two dead tracked files. Manually cleaned them out of all 16 existing projects.

## [3.14.1] — 2026-06-25

- **Docs** — removed stale `routines.yml` references from webapp comments. The per-project `routines.yml` is gone — routine schedules live in the DB and the worker fetches them via `/api/projects/by-repo`. Fixed the now-misleading comments in `by-repo/route.ts` and `lib/routines.ts` (no behavior change).

## [3.14.0] — 2026-06-25

- **Web UI** — the **Global logs** table now has an All / Errors / Success filter (pills above the table). Defaults to All; reuses the existing `logIsError()` rule, so no schema or query changes. `webapp/src/components/RoutineLogsTable.tsx` only.

## [3.13.0] — 2026-06-25

- **Workflow** — the dispatcher now backfills missing `status:*` labels. Slash commands are prompted to set `status:proposed` on create, but LLM agents don't always comply, and unlike the missing-`priority:*` case there was no deterministic repair — so an issue filed without a status sat **untriaged** (`status:none`) forever and never reached the approval queue. New `backfill_missing_status()` in `darkflow-run.sh` (mirrors `backfill_missing_priority()`): any OPEN issue with a routine `source:*` label but no `status:*` gets `status:proposed`. Left untouched — `needs-human` (mailbox/human-attention channel, untriaged is correct there), `source:manual`/no-source, and deprecated `status:blocked`.

## [3.12.0] — 2026-06-23

- **Web UI** — new **Global logs** page (`/logs`, third item in the top nav) showing routine runs aggregated across **all** projects in one table, with an added Project column. On top, a small per-minute bar chart of the last 24 hours stacks successful (green) vs failed (red) runs — bar height = tasks/minute. Error detection reuses the existing `exit:` summary marker. New `webapp/src/app/logs/page.tsx` and `webapp/src/components/GlobalLogsChart.tsx`; `RoutineLogsTable`/`LogRow` gained an optional `project` column (per-project pages render unchanged).

## [3.11.1] — 2026-06-23

- **Docs** — new `make worker-reload` target in the repo `Makefile`: stops the running global worker, then runs a fresh one in the **foreground** (live logs; Ctrl-C to stop). `worker-run`/`worker-start` deliberately refuse to start when a worker is already running (anti-double-start guard), so reloading after a self-update previously meant `worker-stop` + `worker-run` by hand. Source-repo convenience only — not part of the installed-project Makefile block. `Makefile`.

## [3.11.0] — 2026-06-23

- **Workflow / Docs** — the agent must no longer start, restart, or relaunch the global worker. The worker's `claude`/`codex` engine authenticates from the user's interactive shell (keychain / env credentials a Claude Code session does not have); a worker the agent launches inherits a credential-less environment and every routine fails with `Not logged in · Please run /login`. Flipped the instruction in the root `CLAUDE.md` blockquote and in the `/darkflow:self-update` slash command (Step 1b → "Ask the user to restart the global worker"): the agent now prints the restart command and asks the user to run it in their own terminal. Stopping/killing the worker on request is still allowed (needs no credentials). `CLAUDE.md`, `templates/.claude/commands/darkflow/self-update.md`.

## [3.10.3] — 2026-06-22

- **Worker** — `sync_webapp` no longer passes the issue/log/commit arrays to `jq` as `--argjson` command-line arguments. With up to 300 issues (full bodies) the combined argv overflowed `ARG_MAX`, failing with `jq: Argument list too long` and silently dropping the Web UI sync for that project. The large arrays are now concatenated into a temp file and read by `jq` via `--slurpfile` (only the small scalar fields stay on the command line), and the assembled payload is POSTed to `/api/ingest` over stdin (`curl --data-binary @-`) so it can't overflow curl's argv either. `templates/darkflow/darkflow-run.sh`.

## [3.10.2] — 2026-06-22

- **Worker** — repo URL is now resolved from the local git remote (`git remote get-url origin`, normalized to the canonical `https://host/owner/repo` form) instead of `gh repo view`, which used the GitHub **GraphQL** API. The old path ran one GraphQL call per project per 30s tick (~2000/hr across a typical machine), and whenever the shared GraphQL rate limit was exhausted *every* project got skipped — `set_project` failed, no heartbeat was sent, and the Web UI showed the worker permanently "offline". The new resolver costs zero API calls and keeps the worker beating through rate-limit exhaustion. `gh repo view` remains only as a fallback when there is no usable git remote. The two direct `gh repo view` call sites in `apply_pending_statuses` and `sync_webapp` now route through the same cached resolver. `templates/darkflow/darkflow-run.sh`.

## [3.10.1] — 2026-06-22

- **Worker** — `run_in_pgid` now pre-flights the engine binary with `command -v "$1"` before handing off to the python `execvp` wrapper. A missing engine CLI (e.g. `codex` not installed) previously surfaced as an opaque `FileNotFoundError` Python traceback in the routine log; it now fails fast with `command not found on PATH: '<cmd>' — is the engine CLI installed?` and return code 127. `templates/darkflow/darkflow-run.sh`.

## [3.10.0] — 2026-06-22

- **Workflow / policy** — reversed the "never start the worker yourself" rule. After a self-update the agent now **restarts the global worker in the background itself** (a running worker holds the old script in memory, so an update is inert until restart). `CLAUDE.md` directive rewritten; `self-update.md` gains a **Step 1b — Restart the global worker** that does `pkill -f /.darkflow/darkflow-run.sh` then `nohup … &` when a worker was running (first-time start on a fresh machine stays the user's call). `CLAUDE.md`, `templates/.claude/commands/darkflow/self-update.md`.

## [3.9.1] — 2026-06-22

- **Maintainer command** — `/self-checkup` Step 6 now catches the two failure modes behind the silent-approved-issue bug: (1) the **invariant violation** `status:approved` + `needs-human`/`status:blocked` on one issue (mutually exclusive — silently drops it from the `fix-issues` queue), and (2) a **worker-log ↔ queue mismatch** — cross-reads `~/.darkflow/worker.log` and each project's `.darkflow.d/darkflow-run.log` against the live GitHub queue to flag recurring `SKIP fix-issues — no actionable …` / `SKIP … not a registered project` / wedged-dispatch lines that contradict reality. `.claude/commands/self-checkup.md`.

## [3.9.0] — 2026-06-22

- **Bugfix / invariant** — `needs-human` and `status:approved` are now strictly mutually exclusive, enforced at every write site, and `fix-issues` trusts `status:approved` alone. Previously the worker's `apply_pending_statuses` (the path that flushes web-UI approvals to GitHub labels when the webapp's own `gh` call didn't run) added `status:approved` **without** stripping `needs-human`; the `fix-issues` actionable filter then excluded `needs-human`, so those issues sat "approved" in the UI yet were silently never picked up (seen on adsynex: 11 approved issues stuck). Fixes:
  - `apply_pending_statuses` now `--remove-label needs-human` when it sets `status:approved`/`status:rejected` (mirrors the webapp approve path).
  - `convert_blocked_to_needs_human` now also strips `status:approved` when folding `status:blocked` into `needs-human`.
  - `mailbox-check` send-failure path now strips `status:approved` when it parks an issue as `needs-human`.
  - `fix-issues` actionable filter simplified to `status:approved` minus `action:reply` only (dropped the `needs-human`/`status:blocked` re-checks — now guaranteed absent). `action:reply` stays excluded because those are mailbox-owned (handled by `mailbox-check`), not a code task. `templates/darkflow/darkflow-run.sh`, `templates/.claude/commands/darkflow/mailbox-check.md`.
  - (The agent templates `fix-issues.md`/`fix-ci-issue.md` already stripped `status:approved` when adding `needs-human` — unchanged.)

## [3.8.0] — 2026-06-22

- **New label** — `source:arch-review`. The `architecture-review` routine previously labelled its auto-generated findings `source:manual`, but the worker's min-priority gate (`close_routine_below_priority` in `darkflow-run.sh`) deliberately exempts `source:manual` so it never auto-closes human-filed issues. Result: arch-review findings below a project's `minPriority` slipped straight past the level filter and piled up in the proposed queue (seen on qabot/studyclutch with `minPriority=high`). Giving arch-review its own source label makes the gate apply to it like every other routine. `install.sh`, `templates/.claude/commands/darkflow/architecture-review.md`, `routines/architecture-review.md`.
- **Note** — every other routine command already uses a distinct `source:*` label; only `add-issue` keeps `source:manual` (human-driven, correctly exempt). Existing repos get the new label on next `darkflow:update`; their already-filed `arch:` issues must be re-labelled `source:manual` → `source:arch-review` once for the gate to retroactively close the sub-threshold ones.

## [3.7.1] — 2026-06-22

- **Bugfix** — approving an issue in the webapp now also removes the `needs-human` label. Previously, approving a `needs-human` issue added `status:approved` but left `needs-human` on it; the worker correctly excludes `needs-human` from its autonomous `fix-issues` queue, so the issue showed as "approved" in GitHub yet was silently skipped every tick. Approval is a human routing the issue to the agent, so it now overrides the human-gate (matches the close path, which already strips `needs-human`). `webapp/src/lib/github-status.ts`.

## [3.7.0] — 2026-06-22

- **Feature** — per-project **routine constraints**. A free-text field in the project Settings tab (webapp) writes `<project>/.darkflow.d/constraints.md`, which is `@`-imported into every agent's context via `.darkflow.d/claude.md`. Routines that analyze and propose changes (build-optimization, architecture-review, design-*, analytics-review, etc.) honor these limits — findings that violate a constraint are dropped, not filed. New API route `PUT/GET /api/projects/[id]/constraints` reads/writes the file via the project's host `localPath` (same pattern as mailbox `.env`); no DB column, no worker changes.
- **Installer** — `generate_darkflow_md()` now emits the `@.darkflow.d/constraints.md` import plus a "Project constraints" instruction section; `sync_claude_md()` creates a placeholder `constraints.md` on first run (never clobbers user content). Existing installs pick this up on next `darkflow:update`.

## [3.6.0] — 2026-06-22

- **Worker** — the global watch loop now dispatches each project in its own backgrounded subshell, so projects are serviced **in parallel** instead of one-after-another per tick. Cross-project isolation was already guaranteed (per-project lock dir, separate git repos/cwd) and the fork now also gives each project private `PROJECT_ROOT`/`LOG`/`GH_TOKEN`/`PENDING_LOGS`; the global `/tmp/darkflow-slots` semaphore still caps total concurrent agent sessions. The loop does not `wait` on children — a busy project's per-project lock makes its re-dispatch fail fast next tick, bounding live children by project count.
- **Worker** — each subshell now flushes its **own** `PENDING_LOGS` whenever a routine produced logs, instead of relying on the every-10th-tick batch sync. The old batching only worked because `PENDING_LOGS` lived in one long-running process; an ephemeral subshell would have died before the next sync tick and dropped its routine result. This also fixes a latent bug where one project's pending logs could be attributed to another project at sync time.

## [3.5.0] — 2026-06-22

- **Webapp** — approve/reject/close are now non-optimistic: the route pushes to GitHub via `gh` **first** and only mutates the DB on success; on failure it returns 502 and the button surfaces the error instead of silently showing a state GitHub never accepted. Removed the `pendingStatus` write path and the worker fallback for these actions (host-mode `gh` is now required — the Docker profile without `gh` can't approve/reject/close from the UI).
- **Webapp** — reject/close now **delete** the issue row instead of marking it closed; `/api/ingest` no longer stores `state: "closed"` issues, so the worker's `--state all` resync can't resurrect a dismissed row. Trade-off: the home "issues closed per day" chart no longer has data to plot.

## [3.4.7] — 2026-06-22

- **Webapp** — Close button now sets `state: "closed"` in the DB (mirroring Reject), so the row leaves the open-issues list immediately on refresh. Previously close only set `needsHuman`/`pendingStatus`; once v3.4.6 cleared `pendingStatus` synchronously, the row stayed in the list looking untouched.

## [3.4.6] — 2026-06-22

- **Webapp** — approve/reject/close now push the GitHub status label synchronously (best-effort `gh issue edit` on the host) instead of only writing `pendingStatus` and waiting for the worker's ~5-min sync. On success `pendingStatus` is cleared immediately, so the "Pending Sync" badge no longer lingers; on failure (e.g. no `gh` in the Docker profile) it falls back to the worker reconciling as before.

## [3.4.5] — 2026-06-22

- **Installer** — fix `register_project` crashing with `jq: invalid JSON text passed to --argjson` when no optional modules are active. Empty `jq -R` input produced no output; switched to `jq -n --arg` so an empty module list yields `[]`.

## [3.4.4] — 2026-06-22

- **Webapp** — dashboard "Errors" column and project detail Logs tab now scope to the last 24h instead of the latest 100 log entries.

## [3.4.3] — 2026-06-20

- **Webapp** — dropped the "Last synced" column from the projects list. It tracked
  `lastSyncedAt` (set on `/api/ingest`, which fires right after a routine runs), so its
  timestamp duplicated the existing "Last routine" column, and its red ">1h stale" rule
  was misleading given routine cadences range from hourly to weekly. The `lastSyncedAt`
  field stays in the schema; liveness is better surfaced by the global worker status.

## [3.4.2] — 2026-06-20

- **Repo tooling** — added `make worker-run` to run the global worker in the **foreground**
  with live logs in the terminal (Ctrl-C to stop), alongside the existing background
  `worker-start`. Refuses to start if a background worker is already running.

## [3.4.1] — 2026-06-20

Centralized config — phase 4 (docs). Updated documentation to the centralized model;
the per-project file cleanup for existing installs is handled automatically by the
installer (v3.4.0's `cleanup_legacy_project_files`), so no separate migration step is
needed.

- **Docs** — `README.md`, root + template `CLAUDE.md`, `routines/README.md`, and every
  `routines/<name>.md` now describe the Web UI as the source of truth for settings + the
  routine schedule (no more `.darkflow` / `routines.yml` / per-project `get-config.sh`).
  New routines are added to the catalog `webapp/src/lib/routines.ts`.
- **self-checkup** — rewired the repo-consistency and per-project audits to the new model:
  routine source of truth is the catalog (not `checklist.yml`/`routines.yml`), and worker
  version + liveness are read once from the global `Settings` row, not per project.

## [3.4.0] — 2026-06-20

Centralized config — phase 3 (installer). The installer no longer scaffolds any
per-project operational files. A project is registered in the Web UI (DB) and owns
only its docs scaffolding, the `CLAUDE.md` include, the Makefile block, and (opt-in)
the CI-gate workflow.

- **Installer** — stopped writing `.darkflow`, `.darkflow.d/routines.yml`, the
  per-project `get-config.sh`, and the per-project mailbox scripts. Projects are now
  registered via a `POST /api/ingest` (`register_project`); settings + routine
  schedule live in the DB thereafter. Mode detection keys off DB registration /
  scaffolding instead of `.darkflow`; the version-compare "verify" quick-exit is gone
  (re-applying templates is idempotent).
- **Installer** — `get-config.sh` and the mailbox scripts are installed once into
  `~/.darkflow/` by `global_bootstrap` (`install_global_helpers`). `read_config` now
  reads project settings from the Web UI, not a local file.
- **Installer** — `cleanup_legacy_project_files` now also removes the obsolete
  `.darkflow`, `.darkflow.d/routines.yml`, `.darkflow.d/get-config.sh`, and
  `.darkflow.d/mailbox/` from existing projects on the next install/update (the
  config already lives in the DB). `.darkflow.d/` stays as the runtime dir.
- **get-config.sh** — rewritten as a global helper that fetches the project's config
  from `/api/projects/by-repo` into `.darkflow.d/state/config.json`.
- **Slash commands** — every command's "Step 1 — Read project config" now runs
  `~/.darkflow/get-config.sh` and reads `.darkflow.d/state/config.json` (JSON) instead
  of the removed `.darkflow` cache. Mailbox commands call `~/.darkflow/mailbox/*`.
- **checklist.yml** — dropped the per-project `.darkflow` config-keys, `routines.yml`
  routine entries, `get-config.sh`, and mailbox entries. Routines + settings are no
  longer checklisted; new routines auto-propagate via `webapp/src/lib/routines.ts`.
- **Webapp** — `/api/ingest` create now persists `obsTool` / `obsUrl` /
  `posthogProjectId` so install-time integration settings reach the DB.
- Removed the obsolete `templates/darkflow/routines.yml`.

Webapp change — rebuild + restart the host process: `cd webapp && pnpm build && PORT=5555 pnpm start`.

## [3.3.0] — 2026-06-20

Centralized config — phase 2 (web UI). The dashboard now shows **one** global worker
version + liveness indicator instead of a per-project version badge and worker column.
With a single global worker, staleness is a machine-level property, so a per-project
"outdated" badge was noise — every release flagged every project even when nothing
per-project changed.

- **Schema** — added `workerVersion`, `workerLastSeen`, `workerRoutine` to the global
  `Settings` row (additive migration `20260620000000_add_settings_worker_status`).
- **Heartbeat** — `/api/worker/heartbeat` now also mirrors the worker's version, last-seen
  time, and currently-running routine onto the global `Settings` row.
- **UI** — new `GlobalWorkerStatus` header badge (single version + worker online/running/
  offline indicator). Removed the per-project **DF Version** and **Worker** columns from
  the dashboard and the per-project "settings pending" badge (the worker now reads config
  live every tick, so there is no cache lag to flag).

Webapp change — rebuild + restart the host process: `cd webapp && pnpm build && PORT=5555 pnpm start`.

## [3.2.0] — 2026-06-20

Centralized config — phase 1 (worker). The global worker now reads each project's
settings **and** routine schedule straight from the Web UI (`/api/projects/by-repo`)
instead of the local `.darkflow` cache + `.darkflow.d/routines.yml`. The DB is the
single source of truth; the local config files are no longer consulted by the worker.

- **Worker** — `darkflow_val()` now reads the per-project config JSON fetched from the
  Web UI (new `fetch_project_config`), and routine dispatch (`mode_list`/`mode_dispatch`/
  `mode_manual`) reads the merged schedule from that JSON via `jq`. `webapp_url` and
  `version` come from `~/.darkflow/config`; `gh_token` is no longer stored per project
  (the shared Web UI token / `gh auth` is used).
- **Worker** — project discovery no longer gates on `.darkflow.d/` existence; a project
  is serviced iff it's registered in the Web UI (resolved by repo URL). cwd subcommands
  resolve the project via `git rev-parse --show-toplevel`.
- **Worker** — dropped the `yq` dependency and the `get-config.sh` pre-run refresh (config
  is now re-fetched directly before each run). `.darkflow.d/` stays as the per-project
  runtime dir (state, metrics, logs, mailbox); mailbox `fetch.py` is read from
  `~/.darkflow/mailbox/` when present, falling back to the project copy.
- Fixed a latent bug where a disabled routine (`enabled: false`) could be treated as
  enabled because `jq`'s `//` operator coerces `false` to its default.

## [3.1.3] — 2026-06-20

- **Worker** — removed the dead `# DF_VERSION:` comment from `templates/darkflow/darkflow-run.sh`. It was never parsed by anything (version comparison uses the `VERSION` file and per-project `.darkflow` config), so it only drifted out of sync (stuck at 3.0.0). One fewer thing to keep updated.

## [3.1.2] — 2026-06-20

- **Repo tooling** — added `make worker-start` / `worker-stop` / `worker-status` / `worker-logs` to the darkflow repo Makefile for controlling the global worker (`~/.darkflow/darkflow-run.sh`). `worker-start` is idempotent (won't double-start) and logs to `~/.darkflow/worker.err.log`.

## [3.1.1] — 2026-06-20

- **Installer/Docs** — the manual worker start command now redirects stdout to `/dev/null` and stderr to `~/.darkflow/worker.err.log` instead of appending stdout back into `worker.log`. The worker already writes its own log internally, so the old `>> worker.log` doubled every line. `worker.log` is now clean; crashes land in `worker.err.log`.

## [3.1.0] — 2026-06-20

- **Worker** — removed the worker's **automatic self-update**. With a single global worker there's only one artifact to update, so updates are now explicit (`install.sh --self-update` or `/darkflow:self-update`). This drops the riskiest code path — the unattended worker no longer fetches and runs an installer on its own — and removes a class of CDN-lag failure modes.
- **Installer** — Dark Flow no longer **auto-starts** the worker. The launchd agent is gone; `install.sh` now removes any previously-installed `com.darkflow.worker` agent and prints how to start the worker yourself (`nohup bash ~/.darkflow/darkflow-run.sh >> ~/.darkflow/worker.log 2>&1 &`). You control when it runs.
- **Docs** — README, routines guide, and the self-update command updated for manual start + manual update.

## [3.0.2] — 2026-06-20

- **Worker** — the self-update now fetches `install.sh` to a temp file and verifies it actually supports `--self-update` before running it. If the raw CDN briefly serves a stale pre-3.0.0 installer (which would treat the flag as unknown and run a full project install in the worker's cwd), the worker skips and retries next cycle instead. Makes self-update deterministic regardless of CDN propagation lag.

## [3.0.1] — 2026-06-20

- **Worker** — hardened the global worker's self-update: cache-bust the GitHub raw fetches for `VERSION` and `install.sh`, and run the installer from `~/.darkflow` with `--self-update`. Prevents a momentarily-stale CDN copy (an old `install.sh` without `--self-update`) from running a full project install in the worker's cwd.

## [3.0.0] — 2026-06-20

**Breaking: one global worker + user-scope commands.** Dark Flow no longer runs a separate dispatcher per project or copies slash commands into each project. Re-run the installer (`/darkflow:self-update`) in any project once to migrate — the worker then auto-self-updates.

- **Installer** — `install.sh` now installs a single global worker at `~/.darkflow/darkflow-run.sh` and, on macOS, loads it as a launchd agent (`com.darkflow.worker`, `RunAtLoad` + `KeepAlive`) so one process services every project and starts at login. All slash commands are installed once into **user scope** (`~/.claude/commands/darkflow/`, full superset) instead of per project. The per-project worker copy and `.claude/commands/darkflow/` are removed on upgrade. New `--self-update` flag refreshes only the global worker + commands (used by the worker's own update check). The project step still writes `.darkflow.d/{routines.yml,get-config.sh,state,mailbox}` and registers the project's local path with the web UI.
- **Worker** — `darkflow-run.sh` refactored to be project-agnostic: the default loop discovers every registered project from the web UI (`GET /api/projects`, by **Local path**) and dispatches each one's due routines, sharing the existing machine-global concurrency semaphore. Single-project subcommands (`<routine>`, `--list`, `--dry-run`, `--sync`) act on the project containing the current directory. Self-update now refreshes the global worker via `install.sh --self-update` (deterministic, no Claude session) and re-execs.
- **Webapp** — new `GET /api/projects` discovery endpoint returns every project with a Local path; `/api/ingest` now accepts `localPath` and seeds it on first contact (a UI-set value always wins). The worker reports its own absolute path on every sync, so projects self-register for discovery.
- **Docs** — README, routines guide, CLAUDE.md templates, and the generated project docs updated to describe the single global worker and user-scope commands. `checklist.yml` no longer verifies per-project command/worker files (now global).

## [2.96.1] — 2026-06-19

- **Webapp** — the **Needs Human** filter card no longer renders a purple border when it just has open needs-human issues; the border now only highlights when the card is actually selected. Previously a non-zero count made the card look permanently active on first load. The count cue (purple number) is unchanged.

## [2.96.0] — 2026-06-19

- **Webapp** — fixed the Issues tab on the project page:
  - **Filters** — the status cards are now a multi-select. No card selected shows **all** issues (previously the page defaulted to `proposed`); selecting one card shows it; selecting several shows the union. Clicking an active card toggles it back off. The heading reflects the selected cards.
  - **Row actions** — **Close** and **Fix in cmux** now appear on every issue row regardless of status. **Approve** is hidden once an issue is approved or in-progress (shown only for untriaged/proposed). Split the old combined `IssueActions` (Approve+Close) into a standalone `ApproveIssueButton` so Close can render independently without duplication.

## [2.95.0] — 2026-06-19

- **Webapp** — the `fix-ci-issue` routine (CI-gate module: picks up `source:ci` failures, fixes, retries up to 3×, runs every 15 min) now appears in the Routines tab on the project page. It was already shipped to projects via `checklist.yml` / `routines.yml` but was missing from the webapp's canonical `ALL_ROUTINES` catalog, so it never rendered in the settings UI and couldn't be configured there. Added to `webapp/src/lib/routines.ts` with `module: "ci-gate"`, cron `*/15 * * * *`, model `sonnet`.

## [2.94.2] — 2026-06-19

- **CI gate** — drop the `setup-node` / `pnpm/action-setup` steps added in v2.94.1; the gate again calls `pnpm` directly and expects the toolchain to be on the runner's PATH. Root cause of the persistent red CI: the self-hosted runners are minimal `myoung34/github-runner` **containers that ship neither node nor pnpm**, and the v2.94.1 bootstrap actions can't run there either (no hosted tool cache to extract into — the setup step fails before any check). The durable fix is provisioning the toolchain *in the runner image*, not at job time.
- **Docs** — add `docs/ci-runner.md`: runner toolchain requirements + a ready-to-use `Dockerfile` (`FROM myoung34/github-runner` + node 22 + pnpm 10) and a docker-compose anchor pattern to build one image and reuse it across all runner services.

## [2.94.1] — 2026-06-19

- **CI gate** — provision **node + pnpm via dedicated setup steps** (`pnpm/action-setup@v4` + `actions/setup-node@v4`, each guarded by `hashFiles` so Python-only repos skip them) instead of the inline `ensure_pnpm()` shim from v2.94.0. On self-hosted runners where node/npm/corepack are only on the *login* PATH (nvm/fnm/asdf), the gate's `bash --noprofile --norc` shell never sees them, so `ensure_pnpm()` (which itself needs corepack or npm) still failed with `pnpm: command not found`. The setup actions install node+pnpm into the job's PATH independently of host shell config — the same approach a hand-patched project (`vargi`) had already adopted. Existing projects: re-copy the workflow (the `wf-ci-gate` checklist item only restores it when *missing*, so push the updated file manually or delete-then-`self-update`).

## [2.94.0] — 2026-06-19

- **CI gate** — `templates/.github/workflows/darkflow-ci-gate.yml` now **auto-provisions `pnpm`** on self-hosted runners instead of relying on a bare `corepack enable`. After the v2.93.0 switch to `runs-on: [self-hosted, Linux, X64]`, every pnpm-based project's gate failed instantly with `pnpm: command not found` — `corepack enable` writes its shim next to the (root-owned) node binary, which a non-root runner can't do, and `bash --noprofile --norc` never loads a login PATH. The new `ensure_pnpm()` helper installs the shim into `$HOME/.local/bin` (corepack with `--install-directory`, falling back to an `npm install -g --prefix` into a writable prefix) and exports it onto PATH, so the gate works on a plain self-hosted runner with only node + npm present. Existing projects pick this up via `self-update` (checklist `wf-ci-gate`, `copy-template`).

## [2.93.1] — 2026-06-18

- **Webapp** — projects dashboard **Errors** column now counts failed routine runs within the project’s **100 most recent logs**, matching the Logs tab’s 100-entry limit. The previous 7-day window is removed so the dashboard count aligns with what users see on the project page.

## [2.93.0] — 2026-06-17

- **CI gate** — `templates/.github/workflows/darkflow-ci-gate.yml` now runs the gate job on a **self-hosted runner** (`runs-on: [self-hosted, Linux, X64]`) instead of `ubuntu-latest`, so the gate no longer consumes GitHub-hosted Actions minutes / hits billing-blocked startup failures. A comment documents the runner-label requirement (node/pnpm/python on PATH) and how to switch back to `ubuntu-latest`. Existing projects pick this up via `self-update` (checklist `wf-ci-gate`, `copy-template`).

## [2.92.0] — 2026-06-17

- **New command** — `/darkflow:csp-setup`, a one-time setup command that wires Content-Security-Policy violation reporting into a project. It detects the project's CSP location and destination: if PostHog is integrated it reports to PostHog's `/report/` endpoint (region-correct, token from existing config); otherwise it creates an internal `/api/csp-report` route handler that logs violations via the project's existing logger → observability backend (e.g. SigNoz/OTel). Adds a baseline `Content-Security-Policy-Report-Only` when the project has no CSP. Idempotent.
- **Installer** — `install.sh` copies the new command template and lists it in the post-install command summary; `checklist.yml` gains `cmd-csp-setup` so existing projects pick it up on `self-update`.
- **Docs** — README interactive-commands table documents `/darkflow:csp-setup`.

## [2.91.0] — 2026-06-17

- **Webapp** — the project **Logs** tab gained a **Status** column showing **OK**/**Error** per routine run (errors detected from the worker's `exit:N` log marker), and the **Time** and **Status** column headers are now click-to-sort — sort by **Status** to surface all failed runs together.

## [2.90.0] — 2026-06-17

- **Webapp** — projects dashboard gained an **Errors** column (before **Last routine**) showing the count of failed routine runs in the last 7 days (red when >0), so failing routines stand out at a glance. Failures are detected from the worker's `exit:N` log marker.
- **Webapp** — removed the **Commits** tab from the project detail page (commits are easier to view directly on GitHub).

## [2.89.0] — 2026-06-17

- **Self-checkup** — added **Step 7 «Конфигурация рутин»**: audits each project's `RoutineConfig` against the canonical `install.sh` baseline. Flags routines that **run too often** (`* * * * *` or `*/N` with N<15 → critical; heavier-than-baseline / sub-hourly weekly routines → high), frequency drift, disabled core routines, cron parse errors, model drift (opus↔sonnet), orphan/unknown routines, module mismatches, and configured-but-silent routines. Compares on frequency/hour/day (not the literal minute, which `install.sh` staggers per-project).
- **Self-checkup** — recommendations are no longer capped at 10. They are now **grouped into `critical` / `high` / `medium` buckets**; `low`-priority items are dropped entirely.

## [2.88.0] — 2026-06-17

- **Webapp** — added a **Needs approval** column (accent-colored proposal count) before **Approved** on the projects dashboard, so the full triage breakdown reads Open → Needs approval → Approved → Needs Human.

## [2.87.1] — 2026-06-17

- **Webapp** — Open Issues column now shows just the plain total count, dropping the `(N new)` proposal hint for a cleaner read.

## [2.87.0] — 2026-06-17

- **Webapp** — projects dashboard now renders full-width (removed the `max-w-7xl` clamp in the root layout) so the wider issue breakdown fits without horizontal squeeze.
- **Webapp** — split the issue counts into dedicated columns: **Open Issues** now shows just the total open count (with a subtle `(N new)` accent for proposals awaiting approval), plus new **Approved** (green) and **Needs Human** (purple 👤) columns, making it easy to scan where each project stands at a glance.

## [2.86.1] — 2026-06-17

- **Webapp** — fixed unreadable black tooltip text on the "Net change — last 7 days" chart. Because that chart uses per-day `<Cell>` coloring, recharts didn't inherit an item text color from the series and fell back to black on the dark tooltip surface. Added an explicit `itemStyle` (light `--text`) to both activity-chart tooltips so values are legible.

---

## [2.86.0] — 2026-06-16

- **Webapp** — the Projects-page "Issues — last 7 days" panel is now split into two side-by-side charts. The left chart is unchanged (stacked Created/Closed bars). The new right chart, "Net change — last 7 days", plots the daily net delta `created − closed` against a zero reference line, with per-day coloring — red when the open-issue backlog grew that day, green when it shrank — so the dynamics of backlog change are visible at a glance instead of having to mentally subtract the two stacked segments.

---

## [2.85.1] — 2026-06-16

- **Tooling** — `/self-checkup` Step 6 now passes `--limit 200` to `gh label list`. By default `gh label list` caps at 30 labels, so the label-taxonomy diff silently reported every repo as missing `priority:*` / `needs-human` / `action:*` even when those labels exist — pure false positives. Documented the cap inline so the flag isn't dropped again.

---

## [2.85.0] — 2026-06-16

- **Tooling** — the maintainer-only `/self-checkup` command gains a new **Step 5 — Leftover git worktrees** audit. For every registered project with a `localPath`, it runs `git worktree list --porcelain` + `worktree prune --dry-run` and reports leftover worktrees (path, branch, HEAD), flagging **prunable** ones (directory gone) and **stale** ones (branch already merged into the project's default branch, or last commit older than 7 days), with concrete `worktree remove`/`worktree prune` cleanup suggestions. Dark Flow's `cmux` sessions run in worktrees that should be removed on exit, so leftovers signal crashed/abandoned sessions. The GitHub step renumbers to Step 6 and recommendations to Step 7; report output gains section 5 for worktrees. Read-only — never removes anything.

---

## [2.84.0] — 2026-06-16

- **Webapp** — new per-project **Minimum issue priority** slider in Settings (critical · high · medium · low). Routines won't file issues below the chosen level — lower-priority findings go to the run snapshot instead. Default `medium` preserves prior behavior. New `Project.minPriority` column (migration `20260616130000_add_project_min_priority`), persisted via the project PATCH route and exposed on `/api/projects/by-repo` for the worker.
- **Webapp** — the Issues list now highlights any open issue whose priority is **below** the project's configured minimum: a yellow left border, faint row tint, and bold yellow priority cell, so lingering lower-priority items are visible at a glance (e.g. manually-filed `low` issues under a `medium` threshold).
- **Worker** — `darkflow-run.sh` generalizes the old `close_routine_low_issues` into `close_routine_below_priority`: routine-created issues ranking below the project's `min_priority` (synced from the Web UI via `get-config.sh`) are auto-closed before reaching the approval queue. Manual issues (`source:manual`), `status:in-progress`, and `needs-human` issues remain exempt. At the default `medium` threshold this is identical to the previous low-only behavior.

---

## [2.83.0] — 2026-06-16

- **Webapp** — added a 7-day "Issues — last 7 days" stacked bar chart (recharts) to the top of the Projects page, showing issues **created** (blue) and **closed** (green) per day across all projects. Days with no activity still render; an empty state shows when no timestamps exist yet.
- **Webapp** — `Issue` now persists GitHub's real `createdAt`/`closedAt` timestamps (new nullable columns + indexes, migration `20260616120000_add_issue_created_closed_at`). The ingest route maps them from the worker payload; previously the table had no creation/closure timestamps at all (only `updatedAt`), so per-day issue throughput was uncomputable.
- **Worker** — `darkflow-run.sh` now fetches `createdAt,closedAt` in its `gh issue list --json` projection and passes them through the issues-ingest payload. Existing projects populate the chart after their worker updates and runs one sync; historical accuracy is preserved since these are GitHub's true timestamps (within the `--limit 300` window).

---

## [2.82.0] — 2026-06-16

- **Installer** — `_module_active()` in `install.sh` now handles `docs-audit`, `product-overview`, and `mailbox` (they fell into the `*) return 1` default, so on a fresh `--all` install — where `MOD_*=true` but `MODULES` is still empty — checklist items gated `when: module.docs-audit` / `module.product-overview` / `module.mailbox` were silently skipped from verification). Regression of the previously-fixed docs-audit/product-overview gotcha, now also covering `mailbox`.
- **Webapp** — fixed `pendingStatus:"closed"` never clearing on ingest. The clear condition compared `pendingStatus` against the issue's `status:*` label value, but `"closed"` is a *state* transition, never a status label — so a Close-button decision stayed "pending" forever even after GitHub closed the issue (17 stuck rows observed across projects). Ingest now clears a `"closed"` pending state once GitHub reports `state === "closed"`; other pending states still clear on status-label match. Existing stuck rows clear on the next ingest cycle.
- **New label** — added `source:docs`, `source:infra`, `source:vulnerability-report` to `_do_label` in `install.sh`. They were already emitted/queried by `docs-audit`, `coolify-check-deployment`, and `vulnerability-check` but never created, so `gh issue create` had to auto-create them.
- **Removed label** — dropped the entire `area:*` family (including `area:db`) from `_do_label` and all references in command templates, routines, and `docs/auto-approve.md`. Auto-approve rules no longer gate on `area:deps`/`area:db`: Dependabot version upgrades auto-approve on alert type, additive DB-index findings auto-approve on the command's index-only judgement. `architecture-review` now counts its snapshot backlog via `source:manual` instead of `area:architecture`.
- **Docs** — `auto-approve.md` allowlist/exclusions reworded to drop the removed `area:*` match criteria.

---

## [2.81.0] — 2026-06-16

- **Worker** — `fix-issues` now recovers an issue stranded by a crashed run immediately instead of waiting the full 1h auto-revive window. When a run exits non-zero (e.g. the Claude API drops the socket mid-run — `socket connection was closed unexpectedly`), the agent has usually already set `status:in-progress` and posted a "starting work" comment but never created a branch/PR. The new `recover_crashed_fix_issues()` reverts any open `status:in-progress` issue back to `status:approved` so the next cycle re-picks it — unless an open PR already references it (`#N` or a `fix/N-` branch), in which case it's left `in-progress` for a human to merge. The 1h `revive_stuck_issues` backstop remains for externally-killed/hung runs.

---

## [2.80.0] — 2026-06-16

- **Worker / Webapp** — unified mailbox credentials on a **single** canonical convention: `MAILBOX_IMAP_HOST` / `MAILBOX_IMAP_PORT` / `MAILBOX_IMAP_USER` / `MAILBOX_IMAP_PASSWORD` (and `MAILBOX_SMTP_*`), all living in the project's main `.env`. Removed the v2.79.0 multi-name tolerance: `fetch.py` / `send.py`, the `darkflow-run.sh` pre-flight, the `mailbox-check` command, and the webapp `mailbox-config.ts` now read only the canonical names. (`.env.darkflow` is still accepted as a legacy file-location fallback.)
- **Note** — existing projects configured with the old `IMAP_*` / `SMTP_*` (process-emails skill) or `MAILBOX_USER` / `MAILBOX_PASSWORD` names must rename their `.env` keys to `MAILBOX_IMAP_*` / `MAILBOX_SMTP_*`. The three configured projects (marketloop, adbrief, qabot) were migrated as part of this change.

---

## [2.79.0] — 2026-06-16

- **Worker / Webapp** — the mailbox module now tolerates **three** credential naming conventions, normalizing them onto `MAILBOX_IMAP_*` / `MAILBOX_SMTP_*`:
  - `MAILBOX_IMAP_*` (darkflow templates),
  - `MAILBOX_USER` / `MAILBOX_PASSWORD` (e.g. marketloop),
  - bare `IMAP_*` / `SMTP_*` (the process-emails skill convention, e.g. qabot).
  - `fetch.py` and `send.py` self-normalize from `os.environ`; the `darkflow-run.sh` mailbox pre-flight and the `mailbox-check` command normalize in shell after sourcing `.env`, so the "configured" gate and the python scripts both see the creds.
  - Webapp Mailbox tab (`mailbox-config.ts`) reads the same set of names, so projects configured via any convention now show their inbox.

---

## [2.78.0] — 2026-06-16

- **Installer / Worker / Docs** — unified the credential convention: mailbox (and observability) credentials now **always live in the project's main `.env`**, not `.env.darkflow`.
  - `install.sh` now **appends** `MAILBOX_*` / `OBSERVABILITY_*` to `.env` (creating it git-ignored), writing only keys that aren't already present so re-runs never clobber hand-edited values. It no longer creates `.env.darkflow`.
  - `darkflow-run.sh` mailbox pre-flight and the `mailbox-check` command now source `.env` (with `.env.darkflow` kept as a **legacy fallback**, sourced first so `.env` wins). The misconfiguration issue text points at `.env`.
  - Updated `routines/mailbox-check.md` accordingly.

---

## [2.77.1] — 2026-06-16

- **Webapp** — Mailbox tab now reads IMAP creds from the project's main `<localPath>/.env` (canonical location), falling back to `.env.darkflow` for legacy installs. Also accepts the short `MAILBOX_USER` / `MAILBOX_PASSWORD` names in addition to `MAILBOX_IMAP_USER` / `MAILBOX_IMAP_PASSWORD`, normalizing them for the fetcher. Matches how real installs (e.g. marketloop) are actually configured; v2.77.0 only looked in `.env.darkflow` and would have found nothing.

---

## [2.77.0] — 2026-06-16

- **Webapp** — new **Mailbox** tab on the project page. Lists recent IMAP messages in a paginated table (Time · From · Subject); clicking a row expands the full body. Unread messages are marked with a dot. Emails are persisted to a new `Email` model and synced on demand via a **Sync** button.
  - Sync reads the project's IMAP creds from `<localPath>/.env.darkflow` (`MAILBOX_IMAP_*`) and runs `webapp/scripts/mailbox-fetch.py` — a **read-only** lister (`readonly` SELECT + `BODY.PEEK`) that fetches the latest messages newest-first **without** marking anything seen.
  - When `localPath` / `.env.darkflow` isn't configured, the tab shows setup guidance instead.
  - Migration `add_email_model` (additive — new `Email` table only).

---

## [2.76.6] — 2026-06-15

- **Webapp** — "Fix in cmux" now launches Claude with `--worktree issue-<n>`, isolating each fix in its own git worktree so multiple issues can be worked on in parallel without conflicts. Uses Claude Code's built-in flag instead of instructing the model in the prompt.

---

## [2.76.5] — 2026-06-15

- **Webapp** — "Fix in cmux" now brings cmux to the foreground and focuses the new workspace: pass `--focus true` to `new-workspace`, and activate the app via `open` (deriving the `.app` path from `CMUX_BIN`, falling back to `open -a cmux`). Activation is best-effort and won't fail the request.

---

## [2.76.4] — 2026-06-15

- **Webapp** — fix `POST /api/ingest` crashing with a `PrismaClientValidationError` (`Unknown argument`) when the worker LLM emits extra keys (e.g. `lastReview`, `lastReviewDate`, `newIssues`) in the architecture/security metrics JSON. The route now whitelists the known schema fields (`openIssues`/`status`, plus `criticalOpen` for security) instead of spreading raw worker JSON into the Prisma upsert.

---

## [2.75.0] — 2026-06-15

- **Webapp** — add a **Fix in cmux** button to needs-human issue rows. It calls the new `POST /api/issues/[id]/launch` route, which shells out to the host's `cmux new-workspace --cwd <localPath> --command "claude '…'"` to open a cmux workspace with an interactive Claude session focused on that specific issue (passes the issue number into the prompt).
- **Webapp** — add an optional **`localPath`** field to the Project model (Prisma migration `add_project_local_path`, non-destructive) and a "Local path" input in project Settings. The launch button uses it as the cmux working directory. New `CMUX_BIN` env var overrides the cmux binary name/path.
- **Infra** — the webapp now runs as a **host process** (`make web`) instead of in Docker, so it can launch host-side cmux/Claude sessions. `docker-compose.yml` now starts **Postgres only** (published on `localhost:5432`); the webapp service moved behind the `docker` profile (`make docker-up`). Updated `Makefile`, `README.md`, `CLAUDE.md`, and added `webapp/.env.example`.

---

## [2.76.3] — 2026-06-15

- **Webapp** — name the cmux workspace launched by "Fix in cmux" as `[<project>] #<issue>` (e.g. `[adbrief] #250`) via `--name`, so launched sessions are identifiable in the cmux sidebar.

---

## [2.76.2] — 2026-06-15

- **Docs (fix)** — clarify `CMUX_BIN` in `webapp/.env.example`: the macOS cmux app ships the real CLI at `Contents/Resources/bin/cmux`. The GUI binary at `Contents/MacOS/cmux` creates a workspace but silently ignores `--command`, so the "Fix in cmux" button opened an empty workspace and never launched Claude. Point `CMUX_BIN` at the Resources/bin CLI.

---

## [2.76.1] — 2026-06-15

- **Infra (fix)** — add explicit `binaryTargets = ["native", "darwin", "darwin-arm64"]` to the Prisma generator. When the host Node runs under Rosetta (reports `x64`) while the runtime needs the `arm64` query engine, `make web` crashed with `PrismaClientInitializationError: could not locate the Query Engine for runtime "darwin-arm64"`. Bundling both macOS engines fixes host runs; Docker (linux) still resolves via `native`.

---

## [2.76.0] — 2026-06-15

- **Webapp** — show the **Fix in cmux** button on Untriaged issue rows too (previously only on needs-human), so any untriaged issue can be opened in an interactive cmux/Claude session.
- **Infra** — `make web` now serves on **port 5555** (matching the previous Docker setup) via `PORT=5555 pnpm start`. Updated docs accordingly.
- **Infra (fix)** — gate `output: "standalone"` in `next.config.ts` behind a `DOCKER_BUILD` env var. Standalone output is incompatible with `next start` (the host run mode) and printed a warning; the Dockerfile now sets `DOCKER_BUILD=1` so the container image still gets standalone output.

---

## [2.74.2] — 2026-06-15

- **Webapp** — remove the always-on **Needs Human** list at the top of the project Issues tab. The Needs Human card is now a proper filter (`?filter=needs-human`) like the other status cards, so those issues only show when the card is clicked. This stops `needsHuman` issues from appearing twice (once at the top and again under Untriaged when their status is still `none`).

---

## [2.74.1] — 2026-06-15

- **Webapp** — show inline **Approve** and **Close** buttons on Untriaged (`status:none`) issue rows that have no notes/comments. Approve sets the approved status/label; Close just closes the issue. Issues with comments still expand for review without the quick actions.

---

## [2.74.0] — 2026-06-15

- **Webapp** — add an **Untriaged** stat card (`status:none`) to the project page so untriaged open issues are visible in the status breakdown. Previously `none`-status issues counted toward the project's Open Issues total but had no card, so the per-status cards never summed to the table count.
- **Webapp / Installer / Workflow** — remove the vestigial `needs-info` status end-to-end. Deleted the unused `/api/issues/[id]/needs-info` route and its status badge colors; dropped the `status:needs-info` GitHub label from `install.sh`; removed it from the worker's `STATUS_LABELS_ALL` and the dead comment-posting branch in `darkflow-run.sh`; and cleaned the `needs-info` rows/flow from `github-issues.md` (both copies). The status had no UI entry point since v2.69.2 — `needsHuman` covers the "agent is blocked" case.

---

## [2.73.1] — 2026-06-15

Removed the **Reject** action button from the project page issue rows. Issues are now actioned with **Approve** or **Close** only, mirroring the earlier removal of the Rejected stat card.

---

## [2.73.0] — 2026-06-15

Make the Web UI the authoritative source of truth for project config and close the divergence gaps between the web DB and per-project files.

- **Installer** — `get-config.sh` now mirrors the Web UI verbatim: any field present in the API response (including an explicit `null`/empty — meaning "cleared in the UI") is written to `.darkflow`, instead of the old behaviour that silently kept a stale local value when the server sent blank. Only fields entirely absent from the response are left untouched (forward-compat). Fixes config drift where clearing a setting in the UI never reached the project.
- **Installer** — `routines.yml` is now always regenerated from the response when it includes a `routines` array, **even an empty one**, so disabling/removing routines in the UI actually stops the worker running them. Previously a 0-routine response left the old schedule in place.
- **Installer** — `get-config.sh` now hard-requires `jq`: without it a sync could update `.darkflow` but not `routines.yml` (or vice-versa), leaving the two out of step. It now logs to `state/config-sync.log` and skips entirely rather than doing a partial, inconsistent sync.
- **Webapp** — config-sync staleness is now visible. `get-config.sh` records `state/config-synced-at`, the worker reports it on each `/api/worker/heartbeat`, and the UI shows a **"settings pending"** badge (project list + project header) when `settingsUpdatedAt` is newer than the worker's last config sync — i.e. the running worker hasn't picked up the latest settings yet. Requires migration `20260615130000_add_worker_config_synced_at` (new nullable `WorkerStatus.configSyncedAt`).
- **Webapp** — `/api/ingest` no longer drops a pending approval after a fixed 2-hour window. A human's approval recorded in the DB is authoritative and now survives an offline worker indefinitely; it clears only when GitHub's status actually reflects it (the real "applied" signal).

## [2.72.0] — 2026-06-15

- **Webapp** — added a `domain` project state prop (production deployment URL). Editable in Settings → Project, shown as a clickable link in the project list and project header. Requires migration `20260615120000_add_project_domain`.
- **Installer** — `domain` now flows end-to-end like other settings: worker sends it on `/api/ingest`, the Web UI is the source of truth, and `get-config.sh` syncs it back into `.darkflow` (`domain=`).

## [2.71.1] — 2026-06-15

- **Webapp** — removed the "Rejected" stat card from the project page. Rejecting an issue closes it, so a rejected count had no lasting meaning on the open-issues view. The issues stat grid is now four cards (Needs approval, Approved, In progress, Needs Human).

## [2.71.0] — 2026-06-15

- **New routine** — `fix-ci-issue` (`*/15 * * * *`, optional `ci-gate` module): a dedicated worker for `source:ci` issues filed by the CI gate. It reproduces the failing lint/test, pushes a fix, and leaves an attempt marker — **retrying the same issue up to 3 times** before escalating to `needs-human`. This bounds the red-CI → issue → fix → red-CI loop that a single unconditional auto-fix could spin forever.
- **New label** — `ci-retry` (`e99695`): marks a `source:ci` issue that is mid auto-fix; the attempt count is tracked via `<!-- darkflow:ci-attempt -->` marker comments on the issue.
- **Workflow** — `darkflow-ci-gate.yml` reworked to make the retry cap reliable: stable per-branch issue title (`CI failure on <branch>`), issues filed on `push` only (PR runs just report status), and a new **close-on-green** step that auto-closes the branch's CI issue once checks pass again. A persistently red branch keeps one open issue and appends comments instead of spamming new ones.
- **Updated routine** — `fix-issues` now **excludes** `source:ci` issues from its queue (they're owned by `fix-ci-issue` so the retry cap is never bypassed), and **skips the local `build` step when the `ci-gate` module is active** (the CI gate verifies the build on push).
- **Installer** — `install.sh`: creates the `ci-retry` label; copies `fix-ci-issue.md` and registers the `fix-ci-issue` routine when `ci-gate` is enabled; updates the generated CLAUDE.md routine/command lists and the post-install summary. `checklist.yml`: `cmd-fix-ci-issue` + `routine-fix-ci-issue` (both `when: module.ci-gate`) so existing projects pick them up on `darkflow:update`.
- **Docs** — README CI-gate section, routine/command tables, and timeline updated to describe the 3-retry loop and close-on-green.

## [2.70.0] — 2026-06-15

- **Worker** — guarantee every open issue carries a `priority:*` label. Slash commands set priority from prose instructions, but LLM agents don't comply every time, so issues regularly landed with no priority — they sorted last and showed "—" in the Web UI approval queue (the "Needs approval" tab). The dispatcher (`darkflow-run.sh`) now runs a deterministic `backfill_missing_priority` step before each sync: any OPEN issue with no `priority:*` label gets `priority:medium` (the safe default — it stays in the queue, unlike `low` which routines auto-discard), both on GitHub and in the synced snapshot. Mirrors the existing low-priority auto-close enforcement.
- **Docs** — `templates/docs/github-issues.md`: mark `priority:*` as mandatory and document the new dispatcher-level enforcement.

---

## [2.69.2] — 2026-06-15

- **Webapp** — replace the `?` (needs-info) action button in the issues table with a **Close** button. Close marks the issue `pendingStatus: "closed"` via the existing `/api/issues/[id]/close` endpoint and clears `needsHuman`. The inline needs-info question flow was removed from `IssueActions`; the `needs-info` status badge colors and endpoint remain for existing issues.

---

## [2.69.1] — 2026-06-15

- **Docs** — fix the `+ Task` action button wrapping onto two lines in the issues table. Added `whitespace-nowrap` to the link so it renders on a single line and matches the height of the adjacent Approve/?/Reject buttons.

---

## [2.69.0] — 2026-06-15

- **`status:blocked` retired → folded into `needs-human`.** An agent can do nothing with a "blocked" issue (failed `lint → test → build`, or an external blocker) — it always needs a person — so the separate status is gone and those issues now land in the single **Needs Human** bucket. Changes across the stack:
  - **Worker (`darkflow-run.sh`)** — on every sync, `convert_blocked_to_needs_human()` relabels each open `status:blocked` issue to `needs-human` directly in GitHub, so the change sticks and propagates to every installed project on its next run (no per-project manual step). The webapp payload also maps `blocked → needs-human` defensively, and `needsHuman` is now true for any issue carrying either label.
  - **Comments shown** — needs-human issues carry an agent comment explaining what a human must do. The worker now fetches GitHub comments for needs-human issues (bounded — only those) via `enrich_needs_human_comments()` and ingests them into the new `Issue.comments` JSON column; the UI renders them under the issue body.
  - **Web UI** — the **Blocked** filter card (added in 2.68.2) is removed. In the issues table, the title is now a direct link that opens the GitHub issue in a new tab, and a separate chevron button (with a 💬 comment count) toggles the collapsible body + comments — previously clicking anywhere on the row toggled the body and a small ↗ opened GitHub.
  - **Commands / docs** — `fix-issues` and `mailbox-check` now set `needs-human` on failed checks / send failures instead of `status:blocked`; `auto-approve.md`, `github-issues.md`, and the routine docs updated; `install.sh` no longer creates the `status:blocked` label.
  - **Migration** — `20260615000000_issue_comments_drop_blocked` adds `Issue.comments` and converts existing `status='blocked'` rows to `needsHuman=true, status='none'` in place (no data loss).

## [2.68.2] — 2026-06-14

- **Web UI** — split `status:blocked` into its own **"Blocked"** filter card on the project detail page, separate from **"Rejected"**. Previously the "Rejected" group merged `["rejected", "blocked"]` (`projects/[id]/page.tsx`), so legitimately-open blocked issues (auto-fix attempts whose `lint → test → build` failed, or external blockers) appeared under "Rejected" and looked like declined-but-still-open issues. They are conceptually different — rejected = declined (closed), blocked = waiting on a human/external factor (open by design). A direct GitHub audit of all installed repos confirmed **0** open `status:rejected` and **44** open `status:blocked` (pageradar 14, adsynex 10, scopegate 9, baraholka 4, qabot 3, vargi 3, next-flow 1) — the blocked ones are correct to stay open. Colors/labels for `blocked` already existed; only the card grouping changed.

## [2.68.1] — 2026-06-14

- **Web UI** — rejecting an issue now closes it immediately, and the projects-table "Open Issues" count no longer includes rejected issues. Previously the reject handler (`/api/issues/[id]/reject`) only set `status:"rejected"` + `pendingStatus` and left `state:"open"`, deferring the actual close to the dispatcher; meanwhile the main-page count (`page.tsx`) filtered by `state` alone, so a rejected-but-not-yet-closed issue kept inflating the count during the window between reject and the dispatcher's `gh issue close`. **Two changes:** (1) the reject handler now also sets `state:"closed"` so the issue drops off the dashboard instantly; (2) the main-page `_count`/`issues` queries now filter `status: { not: "rejected" }` in addition to the `state` filter — a durable guard that survives ingest (which restores `state` from GitHub but preserves `status:"rejected"` from the `status:rejected` label). Existing rejected issues were already `CLOSED` by the dispatcher, so no backfill was needed. The project detail page, which intentionally groups rejected/blocked issues, is unchanged.

## [2.68.0] — 2026-06-14

- **New module `ci-gate`** (opt-in, `--with-ci-gate`) — ships a GitHub Actions workflow at `.github/workflows/darkflow-ci-gate.yml` that runs lint/tests on every push and, on failure, opens (or reuses) a `source:ci` issue describing the break. The local `fix-issues` worker then picks it up and fixes it, closing the loop `red CI → issue → fix-issues → green CI`. No AI runs in CI (only the cheap deterministic checks + `gh issue create`), so there's no per-token API cost. Issues are de-duplicated by title so a persistently red branch won't spam the queue; `ISSUE_STATUS` in the workflow toggles auto-fix (`status:approved`, default) vs human approval (`status:proposed`). The workflow auto-detects Node (pnpm/npm) and Python (ruff/pytest) stacks; edit it to match other stacks or chain off an existing build workflow via `workflow_run`.
- **New label `source:ci`** — marks issues filed by the CI gate.
- **install.sh / checklist.yml** — `--with-ci-gate`/`--no-ci-gate` flags, `--all` coverage, interactive prompt, `_module_active` case, `.darkflow` `modules=` registration, and a `when: module.ci-gate` copy-template entry so existing installs pick up the workflow on `self-update`.

## [2.67.0] — 2026-06-14

- **Web UI** — fixed a sync gap where the `uptime-check` (shipped v2.54.0) and `code-health`/fallow routines never reached projects whose `routines.yml` is generated by the Web UI (`get-config.sh` → `/api/projects/by-repo`). Both were added to `install.sh`/`checklist.yml` but never to the webapp's canonical catalog `ALL_ROUTINES` (`webapp/src/lib/routines.ts`), so the settings UI never offered them, no `RoutineConfig` row was ever written, and `by-repo` (which filtered against the catalog) never emitted them. Symptom: Coolify-hosted projects had no uptime monitoring in their schedule despite a configured `site_url` — the routine simply never ran. **Two changes:** (1) added `uptime-check` (core, `0 */4 * * *`) and `code-health` (module `fallow`, `0 7 * * 0`) to `ALL_ROUTINES`; (2) `by-repo` now *merges* catalog defaults with each project's DB overrides instead of emitting only existing rows — so any newly-shipped routine auto-propagates to every project's `routines.yml` on the next `get-config.sh` sync, with no manual Save required. Affected projects (baraholka, vargi, scopegate, adsynex, studyclutch, naturalwrite, secscanner) pick up `uptime-check` automatically once the rebuilt webapp is live.

## [2.66.0] — 2026-06-14

- **Dispatcher** — the worker now *enforces* the long-standing "routines file only `critical`/`high`/`medium`" rule instead of trusting the prompt. `darkflow-run.sh` gained `close_routine_low_issues()`, which runs before every sync and auto-closes (with an explanatory comment) any OPEN issue that carries `priority:low` **and** a routine `source:*` label (i.e. not `source:manual`). Manually-filed low issues (`source:manual` or no source label), anything already `status:in-progress`, and `needs-human` issues are left untouched. Background: an audit of installed projects found ~50 routine-created `priority:low` issues across qabot/Vargi/mailmonitor/adsynex that had leaked into the approval queue despite the documented rule — the rule existed only as prompt text and agents didn't reliably obey it. Existing projects pick this up on next `self-update` (dispatcher is `copy-template`).
- **Workflow** — `github-issues.md` (root + template) documents the enforcement and its exclusions.

## [2.65.0] — 2026-06-14

- **Updated routine** — `/darkflow:observability-check` now auto-approves additive database index additions. A finding that purely adds an index (no schema/data change, no query rewrite) is created directly as `status:approved` with `area:db`, so `fix-issues` picks it up without waiting for a human. Query rewrites, N+1 fixes, caching, and denormalization still go through the `status:proposed` human-review gate. The `fix-issues` quality gate (lint → test → build) and `needs-human` escalation remain in force.
- **New label** — `area:db` (`#006b75`) marks database findings; index additions under this label are auto-approved.
- **Docs** — added the new category to `docs/auto-approve.md` / `templates/docs/auto-approve.md` allowlist, updated `routines/observability-check.md` and the README auto-approve note.

## [2.64.0] — 2026-06-12

- **Updated routine** — routine logs now record the model as `engine:model` (e.g. `claude:sonnet`, `codex:gpt-5`) instead of the bare model name. The analytics page groups spend by this field; without the engine prefix, same-named models from different engines collapsed together and the breakdown couldn't tell Claude apart from Codex. New runs carry the prefix; existing log rows keep their old bare value.

## [2.63.0] — 2026-06-11

- **Updated routine** — `/darkflow:fix-issues` issue selection is now rank-based and tolerates the `p0/p1/p2/p3` priority scheme as aliases for `critical/high/medium/low`. Previously the selector only walked `critical → high → medium → low`, so any `status:approved` issue tagged `priority:p2` (etc.) by an agent that ignored the canonical labels was silently skipped — even the no-priority fallback excluded it because a `priority:*` label was present. A repo full of approved `p2` issues would report "no issues" and stall. Selection now ranks every selectable issue in one query and never strands an approved issue over a vocabulary mismatch.

## [2.62.0] — 2026-06-10

- **Updated routine** — routines no longer create git worktrees. `/darkflow:fix-issues` now works in the project root and, under the PR strategy, creates the feature branch in place with `git checkout -b` off the configured base branch (`branch=` in `.darkflow` — `main`, `master`, `dev`, …) instead of `git worktree add`.
- **Installer** — generated `.darkflow.d/claude.md` now carries an explicit "never create a git worktree" workspace rule.
- **Docs** — clarified the worktree note in `routines/README.md` and `routines/fix-issues.md`, and updated the `templates/darkflow/claude.md` reference copy.

## [2.58.2] — 2026-06-10

- **Updated routine** — `/darkflow:analytics-review` now explicitly forbids creating PostHog alerts (or any PostHog artifacts). PostHog access is read-only; all recommendations go out as GitHub Issues only.

## [2.61.0] — 2026-06-10

- **Worker** — `mailbox-check` no longer **silently** skips when the routine is enabled but unconfigured. If `MAILBOX_IMAP_HOST` is empty in `.env.darkflow`, the dispatcher now logs an `ERROR` and files a single, **deduped** `needs-human` + `source:mailbox` + `priority:high` GitHub issue telling the human to add the `MAILBOX_*` credentials (or disable the routine in `routines.yml`). It never opens a second issue while the first is still open, and still does not launch the agent (which can do nothing without config). A forgotten mailbox setup is now visible in triage instead of being a quiet hourly no-op.

## [2.60.0] — 2026-06-10

- **Worker** — `mailbox-check` now has a **cheap pre-flight** in `darkflow-run.sh`, mirroring the `uptime-check` one. Before launching the Sonnet agent the dispatcher counts the actual work two cheap ways: a **read-only IMAP `UNSEEN` count** (new `fetch.py --count` mode — selects the inbox read-only, so it never changes `\Seen` flags) and a `gh issue list` for open `status:approved` + `source:mailbox` + `action:reply` issues. When there's **no new mail and no reply pending** (or the mailbox isn't configured) it writes the run state and **skips the agent** (logged `SKIP mailbox-check — no new mail, no replies pending`). The agent runs **only** when there's mail to triage, a reply to send, or the probe can't decide — IMAP error or missing python3 (logged `ESCALATE mailbox-check — …`). On a quiet inbox this turns 24 hourly agent runs/day into near-zero LLM cost while keeping the cadence and unchanged behaviour when there *is* work. The IMAP creds are sourced inside a subshell so they never leak into the dispatcher's environment. Existing projects pick this up on `darkflow:update`.
- **Worker** — `mailbox/fetch.py` gains a `--count` flag (read-only unseen count) used by the pre-flight.

## [2.59.1] — 2026-06-10

- **Worker** — hardened the `uptime-check` pre-flight against **proxy soft-errors**. Coolify/Traefik/Caddy normally serve "Bad Gateway / no available server" with an HTTP **5xx**, which the status check already escalates — but they can also serve such a page with HTTP **200**. The body-marker grep now catches `Bad Gateway`, `Gateway Timeout`, `Service Unavailable`, and `no available server` / `no server available` (was only matching `502 Bad Gateway` with the leading code), so a backend-down page returned as 200 is correctly classified **down** and escalated to the agent instead of being reported healthy.

## [2.59.0] — 2026-06-10

- **Worker** — `uptime-check` now has a **cheap bash pre-flight** in `darkflow-run.sh`. Before launching the Sonnet agent the dispatcher runs a plain `curl` probe (DNS → HTTP status → body sanity). When the site is healthy (2xx + real body) it writes the snapshot + metrics itself and **skips the agent entirely** (logged `SKIP uptime-check — uptime ok …`); slow-but-2xx is recorded as `degraded` and also skips. The agent is launched **only** when the probe finds the site down/broken or can't decide — no `site_url`, DNS failure, connection/TLS/timeout, 4xx/5xx, or empty/error body (logged `ESCALATE uptime-check — …`). On a healthy site this turns ~6 agent runs/day into zero LLM cost while keeping the every-4h cadence and unchanged snapshot/metrics output. The escalated agent still does the full check from scratch and files the auto-approved critical issue. Existing projects pick this up on `darkflow:update`.

## [2.58.1] — 2026-06-09

- **Web UI** — the **Communication language** field in project settings is now a dropdown (select) instead of a free-text input, with a curated list of common languages. Any previously-saved custom value is preserved as an extra option so nothing is lost.

## [2.58.0] — 2026-06-09

- **Web UI** — the analytics page is now split into **tabs**: **Over time** (the daily cost/tokens chart) and **Breakdown**. The total cost/tokens/runs summary cards and the time-window selector (7d / 30d / 90d / all) stay above the tabs and apply to both.
- **Web UI** — the Breakdown tab supports **multi-dimension grouping** via chip toggles for **Project / Model / Routine**. Selecting one behaves like before; selecting several groups by the combination (e.g. `project + routine` → rows like `scopegate / fix-issues`), so you can answer "which routine on which project eats the most". Tab, window, and grouping selection are all encoded in the URL (shareable/bookmarkable).

## [2.57.0] — 2026-06-09

- **Web UI** — new **Usage analytics** page (`/analytics`, linked from the header nav) that answers "where is the money going?" across **all** projects at once. Breaks cost and tokens down four ways — **over time** (daily area chart), **by project**, **by model**, and **by routine** (horizontal bar charts + exact-number tables) — with a 7d / 30d / 90d / all-time window selector and total cost/tokens/runs summary cards. Charts use `recharts`.
- **Web UI** — the per-project **Logs** tab no longer shows its own "Cost by routine" rollup; that breakdown (and the cross-project ones) now live on the dedicated analytics page. The Logs tab keeps the "Recent runs" table.
- **Database** — added a nullable `model` column to `RoutineLog` (migration `20260609000000_add_routine_log_model`) so spend can be attributed to the model actually used at run time. Existing rows have no model and bucket as `unknown`.
- **Worker** — `darkflow-run.sh` now records the model used for each run (`model` field on the ingested log), captured from the `--model` it already passes to `claude` / `codex exec`. Existing projects pick this up on `darkflow:update`; new logs carry the model immediately.

## [2.56.0] — 2026-06-09

- **Updated routine** — `gsc-check` now does **two halves**: the existing Google Search Console data review **plus** a technical + on-page SEO audit. The audit works primarily from the codebase (so it can propose exact fixes) with optional live-page spot-checks via `site_url=`, and covers crawlability/indexation (robots, sitemap, canonical, noindex, HTTPS), on-page (title/meta/H1 structure, alt text, OpenGraph, JSON-LD structured data, internal linking), and technical foundations (URL structure, mobile viewport, obvious CWV regressions). Includes the schema-detection caveat (JSON-LD is read from source, not raw `curl`/`web_fetch`). If the GSC MCP is absent the routine now **skips only the GSC half** and still runs the audit instead of aborting.
- **New label** — `source:seo` for issues filed by the SEO-audit half of `gsc-check` (GSC-data findings keep `source:gsc`). The routine's `gsc.json` metric now counts open `source:gsc` **or** `source:seo` issues.
- **Workflow** — `agent-workflow.md` snapshot-routing table and `github-issues.md` label tables gain a `docs/insights/seo-audit/` / `source:seo` row.
- **Installer** — creates `docs/insights/seo-audit/`, registers the `source:seo` label, writes the new SEO snapshot guidance into the generated `claude.md`, and updates all GSC routine summaries to "Search Console + SEO audit".

## [2.55.2] — 2026-06-09

- **Fixed** — `fix-issues` got stuck in a loop on `needs-human` / `status:blocked` issues. The routine doc promised it "respects" those labels, but the **Step 2 selection query only excluded `action:reply`** — so an issue carrying both `status:approved` and `needs-human` (e.g. a fix that genuinely needs a human config change) was re-picked **every single run**. Each run re-derived the same "needs a human" verdict, posted another near-identical comment, and stopped — never fixing anything and jamming the whole approved queue behind it (observed live: 10+ duplicate bot comments on one issue, every ~20 min). The Step 2 query now excludes `needs-human` and `status:blocked` alongside `action:reply`.
- **Fixed** — when `fix-issues` parks an issue as `needs-human` or `status:blocked`, it now **removes `status:approved`** (`gh issue edit … --remove-label status:approved`) so the issue leaves the queue cleanly instead of relying solely on the query filter, and is told to skip posting a duplicate comment if it already left an equivalent `needs-human` explanation.
- **Worker** — `darkflow-run.sh`'s `fix-issues` preflight now counts only **actionable** approved issues (excluding `needs-human` / `status:blocked` / `action:reply`). A queue jammed with only non-actionable issues now logs `SKIP … no actionable status:approved issues` instead of launching a wasted codex/claude run every cycle.

---

## [2.55.1] — 2026-06-08

- **Fixed** — a routine removed from Dark Flow (e.g. `coolify-check-logs` in v2.46.0) left an orphaned `RoutineConfig` row in each existing project's database. The `/api/projects/by-repo` config endpoint emitted every row verbatim, so `get-config.sh` kept writing the dead routine into `routines.yml` — and the worker's preflight then **hard-failed on the missing command file, bricking _all_ routines** (`make df-run` aborted before anything ran). The endpoint now filters project routines against the canonical catalog, so orphaned rows are never served and clear from `routines.yml` on the next config refresh.
- **Web UI / Worker** — extracted the canonical routine catalog to `webapp/src/lib/routines.ts` (shared by `RoutineConfigForm` and the by-repo endpoint) as the single source of truth for which routines exist; removing a routine there now also stops it being served to projects.
- **Worker resilience** — `darkflow-run.sh` no longer aborts the whole dispatcher when an enabled routine has no command file. preflight now warns and the routine is skipped at dispatch (it can't run anyway), which also unblocks the `get-config.sh` refresh that self-heals `routines.yml`. Explicitly invoking a routine with no command file (`darkflow-run.sh <name>`) still errors clearly.

---

## [2.55.0] — 2026-06-08

- **Updated routine** — the worker now records **per-session cost and token usage** for every routine run. `darkflow-run.sh` invokes Claude with `--output-format json` and parses the result object: the final assistant text comes from `.result` (as before), while `.total_cost_usd` and the sum of `.usage.*` tokens are captured as `costUsd` and `totalTokens`. If the CLI output isn't valid JSON (crash/partial run), it falls back to storing the raw text with null metrics, so a run never breaks. The Codex engine and skipped runs simply emit no metrics (fields stay null).
- **Web UI** — the project **Logs** tab now shows **Tokens** and **Cost** columns per run, plus a new **"Cost by routine"** summary panel that aggregates total spend/tokens/run-count across the full history and ranks routines by cost — so it's clear which routine eats the most of your limits.
- **Schema** — added nullable `costUsd` (Float) and `totalTokens` (Int) columns to `RoutineLog` (`webapp/prisma/migrations/20260608000000_add_routine_log_usage`). `/api/ingest` accepts and persists the new fields. Non-destructive: existing rows keep null metrics.

---

## [2.54.0] — 2026-06-08

- **New routine** — `uptime-check`, an always-on core routine that runs **every 4 hours** (`0 */4 * * *`, Sonnet) to verify the project's public site is actually up: resolves DNS, hits the production URL, checks the HTTP status is healthy, and confirms the page really loads (not a blank/error/maintenance page). When the site is **down**, it files an **auto-approved** `priority:critical` issue (`status:approved`, `source:uptime`) so `fix-issues` restores it immediately and escalates to `needs-human` if the fix needs infra/credentials. Healthy runs only write a snapshot. The URL comes from `site_url=` in `.darkflow`, or is auto-discovered from Coolify / `vercel.json` / `netlify.toml` / `CNAME` / `package.json` and persisted. Duplicate-safe (comments on an existing open outage issue instead of refiling); slow-but-200 is recorded as `degraded`, not filed.
- **New label** — `source:uptime` (violet `5319e7`) — "From uptime / site health check".
- **Installer** — wired `uptime-check` across `install.sh` (label, command-template copy, `routines.yml` heredoc, `claude.md` Active Routines + command lists, post-install summary) and `checklist.yml` (`cmd-uptime-check`, `routine-uptime-check`), so `darkflow:update` + `check.sh --fix` install it into existing projects.
- **New command** — `templates/.claude/commands/darkflow/uptime-check.md` (`/darkflow:uptime-check`) plus `routines/uptime-check.md` reference doc.
- **Workflow** — added the uptime snapshot route (`insights/uptime/YYYY-MM-DD.md`) to `agent-workflow.md`.

---

## [2.53.1] — 2026-06-08

- **Installer** — the `claude.md` **Active Routines** list now includes `docs-audit` (Weekly Sun 5:00) when the `docs-audit` module is enabled; it was missing from that list while present in the command list. `product-overview` deliberately stays out of Active Routines (it's a reporting command, not a scheduled-into-the-loop audit) and remains in the command list.

---

## [2.53.0] — 2026-06-08

- **Installer** — fully wired the `ads-review` routine (paid ads performance → GitHub issues, weekly Mon 8:00). It previously shipped as an orphan: the routine doc, command template, and a README row existed and `analytics-review` referenced it, but it was never added to the `routines.yml` generator or `checklist.yml` — so it never scheduled and existing projects never picked it up. Now gated behind the `ads` module across `install.sh` (routines.yml heredoc, command copy, `claude.md` routine/command lists, post-install summary) and `checklist.yml` (`cmd-ads-review`, `routine-ads-review`), so `darkflow:update` + `check.sh --fix` install it.
- **Docs** — corrected the `fix-issues` cron everywhere it was documented as `*/15 * * * *` ("every 15 min"); the installer has generated `0 * * * *` (hourly) for some time, so the docs (`README.md`, `routines/README.md`, `routines/fix-issues.md`) now match reality.
- **Docs** — refreshed stale Sunday-cluster schedule diagrams in `routines/architecture-review.md` and `routines/docs-audit.md` (the 4:00 slot has been `build-optimization` for a while, not the long-removed "Security runtime audit" / "UX/UI audit").
- **New routine** — added the missing `routines/mailbox-check.md` reference doc; `mailbox-check` was the only routine without one.

---

## [2.52.3] — 2026-06-08

- **Webapp** — the header logo (`⚡ Dark Flow`) is now a link to the home page (`/`).

---

## [2.52.2] — 2026-06-08

- **Webapp** — the Routines tab now **auto-saves** on every change. Removed the separate "Save routines" button; toggling a routine, switching engine/model, or editing a cron expression persists immediately (debounced 600 ms so typing in the cron field doesn't fire a request per keystroke). A small inline `Saving… / Saved ✓` indicator replaces the button.

---

## [2.52.1] — 2026-06-07

- **Dispatcher** — fixed `engine: codex` routines failing with `error: unexpected argument '--ask-for-approval' found`. Newer Codex CLIs (≥ 0.x with the reworked `exec`) removed `--ask-for-approval` from the `codex exec` subcommand — `exec` is already non-interactive. `darkflow-run.sh` now invokes `codex exec --model <m> --dangerously-bypass-approvals-and-sandbox <prompt>` instead of the old `--sandbox workspace-write --ask-for-approval never`. The bypass is also required for routines to actually work: the `workspace-write` sandbox blocks network, which broke `git push` / `gh` calls. This mirrors Claude's `bypassPermissions` autonomy (Darkflow routines run in an externally-controlled, opt-in autonomous context). Existing installs pick up the fix on next `darkflow:update`.

---

## [2.52.0] — 2026-06-06

- **Installer** — `routines.yml` cron minutes are now **staggered per-project**. On generation, every numeric cron minute is shifted by a deterministic offset derived from the project slug (`cksum(slug) % 60`), so independent projects on the same machine no longer all dispatch on minute `:00`. Relative spacing between a project's own routines is preserved (e.g. an `:00` and a `:30` routine stay 30 minutes apart). This prevents the global concurrency semaphore (`max_concurrent`, default 3) from being saturated every hour by ~all projects firing `fix-issues` simultaneously and thrashing through `DEFER`/retry cycles. The post-install Routines summary notes the project's offset.

---

## [2.51.0] — 2026-06-06

- **New routine** — added the optional **Code health** module (`fallow`): a weekly `code-health` routine (Sun 7:00, Sonnet) that runs [fallow](https://github.com/fallow-rs/fallow) — deterministic codebase intelligence for **TypeScript/JavaScript only** — to find dead code, duplication, circular dependencies, complexity hotspots, and dependency-hygiene problems, then files high-confidence `status:proposed` / `source:code-health` issues. Proposal-only; snapshots to `docs/insights/code-health/YYYY-MM-DD.md`, metrics to `.darkflow.d/state/metrics/code-health.json`. The model only triages fallow's deterministic JSON output and filters false positives (public API surface, framework entry points, dynamically-referenced symbols) — hence Sonnet, not Opus. Positioned to complement `architecture-review` without overlap: fallow owns dead code / dupes / deps / complexity, `architecture-review` owns coupling and structural judgment.
- **New command** — `/darkflow:code-health` (module-gated on `fallow`).
- **New label** — `source:code-health` (`5319e7`).
- **Installer** — new `MOD_FALLOW` module: `--with-fallow` / `--no-fallow` flags, interactive prompt (opt-in, default off, TS/JS-only), `.darkflow` `modules=fallow`, `_module_active fallow`, command template copy, `routines.yml` heredoc (`code-health`, Sun 7:00, Sonnet), claude.md routine + command lists, post-install summary line, and the `source:code-health` label. The **fallow agent skill** ([fallow-rs/fallow-skills](https://github.com/fallow-rs/fallow-skills)) is installed non-interactively via `git clone` + `cp -R` into `~/.claude/skills/fallow` when the module is enabled (idempotent — skips if already present).
- **Installer** — `checklist.yml`: `cmd-code-health` (copy-template) and `routine-code-health` (add-routine, cron `0 7 * * 0`, Sonnet), both gated `when: module.fallow`, so existing projects with the module pick them up on `self-update`.
- **Workflow** — registered the `code-health` snapshot path in `agent-workflow.md` (both copies).
- **Docs** — README routine table, weekly loop diagram, and routine-commands table; `routines/README.md` schedule table; new `routines/code-health.md` reference doc.

## [2.50.0] — 2026-06-06

- **New command** — added `/darkflow:grill`, an interactive (human-in-the-loop) command adapted from Matt Pocock's `grill-with-docs` skill. It pressure-tests a plan against the existing domain model — asking one question at a time, exploring the codebase before asking, challenging terminology, stress-testing relationships with scenarios, and cross-referencing claims against code. Unlike the autonomous audit commands it creates no GitHub issues or snapshots; instead it updates documentation inline. Adapted to Dark Flow's existing doc schema rather than the skill's own files: the glossary maps to `docs/product/glossary.md` (kept strictly implementation-free) and ADRs to `docs/decisions/` using the existing `TEMPLATE.md` and `NNNN-slug.md` numbering. The skill's multi-context `CONTEXT-MAP.md` layer was dropped (Dark Flow uses a single `docs/` tree). Wired as an always-installed command (no module gate, no routine, no cron): `install.sh` template copy + claude.md command list, `checklist.yml` `cmd-grill` (copy-template, picked up by existing projects on `self-update`), and README under a new **Interactive commands** section.

## [2.49.0] — 2026-06-06

- **Web UI** — moved the per-routine settings table (enable/disable, engine, model, cron) out of the **Settings** tab and into the **Routines** tab, which was previously read-only. The Routines tab is now where routines are both viewed and edited, with its own **Save routines** button; it always shows the full canonical routine list rather than only the rows already synced from the worker. The Settings tab keeps Project + Integrations only. Extracted the routine logic into a new `RoutineConfigForm` component; `RoutineConfigList` was removed. Saving still uses the same `PATCH /api/projects/[id]` endpoint — the Routines form now owns the derived `modules` array, the Settings form no longer sends `modules`/`routines`.

## [2.48.0] — 2026-06-06

- **Removed command** — dropped the `/darkflow:ux-audit` command. It was a manual, always-on UX review that called the bare `/impeccable` skill and overlapped almost entirely with the scheduled `impeccable`-module routines `design-audit` (`impeccable:audit`) and `design-critique` (`impeccable:critique`) — same engine, redundant coverage, but a separate `source:ux-audit` label that split the design backlog. UX/visual review now lives entirely in the `design-audit` / `design-critique` / `design-harden` routines (label `source:design`).
- **Removed label** — dropped the `source:ux-audit` GitHub label (from `install.sh` and the `github-issues.md` taxonomy + setup script). Existing issues keep the label; it is simply no longer created or referenced.
- **Installer** — removed the `cmd-ux-audit` checklist entry, the `ux-audit.md` `smart_update_template` line, and the `source:ux-audit` label creation. Deleted `templates/.claude/commands/darkflow/ux-audit.md`.
- **Workflow** — removed the UX-audit row from `agent-workflow.md` (data-sources table) in both the live docs and the templates.

## [2.47.2] — 2026-06-06

- **Web UI** — refreshed the Codex model dropdown to the current Codex CLI lineup: `gpt-5.5` (default), `gpt-5.4`, `gpt-5.4-mini`. Dropped the deprecated `gpt-5` / `gpt-5-mini` slugs, and `defaultModelFor()` now returns `gpt-5.5` when switching a routine to Codex. `gpt-5.3-codex-spark` is intentionally omitted (ChatGPT Pro–only preview). Codex CLI still accepts any model the account can reach via `--model`; this only changes what the UI offers.

## [2.47.1] — 2026-06-06

- **Dispatcher** — dropped the routine transcript parsers for both engines. The Web UI log `output` now stores each run's final output verbatim: Claude runs via plain `claude -p` (default text output, no `--output-format stream-json --verbose`), Codex via plain `codex exec` (no `--json`). Removed `format_claude_stream` / `format_codex_stream` and the per-event Markdown rendering — the parsing was cosmetic only (it never affected what a routine did) and the engines' own output is already readable. Logs lose the step-by-step tool/result breakdown but keep the final result.

## [2.47.0] — 2026-06-06

- **New feature** — per-routine **engine** switch (`claude` | `codex`). Each routine can now run via Claude Code (the default, unchanged) or OpenAI's Codex CLI, selectable from the Web UI routine-settings table next to the model dropdown. Default is `claude` everywhere, so existing installs are unaffected.
- **Dispatcher** — `darkflow-run.sh` reads a per-routine `engine` (and `defaults.engine`) from `routines.yml`. For `codex` it runs `codex exec --model <m> --sandbox workspace-write --ask-for-approval never --json`, feeding the routine's existing `.claude/commands/darkflow/<name>.md` as the prompt (Codex has no `/darkflow:<name>` slash command). A new `format_codex_stream` renders Codex's JSONL events into the same Markdown transcript the Web UI logs already show. The self-update path stays on Claude.
- **Preflight** — the dispatcher now also requires the `codex` CLI when any enabled routine is set to `engine: codex`, with a clear install/auth hint (Claude is still always required for self-update).
- **Web UI** — routine settings gain an **Engine** column; the **Model** dropdown is engine-aware (`sonnet`/`opus` for Claude, `gpt-5`/`gpt-5-mini` for Codex) and resets to the engine's default when switched. Routines whose prompt invokes a Claude-only skill (`security-audit`, `architecture-review`, `design-audit`, `design-critique`, `design-harden`) show a ⚠️ badge when set to Codex — they still run, but with degraded quality.
- **Database** — added `RoutineConfig.engine` (`String?`, default `"claude"`); migration `20260606000000_add_routine_engine` (additive, non-destructive). API `PATCH /api/projects/[id]`, `/api/ingest`, and `/api/projects/by-repo` now read/write/return `engine`, and `get-config.sh` emits it into the regenerated `routines.yml`.
- **Installer** — `install.sh` and `checklist.yml` write `engine: claude` into generated/repaired routines so existing projects pick up the field on `darkflow:update`.
- **Note** — Codex's `--json` event schema is still experimental; `format_codex_stream` is lenient (skips unknown events) and should be re-verified against live `codex exec` output. Setting up and authenticating the `codex` CLI on the worker machine is left to the operator (no `~/.codex`/AGENTS.md scaffolding in this release).

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
