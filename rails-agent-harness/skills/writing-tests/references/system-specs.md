# System Specs Reference

System specs are the **backbone** of Rails testing, not the **coverage**.
They prove that routing, controllers, views, helpers, JavaScript, and
models compose into a working user journey. They are slow, brittle to
copy changes, and expensive to maintain — so each one must earn its
place.

The default answer to "should I add another system spec?" is **no — push
it down a layer.**

---

## Budget

Anchor on these numbers when deciding whether to add a system spec. Going
over the budget requires a stated reason ("this seam broke in production",
"this composition is not covered anywhere else"). Random additions are
the failure mode.

| Scope | Default budget |
|-------|---------------|
| Per CRUD resource | **1** canonical happy-path spec (typically create-and-see). Add a second only if edit or delete has materially different UI (modal, confirmation, multi-step). |
| Per non-trivial form | **1** validation-error spec proving the form re-renders with errors visible. Specific validation rules belong in model specs. |
| Per cross-resource journey (signup, onboarding, checkout, password reset) | **1** spec walking the whole journey end-to-end. |
| Per JavaScript behaviour (Stimulus controller, Turbo Stream pattern) | **1** spec on the simplest representative page. Other usages of the same controller assume it works. |
| Per UI authorization rule | **0** by default. Add 1 only when role-based hiding is a stated product requirement, and prefer asserting it as a secondary check inside an existing journey spec. |

Anything not in this table needs a justification. The defaults are
deliberately tight — system specs absorb work that belongs to model,
request, and policy specs unless held in check.

---

## The Five Gates

Before writing a system spec, every one of these must be true. If any
gate fails, write the test at a lower layer (request, model, policy,
helper) instead.

1. **Interaction gate.** The spec calls at least one of `fill_in`,
   `click_button`, `click_link`, `select`, `check`, `attach_file`, or
   similar. A spec that only calls `visit` and then asserts content is
   not a system spec — it is a view spec masquerading as one. Move it to
   a request spec asserting `response.body.include?`, or trust the
   canonical journey spec already proves the page renders.

2. **Uniqueness gate.** The user journey is materially different from any
   system spec already in the suite for this resource or area. If the
   only difference is the value being submitted, the field being checked,
   or which assertion runs at the end, fold it into the existing spec or
   push it down a layer.

3. **JavaScript-necessity gate.** If the spec requires Selenium, the
   behaviour under test cannot be proved by a request spec asserting the
   Turbo Stream content type, and is not already exercised by another
   system spec for the same Stimulus controller or Turbo pattern. A
   Stimulus controller earns at most one system spec across the entire
   suite, on the simplest page that uses it.

4. **Single-home gate.** The assertion is not already owned by a model
   spec (domain logic), request spec (HTTP / auth gate), policy spec
   (authorization rule), or mailer/job spec (work performed). System
   specs trust the lower layers; they do not duplicate them.

5. **One-story gate.** The spec tells exactly one user story end-to-end.
   No drive-by assertions about nav, footer, sidebar, or unrelated
   widgets. If the test grows past ~10 assertion lines, it is probably
   two stories glued together, or one story with opportunistic
   assertions.

---

## What System Specs Must Cover

These are the only flows that genuinely need a browser-driven integration
test. Everything else lives elsewhere.

### 1. The canonical happy path per major journey

For a CRUD resource, this is typically "user creates X, sees it on the
page." Edit and delete ride along in the same spec only if natural;
otherwise they go to request specs.

```ruby
RSpec.describe "Articles", type: :system do
  before { driven_by(:rack_test) }

  it "user creates an article" do
    user = create(:user)
    sign_in user

    visit new_article_path
    fill_in "Title", with: "Testing in Rails"
    fill_in "Body", with: "System specs are the backbone."
    click_button "Create Article"

    expect(page).to have_content("Testing in Rails")
  end
end
```

That is the entire CRUD system-spec budget for most resources. Do not
add separate `it` blocks for show / edit / delete unless the UI is
materially different.

### 2. Multi-request journeys where rendered HTML feeds the next step

