# Factory Patterns Reference

FactoryBot factories are the foundation of test data. Keep them minimal,
use traits for states, and override in the test when the value matters.

## Basic Factory

```ruby
# spec/factories/articles.rb
FactoryBot.define do
  factory :article do
    title { "Sample Article" }
    body { "This is the article body." }
    association :author, factory: :user

    trait :published do
      after(:create) { |article| article.publish }
    end

    trait :archived do
      after(:create) { |article| article.archive }
    end

    trait :with_comments do
      transient do
        comments_count { 3 }
      end

      after(:create) do |article, evaluator|
        create_list(:comment, evaluator.comments_count, article: article)
      end
    end
  end
end
```

---

## Minimal Factories

Only define attributes that are required to create a valid record. Let
the database defaults and model callbacks handle the rest.

```ruby
# Good — minimal
factory :user do
  sequence(:email_address) { |n| "user#{n}@example.com" }
  password { "password" }
  name { "Test User" }
end

# Bad — over-specified
factory :user do
  sequence(:email_address) { |n| "user#{n}@example.com" }
  password { "password" }
  name { "Test User" }
  role { :member }           # if this is the default, don't set it
  confirmed_at { Time.current } # if not required for valid record
  locale { "en" }            # if this is the default
  timezone { "UTC" }         # if this is the default
end
```

### Why Minimal?

- Tests that override attributes are self-documenting: the override tells
  you what matters
- Defaults that match the database defaults reduce surprise
- Adding a required column only needs one factory change, not every test

---

## Sequences

Use sequences for attributes that must be unique.

```ruby
factory :user do
  sequence(:email_address) { |n| "user#{n}@example.com" }
  sequence(:name) { |n| "User #{n}" }
end

factory :article do
  sequence(:title) { |n| "Article #{n}" }
  sequence(:slug) { |n| "article-#{n}" }
end
```

### When to Use

- Columns with uniqueness constraints (email, slug, external_id)
- Attributes that appear in test output where distinct values aid debugging

### When Not to Use

- Non-unique attributes — use a static value: `name { "Test User" }`
- Attributes you always override in tests anyway

---

## Traits

Traits represent meaningful states or variations. Name them as adjectives
or descriptive phrases.

### State Traits

```ruby
factory :article do
  trait :published do
    after(:create) { |article| article.publish }
  end

  trait :archived do
    after(:create) { |article| article.archive }
  end

  trait :closed do
    after(:create) { |article| article.close }
  end
end
```

Use `after(:create)` when the trait calls a domain verb that requires
a persisted record. The factory creates the record first, then applies
the state transition.

### Role Traits

```ruby
factory :user do
  trait :admin do
    role { :admin }
  end

  trait :moderator do
    role { :moderator }
  end
end
```

### Association Traits

```ruby
factory :article do
  trait :with_comments do
    transient do
      comments_count { 3 }
    end

    after(:create) do |article, evaluator|
      create_list(:comment, evaluator.comments_count, article: article)
    end
  end

  trait :with_tags do
    after(:create) do |article|
      create_list(:tag, 2, articles: [article])
    end
  end
end
```

### Composing Traits

Traits compose freely:

```ruby
create(:article, :published, :with_comments)
create(:article, :published, :with_comments, comments_count: 5)
create(:user, :admin)
```

---

## Associations

### Default Association

```ruby
factory :comment do
  body { "Great article!" }
  association :article
  association :author, factory: :user
end
```

### Sharing Parent Records

When multiple records should share the same parent:

```ruby
# In the test
article = create(:article)
create_list(:comment, 3, article: article)
```

Don't use `after(:create)` on the parent factory to auto-create children
unless it's a trait explicitly requesting it.

### Polymorphic Associations

```ruby
factory :publication do
  association :publishable, factory: :article
  association :publisher, factory: :user
end

factory :closure do
  association :closeable, factory: :card
  association :creator, factory: :user
end
```

---

## Transient Attributes

Use transient attributes to parameterize factory behaviour without
setting model attributes.

```ruby
factory :article do
  transient do
    comments_count { 0 }
    published { false }
  end

  after(:create) do |article, evaluator|
    if evaluator.comments_count > 0
      create_list(:comment, evaluator.comments_count, article: article)
    end

    article.publish if evaluator.published
  end
end

# Usage
create(:article, comments_count: 5, published: true)
```

