# Dark Flow — Routines

Scheduled Claude Code agents that automate the triage loop. Set them up in **Claude Code → Routines → New routine**.

> **Important:** set **Always allowed: Act without asking** on every routine — otherwise the agent stalls waiting for confirmation.

---

## Routines index

| Routine | Schedule | What it does |
|---|---|---|
| [Analytics Review](analytics-review.md) | Daily 8:00 | Checks PostHog + recent commits → `status:proposed` issues |
| [Observability Check](observability-check.md) | Daily 8:30 | Checks SigNoz/errors/slow URLs → `status:proposed` issues |
| [GSC Check](gsc-check.md) | Weekly Mon 8:00 | Checks Google Search Console → `status:proposed` issues |
| [**Fix Issues**](fix-issues.md) | **Hourly** | Picks up `status:approved` → PR → merge to main |
| [Coolify Logs](coolify-logs.md) | Daily 9:00 | Deployment log monitoring → fixes errors → verifies deploy |
| [CLAUDE.md Update](claude-md-update.md) | Weekdays 9:00 | Re-generates CLAUDE.md from current codebase |

---

## How the loop fits together

```
8:00  Analytics review    → creates status:proposed issues
8:30  Observability check → creates status:proposed issues
8:00  GSC check (Mon)     → creates status:proposed issues
      ↓
      Human reviews issues → sets status:approved or status:rejected
      ↓
:00   Fix issues (hourly) → picks up status:approved → PR → merge
      ↓
9:00  Coolify logs        → verifies deployment succeeded, fixes errors
9:00  CLAUDE.md update    → keeps agent context in sync with codebase
```

---

## Setup checklist

- [ ] Create routines in Claude Code → Routines → New routine
- [ ] Set "Always allowed: Act without asking" on each
- [ ] Verify `gh auth status` works in the project folder
- [ ] Configure required MCP servers (see each routine's page for details)
