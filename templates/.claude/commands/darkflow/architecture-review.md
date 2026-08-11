---
description: Architecture + code-health audit — module boundaries, then fallow on TS/JS — and a task per finding.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

Weekly structural pass, in two parts. The **review** reads the codebase for module boundaries,
coupling and layering — it works on any language. The **fallow step** adds deterministic
TS/JS findings (dead code, duplication, cycles, complexity) on top; it is optional precisely
because it only covers TS/JS while the rest of the review does not.

**Proposal-only.** It identifies problems and files tasks. It changes nothing itself — that is
a human / `fix-issues` decision.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`.

## Step 2 — Architecture review

/improve-codebase-architecture

## Step 3 — Code health (TS/JS only — skip otherwise)

Skip this step unless the project is TypeScript/JavaScript (`package.json` plus `tsconfig.json`
or `.ts`/`.tsx`/`.js` files). A Python or Go repo goes straight to Step 4 with the review's
findings alone — that is a normal outcome, not a degraded run, and it needs no note anywhere.

The **fallow skill** (`~/.claude/skills/fallow`) teaches the exact commands, flags, JSON shape
and gotchas — follow it. The entry point is the aggregated audit:

```bash
npx fallow audit --json
```

If `npx fallow` is unavailable, `cargo install fallow-cli` once, or skip the step. **Never guess
findings** — this half is only worth running while it stays deterministic.

Collect at minimum: dead code (unused exports, files, unreachable code) · duplication ·
circular dependencies and boundary violations · complexity hotspots · dependency hygiene.

Read the `actions` array; each finding carries an `auto_fixable` flag. **`auto_fixable` does not
mean "safe to delete"** — that judgement is Step 4.

## Step 4 — Triage (never trust the tool blindly)

fallow is deterministic but context-blind, and the review can over-reach. Filter first:

- **Dead code that is actually live:** public API surface (`exports`/`main`/`types`), framework
  entry points (`page.tsx`, `route.ts`, `layout.tsx`, `app/**`, `pages/**`), dynamically
  referenced symbols (string-keyed lookups, DI, reflection), test fixtures, generated files,
  type-only re-exports consumed downstream. The skill's gotchas reference has the full list.
- **Duplication that is intentional:** generated code, vendored snapshots, deliberately
  decoupled copies. Propose extraction only when the blocks are genuinely the same concern.
- **Complexity that is inherent:** a parser or a state machine is legitimately complex. Propose a
  refactor only where the complexity is accidental *and* the file changes often (cross-check
  `git log` churn).
- **Style preferences are not findings.** Actionable structural problems only.

Rank survivors by **impact** × **confidence**.

Then deduplicate against **every** task in the project, not just this routine's own:

```bash
~/.darkflow/df task list --state all --format compact
```

Filtering by `--source` would let the same problem land twice from two audits — a leaky module
boundary is an architecture finding *and* often a security one. Skip anything already tracked
**or** already dismissed (closed without a merged fix — rejected). Re-file only when a
previously-fixed problem has demonstrably regressed.

## Step 5 — File tasks

One task per significant, independent, high-confidence finding. Group trivially related items
("Remove 4 unused exports in `src/lib/`" → one task).

- `--source arch-review`, `--status proposed`
- Priority by impact:
  - `high` — large, safe wins (delete an unused module and its transitive deps; break a cycle that blocks tree-shaking; split a module two layers depend on in opposite directions)
  - `medium` — meaningful cleanup (a cluster of unused exports, a sizable duplicate worth extracting)
  - **minor or low-confidence → no task** — the snapshot's *Skipped* section is where it goes

**Title**: action-oriented verb — "Remove unused export `parseLegacyConfig` and its 2 helpers",
"Break import cycle between `auth/` and `db/`", "Extract duplicated retry logic in `api/*.ts`".

**Body:**

```
## Problem
<what was found, with file paths — why it is dead / duplicated / cyclic / mislayered>

## What to do
<specific change: which files, what to delete, extract or reorder>

## Acceptance criteria
- [ ] <measurable: "src/lib/legacy.ts removed, build + typecheck pass, no remaining importers">
- [ ] <where fallow found it: re-running `npx fallow dead-code` no longer reports it>

## Confidence
<why this is safe — checked for dynamic refs, public API, framework entry points>
```

```bash
~/.darkflow/df task create --title "<title>" --source arch-review \
  --priority <high|medium> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from the project config.

## Step 6 — Docs snapshot

Write `docs/insights/architecture/YYYY-MM-DD.md` (today's date; append a section if it exists):

```markdown
# Architecture & Code Health — YYYY-MM-DD

**Scope:** <what was analyzed; fallow version if the TS/JS step ran>

## Summary

| Category | Found | Filed | Notes |
|---|---|---|---|
| Structure / boundaries | | | |
| Dead code | | | |
| Duplication | | | |
| Circular deps | | | |
| Complexity hotspots | | | |
| Dependency hygiene | | | |

## Filed tasks

| Finding | File(s) | Priority | Confidence | Task |
|---|---|---|---|---|

## Skipped (false positives / low confidence)

<deliberately not filed, with the reason — keeps the next audit from re-litigating them>

## Recurring

<findings appearing in 2+ consecutive audits — note how many in a row>
```

## Step 7 — Metrics

One file for both halves — `code-health.json` is gone, `architecture.json` absorbed it.

```bash
~/.darkflow/df task list --source arch-review --state open
```

- `openIssues` = the count
- `status` = `"warning"` if any is priority `critical`/`high`, or `openIssues > 10`; else `"ok"`

`ArchitectureStatus` has no `criticalOpen` column — don't write one, it would be dropped.

Write `.darkflow.d/state/metrics/architecture.json` (create parent directories if needed):

```json
{
  "openIssues": <integer>,
  "status":     "ok" | "warning"
}
```

The worker forwards this file on its next sync.
