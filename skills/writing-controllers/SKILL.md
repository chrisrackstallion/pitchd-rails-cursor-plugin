---
name: writing-controllers
description: >-
  Write Rails controllers following DHH/37signals conventions — thin CRUD
  controllers, REST-mapped resources, morphing-first responses, concerns
  for shared behaviour, and strong parameters with params.expect. Use when
  creating new controllers, adding actions, extracting concerns, handling
  Turbo responses, or when the user mentions controllers, actions, strong
  parameters, or REST routing.
---

# Writing Rails Controllers

<objective>
Write controllers that are thin orchestrators — they receive a request,
delegate to the model, and respond. Every custom action maps to CRUD on a
new resource. Responses use the simplest Turbo mechanism that works:
morphing first, then frames, then streams. Follow DHH/37signals
conventions: REST purity, rich models, vanilla controller code, and
clarity over cleverness.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New controller | Read `references/patterns.md`, scaffold the controller |
| New action on existing controller | Read `references/patterns.md` § REST Mapping — likely needs a new resource |
| Turbo responses | See the Turbo rules — controller patterns are covered there |
| Controller concern | Read `references/patterns.md` § Concerns |
| Strong parameters | Read `references/patterns.md` § Strong Parameters |
| Authorization | Read `references/patterns.md` § Authorization |
| Error handling | Read `references/patterns.md` § Error Handling |
| Code review | Read all references, review against conventions |

### 2. Controller Structure

Organise every controller in this order:

```ruby
class ArticlesController < ApplicationController
  # 1. Concerns
  include Sortable

  # 2. Security / rate limiting
  rate_limit to: 10, within: 3.minutes, only: :create

  # 3. Callbacks
  before_action :set_article, only: %i[ show edit update destroy ]

  # 4. Public actions — in CRUD order
  def index
    @articles = Article.chronologically
  end

  def show
  end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Article updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @article.destroy!
    redirect_to articles_path, notice: "Article deleted."
  end

  private
    # 5. Resource finders
    def set_article
      @article = Article.find(params[:id])
    end

    # 6. Strong parameters
    def article_params
      params.expect(article: %i[ title body visibility ])
    end
end
```

This is the baseline. It uses `redirect_to` for every mutation.
No `respond_to`, no format negotiation, no stream templates. Stay here
as long as possible.

### 3. Decision Framework

Before writing code, ask these questions:

**"Does this need a new controller or a new action?"**
- Action outside CRUD (close, archive, publish) → new noun resource with its own controller
- Standard CRUD operation → action on existing controller
- Shared behaviour across controllers → concern

**"Where does the logic live?"**
- Single-model operation → model method, controller just calls it
- Multi-model orchestration → controller coordinates, each model does its part
- External system call → job enqueued by controller or model callback
- Query/filtering → named scope on the model

**"What response mechanism?"**
Prefer the simplest mechanism that satisfies the UX. Each step adds
controller complexity — maximise use of `redirect_to`:

1. **Morphing** — `redirect_to` after mutation. Plain controller code. Default.
2. **Turbo Frames** — scoped partial updates. Controller renders normally.
3. **Turbo Streams** — surgical multi-target DOM updates. Last resort.

See the Turbo rules for implementation detail on each level.

### 4. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Business logic in actions | Model method or domain verb |
| Custom verb actions (`close`, `archive`) | New noun resource with CRUD |
| `params.require(...).permit(...)` | `params.expect(...)` |
| Reaching for Turbo Streams first | Morphing → frames → streams (see Turbo rules) |
| Unscoped find for nested resources | Scope through parent association |
| `redirect_to` after failed validation | `render :action, status: :unprocessable_content` |
| Service object wrapping a single model call | Let the controller call the model directly |
| `rescue => e` in actions | `rescue_from` at the controller class level |
| Skipping CSRF / auth checks per-action | Dedicated controller with appropriate base class |

### 5. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Controllers | Plural noun matching resource | `ArticlesController`, `CommentsController` |
| Nested state controllers | `Parent::StateNounController` | `Cards::ClosuresController`, `Articles::PublicationsController` |
| Namespace controllers | Module wrapping | `Admin::ArticlesController` |
| Callbacks | `set_` for finders, `ensure_` for guards | `set_article`, `ensure_can_edit` |
| Params methods | `resource_params` | `article_params`, `comment_params` |
| Resource finders | `set_` + singular resource name | `set_article`, `set_comment` |
| Concerns | Adjective or `Scoped` suffix | `Searchable`, `BoardScoped`, `Sortable` |

### 6. Verification

Before finishing, verify:

- [ ] No business logic in controller actions — only orchestration
- [ ] Every action maps to one of the seven CRUD verbs (index, show, new, create, edit, update, destroy)
- [ ] Strong parameters use `params.expect`, not `params.require.permit`
- [ ] Failed validations render with `status: :unprocessable_content`, not redirect
- [ ] Nested resource lookups are scoped through parent associations
- [ ] Response uses the simplest Turbo mechanism (morphing > frames > streams)
- [ ] Authorization is checked via `before_action` or model-level guards
- [ ] Controller has no more than ~7 public methods (CRUD actions only)
- [ ] Shared behaviour is extracted to concerns, not duplicated
- [ ] Rate limiting applied to creation/mutation endpoints where appropriate

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
