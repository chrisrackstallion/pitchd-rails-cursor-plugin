# Request Specs Reference

Request specs are the **workhorse layer** of the suite. They test the
HTTP layer — status codes, redirects, params, response bodies, auth
gates — and they absorb most of the CRUD and rendering coverage that
system specs would otherwise bloat with. A request spec runs in
milliseconds, hits real controllers, renders real views, and proves the
record round-tripped through the database. For everything except the
canonical happy-path journey, request specs are the right home.

They replace controller specs (which are deprecated) **and view specs
(which are never written)**, and complement system specs by covering
everything browsers can't verify cheaply, and much of what they *can*
verify but shouldn't pay the Selenium tax for.

**Request specs own rendering.** Never write a view spec (`spec/views/`,
`type: :view`) — it renders a template in isolation with stubbed assigns,
which tests implementation rather than behaviour and drifts from what the
controller actually renders. Any "does the page show X?" assertion belongs
in a request spec via `response.body.include?`.

What request specs own versus every other layer — including the auth-gate,
rate-limit, CSRF, and Turbo-content-type rows: **`agent_harness_rails/rules/testing.mdc`**
§ Ownership by Layer. This file is the worked mechanics.

## Structure

```ruby
# spec/requests/articles_spec.rb
RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    it "returns a successful response" do
      sign_in create(:user)
      create_list(:article, 3, :published)

      get articles_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /articles" do
    it "creates an article and redirects" do
      sign_in create(:user)

      post articles_path, params: { article: { title: "New", body: "Content" } }

      expect(response).to redirect_to(article_path(Article.last))
      expect(Article.count).to eq(1)
    end

    it "re-renders the form with invalid data" do
      sign_in create(:user)

      post articles_path, params: { article: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
```

---

## Authentication Helpers

Set up a sign-in helper that works with your auth system. For Rails 8
built-in authentication:

```ruby
# spec/support/authentication.rb
module AuthenticationHelper
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect!
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
```

Or set the session cookie directly for speed. The Rails 8 `Authentication`
concern reads `cookies.signed[:session_id]`, so writing the raw id does not
authenticate — the value must be signed:

```ruby
module AuthenticationHelper
  def sign_in(user)
    session = user.sessions.create!
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::TestRequest.create, {}
    )
    jar.signed[:session_id] = session.id
    cookies[:session_id] = jar[:session_id]
  end
end
```

If that feels like too much machinery, keep the form-based helper above —
it is one extra request per spec and tests the real path.

---

## CRUD Resource Specs

Most resources have **one canonical system spec** (the create-and-see happy
path) and a request spec that covers every other action — index, show,
edit, update, destroy — plus auth gates, validation responses, and
rendering smoke. The request spec is doing the heavy lifting; the system
spec only proves the canonical journey integrates end-to-end.

```ruby
RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    it "lists articles" do
      sign_in create(:user)
      published = create(:article, :published, title: "Visible Article")

      get articles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible Article")
    end
  end

  describe "GET /articles/:id" do
    it "shows the article" do
      sign_in create(:user)
      article = create(:article, :published, title: "Testing Guide")

      get article_path(article)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Testing Guide")
    end
  end

  describe "POST /articles" do
    # Note: The canonical create-and-see happy path lives in the system spec.
    # The request spec covers the HTTP shape and the failure case.

    it "rejects invalid params and accepts the correction" do
      sign_in create(:user)

      post articles_path, params: { article: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)

      post articles_path, params: { article: { title: "Second attempt" } }

      expect(response).to redirect_to(Article.last)
      expect(Article.last.title).to eq("Second attempt")
    end
  end

  describe "PATCH /articles/:id" do
    it "updates and redirects" do
      user = create(:user)
      sign_in user
      article = create(:article, author: user, title: "Original")

      patch article_path(article), params: { article: { title: "Updated" } }

      expect(response).to redirect_to(article_path(article))
      expect(article.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /articles/:id" do
    it "destroys and redirects to index" do
      user = create(:user)
      sign_in user
      article = create(:article, author: user)

      delete article_path(article)

      expect(response).to redirect_to(articles_path)
      expect(Article.exists?(article.id)).to be false
    end
  end
end
```

### Failure Paths — Assert the Recovery, Not the Error

