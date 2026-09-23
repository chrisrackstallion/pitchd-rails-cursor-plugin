---
name: writing-migrations
description: >-
  Write Rails database migrations — reversible changes, database constraints
  as the source of integrity, safe operations on live tables, never editing
  past migrations. Use when creating or modifying migrations, adding columns
  or indexes, changing constraints, or when the user mentions migrations,
  schema changes, or database columns.
---

# Writing Rails Migrations

<objective>
Migrations are the authoritative record of how the database schema evolved.
They should be boring, reversible where possible, and safe to run on a live
production database.
</objective>

The rules — reversibility, database constraints, the operation-safety matrix,
naming, anti-patterns, and the verification checklist — live in
**`agent_harness_rails/rules/migrations.mdc`**. Read it first.

## Routing

| Task | Read |
|------|------|
| Adding a column | `references/patterns.md` § Adding Columns |
| Removing a column | `references/patterns.md` § Removing Columns |
| Adding an index | `references/patterns.md` § Indexes |
| Adding a foreign key | `references/patterns.md` § Foreign Keys |
| Adding a NOT NULL constraint | `references/patterns.md` § Null Constraints |
| Data migration / backfill | `references/patterns.md` § Data Migrations |
| Renaming a column | `references/patterns.md` § Renaming a Column Safely |
| Reversibility, `up` / `down` conversions | `references/patterns.md` § Reversibility |
| Code review | `agent_harness_rails/rules/migrations.mdc` § Verification |
