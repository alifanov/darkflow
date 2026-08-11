# Screen Inventory

Complete list of all screens / pages in this project. Update this file when screens are added or removed (`When to write` rule in `agent-workflow.md`).

---

## Screens

| Path | Name | Status | Auth required | Figma |
|---|---|---|---|---|
| `/` | Landing | planned / implemented / deprecated | no | |
| `/login` | Login | | no | |
| `/signup` | Sign Up | | no | |
| `/dashboard` | Dashboard | | yes | |

*Add a row for every route in the app.*

---

## Status definitions

| Status | Meaning |
|---|---|
| `planned` | Designed or specced, not yet built |
| `implemented` | Live in production |
| `wip` | In development |
| `deprecated` | Exists but scheduled for removal |

---

## Notes

- One row per distinct URL pattern (use `:param` for dynamic segments, e.g. `/projects/:id`)
- Modal overlays that don't have their own URL are noted in the parent screen's row, not as separate entries
- Figma column: paste the Figma frame link directly
