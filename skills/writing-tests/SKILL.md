---
name: writing-tests
description: >-
  Write Rails tests following DHH/37signals testing philosophy, adapted for
  RSpec and FactoryBot — system specs as the backbone, real objects over mocks,
  behaviour-driven testing over implementation testing. Use
  when writing specs, adding test coverage, debugging test failures, creating
  factories, or when the user mentions tests, specs, RSpec, FactoryBot,
  Capybara, system tests, request specs, or test coverage.
---

# Writing Rails Tests

<objective>
Write tests that give you confidence to ship. System specs are the backbone —
they simulate real users clicking real buttons. Model specs cover domain logic.
Request specs cover the HTTP layer. Everything uses real objects, real database
records, and real rendering. The testing *philosophy* — system tests as
backbone, behaviour over implementation, integration over isolation — comes
from DHH and 37signals. The tooling (RSpec, FactoryBot) is an adaptation;
37signals uses Minitest with fixtures. The principles are the same.
</objective>

## Process

### 1. Determine What You're Testing

| Task | Action |
|------|--------|
| New feature end-to-end | Read `references/system-specs.md`, write a system spec |
| Model domain logic | Read `references/model-specs.md`, write a model spec |
| HTTP behaviour | Read `references/request-specs.md`, write a request spec |
| Creating test data | Read `references/factory-patterns.md`, create factories |
| Authorization / policy | Read `references/support-specs.md` § Policy Specs, write a policy spec |
| Job / mailer / concern | Read `references/support-specs.md`, write the appropriate spec |
| Debugging a failing test | Read all relevant references, diagnose the failure |
| Adding coverage to existing code | Determine the right spec type, read the reference |

### 2. Choosing the Right Spec Type

```
Is this a user-facing feature?
├── YES → System spec (Capybara, real browser)
│         User creates an article, user closes a card
└── NO
    Is this about HTTP behaviour (status codes, redirects, auth)?
    ├── YES → Request spec
    │         401/redirect after login, CSRF protection
    └── NO
        Is this authorization logic (who can do what)?
        ├── YES → Policy spec
        │         admin can delete, owner can edit, scope filters
        └── NO
            Is this domain logic on a model?
            ├── YES → Model spec
            │         article.publish, scope queries, state transitions
            └── NO
                Is this a job, mailer, or standalone object?
                ├── YES → Spec matching the object type
                │         Job enqueues, mailer sends, PORO processes
                └── NO
                    Add the assertion to an existing system spec.
```

### 3. Test Structure

Every test follows this pattern:

```ruby
RSpec.describe Article, type: :model do
  describe "#publish" do
    context "when the article is a draft" do
      it "creates a publication record" do
        # Arrange — set up the world
        article = create(:article)

        # Act — do the thing
        article.publish

        # Assert — verify the outcome
        expect(article).to be_published
        expect(article.publication).to be_present
      end
    end

    context "when already published" do
      it "raises AlreadyPublished" do
        article = create(:article, :published)

        expect { article.publish }.to raise_error(Article::AlreadyPublished)
      end
    end
  end
end
```

Key principles:
- **Arrange-Act-Assert** — every test has three clear phases
- **Inline setup** — each test tells its own story; avoid deep `let` chains. A single `let` for the authenticated user is fine; five nested `let`s are not.
- **One behaviour per test** — multiple assertions are fine if they verify one behaviour
- **Descriptive names** — `describe "#method"`, `context "when X"`, `it "does Y"`
- **Real objects** — `create(:article)`, not `double` or `instance_double`

### 4. Decision Framework

Before writing a test, ask:

**"Am I testing behaviour or implementation?"**
- Behaviour: "when I publish an article, it becomes visible" — good
- Implementation: "publish calls create_publication! then update!" — bad
- If a refactor that preserves behaviour breaks the test, the test is wrong

**"Do I need a mock here?"**
- Almost never. Use real objects and real database records.
- Mock external HTTP APIs (use WebMock or VCR)
- Mock the clock when testing time-dependent behaviour (`travel_to`)
- Never mock ActiveRecord, never mock the object under test

**"Is this test pulling its weight?"**
- Does it catch real bugs? Keep it.
- Does it only break during refactors? Delete it.
- Does it test Rails itself (validates presence works)? Delete it.
- Does it document a non-obvious business rule? Keep it.

