# design-critique

Weekly design review using `impeccable:critique` — scored review with persona tests and automated detection.

## Schedule

| Property | Value |
|---|---|
| Cron | `0 11 * * 6` |
| When | Every Saturday at 11:00 |
| Model | opus |
| Module | `impeccable` |

## What it does

1. Runs `/impeccable:critique` against the project's UI
2. Creates a proposed task for each finding (`source=design`, `priority=high` / `medium`; minor polish is noted in the snapshot, not filed)
3. Writes a snapshot to `docs/insights/design-critique/YYYY-MM-DD.md`
4. Writes metrics to `.darkflow.d/state/metrics/design-critique.json`

## Config

Enable with `--with-impeccable` during install, or set `modules=...,impeccable,...` in `.darkflow`.

Disable without removing: toggle it off in the Web UI (Settings → Routine schedule).

## Notes

- Runs one hour after `design-audit` (10:00) on the same Saturday
- While audit checks technical dimensions, critique scores user-facing quality through persona testing
- Both routines use `source=design` — filter tasks by this field to see the full design backlog
