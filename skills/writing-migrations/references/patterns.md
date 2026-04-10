# Migration Patterns Reference

Migrations are the authoritative, append-only record of schema changes.
Never edit a migration that has been committed to the main branch — it has
been run in production. Create a new migration instead.

---

## Adding Columns

### Nullable column (safe)

The simplest case — add a nullable column with no risk of locking:

```ruby
class AddTaglineToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :tagline, :string
  end
end
```

### Column with a default (safe in Rails 8+)

Rails passes the default to the database efficiently. No table rewrite on
Postgres 11+ or MySQL 8+:

```ruby
class AddNotificationsEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :notifications_enabled, :boolean, default: true, null: false
  end
end
```

### NOT NULL column on a table with existing rows

Adding `null: false` without a default when rows exist will fail. The safe
pattern is three steps across two deploys:

**Deploy 1 — add nullable column and backfill:**

```ruby
class AddPublishedAtToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :published_at, :datetime
  end
end
```

Backfill in a data migration or rake task (run separately from deploys):

```ruby
# lib/tasks/backfill_published_at.rake
namespace :backfill do
  task published_at: :environment do
    Article.in_batches.each_record do |article|
      article.update_column(:published_at, article.created_at)
    end
  end
end
```

**Deploy 2 — add the NOT NULL constraint once all rows have a value:**

```ruby
class AddNotNullToArticlesPublishedAt < ActiveRecord::Migration[8.0]
  def change
    change_column_null :articles, :published_at, false
  end
end
```

---

## Removing Columns

Removing a column while the app still reads or writes it causes errors.
Use a three-step process across two deploys.

**Deploy 1 — tell ActiveRecord to ignore the column:**

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  self.ignored_columns += %w[legacy_status]
end
```

**Deploy 2 — remove the column (after Deploy 1 is stable in production):**

```ruby
class RemoveLegacyStatusFromArticles < ActiveRecord::Migration[8.0]
  def change
    remove_column :articles, :legacy_status, :string
  end
end
```

After the migration runs, remove `ignored_columns` from the model.

---

## Indexes

### Standard index

```ruby
class AddIndexToArticlesOnPublishedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :articles, :published_at
  end
end
```

### Unique index

```ruby
class AddUniqueIndexToUsersOnEmail < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :email, unique: true
  end
end
```

### Composite index

Order matters: put the most selective column first unless your queries
filter on a specific combination:

```ruby
class AddIndexToArticlesOnAuthorIdAndPublishedAt < ActiveRecord::Migration[8.0]
  def change
    add_index :articles, [:author_id, :published_at]
  end
end
```

### Concurrent index (Postgres — no table lock)

For large production tables on Postgres, use `algorithm: :concurrently`
to avoid locking. This requires running outside a transaction:

```ruby
class AddIndexToArticlesOnSlug < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :articles, :slug, unique: true, algorithm: :concurrently
  end
end
```

---

## Foreign Keys

Add foreign keys for referential integrity. Rails generates a name
automatically; provide one when the default is ambiguous:

```ruby
class AddForeignKeyToArticlesOnAuthorId < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :articles, :users, column: :author_id
  end
end
```

When creating a table, declare foreign keys inline:

```ruby
class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :article, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end
  end
end
```

---

## Null Constraints

Enforce NOT NULL at the database level for columns that must always have
a value. Model validations are for error messages; constraints are for
data integrity.

```ruby
class AddNullConstraintToArticlesTitle < ActiveRecord::Migration[8.0]
  def change
    change_column_null :articles, :title, false
  end
end
```

When backfilling is needed first, see **Adding Columns § NOT NULL column
on a table with existing rows** above.

---

## Reversibility

### Automatically reversible operations

These can use `def change` — Rails generates the inverse automatically:

- `add_column` / `remove_column` (with type specified)
- `create_table` / `drop_table`
- `add_index` / `remove_index`
- `add_foreign_key` / `remove_foreign_key`
- `add_reference` / `remove_reference`
- `change_column_null`
- `rename_column` (reversible but unsafe to run on a live app — see below)
- `rename_table`

### Irreversible operations

Use `def up` / `def down`. If truly irreversible, raise:

```ruby
class MigrateArticleBodyToRichText < ActiveRecord::Migration[8.0]
  def up
    add_column :articles, :body_rich_text_id, :bigint
    # ... migration logic ...
    remove_column :articles, :body, :text
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Body content was transformed and cannot be automatically reversed."
  end
end
```

### Verify reversibility in development

```bash
bin/rails db:migrate
bin/rails db:rollback
bin/rails db:migrate
```

A migration that cannot roll back cleanly is a risk in production — you
lose the ability to revert a deploy quickly.

---

## Data Migrations

Data migrations (backfills) are separate from schema migrations. Mixing them
creates problems:

- Schema migrations run fast (DDL); data migrations can be slow (many rows)
- Schema migrations should be repeatable; data migrations are often one-time
- Slow data migrations during a deploy hold up all subsequent schema migrations

### Separate migration file for small backfills

```ruby
class BackfillSlugOnArticles < ActiveRecord::Migration[8.0]
  # Disable transaction so we can commit batches — prevents lock contention
  disable_ddl_transaction!

  def up
    Article.in_batches.each_record do |article|
      article.update_column(:slug, article.title.parameterize)
    end
  end

  def down
    # Reverting a backfill is usually a no-op — the column removal handles it
  end
end
```

### Rake task for large backfills

For tables with millions of rows, a deploy-time migration is too slow.
Use a rake task that can be run independently, monitored, and resumed:

```ruby
# lib/tasks/backfill_article_slugs.rake
namespace :backfill do
  task article_slugs: :environment do
    Article.where(slug: nil).in_batches(of: 1_000) do |batch|
      batch.each do |article|
        article.update_column(:slug, article.title.parameterize)
      end
      sleep 0.1  # rate-limit to reduce DB pressure
    end
  end
end
```

---

## Renaming a Column Safely

`rename_column` is reversible but breaks the running application between
when the migration runs and when the new deploy is live. Use a three-step
process for live systems:

**Deploy 1 — add the new column, write to both:**

```ruby
class AddDisplayNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :display_name, :string
  end
end
```

Update the model to read from the new column, write to both, and alias the old:

```ruby
# app/models/user.rb
def display_name
  self[:display_name] || self[:name]
end
```

**Deploy 2 — backfill, flip reads fully to new column, remove old:**

```ruby
class BackfillAndRemoveNameFromUsers < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE users SET display_name = name WHERE display_name IS NULL"
    remove_column :users, :name, :string
  end

  def down
    add_column :users, :name, :string
    execute "UPDATE users SET name = display_name"
  end
end
```
