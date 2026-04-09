# Model Patterns Reference

## Concerns

Concerns extract horizontal behaviour shared across models or decompose a
large model into cohesive units. Each concern is a self-contained module
that bundles associations, scopes, callbacks, and methods for one capability.

### Structure

```ruby
# app/models/concerns/publishable.rb
module Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, as: :publishable, dependent: :destroy

    scope :published, -> { joins(:publication) }
    scope :unpublished, -> { where.missing(:publication) }
  end

  def published?
    publication.present?
  end

  def publish(by: Current.user)
    create_publication!(publisher: by)
  end

  def unpublish
    publication&.destroy!
  end
end
```

### Guidelines

- **50–150 lines** — if a concern exceeds 150 lines, it likely contains
  multiple responsibilities
- **Named as adjectives** — `Publishable`, `Closeable`, `Watchable`,
  `Searchable`, `Taggable`
- **Self-contained** — include all associations, scopes, and methods the
  capability needs; don't scatter related code across multiple concerns
- **Not for mere organisation** — don't create `UserCallbacks` or
  `UserValidations` concerns; extract when there's genuine reuse or the
  capability is a distinct concept
- **One concern, one concept** — `Closeable` handles closing/reopening;
  it should not also handle archiving

### When to Extract

Extract a concern when:
- Two or more models share the same behaviour (horizontal reuse)
- A model file exceeds ~300 lines and contains distinct capability clusters
- A concept has its own vocabulary (verbs, predicates, scopes)

Don't extract when:
- The code is only used by one model and fits comfortably in the file
- You're just moving code to make the model "look cleaner"

---

## State as Records

Instead of boolean columns, create a separate model that represents the
state. The record's existence *is* the state.

### Pattern

```ruby
# Migration
create_table :closures do |t|
  t.references :closeable, polymorphic: true, null: false, index: { unique: true }
  t.references :creator, null: false, foreign_key: { to_table: :users }
  t.timestamps
end

# State record
class Closure < ApplicationRecord
  belongs_to :closeable, polymorphic: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }
end

# Concern on the parent model
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
  end

  def closed?   = closure.present?
  def open?     = !closed?

  def close(by: Current.user)
    create_closure!(creator: by)
  end

  def reopen
    closure&.destroy!
  end
end
```

### Querying

```ruby
Card.joins(:closure)          # all closed cards
Card.where.missing(:closure)  # all open cards
```

### When to Use

| Scenario | Use |
|----------|-----|
| Need to know *who* made the change | State record |
| Need to know *when* it happened | State record |
| Need to query by state with joins | State record |
| Simple flag, no audit trail needed | Boolean column |
| Toggled frequently with no history | Boolean column |

### Enums, state records, and state machine gems

Rails already gives you most of what you need: **associations**, **transactions**,
**validations**, and **domain verbs** on the parent. A **child row whose presence
is the state** is often the smallest accurate model. Prefer proving you need a
**state machine gem** (AASM, Statesman, Workflow, etc.) with **real complexity**,
not because “serious apps use state machines.”

| Layer | Use when |
|-------|----------|
| **`enum` on a column** | Small ordered lifecycle (`draft` → `active` → `archived`), no rich audit on that axis, transitions stay obvious |
| **State record** (`has_one` / polymorphic child) | Binary or few modes; need **timestamps, actor, joins**; **destroy** = revert feels natural |
| **Per-transition / history table** | Compliance, undo, or **timeline** is a product requirement — not for every app by default |
| **State machine gem** | **Many named states**, **non-obvious allowed transitions**, **guards** across several attributes, or **external workflow** integration would otherwise sprawl |

**Retention:** Reverting with `destroy` fits when the child row is only current state plus metadata and **discarding the row is allowed**. If **policy forbids deletes** (audit retention, legal hold), use a **history table**, **superseding rows**, or **soft flags** on a durable record — not `DELETE` as undo.

**Heuristic:** If the lifecycle fits **two or three nouns** on a napkin and rules
live in **a few well-named methods**, you likely need **better names and maybe
one more table** — not a gem.

### REST and noun resources

State changes map cleanly to **noun resources** and standard HTTP (`POST` to
create the state record, `DELETE` to remove it). Routing, authorization, and
request specs stay conventional. Generic **`transition_to!`**-style APIs on the
model often **fight REST** and duplicate policy boundaries — prefer resources
like `Cards::ClosuresController` (see the writing-controllers skill) unless the
domain truly is a single object with a complex internal machine.

