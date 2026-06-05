# Build Optimization

Weekly audit of the project's build and deploy pipeline — maps how the project actually builds and ships, finds bottlenecks and inefficiencies, and creates `status:proposed` GitHub issues with concrete optimization proposals.

This is a **proposal-only** routine. It identifies opportunities and does not apply changes itself (implementation goes through the normal approve → `fix-issues` path). Pairs with `coolify-check-deployment`, which monitors the live deploy; `build-optimization` focuses on making that deploy faster and cheaper.

---

## Instructions

```
/darkflow:build-optimization
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 4 * * 0` (weekly Sun 4:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Opus (recommended — deep reasoning over Dockerfiles, CI configs, bundlers) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh build-optimization` |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:build`, `priority:high` / `medium` (`low`-impact optimizations are noted in the snapshot, not filed)

A dated snapshot at `docs/insights/build-optimization/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/build-optimization.json`.

---

## Schedule relative to other weekly routines

```
Sun 2:00  Architecture review
Sun 3:00  Security code audit
Sun 4:00  Build optimization       ← this routine
Sun 5:00  Docs audit
```

Runs in the Sunday audit cluster with 1-hour gaps so routines don't overlap.

---

## Notes

- Use **Opus** — reasoning about Docker layer ordering, CI caching, incremental build tools, and bundle analysis requires full-context judgment; Sonnet misses subtle inefficiencies.
- Only creates issues for significant, independent opportunities — trivially related fixes (e.g., `.dockerignore` + layer ordering) are grouped into a single issue.
- Acceptance criteria in each issue should be **measurable**: "CI install step drops from ~90s to ~15s on cache hit", not "build should be faster".
- Opportunities already tracked in open GitHub issues are skipped to avoid duplicates.
