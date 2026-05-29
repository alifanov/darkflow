# Flow: {{Flow name}}

> Copy this file and rename it (e.g. `auth.md`, `onboarding.md`, `checkout.md`).
> Update when the flow changes. See `agent-workflow.md` → "When to write".

---

## Overview

*One sentence: what the user is trying to accomplish in this flow.*

**Entry points:** *where users start this flow*
**Exit points:** *where they end up after success or abandonment*

---

## Happy path

1. User does X
2. System does Y
3. User sees Z
4. ...

---

## States

| State | What the user sees | What triggers it |
|---|---|---|
| Loading | spinner / skeleton | *request in flight* |
| Empty | empty state message | *no data yet* |
| Error | error message + retry | *request failed* |
| Success | confirmation | *action completed* |

---

## Edge cases

- *What happens if the user is not authenticated?*
- *What happens on network failure?*
- *What if the required data is missing?*

---

## Related screens

- `spec/screens/inventory.md` rows: *list the screen names*

## Related decisions

- *Link to any ADR that affected this flow*
