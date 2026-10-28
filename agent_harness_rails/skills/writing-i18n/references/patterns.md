# I18n Patterns

Worked mechanics for the conventions in
**`agent_harness_rails/rules/i18n.mdc`**. Rails loads YAML from
**`config/locales/**/*.yml`**. Optional initializer
**`config/initializers/i18n.rb`** sets load paths, default locale, and fallbacks.

---

## Key structure

```yaml
# config/locales/articles.en.yml
en:
  articles:
    index:
      title: "Articles"
      empty: "No articles yet."
    show:
      meta_description: "%{title} — published %{date}"
```

- **Key nesting follows the app's own layout** — `articles.index.title`
  matches `app/views/articles/index.html.erb`, `article_mailer.published.subject`
  matches the mailer path. This is what makes lazy lookup,
  `default_i18n_subject`, and `human_attribute_name` resolve by convention.
- **`activerecord.models` / `activerecord.attributes`** — model names and column
  labels for forms and `human_attribute_name`.
- **`activerecord.errors`** — override or extend validation messages when needed.
- **Mailers** — `article_mailer.published.subject` (works with
  **`default_i18n_subject`** in mailers) — see **`agent_harness_rails/skills/writing-mailers/references/patterns.md`**.
- **Shared chrome** — `layouts.application.*`, `shared.*`, only for truly global
  copy — not a mega-flat `common.*` junk drawer of unrelated strings.

---

## Lazy lookup in views

Rails resolves **`t(".title")`** relative to the current template path:

```erb
<%# app/views/articles/show.html.erb %>
<h1><%= t(".heading") %></h1>
```

```yaml
# config/locales/articles.en.yml
en:
  articles:
    show:
      heading: "Article"
```

**When it helps:** Page-specific headings, one-off labels tied to a single
template.

**When to use absolute keys instead:** Partials rendered from many contexts
(`render "shared/foo"`), shared components, or when the relative path is
misleading — use **`t("articles.card.title")`**.

---

## Absolute keys

Use explicit paths for:

- **Helpers** — `link_to t("articles.actions.edit"), ...`
- **Controllers** — `redirect_to ..., notice: t("articles.created")`
- **Mailers** — subjects and shared phrases across HTML/text parts
- **Policies / `rescue_from`** — e.g. `I18n.t("pundit.article_policy.update?")` — see **`agent_harness_rails/skills/writing-policies/references/patterns.md`**

---

## Interpolation

```yaml
en:
  greetings:
    hello: "Hello, %{name}!"
```

```erb
<%= t("greetings.hello", name: @user.first_name) %>
```

Never **`"Hello " + name`** — word order differs by locale.

---

## Pluralization

```yaml
en:
  articles:
    comments_count:
      one: "1 comment"
      other: "%{count} comments"
```

```erb
<%= t(".comments_count", count: @article.comments.size) %>
```

Use **`zero`** where the locale needs it. For complex rules, follow Rails’ i18n
pluralization docs for that locale.

---

## Datetime and numbers

- **`l(time)`** / **`l(date)`** — localized format from **`time.formats`** /
  **`date.formats`** in locale files.
- **`number_to_currency`**, **`number_to_percentage`**, **`number_with_delimiter`**
  — use helpers; configure separators in **`en.yml`** under **`number`**.

```yaml
en:
  date:
    formats:
      short: "%-d %b"
  time:
    formats:
      published: "%-d %B %Y at %H:%M"
```

```erb
<%= l(@article.published_at, format: :published) %>
```

---

## Active Record labels and errors

Rails expects:

```yaml
en:
  activerecord:
    models:
      article: "Article"
    attributes:
      article:
        title: "Title"
        body: "Body"
  errors:
    messages:
      blank: "can't be blank"
```

Custom validation messages can live under **`activerecord.errors.models.article.attributes.title`** or **`activerecord.errors.models.article`** as needed.

Rails composes error copy from the attribute label plus the message, so the
label must be **human-readable**: rename schema-shaped attributes — especially
join-table foreign keys — to their real-world names.

```yaml
en:
  activerecord:
    models:
      article_categorization: "Category"
    attributes:
      article_categorization:
        category_id: "Category"
      article:
        published_at: "Publication date"
```

Without the override, a `belongs_to :category` validation on the join model
surfaces as “Article categorizations category id can't be blank” — with it, the
user reads “Category must exist”. Any attribute whose column name would read as
database jargon in an error message gets a label here.

**Enums** — Rails has no built-in enum label lookup; give labels a bounded
key path and translate explicitly:

```yaml
en:
  articles:
    statuses:
      draft: "Draft"
      published: "Published"
```

```erb
<%= t("articles.statuses.#{article.status}") %>
```

The dynamic segment is safe here because enum values are a closed set (see
§ Anti-patterns on dynamic keys). Gems like `enum_help`
(`Article.statuses_i18n`) layer helpers over similar keys — a team choice,
not part of omakase Rails.

---

## Defaults and missing translations

- **`t("key", default: "Fallback")`** — sparingly; prefer adding the key.
- **`defaults: [:first, :second]`** — try keys in order (rare).
- Development: **`config.i18n.raise_on_missing_translations = true`** surfaces
  missing keys early (team choice).

---

## Mailers

Mailer subjects often use **`default_i18n_subject`**, which looks up
**`<mailer_path>.<action>.subject`**. Body copy can use **`t()`** in templates
with keys under **`article_mailer.published.*`**. Keep HTML and text parts from
diverging wildly — shared phrases under the same namespace.

Detail: **`agent_harness_rails/skills/writing-mailers/references/patterns.md`** § I18n and subjects.

---

## Testing

- Prefer asserting **outcomes** (`have_content` on stable copy) over binding
  every spec to English literals if you ship multiple locales.
- When a spec must pin copy, use **`I18n.t("key")`** in the expectation or
  freeze locale for that example — avoid duplicating YAML strings in specs.
- Request specs that assert **`flash`** can compare to **`I18n.t(...)`**.

See **`agent_harness_rails/rules/testing.mdc`** — behaviour has one home; do not re-test every
translation in every layer.
