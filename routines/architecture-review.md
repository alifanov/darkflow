# Architecture Review

Weekly automated architectural analysis of the codebase — identifies structural problems, anti-patterns, coupling issues, and improvement opportunities. Creates `status:proposed` GitHub issues for each finding.

Uses the **[improve-codebase-architecture](https://github.com/mattpocock/skills)** skill by Matt Pocock.

---

## Prerequisites

Install the skill once (the Dark Flow installer does this automatically if you select the Architecture review module):

```bash
npx skills add https://github.com/mattpocock/skills --skill improve-codebase-architecture
```

---

## Instructions

```
/improve-codebase-architecture

After the review is complete, create a GitHub issue for each significant finding:
- Labels: source:manual, area matching the affected module, priority based on impact, effort:m or effort:l
- Focus on actionable improvements, not style preferences
- Do not create issues for findings already tracked in open GitHub issues

Language in GitHub issues: [LANGUAGE]
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekly (e.g. Sunday at 2:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | **Opus** (recommended) — architectural reasoning requires deep understanding of the full codebase |
| Worktree | **No** — read-only analysis |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues
- **improve-codebase-architecture skill** installed (see Prerequisites above)

---

## What gets created

Issues with labels: `status:proposed`, `source:manual`, `area:*`, `priority:p2`–`p3` (architectural debt is rarely urgent), `effort:m`–`l`

Large findings (`effort:l`) should be broken into sub-issues before approving.

---

## Schedule relative to other security/audit routines

```
Sun 2:00  Architecture review  ← this routine
Sun 3:00  Security code audit
Sun 4:00  Security runtime audit
```

All three run on Sunday with 1-hour gaps so they don't overlap.

---

## Notes

- Use **Opus** — this skill reads the entire codebase; Sonnet misses inter-module patterns
- Architectural issues are typically `priority:p2`/`p3` — they compound over time but rarely block releases
- If the codebase is large, add to instructions: "Focus on `src/` and ignore `node_modules/`, `dist/`, generated files"
