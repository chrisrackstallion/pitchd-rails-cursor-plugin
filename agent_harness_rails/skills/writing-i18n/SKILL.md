---
name: writing-i18n
description: >-
  Organize Rails I18n — YAML structure, lazy lookup in views, absolute keys in
  helpers and controllers, interpolation and pluralization, datetime/number
  formats, and Active Record error messages. Opinionated Rails best practice: boring keys,
  framework-first, no string concatenation in templates. Use when adding or
  changing locales, extracting user-facing copy from ERB, flash messages, or
  validation messages; not for translation vendor tooling or SPA i18n-js.
  Triggers: locales, config/locales YAML, t(), I18n.t, missing translations,
  flash copy, human_attribute_name.
---

# Writing I18n

<objective>
Treat locale files as part of the application: namespaced keys mirroring the
app's structure, static copy in YAML, dynamic values via interpolation. Keep
I18n boring and omakase — no parallel translation architecture.
</objective>

The rules — key structure, lazy vs absolute lookup, error messages, dates and
times, anti-patterns, and the verification checklist — live in
**`agent_harness_rails/rules/i18n.mdc`**. Read it first.

## Routing

| Task | Read |
|------|------|
| New feature copy | `references/patterns.md` § Key structure |
| Strings in a view | `references/patterns.md` § Lazy lookup in views |
| Strings in a helper / shared partial / controller | `references/patterns.md` § Absolute keys |
| Dynamic values in copy | `references/patterns.md` § Interpolation |
| Counts | `references/patterns.md` § Pluralization |
| Dates, times, numbers | `references/patterns.md` § Datetime and numbers |
| Validation messages / attribute labels / enums | `references/patterns.md` § Active Record labels and errors |
| Missing-translation surfacing | `references/patterns.md` § Defaults and missing translations |
| Mailer subjects and body copy | `references/patterns.md` § Mailers |
| Specs touching copy | `references/patterns.md` § Testing |
| Code review | `agent_harness_rails/rules/i18n.mdc` § Verification |