Sign-up → confirm → onboard. Password reset email → click link → set
password. Checkout step 1 → step 2 → step 3. These earn a system spec
because the *integration between redirects, flash, form re-population,
and tokens* is the actual feature.

```ruby
it "new user signs up and lands on the dashboard" do
  visit new_registration_path
  fill_in "Email", with: "alice@example.com"
  fill_in "Password", with: "secretpass"
  fill_in "Company", with: "Acme"
  click_button "Sign up"

  expect(page).to have_content("Welcome, Alice")
  expect(page).to have_current_path(dashboard_path)
end
```

### 3. Flows that genuinely require JavaScript to function

The bar is "the user cannot complete the journey with JavaScript off,"
not "there is JS on the page." Turbo Stream updates after a
non-navigation event, inline edit modals, drag-and-drop, real-time
broadcasts.

```ruby
RSpec.describe "Live comments", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "new comment appears without page reload" do
    article = create(:article, :published)
    sign_in create(:user)

    visit article_path(article)
    fill_in "Comment", with: "Great article!"
    click_button "Post Comment"

    expect(page).to have_content("Great article!")
  end
end
```

One spec proves the Turbo Stream pattern works. Other forms that broadcast
in the same way assume it works.

### 4. One canonical validation-error spec per non-trivial form

Prove the form re-renders with errors visible. The *content* of the
validation belongs to the model spec.

```ruby
it "user sees validation errors on invalid submit" do
  sign_in create(:user)

  visit new_article_path
  click_button "Create Article"

  expect(page).to have_content("can't be blank")
end
```

One spec per form. Not one per field, not one per validation rule.

### 5. UI authorization rules — only when product-required

Skip by default. Write one only when "this user must not see this
button" is a stated requirement, and prefer asserting it as a secondary
check inside an existing journey spec.

```ruby
it "owner sees delete button, others do not" do
  owner = create(:user)
  article = create(:article, author: owner)

  sign_in owner
  visit article_path(article)
  expect(page).to have_button("Delete")

  sign_in create(:user)
  visit article_path(article)
  expect(page).not_to have_button("Delete")
end
```

Even this is often better expressed as a policy spec (logic) plus a
request spec (HTTP gate). Reach for a UI-level system spec only when the
hiding is a visible product feature.

---

## When NOT to Write a System Spec

These are the high-frequency mistakes. Each pattern below should be
moved to the layer indicated.

### Visit-only specs ("the page shows X")

If the spec only calls `visit` and then asserts content, with no
interaction, it is a view spec. Move it.

```ruby
# Bad — no interaction; this is not a system spec
it "shows the article on its page" do
  article = create(:article, :published, title: "Hello")
  visit article_path(article)
  expect(page).to have_content("Hello")
end

# Good — request spec proves the same thing, 10x faster
describe "GET /articles/:id" do
  it "renders the article" do
    article = create(:article, :published, title: "Hello")
    get article_path(article)
    expect(response.body).to include("Hello")
  end
end
```

### Repeated testing of the same JavaScript behaviour

A Stimulus controller (character counter, confirm-on-delete, dropdown
toggle, autosave) earns at most one system spec across the suite — on
the simplest page that uses it. Other usages assume it works.

```ruby
# Bad — testing the same character counter across three forms
it "article form shows character count"   # Selenium
it "comment form shows character count"   # Selenium
it "bio form shows character count"       # Selenium

# Good — one spec proves the controller works
it "character counter updates as user types" do
  driven_by(:selenium_chrome_headless)
  visit new_article_path
  fill_in "Title", with: "Short"
  expect(page).to have_content("5 / 100 characters")
end
```

### Trivial persistence-via-UI checks

"User updates their bio and the bio is saved." If the behaviour is
"form posts, attribute round-trips, redirect," request + model specs
already prove it. System specs only own persistence-through-UI when the
form composition itself is non-trivial: nested attributes, multi-select,
`accepts_nested_attributes_for`, polymorphic associations rendered as a
single form.

### Per-attribute or per-field assertions

