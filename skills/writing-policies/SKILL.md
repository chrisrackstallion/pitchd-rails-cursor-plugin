---
name: writing-policies
description: >-
  Write Pundit authorization policies following Rails conventions — one policy
  per model, plain Ruby objects, deny-by-default, scoped collections, and
  controller integration via authorize/policy_scope. Use when creating policies,
  adding authorization, checking permissions, scoping queries by user, or when
  the user mentions policies, Pundit, authorization, permissions, or access control.
---

# Writing Pundit Policies

<objective>
Write policies that answer one question: "can this user perform this action
on this record?" Policies are plain Ruby objects — no DSL, no magic. One
policy per model, one method per controller action, deny by default. Pundit
is a thin convention layer (~300 lines) that earns its dependency by keeping
authorization in one predictable place rather than scattered across models
and controllers.
</objective>

> **Philosophy note:** DHH would keep authorization in model methods and
> controller guards. Pundit is an extra file per model, but the trade-off is
> worth it: every action is authorized, every index is scoped, and
> `verify_authorized` catches anything you miss.
> You always know where to look.

> Policies are **authorization** (who may act), not a second domain layer.
> Business rules and state transitions stay on the model; policies call model
> predicates and return `true` / `false`.

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New policy for a model | Read `references/patterns.md`, create the policy |
| Adding an action to a policy | Read `references/patterns.md` § Action Methods |
| Scoping a collection | Read `references/patterns.md` § Scopes |
| Role-based permissions | Read `references/patterns.md` § Roles |
| Nested / namespaced resource | Read `references/patterns.md` § Namespaced Policies |
| Controller integration | Read `references/patterns.md` § Controller Integration |
| Testing a policy | Read the testing skill `references/support-specs.md` § Policy Specs |
| Code review | Read all references, review against conventions |

### 2. Policy Structure

Every policy follows this shape:

```ruby
# app/policies/article_policy.rb
class ArticlePolicy < ApplicationPolicy
  # 1. Public action methods — mirror controller CRUD
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    user.admin?
  end

  # 2. Scope — filters collections for index
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(creator: user).or(scope.published)
      end
    end
  end

  # 3. Private helpers — shared permission logic
  private
    def owner_or_admin?
      record.creator == user || user.admin?
    end
end
```

### 3. Decision Framework

Before writing code, ask:

**"Which policy does this action belong on?"**
Every controller action calls `authorize` — including index. Index also calls
`policy_scope` to filter records. `after_action :verify_authorized` and
(typically) `after_action :verify_policy_scoped, only: :index` enforce this on
each request (unless customized). Use `skip_after_action` only for actions that intentionally skip
authorization or scoping — see `references/patterns.md` § Skipping Verification.
The question
is never "does this need a policy?" but "which policy?"
- All actions are RESTful CRUD — no custom action methods on policies
- Standard resource → `ArticlePolicy` with `index?`, `show?`, `create?`, `update?`, `destroy?`
- State-change noun resource (e.g., `Cards::ClosuresController`) → `Cards::ClosurePolicy` with `create?`/`destroy?`
- Never add non-CRUD methods like `close?` or `publish?` — those are verbs, and the controller convention maps them to CRUD on a noun

**"What does this method receive?"**
- Policies see `user` (whatever `pundit_user` returns — often `Current` or `Current.user`) and `record` (the model instance)
- Policies do NOT see `request`, `params`, `session`, or controller state
- If a permission depends on request context, the controller decides that
  before calling `authorize`

**"Is this authorization or business logic?"**
- "Can this user edit this article?" → authorization → policy
- "Is this article publishable?" → business logic → model method
- "Can this user publish this article?" → authorization → policy
- "What happens when an article is published?" → business logic → model

**"Should I use a scope or filter in the controller?"**
- Filtering records by what the user can see → `policy_scope` in the policy
- Filtering records by query params (search, status) → named scope on the model
- Both → `policy_scope(Article).search(params[:q])` — compose them

### 4. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Pundit policy checks in `before_action` | `authorize @record` in the action — use `before_action` for authentication and finders |
| Mirroring the full permission matrix on the model | Policy methods; keep domain predicates on the model and compose them in policies |
| Inline `current_user.admin?` in controllers | Policy encapsulates the role check |
| One giant permission method with conditionals | One method per action — `show?`, `update?`, `destroy?` |
| Forgetting `authorize` in any action (including index) | `after_action :verify_authorized` catches it |
| Forgetting `policy_scope` in index | `after_action :verify_policy_scoped, only: :index` catches it (when enabled) |
| Policy accessing `request` or `params` | Policies only see `user` and `record` |
| Business logic in policies | Policies answer "allowed?" — nothing else |
| Duplicating policy logic in views | Use `policy(@record).update?` in views |
| `unless` / negative conditionals in policy methods | Positive assertions: `user.admin?`, not `!user.banned?` (extract predicates) |
| Separate policies for new/edit that differ from create/update | `new?` delegates to `create?`, `edit?` delegates to `update?` |
| Custom verb methods (`close?`, `publish?`, `archive?`) | CRUD methods only — state changes map to `create?`/`destroy?` on a noun-resource policy |
| Policy returning data or performing side effects | Return `true` / `false` only |

### 5. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Policy class | Model name + `Policy` | `ArticlePolicy`, `CommentPolicy` |
| Policy file | `app/policies/model_policy.rb` | `app/policies/article_policy.rb` |
| Action methods | CRUD action + `?` | `show?`, `create?`, `update?`, `destroy?` — no custom verbs |
| State-change policy | Noun-resource namespace | `Cards::ClosurePolicy`, `Articles::PublicationPolicy` |
| Scope class | Nested `Scope` inside the policy | `ArticlePolicy::Scope` |
| Base policy | `ApplicationPolicy` | `app/policies/application_policy.rb` |
| Namespaced policies | Match controller namespace | `Admin::ArticlePolicy` |
| Private helpers | Descriptive predicate | `owner_or_admin?`, `member_of_team?` |

### 6. Verification

Before finishing, verify:

- [ ] Every controller action calls `authorize` — including index
- [ ] Index actions use `policy_scope` to filter records, then `authorize` (typically `authorize Model`)
- [ ] `after_action :verify_authorized` is in `ApplicationController`; `skip_after_action` only where intentional
- [ ] `after_action :verify_policy_scoped, only: :index` when you want to catch forgotten `policy_scope` (recommended)
- [ ] Policy defaults to deny (inherits from `ApplicationPolicy` which returns `false`)
- [ ] `new?` delegates to `create?`, `edit?` delegates to `update?`
- [ ] Policy only receives `user` and `record` — no controller state leaks in
- [ ] Policy methods return `true`/`false` only — no side effects
- [ ] Scope's `resolve` returns an `ActiveRecord::Relation`, not an array
- [ ] Views use `policy(@record).action?` for conditional display
- [ ] Policy spec exists with tests for each role × action combination — `Policy.new`’s first argument matches `pundit_user` (`User` vs `Current`; see testing skill `support-specs` § When `pundit_user` is `Current`)
- [ ] No full permission matrix duplicated in models or in controller `before_action` callbacks

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
