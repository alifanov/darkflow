Audit the codebase with [fallow](https://github.com/fallow-rs/fallow) — deterministic codebase intelligence for TypeScript/JavaScript — and turn its findings into `status:proposed` GitHub issues. fallow does the heavy analysis (unused code, duplication, circular deps, complexity hotspots, dependency hygiene); your job is to triage, judge what is safe to act on, and file concrete issues.

This is a **proposal-only audit**: it identifies problems and proposes changes. It does not apply changes itself (that is a human/`fix-issues` decision).

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to pull the latest project settings from the Web UI and refresh the project config at `.darkflow.d/state/config.json` (silently falls back to cache if the server is unreachable).

Read `.darkflow.d/state/config.json` (JSON, written by get-config.sh). Extract:
- `language` → output/issue language (default: English)
- `mergeStrategy` → context for how fixes land (pr or direct)

If `.darkflow.d/state/config.json` is missing, continue with defaults.

## Step 2 — Confirm this is a TypeScript/JavaScript project

fallow only analyzes TS/JS. Check for `package.json` (and `tsconfig.json` / `.ts` / `.tsx` / `.js` files). If the project is **not** TS/JS:

- Write a one-line snapshot noting "skipped — fallow supports TS/JS only" and a metrics file with `"status": "ok"`, then stop. Do not create issues.

If the repo is a monorepo, note the workspaces — fallow analyzes per-package; run at the root unless a specific package is requested.

## Step 3 — Run fallow

The **fallow skill** is installed (`~/.claude/skills/fallow`) and teaches the exact commands, flags, JSON shape, and gotchas — follow it. The canonical entry point is the full audit in machine-readable form:

```bash
npx fallow audit --json
```

If `npx fallow` is unavailable, fall back to `cargo install fallow-cli` once, or note the missing tool in the snapshot and stop (do not guess findings — this audit is only useful when it is deterministic).

Collect, at minimum:
- **Dead code** — unused exports, unused files, unreachable code (`npx fallow dead-code --json`)
- **Duplication** — copy-paste blocks across the codebase (`npx fallow dupes --json`)
- **Circular dependencies & boundary violations** — import cycles, layering breaks
- **Complexity hotspots** — files/functions with high cyclomatic/cognitive scores
- **Dependency hygiene** — unused or misconfigured `package.json` dependencies

Prefer the aggregated `fallow audit --json` and read the `actions` array (each finding carries an `auto_fixable` flag) — but **do not** rely on `auto_fixable` to mean "safe to delete". Apply judgment in Step 4.

## Step 4 — Triage findings (apply judgment, do not trust the tool blindly)

fallow is deterministic but context-blind. Before filing anything, filter out false positives:

- **Dead code that is actually live:** public API surface (package `exports`/`main`/`types`), framework entry points (Next.js `page.tsx`/`route.ts`/`layout.tsx`, `app/**`, `pages/**`), dynamically referenced symbols (string-keyed lookups, DI containers, reflection), test fixtures, generated files, type-only re-exports consumed downstream. Read the gotchas reference in the skill for the full list.
- **Duplication that is intentional:** generated code, vendored snapshots, deliberately decoupled copies. Only propose extraction when the blocks are genuinely the same concern.
- **Complexity that is inherent:** a parser or state machine may legitimately be complex. Propose refactors only where complexity is accidental and the file changes often (cross-reference `git log` churn).
- **Cross-check open issues:** `gh issue list --state open --json number,title,labels --limit 200` — skip anything already tracked.

Rank survivors by: **impact** (bundle/maintenance/risk reduction) × **confidence** (how sure you are it is truly safe).

## Step 5 — Create issues

Create a GitHub issue for each significant, independent, high-confidence finding. Group trivially related items into one issue (e.g., "Remove 4 unused exports in `src/lib/`" → one issue).

- Labels: `status:proposed`, `source:code-health`, priority by impact:
  - `priority:high` — large, safe wins (e.g., delete an unused module + its transitive deps; break a circular dependency that blocks tree-shaking)
  - `priority:medium` — meaningful cleanup (a cluster of unused exports, a sizable duplicate block worth extracting)
  - **minor / low-confidence → do NOT create an issue** — note it in the snapshot only

**Issue format (required):**

- **Title**: action-oriented verb — "Remove unused export `parseLegacyConfig` and its 2 helpers", "Break import cycle between `auth/` and `db/`", "Extract duplicated retry logic in `api/*.ts`" — never vague
- **Body**:
  ```
  ## Problem
  <what fallow found, with file paths and the fallow finding type — why it is dead/duplicated/cyclic/complex>

  ## What to do
  <specific change: which files, what to delete/extract/reorder>

  ## Acceptance criteria
  - [ ] <measurable: "src/lib/legacy.ts removed, build + typecheck pass, no remaining importers">
  - [ ] <re-run `npx fallow dead-code` shows the finding gone>

  ## Confidence
  <why this is safe — checked for dynamic refs / public API / framework entry points>
  ```

Language for all GitHub issues and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 6 — Write snapshot and metrics

Write `docs/insights/code-health/YYYY-MM-DD.md` (use today's date; append a new section if today's file already exists):

```markdown
# Code Health — YYYY-MM-DD

**Scope:** <fallow version, what was analyzed (root / packages)>

## Summary

| Category | Found | Filed | Notes |
|---|---|---|---|
| Dead code | | | |
| Duplication | | | |
| Circular deps | | | |
| Complexity hotspots | | | |
| Dependency hygiene | | | |

## Filed issues

| Finding | File(s) | Severity | Confidence | Issue |
|---|---|---|---|---|
| | | high / medium | | #N |

## Skipped (false positives / low confidence)

<findings deliberately not filed, with the reason — keeps the next audit from re-litigating them>

## Recurring

<findings appearing in 2+ consecutive audits — note how many audits in a row>
```

Save a snapshot so the Dark Flow worker can forward it to the web UI.

Run `gh issue list --state open --json number,labels --limit 200`, then:
- Count issues with label `source:code-health` → `openIssues`
- Count those with `priority:critical` or `priority:high` → `criticalOpen`
- Derive `status`: `"warning"` if `criticalOpen > 0`, `"warning"` if `openIssues > 5`, `"ok"` otherwise

Write `.darkflow.d/state/metrics/code-health.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
