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
Write tests that give you confidence to ship. System specs are the **backbone**
of the suite — a small number of integration tests that prove the seams hold.
They are not the place to chase coverage. Model specs cover domain logic.
Request specs cover the HTTP layer — including rendering smoke for index/show,
CRUD round-tripping, and every auth gate. Policy specs cover authorization
logic. Everything uses real objects, real database records, and real
rendering.

The default answer to "should this be a system spec?" is **no — push it down
a layer.** System specs are slow, brittle to copy changes, and expensive to
maintain; each one must earn its place against the budget and gates in
`references/system-specs.md`.

The testing *philosophy* — system tests as backbone, behaviour over
implementation, integration over isolation — comes from DHH and 37signals.
The tooling (RSpec, FactoryBot) is an adaptation; 37signals uses Minitest
with fixtures. The principles are the same.
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
| Job / concern | Read `references/support-specs.md`, write the appropriate spec |
| Mailer class, templates, previews | Read `../writing-mailers/references/patterns.md`; RSpec examples in `references/support-specs.md` § Mailer Specs |
| I18n / asserting on translated copy | Read `../writing-i18n/references/patterns.md` § Testing |
| Debugging a failing test | Read all relevant references, diagnose the failure |
| Adding coverage to existing code | Determine the right spec type, read the reference |

### 2. Choosing the Right Spec Type

The tree is biased toward the **lowest layer that can prove the behaviour**.
System specs are reserved for genuine integration — push everything else down.

```
Is this domain logic (a method on a model — publish, close, scope, state transition)?
├── YES → Model spec
└── NO
    Is this authorization logic (who can do what across roles)?
    ├── YES → Policy spec
    └── NO
        Is this an HTTP-layer concern (status code, redirect, auth gate, params,
        index/show rendering smoke, CRUD round-trip)?
        ├── YES → Request spec
        └── NO
            Is this the work a job, mailer, or PORO performs?
            ├── YES → Spec matching the object type
            └── NO
                Does this user journey pass ALL FIVE GATES in
                `references/system-specs.md` (interaction, uniqueness,
                JS-necessity, single-home, one-story)?
                ├── YES → System spec — within the budget
                └── NO → Push down a layer; do NOT add a system spec
```

**Read `references/system-specs.md` before adding any system spec.** It defines
the budget (typically 1 per CRUD resource, 1 per cross-resource journey, 1 per
JS behaviour across the entire suite), the five gates, and the patterns that
look like system specs but belong elsewhere.

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
        article.publish(by: article.author)

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
  - HTTP concerns (status codes, redirects, params handling, rendering smoke
    for index/show, CRUD round-tripping) → request spec owns it
  - Authorization logic (who can do what) → policy spec owns the logic
  - Auth gates at the HTTP layer → request spec **always** owns this, even if a system spec exists. Test one authorized + one unauthorized case per endpoint.
  - Canonical user journey end-to-end (form → submit → see result on page) → system spec owns it, but only within the budget in `references/system-specs.md`
  - Job/mailer work → job/mailer spec owns it; callers just assert enqueuing
- If a request spec proves `POST /articles` creates the record and redirects,
  don't add a system spec to prove the same thing unless the journey is the
  canonical happy path for that resource (one per resource — not one per action).
- If a model spec proves `article.publish` works, the system spec just clicks
  "Publish" and checks the page — it doesn't also inspect `article.publication`.

**"Does this system spec pass the Five Gates?"** (Only ask if a system spec is
under consideration — see `references/system-specs.md` for the full text.)
1. **Interaction gate** — the spec calls `fill_in`, `click_*`, `select`, `check`,
   or `attach_file`. A `visit` + assert with no interaction is not a system spec;
   it is a view spec — move to a request spec.
2. **Uniqueness gate** — the journey is materially different from existing system
   specs for this resource or area.
3. **JavaScript-necessity gate** — Selenium is justified, and the Stimulus
   controller / Turbo pattern is not already exercised by another system spec.
4. **Single-home gate** — the assertion is not already owned by a model, request,
   policy, or job/mailer spec.
5. **One-story gate** — the spec tells exactly one user story; no drive-by
   assertions about nav, footer, sidebar, or unrelated widgets.

