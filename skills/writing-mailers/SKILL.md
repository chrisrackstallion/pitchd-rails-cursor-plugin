---
name: writing-mailers
description: >-
  Write ActionMailer classes, mailer templates, and previews following
  DHH/37signals conventions — thin mailers, parameterized Mailer.with,
  deliver_later, multipart HTML/text, I18n for subjects, and previews for
  development. Use when creating or changing mailers, mailer views, email copy,
  or mailer specs; not for SMTP provider setup or Action Mailbox inbound mail.
---

# Writing Mailers

<objective>
Treat mailers as controllers for email: one clear method per message, instance
variables for templates, and delivery pushed to the background by default.
Orchestration belongs in models and jobs; mailers turn domain state into MIME.
Previews make email reviewable without sending. Tests assert what recipients
see — not wrapper objects or implementation trivia.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New mailer / new email | Read `references/patterns.md`, add mailer + templates |
| Parameterized mail (`Mailer.with`) | Read `references/patterns.md` § Parameterized mailers |
| Subject / body copy | Read `references/patterns.md` § I18n and subjects; key structure in `../writing-i18n/references/patterns.md` § Mailers |
| Async vs sync delivery | Read `references/patterns.md` § Delivery |
| Preview in browser | Read `references/patterns.md` § Previews |
| Mailer spec | Read `references/patterns.md` § Testing; **`skills/writing-tests/references/support-specs.md`** § Mailer Specs |
| Template partials / helpers | **`skills/writing-views/references/patterns.md`** (strict locals where applicable) |

### 2. Shape the API

Name methods for the **email’s purpose** (`invitation`, `receipt`), not generic verbs. Prefer **`Mailer.with(record: foo).invitation`** when multiple arguments or cross-cutting params; use plain method args when a single, obvious recipient fits.

### 3. Templates

Add **`action.html.erb`** and **`action.text.erb`** under **`app/views/<mailer_name>/`**. Use **`_url`** in links. Share fragments via partials if needed — avoid duplicating copy between HTML and text (shared phrases via helpers or I18n).

### 4. Send It

From controllers or models, prefer **`deliver_later`**. After transactions, use **`after_*_commit`** callbacks so email is not enqueued for rolled-back work.

### 5. Previews

Add or update a class under your preview path so `/rails/mailers` lists a working example.

### 6. Test

Mailer spec owns recipients, subject, and key body content. Request/system specs assert enqueue only when that is the behaviour under test.

## Verification

- [ ] Public methods are named for the message, not `send` / `notify` generics
- [ ] Instance variables are set in the mailer method (or a documented `before_action` pattern)
- [ ] HTML + text templates exist, or the exception is documented
- [ ] Links use **`_url`**, not **`_path`**
- [ ] **`deliver_later`** unless sync delivery is truly required
- [ ] No new “mailer service” wrapper — callers use the mailer API
- [ ] Preview exists for non-trivial mail
- [ ] Mailer spec covers content; callers use **`have_enqueued_mail`** where appropriate

## References

- [references/patterns.md](references/patterns.md) — delivery, params, I18n, previews, testing, anti-patterns