**"Is this already tested elsewhere?"**
- Before writing a test, check if the behaviour is already covered in another
  spec type. Each behaviour has exactly one home:
  - Domain logic (publish, close, scopes) → model spec owns it
  - User-visible flow (fill form, click, see result) → system spec owns it
  - HTTP concerns (status codes, redirects) → request spec owns it
  - Authorization logic (who can do what) → policy spec owns the logic
  - Auth gates at the HTTP layer → request spec **always** owns this, even if a system spec exists. Test one authorized + one unauthorized case per endpoint.
  - Job/mailer work → job/mailer spec owns it; callers just assert enqueuing
- If a system spec proves the user can create an article, don't write a request
  spec that posts the same params and checks the record exists. The request spec
  should only exist for HTTP-layer concerns the system spec can't cover.
- If a model spec proves `article.publish` works, the system spec just clicks
  "Publish" and checks the page — it doesn't also inspect `article.publication`.

**"Am I splitting tests unnecessarily within this file?"**
- Multiple assertions about the same action belong in one test, not separate tests.
- Split tests when the *setup* differs (different `context`), not when you want to
  assert another facet of the same outcome.
- If two tests have identical setup and identical action but different `expect` lines,
  merge them into one test.

**"Where does this test live?"**
- Tests live in `spec/` mirroring `app/` structure
- System specs live in `spec/system/` organized by feature
- Factories live in `spec/factories/` one file per model

### 5. No Duplication — Across Layers or Within Files

Every behaviour is tested in exactly one place. Duplication across spec types
slows the suite, obscures what each layer proves, and creates maintenance drag
when behaviour changes. Duplication within a file inflates test counts without
adding confidence.

#### Across Spec Types

Each spec type has a job. Test the behaviour where it naturally lives, and
trust the lower layer from above:

```
┌─────────────┐  Owns: user-visible flows, page content, form interactions
│ System spec │  Trusts: model logic, policies, HTTP layer
├─────────────┤  Owns: status codes, redirects, rate limits
│ Request spec│  Owns: auth gates — ALWAYS test auth here, even if system specs exist
│             │  Trusts: policy logic (tested in policy spec), model logic (tested in model spec)
│             │  Does NOT duplicate: system spec flows or policy logic
├─────────────┤  Owns: authorization logic — who can do what, scoped collections
│ Policy spec │  Is trusted by: request and system specs
│             │  Does NOT test: HTTP responses or UI
├─────────────┤  Owns: domain verbs, scopes, state transitions, business rules
│ Model spec  │  Is trusted by: system, request, and policy specs
│             │  Does NOT test: HTTP, UI, or authorization concerns
├─────────────┤  Owns: the work the job/mailer performs
│ Support spec│  Callers assert enqueuing only (have_enqueued_job / have_enqueued_mail)
└─────────────┘
```

**Concrete example — article publishing:**

```ruby
# Model spec — owns the domain logic
describe "#publish" do
  it "creates a publication and records the publisher" do
    article = create(:article)
    article.publish
    expect(article).to be_published
    expect(article.publication.publisher).to eq(Current.user)
  end
end

# System spec — owns the user flow, trusts the model
it "user publishes an article" do
  visit article_path(article)
  click_button "Publish"
  expect(page).to have_content("Published")  # visible outcome only
  # Does NOT check article.publication.present? — model spec covers that
end

# Request spec — ONLY if there's an HTTP concern system spec can't cover
# e.g., specific status code, rate limiting, auth gate
# Do NOT write a request spec that just posts and checks the record exists
# when the system spec already covers the flow.
```

#### Within a Single Spec File

Don't split assertions about the same action into separate tests:

```ruby
# Bad — three tests for one action, identical setup
it "publishes the article" do
  article.publish
  expect(article).to be_published
end

it "creates a publication record" do
  article.publish
  expect(article.publication).to be_present
end

it "records the publisher" do
  article.publish
  expect(article.publication.publisher).to eq(Current.user)
end

# Good — one test verifying one behaviour from multiple angles
it "publishes the article with attribution" do
  article = create(:article)
  article.publish

  expect(article).to be_published
  expect(article.publication).to be_present
  expect(article.publication.publisher).to eq(Current.user)
end
```

