# Request Specs Reference

Request specs test the HTTP layer — status codes, redirects, response
bodies, authentication, and authorization. They replace controller specs
(which are deprecated) and complement system specs by testing things
browsers can't easily verify.

## Structure

```ruby
# spec/requests/articles_spec.rb
RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    it "returns a successful response" do
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

Or set the session directly for speed:

```ruby
module AuthenticationHelper
  def sign_in(user)
    session = user.sessions.create!
    # Set the cookie that Authentication concern expects
    cookies[:session_id] = session.id
  end
end
```

---

## CRUD Resource Specs

### Full CRUD Pattern (API-Only or Without System Specs)

Use this pattern for **API-only resources** or resources that don't have
system specs. For server-rendered resources with system specs, you typically
do NOT need a full CRUD request spec — write request specs only for
HTTP-layer concerns not covered by system specs (auth gates, status codes,
rate limits). See "Boundaries" below.

```ruby
RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    it "lists articles" do
      sign_in create(:user)
      create_list(:article, 3)

      get articles_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /articles/:id" do
    it "shows the article" do
      sign_in create(:user)
      article = create(:article)

      get article_path(article)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /articles" do
    it "creates and redirects" do
      sign_in create(:user)

      post articles_path, params: { article: { title: "Hello", body: "World" } }

      expect(response).to redirect_to(article_path(Article.last))
    end

    it "returns 422 with invalid params" do
      sign_in create(:user)

      post articles_path, params: { article: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /articles/:id" do
    it "updates and redirects" do
      sign_in create(:user)
      article = create(:article)

      patch article_path(article), params: { article: { title: "Updated" } }

      expect(response).to redirect_to(article_path(article))
    end
  end

  describe "DELETE /articles/:id" do
    it "destroys and redirects to index" do
      sign_in create(:user)
      article = create(:article)

      delete article_path(article)

      expect(response).to redirect_to(articles_path)
    end
  end
end
```

---

## Authentication and Authorization

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

### Authorization

```ruby
describe "DELETE /articles/:id" do
  it "returns 403 for non-owners" do
    article = create(:article)
    other_user = create(:user)
    sign_in other_user

    delete article_path(article)

    expect(response).to have_http_status(:forbidden)
  end

  it "succeeds for the article owner" do
    article = create(:article, author: user)
    sign_in user

    delete article_path(article)

    expect(response).to redirect_to(articles_path)
  end
end
```

### Admin-Only Endpoints

```ruby
RSpec.describe "Admin::Users", type: :request do
  describe "GET /admin/users" do
    it "returns 403 for non-admins" do
      sign_in create(:user)

      get admin_users_path

      expect(response).to have_http_status(:forbidden)
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
    it "redirects to the card" do
      user = create(:user)
      sign_in user
      card = create(:card)

      post card_closure_path(card)

      expect(response).to redirect_to(card_path(card))
      # Don't assert card.reload.closed? — the model spec owns that.
      # This spec proves the endpoint returns the right HTTP response.
    end
  end

  describe "DELETE /cards/:card_id/closure" do
    it "redirects to the card" do
      user = create(:user)
      sign_in user
      card = create(:card, :closed)

      delete card_closure_path(card)

      expect(response).to redirect_to(card_path(card))
    end
  end
end
```

---

## JSON API Endpoints

For APIs that return JSON:

```ruby
RSpec.describe "API Articles", type: :request do
  describe "GET /api/articles" do
    it "returns articles as JSON" do
      create_list(:article, 3, :published)

      get api_articles_path, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")

      json = response.parsed_body
      expect(json.length).to eq(3)
      expect(json.first).to include("title", "body", "created_at")
    end
  end

  describe "POST /api/articles" do
    it "creates and returns the article" do
      sign_in create(:user)

      post api_articles_path,
        params: { article: { title: "API Article", body: "Content" } },
        as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["title"]).to eq("API Article")
    end

    it "returns validation errors" do
      sign_in create(:user)

      post api_articles_path,
        params: { article: { title: "" } },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("title")
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