Prefer traits over transient booleans when the state has a clear name:

```ruby
# Better — trait is clearer than transient boolean
create(:article, :published, :with_comments, comments_count: 5)
```

---

## create vs build vs build_stubbed

| Method | Database? | Associations? | Use When |
|--------|-----------|---------------|----------|
| `create` | Yes | Persisted | Default — most tests need real records |
| `build` | No | Built | Testing validations or form objects before save |
| `build_stubbed` | No | Stubbed | Rarely — speed gain is marginal, behaviour drift can mask bugs |

### Default to `create`

```ruby
# Good — real record in the database
article = create(:article, :published)
expect(Article.published).to include(article)

# Using build wouldn't work — the scope queries the database
article = build(:article)
article.valid? # This works with build
```

### Use `build` for Validation Tests

```ruby
it "requires a title" do
  article = build(:article, title: "")

  expect(article).not_to be_valid
  expect(article.errors[:title]).to be_present
end
```

---

## create_list

Create multiple records at once:

```ruby
# Creates 3 articles
articles = create_list(:article, 3)

# With traits and overrides
published = create_list(:article, 5, :published)
by_author = create_list(:article, 3, author: user)
```

---

## Overriding in Tests

Override factory defaults when the value matters to the assertion. If
a test creates a user and checks their name, the name should be set in
the test, not inherited from the factory.

```ruby
# Good — the test tells you what matters
it "displays the user's name" do
  user = create(:user, name: "Alice Johnson")

  visit profile_path(user)

  expect(page).to have_content("Alice Johnson")
end

# Bad — relies on factory default, name is invisible
it "displays the user's name" do
  user = create(:user)

  visit profile_path(user)

  expect(page).to have_content("Test User") # Where did "Test User" come from?
end
```

---

## Factory Organization

### One File Per Model

```
spec/factories/
├── articles.rb
├── comments.rb
├── users.rb
├── closures.rb
├── publications.rb
└── tags.rb
```

### Factory File Structure

```ruby
# spec/factories/articles.rb
FactoryBot.define do
  factory :article do
    # 1. Required attributes (sequences first)
    sequence(:title) { |n| "Article #{n}" }
    body { "Article body content." }

    # 2. Associations
    association :author, factory: :user

    # 3. Traits — states
    trait :published do
      after(:create) { |article| article.publish }
    end

    trait :archived do
      after(:create) { |article| article.archive }
    end

    # 4. Traits — with associations
    trait :with_comments do
      transient do
        comments_count { 3 }
      end

      after(:create) do |article, evaluator|
        create_list(:comment, evaluator.comments_count, article: article)
      end
    end
  end
end
```

---

## Common Factory Recipes

### User with Auth

```ruby
factory :user do
  sequence(:email_address) { |n| "user#{n}@example.com" }
  password { "password" }
  name { "Test User" }

  trait :admin do
    role { :admin }
  end
end
```

### Record with State-as-Record

```ruby
factory :card do
  sequence(:title) { |n| "Card #{n}" }
  association :board
  association :creator, factory: :user

  trait :closed do
    after(:create) { |card| card.close }
  end

  trait :archived do
    after(:create) { |card| card.archive }
  end
end
```

### Record with Enum

```ruby
factory :article do
  title { "Sample Article" }
  visibility { :public }

  trait :private do
    visibility { :private }
  end

  trait :unlisted do
    visibility { :unlisted }
  end
end
```

### Record with File Attachment

```ruby
factory :document do
  association :project
  file { Rack::Test::UploadedFile.new("spec/fixtures/files/sample.pdf", "application/pdf") }

  trait :without_file do
    file { nil }
  end
end
```

---

## Guidelines

- **Minimal factories** — only required attributes
- **Traits for states** — `:published`, `:closed`, `:admin`
- **Sequences for unique values** — emails, slugs, external IDs
- **`create` by default** — hit the database
- **Override when it matters** — if the test asserts a value, set it in the test
- **One file per model** — `spec/factories/model_name.rb`
- **No factory inheritance** — use traits instead of child factories
- **Avoid `build_stubbed`** — the speed gain is marginal and the behaviour drift can mask real bugs
- **No shared mutable state** — each test creates its own records
- **Traits compose** — `create(:article, :published, :with_comments)`