The form does not need a system spec per field. If the composition is
non-trivial, one spec exercises the form as a whole. Per-field round-trip
testing belongs to model specs (the attribute is set) and request specs
(the parameter is permitted).

```ruby
# Bad — one spec per field
it "user sets the title"
it "user sets the body"
it "user sets the visibility"
it "user sets the due date"

# Good — one spec exercises the form; round-tripping is request/model
it "user creates an article" do
  # ...fills the form fully, asserts the result
end
```

### CRUD parity proliferation

Do not write one system spec per CRUD action when the actions share a
shape. Pick the most representative flow (usually create) and push the
rest to request specs.

```ruby
# Bad — four near-identical system specs
it "user creates an article"
it "user edits an article"
it "user deletes an article"
it "user views an article"

# Good — one system spec; edit/delete/show live in request specs
it "user creates an article" do
  # ...canonical create flow
end
```

Add a second system spec only when edit or delete has UI that genuinely
differs (e.g. delete is a confirmation modal driven by Stimulus).

### Flash message and copy as the primary signal

Asserting `have_content("Article created.")` is brittle to copy changes.
Use the resource state ("the article title appears on the page") as the
primary signal that the action succeeded. Flash assertions are a fine
*secondary* check when the flash itself is the feature (account locked,
session expired, rate limited).

### Negative-path proliferation

Every "unauthorized user sees X," "missing param returns Y," "empty
state shows Z" does not need a system spec. These belong in request
specs (status / redirect) and policy specs (logic). Empty-state copy
gets at most a request spec asserting `response.body.include?`.

### Selenium when rack_test would do

If the spec passes under `rack_test`, it is not a JavaScript spec.
Selenium adds 10× the runtime and an order of magnitude more flakiness.
Default to `rack_test`; switch only when the behaviour under test
provably fails without JS.

### Drive-by assertions

A spec titled "user creates an article" must not also assert nav links,
footer copy, sidebar widgets, or the global search bar. Each system
spec tells one story. Drive-by assertions couple unrelated changes
together — a footer copy change breaks the article-creation spec.

### `not_to` as a primary assertion

Already in the skill, but worth restating: a test whose only assertion
is `not_to have_*` proves only absence. It passes trivially on a blank
page. Every test needs a positive assertion; `not_to` is a secondary
check that pairs with one.

---

## Driver Selection

### rack_test (default)

Fast, no JavaScript, no real browser. Use for everything that doesn't
need JS.

```ruby
before { driven_by(:rack_test) }
```

### selenium_chrome_headless (only when JavaScript is essential)

Use only when the behaviour under test provably requires JavaScript —
Turbo Stream updates after a non-navigation event, Stimulus-driven UI
state, drag-and-drop.

```ruby
before { driven_by(:selenium_chrome_headless) }
```

If the spec passes under `rack_test`, it is not a Selenium spec. Move it
back.

---

## Authentication in System Specs

Sign in through the form by default — it tests the real auth path.
Switch to direct session insertion only when sign-in adds meaningful
time to a spec that isn't testing auth.

```ruby
# spec/support/system_authentication.rb
module SystemAuthenticationHelper
  def sign_in(user, password: "password")
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: password
    click_button "Sign in"
  end
end

RSpec.configure do |config|
  config.include SystemAuthenticationHelper, type: :system
end
```

---

## Form Interactions

Use Capybara's high-level DSL — `fill_in` by label, `click_button` by
visible text, `select` by option text. Do not select by CSS id or
`name` attribute. Tests read as user actions, not as DOM scripts.

```ruby
# Good — reads like a user
fill_in "Title", with: "Hello"
select "Private", from: "Visibility"
check "I agree to the terms"
attach_file "Avatar", Rails.root.join("spec/fixtures/files/avatar.jpg")
click_button "Create Article"

# Bad — DOM-coupled
fill_in "article_title", with: "Hello"
find("#submit").click
```

---

## Waiting for Async

Capybara's finders auto-wait (default 2 seconds). Bump the wait when an
async operation genuinely takes longer.

```ruby
expect(page).to have_content("Processing complete", wait: 5)
```

