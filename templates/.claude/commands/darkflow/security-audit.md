---
description: Full security review — GitHub alerts, static code analysis, live app check — then a task per finding.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

Weekly security pass. It covers both halves that used to be separate routines: **what GitHub
already knows** (Dependabot, code scanning, secret scanning) and **what only a reading of the
code finds**. The GitHub half is cheap and runs first — it is also the half that can already
have a fix waiting.

The cost of folding the daily `vulnerability-check` into this weekly run is response time: a
Dependabot advisory can now sit for up to seven days instead of one. Accepted knowingly.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`.

## Step 2 — GitHub alerts

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Fetch open alerts from all three surfaces. Any of them may return `404` or `403` when the
feature is off or the token lacks scope — that means "no findings from that surface", not an
error to stop on.

```bash
gh api -X GET "/repos/${REPO}/dependabot/alerts"      -f state=open --paginate 2>/dev/null || echo "[]"
gh api -X GET "/repos/${REPO}/code-scanning/alerts"   -f state=open --paginate 2>/dev/null || echo "[]"
gh api -X GET "/repos/${REPO}/secret-scanning/alerts" -f state=open --paginate 2>/dev/null || echo "[]"
```

Derive a stable identifier per alert — it is what dedup in Step 4 matches on:

- Dependabot: `security_advisory.ghsa_id` + affected package name and version range
- Code scanning: `rule.id` + file path + line
- Secret scanning: secret type + the locations array — **never the secret value itself**

## Step 3 — Code review

/security-review

## Step 4 — Deduplicate, then file

Read **every** task in the project, not just this routine's own:

```bash
~/.darkflow/df task list --state all --format compact
```

The same weakness reaches two audits from two directions — a missing rate limit is a security
finding *and* an architecture one — and filtering by `--source` would let it land twice. Skip a
finding when it matches an existing task **or** one a human already closed without a merged fix
(rejected). Re-file only when a previously-fixed problem has demonstrably regressed.

One task per surviving finding:

| Origin | `--source` | `--status` |
|---|---|---|
| Dependabot version upgrade | `vulnerability-report` | `approved` — auto-approved, see `docs/auto-approve.md` |
| Code scanning / secret scanning | `vulnerability-report` | `proposed` |
| Code review finding | `security-review` | `approved` — auto-approved |

Priority = severity (`critical` / `high` / `medium`). **`low` never becomes a task** — mention it
in the run output and move on.

**Title**: action-oriented verb — "Upgrade `lodash` to ≥4.17.21 (GHSA-jf85-cpcp-j695)", "Remove
leaked Stripe live key from `scripts/seed.ts`", "Restrict CORS on `/api/export`". Never a restatement
of the alert ("Vulnerability in X", "X is insecure").

**Body:**

```
## Problem
<what was found, why it is a risk, and the affected file / package / location>

GitHub alert: <html_url, for a GitHub-sourced finding>
Identifier:   <GHSA / rule.id / secret type — omit for a code-review finding>
Severity:     <critical | high | medium>

## Plan
- [ ] 1. <concrete remediation — exact version to upgrade to, code to change, key to rotate>
- [ ] 2. <next step, if the fix needs one>

## Acceptance criteria
- [ ] <verifiable outcome>
- [ ] <GitHub alert dismissed or auto-closed, where one exists>
```

For a secret-scanning finding, reference the location only — never paste the secret.

```bash
~/.darkflow/df task create --title "<title>" --source <vulnerability-report|security-review> \
  --priority <critical|high|medium> --status <approved|proposed> --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Language for all tasks and output: the `language` value from the project config.

## Step 5 — Docs snapshot

Append a `## Security` section to today's daily log, `docs/logs/$(date +%F).md` — create the
file if it is not there yet, and never touch a section another routine wrote.

**Found nothing? Append nothing.** No section, no "all clear" line. Silence is the clean
result, and the observation threshold counts on it (see `.darkflow.d/claude.md`).

```markdown
## Security

**Period:** <date range reviewed>

### Findings

| Category | Finding | Severity | File / Config | Source |
|---|---|---|---|---|
| | | critical / high / medium / low | | github / code-review |

### Recurring Issues

<findings appearing in 2+ consecutive audits — note how many in a row>

### Recommendations

<each with: what was found → specific fix → acceptance criterion>
```

## Step 6 — Metrics

One file for both halves — `vulnerabilities.json` is gone, `security.json` absorbed it.

```bash
~/.darkflow/df task list --source security-review      --state open
~/.darkflow/df task list --source vulnerability-report --state open
```

- `openIssues` = both counts together
- `criticalOpen` = those with priority `critical` or `high`
- `status` = `"critical"` if `criticalOpen > 0`, else `"warning"` if `openIssues > 5`, else `"ok"`

Write `.darkflow.d/state/metrics/security.json` (create parent directories if needed):

```json
{
  "openIssues":   <integer>,
  "criticalOpen": <integer>,
  "status":       "ok" | "warning" | "critical"
}
```

The worker forwards this file on its next sync.