A bare `expect(response).to have_http_status(:unprocessable_content)` is green
whether or not the page that came back is usable. The 422 is the **setup**; the
behaviour is that the user can correct the input and land the mutation — so the
example submits twice, as in `POST /articles` above.

Where the action's finder can return a record in more than one state —
`find_or_initialize_by`, a singular resource, a create that revives or re-decides
an existing row — that is two renderings, not one, and each needs its own example.
The branch that is usually missing is the one whose setup costs an extra line:

```ruby
describe "POST /cards/:card_id/closure" do
  it "rejects a blank reason and accepts the correction" do
    sign_in create(:user)
    card = create(:card)

    post card_closure_path(card), params: { closure: { reason: "" } }

    expect(response).to have_http_status(:unprocessable_content)

    post card_closure_path(card), params: { closure: { reason: "Duplicate" } }

    expect(response).to redirect_to(card_path(card))
    expect(card.reload).to be_closed
  end

  it "rejects a blank reason on a card that is already closed" do
    sign_in create(:user)
    card = create(:card, :closed)     # the finder returns a persisted record here

    post card_closure_path(card), params: { closure: { reason: "" } }

    expect(response).to have_http_status(:unprocessable_content)

    post card_closure_path(card), params: { closure: { reason: "Superseded" } }

    expect(response).to redirect_to(card_path(card))
    expect(card.reload.closure.reason).to eq("Superseded")
  end
end
```

The second example is the one that catches a re-rendered form addressed to a verb
the route does not serve — `form_with model:` infers `PATCH` from a persisted
record, and a `POST`-only route answers that with a 404 at submit time
(`agent_harness_rails/rules/views.mdc` § Form Conventions). Nothing short of
submitting the corrected form sees it.

### Rendering Smoke (Replaces visit-only System Specs)

Use this pattern whenever you'd otherwise be tempted to write a
`visit`-only system spec. It's an order of magnitude faster and proves
the same thing — the page renders and contains the expected content.

```ruby
describe "GET /articles/:id" do
  it "renders the article title and body" do
    sign_in create(:user)
    article = create(:article, :published, title: "Hello", body: "World")

    get article_path(article)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hello")
    expect(response.body).to include("World")
  end
end
```

This is the right home for "does the page show X?" — not a system spec.

---

## Authentication and Authorization

Request specs test the HTTP gate — status codes and redirects. The policy
spec tests the authorization *logic* (who can do what). Don't re-test
policy logic here; just verify the endpoint enforces it.

### Unauthenticated Access

```ruby
describe "GET /articles" do
  context "when not signed in" do
    it "redirects to login" do
      get articles_path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
```

### Authorization (with Pundit)

Request specs verify that Pundit enforcement works at the HTTP layer —
one authorized and one unauthorized case per endpoint, per
`agent_harness_rails/rules/testing.mdc` § Ownership by Layer; the policy
spec covers the full role × action matrix.

The `rescue_from Pundit::NotAuthorizedError` handler in `ApplicationController`
typically redirects with a flash (302). Test accordingly:

```ruby
describe "DELETE /articles/:id" do
  it "redirects unauthorized users" do
    article = create(:article)
    sign_in create(:user) # authenticated but not the owner

    delete article_path(article)

    expect(response).to redirect_to(root_path)
    # Don't also assert policy.destroy? — policy spec owns that
  end

  it "succeeds for the article owner" do
    user = create(:user)
    sign_in user
    article = create(:article, creator: user)

    delete article_path(article)

    expect(response).to redirect_to(articles_path)
  end
end
```

> **Important:** Sign in an authenticated but *unauthorized* user to test
> the Pundit layer specifically. If you skip sign-in, the authentication
> layer redirects to login before Pundit ever runs — you'd be testing auth,
> not authorization.

### Admin-Only Endpoints

```ruby
RSpec.describe "Admin::Users", type: :request do
  describe "GET /admin/users" do
    it "redirects non-admins" do
      sign_in create(:user)

      get admin_users_path

      expect(response).to redirect_to(root_path)
    end

    it "succeeds for admins" do
      sign_in create(:user, :admin)

      get admin_users_path

      expect(response).to have_http_status(:ok)
    end
  end
end
```

---

## Nested Resources

Scope requests through the parent resource.

