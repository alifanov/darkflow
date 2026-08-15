---
description: Full SEO check — technical + on-page audit plus Google Search Console data, then create tasks with concrete fixes.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch
---

This routine has two halves:
1. **GSC data** — what's actually happening in search (positions, CTR, impressions, indexing).
2. **SEO audit** — why it's happening (on-page + technical issues in the codebase / live pages).

GSC is the only half that carries **real measured data** — everything else is a static read of
the code. When the GSC MCP is connected, Step 2 is never optional and never a footnote: run it
first and let its numbers set the priority of what Step 3 finds. Skipping it because "the audit
already found things" inverts the routine.

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

**Look in the repo before asking for GSC data.** Projects often keep exports of Performance
reports in-tree — `grep -rl "impressions" docs/insights docs/logs 2>/dev/null` or a glob for
`docs/insights/search-console/*.md`. Those tables carry per-query and per-page history the API
window no longer covers, and reading them costs nothing. Found in four naturalwrite files only
after a full round of "please export this from GSC" — check first.

### The two "not indexed" statuses are different diagnoses

They read almost the same and mean opposite things. Getting them backwards sends the fix in the
wrong direction, so never paraphrase them into one bucket:

| GSC status | means | fix direction |
|---|---|---|
| **Discovered – currently not indexed** | "found by Google, but not crawled yet… Google rescheduled the crawl" — crawl date is empty. **Not a quality signal.** | discovery/crawl: internal links, sitemap, server capacity |
| **Crawled – currently not indexed** | crawled and rejected | content quality, intent match, duplication |

`average position` in a query row is the **topmost** position across your URLs, not an average
across them — two pages competing for one query is invisible in the summary by construction.
Filtered queries also drop anonymized long-tail rows, so a filtered total is always lower than
the real one. Never report a filtered number as the site's total.

### A drop in impressions is not a drop in traffic

