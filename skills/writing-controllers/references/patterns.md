# Controller Patterns Reference

## REST Mapping

Every controller action maps to one of the seven CRUD verbs. When you need
a custom action, create a new resource instead.

### The Rule

If the action name is not `index`, `show`, `new`, `create`, `edit`,
`update`, or `destroy`, you need a new controller.

### Mapping Custom Actions to Resources

```ruby
# Instead of verb actions on the parent...
# POST   /cards/:id/close     → custom action
# DELETE /cards/:id/close     → custom action
# POST   /cards/:id/archive   → custom action

# ...create noun resources:
# POST   /cards/:id/closure   → Cards::ClosuresController#create
# DELETE /cards/:id/closure   → Cards::ClosuresController#destroy
# POST   /cards/:id/archival  → Cards::ArchivalsController#create

resources :cards do
  resource :closure, only: %i[ create destroy ]
  resource :archival, only: %i[ create ]
  resources :assignments, only: %i[ create destroy ]
end
```

### State-Change Controllers

These controllers typically have only `create` (to apply the state) and
optionally `destroy` (to reverse it). They are tiny — the domain verb
lives on the model:

```ruby
module Cards
  class ClosuresController < ApplicationController
    before_action :set_card

    def create
      authorize @card, policy_class: Cards::ClosurePolicy
      @card.close(by: Current.user)
      redirect_to @card
    end

    def destroy
      authorize @card, policy_class: Cards::ClosurePolicy
      @card.reopen
      redirect_to @card
    end

    private
      def set_card
        @card = Card.find(params[:card_id])
      end
  end
end
```

### Singular vs Plural Resources

```ruby
# Singular — one per parent (a card has one closure)
resource :closure, only: %i[ create destroy ]

# Plural — many per parent (a card has many assignments)
resources :assignments, only: %i[ create destroy ]
```

Use `resource` (singular) when the child is a 1:1 relationship with the
parent. Use `resources` (plural) for 1:many.

---

## Strong Parameters

### params.expect (Rails 8+)

`params.expect` is the preferred way to extract and permit parameters. It
replaces `params.require(:key).permit(...)` — more concise, raises on
missing keys, and reads as a declaration.

### Basic Usage

```ruby
def article_params
  params.expect(article: %i[ title body visibility ])
end
```

### Nested Attributes

Double-bracket syntax `[[ ]]` declares "an array of hashes with these
keys":

```ruby
def article_params
  params.expect(article: [
    :title, :body,
    tags_attributes: [[ :id, :name, :_destroy ]]
  ])
end
```

### Deep Nesting

```ruby
def person_params
  params.expect(person: [
    :name,
    emails: [],
    friends: [[
      :name,
      family: [:name],
      hobbies: []
    ]]
  ])
end
```

### Multiple Top-Level Keys

```ruby
name, emails = params.expect(:name, emails: [])
```

### File Uploads

```ruby
def avatar_params
  params.expect(user: [:avatar])
end
```

### Guidelines

- Always use `params.expect` over `params.require.permit`
- Keep params methods private and named `resource_params`
- One params method per resource type
- Never permit `:id` for creation — only for nested `_attributes`

---

## Response Hierarchy

Prefer the simplest mechanism that satisfies the UX. Each step adds
controller complexity — maximise use of `redirect_to`:

1. **Morphing** — `redirect_to` after mutation. Plain controller code. Default.
2. **Turbo Frames** — scoped partial updates. Controller renders normally.
3. **Turbo Streams** — surgical multi-target DOM updates. Last resort.

See the Turbo rules for implementation detail on each level.

### Failed Validations

Never redirect after a failed save — re-render the form with errors:

```ruby
def create
  @article = Article.new(article_params)
  if @article.save
    redirect_to @article, notice: "Article created."
  else
    render :new, status: :unprocessable_content
  end
end
```

`status: :unprocessable_content` (422) tells Turbo the submission failed
and prevents navigation advancement.

---

## Concerns

Controller concerns extract shared behaviour into reusable modules.

### Structure

```ruby
# app/controllers/concerns/board_scoped.rb
module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
  end

  private
    def set_board
      @board = Board.find(params[:board_id])
    end
end
```

### Common Concern Types

| Type | Purpose | Example |
|------|---------|---------|
| Resource scoping | Load parent resource for nested controllers | `BoardScoped`, `AccountScoped` |
| Request context | Populate `Current` attributes from request | `SetCurrentRequest`, `SetTimezone` |
| Response helpers | Shared rendering patterns | `FlashStreams`, `Sortable` |
| Authentication / session | Ensure user is signed in — not Pundit | `Authentication`, session setup |
| Platform detection | Mobile/desktop branching | `DetectPlatform` |