```ruby
RSpec.describe "Article Comments", type: :request do
  describe "POST /articles/:article_id/comments" do
    it "creates a comment and redirects" do
      user = create(:user)
      sign_in user
      article = create(:article)

      expect {
        post article_comments_path(article),
          params: { comment: { body: "Great article!" } }
      }.to change(article.comments, :count).by(1)

      expect(response).to redirect_to(article_path(article))
    end
  end

  describe "DELETE /articles/:article_id/comments/:id" do
    it "destroys the comment and redirects" do
      user = create(:user)
      sign_in user
      article = create(:article)
      comment = create(:comment, article: article)

      delete article_comment_path(article, comment)

      expect(response).to redirect_to(article_path(article))
      expect(Comment.exists?(comment.id)).to be false
    end
  end
end
```

---

## State-Change Controllers

For controllers that map custom actions to CRUD (e.g., closing, publishing):

```ruby
RSpec.describe "Card Closures", type: :request do
  describe "POST /cards/:card_id/closure" do
    it "redirects to the card on success" do
      user = create(:user)
      sign_in user
      card = create(:card, creator: user)

      post card_closure_path(card)

      expect(response).to redirect_to(card_path(card))
      # Don't assert card.reload.closed? — the model spec owns that.
      # This spec proves the endpoint returns the right HTTP response.
    end

    it "redirects unauthorized users" do
      sign_in create(:user)
      card = create(:card) # created by someone else

      post card_closure_path(card)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /cards/:card_id/closure" do
    it "redirects to the card on success" do
      user = create(:user)
      sign_in user
      card = create(:card, :closed, creator: user)

      delete card_closure_path(card)

      expect(response).to redirect_to(card_path(card))
    end
  end
end
```

---

## Turbo Responses

### Turbo Stream Requests

Test that Turbo Stream requests get the right content type:

```ruby
describe "POST /articles" do
  it "returns a Turbo Stream on success" do
    sign_in create(:user)

    post articles_path,
      params: { article: { title: "New", body: "Content" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response.content_type).to include("text/vnd.turbo-stream.html")
  end
end
```

### Turbo Frame Requests

Test that Turbo Frame requests return the expected frame:

```ruby
describe "GET /articles/:id/edit" do
  it "returns the edit form within a Turbo Frame" do
    sign_in create(:user)
    article = create(:article)

    get edit_article_path(article),
      headers: { "Turbo-Frame" => "article_#{article.id}" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("turbo-frame")
  end
end
```

---

## Rate Limiting

`rate_limit` counts attempts in `Rails.cache`. The test environment
defaults to `:null_store`, which stores nothing — the limit never trips
and the spec fails. Use a real store for these specs:

```ruby
describe "POST /sessions" do
  it "rate limits after 10 attempts" do
    memory_store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(memory_store)

    11.times do
      post session_path, params: { email_address: "test@example.com", password: "wrong" }
    end

    expect(response).to have_http_status(:too_many_requests)
  end
end
```

(Or set `config.cache_store = :memory_store` in `config/environments/test.rb`
and skip the stub.)

---

## File Uploads

```ruby
describe "POST /articles" do
  it "attaches an image" do
    sign_in create(:user)
    image = fixture_file_upload("test_image.jpg", "image/jpeg")

    post articles_path, params: { article: { title: "With Image", image: image } }

    expect(Article.last.image).to be_attached
  end
end
```

---

## Response Body Assertions

When you need to check rendered content, request specs are the home —
never a view spec, and not a system spec unless the journey involves
interaction:

```ruby
describe "GET /articles/:id" do
  it "includes the article title" do
    sign_in create(:user)
    article = create(:article, title: "Testing Guide")

    get article_path(article)

    expect(response.body).to include("Testing Guide")
  end
end
```

---

## Within-File Discipline

One test per concern — assertions about the same action belong in one `it`
with multiple `expect`s. Worked example:
**`agent_harness_rails/skills/writing-tests/references/model-specs.md`**
§ No Redundant Tests Within the File.

## Guidelines

- **One HTTP verb per `describe`** — `describe "POST /articles"`
- **Use path helpers** — `articles_path`, not `"/articles"`
- **`response.body.include?`** is the right tool for "does the page show X?"
- **Follow redirects when needed** — `follow_redirect!` after a redirect assertion
- **Ownership is settled in `agent_harness_rails/rules/testing.mdc` § Ownership by Layer** — auth gates always here (one authorized + one unauthorized per endpoint), non-canonical CRUD only here, domain logic and the policy matrix never here
