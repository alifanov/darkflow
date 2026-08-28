---
name: openpanel
description: Query self-hosted OpenPanel analytics — funnel counts, unique users, breakdowns by os/country/path, raw events. Use whenever analytics numbers are needed: funnel conversion, visitor counts, event counts over a window, period-over-period deltas, "how many signups/checkouts/sessions", or any /darkflow:analytics-review style run. Replaces the openpanel MCP server, which is broken.
---

# OpenPanel CLI

`openpanel` is the only supported way to read OpenPanel here. **Do not use or try to
reconnect the `openpanel` MCP server** — `openpanel-mcp-server@1.0.0` never answers the
MCP `initialize` handshake, so every client times out after 30 s. It has been removed
from project `.mcp.json` files. Nothing about that is fixable from this side.

```bash
~/.darkflow/openpanel <command> [options]
```

Installed and versioned by Dark Flow (`install.sh` → `~/.darkflow/openpanel`), so every
project on this machine runs the same script. `~/.claude/skills/openpanel/openpanel` is a
symlink to it, kept so this skill stays self-contained — both paths are the same file.

## Commands

| Command | What it gives |
|---|---|
| `funnel --events a,b,c` | one row per event: total, unique devices, unique profiles |
| `breakdown --event X --by os\|browser\|country\|city\|path` | that event grouped |
| `events --event X` | raw event JSON (escape hatch) |
| `selftest` | asserts the pagination walk still holds — run after editing the script |

Shared options: `--start`/`--end` (`YYYY-MM-DD`), `--days N` (default 7), `--paths a,b`
(client-side path allowlist), `--json`, `--project`. `funnel` also takes `--prev` for the
preceding equal-length window and a `Δ events` column.

```bash
OP=~/.darkflow/openpanel

# canonical funnel, last full 7 days, with period-over-period delta
$OP funnel --prev --end 2026-08-16 --days 7 \
  --events session_start,user_signed_up,scan_created,checkout_initiated,payment_succeeded

# where the biggest drop happens, by platform
$OP breakdown --event user_signed_up --by os --days 7

# top-of-funnel restricted to landing paths
$OP funnel --events session_start --paths /,/visualping-alternative --days 7
```

## Credentials and project

Per project, first non-empty wins. Run it **from the project directory** — the search for
`.env` starts at the CWD, so the CWD is what picks the project.

1. the real environment
2. the nearest `.env` at or above the CWD
3. `.claude/settings.local.json` → `env` at the git root (where Claude Code keeps them)
4. `~/.darkflow/env` — machine-wide fallback, in practice only the API URL

| Variable | Note |
|---|---|
| `OPENPANEL_API_URL` | e.g. `https://openpanel.chatindex.app/api`; falls back to `NEXT_PUBLIC_OPENPANEL_API_URL` (not a secret, and instrumented projects already ship it) |
| `OPENPANEL_READ_CLIENT_ID` | falls back to `OPENPANEL_CLIENT_ID` |
| `OPENPANEL_READ_CLIENT_SECRET` | falls back to `OPENPANEL_CLIENT_SECRET` |
| `OPENPANEL_PROJECT_ID` | optional; otherwise the git-root directory name, or `--project` |

Read-only by design: the endpoint is `GET /export/events` and there is no write path.
This instance exposes no chart or aggregate endpoint, so every number is counted
client-side from raw rows.

## What this endpoint cannot give you

`/export/events` returns only these fields per event:

```
id  name  deviceId  profileId  projectId  sessionId  createdAt
country  city  os  browser  duration  path
```

**Event properties are not exposed.** No `plan`, `amount`, `currency`, `source`, `trigger`,
`method` — nothing a `track()` call attached. Adding `includes=properties,referrer,...` to
the query (as an older reader did) does **not** help: measured 2026-08-17, the field set
comes back identical and only the already-untrustworthy `totalCount` changes. Anything
keyed on a property therefore cannot be answered here: revenue from a payment event's
`amount`, a split by `plan` or `source`, `method` on a signup. Report those as **not
measurable via the CLI** rather than as zero, and take them from the source of truth
instead (the billing provider for revenue, the database for plan mix).

There is also **no `device` field** — only `deviceId`. Mobile vs desktop reads off `os`,
which is why `--by` has no `device` choice.

`profileId` is stable per user once identified, so per-user funnels *are* possible: pull
`events` for each stage and intersect the profile sets.

## Four API defects this CLI works around

Numbers straight from the raw endpoint are wrong in four ways (1–3 measured 2026-08-17,
4 measured 2026-08-28, against `openpanel.chatindex.app`). All four are handled inside
the script; they matter when reading its output or editing it.

1. **A `limit` above ~10 truncates the walk.** The server honours the number itself —
   `limit=100` really returns 100 rows — but then calls page 2 empty. The same window
   yields **80** unique rows at `limit=10` and **4** at `limit=100`. `PAGE_LIMIT = 10`
   is therefore deliberate, and `selftest` asserts the small page is still the honest one.
2. **Page 1 is short** — ~4 rows whatever the limit, with the full pages starting at page
   2. Any loop that stops on `len(rows) < limit` exits immediately and reports ~5% of the
   truth. The script walks to a genuinely empty page and dedupes by event id.
3. **`meta.totalCount` tracks neither the window nor the row set** — 25 claimed for a
   window whose real set is 80 rows, and adding `includes=` to the query moved the same
   claim from 25 to 272. It is reported as `claimed` and never believed.
4. **No single query is complete — `fetch()` returns the union of a wide walk and a walk
   per day.** The two miss different rows, and slicing finer does not converge:
   * a multi-day walk drops whole days for a *sparse* event — `scan_created` over
     22–28.08 serves page 1 (two rows dated 27.08), page 2 (two rows dated 22.08), then
     empty pages forever: **4 rows of the real 11**;
   * a per-day walk misses rows only the wide window returns — on 24.08 the day window
     and its 6-hour slices both give 11 `session_start`, while the 22–28 walk returns two
     more (05:35 and 06:34 UTC).

   Dense events were always counted right by the wide walk, which is why this hid for so
   long: `selftest` runs on `session_start`. **A hand-rolled query over a multi-day window
   silently undercounts a sparse event by ~3x** — use the CLI, or query day by day and
   union with the wide window.

**Both `start` and `end` are inclusive**, and they *are* honoured (rows never fall outside
the requested window — asserted by `selftest`). `--days 7` therefore spans `end-6..end`;
taking `end-7` would put the boundary day in both the current and previous window and
double-count it in every delta.

## Reading the output

- **Count users, not events.** Some events fire twice per action by design (a server
  send plus a client send), so `devices` / `profiles` are usually the honest number.
- **`profiles` covers server-side events, `devices` does not** — server sends carry no
  `deviceId`, and their `country` is two NUL bytes, shown as `(server/unset)`.
- A `warning: ... hit MAX_PAGES` line on stderr means the count is a floor, not a total.
- Event names are project-specific: read the project's metrics doc (for pageradar,
  `docs/state/product/metrics.md`) rather than guessing. A name that does not exist
  returns an empty series, which is indistinguishable from a real zero.
