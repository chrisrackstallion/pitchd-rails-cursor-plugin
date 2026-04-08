# View Patterns Reference

## Partials

Partials are the unit of reuse in Rails views. A partial represents one
concept — a comment, a form, a card — and declares its interface with
strict locals.

### Strict Locals (Rails 7.1+)

Every partial declares its expected locals with a magic comment on the
first line. Rails raises `ArgumentError` if the caller passes unexpected
locals or omits required ones.

```erb
<%# app/views/articles/_article.html.erb %>
<%# locals: (article:) %>
<article id="<%= dom_id(article) %>" class="border-b border-gray-200 py-4">
  <h2><%= link_to article.title, article, class: "text-lg font-semibold text-gray-900 hover:text-blue-600" %></h2>
  <p class="mt-1 text-sm text-gray-600"><%= article.summary %></p>
</article>
```

### Optional Locals with Defaults

```erb
<%# locals: (article:, show_author: true) %>
<article id="<%= dom_id(article) %>" class="py-4">
  <h2 class="text-lg font-semibold"><%= article.title %></h2>
  <% if show_author %>
    <p class="text-sm text-gray-500"><%= article.creator.name %></p>
  <% end %>
</article>
```

### Disabling Strict Locals

For partials that intentionally accept arbitrary locals (rare — layout
wrappers, generic components):

```erb
<%# locals: (**) %>
```

### No Instance Variables

Partials never read instance variables. Everything comes through locals.
This makes partials portable, testable, and self-documenting. The
`locals:` comment *is* the partial's API.

```erb
<%# Good — explicit dependency %>
<%# locals: (article:) %>
<h2><%= article.title %></h2>

<%# Bad — hidden dependency, fragile %>
<h2><%= @article.title %></h2>
```

### Rendering Partials

```erb
<%# Explicit partial with locals %>
<%= render "articles/article", article: @article %>

<%# Short form — Rails infers partial from model class %>
<%= render @article %>

<%# Collection rendering — Rails loops automatically %>
<%= render @articles %>

<%# Partial with explicit collection %>
<%= render partial: "articles/article", collection: @articles %>

<%# Aliasing the local variable %>
<%= render partial: "articles/article", collection: @articles, as: :post %>
```

### When to Extract a Partial

Extract when:
- The same markup appears in two or more templates
- A section represents a distinct domain concept (a card, a comment, a
  form field group)
- The template exceeds ~50 lines
- A section needs to be a Turbo Frame target
- You need to render something as part of a collection
- You want to reuse a styled block — partials are your components,
  not `@apply`

Don't extract when:
- The markup is used once and is only a few lines
- Extracting would create a partial with 10+ locals (too many — the
  abstraction is wrong)
- You're just hiding code to make a template "look shorter"

---

## Collections

Collection rendering is one of Rails' most powerful view conventions.
Let Rails handle the loop — you define what one item looks like.

### Basic Collection Rendering

```erb
<%# Renders _article.html.erb for each article, passing `article` as local %>
<%= render @articles %>
```

This is shorthand for:

```erb
<%= render partial: "articles/article", collection: @articles %>
```

### Empty States

```erb
<%= render(@articles) || render("articles/empty") %>
```

Or inline:

```erb
<%= render(@articles) || tag.p("No articles yet.", class: "py-8 text-center text-gray-500 italic") %>
```

### Spacer Templates

Insert markup between collection items:

```erb
<%= render partial: "articles/article", collection: @articles,
          spacer_template: "articles/spacer" %>
```

### Counter and Index

Rails provides `article_counter` (1-indexed) and `article_iteration`
automatically inside collection partials:

```erb
<%# locals: (article:, article_counter:) %>
<article class="flex items-center gap-3 py-3">
  <span class="text-sm font-medium text-gray-400"><%= article_counter %></span>
  <h2 class="text-base font-semibold"><%= article.title %></h2>
</article>
```

The `article_iteration` object provides `#index`, `#first?`, `#last?`,
and `#size`.

### Polymorphic Collection Rendering

When a collection contains mixed types, Rails resolves the partial per
model:

```erb
<%# Renders _comment.html.erb for Comments, _reaction.html.erb for Reactions %>
<%= render @activities %>
```

