# Model Specs Reference

Model specs are unit tests for domain logic. They test methods, scopes,
state transitions, and business rules on the model — using real database
records, not mocks.

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
      article = create(:article)

      article.publish

      expect(article).to be_published
      expect(article.publication).to be_present
      expect(article.publication.publisher).to eq(Current.user)
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
  it "creates a closure record" do
    card = create(:card)

    card.close

    expect(card).to be_closed
    expect(card.closure.creator).to eq(Current.user)
  end

  it "accepts a custom closer" do
    card = create(:card)
    admin = create(:user, :admin)

    card.close(by: admin)

    expect(card.closure.creator).to eq(admin)
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

    article.publish
    expect(article).to be_published

    article.unpublish
    expect(article).not_to be_published
  end
end
```

### Testing Concerns

Test concerns through a real model that includes them, not through a
test double or anonymous class.

```ruby
# spec/models/concerns/publishable_spec.rb
RSpec.describe Publishable do
  # Test through Article, which includes Publishable
  describe "#publish" do
    it "creates a publication record" do
      article = create(:article)

      article.publish

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
    expect(duplicate.errors[:email]).to include("has already been taken")
  end
end

# Good — custom validation with business logic
describe "publishing requirements" do
  it "requires a body to publish" do
    article = create(:article, body: nil)

    expect { article.publish }.to raise_error(ActiveRecord::RecordInvalid)
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

```ruby
describe "#publish" do
  it "records the current user as publisher" do
    user = create(:user)
    Current.user = user
    article = create(:article)

    article.publish

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

### What Model Specs Own

- Domain verbs: `publish`, `close`, `archive` — the method does the right thing
- Scopes: `.published`, `.chronologically` — the query returns the right records
- State transitions: draft → published → unpublished lifecycle
- Business rules: "can't publish without a body", "can't close twice"
- Callbacks: derived data computed, jobs enqueued
- Normalizations: email stripped and downcased

### What Model Specs Do NOT Test

- That the user can fill in a form and see the result — system spec
- That `POST /articles` returns 201 — request spec
- That the HTML renders correctly — system spec
- That the mailer body contains the right text — mailer spec
- That the job processes correctly — job spec (model spec just asserts `have_enqueued_job`)

### No Redundant Tests Within the File

Group assertions about the same action into one test:

```ruby
# Bad — same setup, same action, split across tests
it "creates a publication" do
  article.publish
  expect(article.publication).to be_present
end

it "sets the publisher" do
  article.publish
  expect(article.publication.publisher).to eq(Current.user)
end

# Good — one action, one test, multiple assertions
it "publishes with attribution" do
  article = create(:article)
  article.publish

  expect(article).to be_published
  expect(article.publication).to be_present
  expect(article.publication.publisher).to eq(Current.user)
end
```

Split into separate tests only when the `context` differs — different
preconditions or different inputs, not different assertions on the same
outcome.
