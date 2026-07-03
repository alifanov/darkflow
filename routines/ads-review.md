# Ads Review

Weekly review of paid ads performance (Google Ads, Meta Ads, or equivalent) — creates proposed tasks with prioritised optimisation recommendations.

---

## Instructions

```
/darkflow:ads-review
```

The command reads `.darkflow` for the output language — no placeholders to replace.

---

## Configuration

| Setting | Value |
|---|---|
| Cron | `0 8 * * 1` (weekly Monday 8:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) |
| Permission mode | `bypassPermissions` (default; override per project in the Web UI) |
| Run manually | `~/.darkflow/darkflow-run.sh ads-review` |

---

## Required integrations

- Ads platform access (Google Ads MCP, Meta Ads API, or equivalent) configured in project `.claude/settings.json`

---

## What gets created

Tasks with: `status=proposed`, `source=ads`, `priority=*`

The routine writes an ads snapshot to `docs/insights/ads/YYYY-MM-DD.md` before posting recommendations.

---

## Notes

- Covers paid campaigns only — organic search is handled by `gsc-check`
- Analytics attribution (ROAS from PostHog) is covered by `analytics-review` — avoid duplicate tasks
