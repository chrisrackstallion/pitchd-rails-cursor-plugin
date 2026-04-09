---
name: writing-i18n
description: >-
  Organize Rails I18n — YAML structure, lazy lookup in views, absolute keys in
  helpers and controllers, interpolation and pluralization, datetime/number
  formats, and Active Record error messages. DHH/37signals style: boring keys,
  framework-first, no string concatenation in templates. Use when adding or
  changing locales, extracting user-facing copy from ERB, flash messages, or
  validation messages; not for translation vendor tooling or SPA i18n-js.
  Triggers: locales, config/locales YAML, t(), I18n.t, missing translations,
  flash copy, human_attribute_name.
---

# Writing I18n

<objective>
Treat locale files as part of the application: namespaced keys, static copy
in YAML, dynamic values via interpolation. Views use lazy lookup where it reads
naturally; helpers and shared partials use explicit keys. Rails handles
pluralization and time formats — do not hand-roll them in templates. Keep
I18n boring and omakase — no parallel translation architecture.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New feature copy | Read `references/patterns.md` § Key structure; add keys under a feature namespace |
| Strings in a view | Prefer `t(".key")` lazy lookup; read § Lazy vs absolute |
| Strings in a helper / shared partial | Absolute key — `t("feature.button.save")` |
| Flash / controller messages | Absolute keys; keep messages out of fat controllers where possible |
| Validation / attribute labels | `activerecord` tree — § Active Record |
| Mailer subject / body phrases | `mailers.*` + § Mailers in patterns; mailer skill § subjects |
| Pluralization / dates / numbers | § Pluralization and datetime; use `l()`, `number_to_*` |

### 2. Add or Update YAML

Place files under **`config/locales/`** — e.g. `en.yml`, `articles.en.yml`. Keep **default locale** complete for keys you introduce; add secondary locales when the app actually ships them.

### 3. Replace String Soup

Swap `"Save"`, `"Cancel"`, concatenated greetings, etc., for **`t()`** calls and keys. Use **`%{name}`** — never string math for grammar.

### 4. Verify

In development, **`config.i18n.raise_on_missing_translations = true`** (if enabled) catches missing keys. Run the screen or mailer preview that uses the new copy.

## Verification

- [ ] User-facing static strings in views/helpers/controllers use **`t()`** / **`I18n.t`**, not raw literals (domain data excepted)
- [ ] Lazy keys match the template path; shared partials use absolute keys
- [ ] Interpolation uses YAML placeholders, not Ruby concatenation
- [ ] Pluralization uses `count:` and proper `one` / `other` (and locale-specific keys when required)
- [ ] No unbounded dynamic key paths from user input
- [ ] `activerecord` attributes/errors follow Rails structure for forms

## References

- [references/patterns.md](references/patterns.md)
