# Security Code Audit

Weekly static analysis of the codebase — finds security vulnerabilities, exposed secrets, insecure patterns, and outdated dependencies. Creates `status:proposed` GitHub issues for each finding.

---

## Instructions

```
Perform a security audit of the codebase. Check for:

1. Exposed secrets and credentials — API keys, tokens, passwords hardcoded in source files or committed .env files
2. Injection vulnerabilities — SQL injection, command injection, path traversal in user-controlled inputs
3. Authentication and authorisation gaps — unprotected routes, missing auth checks, insecure session handling
4. Insecure dependencies — run `npm audit` (or equivalent) and check for high/critical CVEs
5. Unsafe data handling — XSS vectors, unvalidated redirects, unsafe deserialization
6. Overly broad permissions — API routes that expose more data than needed, missing rate limiting

For each finding:
- Describe the vulnerability and where it is (file + line)
- Assess the severity (critical / high / medium / low)
- Suggest a concrete fix

Create a GitHub issue for each finding with labels source:security-review, priority based on severity.
Language in GitHub issues: Russian.
```

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekly (e.g. Sunday at 3:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | **Opus** (recommended) — deep code reasoning needed |
| Worktree | **No** — read-only analysis |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues
- No additional MCP needed — the agent reads the codebase directly

---

## What gets created

Issues with labels: `status:proposed`, `source:security-review`, `area:api` / `area:auth` / `area:infra`, `priority:p0`–`p3`, `effort:*`

Critical findings (`priority:p0`) should be reviewed immediately — consider adding a notification step to the instructions.

---

## Notes

- Use **Opus** — security analysis requires understanding implicit data flows across files; Sonnet may miss subtle vulnerabilities
- Add to instructions: "Do not create issues for findings already tracked in open GitHub issues"
- For monorepos, scope the instruction to a specific package: "Focus on `apps/api/` and `packages/auth/`"
- Consider running after major feature merges in addition to the weekly schedule
