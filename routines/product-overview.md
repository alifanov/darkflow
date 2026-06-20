# Product Overview

Weekly product digest — consolidates the current state of the product with what was recently improved (product + technical), recent bugs and fixes, and the hypotheses currently being tracked. A narrative summary for a human, written as a dated snapshot.

This is a **reporting** routine, not a check. It creates no GitHub issues and audits no drift (see `/darkflow:docs-audit` for the docs-vs-code check). It reads docs, git history, issues, and `insights/*` snapshots, then synthesizes.

---

## Instructions

```
/darkflow:product-overview
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 7 * * 1` (weekly Mon 7:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Opus (recommended — synthesis across many sources) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh product-overview` |

---

## Required integrations

- **`gh` CLI** authenticated — for reading open/closed issues (optional; degrades gracefully if absent)

---

## What gets created

A dated digest at `docs/insights/product-overview/YYYY-MM-DD.md`. No GitHub issues, no metrics file, no edits to other docs layers.

---

## Schedule rationale

Runs **Monday 7:00**, before the daily `analytics-review` (8:00) — so the week opens with a fresh product picture that the rest of the week's reviews build on.

---

## Notes

- Use **Opus** — a good overview weaves together product docs, commit history, issue state, and scattered hypotheses; Sonnet tends to produce a flat changelog instead of a synthesis.
- Keep it executive-summary length. The value is the synthesis and the top-3 next moves, not an exhaustive list.
- It deliberately does not create issues — if a recommendation is worth acting on, a human approves it and the review/fix routines pick it up.
