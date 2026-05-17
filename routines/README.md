# Dark Flow — Claude Code Routines

Routines are scheduled Claude Code agents that run automatically and power the triage loop. They create GitHub issues from observations, fix approved issues, and keep project docs in sync.

Set them up in: **Claude Code → Routines → New routine**

Set **Always allowed: Act without asking** on every routine — otherwise the agent will stall waiting for confirmation.

---

## 1. Daily analytics review

**Schedule:** Every day at ~8:00  
**Folder:** your project root  
**Instruction:**

```
Check the latest commits for the last 24 hours. Check the latest PostHog analytics data for this project for the last 24 hours. Check what changes (commits) happened over the last week.

Based on this, suggest improvements.

Before making recommendations, get data on: new user funnel, errors, any anomalies.

Add all recommendations as GitHub Issues to the remote GitHub repository of this project.

Do NOT create recommendations about Google Ads work — that is handled in a separate routine.

Language in GitHub issues: Russian
```

---

## 2. Daily Coolify logs check

**Schedule:** Every day at ~9:00  
**Folder:** your project root  
**Instruction:**

```
1. Get logs for this project in Coolify for the last 24h
2. Check for errors
3. Fix these errors
4. Wait for successful deployment
5. Check app logs after deployment
```

> Requires Coolify MCP server configured in your Claude Code project settings.

---

## 3. Hourly GitHub issues fix

**Schedule:** Hourly at :00  
**Folder:** your project root  
**Instruction:**

```
Look at the open GitHub issues for this project in the GitHub repository. Fix them one by one, leave a comment in the GitHub issue. Close the GitHub issue after completion. Do each GitHub issue via a pull request and merge into the main branch.

1. Take only one GitHub issue, sorted by priority.
2. Make all the changes needed for it.
3. Commit and merge into the master branch and push these changes.

Language in GitHub issues: Russian
```

> This is the core execution routine. It picks up `status:approved` issues and closes them via PRs with `Closes #N`.

---

## 4. Weekly Google Search Console check

**Schedule:** Every Monday at 8:00  
**Folder:** your project root  
**Instruction:**

```
Check Google Search Console data for the last week. Suggest what to do to improve it. Output language: Russian. Add all recommendations as GitHub Issues.
```

> Requires Google Search Console MCP server configured.

---

## 5. Daily SigNoz observability check

**Schedule:** Every day at ~8:30  
**Folder:** your project root  
**Instruction:**

```
Check SigNoz for this project. Specifically: check for errors, check loaded URLs (how long they take to load), check request counts to specific URLs. Based on this, give recommendations on what needs to be done with the project. Add recommendations as GitHub issues.

Language of responses and GitHub issues: Russian.
```

> Requires SigNoz MCP server configured. Adapt to your observability tool (Datadog, Grafana, etc.)

---

## 6. Weekday CLAUDE.md regeneration

**Schedule:** Weekdays at ~9:00  
**Folder:** your project root  
**Instruction:**

```
Study the current state of the code and generate a new CLAUDE.md file that reflects what is currently in the code. So that it is up to date. Then commit and push the changes.
```

---

## Setup checklist

- [ ] Create all 6 routines in Claude Code → Routines
- [ ] Set "Always allowed: Act without asking" on each
- [ ] Verify `gh auth status` works in the project folder (needed by routines 1, 3, 4, 5)
- [ ] Verify Coolify MCP is configured if using routine 2
- [ ] Verify observability MCP is configured if using routine 5

## How the loop fits together

```
8:00  analytics review   → creates status:proposed issues in GitHub
8:30  SigNoz check       → creates status:proposed issues in GitHub
8:00  GSC check (Mon)    → creates status:proposed issues in GitHub
      ↓
      Human reviews issues, sets status:approved or status:rejected
      ↓
:00   hourly fix routine → picks up status:approved, fixes, PRs, merges
      ↓
9:00  Coolify check      → verifies deployment succeeded, fixes errors
9:00  CLAUDE.md update   → keeps agent context in sync with codebase
```
