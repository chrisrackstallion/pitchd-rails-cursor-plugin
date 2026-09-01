---
name: writing-tests
description: >-
  Write Rails tests with RSpec and FactoryBot — system specs as the backbone,
  real objects over mocks, behaviour-driven over implementation testing. Use
  when writing specs, adding test coverage, debugging test failures, creating
  factories, or when the user mentions tests, specs, RSpec, FactoryBot,
  Capybara, system tests, or request specs.
---

# Writing Rails Tests

<objective>
Write tests that give you confidence to ship, at the lowest layer that can
prove the behaviour, with real objects, real database records, and real
rendering. The normative canon — philosophy, test pyramid, system-spec budget,
Five Gates, ownership by layer, anti-patterns, falsifiability, running and
flake discipline — is **`agent_harness_rails/rules/testing.mdc`**. Read it
before writing any spec; this skill routes you to the right spec type and the
worked patterns for it.
</objective>

**Announce:** "I'm using the writing-tests skill."

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
| Mailer class, templates, previews | Read `agent_harness_rails/skills/writing-mailers/references/patterns.md`; RSpec examples in `references/support-specs.md` § Mailer Specs |
| I18n / asserting on translated copy | Read `agent_harness_rails/skills/writing-i18n/references/patterns.md` § Testing |
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
        CRUD round-trip) or anything about what a page renders?
        ├── YES → Request spec (rendering is ALWAYS a request spec — never a view spec)
        └── NO
            Is this the work a job, mailer, or PORO performs?
            ├── YES → Spec matching the object type
            └── NO
                Does this user journey pass ALL FIVE GATES
                (interaction, uniqueness, JS-necessity, single-home, one-story —
                agent_harness_rails/rules/testing.mdc § The Five Gates)?
                ├── YES → System spec — within the budget
                └── NO → Push down a layer; do NOT add a system spec
```

The system-spec **budget**, the **Five Gates**, and the **ownership table**
(which layer owns which behaviour, including the auth-gate and rate-limit
rules) live in `agent_harness_rails/rules/testing.mdc`. Full gate rationale
and the patterns that look like system specs but belong elsewhere:
`references/system-specs.md`.

### 3. Test Structure

Every test follows Arrange-Act-Assert:

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
- **One behaviour per test** — multiple assertions are fine if they verify one behaviour; split into a new `it` when the *context* differs, not when you want another `expect` on the same outcome (`agent_harness_rails/rules/testing.mdc` § Within a Single Spec File)
- **Descriptive names** — `describe "#method"`, `context "when X"`, `it "does Y"`
- **Real objects** — `create(:article)`, not `double` or `instance_double`

### 4. The Rules You Are Working Under

All normative in **`agent_harness_rails/rules/testing.mdc`** — one-line
pointers, not restated here:

- **Each behaviour has one home** — § Ownership by Layer is the arbitration
  table; check it before writing a test that another layer might own.
- **Anti-patterns** — § What NOT to Do is the full table (mocking, view
  specs, per-field system specs, Selenium-where-rack_test-passes, and more).
- **Every assertion must be able to fail** — § Every Assertion Must Be Able
  to Fail covers unanchored absences, tautological anchors, discriminating
  setup, recovery over error codes, finder branches, and removal receipts.
- **Running specs** — § Running Specs, § When a Run Comes Back Red, and
  § Flaky and Order-Dependent Failures: run the narrowest slice, re-run
  failures not runs, report flakes with their seed. Never call the suite
  green off a slice run — report the command you ran.
- **Intent tags** — when the app has `docs/primitives/`, the example proving
  an intent clause carries `intent:` metadata per
  **`agent_harness_rails/rules/intent-tags.mdc`**; finish with
  `agent_harness_rails evals` green.

### 5. Verification

Before finishing, verify:

- [ ] Tests cover the happy path and key error paths
- [ ] Each test is self-contained — can run in isolation
- [ ] Factory uses minimal required attributes
- [ ] Every spec passes the tables in `agent_harness_rails/rules/testing.mdc`: the **Budget** and **Five Gates** for any system spec, § Ownership by Layer for where each assertion lives (no cross-layer duplication), and § What NOT to Do for the anti-patterns — mocking, view specs, visit-only specs, Selenium where `rack_test` passes, flash-as-signal, unanchored absences, indiscriminate setup
- [ ] Tests read as documentation — a new developer understands the feature from reading them
- [ ] No flaky tests — no sleep, no order-dependent state
- [ ] Transactional fixtures are on — they cover system specs too (Rails 5.1+ shares the connection); database_cleaner is unnecessary
- [ ] No redundant `it` blocks — tests with identical setup/action are merged into one
- [ ] No removal-verification scaffolding left behind — any throwaway spec written to confirm a deletion is deleted before reporting
- [ ] The commands you ran match the scope you changed, and the report names them — no full-suite run without an earned reason
- [ ] When the app has `docs/primitives/`: every spec proving an intent clause carries its `intent:` tag per `agent_harness_rails/rules/intent-tags.mdc`, the clause lists the file in `evaluations:`, and **`agent_harness_rails evals`** is green

## References

For detailed patterns and examples by spec type:

- [Model specs](references/model-specs.md) — domain logic, scopes, concerns, validations
- [Request specs](references/request-specs.md) — HTTP layer, auth, redirects
- [System specs](references/system-specs.md) — user flows, Capybara, browser testing
- [Factory patterns](references/factory-patterns.md) — FactoryBot conventions, traits, sequences
- [Support specs](references/support-specs.md) — policies, jobs, mailers, concerns, POROs

## Refactoring an existing suite

For rebalancing a drifted suite — slimming heavy system specs, moving
assertions to their correct layer, deleting framework-tautology tests —
use the **`refactoring-rails-specs`** skill. It batches discovery → audit →
plan → execute → verify per resource, using the Five Gates and budget in
`agent_harness_rails/rules/testing.mdc` as the rubric.
