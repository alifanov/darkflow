# Security Runtime Audit

Weekly check of the live application's security posture — HTTP headers, TLS configuration, CSP policy, DNS security records, and exposed endpoints. Creates `status:proposed` GitHub issues for each gap.

---

## Instructions

```
Perform a runtime security audit of the live application at [YOUR_DOMAIN].

Check the following:

1. HTTP security headers — Content-Security-Policy, Strict-Transport-Security, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy
2. TLS configuration — certificate validity and expiry, protocol versions (no TLS 1.0/1.1), cipher suites
3. DNS security — SPF, DKIM, DMARC records; check for subdomain takeover risks
4. Exposed sensitive paths — /.env, /admin, /.git, /api/debug, error pages that leak stack traces
5. CORS policy — overly permissive Access-Control-Allow-Origin
6. Cookie security — Secure, HttpOnly, SameSite flags on session cookies

For each gap:
- Describe what is missing or misconfigured
- Explain the risk
- Provide the exact fix (header value, DNS record, config change)

Create a GitHub issue for each finding.
Language in GitHub issues: Russian.
```

Replace `[YOUR_DOMAIN]` with your production URL before saving the routine.

---

## Configuration

| Setting | Value |
|---|---|
| Schedule | Weekly (e.g. Sunday at 4:00) |
| Folder | Project root (`/path/to/your-project`) |
| Model | Sonnet (default) — mostly HTTP checks, no deep reasoning needed |
| Worktree | **No** — external HTTP checks only |
| Always allowed | **Act without asking** |

---

## Required integrations

- **`gh` CLI** authenticated — for creating GitHub issues
- The agent uses `fetch` / `curl` to check headers — no additional MCP needed
- Optionally: configure a security scanning MCP (e.g. secscanner) for deeper checks

---

## What gets created

Issues with labels: `status:proposed`, `source:security-review`, `area:infra` / `area:api`, `priority:p0`–`p3`, `effort:xs`–`m`

Most header and DNS fixes are `effort:xs` — quick wins worth fixing immediately.

---

## Notes

- Schedule 1 hour after the code audit (Sunday 4:00 vs 3:00) so they don't run in parallel
- TLS certificate expiry is often `priority:p0` — add to instructions: "If TLS cert expires within 14 days, mark as priority:p0"
- For multi-domain setups, clone this routine per domain
- The runtime audit catches deployment-level issues the code audit misses (e.g. headers set by the hosting platform, not the app)
