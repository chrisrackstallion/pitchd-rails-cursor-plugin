# Model Specs Reference

Model specs are unit tests for domain logic — and they are the **largest
layer** of the suite. They test methods, scopes, state transitions,
callbacks, normalizations, and business rules on the model using real
database records, not mocks. Most application behaviour belongs here:
every domain verb, every scope, every state transition, every derived
attribute. When system specs trust "the model works," they are trusting
this layer.

## When to Write One

Write a model spec when the model has *behaviour* worth testing in
isolation:

- Domain verbs (`publish`, `close`, `archive`, `cancel`)
- Scopes that filter or order records
- State transitions and lifecycle rules
- Business-rule validations (uniqueness with case-insensitivity, "can't
  publish without a body")
- Callbacks: derived data, normalizations, enqueued jobs
- Counter caches and dependent destroy behaviour
- Polymorphic or unusual association behaviour

## When NOT to Write One

A model with no domain logic — pure ActiveRecord with associations,
schema-level validations, and no custom methods — does not need a spec
just because the file exists. Specifically, skip:

- `validates :title, presence: true` — Rails already tests `validates`
- `belongs_to :author` — Rails already tests the macro
- `has_many :comments, dependent: :destroy` — Rails already tests it;
  only write a spec if the destroy chain has unusual semantics
- Enum declarations — Rails already tests enums

If the only thing you can think to test is "the model has these
attributes," delete the spec. The schema is the source of truth.

## Factories: `create` by Default

As a controlled exception, you may use `build_stubbed` when the method under
test is purely in-memory — no DB queries, no scopes, no callbacks requiring
persistence. `build_stubbed` returns a stubbed object, not a real record; it
stubs `id`, `persisted?`, `save`, and all association persistence methods.
If the method ever grows to touch the database, the test will fail loudly —
that's the point. Use `create` for everything else. When in doubt, use `create`.

## Structure

```ruby
# spec/models/article_spec.rb
RSpec.describe Article, type: :model do
  describe "#publish" do
    it "creates a publication record" do
      publisher = create(:user)
      article = create(:article)

      article.publish(by: publisher)

      expect(article).to be_published
      expect(article.publication).to be_present
      expect(article.publication.publisher).to eq(publisher)
    end

    it "raises when already published" do
      article = create(:article, :published)

      expect { article.publish }.to raise_error(Article::AlreadyPublished)
    end
  end

  describe "#unpublish" do
    it "destroys the publication record" do
      article = create(:article, :published)

      article.unpublish

      expect(article).not_to be_published
      expect(article.reload.publication).to be_nil
    end
  end
end
```

---

## Domain Verbs

Test every public domain verb on the model. These are the core of your
model specs — they verify business behaviour.

### Pattern

```ruby
describe "#close" do
  it "creates a closure record attributed to the closer" do
    card = create(:card)
    closer = create(:user)

    card.close(by: closer)

    expect(card).to be_closed
    expect(card.closure.creator).to eq(closer)
  end

  it "defaults the closer to Current.user" do
    card = create(:card)
    user = create(:user)

    as_user(user) { card.close }

    expect(card.closure.creator).to eq(user)
  end
end

describe "#reopen" do
  it "destroys the closure" do
    card = create(:card, :closed)

    card.reopen

    expect(card).to be_open
  end

  it "is a no-op when already open" do
    card = create(:card)

    expect { card.reopen }.not_to raise_error
  end
end
```

### What to Assert

- The state changed (predicate method returns expected value)
- Associated records were created/destroyed
- Timestamps were set
- Jobs were enqueued (use `have_enqueued_job`)
- Exceptions are raised for invalid state transitions

---

## Scopes

Test scopes by creating records in different states and asserting which
ones the scope returns.

### Pattern

```ruby
describe ".published" do
  it "returns only published articles" do
    published = create(:article, :published)
    draft = create(:article)

    expect(Article.published).to contain_exactly(published)
  end
end

describe ".chronologically" do
  it "orders by created_at ascending" do
    old = create(:article, created_at: 2.days.ago)
    new = create(:article, created_at: 1.day.ago)

    expect(Article.chronologically).to eq([old, new])
  end
end

describe ".search" do
  it "matches articles by title" do
    matching = create(:article, title: "Rails Testing Guide")
    other = create(:article, title: "Unrelated Topic")

    results = Article.search("testing")

    expect(results).to contain_exactly(matching)
  end

  it "is case-insensitive" do
    article = create(:article, title: "Rails Testing")

    expect(Article.search("rails testing")).to include(article)
  end
end
```

### Matcher Selection

| Scenario | Matcher |
|----------|---------|
| Exact set, any order | `contain_exactly(a, b, c)` |
| Ordered results | `eq([a, b, c])` |
| Includes specific records | `include(a, b)` |
| Excludes specific records | `not_to include(a)` |
| Empty result | `be_empty` |
| Count | `have_attributes(count: 3)` |

---

## State Transitions

When models use state-as-records (Publishable, Closeable, etc.), test
the full lifecycle.

### Pattern

```ruby
describe "publishing lifecycle" do
  it "transitions from draft to published to unpublished" do
    article = create(:article)

    expect(article).not_to be_published

    article.publish(by: article.author)
    expect(article).to be_published

    article.unpublish
    expect(article).not_to be_published
  end
end
```

### Testing Concerns

Concern behaviour does not live in model specs. Every concern with behaviour
gets its own spec file at `spec/models/concerns/<concern>_spec.rb`, tested
through a real model that includes it — not a test double or anonymous class.
A model spec touches a concern method only when the model **overrides or
extends** it, and then tests only the delta.

```ruby
# spec/models/concerns/publishable_spec.rb
RSpec.describe Publishable do
  # Test through Article, which includes Publishable
  describe "#publish" do
    it "creates a publication record" do
      article = create(:article)

      article.publish(by: article.author)

      expect(article.publication).to be_present
    end
  end

  describe ".published scope" do
    it "returns models with publications" do
      published = create(:article, :published)
      draft = create(:article)

      expect(Article.published).to contain_exactly(published)
    end
  end
end
```

---

## Validations

Only test validations that encode business rules. Don't test that
`validates :title, presence: true` works — Rails already tests that.

### What to Test

```ruby
# Good — business rule validation
describe "email uniqueness" do
  it "prevents duplicate emails (case-insensitive)" do
    create(:user, email: "alice@example.com")
    duplicate = build(:user, email: "Alice@Example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors).to be_of_kind(:email, :taken)  # error key, not copy
  end
end

# Good — custom validation with business logic
describe "publishing requirements" do
  it "requires a body to publish" do
    article = create(:article, body: nil)

    # Actor passed explicitly so the failure can only come from the body rule
    expect { article.publish(by: article.author) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
```

### What NOT to Test

```ruby
# Bad — testing Rails, not your code
it "validates presence of title" do
  article = build(:article, title: nil)
  expect(article).not_to be_valid
end

# Bad — testing the association declaration
it "belongs to an author" do
  expect(Article.reflect_on_association(:author)).to be_present
end
```

---

## Callbacks and Side Effects

Test callbacks through their observable effects, not by asserting the
callback is registered.

### Async Jobs

```ruby
describe "after creating an article" do
  it "enqueues a notification job" do
    expect {
      create(:article)
    }.to have_enqueued_job(NotifySubscribersJob)
  end
end
```

### Derived Data

```ruby
describe "slug generation" do
  it "generates a slug from the title on save" do
    article = create(:article, title: "My Great Article")

    expect(article.slug).to eq("my-great-article")
  end

  it "updates the slug when the title changes" do
    article = create(:article, title: "Original")
    article.update!(title: "Updated Title")

    expect(article.slug).to eq("updated-title")
  end
end
```

### Normalizations

```ruby
describe "email normalization" do
  it "strips whitespace and downcases" do
    user = create(:user, email: "  Alice@Example.COM  ")

    expect(user.email).to eq("alice@example.com")
  end
end
```

---

## Associations

Test association behaviour when it affects domain logic, not the
declaration itself.

### Counter Caches

```ruby
describe "comments_count" do
  it "increments when a comment is added" do
    article = create(:article)

    create(:comment, article: article)

    expect(article.reload.comments_count).to eq(1)
  end
end
```

### Dependent Destroy

```ruby
describe "destroying an article" do
  it "destroys associated comments" do
    article = create(:article)
    create_list(:comment, 3, article: article)

    article.destroy!

    expect(Comment.where(article_id: article.id)).to be_empty
  end
end
```

---

## Time-Dependent Tests

Use `travel_to` for tests that depend on the current time.

```ruby
describe ".created_after" do
  it "returns articles created after the given date" do
    travel_to Date.new(2024, 6, 1) do
      old = create(:article, created_at: Date.new(2024, 1, 1))
      recent = create(:article, created_at: Date.new(2024, 5, 15))

      results = Article.created_after(Date.new(2024, 3, 1))

      expect(results).to contain_exactly(recent)
    end
  end
end

describe "#stale?" do
  it "returns true when not updated in 30 days" do
    article = create(:article, updated_at: 31.days.ago)

    expect(article).to be_stale
  end
end
```

---

## Testing with Current Attributes

Set `Current` attributes in tests when model behaviour depends on them.
Prefer the block form (`Current.set(...) { }`) — it restores the previous
values when the block exits, so nothing leaks into the next example:

```ruby
describe "#publish" do
  it "records the current user as publisher" do
    user = create(:user)
    article = create(:article)

    Current.set(user: user) { article.publish }

    expect(article.publication.publisher).to eq(user)
  end
end
```

Or use a helper:

```ruby
# spec/support/current_user.rb
module CurrentUserHelper
  def as_user(user, &block)
    Current.set(user: user, &block)
  end
end

RSpec.configure do |config|
  config.include CurrentUserHelper
end
```

**Match your app's `Current` shape.** `Current.set(user: ...)` works when
`Current` declares `attribute :user`. With the Rails 8 authentication
generator, `Current` declares `attribute :session` and derives `user` from
it — setting `user` directly raises. Set the session instead:

```ruby
def as_user(user, &block)
  Current.set(session: user.sessions.create!, &block)
end
```

```ruby
it "records the publisher" do
  user = create(:user)
  article = create(:article)

  as_user(user) { article.publish }

  expect(article.publication.publisher).to eq(user)
end
```

---

## Form Objects and POROs

Test form objects and POROs the same way as models — create real records,
call methods, assert outcomes.

### Form Object

```ruby
# spec/models/registration_spec.rb
RSpec.describe Registration do
  describe "#save" do
    it "creates a user and account" do
      registration = Registration.new(
        name: "Alice",
        email: "alice@example.com",
        password: "secret123",
        company_name: "Acme"
      )

      expect(registration.save).to be true
      expect(registration.user).to be_persisted
      expect(registration.account.name).to eq("Acme")
    end

    it "returns false with invalid data" do
      registration = Registration.new(name: "", email: "")

      expect(registration.save).to be false
      expect(registration.errors[:name]).to be_present
    end
  end
end
```

### PORO

```ruby
# spec/models/account/onboarding_spec.rb
RSpec.describe Account::Onboarding do
  describe "#complete" do
    it "sets up the account with defaults" do
      account = create(:account)
      onboarding = Account::Onboarding.new(account)

      onboarding.complete(name: "Acme Corp", plan: :pro)

      expect(account.reload.name).to eq("Acme Corp")
      expect(account.memberships.count).to eq(1)
      expect(account.projects.count).to eq(1)
    end
  end
end
```

---

## Boundaries — What Belongs Here vs. Elsewhere

Model specs own domain logic. Other spec types trust that it works.
Because system specs are tightly budgeted and request specs trust the
domain layer, **most behavioural coverage lives here**. If a behaviour
can be expressed as "given this state, calling this method produces
this outcome," it belongs in a model spec.

### What Model Specs Own

- Domain verbs: `publish`, `close`, `archive`, `cancel` — every public method that changes state or returns derived data
- Scopes: `.published`, `.chronologically`, `.search` — the query returns the right records
- State transitions: draft → published → unpublished lifecycle and the invariants between them
- Business rules: "can't publish without a body", "can't close twice", uniqueness with case-insensitivity
- Callbacks: derived data computed, jobs enqueued (assertion: `have_enqueued_job` — not what the job does)
- Normalizations: email stripped and downcased, slug generated
- Counter caches and dependent-destroy chains when they are part of the domain contract
- Time-dependent methods using `travel_to`
- `Current`-dependent behaviour using `Current.set` / `as_user`

### What Model Specs Do NOT Test

- Framework declarations: `validates :title, presence: true`, `belongs_to :author`, `has_many :comments` — Rails owns these
- That the user can fill in a form and see the result — system spec
- That `POST /articles` returns 201 or that `response.body` includes the title — request spec
- That the HTML renders correctly — system spec (canonical journey) or request spec (rendering smoke)
- That the mailer body contains the right text — mailer spec
- That the job processes correctly — job spec (model spec asserts `have_enqueued_job` and nothing more)
- Authorization rules: who can call `publish` — policy spec owns the matrix
- Pure helper formatting that doesn't live on the model — helper spec

### No Redundant Tests Within the File

Group assertions about the same action into one test:

```ruby
# Bad — same setup, same action, split across tests
it "creates a publication" do
  article.publish(by: publisher)
  expect(article.publication).to be_present
end

it "sets the publisher" do
  article.publish(by: publisher)
  expect(article.publication.publisher).to eq(publisher)
end

# Good — one action, one test, multiple assertions
it "publishes with attribution" do
  publisher = create(:user)
  article = create(:article)
  article.publish(by: publisher)

  expect(article).to be_published
  expect(article.publication).to be_present
  expect(article.publication.publisher).to eq(publisher)
end
```

Split into separate tests only when the `context` differs — different
preconditions or different inputs, not different assertions on the same
outcome.