Each model type needs a matching partial in its conventional location.

---

## Tailwind

Tailwind is the 37signals CSS strategy. Utility classes go directly in
ERB markup. The HTML *is* the component in Rails — partials provide
reuse, not CSS abstractions.

### Utilities in the Markup

Don't apologise for long class strings — they're readable and greppable.
Each class does one thing. The alternative is indirection.

```erb
<div class="flex items-center gap-3 rounded-lg border border-gray-200 bg-white p-4 shadow-sm hover:shadow-md transition-shadow">
  <div class="flex-1">
    <h3 class="text-lg font-semibold text-gray-900"><%= article.title %></h3>
    <p class="mt-1 text-sm text-gray-500"><%= article.summary %></p>
  </div>
  <%= status_badge(article) %>
</div>
```

### Partials Are Your Components

In React, you extract a component to reuse a styled block. In Rails,
you extract a partial. This is the primary reuse mechanism — not
`@apply`, not CSS component classes.

```erb
<%# Reuse by rendering the partial — not by creating a .card CSS class %>
<%= render "articles/article_card", article: @article %>
```

### class_names for Conditional Classes

Rails ships `class_names` (aliased as `token_list`) for building
conditional class lists. Essential for Tailwind, where conditional
styling is common.

```erb
<div class="<%= class_names(
  "rounded-lg border p-4",
  "border-blue-300 bg-blue-50": article.featured?,
  "border-gray-200 bg-white": !article.featured?
) %>">
  <%= article.title %>
</div>
```

In helpers with `tag` builder:

```ruby
def status_badge(article)
  classes = class_names(
    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
    "bg-green-100 text-green-700": article.published?,
    "bg-gray-100 text-gray-600": !article.published?
  )
  tag.span(article.published? ? "Published" : "Draft", class: classes)
end
```

### Helpers for Repeated Class Patterns

When the *same set of classes* appears on different elements across
many templates, a helper that returns the class string is cleaner than
`@apply`. It's Ruby, it's testable, it composes.

```ruby
module ComponentHelper
  def btn_classes(variant = :primary)
    base = "inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2"

    case variant
    when :primary
      class_names(base, "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500")
    when :secondary
      class_names(base, "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-blue-500")
    when :danger
      class_names(base, "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500")
    end
  end

  def input_classes
    "block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
  end

  def label_classes
    "block text-sm font-medium text-gray-700"
  end
end
```

Usage:

```erb
<%= f.submit "Save", class: btn_classes(:primary) %>
<%= link_to "Cancel", articles_path, class: btn_classes(:secondary) %>
<%= f.text_field :title, class: input_classes %>
```

### @apply — Last Resort

Use `@apply` only for design tokens you repeat across *many different
partials* and where a helper or partial doesn't make sense. The canonical
case is base form input styling via `@tailwindcss/forms` plugin
customisation.

```css
/* app/assets/stylesheets/application.css */
/* Rare — only for truly atomic, cross-cutting styles */
@layer components {
  .prose { @apply max-w-none text-gray-800 leading-relaxed; }
}
```

If you're reaching for `@apply` more than a few times, you're fighting
Tailwind. Extract a partial or helper instead.

### Class Order

Suggest a consistent order for readability (not enforced, but helps
scanning):

1. Layout: `flex`, `grid`, `block`, `inline-flex`
2. Positioning: `relative`, `absolute`, `sticky`
3. Sizing: `w-`, `h-`, `max-w-`, `min-h-`
4. Spacing: `p-`, `m-`, `gap-`
5. Typography: `text-`, `font-`, `leading-`, `tracking-`
6. Colors: `bg-`, `text-`, `border-`
7. Borders / rings: `border`, `rounded`, `ring-`
8. Effects: `shadow-`, `opacity-`
9. Transitions: `transition-`, `duration-`
10. States: `hover:`, `focus:`, `active:`, `disabled:`
11. Responsive: `sm:`, `md:`, `lg:`, `xl:`

### Extend the Config, Not Arbitrary Values

