# System Specs Reference

System specs are the backbone of Rails testing. They simulate real users
interacting with the application through a browser — clicking buttons,
filling forms, navigating pages. They give the highest confidence that
the feature actually works.

## Structure

```ruby
# spec/system/articles_spec.rb
RSpec.describe "Articles", type: :system do
  before do
    driven_by(:rack_test)
  end

  it "user creates an article" do
    user = create(:user)
    sign_in user

    visit new_article_path
    fill_in "Title", with: "My New Article"
    fill_in "Body", with: "This is the content."
    click_button "Create Article"

    expect(page).to have_content("My New Article")
    expect(page).to have_content("Article created.")
  end
end
```

---

## Driver Selection

### rack_test (Default — Fast)

Use for most system specs. No JavaScript, no real browser, but very fast.

```ruby
before do
  driven_by(:rack_test)
end
```

### selenium_chrome_headless (When JS Required)

Use only when the test requires JavaScript (Turbo Streams, Stimulus
controllers, dynamic UI).

```ruby
before do
  driven_by(:selenium_chrome_headless)
end
```

### Guidelines

- Default to `rack_test` — it's 10x faster than Selenium
- Only switch to Selenium when the feature under test requires JS
- If you're testing a form submission and redirect, `rack_test` is enough
- If you're testing live Turbo Stream updates or Stimulus behaviour, use Selenium

---

## Authentication in System Specs

### Sign-In Helper

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

### Warden/Devise-Style Direct Login

If you want to skip the login form for speed (common with Devise):

```ruby
# For Rails 8 built-in auth, sign in via the form is recommended.
# For Devise: login_as(user, scope: :user)
```

Prefer signing in through the form in system specs — it tests the
real auth flow. Only use direct login when auth is not what you're testing
and the form sign-in adds meaningful time.

---

## CRUD Feature Specs

### Full Lifecycle

```ruby
RSpec.describe "Article management", type: :system do
  before { driven_by(:rack_test) }

  let(:user) { create(:user) }

  before { sign_in user }

  it "user creates an article" do
    visit articles_path
    click_link "New Article"

    fill_in "Title", with: "Testing in Rails"
    fill_in "Body", with: "System specs are great."
    click_button "Create Article"

    expect(page).to have_content("Testing in Rails")
    expect(page).to have_content("Article created.")
  end

  it "user edits an article" do
    article = create(:article, author: user, title: "Original Title")

    visit article_path(article)
    click_link "Edit"

    fill_in "Title", with: "Updated Title"
    click_button "Update Article"

    expect(page).to have_content("Updated Title")
    expect(page).to have_content("Article updated.")
  end

  it "user deletes an article" do
    article = create(:article, author: user, title: "To Delete")

    visit article_path(article)
    click_button "Delete"

    expect(page).to have_content("Article deleted.")
    expect(page).not_to have_content("To Delete")
  end

  it "user sees validation errors" do
    visit new_article_path

    fill_in "Title", with: ""
    click_button "Create Article"

    expect(page).to have_content("can't be blank")
  end
end
```

---

## State Transition Flows

```ruby
RSpec.describe "Card closing", type: :system do
  before { driven_by(:rack_test) }

  it "user closes and reopens a card" do
    user = create(:user)
    card = create(:card, title: "Fix the bug")
    sign_in user

    visit card_path(card)
    click_button "Close"

    expect(page).to have_content("Closed")
    expect(page).to have_button("Reopen")

    click_button "Reopen"

    expect(page).to have_content("Open")
    expect(page).to have_button("Close")
  end
end
```

---

## List and Filtering

```ruby
RSpec.describe "Article listing", type: :system do
  before { driven_by(:rack_test) }

  it "displays published articles" do
    published = create(:article, :published, title: "Visible Article")
    draft = create(:article, title: "Draft Article")

    visit articles_path

    expect(page).to have_content("Visible Article")
    expect(page).not_to have_content("Draft Article")
  end

  it "user searches articles" do
    create(:article, :published, title: "Rails Testing")
    create(:article, :published, title: "Ruby Gems")

    visit articles_path
    fill_in "Search", with: "testing"
    click_button "Search"

    expect(page).to have_content("Rails Testing")
    expect(page).not_to have_content("Ruby Gems")
  end
end
```

---

## Form Interactions

### Select Dropdowns

```ruby
it "user sets article visibility" do
  visit new_article_path

  fill_in "Title", with: "Private Post"
  select "Private", from: "Visibility"
  click_button "Create Article"

  expect(page).to have_content("Private")
end
```

### Checkboxes and Radio Buttons

```ruby
it "user accepts terms" do
  visit new_registration_path

  fill_in "Name", with: "Alice"
  fill_in "Email", with: "alice@example.com"
  check "I agree to the terms"
  click_button "Sign up"

  expect(page).to have_content("Welcome!")
end
```

