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

### One-liner (run inside your project directory)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alifanov/darkflow/master/install.sh)
```

### From source

```bash
git clone https://github.com/alifanov/darkflow.git /tmp/darkflow
cd /path/to/your-project
bash /tmp/darkflow/install.sh
```

### What the installer does

1. Creates `docs/` folder structure with template files
2. Creates `.github/ISSUE_TEMPLATE/recommendation.yml`
3. Sets up GitHub issue labels via `gh` (if authenticated)
4. Prints the CLAUDE.md snippet to add

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
