---
description: Visual design audit — quality dimensions, UI performance, production-readiness — then a task per finding.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

The **visual** half of design review: what the interface looks like, how fast it paints, and
whether it survives contact with real content. Its counterpart is `check-ux`, which walks the
flows instead of looking at the surfaces.

**Proposal-only.** Findings become tasks; nothing is changed here.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `stagingUrl`, `domain`.

Check against `stagingUrl` when it is set, otherwise `domain`. There is no list of key pages to
maintain: read `sitemap.xml` and pick the pages from it. If neither URL is set and there is no
sitemap, audit the components in the repo and say so in one line.

## Step 2 — Quality

/impeccable:audit

## Step 3 — UI performance

/impeccable:optimize

## Step 4 — Production readiness

/impeccable:harden

Cover the visual failure modes only — text overflow at 320px, contrast, untranslated strings,
truncation with long real-world content. The *behavioural* ones (a flow that dead-ends on an
error, a missing empty state you can only reach by using the app) belong to `check-ux`.

## Step 5 — Deduplicate, then file

Read **every** task in the project, not just this routine's own:

```bash
~/.darkflow/df task list --state all --format compact
```

Design, UX, performance and build audits all reach the same slow page from different angles;
filtering by `--source` would file it two or three times. Skip anything already tracked **or**
already dismissed (closed without a merged fix — rejected). Re-file only when a previously-fixed
problem has demonstrably regressed. A performance finding already covered by `build-optimization`
is theirs, not yours.

- `--source design`, `--status proposed`
- Priority:
  - `high` — broken layout, inaccessible element, missing state on a critical screen, LCP > 2.5s, CLS > 0.1
  - `medium` — visual inconsistency, unclear hierarchy, spacing, measurable slowdown, large unoptimized asset
  - **polish and nice-to-have → no task.** It goes in the snapshot's Recommendations, nowhere else.

**Title**: action-oriented verb — "Fix broken grid on /dashboard at 375px", "Reduce LCP on
/landing from 4s to <2.5s", "Fix contrast ratio on primary button". Never a bare observation.

**Body:**

```
## Problem
<what was found, which page or component, why it matters — for a metric: current value vs target>

## What to do
<concrete change — specific file, component, asset or CSS>

## Acceptance criteria
- [ ] <verifiable outcome — e.g. "LCP below 2.5s on Lighthouse mobile">
```

```bash
~/.darkflow/df task create --title "<title>" --source design \
  --priority <high|medium> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from the project config.

## Step 6 — Docs snapshot

Write `docs/insights/design/YYYY-MM-DD.md` (today's date; append a section if it exists):

```markdown
# Design — YYYY-MM-DD

**Scope:** <URL checked, pages walked>

## Quality

| Dimension | Finding | Severity | Page / Component |
|---|---|---|---|

## Performance

| Metric | Current | Target | Page | Task |
|---|---|---|---|---|
| LCP | | < 2.5s | | |
| CLS | | < 0.1 | | |
| Bundle | | | | |

## Production readiness

| Category | Component / Page | Gap | Risk |
|---|---|---|---|
| overflow | | | |
| contrast | | | |
| i18n | | | |

## Recurring

<findings appearing in 2+ consecutive audits — note how many in a row>

## Recommendations

<page/component → what to fix → acceptance criterion>
```

No metrics file: nothing in the worker forwards a design metric today, and writing one nobody
reads only freezes a widget on a stale value.
