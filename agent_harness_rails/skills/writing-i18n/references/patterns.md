# I18n Patterns

Rails loads YAML from **`config/locales/**/*.yml`**. Optional initializer
**`config/initializers/i18n.rb`** sets load paths, default locale, and fallbacks.
Prefer **boring, namespaced keys** over a clever taxonomy — match how the app is
organized (`articles`, `registrations`, `mailers`).

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

- **Mirror the application structure** — locale files and key nesting always
  follow the app's own layout: `articles.index.title` matches
  `app/views/articles/index.html.erb`, `article_mailer.published.subject`
  matches the mailer path. This is what makes lazy lookup,
  `default_i18n_subject`, and `human_attribute_name` resolve by convention —
  a taxonomy that diverges from the app breaks resolution and forces absolute
  keys everywhere.
- **Feature-first** — top level mirrors user-facing areas, not generic buckets
  like `strings` or `text`.
- **`activerecord.models` / `activerecord.attributes`** — model names and column
  labels for forms and `human_attribute_name`.
- **`activerecord.errors`** — override or extend validation messages when needed.
- **Mailers** — `article_mailer.published.subject` (works with
  **`default_i18n_subject`** in mailers) — see **`agent_harness_rails/skills/writing-mailers/references/patterns.md`**.
- **Shared chrome** — `layouts.application.*`, `shared.*`, only for truly global
  copy.

Avoid **mega-flat** `common.*` with dozens of unrelated strings — it becomes a
junk drawer.

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

**All user-visible dates and times go through I18n.** Format via **`l()`**, with
the formats themselves declared in locale YAML — never inline `strftime` in
views or helpers.

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

A hand-rolled **`strftime`** in a template is a smell: it hardcodes one locale's
convention and bypasses the shared format catalogue.

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

**All user-facing error messages live in I18n** — never hardcoded in models,
controllers, or views. Rails composes error copy from the attribute label plus
the message, so the label must be **human-readable**: rename schema-shaped
attributes — especially join-table foreign keys — to their real-world names.

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

---

## Anti-patterns

- **Concatenation** — `"You have " + count + " items"` → pluralized **`t`** with
  **`count:`**.
- **`strftime` in templates** — `@article.created_at.strftime("%d/%m/%Y")` →
  **`l(@article.created_at, format: :short)`** with the format in locale YAML.
- **Schema jargon in errors** — “Category id can't be blank”, “Article
  categorizations must exist” → `activerecord.attributes` / `activerecord.models`
  overrides with real-world names.
- **Hardcoded error strings** — `errors.add(:base, "Something went wrong")`,
  flash literals in controllers → keys under the feature or `activerecord.errors`
  namespace.
- **Locale taxonomy that diverges from the app** — keys grouped by "type of
  string" instead of mirroring view/mailer paths → resolution breaks and every
  call needs an absolute key.
- **Dynamic key assembly** — `t("status.#{params[:x]}")` with arbitrary user
  **`x`** → allowlist or explicit branches.
- **Strings in the database** as the source of truth for static UI chrome — use
  YAML; DB for user-authored or admin-managed content only.
- **Half-migrated apps** — English hardcoded in views and only some keys in
  **`en.yml`** — pick a consistent rule per codebase.
- **Bypassing I18n** because the app only ships English — still use keys for
  consistency and grep-ability; **`en`** alone is a valid single-locale setup.

---

## Out of scope

- Translation Management Systems (Phrase, Lokalise, Smartling), translator
  workflows, screenshots, and vendor webhooks.
- **`i18n-js`** / full client-side key catalogs — only document if the app
  adopts them; server-rendered strings remain the default story for
  Hotwire-first Rails.
