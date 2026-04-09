# Hotwire Patterns

Server-rendered HTML first. Controllers own **HTTP responses**; templates and Stimulus own **markup and behaviour**. Model callbacks own **broadcasts** when updates should reach other tabs or users — see **`skills/writing-models/references/patterns.md`** § Turbo Broadcasts for `broadcasts_refreshes`, `broadcast_append_later_to`, etc.

---

## Response Hierarchy

Prefer the simplest mechanism that satisfies the UX. Each step adds complexity — maximise use of `redirect_to`:

1. **Full-page success** — `redirect_to` after a successful mutation. Turbo Drive performs a full-page visit by default; Turbo 8 may apply morphing on some refresh paths — do not assume every redirect is a morph. Pair with model-level broadcast refresh helpers when other tabs or users should update without a full navigation. Default for ordinary CRUD.
2. **Turbo Frames** — scoped regions (drawers, modals, per-record inline edit). Validation failures re-render with 422 inside the frame when possible.
3. **Turbo Streams** — multi-target DOM updates. Last resort — see § Controller responses below.

### Failed validations (controllers)

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

`status: :unprocessable_content` (422) tells Turbo the submission failed and prevents navigation advancement. Prefer **`:unprocessable_content`**, not **`:unprocessable_entity`**.

When **`render :new` / `:edit`** does not re-run `new` / `edit`, pass **`locals:`** if the partial expects symbols your action did not assign — or rely on **instance variables** already set (e.g. `@article` after `Article.new` fails validation), matching what `new` would have exposed.

---

## Controller Responses

Controller-side Hotwire patterns (Turbo Drive, Frames, Streams). View markup and Stimulus live in templates and `app/javascript/controllers/`; here we focus on **responses**.

### Default: full-page success, 422 on failure

Typical CRUD needs **no `respond_to`** — redirect on success, render on failure:

```ruby
def create
  @article = Article.new(article_params)
  if @article.save
    redirect_to @article, notice: "Article created."
  else
    render :new, status: :unprocessable_content, locals: { article: @article }
  end
end
```

### When to add `format.turbo_stream`

Use **`respond_to`** when the same action serves **HTML** and a **Turbo Stream** — e.g. a form in a **modal or slideover** where success should **close the overlay** and **refresh the page behind it** in one response, without relying only on async broadcasts (they can race open frames).

```ruby
def create
  @article = Article.new(article_params)
  if @article.save
    respond_to do |format|
      format.turbo_stream { render turbo_stream: modal_success_streams }
      format.html { redirect_to articles_path, notice: "Created." }
    end
  else
    render :new, status: :unprocessable_content, locals: { article: @article }
  end
end
```

Implement **`modal_success_streams`** (name it for your app) on `ApplicationController` or a concern. It should return something **`render turbo_stream:`** accepts — typically an **array** of stream actions (e.g. **`turbo_stream.update`** to clear the modal target, **`turbo_stream.append`** for flash, **`turbo_stream.refresh`** so the current URL re-fetches). Splat or return the array from one method so actions stay one-liners. **Compose** stream arrays in one place; avoid long inline `turbo_stream` chains in every action. If Turbo skips a refresh when the request id matches a recent navigation, you may need **`turbo_stream.refresh`** with **`request_id: nil`** — check Turbo’s docs for your version.

Prefer **one coordinated refresh** (clear modal + `refresh`) over many ad hoc **`replace`** calls on individual fragments unless a full refresh is wrong (rare).

### Frames: overlay vs full page

Overlays are for work **without leaving the page**. If success should **go to another screen**, use a **full-page** form instead of escaping frames.

**`data-turbo-frame="_top"`** breaks out of all enclosing frames — treat as a **smell**: often you want a named frame (`turbo_frame_tag dom_id(record)`), a full-page flow, or **422 + re-render** inside the frame. Use `_top` only when intentionally leaving the current UI.

### Per-record inline edit

Use **`turbo_frame_tag dom_id(record)`** around rows and edit templates. On failure, **`render :edit, status: :unprocessable_content`**. Avoid **`data-turbo-permanent`** on rows that must update during morphs.

### Broadcasts vs synchronous responses

**`broadcasts_refreshes_to`** updates **other** clients. The **submitter** should still get a correct **redirect or stream** in the same request. For **bulk** work, suppress per-record broadcasts and emit **one** refresh when the batch completes.

### Morph protection

Permanent overlay frames can use **`data-turbo-permanent`**. Do **not** cancel the **entire page** morph from Stimulus — that stalls the document. Clear modal content with streams targeted at the frame.

### When streams fit

| Streams add value | Simpler first |
|-------------------|---------------|
| Ephemeral UI (e.g. typeahead) | — |
| Modal / slideover: must **clear the overlay** and **synchronously** refresh the page behind it in **one** response (see § When to add `format.turbo_stream`) | **`redirect_to`** alone when a full navigation is acceptable and your layout clears the modal; **streams** when the background must update without that trade-off |
| Replace one row + flash after inline save | **`redirect_to`** or a single **`render`** when that matches the UX |

**Validation errors** belong on **`render` + 422** inside the frame or full page — not a stream workaround.

### Redirects that preserve filters

Merge **permitted** query params into **`redirect_to`** when returning to an index (search, sort, tab). Frame POSTs may omit the parent URL — use **hidden fields** when state must survive.

### Mutating requests

Use **`button_to`** or forms for **POST/PATCH/DELETE**, not **`link_to`** for state-changing actions.

---

## Stimulus

Stimulus controllers provide interactivity through data attributes in ERB. No inline `<script>` tags, no custom JavaScript in templates.

**File location, importmap pins, and bundling** — not duplicated here: **`../writing-javascript/references/patterns.md`**.

