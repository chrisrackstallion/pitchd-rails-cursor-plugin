---
name: writing-migrations
description: >-
  Write Rails database migrations following DHH/37signals conventions —
  reversible changes, database constraints as the source of integrity, safe
  operations on live tables, and never editing past migrations. Use when
  creating or modifying migrations, adding columns or indexes, changing
  constraints, or when the user mentions migrations, schema changes, or
  database columns.
---

# Writing Rails Migrations

<objective>
Migrations are the authoritative record of how the database schema evolved.
They should be boring, reversible where possible, and safe to run on a live
production database. The schema is a contract — break it carefully, document
intent in the migration name, and enforce integrity at the database level,
not only in model validations.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| Adding a column | Read `references/patterns.md` § Adding Columns |
| Removing a column | Read `references/patterns.md` § Removing Columns (three-step) |
| Adding an index | Read `references/patterns.md` § Indexes |
| Adding a foreign key | Read `references/patterns.md` § Foreign Keys |
| Adding a NOT NULL constraint | Read `references/patterns.md` § Null Constraints |
| Data migration | Read `references/patterns.md` § Data Migrations |
| Reversibility question | Read `references/patterns.md` § Reversibility |
| Code review | Read all references, review against conventions |

### 2. Migration Structure

#### Reversible change (preferred)

Use `def change` when Rails can automatically reverse the migration. This
is the default for adding columns, adding tables, adding indexes, and adding
foreign keys:

```ruby
class AddPublishedAtToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :published_at, :datetime
    add_index :articles, :published_at
  end
end
```

#### Irreversible change (explicit)

Use `def up` and `def down` when the operation cannot be automatically
reversed, or when reverting requires a different operation:

```ruby
class ChangeArticleStatusToEnum < ActiveRecord::Migration[8.0]
  def up
    add_column :articles, :status, :integer, default: 0, null: false
    execute "UPDATE articles SET status = 0"
    remove_column :articles, :published, :boolean
  end

  def down
    add_column :articles, :published, :boolean, default: false, null: false
    execute "UPDATE articles SET published = (status = 1)"
    remove_column :articles, :status, :integer
  end
end
```

If a migration truly cannot be reversed (data is destroyed), raise in `down`:

```ruby
def down
  raise ActiveRecord::IrreversibleMigration
end
```

### 3. Decision Framework

**"Is this operation safe on a large table?"**

Some operations lock the table and block reads/writes while they run.
On a small or new table this is fine. On a large production table,
evaluate before running:

| Operation | Safety | Notes |
|-----------|--------|-------|
| `add_column` (nullable) | Safe | No table rewrite |
| `add_column` with `default:` (Rails 8+) | Safe | Rails writes default at the DB level efficiently |
| `add_column` NOT NULL, no default, existing rows | Unsafe on large tables | Add nullable first, backfill, then add constraint |
| `add_index` | Unsafe without `algorithm: :concurrently` | Locks table; use concurrent index on Postgres |
| `remove_column` | Requires three-step deploy | App must ignore column before it is removed |
| `rename_column` | Unsafe | App breaks between deploy and migration; use three-step |
| `change_column_type` | Often unsafe | Full table rewrite; use new column + backfill instead |

For Postgres: `add_index :table, :column, algorithm: :concurrently` adds
the index without a full table lock. Rails wraps this in `disable_ddl_transaction!`.

**"Does this need a data migration?"**

Schema changes (DDL) and data migrations (DML) should usually be separate
migrations. Run schema changes in the standard deploy; run data migrations
independently, or in a separate migration file after the schema is stable.

**"Is this already enforced at the model level?"**

Database constraints are the source of truth for data integrity. Model
validations are for user-facing error messages. Add the constraint in the
migration; mirror it as a validation for clear error reporting.

### 4. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Editing a past migration | Never — create a new migration to change the schema |
| Data migration in the same file as DDL | Separate migration for data; DDL is instant, DML can be slow |
| `add_column :col, :type, null: false` without a default on an existing table | Add nullable, backfill, then add constraint |
| `add_index` without `algorithm: :concurrently` on Postgres production tables | Use `algorithm: :concurrently` and `disable_ddl_transaction!` |
| `rename_column` with a live app | Three-step: add new column, dual-write, remove old |
| Putting business rules in `change` | Schema only in migrations; business logic belongs on models |
| Hardcoding data in migrations | Seeds or a separate data migration rake task |
| Migration that only works in one direction without `def down` or `raise IrreversibleMigration` | Explicit reversibility |

### 5. Naming Conventions

Migration names are the permanent record of what changed. Be specific:

| Pattern | Example |
|---------|---------|
| `add_column_to_table` | `add_published_at_to_articles` |
| `remove_column_from_table` | `remove_legacy_status_from_articles` |
| `create_table` | `create_publications` |
| `add_index_to_table` | `add_index_to_articles_on_published_at` |
| `add_foreign_key_to_table` | `add_foreign_key_to_articles_on_author_id` |
| `change_column_in_table` | `change_body_to_text_in_articles` |
| Data-only migration | `backfill_published_at_from_publications` |

### 6. Verification

Before finishing, verify:

- [ ] Migration uses `def change` where reversible; `def up` / `def down` or
  `raise ActiveRecord::IrreversibleMigration` where not
- [ ] Migration name describes exactly what changes (`add_X_to_Y`, not `update_articles`)
- [ ] Adding NOT NULL column to existing table: added nullable first, backfill
  scheduled, constraint added in follow-up migration
- [ ] Adding index to Postgres: `algorithm: :concurrently` with
  `disable_ddl_transaction!` for production tables
- [ ] Removing a column: app ignores it first (deploy 1), migration removes it
  (deploy 2)
- [ ] No data migration mixed with DDL (separate files)
- [ ] Database constraints added: `add_foreign_key`, `change_column_null`,
  `add_index unique:` where data integrity requires it
- [ ] No hardcoded IDs or environment-specific data in the migration
- [ ] `bin/rails db:migrate` followed by `bin/rails db:rollback` passes
  (verify reversibility in development)
- [ ] `schema.rb` (or `structure.sql`) committed alongside the migration

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
