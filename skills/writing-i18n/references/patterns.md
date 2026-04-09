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

- **Feature-first** — top level mirrors user-facing areas, not generic buckets
  like `strings` or `text`.
- **`activerecord.models` / `activerecord.attributes`** — model names and column
  labels for forms and `human_attribute_name`.
- **`activerecord.errors`** — override or extend validation messages when needed.
- **Mailers** — `article_mailer.published.subject` (works with
  **`default_i18n_subject`** in mailers) — see **`skills/writing-mailers/references/patterns.md`**.
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
- **Policies / `rescue_from`** — e.g. `I18n.t("pundit.article_policy.update?")` — see **`skills/writing-policies/references/patterns.md`**

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

Do not hand-roll **`strftime`** in views for user-visible dates unless you have a
one-off exception — prefer **`l()`** and shared formats.

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

**Enums** — use **`human_attribute_name`** / **`Article.statuses_i18n`** with
**`activerecord.enums`** when you expose enum labels in the UI.

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

Detail: **`skills/writing-mailers/references/patterns.md`** § I18n and subjects.

---

## Testing

- Prefer asserting **outcomes** (`have_content` on stable copy) over binding
  every spec to English literals if you ship multiple locales.
- When a spec must pin copy, use **`I18n.t("key")`** in the expectation or
  freeze locale for that example — avoid duplicating YAML strings in specs.
- Request specs that assert **`flash`** can compare to **`I18n.t(...)`**.

See **`rules/testing.mdc`** — behaviour has one home; do not re-test every
translation in every layer.

---

## Anti-patterns

- **Concatenation** — `"You have " + count + " items"` → pluralized **`t`** with
  **`count:`**.
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