**Clicks are the only metric in the Performance report that survived the last audit of the tool
itself.** Google logged a [data anomaly](https://support.google.com/webmasters/answer/6211453):
*"A logging error prevented Search Console from accurately reporting impressions from May 13,
2025 until April 27, 2026"* — impressions, CTR and average position were wrong for ~50 weeks and
that history was never corrected; clicks were not affected. Treat impressions as the softest
number in the tool, not the headline.

**An impression below the first page has to be paginated to.** Verbatim: *"A link must get an
impression for its position to be recorded. If a result does not get an impression — for example,
if the result is on page 3 of search results, but the user only views page 1 — then its position
is not recorded for that query."* So hundreds of daily impressions at average position 50–70 mean
hundreds of daily visits to page 6–7 of a SERP. That is a machine reading the SERP, not an
audience. **Never open a snapshot, a task or an acceptance criterion with impressions won or lost
at position > 20** — state the clicks first, and if clicks were ~0 before and after, say plainly
that nothing of value moved.

**A drop is a different question from a deficiency**, and Google publishes the diagnostic tree —
[Debugging drops in Google Search traffic](https://developers.google.com/search/docs/monitor-debug/debugging-search-traffic-drops).
Its causes, in its own words: **algorithmic update · technical issues · security issues · spam
issues · seasonality and changing interests · site moves and migrations**. Work that list before
inventing a cause, and mark each one checked / excluded / not checkable:

| check | where | API? |
|---|---|---|
| a confirmed update overlapping the drop window | [Search Status Dashboard](https://status.search.google.com/products/rGHU1u87FJnkP6W2GwMi/history) — the primary source, one fetch | no, but public |
| a logged reporting glitch on those exact dates | [Data anomalies](https://support.google.com/webmasters/answer/6211453) | no, but public |
| **which queries** disappeared | `searchAnalytics.query` with `dimensions: ["query","date"]` | yes |
| manual action / security issue | Search Console → **Security & Manual Actions** | **no — web UI only** |

The Search Console API has exactly four resources — `searchAnalytics`, `sitemaps`, `sites`,
`urlInspection`. Manual actions and security issues are **not among them**, so a run that only
used the API has not excluded two of the six causes; say so instead of writing "technical causes
ruled out, nothing left".

🚫 **"The site left the sandbox / the fresh-domain discovery period ended" is not a diagnosis.**
It is on no Google list, Google denies the sandbox exists, and it conveniently explains any drop —
which is what makes it useless. Splitting a drop by query almost always beats it: a drop
concentrated on 3 URLs and one query shape is a ranking event; a drop spread evenly across
everything is a reporting or crawling event.

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

> 🛑 **Never propose markup for a retired search feature, and never call markup a win until its required properties are present.** A schema type earns a rich result only if it is listed in the [search gallery](https://developers.google.com/search/docs/appearance/structured-data/search-gallery) *and* the page carries every required property. Two failure modes, both silent — the markup validates, Google draws nothing.
>
> - **Retired — do not add, do not file tasks for, do not report as an SEO win:** `FAQPage` (rich result gone [7 May 2026](https://developers.google.com/search/docs/appearance/structured-data/faqpage); Search Console report and Rich Results Test support dropped with it), `HowTo` (gone since Sept 2023, [announced Aug 2023](https://developers.google.com/search/blog/2023/08/howto-faq-changes)), `sitelinks searchbox`. Existing markup may stay — Google explicitly says it need not be removed — but it buys nothing in Search.
> - **`HowTo` is the trap:** a step-by-step page looks like `HowTo` and isn't. Use `Article`/`BlogPosting` and keep the steps as an `ItemList` inside it.
> - **`SoftwareApplication`/`WebApplication` is live but conditional:** it needs `name`, `offers.price` **and** `aggregateRating` or `review`. A SaaS landing page with no genuine user ratings cannot satisfy that — and inventing them is a policy violation ("ratings must be sourced directly from users"; an entity reviewing itself is [ineligible](https://developers.google.com/search/docs/appearance/structured-data/review-snippet)). So: leave the markup, but **never report it as a rich-result win, and never file a task to "add ratings"**.
> - **Safe, live and worth checking:** `Organization` (once, site-wide), `Article`/`BlogPosting`, `BreadcrumbList`, `Product` (real products only), `VideoObject`, `Event`, `Recipe`, `Dataset`.
> - Before proposing any type not in that list, open the gallery and confirm it is still there. "It validates on schema.org" is not evidence of a search feature.

Check, in priority order:

**Crawlability & indexation — an AND-chain, not a list**

The bot stops at the first broken link and nothing below it exists. Check the links **in order**,
and never propose work below an unrepaired break (a sitemap entry, a schema block or an inbound
link cannot route around a `Disallow`):

1. `robots.txt` allows the path, and the sitemap is referenced there
2. the URL returns **200 without a cookie or login** — `curl -s -o /dev/null -w '%{http_code}'`
3. the **content is in the served HTML**, not only after client-side hydration
4. the page has its **own** `<title>`/description/canonical
5. it is in the sitemap, and its markup is present

> 🪤 **`Disallow` + `noindex` cancel each other out.** Blocked pages are never crawled, so the
> `noindex` is never seen, and the URL stays in the index as a bare link. To *hide* a page you must
> first *unblock* it. GSC calls this "Indexed, though blocked by robots.txt"; a sitemap listing such
> a URL raises "Sitemap contains urls which are blocked by robots.txt".

> 🪤 **Next.js:** a `"use client"` page cannot export `metadata` — without a sibling `layout.tsx`
> it silently inherits the homepage title. Grep for `"use client"` in `page.tsx` files that are
> supposed to rank and check each has its own metadata source.

**The page meant to rank is not the one excluded from the index** (critical, cheapest real finding)

```bash
grep -rn "index: *false\|noindex" --include="page.tsx" --include="*.ts" src app | grep -vE "login|account|checkout|admin|api"
```

Check every hit against the query it should serve, and check `X-Robots-Tag` on the live response
too. sqlformatter.dev sat outside the top 100 for a month because its only page with an input
field carried `robots: { index: false }`, added by hand as anti-cannibalization.

**Removing a losing page is a ladder, and `noindex` is its last rung** — differentiate titles →
re-link internally → canonical → 308 → and only then `noindex`, which drops the page from Search
entirely "regardless of whether other sites link to it".

**Canonical & duplicates**

- Canonicals are self-referencing and point at the chosen version (trailing slash, query params, www vs apex, locale)
- 🚩 **Next.js does not emit a canonical by itself** — `charset` and `viewport` are its only unconditional tags. This is the most common hole in Next projects; do not assume "it's an SEO framework" covers it
- 🚩 **Never canonical page 2+ of a paginated sequence to page 1** — Google documents this as an anti-pattern verbatim. `rel=next/prev` has been dead since 2019
- Signal strength, in order: **redirect > canonical > internal links > sitemap**. A canonical is a hint, not a rule — if external links point at `?utm=…` versions, the hint can lose
- Duplicates are **not** penalised. The damage is signals split across copies, so file the task in those terms, never as "duplicate content penalty"

**hreflang (multilingual projects only)**

- 🚩 **Bidirectional or ignored — entirely, not partially.** If A lists B and B does not list A, Google drops the whole cluster. The frequent shape of this bug: the sitemap emits only the default-locale `<loc>` rows with `xhtml:link` alternates hanging off them, and the localized URLs never appear as `<loc>` themselves
- The `<loc>` value and the `hreflang` `href` must match **character for character** — build both from the same call, a trailing slash is enough to break the pair
- **"Alternate language pages are not detected by Search Console"** — the fix is unverifiable in GSC. Verify by `curl` and, weeks later, Performance → Countries

**Redirects, 404s and soft-404s**

- `curl -I` the known moved paths: a permanent move must answer **301/308**, not 302/307. With a temporary code the *source* stays canonical
- 🚩 **Read the `Location` header to learn who answered.** An **absolute** URL means a proxy/hosting layer replied before the app — so the `301` in the repo never runs and the code in git is not the code in production. A **relative** `Location` means the framework answered. This trick works on any stack and settles "but it's fixed in the code" in one command
- **Next.js codes are not what people assume:** `permanent: true` → **308**, `redirect()` → **307**, `permanentRedirect()` → 308, both → 303 inside a Server Action
- 🪤 **`notFound()` returns 200 while streaming** — "Next.js will return a 200 HTTP status code for streamed responses, and 404 for non-streamed". Streaming starts at the first `loading.tsx`/`<Suspense>`, so a page can render "not found" with a 200 and become a soft-404. Verify with `curl -o /dev/null -w '%{http_code}'` on a deliberately bad URL, never by looking at the page
- A custom `app/not-found.tsx` exists (the default Next stub has no navigation, and it is a real dead end for both crawlers and people)
- Host-level breaks count too: a `www.` hostname with **no DNS record at all** is not a 404, it is an unreachable link — check `dig +short www.<domain>` alongside the redirect

**sitemap: `lastmod` is the only field Google reads — and the only one you can lose by faking**

This was the single defect shared by every site in the portfolio, and its root cause is the
official Next.js example (`lastModified: new Date()`), copied verbatim.

```bash
curl -s https://<domain>/sitemap.xml | grep -o '<lastmod>[^<]*' | sort | uniq -c | sort -rn | head
```

- **Fail** if every entry carries the same timestamp (`new Date()` → freezes at the last deploy, or refreshes on every build), if values cluster within milliseconds (`fs.statSync().mtime` under Docker `COPY . .` = build time), or if the field is absent while the content genuinely changes
- The date must be the last **significant** change to what a reader sees — "an update to the main content, the structured data, or links on the page is generally considered significant, however an update to the copyright date is not"
- **Omitting the field is officially allowed**: "use a `lastmod` element for all the pages… or just the ones you're confident about". The choice is between truth and silence — lying is not one of the options, and trust is lost for the **whole site**, not the one URL
- 🚫 **Google ignores `<priority>` and `<changefreq>`.** Their presence is harmless; treating them as a lever is not. Never file a task to tune them, and flag code that computes them as if they mattered
- The sitemap **ping endpoint was retired in 2023** and now 404s. Resubmission goes through the Sitemaps API (see Step 2)

**Programmatic pages: demand is measured before generation, not after**

Find bulk-generated route groups (`[slug]`, `/convert/{a}-to-{b}`, a dataset-driven `generateStaticParams`).
A template multiplies **pages**, never demand. If a group exists and there is no evidence demand was
checked first, that is the finding — 35 of sqlformatter's 42 pages targeted queries with **zero**
monthly searches, each one technically flawless: unique copy, correct canonical, in the sitemap,
linked from the homepage.

- Rule of thumb: **median demand < 50/mo across the dimension → one page, not N**. What matters is clicks from **one** page (`median × CTR`), never the total summed across the template
- The relevant risk is not a penalty but the documented shapes of *scaled content abuse* and *doorway abuse* — cite them as descriptions, never as an accusation
- Consolidating an existing group is a redirect job (many URLs → one, 301/308), and the result is measurable only 4–6 weeks later

**Internal linking**

- 🔑 **"Every page you care about should have a link from at least one other page on your site."** Being in the sitemap is not a link. Grep the rendered HTML for each key path to count real inbound `<a href>`s
- Pagination that only links `1`, `N−1`, `N+1`, `last` buries the middle of an archive dozens of clicks deep — measured at 19 on a 320-post blog. A "Load more" button that *replaces* links is worse: it can cut a reachable graph from 371 URLs to 24
- Hub and spoke link **both** ways; a tool and its explainer article link to each other (the common bug is the article linking to some *other* tool)
- ❌ Do **not** file findings based on: the "3 clicks from home" rule (it does not exist — Google files it under crawling myths, and only affects crawl *frequency*), a "100 links per page" limit (retired before 2008), or nofollow sculpting (dead since 2009)
- Frame it honestly: internal linking fixes **discovery**, not position — "crawling is necessary for a page to be in search results, but it's not a ranking signal"
- **Crawl budget is not a finding below ~10k URLs** (thresholds: 1M+ URLs, or 10k+ with daily updates). "Small sites aren't crawled as often as big ones" is explicitly false

**HTTPS + consistent host** (www vs non-www, trailing slash; note `site.com` = `site.com/` for the root, but `/page` ≠ `/page/`)

**On-page**
- Title tags — unique per page, primary keyword near the front, ~50–60 chars, no duplicates/missing
- Meta descriptions — unique, ~150–160 chars, compelling; none auto-generated/missing
- Heading structure — exactly one `<h1>` per page, logical `h1→h2→h3` hierarchy
- Image `alt` text on meaningful images
- OpenGraph / Twitter card tags present for shareable pages
- Structured data (JSON-LD) — only types that still earn a search feature, and only when the required properties are actually present (see the block above)

**Technical foundations**
- Readable URL structure (lowercase, hyphenated, no needless params)
- Mobile viewport configured; no obvious mobile-breaking layout
- Obvious performance regressions affecting Core Web Vitals (giant unoptimized images, render-blocking assets) — flag, don't deep-profile

### Findings that are verified NOT worth filing

These come back every audit because tools score them and blogs repeat them. Each was checked
against the live portfolio and cost nothing. **Do not file them, do not list them in the snapshot,
do not "just mention" them.**

| non-finding | why |
|---|---|
| **`/llms.txt` missing** | see the Step 2 section — no vendor consumes it. Lighthouse audits it anyway, and that is what keeps re-filing it |
| **`contents[].indexed` = 0** | deprecated API field, returns 0 for every site on earth |
| **Cannibalization / two pages on one query** | Ahrefs: 80 manually reviewed cases, **1** needed action. Google's own docs never use the word. Identical titles are not a diagnosis, and site diversity means the 3rd and 4th URL of a cluster take nothing from anyone. File one only when leadership actually **swaps** between URLs week over week |
| **`<priority>` / `<changefreq>` not tuned** | ignored by Google |
| **"Add ratings to get stars"** | self-sourced reviews are a policy violation, so the task can never be completed honestly |
| **Page length / "add more words"** | "The length of the content alone doesn't matter for ranking purposes" |
| **The robots.txt nit that scanners rate "high"** | verified live on 4 of 7 sites, costs nothing |

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

**Every criterion must be checkable from outside the code.** "The JSON-LD is present" is not one —
markup can be valid and still draw nothing. Use the instrument that decides:

| finding type | acceptance criterion |
|---|---|
| structured data | Rich Results Test on the live URL **detects the type** (it ignores JSON-LD comments, crawls as a smartphone, and does not check `noindex`/robots-blocked pages) |
| redirect | `curl -I` returns 301/308 and the `Location` is the final URL — no chain |
| noindex removed | `curl … \| grep robots` shows no `noindex`, and GSC URL Inspection says the page is indexable |
| `lastmod` | the sitemap shows ≥2 distinct dates and one sampled URL's date matches its last content commit |
| internal links | the target path appears as an `<a href>` in the served HTML of ≥1 other page |

A criterion no instrument can produce (a GSC counter with no API, a metric only visible in the web
UI) makes the task uncloseable — either hand it to a human with `--needs-human` or reword it
around something measurable.

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
