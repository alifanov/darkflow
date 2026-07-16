# Hypotheses

Central ledger of product hypotheses — every bet being tracked, from first signal to
verdict. Snapshots in `insights/*/` hold the raw evidence; this file holds the **current
state** of each hypothesis. One entry of truth per bet.

Agents must read this file before creating tasks from analytics/ads/GSC findings —
a hypothesis already refuted here must not come back as a new task without new data.

Lifecycle: `tracking` (collecting evidence) → `testing` (task / experiment in flight) →
`confirmed` / `refuted` / `abandoned`. IDs are sequential (`H-001`, `H-002`, …) and never reused.

---

## Active

<!-- One section per open hypothesis. Example:

### H-001 — checkout drop is caused by the new address form
- **Hypothesis**: the 3-field address form added on 2026-05-20 increases friction on mobile
- **Expected impact**: +8–12% checkout conversion if reverted/simplified
- **Verification**: funnel step `address_submitted` recovers after simplification
- **Evidence**: insights/analytics/2026-05-27.md (−12%), insights/analytics/2026-05-28.md (−8%)
- **Status**: tracking (2/3 snapshots)
- **Task**: — (created when the evidence threshold is reached; then link task #N)
-->

*(no active hypotheses yet)*

---

## Closed

One line per verdict — move entries here from Active:

| ID | Hypothesis | Verdict | Evidence | Task |
|---|---|---|---|---|
| | | confirmed / refuted / abandoned | | |