### Anti-patterns (state machines)

- **Callback-heavy gems** driving transitions through `after_save` or magic
  hooks — same pain as callback-heavy domain logic; hard to test and follow.
- **Scattered** `if` / `case` on `state` across controllers and jobs when **one
  place** (model verbs or a small PORO next to the model) would do.
- **Over-modeled enums** — twelve `status` values when the domain is really
  **“has publication” / “has closure”** plus clear verbs.
- **Reaching for a gem** before **state-as-record + verbs** has been tried.

### When a state machine library is justified

- Large **transition matrix** with role-based or attribute-heavy **guards**.
- **External workflow** or BPM integration with a contract that expects a
  formal state model.
- Team agreement that the gem’s API is the **single choke point** for
  transitions — not as a substitute for modeling state as data.

### Contrast — verbs and records vs callback transitions

Prefer explicit verbs and Active Record calls:

```ruby
def close(by: Current.user)
  transaction { create_closure!(creator: by) }
end
```

Avoid packing domain rules into transition callbacks on a gem unless the
**matrix** truly warrants centralization — and even then, keep side effects in
**`after_commit`** when they must be async.

---

## Scopes

Scopes express domain queries as named, chainable methods on the model.
They keep controllers readable and centralise query logic.

### Standard Names

```ruby
scope :chronologically,         -> { order(created_at: :asc) }
scope :reverse_chronologically, -> { order(created_at: :desc) }
scope :alphabetically,          -> { order(title: :asc) }
scope :latest,                  -> { reverse_chronologically.limit(10) }
scope :preloaded,               -> { includes(:creator, :tags, :comments) }
```

### Parameterised Scopes

```ruby
scope :by_status, ->(status) { where(status: status) }
scope :created_after, ->(date) { where(created_at: date..) }
```

When accepting sort columns from user input, **allowlist** the column names:

```ruby
SORTABLE_COLUMNS = %w[title created_at updated_at].freeze

scope :sorted_by, ->(col, dir = :asc) {
  order(col => dir) if col.in?(SORTABLE_COLUMNS)
}
```

### Complex Queries as Class Methods

When a scope needs conditionals or multiple steps, use a class method:

```ruby
def self.available_for(project, search: nil)
  scope = published
  scope = scope.search(search) if search.present?
  scope.where.not(id: project.assigned_ids)
end
```

### Guidelines

- Use **business terms** for scope names: `active`, `pending`, `featured`
  — not SQL-ish names like `with_status_active`
- One `preloaded` scope per model for standard eager loading
- Scopes should be **composable** — each does one thing
- **Never use `default_scope`** — it contaminates every query, breaks
  `unscoped` expectations, and hides intent. Use named scopes instead.

---

## Validations

### Philosophy

Database constraints are the source of truth for data integrity. Model
validations exist to produce user-facing error messages.

```ruby
# Migration — enforces integrity
add_index :users, :email, unique: true
change_column_null :users, :email, false
add_check_constraint :products, "price >= 0", name: "products_price_positive"

# Model — provides error messages for forms
validates :email, presence: true,
                  uniqueness: { case_sensitive: false },
                  format: { with: URI::MailTo::EMAIL_REGEXP }
validates :price, numericality: { greater_than_or_equal_to: 0 }
```

### Contextual Validations

For validations specific to a workflow (signup, onboarding, publishing),
use form objects instead of conditional model validations. Form objects
live in `app/models/` — they are models, just not database-backed ones.

```ruby
# app/models/signup.rb
class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :name, :string
  attribute :terms_accepted, :boolean

  validates :email, :name, presence: true
  validates :terms_accepted, acceptance: true

  def save
    return false unless valid?
    User.create!(email: email, name: name)
  end
end
```

---

## Callbacks

### Use For

- `after_commit` / `after_create_commit` — enqueue async work
- `before_save` — compute derived data from the model's own attributes
- `before_validation` — normalise data (prefer `normalizes` in Rails 7.1+)

### Avoid

- Callbacks that touch other models
- Callbacks that call external services
- Chains of callbacks that create ordering dependencies
- `after_save` for side effects (use `after_commit` for safety)

