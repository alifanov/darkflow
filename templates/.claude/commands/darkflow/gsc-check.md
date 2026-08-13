---
description: Review Google Search Console data **and** run a technical + on-page SEO audit, then create tasks with concrete fixes.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

This routine has two halves:
1. **GSC data** — what's actually happening in search (positions, CTR, impressions, indexing).
2. **SEO audit** — why it's happening (on-page + technical issues in the codebase / live pages).

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses: `language`, `domain`. If `domain` is absent, try to auto-discover the production URL (Coolify FQDN, `vercel.json`/`.vercel/project.json`, `netlify.toml`, `CNAME`); if none is found, skip the live-page checks and audit the codebase only.

## Step 2 — GSC data analysis

**IMPORTANT: Never use the browser to access Google Search Console. All GSC data must be fetched exclusively via the Google Search Console MCP tools. If the GSC MCP is not connected or its tools are unavailable, skip this step (do NOT abort the whole routine — Step 3 still runs) and note in the snapshot:**

```
GSC data skipped: Google Search Console MCP is not connected.
Connect the GSC MCP in your project's .claude/settings.json to enable it.
```

Do not fall back to browser automation for GSC data.

Check Google Search Console data for the last week using MCP tools. Analyse positions, CTR, impressions, and indexing issues. For each meaningful finding, suggest a concrete fix and file it as a task (see task format below) with `--source gsc`.

### Never report indexation from the sitemaps API

`searchConsole_list_sitemaps` / `get_sitemap` return `contents[].indexed`. Google's own API
reference marks that field **"Deprecated; do not use."** — it returns `0` for every site, always,
including fully indexed ones. It is not a measurement, and "0 indexed" is not a finding.

Never put it in a snapshot, a task body, or an acceptance criterion. An acceptance criterion like
"indexed count in the sitemap report is > 0" can never be met, so the task can never be closed.

From that same response, these fields **are** real and worth reporting:

| field | means |
|---|---|
| `lastDownloaded` | when Google last actually fetched the sitemap — stale = it hasn't re-read your changes |
| `submitted` | URL count **as of that fetch** — compare with a live `curl` of the sitemap to spot drift |
| `errors` / `warnings` | real parse problems |

**To actually measure indexation**, in this order:

1. `searchConsole_query_analytics` — any URL with impressions is indexed by definition; it cannot
   rank without being in the index. This is the cheapest real check and it is available via MCP.
2. `searchConsole_inspect_url` — authoritative per-URL verdict (`coverageState`, last crawl).
   Rate-limited, so use it on a handful of key URLs, not the whole site.
3. The **Page Indexing** report (Indexing → Pages) — the only source of site-wide indexed /
   not-indexed counts with reasons. It has **no API**: it is web-UI only. If a run needs those
   numbers, say so and hand it to a human — do not substitute the deprecated field for it.

Contradiction check before filing anything about indexation: if the same run shows impressions or
positions for URLs, the site **is** indexed, whatever any counter says.

### Sitemap resubmission is not a human-only action

The Search Console API does expose `PUT /sites/{siteUrl}/sitemaps/{feedpath}` (`sitemaps.submit`,
not deprecated), which forces Google to re-fetch a sitemap. If the MCP connection exposes a
submit-sitemap tool, resubmit directly instead of filing a `--needs-human` task. Only if the
connection was granted read-only actions is a human needed — and then the task is "grant the
write action to the GSC connection", not "go click in Search Console".

**"I don't see a submit tool" is not evidence that there is none.** MCP tools can be *deferred*:
they are absent from the visible tool list until a `ToolSearch` call loads their schemas. Never
conclude the connection is read-only from what you can see. Run
`ToolSearch("select:searchConsole_submit_sitemap")` (or a keyword search for `sitemap submit`)
and attempt the call — only a real error from the call proves the action is missing. This exact
wrong conclusion stalled two sqlformatter tasks (#24, #37) for a combined 30+ days, each closed
as "needs a human to click Resubmit" when the tool was available all along.

Pass `siteUrl` exactly as `searchConsole_list_sites` returns it. A domain property is
`sc-domain:example.com`; calling the same tool with `https://example.com/` fails, and that
failure is about the argument, not about permissions.

**Request Indexing** (URL Inspection) genuinely has no public API and does require a human.

### AI crawlers are measured in access logs, not in files

**Never file a task to add or maintain `llms.txt`, and never report AI visibility from the fact
that the file exists.** No LLM vendor has stated it reads other sites' `llms.txt`; Google's John
Mueller: *"none of the AI services have said they're using LLMs.TXT (and you can tell when you
look at your server logs that they don't even check for it)"*, and Gary Illyes confirmed Google
has no plans to support it. Publishing an `llms.txt` (as OpenAI and Anthropic do for their own
docs) is not the same as consuming one. The file is cheap and harmless — leave an existing one
alone — but it is not evidence of anything and must never appear in a snapshot as a win.

What AI crawlers actually do is visible in the origin access log. The log usually has no
User-Agent field, so identify bots by the **published IP ranges**, not by name:

| bot | IP list |
|---|---|
| GPTBot (training) | `https://openai.com/gptbot.json` |
| OAI-SearchBot (ChatGPT search) | `https://openai.com/searchbot.json` |
| ChatGPT-User (user-triggered) | `https://openai.com/chatgpt-user.json` |
| Googlebot | `https://developers.google.com/static/search/apis/ipranges/googlebot.json` |
| Google-Extended & co | `https://developers.google.com/static/search/apis/ipranges/special-crawlers.json` |
| Bingbot (feeds ChatGPT search) | `https://www.bing.com/toolbox/bingbot.json` |

For a Coolify/Traefik host the log is `/data/coolify/proxy/access.log` (JSON lines).

> ⛔ **Check what the log is allowed to contain before concluding anything from it.** This proxy
> runs with `--accesslog.filters.statuscodes=500-599` (see `grep accesslog
> /data/coolify/proxy/docker-compose.yml`) — it is an **error log**, not a traffic log. Successful
> crawls never appear in it. Reading an absence there as "no bots came" is a false finding; it was
> made and caught on 2026-08-13. **Prove the log can show a hit before trusting a zero:** send a
> marked request (`curl 'https://<host>/robots.txt?probe=<id>'`) and grep the log for `probe=<id>`.
> No probe in the log ⇒ the log cannot answer questions about traffic, only about failures.

So report only what this log can support, per host: **which bot requests failed, on which paths,
with which status codes**. A bot request answered `5xx` is a real finding and outranks any on-page
nitpick — a `www.` hostname answering `503` to Googlebot's `/robots.txt` means that hostname is
invisible no matter what the pages contain. Do **not** report "N bot visits" or "zero bot visits"
from an error-filtered log.

To measure actual crawler traffic you need a source that records successes: the app's own request
logs, or Search Console's **Crawl stats** report (Settings → Crawl stats — Googlebot only, web-UI
only). If neither exists, say the number is unavailable rather than substituting the error log —
substituting the nearest available number for a missing one is the failure mode this whole section
exists to prevent.

