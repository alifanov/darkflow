# Dark Flow — Routines

Scheduled Claude Code agents that automate the triage loop. Set them up in **Claude Code → Routines → New routine**.

> **Important:** set **Always allowed: Act without asking** on every routine — otherwise the agent stalls waiting for confirmation.

---

## Routines index

| Routine | Schedule | What it does |
|---|---|---|
| [Analytics Review](analytics-review.md) | Daily 8:00 | Checks PostHog + recent commits → `status:proposed` issues + updates overview |
| [Observability Check](observability-check.md) | Daily 8:30 | Checks SigNoz/errors/slow URLs → `status:proposed` issues |
| [**Overview Update**](overview-update.md) | **Daily 9:30** | Refreshes `docs/overview.html` — GitHub issues, analytics, security & arch status |
| [GSC Check](gsc-check.md) | Weekly Mon 8:00 | Checks Google Search Console → `status:proposed` issues |
| [**Fix Issues**](fix-issues.md) | **Hourly** | Picks up `status:approved` → PR → merge to main |
| [Coolify Logs](coolify-logs.md) | Daily 9:00 | Deployment log monitoring → fixes errors → verifies deploy |
| [**Deployment Failure Fix**](deployment-failure.md) | **API trigger** | Fires on failed deploy → diagnoses → fixes → redeploys |
| [CLAUDE.md Update](claude-md-update.md) | Weekdays 9:00 | Re-generates CLAUDE.md from current codebase |
| [Security Code Audit](security-code-audit.md) | Weekly Sun 3:00 | `/security-review` on codebase → issues + updates overview |
| [Security Runtime Audit](security-runtime-audit.md) | Weekly Sun 4:00 | `/security-review` on live app → issues + updates overview |
| [Architecture Review](architecture-review.md) | Weekly Sun 2:00 | `/improve-codebase-architecture` → issues + updates overview |

---

## How the loop fits together

```
Daily
  8:00  Analytics review    → status:proposed issues + updates overview
  8:30  Observability check → status:proposed issues
  9:00  Coolify logs        → verifies deploy, fixes errors
  9:00  CLAUDE.md update    → keeps agent context in sync
  9:30  Overview update     → refreshes docs/overview.html

On-demand (API trigger)
  deployment failure webhook → diagnoses → fixes → redeploys

Weekly
  Mon 8:00  GSC check              → status:proposed issues
  Sun 2:00  Architecture review    → status:proposed issues (Opus) + updates overview
  Sun 3:00  Security code audit    → status:proposed issues (Opus) + updates overview
  Sun 4:00  Security runtime audit → status:proposed issues + updates overview

Continuous
  :00  Fix issues (hourly) → picks up status:approved → PR → merge

Human
       Reviews status:proposed → sets status:approved or status:rejected
```

---

## Setup checklist

- [ ] Create routines in Claude Code → Routines → New routine
- [ ] Set "Always allowed: Act without asking" on each
- [ ] Verify `gh auth status` works in the project folder
- [ ] Configure required MCP servers (see each routine's page for details)
