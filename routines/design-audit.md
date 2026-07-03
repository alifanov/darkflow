# design-audit

Weekly design quality check using `impeccable:audit` — five-dimension technical review with P0–P3 severity findings.

## Schedule

| Property | Value |
|---|---|
| Cron | `0 10 * * 6` |
| When | Every Saturday at 10:00 |
| Model | opus |
| Module | `impeccable` |

## What it does

1. Runs `/impeccable:audit` against the project's UI
2. Creates a proposed task for each finding (`source=design`, `priority=high` / `medium`; polish-level findings are noted in the snapshot, not filed)
3. Writes a snapshot to `docs/insights/design-audit/YYYY-MM-DD.md`
4. Writes metrics to `.darkflow.d/state/metrics/design-audit.json`

## Config

Enable with `--with-impeccable` during install, or set `modules=...,impeccable,...` in `.darkflow`.

Disable without removing: toggle it off in the Web UI (Settings → Routine schedule).

## Notes

- Complements `design-critique` (same day, 11:00) — audit is technical quality, critique is user-facing quality
- `design-harden` runs monthly (1st of month) for production-readiness edge cases
- Tasks are created with `status=proposed` — human triage required before `fix-issues` picks them up
