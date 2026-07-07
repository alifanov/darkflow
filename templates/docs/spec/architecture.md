# Architecture

> Update when the system shape changes (new service, new integration, stack swap).
> Read this **first** before any non-trivial code change — it's the map an agent needs
> to navigate the repo. `data-model.md` covers the DB; this file covers everything else.

---

## Stack

| Layer | Tech | Notes |
|---|---|---|
| Language / runtime | *e.g. TypeScript / Node 24* | |
| Framework | *e.g. Next.js App Router* | |
| Data store | *e.g. Postgres via Prisma* | see `spec/data-model.md` |
| Hosting / deploy | *e.g. host process + Docker for DB* | |

---

## Top-level modules

*The main parts of the codebase and what each is responsible for. One row per module —
enough that an agent knows where a given change belongs.*

| Module / path | Responsibility |
|---|---|
| `src/...` | *what lives here* |
| | |

---

## Entry points

*Where execution starts — HTTP routes, CLI commands, workers, cron/scheduled jobs.*

- *e.g. `app/api/**/route.ts` — REST route handlers*
- *e.g. `worker.ts` — background job runner*

---

## External integrations

| Service | Purpose | Where it's wired | Auth / secret |
|---|---|---|---|
| *e.g. Stripe* | billing | `src/lib/stripe.ts` | `STRIPE_KEY` |
| | | | |

---

## How a request flows

*One short walkthrough of the primary path (request → handler → data → response), so an
agent can trace behavior without reverse-engineering it from scratch.*

---

## Invariants & gotchas

- *Non-obvious rules that hold across the system — e.g. "all money in integer cents",
  "every mutation goes through a route handler, never a server action".*
