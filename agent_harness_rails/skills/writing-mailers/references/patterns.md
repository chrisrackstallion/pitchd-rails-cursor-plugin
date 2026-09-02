# Mailer Patterns

Worked mechanics for the conventions in **`agent_harness_rails/rules/mailers.mdc`**.
Where orchestration code belongs: **`agent_harness_rails/rules/services.mdc`**.
Mailer **templates** follow the same ERB discipline as web views; reuse helpers
and partials where it helps — see **`agent_harness_rails/skills/writing-views/references/patterns.md`**.

---

## Mailer as controller

The canonical shape — one public method per email, `@variables` set for the
templates, no queries beyond what the template needs:

```ruby
# app/mailers/article_mailer.rb
class ArticleMailer < ApplicationMailer
  def published
    @article = params[:article]
    mail(to: @article.author.email, subject: default_i18n_subject)
  end
end
```

---

## Parameterized mailers

Use **`Mailer.with(...)`** when you pass structured context (records, options)
that should not be a long positional argument list:

```ruby
ArticleMailer.with(article: article).published.deliver_later
```

Inside the mailer, read **`params[:article]`** (Rails 6+ style) or set from
`params` in the method. Use **`default`** for shared keys if you standardize
across methods:

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: "App <noreply@example.com>"
end
```

Pass **IDs** only when you must cross a boundary; prefer loaded objects for
mailer specs and previews when practical.

---

## Delivery

**`deliver_later`** enqueues `ActionMailer::MailDeliveryJob` and does not block
the HTTP response. Enqueue **after commit**, not inside a transaction that
might roll back:

```ruby
after_create_commit :send_welcome_later

private
  def send_welcome_later
    UserMailer.with(user: self).welcome.deliver_later
  end
```

If you call `deliver_later` from a controller action without a callback, be
aware the mail job runs after the request — that is usually what you want.

---

## Templates and MIME

- Place templates in **`app/views/<mailer_path>/`** — e.g. `article_mailer/published.html.erb`
  with `published.text.erb` alongside it.
- Email clients have no request host — **`_url`** helpers rely on
  **`default_url_options`** in environment configs.

**Styling:** Class-based Tailwind does not apply in email. Use inline styles,
table layouts for complex messages, or a gem such as **premailer-rails** if the
team standardizes on it — do not assume web CSS works in Gmail.

---

## I18n and subjects

```ruby
mail(to: user.email, subject: default_i18n_subject)
```

**`default_i18n_subject`** looks up **`<mailer>.<action>.subject`**. Use
**`I18n.t`** for interpolation; keep HTML and text bodies aligned on shared keys
where it helps. Full key conventions, lazy vs absolute lookup, and testing:
**`agent_harness_rails/skills/writing-i18n/references/patterns.md`**.

---

## Previews

Subclasses of **`ActionMailer::Preview`** live on the preview path (often
**`test/mailers/previews/`** or **`spec/mailers/previews/`** depending on
generator and team). Each preview method returns a **`Mail::Message`**:

```ruby
# spec/mailers/previews/article_mailer_preview.rb
class ArticleMailerPreview < ActionMailer::Preview
  def published
    article = Article.published.first || Article.first
    ArticleMailer.with(article: article).published
  end
end
```

Use **realistic** factory or seed-like records — avoid relying on production
data or secrets. Visit **`/rails/mailers`** in development.

---

## Testing

Ownership boundaries: **`agent_harness_rails/rules/mailers.mdc`** § Testing.
The worked mailer spec:

```ruby
# spec/mailers/article_mailer_spec.rb
RSpec.describe ArticleMailer, type: :mailer do
  describe "#published" do
    it "sends to the author" do
      article = create(:article, :published)
      mail = ArticleMailer.with(article: article).published
      expect(mail.to).to eq([article.author.email])
      expect(mail.body.encoded).to include(article.title)
    end
  end
end
```

Use **`deliver_now`** in mailer specs when asserting **`ActionMailer::Base.deliveries`**
if you are not testing the queue — or assert enqueued job when testing
**`deliver_later`**. Match the style of **`agent_harness_rails/skills/writing-tests/references/support-specs.md`**.
