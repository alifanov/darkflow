Set up Content-Security-Policy (CSP) violation reporting for this project so CSP errors stop hiding in the browser console and start streaming into your telemetry. This is a one-time setup command — run it once per project. It is idempotent: re-running it makes no changes if reporting is already wired.

## Background — why this is needed

CSP violations are NOT JavaScript exceptions. `window.onerror`, try/catch, and error-tracking SDKs never see them — the browser blocks the resource at the policy layer and only (a) logs to the console and (b) fires a `securitypolicyviolation` event / POSTs to a `report-uri`/`report-to` endpoint if one is configured. Nothing forwards them to your telemetry unless you wire it explicitly. This command wires it.

Two requirements for any reporting to work:
1. A CSP must exist (enforced or Report-Only) — without a policy there are no violations to report.
2. A destination endpoint must exist.

## Step 1 — Read project config

Run `bash ~/.darkflow/get-config.sh` to refresh the project config, then read `.darkflow.d/state/config.json` (JSON). Extract `language` (default: English) for any output.

## Step 2 — Map the project

Determine, by reading the code (do not guess):

1. **Where the site's response CSP is (or should be) set** — typically `middleware.ts` / `src/middleware.ts`, `next.config.{ts,js}` `async headers()`, or a `proxy.ts`. Note whether a `Content-Security-Policy` (enforced) or `Content-Security-Policy-Report-Only` header already exists, and its directives.
2. **The project's server observability** — winston / a `logger` module / OpenTelemetry (e.g. SigNoz). Find the reusable logger the app already uses for server logs.

## Step 3 — Choose the destination

Reports always go to an **internal collector route** on the app's own origin (`/api/csp-report`), which forwards each violation to the project's logger / observability backend. If the app has no reusable logger, the collector falls back to a structured `console.warn` that server log collection can pick up. (OpenPanel is product analytics and does not accept CSP violation reports, so there is no external destination here.)

## Step 4 — Wire reporting (internal endpoint → observability)

1. Create a route handler at `app/api/csp-report/route.ts` (or `src/app/api/csp-report/route.ts` — match the project's App Router layout; for Pages Router use `pages/api/csp-report.ts`). It must:
   - Accept **POST** only; `export const dynamic = "force-dynamic"`.
   - Handle BOTH report shapes:
     - `report-uri` → content-type `application/csp-report`, body `{ "csp-report": { "blocked-uri", "violated-directive", "document-uri", "source-file", "line-number", ... } }` (hyphenated keys)
     - `report-to` → content-type `application/reports+json`, an **array** of `{ type, body: { blockedURL, effectiveDirective, documentURL, ... } }` (camelCase keys)
   - Normalize both into one record: `blockedURI, violatedDirective, documentURI, sourceFile, lineNumber, disposition, userAgent`.
   - Log each violation via the **project's existing logger** so it reaches the observability backend (e.g. `logger.warn("[csp-violation]", record)`, or an OTel log/span if that's the project's pattern). If there is no reusable logger, use `console.warn("[csp-violation]", JSON.stringify(record))` — server stdout is shipped to most backends.
   - Be fully defensive — never throw on bad input. Always return **204** with no body.
2. Append to the CSP directive string:
   - `report-uri /api/csp-report`
   - `report-to csp-endpoint`
   And set a sibling response header `Reporting-Endpoints: csp-endpoint="/api/csp-report"`.
3. If a proxy/middleware redirects or blocks requests, verify the same-origin POST to `/api/csp-report` passes through unmodified.

## Step 5 — Baseline policy (only if the project has NO CSP yet)

Add a `Content-Security-Policy-Report-Only` header (Report-Only blocks **nothing** — safe to ship). Author a permissive-but-meaningful policy by inspecting what the app legitimately loads (providers, analytics/GTM, fonts, image and connect domains — grep for external hosts). Reasonable starting point:

```
default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self';
script-src 'self' 'unsafe-inline' <discovered hosts>;
connect-src 'self' <discovered hosts>;
img-src 'self' data: blob: <discovered hosts>;
style-src 'self' 'unsafe-inline';
font-src 'self' data: <discovered hosts>;
worker-src 'self' blob:
```

Then append the reporting directives from Step 4. Notes:
- Err toward allowing what the app actually uses to keep noise low.
- If the app runs inside an embedder (e.g. a Telegram Mini App), do not over-restrict `frame-ancestors` and allow the embedder's script/connect/img hosts.
- If an enforced CSP already exists but is trivial (e.g. only `frame-ancestors`), leave it intact and add a SEPARATE Report-Only baseline so meaningful violations are actually surfaced.

## Step 6 — Verify

- Build the project (`pnpm build` or the project's build command) and run any CSP/middleware tests — everything must pass; fix regressions caused by this change.
- Confirm the report endpoint resolves and the headers are emitted.

## Step 7 — Report

Summarize: which file holds the CSP, the internal `/api/csp-report` destination → which logger/backend, the final policy, and the build/test result. No tasks and no metrics snapshot are created — this is a setup command.

Once violations start flowing, query your observability backend for `csp-violation` logs/spans.
