# Dark Flow

**A workflow layer for AI-assisted development** — structured docs, a GitHub Issues triage loop, and an installer that sets it all up in minutes.

---

## What problem does this solve?

When Claude Code (or any AI agent) works on your project, it generates insights and recommendations — but they evaporate between sessions. There's no handoff from "observation" to "approved task" to "merged PR."

Dark Flow installs:
- A **5-layer docs structure** (`product / spec / design / insights / decisions`) with clear read/write rules for the agent
- A **GitHub Issues triage loop** — agent creates `status:proposed` issues from insights, human approves or rejects, agent picks up `status:approved` tasks automatically
- A **taxonomy of labels** (`status:*`, `source:*`, `area:*`, `priority:*`, `effort:*`) so you can filter with `gh issue list --label "status:approved"`
- **Agent-workflow rules** baked into `docs/agent-workflow.md` (referenced from CLAUDE.md)

---

## Install

### Via Claude Code agent (recommended)

Open Claude Code in your project directory and paste this message:

```
Install Dark Flow workflow from https://github.com/alifanov/darkflow

Run the installer:
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)

Ask me which optional modules I want (analytics, observability, GSC, ads, Coolify, CLAUDE.md update),
then run the installer with the appropriate flags.
After install, show me the routines I need to set up in Claude Code → Routines.
```

The agent will fetch the installer, ask about your stack, run it with the right flags, and walk you through setting up Routines.

### One-liner (terminal)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/main/install.sh)
```

### From source

```bash
git clone https://github.com/alifanov/darkflow.git /tmp/darkflow
cd /path/to/your-project
bash /tmp/darkflow/install.sh
```

### What the installer does

1. Asks which optional modules apply to your project
2. Creates `docs/` folder structure with template files
3. Creates `.github/ISSUE_TEMPLATE/recommendation.yml`
4. Sets up GitHub issue labels via `gh` (if authenticated)
5. Generates a comprehensive `CLAUDE.md` tailored to your modules
6. Installs `/darkflow` slash command for Claude Code

---

## Structure installed

```
docs/
├── README.md               ← manifest of all files + reading order
├── agent-workflow.md        ← rules: when agent reads / writes each layer
├── github-issues.md         ← labels taxonomy + triage loop spec
├── product/                 ← business layer (what, why, for whom) — quarterly
├── spec/                    ← product/UX layer (flows, screens, data model) — weekly
├── design/                  ← visual identity, tokens, patterns — situational
├── insights/                ← time-stamped snapshots (analytics, GSC, ads) — daily
│   ├── analytics/
│   ├── search-console/
│   ├── ads/
│   └── qualitative/
└── decisions/               ← ADRs (context → decision → verification) — as needed
    └── TEMPLATE.md
```

---

## The triage loop

```
Agent analyzes insights/* 
  → creates issue with status:proposed
Human reviews
  → sets status:approved or status:rejected
Agent starts next session
  → gh issue list --label "status:approved"
  → picks up matching area:* tasks
  → sets status:in-progress, comments with branch name
  → closes via PR with "Closes #N"
```

The loop runs automatically via **Claude Code Routines** — see [routines/README.md](./routines/README.md).

---

## Routines (automated agents)

The real power comes from scheduling Claude Code agents that run the loop without manual triggering:

| Routine | Schedule | What it does |
|---|---|---|
| [Analytics review](routines/analytics-review.md) | Daily 8:00 | PostHog + commits → `status:proposed` issues |
| [Observability check](routines/observability-check.md) | Daily 8:30 | SigNoz/errors/slow URLs → issues |
| [GSC check](routines/gsc-check.md) | Weekly Mon 8:00 | Google Search Console → issues |
| [**Fix issues**](routines/fix-issues.md) | **Hourly** | Picks up `status:approved` → PR → merge |
| [Coolify logs](routines/coolify-logs.md) | Daily 9:00 | Deployment logs → fixes errors → verifies |
| [CLAUDE.md update](routines/claude-md-update.md) | Weekdays 9:00 | Re-generates CLAUDE.md from codebase |
| [Security code audit](routines/security-code-audit.md) | Weekly Sun 3:00 | Secrets, injections, insecure deps → issues |
| [Security runtime audit](routines/security-runtime-audit.md) | Weekly Sun 4:00 | Headers, TLS, DNS, exposed paths → issues |

**Set up in:** Claude Code → Routines → New routine  
**Important:** set "Always allowed: Act without asking" on every routine.

Each routine page has: full instructions, schedule, model recommendation, worktree setting, and required integrations.

---

## Customization

After install, edit:
- `docs/agent-workflow.md` — add project-specific read/write rules
- `docs/github-issues.md` — extend area:* labels if needed
- `.github/ISSUE_TEMPLATE/recommendation.yml` — adjust dropdown options

---

## Requirements

- `git` — any version
- `gh` (GitHub CLI) — for label setup and issue management; [install](https://cli.github.com/)
- Claude Code — the workflow is designed around it, but works with any AI agent that follows markdown instructions