Split into separate `it` blocks only when the **context differs** — different
preconditions, different user roles, different input. The signal for a new test
is a new `context`, not a new `expect`.

```ruby
# Good — different contexts warrant separate tests
context "when the article is a draft" do
  it "publishes successfully" do
    article = create(:article)
    article.publish
    expect(article).to be_published
  end
end

context "when already published" do
  it "raises AlreadyPublished" do
    article = create(:article, :published)
    expect { article.publish }.to raise_error(Article::AlreadyPublished)
  end
end
```

### 6. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Mocking ActiveRecord models | Use FactoryBot — create real records |
| `allow_any_instance_of` | Test through the real code path |
| Testing private methods directly | Test through public interface |
| `before(:all)` for database records | `before(:each)` or inline `create` |
| Deep `let` / `subject` chains that obscure setup | Inline setup in each test; a single `let` for auth user is fine |
| Shared examples across unrelated specs | Inline the assertion — clarity over DRY |
| Testing validates/belongs_to declarations | Test domain behaviour, not framework |
| Controller specs | Request specs — controller specs are deprecated |
| `stub_const` for ENV vars | Use Rails credentials or test config |
| Asserting exact error messages | Assert error keys or behaviour |
| Giant setup blocks | Extract to factory traits |
| `is_expected.to` with implicit subject | Explicit subject and expectation |
| Request spec that duplicates a system spec flow | Request spec only for HTTP-layer concerns (status, redirects, auth) |
| System spec inspecting model internals (`article.publication`) | System spec asserts what the user sees on the page |
| Model spec + request spec + system spec for the same happy path | One home per behaviour — pick the right layer |
| Separate `it` blocks for each assertion on one action | One `it` with multiple `expect`s when setup and action are identical |
| Re-testing domain verb logic in a request spec | Request spec calls the endpoint; model spec owns the verb logic |
| Job spec re-testing what the model spec covers | Job spec tests orchestration; model spec tests the domain method the job calls |

### 7. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Spec files | `_spec.rb` suffix matching source | `article_spec.rb`, `articles_spec.rb` |
| Top-level describe | Class or feature name | `RSpec.describe Article`, `RSpec.describe "Article management"` |
| Method describes | `#instance_method`, `.class_method` | `describe "#publish"`, `describe ".search"` |
| Contexts | Start with "when" or "with" | `context "when published"`, `context "with comments"` |
| Examples | Read as sentences | `it "creates a publication record"` |
| Factories | Singular model name | `factory :article`, `factory :user` |
| Traits | Adjective or state | `:published`, `:archived`, `:with_comments` |
| System specs | User action or flow | `"User publishes an article"`, `"Admin manages users"` |

### 8. Verification

Before finishing, verify:

- [ ] Tests cover the happy path and key error paths
- [ ] No mocks of ActiveRecord or internal objects
- [ ] Each test is self-contained — can run in isolation
- [ ] Factory uses minimal required attributes
- [ ] System specs test real user flows, not implementation details
- [ ] Request specs verify status codes and redirects
- [ ] Model specs cover domain verbs, scopes, and state transitions
- [ ] Tests read as documentation — a new developer understands the feature from reading them
- [ ] No flaky tests — no sleep, no order-dependent state
- [ ] Database is cleaned between tests (transactional fixtures or database_cleaner)
- [ ] No cross-layer duplication — each behaviour is tested in exactly one spec type
- [ ] System specs don't inspect model internals — they assert what users see
- [ ] Request specs don't duplicate system spec flows — they cover HTTP-only concerns
- [ ] Model specs don't re-test in request/system specs — integration specs trust the unit
- [ ] No redundant `it` blocks — tests with identical setup/action are merged into one
- [ ] Job/mailer callers assert enqueuing only — the job/mailer spec owns the work

## References

For detailed patterns and examples by spec type:

- [Model specs](references/model-specs.md) — domain logic, scopes, concerns, validations
- [Request specs](references/request-specs.md) — HTTP layer, auth, redirects
- [System specs](references/system-specs.md) — user flows, Capybara, browser testing
- [Factory patterns](references/factory-patterns.md) — FactoryBot conventions, traits, sequences
- [Support specs](references/support-specs.md) — jobs, mailers, concerns, POROs
