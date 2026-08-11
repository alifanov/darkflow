# Product Metrics

Canonical definitions of all tracked metrics and analytics events for this project. **This is a definition file, not a values file** — actual measurements live in `docs/insights/analytics/`.

Agents must read this file before writing analytics queries or instrumentation code to avoid inventing event names.

---

## North Star Metric

| Metric | Definition | Analytics event |
|---|---|---|
| *define your north star here* | | |

---

## Acquisition

| Metric | Definition | Analytics event / property | Goal |
|---|---|---|---|
| Visitors (7d) | Unique visitors in last 7 days | `$pageview` | |
| Signups | New accounts created | `user_signed_up` | |
| Activation rate | % of signups who complete onboarding | `onboarding_completed` / `user_signed_up` | |

---

## Engagement

| Metric | Definition | Analytics event / property | Goal |
|---|---|---|---|
| DAU / MAU | Daily vs monthly active users | `$pageview` (distinct users) | |
| Core action | *define the action that defines "active"* | | |

---

## Retention

| Metric | Definition | Analytics event / property | Goal |
|---|---|---|---|
| Day-7 retention | % of signups still active 7 days later | | |
| Day-30 retention | % of signups still active 30 days later | | |

---

## Revenue

| Metric | Definition | Analytics event / property | Goal |
|---|---|---|---|
| MRR | Monthly recurring revenue | `subscription_started`, `subscription_cancelled` | |
| Conversion rate | % of signups who pay | `payment_completed` / `user_signed_up` | |
| ARPU | Average revenue per active user | MRR / MAU | |

---

## Analytics event registry

Full list of custom events instrumented in this project:

| Event name | When it fires | Key properties |
|---|---|---|
| *add events as you instrument them* | | |

---

## Notes

- Event names follow snake_case
- All monetary values in `currency` property (ISO 4217 code)
- Update this file whenever a new event is added to the codebase (`When to write` rule in `agent-workflow.md`)