Project-specific colours, fonts, and spacing go in the Tailwind config.
Repeated arbitrary values (`bg-[#1a2b3c]`) mean you should extend the
theme.

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff6ff',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
        }
      },
      fontFamily: {
        display: ['Cal Sans', 'Inter', 'sans-serif'],
      }
    }
  }
}
```

Then use `bg-brand-500` instead of `bg-[#3b82f6]`.

Arbitrary values are fine for one-offs. Repeated arbitrary values are a
code smell — extend the config.

### Responsive Design

Tailwind responsive prefixes (`sm:`, `md:`, `lg:`) live in the HTML.
The responsive behaviour is visible where the content is.

```erb
<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
  <%= render @articles %>
</div>
```

### Dark Mode

Use Tailwind's `dark:` variant when the app supports it:

```erb
<div class="bg-white text-gray-900 dark:bg-gray-900 dark:text-gray-100">
  <h1 class="text-2xl font-bold text-gray-900 dark:text-white"><%= @article.title %></h1>
</div>
```

Set the strategy in the config (`class` for manual toggle, `media` for
system preference):

```js
// tailwind.config.js
module.exports = {
  darkMode: 'class',
}
```

---

## Stimulus Markup

Stimulus controllers provide interactivity through data attributes in
ERB. No inline `<script>` tags, no custom JavaScript in templates.

### Attaching a Controller

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

### Full Example

```erb
<div data-controller="toggle" class="relative">
  <button data-action="toggle#toggle"
          class="text-sm text-gray-600 hover:text-gray-900">
    Options
  </button>
  <div data-toggle-target="content"
       class="absolute right-0 mt-2 hidden w-48 rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5">
    <%= link_to "Edit", edit_article_path(@article), class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100" %>
    <%= button_to "Delete", article_path(@article), method: :delete,
          class: "block w-full px-4 py-2 text-left text-sm text-red-600 hover:bg-gray-100",
          data: { turbo_confirm: "Delete this article?" } %>
  </div>
</div>
```

### Data Attributes in Helpers

When generating elements with data attributes in helpers:

```ruby
tag.div(data: { controller: "countdown", countdown_deadline_value: article.deadline.iso8601 }) do
  tag.span("", data: { countdown_target: "display" })
end
```

### Guidelines

- Controller names are kebab-case: `data-controller="slide-over"`
- Target names are camelCase: `data-slide-over-target="panel"`
- Action format: `event->controller#method` (click is default for buttons)
- Values use the pattern: `data-[controller]-[name]-value`
- Keep controllers small and focused — one behaviour per controller
- Controllers live in `app/javascript/controllers/`

---

## Links and Buttons

`link_to` is for navigation (GET). `button_to` generates a form for
state-changing actions (POST/PATCH/DELETE). This is semantic, accessible,
and works correctly with Turbo.

### Navigation — link_to

```erb
<%= link_to "View article", article_path(@article),
      class: "text-blue-600 hover:text-blue-800 hover:underline" %>

<%= link_to article_path(@article), class: "group block" do %>
  <h3 class="text-lg font-semibold group-hover:text-blue-600"><%= article.title %></h3>
  <p class="text-sm text-gray-500"><%= article.summary %></p>
<% end %>
```

### Mutations — button_to

```erb
<%# Delete with confirmation %>
<%= button_to "Delete", article_path(@article),
      method: :delete,
      class: "text-sm font-medium text-red-600 hover:text-red-800",
      data: { turbo_confirm: "Delete this article?" } %>

<%# State change %>
<%= button_to "Publish", article_publication_path(@article),
      method: :post,
      class: btn_classes(:primary) %>

<%# With form class for layout control %>
<%= button_to "Archive", article_archival_path(@article),
      method: :post,
      class: "text-sm text-gray-600 hover:text-gray-900",
      form_class: "inline" %>
```

### Confirmation for Destructive Actions

Always add `turbo_confirm` to destructive actions:

```erb
<%= button_to "Remove", assignment_path(@assignment),
      method: :delete,
      data: { turbo_confirm: "Remove this assignment?" } %>
```

### Anti-Pattern: link_to for Mutations

```erb
<%# Bad — link_to for a DELETE action %>
<%= link_to "Delete", article_path(@article), data: { turbo_method: :delete } %>

<%# Good — button_to generates a proper form %>
<%= button_to "Delete", article_path(@article), method: :delete %>
```

---

## Helpers

Helpers are modules of methods available in views. They format data for
display — they don't fetch data, mutate state, or contain business
logic.

### Structure

```ruby
# app/helpers/articles_helper.rb
module ArticlesHelper
  def reading_time(article)
    minutes = (article.body.split.size / 200.0).ceil
    pluralize(minutes, "min read")
  end

  def status_badge(article)
    classes = class_names(
      "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
      "bg-green-100 text-green-700": article.published?,
      "bg-gray-100 text-gray-600": !article.published?
    )
    tag.span(article.published? ? "Published" : "Draft", class: classes)
  end

  def article_visibility_label(article)
    tag.span(article.visibility.humanize,
      class: "text-xs font-medium text-gray-500 uppercase tracking-wide")
  end
end
```

### Guidelines

- **Return strings** — helpers produce output for the template
- **No side effects** — never modify state, enqueue jobs, or touch the
  database
- **Use `tag` builder** — prefer `tag.span(...)` over string
  concatenation or `content_tag`
- **Use `class_names`** — for conditional Tailwind classes
- **Small and focused** — if a helper exceeds ~10 lines of HTML, it
  should be a partial instead
- **Named for output** — `reading_time`, `status_badge`,
  `btn_classes` — not `process_article` or `handle_display`

### tag Builder

The `tag` builder produces safe HTML without string concatenation:

```ruby
tag.div(class: "flex items-center gap-2") { "content" }
tag.span("Active", class: "rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700")
tag.input(type: "text", name: "query", value: params[:q],
  class: "rounded-md border-gray-300 shadow-sm")
```

For void elements:

```ruby
tag.br
tag.hr(class: "my-8 border-gray-200")
tag.img(src: image_path("logo.png"), alt: "Logo", class: "h-8 w-auto")
```

### Application-Wide Helpers

Put helpers used across all views in `ApplicationHelper`:

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def current_page_class(*paths)
    "text-blue-600 font-medium" if paths.any? { |path| current_page?(path) }
  end
end
```

### When Helper vs Partial vs Model Method

| Need | Solution |
|------|----------|
| Format a value (date, currency, truncation) | Helper |
| Single HTML element with dynamic attributes | Helper with `tag` builder |
| Small composed element (badge with icon + text) | Helper with `tag` builder |
| Multi-line HTML with structure (card, section) | Partial |
| Domain predicate (`published?`, `editable?`) | Model method |
| Computed display value (`byline`, `summary`) | Model method |
| Complex conditional HTML | Partial, not helper |
| Repeated Tailwind class pattern (buttons, inputs) | Helper returning class string |

---

## Current Attributes in Views

Views frequently render conditionally based on the current user. The
model skill establishes `Current.user` as the convention. Here's how
to handle it in views.

### Action Templates

Action templates can reference `Current.user` for conditional rendering:

```erb
<%# app/views/articles/show.html.erb %>
<% if @article.editable_by?(Current.user) %>
  <%= link_to "Edit", edit_article_path(@article), class: "text-sm text-blue-600 hover:underline" %>
<% end %>
```

### Partials — Keep Them Dumb

Partials should not check `Current.user` internally. Pass permission
state as a boolean local or use a model predicate at the template
level that produces the conditional *before* rendering:

```erb
<%# Good — partial receives what it needs %>
<%= render "articles/article", article: @article, editable: @article.editable_by?(Current.user) %>

<%# In the partial %>
<%# locals: (article:, editable: false) %>
<article id="<%= dom_id(article) %>">
  <h2><%= article.title %></h2>
  <% if editable %>
    <%= link_to "Edit", edit_article_path(article), class: "text-sm text-blue-600" %>
  <% end %>
</article>
```

```erb
<%# Bad — partial reaches for global state %>
<%# locals: (article:) %>
<article>
  <% if article.editable_by?(Current.user) %>
    ...
  <% end %>
</article>
```

The exception: model predicates that don't take arguments and reference
`Current` internally (via association defaults) are acceptable in
partials, because the partial doesn't know about `Current` — the model
does.

---

## Layouts

Layouts provide the page chrome — `<html>`, `<head>`, navigation,
footer. Action templates fill in the content.

### Application Layout

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="en">
<head>
  <title><%= yield(:title) || "App Name" %></title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>

  <meta name="turbo-refresh-method" content="morph">
  <meta name="turbo-refresh-scroll" content="preserve">

  <%= stylesheet_link_tag "application", data_turbo_track: "reload" %>
  <%= javascript_include_tag "application", defer: true,
        data_turbo_track: "reload" %>
</head>
<body class="min-h-screen bg-gray-50 text-gray-900 antialiased">
  <%= render "shared/flash" %>

  <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
    <%= yield %>
  </main>
</body>
</html>
```

### provide vs content_for

Use `provide` when setting a single value. Use `content_for` when
building up content with blocks or appending.

```erb
<%# Single value — use provide %>
<% provide(:title, @article.title) %>

<%# Block content — use content_for %>
<% content_for(:sidebar) do %>
  <%= render "articles/sidebar", article: @article %>
<% end %>
```

```erb
<%# In the layout %>
<title><%= yield(:title) || "App Name" %></title>

<% if content_for?(:sidebar) %>
  <aside class="w-64"><%= yield(:sidebar) %></aside>
<% end %>

<% if content_for?(:head) %>
  <%= yield(:head) %>
<% end %>
```

### Multiple Layouts

Use purpose-specific layouts for different sections of the app:

```ruby
class Admin::BaseController < ApplicationController
  layout "admin"
end

class SessionsController < ApplicationController
  layout "auth"
end
```

### Nested Layouts

Child layouts can extend a parent layout:

```erb
<%# app/views/layouts/admin.html.erb %>
<% content_for(:body) do %>
  <div class="flex min-h-screen">
    <nav class="w-64 bg-gray-900 text-white">
      <%= render "admin/shared/navigation" %>
    </nav>
    <div class="flex-1 p-8">
      <%= yield %>
    </div>
  </div>
<% end %>
<%= render template: "layouts/application" %>
```

---

## Forms

### form_with (Model-Bound)

Always bind forms to a model. `form_with` infers URL, HTTP method,
and Turbo submission behaviour:

```erb
<%= form_with model: @article, class: "space-y-6" do |f| %>
  <div>
    <%= f.label :title, class: label_classes %>
    <%= f.text_field :title, class: input_classes %>
  </div>

  <div>
    <%= f.label :body, class: label_classes %>
    <%= f.rich_text_area :body, class: "prose min-h-[200px]" %>
  </div>

  <div>
    <%= f.label :visibility, class: label_classes %>
    <%= f.select :visibility, Article::VISIBILITIES.keys.map { |v| [v.to_s.humanize, v] },
          {}, class: input_classes %>
  </div>

  <div class="flex items-center gap-3">
    <%= f.submit class: btn_classes(:primary) %>
    <%= link_to "Cancel", articles_path, class: btn_classes(:secondary) %>
  </div>
<% end %>
```

### Shared Form Partials

Extract the form partial when `new` and `edit` share the same fields:

```erb
<%# app/views/articles/_form.html.erb %>
<%# locals: (article:) %>
<%= form_with model: article, class: "space-y-6" do |f| %>
  <div>
    <%= f.label :title, class: label_classes %>
    <%= f.text_field :title, class: input_classes %>
    <%= field_errors(article, :title) %>
  </div>

  <div>
    <%= f.label :body, class: label_classes %>
    <%= f.rich_text_area :body %>
    <%= field_errors(article, :body) %>
  </div>

  <div class="flex items-center gap-3">
    <%= f.submit class: btn_classes(:primary) %>
    <%= link_to "Cancel", articles_path, class: btn_classes(:secondary) %>
  </div>
<% end %>
```

```erb
<%# app/views/articles/new.html.erb %>
<% provide(:title, "New Article") %>
<h1 class="text-2xl font-bold text-gray-900">New Article</h1>
<%= render "form", article: @article %>

<%# app/views/articles/edit.html.erb %>
<% provide(:title, "Edit #{@article.title}") %>
<h1 class="text-2xl font-bold text-gray-900">Edit Article</h1>
<%= render "form", article: @article %>
```

### Validation Errors

Display errors inline next to the relevant field:

```erb
<div class="<%= class_names("space-y-1", "text-red-600": article.errors[:title].any?) %>">
  <%= f.label :title, class: label_classes %>
  <%= f.text_field :title, class: class_names(input_classes,
        "border-red-300 focus:border-red-500 focus:ring-red-500": article.errors[:title].any?) %>
  <% article.errors[:title].each do |error| %>
    <p class="text-sm text-red-600"><%= error %></p>
  <% end %>
</div>
```

For a reusable error display, extract a helper:

```ruby
# app/helpers/form_helper.rb
module FormHelper
  def field_errors(object, attribute)
    return if object.errors[attribute].empty?

    safe_join(object.errors[attribute].map { |msg|
      tag.p(msg, class: "mt-1 text-sm text-red-600")
    })
  end
end
```

### Nested Attributes

```erb
<%= form_with model: @article, class: "space-y-6" do |f| %>
  <%= f.text_field :title, class: input_classes %>

  <%= f.fields_for :tags do |tag_fields| %>
    <div class="flex items-center gap-2">
      <%= tag_fields.text_field :name, class: input_classes %>
      <%= tag_fields.check_box :_destroy %>
      <%= tag_fields.label :_destroy, "Remove", class: "text-sm text-red-600" %>
    </div>
  <% end %>

  <%= f.submit class: btn_classes(:primary) %>
<% end %>
```

### File Uploads with Active Storage

```erb
<div>
  <%= f.label :avatar, class: label_classes %>
  <%= f.file_field :avatar, accept: "image/*", direct_upload: true,
        class: "block w-full text-sm text-gray-500 file:mr-4 file:rounded-md file:border-0 file:bg-blue-50 file:px-4 file:py-2 file:text-sm file:font-medium file:text-blue-700 hover:file:bg-blue-100" %>
</div>
```

---

## Turbo Markup

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

### Lazy-Loading Frames

Load content on demand with `loading: :lazy` and a `src`:

```erb
<%= turbo_frame_tag "recent_activity", src: activity_path, loading: :lazy do %>
  <p class="text-sm text-gray-400 animate-pulse">Loading...</p>
<% end %>
```

### Breaking Out of Frames

When a link inside a frame should navigate the whole page:

```erb
<%= link_to "View full article", article_path(@article), data: { turbo_frame: "_top" } %>
```

### Turbo Stream Templates

For actions that need to update multiple targets on the page. The
controller renders this instead of the normal HTML template:

```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.update "comments_count", html: @article.comments.size.to_s %>
<%= turbo_stream.replace dom_id(@article, :comment_form),
      partial: "comments/form", locals: { article: @article, comment: @comment } %>
```

### Turbo Stream Actions

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

### Broadcasts with Morphing

For real-time updates, prefer `broadcasts_refreshes` on the model and
morphing in the browser. This is the simplest real-time pattern:

```erb
<%# In the view that subscribes to updates %>
<%= turbo_stream_from @room %>
```

```ruby
# On the model
class Message < ApplicationRecord
  broadcasts_refreshes_to :room
end
```

The layout needs the morphing meta tags:

```erb
<meta name="turbo-refresh-method" content="morph">
<meta name="turbo-refresh-scroll" content="preserve">
```

---

## Morphing-Friendly Views

When using Turbo morphing (the default response strategy), structure
views so morphing works well.

### Stable IDs on Everything

Every significant element needs a stable ID via `dom_id`. Morphing
matches elements by ID to diff correctly.

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

Use for: media players, scroll containers with user position, elements
with open dropdowns/modals managed by Stimulus, text inputs mid-typing.

### Stateless Stimulus Controllers

Prefer Stimulus controllers that derive state from the DOM (targets,
values, classes) rather than holding internal state. Morphing preserves
the DOM element but doesn't re-fire `connect()` — controllers that
initialise state in `connect()` and never re-read the DOM will get
stale.

---

## dom_id and dom_class

Always use `dom_id` for element IDs. It produces stable, unique IDs
based on the model and avoids collisions.

```erb
dom_id(@article)            # => "article_42"
dom_id(@article, :comments) # => "comments_article_42"
dom_id(Article.new)         # => "new_article"
```

For CSS classes based on model type:

```erb
dom_class(@article)         # => "article"
dom_class(@article, :featured) # => "featured_article"
```

---

## Empty States

Handle empty collections gracefully. Never show a blank page.

```erb
<%= render(@articles) || render("articles/empty") %>
```

```erb
<%# app/views/articles/_empty.html.erb %>
<%# locals: () %>
<div class="py-12 text-center">
  <h3 class="text-lg font-medium text-gray-900">No articles yet</h3>
  <p class="mt-1 text-sm text-gray-500">Create your first article to get started.</p>
  <div class="mt-6">
    <%= link_to "New Article", new_article_path, class: btn_classes(:primary) %>
  </div>
</div>
```

---

## Shared Partials

Partials used across the entire application live in
`app/views/shared/` or `app/views/application/`.

### Flash Messages

```erb
<%# app/views/shared/_flash.html.erb %>
<%# locals: () %>
<% flash.each do |type, message| %>
  <% classes = class_names(
    "mb-4 rounded-md px-4 py-3 text-sm font-medium",
    "bg-green-50 text-green-800": type == "notice",
    "bg-red-50 text-red-800": type == "alert"
  ) %>
  <div class="<%= classes %>" role="alert">
    <p><%= message %></p>
  </div>
<% end %>
```

### Pagination

```erb
<%# app/views/shared/_pagination.html.erb %>
<%# locals: (pagy:) %>
<nav class="mt-8 flex items-center justify-center">
  <%== pagy_nav(pagy) %>
</nav>
```

---

## Conditional Rendering

### Polymorphic Partials

When rendering varies by type, let Rails resolve it:

```erb
<%# Each model type has its own partial %>
<%= render @notification.notifiable %>
```

This renders `_comment.html.erb` for a Comment, `_reaction.html.erb`
for a Reaction, etc.

### Explicit Variant Partials

For the same model rendered differently in different contexts, use
a descriptive partial name:

```erb
<%# Full detail view %>
<%= render "articles/article", article: @article %>

<%# Compact list item %>
<%= render "articles/article_row", article: @article %>

<%# Card layout %>
<%= render "articles/article_card", article: @article %>
```

Don't use a single partial with many boolean flags — use separate
partials for distinct presentations.

---

## Previews and Mailer Views

### Mailer Views

Mailer views follow the same conventions as web views. Mailer templates
are action templates (not partials), so instance variables are correct
here — same as controller action views.

```erb
<%# app/views/article_mailer/published.html.erb %>
<h1><%= @article.title %> is now live</h1>
<p><%= @article.summary %></p>
<%= link_to "Read it", article_url(@article) %>
```

Use `_url` helpers (not `_path`) in mailer views — emails need full
URLs.

Note: Tailwind utilities don't work in email HTML. Email templates
need inline styles or a CSS inliner (like `premailer-rails`).

---

## Performance

### Fragment Caching

Cache expensive partials with `cache`:

```erb
<% cache @article do %>
  <article class="border-b border-gray-200 py-4">
    <h2 class="text-lg font-semibold"><%= @article.title %></h2>
    <div class="prose mt-2"><%= @article.body %></div>
  </article>
<% end %>
```

For collections:

```erb
<%= render partial: "articles/article", collection: @articles, cached: true %>
```

The `cached: true` option uses multi-key cache reads for the whole
collection in one round-trip.

### Cache Keys

Rails generates cache keys from `updated_at` by default. When the
partial depends on more than the object itself, compose the key:

```erb
<% cache [Current.user, @article] do %>
  <%# Content that varies by user and article %>
<% end %>
```

### Avoiding N+1 in Views

Eager load associations in the controller, not the view:

```ruby
# Controller
def index
  @articles = policy_scope(Article).preloaded.chronologically
  authorize Article
end
```

Where `preloaded` is a scope:

```ruby
scope :preloaded, -> { includes(:creator, :tags, :comments) }
```

Never call associations in views that weren't eager-loaded by the
controller.

---

## Template Variants

Rails supports device-specific templates via variants:

```ruby
# Controller
before_action :set_variant

private
  def set_variant
    request.variant = :phone if request.user_agent&.match?(/Mobile/)
  end
```

```
app/views/articles/
  show.html.erb          # default
  show.html+phone.erb    # mobile variant
```

Use sparingly — Tailwind responsive utilities handle most cases.
Variants are for when mobile needs fundamentally different markup,
not just different styling.