If any gate fails, do not write the system spec — push the assertion to the
appropriate lower layer.

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
┌─────────────┐  Owns: canonical happy-path journeys (one per resource, within budget)
│ System spec │  Owns: multi-request integration (signup, checkout, password reset)
│ (smallest)  │  Owns: JS-essential behaviour (one spec per Stimulus controller / Turbo pattern)
│             │  Trusts: model logic, policies, HTTP layer, mailer/job content
│             │  Does NOT do: visit-only assertions, per-field testing, CRUD parity
├─────────────┤  Owns: status codes, redirects, params handling, rate limits
│ Request spec│  Owns: auth gates — ALWAYS test auth here, even if system specs exist
│ (workhorse) │  Owns: rendering smoke (response.body.include?) for index/show pages
│             │  Owns: CRUD round-trips for non-canonical actions (show/edit/update/destroy)
│             │  Trusts: policy logic, model logic, mailer/job content
│             │  Does NOT duplicate: the canonical happy-path system spec, policy logic
├─────────────┤  Owns: authorization logic — full role × action matrix, scoped collections
│ Policy spec │  Is trusted by: request and system specs
│             │  Does NOT test: HTTP responses or UI
├─────────────┤  Owns: domain verbs, scopes, state transitions, business rules, callbacks
│ Model spec  │  (largest layer — most behaviour lives here)
│             │  Is trusted by: system, request, and policy specs
│             │  Does NOT test: HTTP, UI, or authorization concerns
├─────────────┤  Owns: the work the job/mailer performs
│ Support spec│  Callers assert enqueuing only (have_enqueued_job / have_enqueued_mail)
└─────────────┘
```

**Concrete example — article publishing:**

```ruby
# Model spec — owns the domain logic (this is where most coverage lives)
describe "#publish" do
  it "creates a publication and records the publisher" do
    publisher = create(:user)
    article = create(:article)
    article.publish(by: publisher)
    expect(article).to be_published
    expect(article.publication.publisher).to eq(publisher)
  end

  it "raises when already published" do
    article = create(:article, :published)
    expect { article.publish }.to raise_error(Article::AlreadyPublished)
  end
end

# Policy spec — owns the role × action matrix
describe ArticlePolicy do
  it "permits the author and forbids others" do
    # ...full matrix here
  end
end

# Request spec — owns auth gates, status codes, and the HTTP shape
describe "POST /articles/:id/publication" do
  it "requires authentication" do
    post article_publication_path(article)
    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthorized users" do
    sign_in create(:user)  # not the author
    post article_publication_path(article)
    expect(response).to redirect_to(root_path)
  end
end

# System spec — owns the ONE canonical happy-path journey (within budget)
it "author publishes an article" do
  sign_in author
  visit article_path(article)
  click_button "Publish"
  expect(page).to have_content("Published")  # visible outcome only
  # Does NOT check article.publication.present? — model spec covers that
  # Does NOT also test "non-author cannot publish" — request/policy specs cover that
end
```

#### Within a Single Spec File

Don't split assertions about the same action into separate tests:

```ruby
# Bad — three tests for one action, identical setup
it "publishes the article" do
  article.publish(by: publisher)
  expect(article).to be_published
end

it "creates a publication record" do
  article.publish(by: publisher)
  expect(article.publication).to be_present
end

it "records the publisher" do
  article.publish(by: publisher)
  expect(article.publication.publisher).to eq(publisher)
end

# Good — one test verifying one behaviour from multiple angles
it "publishes the article with attribution" do
  publisher = create(:user)
  article = create(:article)
  article.publish(by: publisher)

  expect(article).to be_published
  expect(article.publication).to be_present
  expect(article.publication.publisher).to eq(publisher)
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
    article.publish(by: article.author)
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
| System spec inspecting model internals (`article.publication`) | System spec asserts what the user sees on the page |
| Model spec + request spec + system spec for the same happy path | One home per behaviour — pick the right layer |
| Separate `it` blocks for each assertion on one action | One `it` with multiple `expect`s when setup and action are identical |
| Re-testing domain verb logic in a request spec | Request spec calls the endpoint; model spec owns the verb logic |
| Job spec re-testing what the model spec covers | Job spec tests orchestration; model spec tests the domain method the job calls |
| Standalone `not_to` assertions to prove code was removed | Assert the positive behaviour the user sees; `not_to` is a side-effect, not a primary assertion |
| System spec that only `visit`s and asserts content (no interaction) | Move to a request spec asserting `response.body.include?` |
| One system spec per CRUD action when the actions share a shape | One canonical happy-path system spec (usually create); edit/delete go to request specs |
| One system spec per field, attribute, or validation rule | One system spec exercises the form as a whole; per-field belongs to model/request specs |
| Re-testing the same Stimulus controller / Turbo pattern in multiple system specs | One system spec per JS behaviour across the entire suite, on the simplest page |
| Selenium driver for a spec that passes under `rack_test` | Use `rack_test`; Selenium is for genuinely JS-required behaviour only |
| Asserting flash copy as the primary success signal | Use resource state on the page as the primary signal; flash is a secondary check |
| Drive-by assertions on nav/footer/sidebar inside a feature spec | One story per spec; assert only what belongs to the journey under test |
| System spec for a UI authorization rule when no product requirement exists | Policy spec for the logic + request spec for the HTTP gate is usually enough |

