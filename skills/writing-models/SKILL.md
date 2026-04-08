---
name: writing-models
description: >-
  Write Rails models following DHH/37signals conventions — rich domain models,
  concerns for horizontal behaviour, state-as-records, scopes, database
  constraints, and vanilla Rails patterns. Use when creating new models,
  adding model methods, extracting concerns, refactoring model logic, or
  when the user mentions models, concerns, scopes, callbacks, or domain logic.
---

# Writing Rails Models

<objective>
Write models that are rich domain objects — the heart of the application, not
anaemic data bags. Models own business logic, express domain language, and
keep controllers thin. Follow DHH/37signals conventions: concerns for
horizontal behaviour, state tracked as records, database-backed everything,
and clarity over cleverness.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New model | Read `references/patterns.md`, scaffold the model |
| New concern | Read `references/patterns.md` § Concerns |
| Scopes / queries | Read `references/patterns.md` § Scopes |
| State tracking | Read `references/patterns.md` § State as Records |
| Refactoring | Read `references/patterns.md`, identify which pattern applies |
| Code review | Read all references, review against conventions |

### 2. Model Structure

Organise every model in this order:

```ruby
class Article < ApplicationRecord
  # 1. Concerns (capabilities this model has)
  include Publishable
  include Taggable
  include Searchable

  # 2. Constants
  VISIBILITIES = { public: "public", private: "private", unlisted: "unlisted" }.freeze

  # 3. Associations (belongs_to first, then has_many, then has_one)
  belongs_to :author, class_name: "User", default: -> { Current.user }
  has_many :comments, dependent: :destroy

  # 4. Delegated types / enums / store accessors
  enum :visibility, VISIBILITIES, default: :public

  # 5. Normalizes
  normalizes :title, with: ->(t) { t.strip }

  # 6. Validations (minimal — database constraints do the heavy lifting)
  validates :title, presence: true

  # 7. Scopes
  scope :chronologically, -> { order(created_at: :asc) }
  scope :preloaded, -> { includes(:author, :tags) }

  # 8. Callbacks (sparingly)
  after_create_commit :notify_subscribers_later

  # 9. Class methods
  def self.search(query)
    where("title ILIKE ?", "%#{query}%")
  end

  # 10. Public instance methods — domain verbs
  # (publishing is handled by the Publishable concern via state record)

  private
    def notify_subscribers_later
      NotifySubscribersJob.perform_later(self)
    end
end
```

The `Publishable` concern (from `references/patterns.md`) provides `publish`,
`unpublish`, `published?`, and scopes like `published` / `unpublished` via a
`Publication` state record. Enums are used for a *different* dimension
(`visibility`) that doesn't need audit trails. Never mix both patterns for the
same concept.

### 3. Decision Framework

Before writing code, ask these questions:

**"Does this logic belong on the model?"**
- Operates on a single model instance → model method
- Crosses model boundaries → controller orchestration or a PORO namespaced under the primary model (e.g. `Article::Publisher`)
- Hits external systems → job for async; PORO or model method for sync
- Shared across unrelated models → concern
- Pure presentation → helper or component

**"Is this a new concept or a capability?"**
- New concept (own table, own identity) → new model
- Capability added to existing model → concern
- Derived/computed state → method on the model

**"Boolean column or state record?"**
- Need to know *when* and *who* → state record
- Simple flag with no history → boolean is acceptable
- Will be queried with joins → state record

### 4. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Service wrapping a single `update!` | Model method |
| `app/services/` single-method service objects | Model method or PORO under model namespace |
| Callback chains for business logic | Explicit method calls |
| `before_save` touching other models | Controller orchestration or explicit call |
| Fat controller with inline queries | Named scopes |
| Generic `set_X` / `update_X` methods | Domain verbs (`publish`, `close`) |
| Boolean columns for auditable state | State records with timestamps |
| Model validations for data integrity | Database constraints |
| `rescue => e` in model methods | Let exceptions propagate |
| `default_scope` | Named scopes — `default_scope` contaminates all queries |
| `ActiveRecord::Base` subclass with no table | `ActiveModel::Model` instead |
| Conditional validations (`if:` / `on:`) | Form objects for workflow-specific validation |

### 5. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Concerns | Adjective describing capability | `Publishable`, `Closeable`, `Watchable` |
| Scopes | Adverb or business term | `chronologically`, `active`, `preloaded` |
| State records | Noun for the state | `Closure`, `Publication`, `Archival` |
| Verbs | Domain action (non-bang) | `publish`, `close`, `archive`, `gild` |
| Predicates | State query | `published?`, `closed?`, `golden?` |
| POROs | Namespaced under parent | `Article::Summary`, `User::Filtering` |

### 6. Verification

Before finishing, verify:

- [ ] No logic that belongs in a service sitting on the model (multi-model, external calls)
- [ ] No logic that belongs on the model sitting in a service (single-model operations)
- [ ] Concerns are self-contained (associations + scopes + methods together)
- [ ] Database constraints back up any model validations
- [ ] Scopes handle all domain queries — no raw `where` chains in controllers
- [ ] Callbacks are limited to async dispatch and derived data
- [ ] Method names use domain language, not generic CRUD terms
- [ ] Bang methods used for operations where failure is exceptional

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