### File Uploads

```ruby
it "user uploads an avatar" do
  visit edit_profile_path

  attach_file "Avatar", Rails.root.join("spec/fixtures/files/avatar.jpg")
  click_button "Update Profile"

  expect(page).to have_css("img[src*='avatar']")
end
```

---

## JavaScript-Dependent Tests

Only use Selenium when the test requires JavaScript execution.

### Turbo Stream Updates

```ruby
RSpec.describe "Live comments", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "new comment appears without page refresh" do
    article = create(:article, :published)
    user = create(:user)
    sign_in user

    visit article_path(article)
    fill_in "Comment", with: "Great article!"
    click_button "Post Comment"

    # Turbo Stream appends the comment without navigation
    expect(page).to have_content("Great article!")
    expect(page).not_to have_current_path(new_article_comment_path(article))
  end
end
```

### Stimulus Controllers

```ruby
it "character counter updates as user types" do
  driven_by(:selenium_chrome_headless)

  visit new_article_path
  fill_in "Title", with: "Short"

  expect(page).to have_content("5 / 100 characters")
end
```

### Waiting for Async

Capybara's finders automatically wait (default 2 seconds). Increase for
slow operations:

```ruby
expect(page).to have_content("Processing complete", wait: 5)
```

Never use `sleep` — always use Capybara's built-in waiting.

---

## A Note on Page Objects

Page objects are rarely needed in Rails. The Capybara DSL *is* your page
object — `visit`, `fill_in`, `click_button`, `have_content` already read
like plain English. Wrapping them in a class adds indirection without
adding clarity.

If you find yourself reaching for page objects, consider whether the spec
is too complex instead. Break it into multiple focused specs or simplify
the page under test. Only consider page objects for extremely complex admin
dashboards where identical page interactions are tested from many angles.

---

## Multi-User Scenarios

Use `using_session` to simulate multiple users:

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

## Accessibility Checks

Integrate accessibility assertions into system specs:

```ruby
it "article page is accessible" do
  article = create(:article, :published)

  visit article_path(article)

  expect(page).to be_axe_clean
end
```

Requires the `axe-core-rspec` gem.

---

## Boundaries — What Belongs Here vs. Elsewhere

System specs own user-visible flows. They prove the feature works from the
user's perspective. They do not inspect model internals or assert HTTP details.

### What System Specs Own

- User flows: "user creates an article", "admin closes a card"
- Page content: the user sees the right text, links, buttons after an action
- Form interactions: fill in, select, check, submit, see result
- Navigation: the user ends up on the right page
- Error states: the user sees validation errors, flash messages
- Multi-step workflows: sign up → onboard → see dashboard

### What System Specs Do NOT Test

- Model internals: don't assert `article.publication.present?` — assert the page shows "Published"
- Status codes: don't check `response.status` — that's a request spec concern
- Domain logic edge cases: don't test every scope permutation — model spec covers that
- Exact database state: don't count records or inspect columns — assert what the user sees

### Trust the Lower Layers

The system spec trusts that model logic works (the model spec covers it)
and that the HTTP layer works (the request spec covers it). The system spec
just verifies the glue — user does a thing, user sees the result:

```ruby
# Good — asserts what the user sees
it "user publishes an article" do
  visit article_path(article)
  click_button "Publish"

  expect(page).to have_content("Published")
  expect(page).not_to have_button("Publish")
end

# Bad — reaching into model internals
it "user publishes an article" do
  visit article_path(article)
  click_button "Publish"

  expect(article.reload.publication).to be_present  # Model spec's job
  expect(article.reload).to be_published             # Model spec's job
end
```

### No Redundant Tests Within the File

Don't write separate tests for steps in the same flow:

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
  expect(page).to have_content("Article created.")
end
```

Separate tests for separate flows (create vs. edit vs. delete), not for
separate steps within one flow.

## Guidelines

- **Test user flows, not implementation** — "user creates an article", not "form posts to /articles"
- **One flow per test** — a test should tell one story
- **Assert what users see, not model state** — `have_content("Published")`, not `article.published?`
- **Use `rack_test` by default** — Selenium only when JS is required
- **Sign in through the form** — tests the real auth path
- **Never use `sleep`** — use Capybara's built-in waiting
- **Use `have_content`** for text, **`have_css`** for elements, **`have_link`** / **`have_button`** for interactions
- **Fill in by label text** — `fill_in "Title"`, not `fill_in "article_title"`
- **Click by visible text** — `click_button "Save"`, not `find("#submit").click`
- **Keep tests independent** — no test should depend on another test's side effects
- **Test error states** — validation errors, unauthorized access, not found
- **Don't duplicate model spec assertions** — the model spec proves the logic; the system spec proves the UX
- **Don't duplicate request spec concerns** — system specs don't check status codes or response headers
