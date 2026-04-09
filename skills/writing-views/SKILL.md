---
name: writing-views
description: >-
  Write Rails views, partials, and helpers following DHH/37signals conventions —
  ERB templates as HTML-first documents, strict-local partials, collection
  rendering, helpers for presentation logic, Tailwind utility-first styling,
  layouts with content_for. Stimulus and Turbo (frames, streams) — see the
  writing-hotwire skill for canonical Hotwire patterns. Use when creating new
  views, extracting partials, writing helpers, building forms, styling with
  Tailwind, working with layouts, or when the user mentions views, partials,
  ERB, helpers, Tailwind, Stimulus, Turbo, or templates.
---

# Writing Rails Views

<objective>
Write views that are HTML documents with the minimum Ruby necessary to display
data. Views are the final rendering step — they present what the model provides,
they don't compute it. Partials are the unit of reuse. Helpers format data for
display. Tailwind utilities style directly in the markup. Stimulus data
attributes provide interactivity; Hotwire (Turbo + Stimulus) is documented in
the writing-hotwire skill. Follow DHH/37signals conventions: ERB, strict
locals, utility-first CSS, collection rendering, and clarity over cleverness.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New view template | Read `references/patterns.md`, scaffold the template |
| Extract a partial | Read `references/patterns.md` § Partials |
| Collection rendering | Read `references/patterns.md` § Collections |
| New helper method | Read `references/patterns.md` § Helpers |
| Tailwind styling | Read `references/patterns.md` § Tailwind |
| Stimulus / Turbo / Hotwire | Read `../writing-hotwire/references/patterns.md` |
| Layout / content_for | Read `references/patterns.md` § Layouts |
| Form template | Read `references/patterns.md` § Forms |
| Turbo Frame/Stream markup | Read `../writing-hotwire/references/patterns.md` |
| Links vs buttons | Read `references/patterns.md` § Links and Buttons |
| Empty state / error display | Read `references/patterns.md` § Empty States |
| Code review | Read all references, review against conventions |

### 2. View Structure

Organise every action template like this:

```erb
<%# app/views/articles/show.html.erb %>
<% provide(:title, @article.title) %>

<article id="<%= dom_id(@article) %>" class="mx-auto max-w-2xl py-8">
  <header>
    <h1 class="text-3xl font-bold text-gray-900"><%= @article.title %></h1>
    <p class="mt-2 text-sm text-gray-500"><%= @article.byline %></p>
  </header>

  <div class="prose mt-6">
    <%= @article.body %>
  </div>

  <section id="comments" class="mt-12">
    <h2 class="text-xl font-semibold text-gray-900">Comments</h2>
    <%= render @article.comments %>
    <%= render "comments/form", article: @article, comment: @comment %>
  </section>
</article>
```

Key principles:
- Set page metadata via `provide` (single value) or `content_for` (block) at the top
- Use `dom_id` for element IDs — never hand-roll them
- Style with Tailwind utilities directly in the markup
- Delegate sub-sections to partials
- Keep the template under ~50 lines — extract partials when it grows
- The controller builds objects (`@comment = @article.comments.build`) — views don't instantiate models

### 3. Partial Structure

Every partial uses strict locals and receives everything it needs through locals:

```erb
<%# app/views/comments/_comment.html.erb %>
<%# locals: (comment:) %>
<div id="<%= dom_id(comment) %>" class="border-b border-gray-100 py-4">
  <p class="text-gray-800"><%= comment.body %></p>
  <span class="mt-1 text-xs text-gray-400">
    <%= comment.creator.name %> · <%= time_ago_in_words(comment.created_at) %> ago
  </span>
</div>
```

### 4. Decision Framework

Before writing markup, ask these questions:

**"Where does this logic belong?"**
- Formatting a value for display → helper method
- Simple string formatting (`.truncate`, `.humanize`, `time_ago_in_words`) → fine inline in ERB
- Deciding *what* to show (permission, state) → model predicate, controller sets the data
- Reusable HTML fragment → partial
- Page-specific HTML → inline in the action template
- Shared page chrome → layout

**"Should this be a partial?"**
- Used in more than one place → yes, extract
- Represents a single domain concept (a comment, a card, a form) → yes, extract
- Template exceeds ~50 lines → extract sub-sections
- Needs to be a Turbo Frame target → yes, extract into its own partial
- Reusing a styled block (same markup + Tailwind classes) → extract partial, not `@apply`
- One-off structural HTML → keep inline