Never use `sleep` — always use Capybara's built-in waiting.

---

## Multi-User Scenarios

Use `using_session` to simulate multiple users in the same spec. Reserve
this for collaboration features where two users interacting *is the
feature* (real-time chat, shared documents). Don't reach for it to test
isolated per-user behaviour — sign in as one user, log out, sign in as
another instead.

```ruby
it "two users see each other's comments" do
  driven_by(:selenium_chrome_headless)

  article = create(:article)
  alice = create(:user, name: "Alice")
  bob = create(:user, name: "Bob")

  using_session(:alice) do
    sign_in alice
    visit article_path(article)
    fill_in "Comment", with: "Hello from Alice"
    click_button "Post Comment"
  end

  using_session(:bob) do
    sign_in bob
    visit article_path(article)
    expect(page).to have_content("Hello from Alice")
  end
end
```

---

## A Note on Page Objects

Page objects are rarely needed in Rails. The Capybara DSL *is* the page
object — `visit`, `fill_in`, `click_button`, `have_content` already read
like English. Wrapping them in a class adds indirection without adding
clarity.

If you reach for page objects, the system spec is probably too complex —
which usually means it is doing the work of a lower-layer spec. Look for
gates 1, 2, and 5 violations first.

---

## Accessibility Checks

Integrate accessibility assertions into existing system specs — do not
write standalone accessibility-only specs.

```ruby
it "user creates an article" do
  # ...the canonical flow
  expect(page).to be_axe_clean
end
```

Requires the `axe-core-rspec` gem.

---

## Boundaries — What Belongs Here vs. Elsewhere

### What system specs own

- The canonical happy path through each major user journey
- Multi-request journeys where rendered HTML feeds the next step
- Behaviour that genuinely requires JavaScript to function
- One validation-error path per non-trivial form
- UI authorization, only when product-required

### What system specs do NOT test

- Model internals (`article.publication.present?`) — model spec
- Status codes (`response.status`) — request spec
- Auth gates (unauthenticated → redirect) — request spec
- Authorization logic (admin vs. member matrix) — policy spec
- Job / mailer work — job / mailer spec
- Helper output — helper spec or canonical system spec implicitly
- Every CRUD action when the actions share a shape — request spec
- Every field, every validation, every role — push down

### Trust the lower layers

```ruby
# Good — asserts what the user sees
it "user publishes an article" do
  visit article_path(article)
  click_button "Publish"

  expect(page).to have_content("Published")
end

# Bad — reaches into model internals
it "user publishes an article" do
  visit article_path(article)
  click_button "Publish"

  expect(article.reload.publication).to be_present  # model spec's job
  expect(article.reload).to be_published             # model spec's job
end
```

---

## Within-File Discipline

Don't split a single user story into stepwise tests:

```ruby
# Bad — split flow into micro-tests
it "user visits the new article page" do
  visit new_article_path
  expect(page).to have_field("Title")
end

it "user fills in the form" do
  visit new_article_path
  fill_in "Title", with: "Test"
  click_button "Create Article"
  expect(page).to have_content("Test")
end

# Good — one test for the complete flow
it "user creates an article" do
  visit new_article_path
  fill_in "Title", with: "Test"
  fill_in "Body", with: "Content"
  click_button "Create Article"

  expect(page).to have_content("Test")
end
```

Separate tests are for separate flows (create vs. edit), not for
separate steps inside one flow.

---

## Guidelines

- **System specs are the backbone, not the coverage** — push to lower layers by default
- **Default to `rack_test`** — Selenium only when JS provably required
- **Sign in through the form** — tests the real auth path
- **Use Capybara's high-level DSL** — `fill_in` by label, `click_button` by visible text
- **Never use `sleep`** — use Capybara's built-in waiting
- **One story per spec** — no drive-by assertions
- **Resource state as the primary signal** — flash content is a secondary check
- **Don't duplicate lower layers** — model logic, status codes, policy rules, mailer content all live elsewhere
- **Selenium-driven specs are a budget** — one per JS behaviour across the entire suite
