# Mailer Patterns

ActionMailer is part of Rails omakase: **no separate “email service layer.”** Call
`UserMailer.welcome(user).deliver_later` (or `Mailer.with(...).welcome`) from a
controller, model callback, or job — not from a PORO whose only job is wrapping
the mailer. See **`rules/services.mdc`**.

Mailer **templates** follow the same ERB discipline as web views; reuse helpers
and partials where it helps — see **`skills/writing-views/references/patterns.md`**.

---

## Mailer as controller

- **One public method per email** — `welcome`, `password_reset`, `invoice_paid`.
- **Set `@variables`** in the method for templates; avoid fat queries — load what
  the template needs, preferring objects the model already exposed.
- **No domain rules that belong on the model** — e.g. “can this user receive
  this?” is authorization or a model predicate; the mailer assumes the caller
  already decided to send.

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

| Call | When |
|------|------|
| **`deliver_later`** | Default — enqueues `ActionMailer::MailDeliveryJob`; does not block the HTTP response. |
| **`deliver_now`** | Tests, console, or rare synchronous flows where the caller must confirm delivery in-process. |

**Transactions:** Enqueue **after commit**, not inside a transaction that might
roll back:

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

- Place templates in **`app/views/<mailer_path>/`** — e.g. `article_mailer/published.html.erb`.
- Provide **`published.text.erb`** alongside **`published.html.erb`** so plain-text
  clients get a real body. If you only ship HTML, document the product decision.
- Use **`_url`** helpers for links — email clients have no request host; rely on
  **`default_url_options`** in environment configs.

**Styling:** Class-based Tailwind does not apply in email. Use inline styles,
table layouts for complex messages, or a gem such as **premailer-rails** if the
team standardizes on it — do not assume web CSS works in Gmail.

---

## I18n and subjects

```ruby
mail(to: user.email, subject: default_i18n_subject)
```

Use **`default_i18n_subject`** with keys under **`article_mailer.published.subject`**
or set explicit **`subject:`** with **`I18n.t`** for interpolation. Avoid
hardcoded English in one branch and I18n in another for the same mail — pick a
consistent approach per app.

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

Align with **`rules/testing.mdc`**: **mailer specs** own subject, recipients,
and important body fragments. **Request specs** assert **`have_enqueued_mail`**
when the behaviour under test is “this action enqueues email,” not the wording
of the mail.

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
**`deliver_later`**. Match the style of **`skills/writing-tests/references/support-specs.md`**.

---

## Anti-patterns

- **`EmailNotificationService#send_welcome`** that only calls **`UserMailer`** —
  delete the wrapper; call the mailer from the model/job/controller.
- **Authorization logic only in the mailer** — duplicate of policy; caller should
  enforce policy before sending.
- **`deliver_now` in every controller** — slows responses; use **`deliver_later`**.
- **N+1 queries in `mail`** — preload in the mailer method or pass preloaded
  associations.
- **Copy-pasted HTML and text bodies** — extract shared strings via I18n or
  small partials/helpers.

---

## What this skill does not cover

- SMTP credentials, provider dashboards, or DNS (SPF/DKIM) — operations concern;
  keep secrets in env vars.
- **Action Mailbox** inbound processing — separate feature; not mailer *sending*.
- MJML/component frameworks — adopt in the app first, then document locally if
  needed.
