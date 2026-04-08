# Policy Patterns Reference

## ApplicationPolicy

The base policy defines defaults and the Scope base class. All policies
inherit from it. The default is **deny everything** — each policy explicitly
opens what it allows.

### Structure

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Default: deny all actions
  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class} must implement #resolve"
    end

    private
      attr_reader :user, :scope
  end
end
```

### Guidelines

- `new?` always delegates to `create?`, `edit?` always delegates to `update?`
  — override only when the form page itself has different access from the
  submission (rare)
- Keep the base policy minimal — no role-checking helpers here unless
  every policy needs them
- The `Scope` base class raises `NotImplementedError` to catch missing
  implementations early

---

## Action Methods

Each public method on a policy corresponds to a controller action. The
method receives `user` (from `pundit_user` — often `Current` or `Current.user`) and
`record` (the model instance passed to `authorize`).

### `pundit_user` shape: `User` vs `Current`

Most examples below treat `user` as a **`User`** (or `nil`) — that matches
`pundit_user` → `Current.user`. If **`pundit_user` → `Current`** (multi-tenant),
the policy’s `user` is **`Current`**, not a `User`. Do not copy comparisons
verbatim: use **`user.user`** for the signed-in `User`, **`user.account`** for
tenant, etc. For membership and role checks, either call **`user.user.admin?`**
(and similar) or **delegate** `admin?` / `member?` on `Current` to the underlying
user so `user.admin?` stays readable — otherwise `user.admin?` resolves to
**`Current#admin?`**, not `User#admin?`.

### Standard CRUD

```ruby
class ArticlePolicy < ApplicationPolicy
  def index?
    true  # Anyone can see the list (scope filters what they see)
  end

  def show?
    true  # Anyone can view a single article
  end

  def create?
    user.present?  # Must be logged in
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    user.admin?  # Only admins can delete
  end

  private
    def owner_or_admin?
      record.creator == user || user.admin?
    end
end
```

### State-Change Controllers (Noun Resources)

Every action is RESTful. State changes like closing a card are modelled
as CRUD on a noun resource (`Cards::ClosuresController`), not custom
actions on the parent. The policy mirrors this — a `Cards::ClosurePolicy`
with standard `create?`/`destroy?`, not custom methods on `CardPolicy`.

```ruby
# app/policies/cards/closure_policy.rb
module Cards
  class ClosurePolicy < ApplicationPolicy
    def create?
      owner_or_team_member?
    end

    def destroy?
      owner_or_team_member?
    end

    private
      def owner_or_team_member?
        record.creator == user || record.board.members.include?(user)
      end
  end
end
```

In the controller, `authorize` resolves to the namespaced policy
automatically:

```ruby
module Cards
  class ClosuresController < ApplicationController
    def create
      @card = Card.find(params[:card_id])
      authorize @card, policy_class: Cards::ClosurePolicy

      @card.close(by: Current.user)
      redirect_to @card
    end

    def destroy
      @card = Card.find(params[:card_id])
      authorize @card, policy_class: Cards::ClosurePolicy

      @card.reopen
      redirect_to @card
    end
  end
end
```

Alternatively, if the closure is its own model (state-as-record pattern),
authorize the closure record directly:

```ruby
module Cards
  class ClosuresController < ApplicationController
    def create
      @card = Card.find(params[:card_id])
      @closure = @card.build_closure(creator: Current.user)
      authorize @closure

      @card.close(by: Current.user)
      redirect_to @card
    end
  end
end
```

### Headless Policies (No Record)

For actions that don't operate on a specific record (dashboards, global
settings), authorize against the class:

```ruby
class DashboardPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end

# Controller
class DashboardController < ApplicationController
  def show
    authorize :dashboard, :show?
    # ...
  end
end
```

Or use a namespaced symbol when there is no AR record:

```ruby
# When you need to pass context but there's no AR record
authorize [:admin, :dashboard], :show?
```

Pundit must resolve a concrete policy class (e.g. `DashboardPolicy`,
`Admin::DashboardPolicy`) — prefer predictable naming; if resolution is
ambiguous, pass `policy_class:` explicitly.

---

## Scopes

Scopes filter collections based on what the user is allowed to see. Every
policy that supports `index?` should have a `Scope`.

### Basic Scope

```ruby
class ArticlePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.published.or(scope.where(creator: user))
      end
    end
  end
end
```

### Usage in Controllers

```ruby
def index
  @articles = policy_scope(Article).chronologically
  authorize Article
end
```

You may use `authorize @articles` instead — Pundit passes the relation as
`record` to `index?`. Prefer `authorize Article` when `index?` only needs
the model class (common; matches Pundit examples).

