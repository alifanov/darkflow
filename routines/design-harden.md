# design-harden

Monthly production-readiness review using `impeccable:harden` — edge cases, i18n, error states, overflow.

## Schedule

| Property | Value |
|---|---|
| Cron | `0 10 1 * *` |
| When | 1st of every month at 10:00 |
| Model | opus |
| Module | `impeccable` |

## What it does

1. Runs `/impeccable:harden` against the project's UI
2. Creates `status:proposed` GitHub issues for each gap (labels: `source:design`, `priority:high` / `medium`; low-risk gaps are noted in the snapshot, not filed)
3. Writes a snapshot to `docs/insights/design-harden/YYYY-MM-DD.md`
4. Writes metrics to `.darkflow.d/state/metrics/design-harden.json`

## Config

Enable with `--with-impeccable` during install, or set `modules=...,impeccable,...` in `.darkflow`.

Disable without removing: set `enabled: false` in `.darkflow.d/routines.yml`.

## Notes

- Monthly cadence — hardening gaps change slowly; weekly would create noise
- Covers: missing error/empty states, text overflow at small viewports, untranslated strings, unhandled edge cases
- Pairs with weekly `design-audit` + `design-critique` for full design health coverage