### Guidelines

- Name concerns as adjectives (`Searchable`, `Sortable`) or with a
  `Scoped` suffix (`BoardScoped`, `AccountScoped`)
- Keep concerns under 100 lines
- `included do` block for `before_action`, `helper_method`, `layout`
- Private methods for the implementation
- One concern, one responsibility

### When to Extract

Extract when:
- Two or more controllers share identical `before_action` + private
  methods
- A nested controller family all need the same parent resource loading
- Response formatting logic is duplicated across controllers

Don't extract when:
- The code is used by one controller only
- You're just hiding code to make the controller "look smaller"

---

## Authentication (Rails 8+)

Rails 8 ships a built-in authentication generator (`bin/rails generate
authentication`) that creates `User`, `Session`, and `Current` models
plus an `Authentication` concern. The default posture is: all controllers
require authentication, specific controllers opt out explicitly.

### Default Pattern

```ruby
class ApplicationController < ActionController::Base
  include Authentication
end
```

All controllers inheriting from `ApplicationController` now require a
logged-in user. To open specific controllers to unauthenticated visitors:

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `allow_unauthenticated_access` | Opt a controller out of the default auth requirement |
| `start_new_session_for(user)` | Create a new session after successful login |
| `terminate_session` | End the current session (logout) |
| `resume_session` | Called automatically by `require_authentication` |
| `Current.user` | The authenticated user for the current request |

---

## Current Attributes

`Current` is a singleton that carries request-scoped state. The controller
is where `Current` gets populated — typically via `Authentication` or a
custom concern.

### Structure

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent
  attribute :ip_address

  def user
    session&.user
  end
end
```

### Populating from the Controller

The `Authentication` concern sets `Current.session` automatically. For
additional attributes, use a concern:

```ruby
# app/controllers/concerns/set_current_request.rb
module SetCurrentRequest
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  private
    def set_current_request_details
      Current.user_agent = request.user_agent
      Current.ip_address = request.remote_ip
    end
end
```

### Usage in Models

Models reference `Current` for defaults and attribution:

```ruby
belongs_to :creator, class_name: "User", default: -> { Current.user }
```

---

## Authorization with Pundit

### Philosophy

Authorization logic lives in policy objects — one per model, one method
per action. The controller calls `authorize`, the policy decides. This
replaces Pundit policy checks in `before_action` and duplicating the full
permission matrix on the model. Domain predicates (`published?`, `owned_by?(user)`)
stay on the model; policies compose them.

### Controller Integration

```ruby
class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = policy_scope(Article).chronologically
    authorize Article
  end

  def show
    authorize @article
  end

  def create
    @article = Article.new(article_params)
    authorize @article

    if @article.save
      redirect_to @article
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @article

    if @article.update(article_params)
      redirect_to @article
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @article
    @article.destroy!
    redirect_to articles_path
  end

  private
    def set_article
      @article = Article.find(params[:id])
    end

    def article_params
      params.expect(article: %i[title body visibility])
    end
end
```

### State-Change Controllers (Noun Resources)

State changes are modelled as CRUD on noun resources. The policy mirrors
this — a `Cards::ClosurePolicy` with standard `create?`/`destroy?`. See
the ClosuresController example above in "Mapping Custom Actions to
Resources" for the full implementation with `before_action :set_card` and
`authorize`. See the policies skill for the `Cards::ClosurePolicy` pattern.

### ApplicationController Setup

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private
    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_back_or_to(root_path)
    end
end
```

`verify_authorized` catches actions that never called `authorize`.
`verify_policy_scoped` catches index actions that never called `policy_scope`.
Use `skip_after_action` only for actions that intentionally skip authorization
or scoping (public pages, health checks). See the policies skill § Skipping
Verification.

### Skipping Verification

For actions that genuinely don't need authorization:

```ruby
class PagesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def home
  end
end
```

See the policies skill for full policy patterns, scopes, roles, and
namespaced policies.

---

## Error Handling

### Conditional Save for Form Flows (Default)

Use the non-bang form when re-rendering a form with errors is the expected
path. This is the standard pattern for user-facing CRUD:

```ruby
def create
  @article = Article.new(article_params)
  if @article.save
    redirect_to @article
  else
    render :new, status: :unprocessable_content
  end
end

def update
  if @article.update(article_params)
    redirect_to @article
  else
    render :edit, status: :unprocessable_content
  end
end
```