`policy_scope` resolves `ArticlePolicy::Scope` with **`pundit_user`** (often
`Current` or `Current.user`) and the model class, then calls `#resolve` — it
returns an `ActiveRecord::Relation`, fully chainable with scopes. The scope’s
`user` is the same object Pundit passes to policies.

### Nested Resource Scopes

Scope through the parent association, then apply policy scope:

```ruby
def index
  @board = Board.find(params[:board_id])
  @cards = policy_scope(@board.cards).chronologically
  authorize Card
end
```

If `index?` must inspect the scoped relation (uncommon), use `authorize @cards`
so `record` is the relation.

### Guidelines

- `resolve` must return an `ActiveRecord::Relation`, never an `Array`
- **`Scope` receives the same `user` as policies** — your `pundit_user` object.
  When it is `Current`, use `user.user` (or helpers)   anywhere the scope compares
  to a `User` or calls user predicates that live on `User`.
- Scopes compose with named scopes: `policy_scope(Article).published.search(q)`
- Don't duplicate scope logic in the controller — the policy scope is the
  single source of "what can this user see?"
- Admin users typically see `scope.all`; regular users see their own
  records plus publicly visible ones

---

## Roles

Keep role logic simple. Prefer model predicates (`user.admin?`) over
passing role strings around.

### Role Predicates on User

```ruby
class User < ApplicationRecord
  enum :role, { member: "member", admin: "admin", moderator: "moderator" },
       default: :member

  # Enum gives you: user.admin?, user.member?, user.moderator?
end
```

### Role-Based Policy

```ruby
class CommentPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def update?
    author? || moderator_or_admin?
  end

  def destroy?
    author? || moderator_or_admin?
  end

  private
    def author?
      record.author == user
    end

    def moderator_or_admin?
      user.admin? || user.moderator?
    end
end
```

### Team/Account-Scoped Permissions

For multi-tenant apps where permissions are scoped to an account or team, use
`pundit_user` → `Current` (see § Pundit User). The policy’s `user` is then
`Current`; the member record is `user.user` (naming is Pundit’s `attr_reader :user`).

```ruby
class ProjectPolicy < ApplicationPolicy
  def show?
    member_of_account?
  end

  def update?
    member_of_account? && (record.creator == user.user || user_is_account_admin?)
  end

  private
    def member_of_account?
      record.account.memberships.exists?(user: user.user)
    end

    def user_is_account_admin?
      record.account.memberships.find_by(user: user.user)&.admin?
    end
end
```

### Guidelines

- Keep role checks as model predicates: `user.admin?`, not `user.role == "admin"`
- Extract shared permission helpers to private methods on the policy
- Don't put role helpers on `ApplicationPolicy` unless every policy needs them
- For complex role hierarchies, consider a `Membership` model with a `role`
  column rather than a role on the `User`

---

## Controller Integration

### Basic Pattern

Call `authorize` in every action — including `index`. Use `policy_scope` in
`index` to filter records, then `authorize` (typically `authorize Article`
after scoping; see § Scopes).

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = policy_scope(Article).chronologically
    authorize Article
  end

  def show
    @article = Article.find(params[:id])
    authorize @article
  end

  def new
    @article = Article.new
    authorize @article
  end

  def create
    @article = Article.new(article_params)
    authorize @article

    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @article = Article.find(params[:id])
    authorize @article
  end

  def update
    @article = Article.find(params[:id])
    authorize @article

    if @article.update(article_params)
      redirect_to @article, notice: "Article updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @article = Article.find(params[:id])
    authorize @article
    @article.destroy!
    redirect_to articles_path, notice: "Article deleted."
  end

  private
    def article_params
      params.expect(article: %i[title body visibility])
    end
end
```

### With before_action Finders

You can still use `before_action` for finding records — just call
`authorize` in the action body, not in the callback:

```ruby
class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def show
    authorize @article
  end

  def update
    authorize @article

    if @article.update(article_params)
      redirect_to @article
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_article
      @article = Article.find(params[:id])
    end
end
```

### Verification Callbacks

Add these to `ApplicationController` to catch missed authorizations:

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

`verify_authorized` raises if the action didn't call `authorize`.
`verify_policy_scoped` with `only: :index` raises if **`index`** didn't call
`policy_scope`. It does **not** cover other actions that call `policy_scope`
— widen `only:` / `except:` or add `skip_after_action` where needed.

Default is to run both; use `skip_after_action` only for actions that
intentionally have no authorization or no scoped index (public pages, health
checks, unscoped feeds you have explicitly decided are OK).

### Skipping Verification

For actions that genuinely don't need authorization (public pages, health
checks), skip explicitly:

```ruby
class PagesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def home
  end
