# UI Patterns

> Update situationally. Read before implementing loading, error, or empty states — use consistent patterns everywhere.

---

## Loading states

| Context | Pattern | Component |
|---|---|---|
| Full page | skeleton layout | `<Skeleton>` |
| Button after click | spinner inside button, disabled | `<Button loading>` |
| Inline data | skeleton rows | `<Skeleton>` |

---

## Empty states

| Context | What to show | CTA |
|---|---|---|
| List with no items | illustration + message | *primary action* |
| Search with no results | "No results for X" | clear search |
| Feature not set up | explanation + setup link | setup CTA |

---

## Error states

| Error type | What to show | Recovery action |
|---|---|---|
| Network / 5xx | "Something went wrong" + retry | retry button |
| 404 | "Not found" | go back / home |
| Validation | inline field error | — |
| Permission | "You don't have access" | contact / upgrade |

---

## Confirmation dialogs

*When do we ask for confirmation vs. just act? Rule: destructive or irreversible actions always confirm.*

---

## Toasts / notifications

| Event | Type | Duration |
|---|---|---|
| Action success | success | 3s |
| Non-critical error | error | 5s |
| Background process started | info | 3s |