**"Helper or model method?"**
- Domain question (is this published? can this user edit?) → model method
- Display formatting (badge, formatted date, reading time) → helper
- Conditional CSS class composition → helper with `class_names`
- Multi-line HTML with structure (sections, lists, forms) → partial
- Small composed elements (badge with icon, link with label) → helper with `tag` builder is fine

**"How should this be styled?"**
- Standard presentation → Tailwind utilities directly in the markup
- Conditional appearance (state-dependent) → `class_names` helper
- Same class pattern repeated in many partials → helper returning class string
- Design tokens (colors, fonts, spacing) → extend `tailwind.config`, not arbitrary values
- Last resort for truly atomic repeated styles → `@apply` in CSS

**"link_to or button_to?"**
- Navigating to a page (GET) → `link_to`
- Performing an action (POST/PATCH/DELETE) → `button_to`
- Destructive action → `button_to` with `data: { turbo_confirm: "..." }`

### 5. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Instance variables in partials | Strict locals — `<%# locals: (article:) %>` |
| Queries or business logic in views | Controller loads data into instance variables |
| Instantiating models in views (`Comment.new`) | Controller builds the object (`@comment = @article.comments.build`) |
| `if/elsif/else` trees for variants | Separate templates or polymorphic partial rendering |
| `link_to` for mutations (DELETE, POST) | `button_to` with `method:` |
| Inline `<script>` or `<style>` in templates | Stimulus controllers, Tailwind utilities |
| `@apply` for every styled block | Extract a partial — partials are your components |
| Arbitrary Tailwind values everywhere (`bg-[#1a2b3c]`) | Extend the Tailwind config with project tokens |
| Repeated class strings across many templates | Helper returning class string, or extract partial |
| `Current.user` checks inside partials | Pass permission as boolean local, or use model predicate at the template level |
| Formatting in the template (`.strftime`, complex conditionals) | Helper method (but `.truncate`, `.humanize` are fine inline) |
| Hand-rolled element IDs (`id="article-42"`) | `dom_id(@article)` |
| Partials without `locals:` declaration | Always declare strict locals |
| HTML string building in helpers | Use `tag` builder, `content_tag`, or a partial |
| Deep nesting of `render` calls (3+ levels) | Flatten — max 2 levels of nesting |
| `content_for` used for control flow | `content_for` / `provide` is for content injection into layouts |
| Fat helpers with many lines of HTML | Extract to a partial instead |

### 6. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Action templates | `action.html.erb` | `show.html.erb`, `index.html.erb` |
| Partials | `_noun.html.erb` (singular) | `_article.html.erb`, `_comment.html.erb` |
| Form partials | `_form.html.erb` | `_form.html.erb` |
| Shared partials | `app/views/shared/` or `app/views/application/` | `shared/_flash.html.erb` |
| Helper modules | `ResourceHelper` matching controller | `ArticlesHelper`, `CommentsHelper` |
| Helper methods | Verb or noun describing the output | `reading_time`, `status_badge`, `btn_classes` |
| Layouts | Purpose-named | `application.html.erb`, `admin.html.erb`, `mailer.html.erb` |
| Turbo stream templates | `action.turbo_stream.erb` | `create.turbo_stream.erb` |
| Spacer templates | `_spacer.html.erb` | `_spacer.html.erb` |

### 7. Verification

Before finishing, verify:

- [ ] No instance variables in partials — everything comes through strict locals
- [ ] Every partial has a `<%# locals: (...) %>` magic comment
- [ ] No queries, business logic, or complex conditionals in templates
- [ ] No model instantiation in views — controller builds objects
- [ ] Presentation logic lives in helpers, not inline in ERB
- [ ] Element IDs use `dom_id`, not hand-rolled strings
- [ ] Collections rendered with `render @collection`, not manual loops
- [ ] Forms use `form_with model:`, not `form_tag` or `form_for`
- [ ] Mutations use `button_to`, not `link_to` with `turbo_method`
- [ ] Destructive actions have `data: { turbo_confirm: "..." }`
- [ ] Templates are under ~50 lines — sub-sections extracted to partials
- [ ] Turbo Frames wrap the right granularity of content
- [ ] Page titles and meta set via `provide` / `content_for`, not hardcoded in layout
- [ ] Helpers return strings and have no side effects
- [ ] Tailwind utilities used directly in markup — partials for reuse, not `@apply`
- [ ] Conditional classes use `class_names` helper
- [ ] Stimulus attributes use `data-controller`, `data-action`, `data-[name]-target`
- [ ] No inline `<script>` or `<style>` tags

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