end
```

Or on specific actions:

```ruby
class ArticlesController < ApplicationController
  skip_after_action :verify_authorized, only: :feed
  skip_after_action :verify_policy_scoped, only: :feed

  def feed
    @articles = Article.published.latest
  end
end
```

---

## Namespaced Policies

### Admin Namespace

When admin controllers need different permissions:

```ruby
# app/policies/admin/article_policy.rb
module Admin
  class ArticlePolicy < ApplicationPolicy
    def index?
      user.admin?
    end

    def destroy?
      user.admin?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.all  # Admins see everything
      end
    end
  end
end
```

Pundit resolves the policy based on the controller namespace:

```ruby
module Admin
  class ArticlesController < ApplicationController
    def index
      @articles = policy_scope([:admin, Article])
      authorize [:admin, Article]
    end

    def destroy
      @article = Article.find(params[:id])
      authorize [:admin, @article]
      @article.destroy!
      redirect_to admin_articles_path
    end
  end
end
```

### Guidelines

- Namespace policies to match controller namespaces
- Use `authorize [:namespace, @record]` to resolve the namespaced policy
- `policy_scope([:namespace, Model])` resolves the namespaced scope
- Keep namespaced policies focused — they don't need to duplicate the
  base policy; inherit from it if the base permissions apply

---

## View Integration

Use `policy` helper in views to conditionally show UI elements:

```ruby
<% if policy(@article).update? %>
  <%= link_to "Edit", edit_article_path(@article) %>
<% end %>

<% if policy(@article).destroy? %>
  <%= button_to "Delete", @article, method: :delete %>
<% end %>
```

### Guidelines

- Always gate UI elements behind policy checks — don't show buttons the
  user can't use
- The policy is the single source of truth — don't duplicate permission
  logic in view conditionals
- Use `policy(Model).create?` for "New" links: `policy(Article).create?`
- Views call policy methods but never bypass them — if the button is
  hidden but the endpoint isn't authorized, that's a security bug

---

## Pundit User

By default, Pundit calls `current_user`. Override `pundit_user` when your auth
stack exposes the signed-in user differently:

```ruby
class ApplicationController < ActionController::Base
  def pundit_user
    Current.user
  end
end
```

### Multi-tenant apps

Use **`Current`** as `pundit_user` — do not introduce a separate `Data.define`
or struct for “context.” Tenant, session, and user already live on `Current`;
policies read the same attributes as controllers and models.

```ruby
class ApplicationController < ActionController::Base
  def pundit_user
    Current
  end
end
```

Pundit passes this object as the policy’s first argument; `ApplicationPolicy`
still exposes it as `user`, so you write `user.account`, `user.user` (the
`User` record), and other attributes your `Current` defines. Add a helper on
`ApplicationPolicy` (e.g. `def current_user = user.user`) if you want to avoid
repeating `user.user`.

**Predicates:** If you rely on `user.admin?` in policies, either implement
`Current#admin?` (delegating to `user.admin?`) or call **`user.user.admin?`**
so you do not accidentally define admin logic only on `User` while `user` is
`Current`.

### Extra context for some policies only

When only certain areas need another record on top of what `Current` already
carries, use a **thin wrapper** that exposes that extra attribute and
**delegates the rest to `Current`** — for example a `CurrentProject` with a
`project` reader and methods like `user` / `account` forwarded to `Current`.
**Override `pundit_user` only in controllers whose policies need that extra
context** — other controllers still use plain `Current`, so policies must not
assume `project` exists unless this controller passed a wrapper.

```ruby
class CurrentProject
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def user
    Current.user
  end

  def account
    Current.account
  end
end

# e.g. Projects::TasksController — after `before_action :set_project`
def pundit_user
  CurrentProject.new(@project)
end
```

---

## Error Handling

### Rescue Globally

Handle `Pundit::NotAuthorizedError` once in `ApplicationController`:

```ruby
rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

private
  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = I18n.t("pundit.#{policy_name}.#{exception.query}",
                           default: "You are not authorized to perform this action.")
    redirect_back_or_to(root_path)
  end
```

### I18n for Policy Messages

```yaml
# config/locales/pundit.en.yml
en:
  pundit:
    article_policy:
      update?: "You can only edit your own articles."
      destroy?: "Only administrators can delete articles."
```

### Guidelines

- Never rescue `Pundit::NotAuthorizedError` in individual controllers —
  handle it once in the base controller
- Use I18n for user-facing messages — keeps policies free of display concerns
- Log authorization failures for security auditing
- HTML responses: redirect (or render) from `user_not_authorized` as above