```ruby
describe "POST /sessions" do
  it "rate limits after 10 attempts" do
    11.times do
      post session_path, params: { email_address: "test@example.com", password: "wrong" }
    end

    expect(response).to have_http_status(:too_many_requests)
  end
end
```

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

When you need to check content (prefer system specs for this, but
sometimes request specs are simpler):

```ruby
describe "GET /articles/:id" do
  it "includes the article title" do
    article = create(:article, title: "Testing Guide")

    get article_path(article)

    expect(response.body).to include("Testing Guide")
  end
end
```

---

## Boundaries — What Belongs Here vs. Elsewhere

Request specs own the HTTP layer. They do not duplicate system spec flows
or re-test model domain logic.

### What Request Specs Own

- Status codes: 200, 201, 302, 401, 403, 422, 429
- Redirects: where the user is sent after mutations
- Auth gates: unauthenticated → redirect to login, unauthorized → 403
- Rate limiting: 429 after exceeding limits
- API JSON shape: correct keys, correct types in response body
- CSRF and security headers
- Turbo Stream content type for Turbo requests

### What Request Specs Do NOT Test

- That a user can fill in a form and see the created record — system spec
- That `article.publish` creates a publication — model spec
- That the page renders the right HTML content — system spec
- That a job does its work — job spec

### Auth Is Always Tested Here

Authentication and authorization are critical enough to **always** test at
the HTTP layer, even when system specs exist for the happy path. A system
spec that signs in and creates an article doesn't prove that an
unauthenticated request gets a 302, or that a non-owner gets a 403. Those
are request spec concerns.

```ruby
# Always write these, regardless of system spec coverage
describe "POST /articles" do
  it "requires authentication" do
    post articles_path, params: { article: { title: "New" } }
    expect(response).to redirect_to(new_session_path)
  end
end

describe "DELETE /articles/:id" do
  it "returns 403 for non-owners" do
    sign_in create(:user)
    article = create(:article) # owned by a different user

    delete article_path(article)

    expect(response).to have_http_status(:forbidden)
  end
end
```

### When NOT to Write a Request Spec

If a system spec already covers the flow (user fills form, clicks save,
sees the result), don't write a request spec that posts the same params
and checks the same record exists. A request spec earns its place only
when it tests something the system spec cannot:

```ruby
# Unnecessary — the system spec already covers article creation
describe "POST /articles" do
  it "creates an article" do
    post articles_path, params: { article: { title: "New", body: "Content" } }
    expect(Article.count).to eq(1)  # System spec already proves this
  end
end

# Valuable — tests an HTTP concern the system spec can't
describe "POST /articles" do
  it "returns 422 with missing params" do
    post articles_path, params: { article: { title: "" } }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "requires authentication" do
    post articles_path, params: { article: { title: "New" } }
    expect(response).to redirect_to(new_session_path)
  end
end
```

### No Redundant Tests Within the File

Don't test the same endpoint twice with different wording for the same
concern:

```ruby
# Bad — two tests for one concern
it "redirects to the article" do
  post articles_path, params: { article: valid_params }
  expect(response).to redirect_to(article_path(Article.last))
end

it "creates the article record" do
  post articles_path, params: { article: valid_params }
  expect(Article.count).to eq(1)
end

# Good — one test for the success path
it "creates an article and redirects" do
  post articles_path, params: { article: valid_params }

  expect(response).to redirect_to(article_path(Article.last))
  expect(Article.count).to eq(1)
end
```

## Guidelines

- **One HTTP verb per `describe`** — `describe "POST /articles"`
- **Use path helpers** — `articles_path`, not `"/articles"`
- **Test status codes and redirects** — not response body content (save that for system specs)
- **Test auth at every endpoint** — unauthenticated, unauthorized, authorized
- **Follow redirects when needed** — `follow_redirect!` after a redirect assertion
- **Use `as: :json`** for JSON API tests — sets content type and parses response
- **Don't test view rendering** — that's what system specs are for
- **Keep request specs focused on HTTP concerns** — the model spec tests the domain logic
- **Don't duplicate system spec flows** — if the system spec proves the feature works, the request spec only adds HTTP-layer assertions
- **Don't re-test domain logic** — `article.publish` is the model spec's job; the request spec tests the endpoint
