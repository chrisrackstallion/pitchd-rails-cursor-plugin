# Routes Patterns Reference

Worked mechanics for the conventions in
**`agent_harness_rails/rules/routes.mdc`**.

## REST Resources

```ruby
# Full resource — all seven actions exist in the UI
resources :articles

# Trimmed — no edit/delete UI, so those routes don't exist
resources :articles, only: %i[ index show new create ]
```

HTTP verbs and routes align with Rails conventions:

| Verb   | Action   | Path               |
|--------|----------|--------------------|
| GET    | index    | /articles          |
| GET    | show     | /articles/:id      |
| GET    | new      | /articles/new      |
| POST   | create   | /articles          |
| GET    | edit     | /articles/:id/edit |
| PATCH/PUT | update | /articles/:id   |
| DELETE | destroy  | /articles/:id      |

Plural resource name in the path; controller name follows (`ArticlesController`).

---

## Singleton `resource`

Use `resource` (singular) when there is exactly one per scope — e.g. `resource :profile` under the current user, `resource :account`, or `resource :session` for sign-in/out.

```ruby
resource :session, only: %i[ new create destroy ]
```

Singular routes do not take `:id` in the path. Helpers are named accordingly (`new_session_path`, not `session_path` for new — check `rails routes` for exact names).

---

## Shallow Nesting

Nest while the parent identifies the collection (`index`, `new`, `create`). Use `shallow: true` so `show`, `edit`, `update`, and `destroy` live at `/child/:id` without repeating the parent prefix.

```ruby
resources :projects do
  resources :tasks, shallow: true
end
```

Typical outcome:

- `GET /projects/:project_id/tasks` — index (nested)
- `POST /projects/:project_id/tasks` — create (nested)
- `GET /tasks/:id` — show (shallow)
- `PATCH /tasks/:id` — update (shallow)

Match finders to each action's depth: nested `index`/`create` receive
`params[:project_id]` (scope through the parent —
`@project.tasks.find(...)`), while shallow member actions receive a plain
`params[:id]` with no parent param at all (`Task.find(params[:id])`).

**Rule of thumb:** If the URL has more than one nested `:id` segment for a normal CRUD screen, reconsider shallowing or a top-level resource.

---

## Member vs Collection

```ruby
resources :invoices do
  member do
    get :preview   # GET /invoices/:id/preview — one invoice
  end
  collection do
    get :search    # GET /invoices/search — the set
  end
end
```

- **member** — operation on one record; needs `:id` in path.
- **collection** — operation on the collection; no `:id`.

If you reach for many member routes (`approve`, `reject`, `schedule`), consider a small nested resource (`resources :approvals`) with CRUD on that resource instead — see the writing-controllers skill REST mapping.

---

## Custom Actions vs New Resources

The router declares URLs; the decision “verb on parent vs new controller” is shared with controller conventions.

**Prefer:** new noun resource + standard actions (`create` / `destroy`) when the behaviour is a domain state change or a first-class concept.

**Acceptable on the router:** rare `member` / `collection` routes for honest one-offs (e.g. `preview`, `export`) with a clear comment or ticket reference.

**Avoid:** many `post :verb` routes on the same resource — that is RPC sprawl; refactor toward resources and model methods.

---

## API vs HTML

When JSON/API behaviour is a different contract (authentication, versioning, error shape), use a namespace:

```ruby
namespace :api do
  namespace :v1 do
    resources :articles, only: %i[ index show ]
  end
end
```

Do not maintain two parallel trees that differ only by format if a single controller can `respond_to` or separate serializers — namespaces are for boundary and policy, not format alone.

Version when external clients depend on stability; internal SPA + same app can often stay unversioned until you need the break.

---

## Constraints

Use `constraints` for routing predicates Rails should know before dispatch:

- Subdomain or host (`constraints subdomain: 'api'`)
- Format (`constraints format: :json`) when routing truly splits
- Segment patterns (numeric id vs uuid) when the router must distinguish

```ruby
# Good — host-based split
constraints(host: "api.example.com") do
  namespace :api do
    resources :widgets
  end
end

# Bad — permission check in router
# constraints ->(req) { User.find_by(id: session[:user_id])&.admin? }
```

---

## Namespaces and `scope`

- `namespace :admin` — module `Admin::`, path prefix `/admin`, expected folder `app/controllers/admin/`.
- `scope module:` — change controller lookup without changing the URL path (useful to group implementation without extra URL segments).
- `path:` option — change URL segment without renaming the module; use sparingly and document.

Prefer explicit `namespace` / `scope` blocks over `draw` magic unless splitting `config/routes` into files for readability (each file still lists routes clearly).

---

## Helpers: `as`, `param`

**`as:`** — disambiguate helper names when two routes could collide or you need a stable name.

```ruby
get "signup", to: "registrations#new", as: :signup
```

**`param:`** — use when the segment is not `id` but a slug, consistently with `Model#to_param` and unique lookup.

```ruby
resources :articles, param: :slug
# article_path(@article) uses slug segment
```

Slugs are a tradeoff: prettier URLs vs mental overhead for IDs in logs and support — team should agree.

---

## Redirects and Legacy Routes

Simple permanent URL moves can live in the router:

```ruby
get "old-articles/:id", to: redirect("/articles/%{id}")
```

If redirect logic needs models or conditions, use a controller action or Rack middleware — not a bloated `routes.rb`.

---

## `direct` and `resolve` (Polish)

Rails offers `direct` for named URL helpers and `resolve` for polymorphic mapping. Use when they clarify Active Storage or polymorphic `url_for` without obscuring `rails routes` — not as a default for every resource.

---

## Testing

Assert behaviour that matters:

- Named route exists and points to the expected controller#action (routing spec or request spec).
- HTTP verb + path dispatch correctly.
- For APIs, content-type / accept headers if they change dispatch.

Avoid testing every line of `routes.rb` syntax; test the integration surface teams rely on.

---

## Cross-References

- **Controller action shape and new resources:** writing-controllers skill, `references/patterns.md` § REST Mapping.
- **Authorization:** writing-policies skill — not in the router.
