# {{PROJECT_NAME}} Docs

Documentation split into **5 content layers** (product · spec · design · insights · decisions),
each with a different update frequency, plus a few cross-cutting **process** files.

Agent rules "when to read / when to write" — in [`agent-workflow.md`](./agent-workflow.md).

## How this folder gets populated

A fresh install scaffolds only the **process files + empty layer folders** — it does
**not** drop empty stubs for every doc. Everything in the manifest below marked
`on demand` is created later, by you or by a routine, when there's something real to
put in it. So a file being absent means "not written yet", not "missing" — don't treat
gaps as drift (the `docs-audit` routine follows the same rule).

## File manifest

**Scaffolded on install** (present in every project from day one):

| File | Purpose | Update frequency |
|---|---|---|
| `README.md` | This map | As structure changes |
| `agent-workflow.md` | When agents read / write each doc + task triage loop | As changed |
| `tasks.md` | Task field taxonomy + agent triage loop | Quarterly |
| `auto-approve.md` | Which findings a routine may auto-approve | As changed |
| `decisions/TEMPLATE.md` | ADR template (context → decision → verification) | — |
| `decisions/README.md` | ADR index (list of accepted decisions) | As made |

**Created on demand** (folder exists; file appears when there's content):

| File | Layer / frequency | Purpose |
|---|---|---|
| `product/product.md` | product · quarterly | Product description, pain points, audience, stage |
| `product/audience.md` | product · quarterly | User segments |
| `product/use-cases.md` | product · quarterly | Usage scenarios |
| `product/competitors.md` | product · quarterly | Competitive landscape |
| `product/positioning.md` | product · quarterly | Positioning, value prop |
| `product/pricing.md` | product · as changed | Pricing tiers, billing |
| `product/marketing.md` | product · monthly | Marketing channels and messages |
| `product/metrics.md` | product · monthly | North-star metrics + analytics event **definitions** |
| `product/glossary.md` | product · as changed | Domain terms and entities |
| `spec/flows/*.md` | spec · weekly | User-flow descriptions (`TEMPLATE.md` inside) |
| `spec/screens/inventory.md` | spec · weekly | Screen inventory |
| `spec/data-model.md` | spec · per migration | Data model summary (from ORM schema) |
| `design/components.md` | design · weekly | Component registry |
| `design/patterns.md` | design · situational | UI patterns and states (loading/empty/error) |
| `design/assets/` | design · situational | Logos, illustrations, OG images |
| `decisions/NNNN-*.md` | decisions · as made | One accepted decision per file |

**Insights** (`insights/` — time-stamped snapshots; each subfolder is created only when its
module is enabled at install):

| Folder | Enabled by | Contents |
|---|---|---|
| `insights/qualitative/` | always | Interviews, feedback, session recordings |
| `insights/analytics/` | analytics module | Analytics / HogQL snapshots |
| `insights/search-console/` | gsc module | Google Search Console snapshots |
| `insights/seo-audit/` | gsc module | SEO audit snapshots |
| `insights/ads/` | ads module | Paid-ads snapshots |
| `insights/docs-audit/` | docs-audit routine | Docs↔code drift snapshots |

## Reading order for newcomer / AI agent

Once the docs are filled in, read them in this order (skip any not yet written):

1. `product/product.md` — what is this
2. `product/audience.md` + `product/use-cases.md` — who and why
3. `product/competitors.md` + `product/positioning.md` — what's different
4. `spec/data-model.md` + `spec/screens/inventory.md` — how it's built
5. `design/components.md` + `design/patterns.md` — how we build UI
6. `product/metrics.md` + last 2–3 files from `insights/analytics/` — what's working now
7. `decisions/README.md` + `decisions/` — what decisions have already been made