```ruby
# Good — async dispatch after commit
after_create_commit :notify_watchers_later

private
  def notify_watchers_later
    NotifyWatchersJob.perform_later(self)
  end
```

```ruby
# Good — derived data from own attributes
before_save :update_slug, if: :title_changed?

private
  def update_slug
    self.slug = title.parameterize
  end
```

---

## Associations

### Ordering

Declare associations in this order: `belongs_to`, `has_many`, `has_one`,
`has_and_belongs_to_many`.

### Defaults with Current

```ruby
belongs_to :creator, class_name: "User", default: -> { Current.user }
belongs_to :account, default: -> { Current.account }
```

### Counter Caches

Avoid N+1 count queries with `counter_cache`:

```ruby
class Comment < ApplicationRecord
  belongs_to :article, counter_cache: true
end
```

Requires a `comments_count` integer column on the `articles` table
(default `0`). Rails increments/decrements it automatically.

### Touch Chains for Cache Invalidation

```ruby
class Comment < ApplicationRecord
  belongs_to :article, touch: true
end

class Article < ApplicationRecord
  belongs_to :section, touch: true
end
```

When a comment updates, `article.updated_at` changes, cascading to section.

### Dependent Strategy

| Strategy | When |
|----------|------|
| `dependent: :destroy` | Child has callbacks or its own dependents |
| `dependent: :delete_all` | Clean table, no callbacks needed |
| `dependent: :nullify` | Child should survive, just unlink |

### Strict Loading

Prevent N+1 queries by raising when associations are lazily loaded:

```ruby
class Article < ApplicationRecord
  has_many :comments, strict_loading: true
end
```

Or enforce it per-query:

```ruby
articles = Article.strict_loading.includes(:author).all
articles.first.comments # raises ActiveRecord::StrictLoadingViolationError
```

Use `:n_plus_one_only` mode to only flag actual N+1 patterns:

```ruby
user.strict_loading!(mode: :n_plus_one_only)
```

### Deprecated Associations (Rails 8.1+)

Flag associations scheduled for removal. Access triggers a deprecation
warning (configurable to `:warn`, `:raise`, or `:notify`):

```ruby
class Author < ApplicationRecord
  has_many :legacy_posts, deprecated: true
end
```

---

## Modern Rails Features

### Normalizes (Rails 7.1+)

Clean data before validation — replaces `before_validation` for simple transforms:

```ruby
normalizes :email, with: ->(email) { email.strip.downcase }
normalizes :phone, with: ->(phone) { phone.gsub(/\D/, "") }
normalizes :name,  with: ->(name)  { name.squish }
```

### Delegated Types

Replace complex polymorphic associations with type-safe delegation:

```ruby
class Message < ApplicationRecord
  delegated_type :messageable, types: %w[Comment Reply Announcement]
end

message.comment?     # type check
message.comment      # returns the Comment
Message.comments     # scope for Comment messages
```

### Store Accessors

Structured JSON storage for settings-like data:

```ruby
store :settings, accessors: %i[theme locale notifications_enabled], coder: JSON
```

### Enum

```ruby
enum :status, { draft: "draft", published: "published", archived: "archived" },
     default: :draft

# Gives you: article.draft?, article.published!, Article.published
```

### generates_token_for (Rails 7.1+)

Generate expiring tokens that embed record data. The token auto-expires
when the block's return value changes (e.g. password is reset):

```ruby
class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end
end

token = user.generate_token_for(:password_reset)
User.find_by_token_for(:password_reset, token) # => user
# After password change:
User.find_by_token_for(:password_reset, token) # => nil
```

### has_secure_password

Built-in bcrypt authentication. Requires `gem "bcrypt"` in Gemfile and a
`password_digest` column on the model's table:

```ruby
class User < ApplicationRecord
  has_secure_password
end

user = User.create!(email: "david@hey.com", password: "secret", password_confirmation: "secret")
user.authenticate("secret") # => user
user.authenticate("wrong")  # => false
```

### Encrypted Attributes (Rails 7+)

Encrypt sensitive data at the application layer:

```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
  encrypts :ssn
end
```

Deterministic encryption allows querying (`User.find_by(email: "...")`).
Non-deterministic is more secure but not queryable.

### Active Storage

File attachments as model-level declarations:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  has_many_attached :documents
end
```

### Action Text

Rich text content as a model-level declaration:

```ruby
class Article < ApplicationRecord
  has_rich_text :body