## Step 3 — Technical + on-page SEO audit

Audit the project's site for SEO problems. Work primarily from the **codebase** (it's the source of truth and lets you propose exact fixes); use `domain` to spot-check rendered pages where code alone is ambiguous.

> ⚠️ **Schema markup detection:** `curl`/`web_fetch` strip `<script>` tags, so JSON-LD injected client-side won't show in static HTML. Detect structured data from the **source code** (e.g. `application/ld+json` blocks, Next.js metadata, schema components) or a rendered browser DOM — never report "no schema" based on a raw fetch alone.

Check, in priority order:

**Crawlability & indexation**
- `robots.txt` — no unintentional blocks on important paths; sitemap referenced
- `sitemap.xml` (or framework sitemap route) exists, lists only canonical/indexable URLs
- No stray `noindex` on pages that should rank; canonicals are self-referencing and point the right way
- HTTPS + consistent host (www vs non-www, trailing slash)

**On-page**
- Title tags — unique per page, primary keyword near the front, ~50–60 chars, no duplicates/missing
- Meta descriptions — unique, ~150–160 chars, compelling; none auto-generated/missing
- Heading structure — exactly one `<h1>` per page, logical `h1→h2→h3` hierarchy
- Image `alt` text on meaningful images
- OpenGraph / Twitter card tags present for shareable pages
- Structured data (JSON-LD) for the relevant page types (Organization, Product, Article, BreadcrumbList, etc.)
- Internal linking — no orphan pages, descriptive anchor text

**Technical foundations**
- Readable URL structure (lowercase, hyphenated, no needless params)
- Mobile viewport configured; no obvious mobile-breaking layout
- Obvious performance regressions affecting Core Web Vitals (giant unoptimized images, render-blocking assets) — flag, don't deep-profile

For each real issue found, file a task (format below) with `--source seo`. Prefer a small number of high-impact, specific tasks over an exhaustive nitpick list — group trivial same-type findings (e.g. "Add meta descriptions to 6 blog pages") into one task.

### Task format (required, both sources)

Add all recommendations as tasks with `--source gsc` **or** `--source seo` and a priority.

- **Title**: action-oriented verb — "Improve title tag on /pricing", "Add JSON-LD Product schema to product pages", "Fix missing meta descriptions on /blog/*" — never just a statement of the finding ("Low CTR on /pricing", "No structured data")
- **Body**:
  ```
  ## Problem
  <metric/finding, current value, affected URL or page group, and how it was detected (GSC vs code audit)>

  ## What to do
  <concrete SEO action — specific tag, file, component, or config to change>

  ## Acceptance criteria
  - [ ] <verifiable outcome, e.g. "Every /blog/* page has a unique <meta name='description'> 150–160 chars">
  - [ ] <additional criterion if needed>
  ```

Create with:
```bash
~/.darkflow/df task create --title "<title>" --source <gsc|seo> \
  --priority <critical|high|medium|low> --status proposed --body "$(cat <<'EOF'
<body as above>
EOF
)"
```

Before posting recommendations, write the snapshots:
Append a `## SEO` section to today's daily log, `docs/logs/$(date +%F).md` — create the
file if it is not there yet, and never touch a section another routine wrote.

**Found nothing? Append nothing.** No section, no "all clear" line. Silence is the clean
result, and the observation threshold counts on it (see `.darkflow.d/claude.md`).

Language for all tasks and output: the `language` value from `.darkflow.d/state/config.json`.

## Step 4 — After completing

Run both and combine:
```bash
jq -s 'add | length' \
  <(~/.darkflow/df task list --source gsc --state open) \
  <(~/.darkflow/df task list --source seo --state open)
```
- That count → `openIssues`
- Derive `status`: `"warning"` if openIssues > 5, `"ok"` otherwise

Write `.darkflow.d/state/metrics/gsc.json` (create parent directories if needed):

```json
{
  "openIssues": <integer>,
  "status":     "ok" | "warning"
}
```

The worker will pick up this file on its next sync. You do not need to update any HTML files.
