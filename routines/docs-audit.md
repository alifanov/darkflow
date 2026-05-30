# Docs Audit

Weekly check that the `docs/` knowledge base still matches the code — finds drift between what the docs claim and what the code actually does, and creates `status:proposed` GitHub issues for each significant mismatch.

This is a **verification** routine. It does not rewrite docs and it does not produce a product narrative (see `/darkflow:product-overview` for that). Pairs with `claude-md-update`, which keeps `CLAUDE.md` itself current — `docs-audit` covers the `product/`, `spec/`, `design/`, and `decisions/` layers.

---

## Instructions

```
/darkflow:docs-audit
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 5 * * 0` (weekly Sun 5:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Opus (recommended — reads both code and docs deeply) |
| Permission mode | `bypassPermissions` (set in `.darkflow.d/routines.yml`) |
| Run manually | `bash .darkflow.d/darkflow-run.sh docs-audit` |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues

---

## What gets created

Issues with labels: `status:proposed`, `source:docs`, `area:docs`, `priority:p1`–`p3`

A dated snapshot at `docs/insights/docs-audit/YYYY-MM-DD.md` and a metrics file at `.darkflow.d/state/metrics/docs-audit.json`.

---

## Schedule relative to other weekly routines

```
Sun 2:00  Architecture review
Sun 3:00  Security code audit
Sun 4:00  UX/UI audit
Sun 5:00  Docs audit            ← this routine
```

Runs after the other Sunday audits with 1-hour gaps so they don't overlap.

---

## Notes

- Use **Opus** — comparing documented claims against real schema, routes, events, and components needs full-codebase reasoning; Sonnet misses subtle drift.
- Stub/placeholder doc files are reported as "not yet written", not as drift — no issues are created for them.
- Drift becomes an issue only when it is actively misleading; cosmetic staleness stays `priority:p3`.