end
```

### Turbo Broadcasts

Narrative order (redirect → frames → streams), ERB/stream templates, and Stimulus: **`../../writing-hotwire/references/patterns.md`**. This section documents **model-side** broadcast APIs.

**Preferred — broadcast page refreshes with morphing:**

```ruby
class Message < ApplicationRecord
  broadcasts_refreshes_to :room
end
```

This broadcasts a `<turbo-stream action="refresh">` when the record
changes. Combined with morphing, Turbo diffs the current page against a
fresh server render and surgically updates only the changed DOM elements —
no partials to manage, no target IDs to wire up, scroll position preserved.

Requires two meta tags in your layout `<head>`:

```erb
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

And a `turbo_stream_from` subscription in the view:

```erb
<%= turbo_stream_from @room %>
```

For models that broadcast to themselves (not an association):

```ruby
class Calendar < ApplicationRecord
  broadcasts_refreshes
end
```

**Granular streams — when you need per-element control:**

Use `broadcasts_to` or manual callbacks when morphing is too broad (e.g.
appending to a specific list without re-rendering the whole page):

```ruby
class Message < ApplicationRecord
  broadcasts_to :room
end
```

```ruby
after_create_commit -> { broadcast_append_later_to(room, :messages, target: "messages") }
after_destroy_commit -> { broadcast_remove_to(room, :messages) }
```

The `_later` variants (e.g. `broadcast_append_later_to`) use ActiveJob and
are recommended inside callbacks to avoid slow broadcasts blocking the
response.

---

## POROs (Plain Old Ruby Objects)

Namespace POROs under their parent model. Use them for presentation,
calculation, or coordination — not as service objects.

```ruby
# app/models/article/summary.rb
class Article::Summary
  def initialize(article)
    @article = article
  end

  def to_s
    "#{@article.title} by #{@article.author.name} (#{@article.comments.size} comments)"
  end
end

# app/models/user/filtering.rb
class User::Filtering
  def initialize(params)
    @params = params
  end

  def apply(scope)
    scope = scope.by_role(@params[:role]) if @params[:role]
    scope = scope.search(@params[:q]) if @params[:q]
    scope
  end
end
```

---

## Error Handling

### Let It Crash

Use bang AR methods internally. `ActiveRecord::RecordInvalid` propagates
to the controller, where it becomes a 422 response. Domain verbs use the
non-bang form — they are the normal way to perform the action:

```ruby
def publish(by: Current.user)
  create_publication!(publisher: by)
end
```

Reserve a bang domain verb (`publish!`) only when you offer both a "try"
form (returns false on failure) and a "must succeed" form (raises).

### Domain Exceptions

For business rule violations, define exceptions namespaced to the model:

```ruby
class Article < ApplicationRecord
  class AlreadyPublished < StandardError; end

  def publish(by: Current.user)
    raise AlreadyPublished if published?
    create_publication!(publisher: by)
  end
end
```

---

## Transactions

Wrap multi-step operations in transactions. Keep them short.

**Preferred — `after_commit` callback for side effects:**

```ruby
def close(by: Current.user)
  transaction do
    create_closure!(creator: by)
    record_event(:closed)
  end
end

after_commit :notify_watchers_later, on: :update
```

`after_commit` is the safest option — it only fires after the database
transaction is fully committed. Code after a `transaction` block but before
the method returns still runs in the same request and can fail, leaving the
job enqueued for a "failed" request.

**Per-transaction callbacks (Rails 7.2+) — inline side effects tied to a
specific transaction, not a model lifecycle:**

```ruby
def close(by: Current.user)
  transaction do |txn|
    create_closure!(creator: by)
    record_event(:closed)

    txn.after_commit do
      NotifyWatchersJob.perform_later(self)
    end
  end
end
```

This is useful when the side effect depends on method arguments or local
context that a model-level `after_commit` callback can't access.

**`ActiveRecord.after_all_transactions_commit`** — fires after the
outermost transaction commits, safe to call inside or outside a
transaction. Mailer API and delivery: **`../../writing-mailers/references/patterns.md`**.

```ruby
def publish(by: Current.user)
  create_publication!(publisher: by)

  ActiveRecord.after_all_transactions_commit do
    PublishNotificationMailer.with(article: self).deliver_later
  end
end
```