### Attaching a controller

```erb
<div data-controller="clipboard">
  ...
</div>
```

### Targets

```erb
<input data-clipboard-target="source" value="<%= @article.share_url %>"
       class="rounded border border-gray-300 px-3 py-2 text-sm" readonly>
```

### Actions

```erb
<button data-action="clipboard#copy"
        class="rounded bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700">
  Copy
</button>
```

### Values

```erb
<div data-controller="loader" data-loader-url-value="<%= articles_path %>">
  ...
</div>
```

### Guidelines

- Controller names are kebab-case: `data-controller="slide-over"`
- Target names are camelCase: `data-slide-over-target="panel"`
- Action format: `event->controller#method` (click is default for buttons)
- Values use the pattern: `data-[controller]-[name]-value`
- Keep controllers small and focused — one behaviour per controller
- Controllers live in `app/javascript/controllers/`

### Data attributes in helpers

```ruby
tag.div(data: { controller: "countdown", countdown_deadline_value: article.deadline.iso8601 }) do
  tag.span("", data: { countdown_target: "display" })
end
```

---

## Turbo markup (ERB)

### Turbo Frames

Wrap the region of the page that should update in isolation:

```erb
<%# app/views/articles/show.html.erb %>
<%= turbo_frame_tag dom_id(@article) do %>
  <h1 class="text-2xl font-bold"><%= @article.title %></h1>
  <p class="mt-2 text-gray-600"><%= @article.body %></p>
  <%= link_to "Edit", edit_article_path(@article), class: "text-sm text-blue-600 hover:underline" %>
<% end %>
```

The edit template wraps its form in a matching frame:

```erb
<%# app/views/articles/edit.html.erb %>
<%= turbo_frame_tag dom_id(@article) do %>
  <h1 class="text-xl font-bold">Edit Article</h1>
  <%= render "form", article: @article %>
<% end %>
```

Turbo swaps the frame contents without a full page navigation.

### Lazy-loading frames

```erb
<%= turbo_frame_tag "recent_activity", src: activity_path, loading: :lazy do %>
  <p class="text-sm text-gray-400 animate-pulse">Loading...</p>
<% end %>
```

### Breaking out of frames

When a link inside a frame should navigate the whole page:

```erb
<%= link_to "View full article", article_path(@article), data: { turbo_frame: "_top" } %>
```

### Turbo Stream templates

For actions that need to update multiple targets on the page. The controller renders this instead of the normal HTML template:

```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.update "comments_count", html: @article.comments.size.to_s %>
<%= turbo_stream.replace dom_id(@article, :comment_form),
      partial: "comments/form", locals: { article: @article, comment: @comment } %>
```

### Turbo Stream actions

| Action | Purpose |
|--------|---------|
| `append` | Add to end of target container |
| `prepend` | Add to beginning of target container |
| `replace` | Replace the target element entirely |
| `update` | Replace the target's inner HTML |
| `remove` | Remove the target element |
| `before` | Insert before the target |
| `after` | Insert after the target |
| `refresh` | Trigger a page morph (Rails 8+) |

### Broadcasts with morphing

For real-time updates, prefer `broadcasts_refreshes` on the model and morphing in the browser. See **models patterns** § Turbo Broadcasts for `broadcasts_refreshes_to`, `turbo_stream_from`, and callbacks.

The layout needs the morphing meta tags:

```erb
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

---

## Morphing-friendly views

When using Turbo morphing (the default response strategy), structure views so morphing works well.

### Stable IDs on everything

Every significant element needs a stable ID via `dom_id`. Morphing matches elements by ID to diff correctly.

```erb
<article id="<%= dom_id(article) %>">...</article>
<div id="<%= dom_id(article, :comments) %>">...</div>
```

### data-turbo-permanent

Mark elements that hold client-side state and should survive morphs:

```erb
<%# Audio player — don't reset playback position %>
<audio data-turbo-permanent id="player" src="<%= @track.audio_url %>"></audio>

<%# Scroll container — don't reset scroll position %>
<div data-turbo-permanent id="chat-messages" class="overflow-y-auto h-96">
  <%= render @messages %>
</div>
```

Use for: media players, scroll containers with user position, elements with open dropdowns/modals managed by Stimulus, text inputs mid-typing.

### Stateless Stimulus controllers

Prefer Stimulus controllers that derive state from the DOM (targets, values, classes) rather than holding internal state. Morphing preserves the DOM element but doesn't re-fire `connect()` — controllers that initialise state in `connect()` and never re-read the DOM will get stale.

---

## Accidental SPA anti-patterns

1. **Client as source of truth** — Large JS state mirroring server models; JSON + `fetch` to rebuild what a Turbo Frame or stream would render for **your own** ERB.
2. **Unclear response contract** — Replacing fragments without stable frame ids, or mixing full-page and frame navigation inconsistently.
3. **API-shaped workflows for first-party HTML** — Extra JSON endpoints and serializers with no consumer other than your templates — use HTML + Turbo.
4. **Stimulus as a mini framework** — Global stores, event buses, or `fetch` + `innerHTML` everywhere instead of form posts and stream templates.
5. **Broadcast/stream sprawl** — Pushing DOM from everywhere with no naming convention or without tying updates to domain events.

Same-origin sessions do not need JWT-for-everything when cookie sessions + Turbo suffice.

---

## Links and buttons (Turbo-aware)

`link_to` is for navigation (GET). `button_to` generates a form for state-changing actions (POST/PATCH/DELETE). Semantic, accessible, and correct for Turbo.

See **`skills/writing-views/references/patterns.md`** § Links and Buttons for extended examples — behaviour matches this document.