### Bang Methods for Fail-Fast

Use bang ActiveRecord methods (`create!`, `update!`, `destroy!`) when
failure is exceptional — state-change controllers, non-form actions, or
anywhere validation failure is not part of the normal user flow:

```ruby
def create
  @card.close(by: Current.user)
  redirect_to @card
end

def destroy
  @article.destroy!
  redirect_to articles_path
end
```

### rescue_from at the Class Level

Handle exceptions declaratively, not with `begin/rescue` in actions:

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordNotDestroyed, with: :not_destroyed

  private
    def not_found
      render file: Rails.public_path.join("404.html"),
             status: :not_found, layout: false
    end

    def not_destroyed
      flash[:alert] = "The record could not be deleted."
      redirect_back_or_to(root_path)
    end
end
```

Avoid a generic `rescue_from ActiveRecord::RecordInvalid` handler for
form flows — it cannot know whether to render `:new` or `:edit`. Use the
conditional save pattern instead. Reserve `rescue_from RecordInvalid` for
non-form contexts (state transitions, background processing) where a
generic error page is acceptable.

---

## Rate Limiting

Rails 8+ provides built-in rate limiting. Apply it to endpoints that
accept external input or trigger expensive operations.

### Basic Usage

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
end
```

### Custom Response

```ruby
class RegistrationsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_registration_path, alert: "Try again later." }
end
```

### Where to Apply

| Endpoint | Why |
|----------|-----|
| Login / session creation | Prevent brute-force |
| Registration / sign-up | Prevent spam |
| Password reset requests | Prevent email flooding |
| Email / notification sending | Prevent abuse |
| File uploads | Prevent storage abuse |

---

## HTTP Caching

Use conditional GET / ETags to skip rendering when content hasn't changed.

### fresh_when

```ruby
def show
  @article = Article.find(params[:id])
  fresh_when @article
end

def index
  @articles = policy_scope(Article).chronologically
  authorize Article
  fresh_when etag: @articles
end
```

When times are rendered server-side in the user's timezone, include the
timezone in the ETag:

```ruby
fresh_when etag: [@article, Current.user&.timezone]
```

### Global ETag Seed

Bump to invalidate all HTTP caches after a deploy:

```ruby
class ApplicationController < ActionController::Base
  etag { "v1" }
end
```

---

## Base Controllers & Inheritance

### Typical Hierarchy

```
ApplicationController                   # global config, auth, flash types, layout
├── Admin::BaseController               # admin layout, admin-only guard
│   ├── Admin::UsersController
│   └── Admin::ArticlesController
├── SessionsController                  # allow_unauthenticated_access
├── RegistrationsController             # allow_unauthenticated_access
└── PagesController                     # allow_unauthenticated_access
```

### When to Use a Base Controller

- A namespace needs a shared layout, `before_action`, or helper methods
- All controllers in the namespace need the same parent resource loaded
- Authorization context differs from the global default

### Guidelines

- Keep base controllers minimal — layout, shared finders, auth guards
- Don't put actions on base controllers — they are abstract
- Use `helper_method` to expose parent resources to views

```ruby
module Admin
  class BaseController < ApplicationController
    layout "admin"

    # Each admin controller action calls authorize [:admin, @record],
    # which resolves to Admin::ModelPolicy — these policies check user.admin?
    # No need for a blanket before_action guard; Pundit handles it per-action.
  end
end
```

---

## Browser Requirements

Rails 8+ provides `allow_browser` to enforce minimum browser versions:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
end
```

For granular control:

```ruby
allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
```

Override the blocked response:

```ruby
allow_browser versions: :modern, block: :render_unsupported_browser

private
  def render_unsupported_browser
    render "errors/not_acceptable", layout: false, status: :not_acceptable
  end
```

---

## Streaming & File Downloads

### send_data / send_file

```ruby
def show
  send_data @report.to_csv,
    filename: "report-#{Date.current}.csv",
    type: "text/csv"
end
```

### Streaming Bodies

For large responses, stream to avoid buffering:

```ruby
class ReportsController < ApplicationController
  include ActionController::Live

  def show
    response.headers["Content-Type"] = "text/csv"
    response.headers["Content-Disposition"] = "attachment; filename=report.csv"

    @records.find_each do |record|
      response.stream.write record.to_csv_row
    end
  ensure
    response.stream.close
  end
end
```

