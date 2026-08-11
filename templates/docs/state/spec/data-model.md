# Data Model

Current data model for this project. Update this file whenever the database schema changes (`When to write` rule in `agent-workflow.md`).

---

## Entities

### `<EntityName>`

| Field | Type | Description | Constraints |
|---|---|---|---|
| `id` | uuid | Primary key | NOT NULL, unique |
| `created_at` | timestamp | Creation time | NOT NULL |
| | | | |

*Duplicate this section for each entity.*

---

## Relationships

```
EntityA ──< EntityB     (one-to-many: one A has many B)
EntityB >──< EntityC    (many-to-many via join table)
EntityA ──── EntityD    (one-to-one)
```

*Replace with actual entity names and relationships.*

---

## Key Constraints and Invariants

- *List any non-obvious constraints that aren't obvious from field types alone*
- *Example: "A subscription can only have one active period at a time"*
- *Example: "User.email is unique across soft-deleted records too"*

---

## Indexes

| Table | Index | Reason |
|---|---|---|
| | | |

---

## Soft Deletes

*Does this project use soft deletes? If yes, which tables and how (`deleted_at`, `is_deleted`, etc.)?*

---

## Notes

- ORM / migration tool: *e.g. Prisma, Drizzle, Alembic*
- Migration files: *e.g. `webapp/prisma/migrations/`*
