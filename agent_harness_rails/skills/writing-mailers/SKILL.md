---
name: writing-mailers
description: >-
  Write ActionMailer classes, templates, and previews — thin mailers,
  parameterized Mailer.with, deliver_later, multipart HTML/text, I18n
  subjects. Use when creating or changing mailers, mailer views, email copy,
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

The conventions — thin mailers, delivery timing, multipart templates, I18n
subjects, previews, testing ownership, anti-patterns, and the verification
checklist — live in **`agent_harness_rails/rules/mailers.mdc`**. Read it
first, then route by task:

| Task | Action |
|------|--------|
| New mailer / new email | Read `references/patterns.md`, add mailer + templates |
| Parameterized mail (`Mailer.with`) | Read `references/patterns.md` § Parameterized mailers |
| Subject / body copy | Read `references/patterns.md` § I18n and subjects; key structure in `agent_harness_rails/skills/writing-i18n/references/patterns.md` § Mailers |
| Async vs sync delivery | Read `references/patterns.md` § Delivery |
| Preview in browser | Read `references/patterns.md` § Previews |
| Mailer spec | Read `references/patterns.md` § Testing; **`agent_harness_rails/skills/writing-tests/references/support-specs.md`** § Mailer Specs |
| Template partials / helpers | **`agent_harness_rails/skills/writing-views/references/patterns.md`** (strict locals where applicable) |
| Code review | Read `agent_harness_rails/rules/mailers.mdc` and all references, review against conventions |

## References

- [references/patterns.md](references/patterns.md) — delivery, params, I18n, previews, testing