#### Do not write specs to prove code was removed

A test whose only assertion is `not_to have_*` does not test behaviour — it tests absence. It passes trivially (including if the page is blank), documents nothing about what users *can* do, and breaks silently when an element is renamed rather than removed.

```ruby
# Bad — only asserts an element is absent; no positive behaviour proven
it "does not show an excluded agencies section" do
  expect(page).not_to have_link("New Excluded Agency")
end

# Good — asserts what the user actually sees and can do
it "shows the agencies list" do
  visit agencies_path
  expect(page).to have_content("Agencies")
  expect(page).to have_link("New Agency")
end
```

`not_to` is valid as a **secondary assertion** confirming a visible change alongside a positive one:

```ruby
# Fine — not_to confirms removal after deletion, paired with a positive assertion
it "user deletes an article" do
  article = create(:article, title: "To Delete")
  visit article_path(article)
  click_button "Delete"

  expect(page).to have_content("Article deleted.")  # primary assertion
  expect(page).not_to have_content("To Delete")     # confirms removal
end
```

Every test must have at least one positive assertion. A test that consists only of `not_to` is not a test — it is a removal receipt.

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
- [ ] Every system spec passes the **Five Gates** (interaction, uniqueness, JS-necessity, single-home, one-story)
- [ ] System-spec count is within budget: ~1 canonical journey per CRUD resource, 1 per cross-resource journey, 1 per JS behaviour across the suite
- [ ] No `visit`-and-assert-only specs in `spec/system/` — they live in `spec/requests/` with `response.body.include?`
- [ ] No Selenium spec passes under `rack_test` — if it does, move it back
- [ ] System specs assert resource state on the page as the primary signal; flash copy is at most secondary
- [ ] Request specs verify status codes, redirects, auth gates, and rendering smoke (`response.body.include?`) for resources without a system spec
- [ ] Model specs cover domain verbs, scopes, and state transitions
- [ ] Policy specs cover the full role × action matrix
- [ ] Tests read as documentation — a new developer understands the feature from reading them
- [ ] No flaky tests — no sleep, no order-dependent state
- [ ] Transactional fixtures are on — they cover system specs too (Rails 5.1+ shares the connection); database_cleaner is unnecessary
- [ ] No cross-layer duplication — each behaviour is tested in exactly one spec type
- [ ] System specs don't inspect model internals — they assert what users see
- [ ] System specs don't re-test the same Stimulus controller / Turbo pattern across files
- [ ] Model specs don't re-test in request/system specs — integration specs trust the unit
- [ ] No redundant `it` blocks — tests with identical setup/action are merged into one
- [ ] Job/mailer callers assert enqueuing only — the job/mailer spec owns the work
- [ ] No standalone `not_to` assertions — every test has at least one positive assertion; `not_to` is only used alongside a positive one

## References

For detailed patterns and examples by spec type:

- [Model specs](references/model-specs.md) — domain logic, scopes, concerns, validations
- [Request specs](references/request-specs.md) — HTTP layer, auth, redirects
- [System specs](references/system-specs.md) — user flows, Capybara, browser testing
- [Factory patterns](references/factory-patterns.md) — FactoryBot conventions, traits, sequences
- [Support specs](references/support-specs.md) — jobs, mailers, concerns, POROs

## Refactoring an existing suite

For rebalancing a drifted suite — slimming heavy system specs, moving
assertions to their correct layer, deleting framework-tautology tests —
use the **`refactoring-rails-specs`** skill. It batches discovery → audit →
plan → execute → verify per resource, using this skill's Five Gates and
budget as the rubric.
