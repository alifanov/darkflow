# Tasks — recommendation cycle

Describes how the agent (Claude Code) and a human jointly run the task queue through Dark Flow's own task store (Postgres, via the `~/.darkflow/df` CLI — no GitHub Issues involved). Findings recorded in the daily log (`docs/logs/YYYY-MM-DD.md`) become tasks → a human decides → the agent picks up approved ones.

---

## Task fields

Every task carries: `number` (per-project, human-facing "#N"), `title`, `body`, `status`, `priority`, `source`, `action` (mailbox only), `scheduledFor`, and `comments`.

### `status` — lifecycle (state machine)

Exactly one status at a time. There is no separate open/closed field — `closed` is a status value, so any status other than `closed` is implicitly "open" and vice versa.

| Value | When it's set | Who sets it |
|---|---|---|
| `proposed` | Default when the agent creates a task | Agent |
| `approved` | Human approved — agent may pick it up | Human (or Agent for categories in [`auto-approve.md`](./auto-approve.md)) |
| `in-progress` | Agent started work; left a comment with a summary | Agent |
| `needs-human` | The agent can't proceed on its own (missing access, config, failed checks, external service) — the comments say what's needed. Parked out of the approved queue until a human acts. | Agent (`df task needs-human <n>`) |
| `closed` | Terminal — either the agent shipped the fix, or a human declined it (Reject) or dismissed it (Close). Comments explain which. | Agent or Human |

Approving a task overwrites `needs-human` — one value, so the two can never disagree.

`scheduledFor` (nullable timestamp) — snooze: `fix-issues` does not pick the task up before this moment, even when it is `approved`. Set at creation with `df task create --after <ISO date>`, later with `df task snooze <n> <ISO date|clear>` or the Snooze button in the Web UI. Null = no delay.

> **Auto-approve:** for select categories (security fixes, dependency updates) the agent sets `--status approved` directly at creation time, skipping human review. Full list — [`auto-approve.md`](./auto-approve.md).

### `source` — where the recommendation came from

One value per task. The **task body** links directly to the daily-log section it came from (e.g. `docs/logs/2026-05-16.md` → `## Analytics`).

| Value | Source |
|---|---|
| `openpanel` | `## Analytics` in the daily log (OpenPanel) |
| `gsc` | `## SEO` in the daily log (Google Search Console) |
| `seo` | `## SEO` in the daily log (technical/on-page audit) |
| `ads` | `## Ads` in the daily log (Google Ads) |
| `signoz` | SigNoz observability (`/check-signoz`) |
| `security-review` | Security audit (`/security-review`) |
| `user-feedback` | Interviews, emails, session recordings |
| `vulnerability-report` | GitHub Dependabot / Code Scanning / Secret Scanning |
| `infra` | Coolify / deployment health checks |
| `manual` | Hypothesis without a data source |

### `priority` — urgency

Exactly one, and it is **required** — every task must carry a priority. Replaces priority suffixes in titles.

| Value | Semantics |
|---|---|
| `critical` | Hits revenue or disables a feature right now |
| `high` | This week |
| `medium` | This month |
| `low` | Someday / nice-to-have |

> **Rule for filing tasks:** agents and routines create tasks **only for `critical` / `high` / `medium`**. `low`-level findings never become tasks — they're recorded in today's daily-log section instead. `low` remains valid for manually filed tasks.
>
> **Enforcement:** the rule isn't left to a single prompt — `POST /api/tasks` enforces the project's configured `minPriority` server-side: a routine-sourced task below the threshold is silently skipped (never created) instead of entering the queue.

---

## Task body — the template

Three sections, in this order. One shape for every task — routine-filed or hand-written.

```markdown
## Problem

Source: docs/logs/2026-05-16.md — ## Analytics

<What is wrong, where, and why it matters — numbers, the segment it applies to, file:line>

## Plan

- [ ] 1. <first concrete step — the file to touch, the change to make>
- [ ] 2. <second step>

## Acceptance criteria

- [ ] `pnpm exec fallow dead-code` no longer reports src/lib/legacy.ts
- [ ] Step 2 → Step 3 in OpenPanel is above 60% after 7 days
```

| Section | What belongs there |
|---|---|
| `Problem` | What breaks, for whom, with evidence. Never a bare observation ("low conversion on step 2"). |
| `Plan` | 2–5 concrete steps — the files to touch, the change to make. A starting point, not a contract: the agent that picks the task up may rewrite it, and says so when it does. Unsure of a step? Write the ones you are sure of. |
| `Plan (one step per run)` | The same section, opted into being done over several runs. `fix-issues` lands **one** step per tick — one commit or PR each — and closes the task only on the last one. Progress lives in the task's comments (`Step K/M — …`), because the body is not editable from the CLI. Use it when a task genuinely does not fit one run; a plain `## Plan` is still the default and finishes in one. |
| `Acceptance criteria` | What must be **true** when it is done — and **every criterion names the instrument that decides it**: a command, a report, a URL. "The fix works" is not a criterion; `pnpm build` passing is. Plan is the steps, this is the outcome — never the same list twice. |

`## Out of scope` is an optional fourth section — one line, only when the task borders on a
bigger change someone would otherwise drag in.

There is no separate "how to verify" section: a criterion that does not say how it is checked
is not a criterion yet, so the check lives on the criterion itself.

---

## Roles: who does what

### Agent (Claude Code)

1. **Creates a task** from each finding that clears the threshold — body per
   [the template](#task-body--the-template):
   ```bash
   ~/.darkflow/df task create \
     --title "Short, action-oriented description" \
     --source <...> --priority <...> --status proposed \
     --body "$(cat <<'EOF'
   <the four sections>
   EOF
   )"
   ```

2. **Before starting any session** — checks the approved queue:
   ```bash
   ~/.darkflow/df task list --status approved
   ```
   If there's an approved task matching the current context — pick it up first.

3. **When starting work on a task** — switches its status and leaves a comment:
   ```bash
   ~/.darkflow/df task set-status <N> in-progress
   ~/.darkflow/df task comment <N> --body "Starting implementation. Branch: <branch-name>"
   ```

4. **When done** — commits (direct push, or PR referencing "Task #N" if `mergeStrategy=pr`), then `~/.darkflow/df task close <N>` — the task moves to closed (done).

### Human

- Reviews tasks with `status=proposed` in the Web UI → approves or rejects.
- On reject — the task is closed (`status=closed`). The agent **does not recreate** it in later runs without new data; the daily log notes: "Not recreating — declined as task #N."

---

## Antipatterns

- **Don't encode dates in `source`** (`openpanel-2026-05-16`) — use `--source openpanel` + a link to the daily-log section in the body.
- **Don't encode priority in the title** (`[SEO/P0]`) — use `--priority critical`.
- **Don't recreate a declined task** without new data — note in the daily log: "Not recreating — declined as task #N."
- **Don't close a task manually as "done"** without a summary comment — leave a comment describing what was done before closing, for traceability.
