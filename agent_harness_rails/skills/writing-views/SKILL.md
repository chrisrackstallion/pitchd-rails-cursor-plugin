---
name: writing-views
description: >-
  Write Rails views, partials, helpers, forms, and layouts — HTML-first ERB,
  strict-local partials, helpers for presentation logic, Tailwind
  utility-first styling in templates, content_for. Use when the user mentions
  views, partials, ERB, helpers, forms, layouts, or templates. Stimulus/Turbo
  behaviour: writing-hotwire; copy and locales (I18n): writing-i18n; JS
  delivery (importmap, bundling): writing-javascript; Tailwind
  build/config/global CSS: writing-css-tailwind.
---

# Writing Rails Views

Views are HTML documents with the minimum Ruby necessary to display data —
they present what the model provides, they don't compute it. The conventions
(template skeleton, strict locals, decision framework, anti-patterns, naming,
verification checklist) live in **`agent_harness_rails/rules/views.mdc`** —
read it first, then the worked examples the task needs.

| Task | Read |
|------|------|
| Any view work — rules, skeleton, decision framework, verification | `agent_harness_rails/rules/views.mdc` |
| Partials, collections, empty states | [references/patterns.md](references/patterns.md) § Partials, § Collections, § Empty States |
| Tailwind in templates (utilities, `class_names`, class helpers) | [references/patterns.md](references/patterns.md) § Tailwind |
| Helpers, `tag` builder, `Current` in views | [references/patterns.md](references/patterns.md) § Helpers, § Current Attributes |
| Layouts, `content_for`, forms, links vs buttons | [references/patterns.md](references/patterns.md) § Layouts, § Forms, § Links and Buttons |
| Fragment caching, N+1, template variants | [references/patterns.md](references/patterns.md) § Performance, § Template Variants |
| User-facing strings / locales | `agent_harness_rails/skills/writing-i18n/references/patterns.md` |
| Stimulus / Turbo / Hotwire markup | `agent_harness_rails/skills/writing-hotwire/references/patterns.md` |
| Tailwind pipeline, config, `@apply`, v3/v4, global CSS | `agent_harness_rails/skills/writing-css-tailwind/references/patterns.md` |
| Importmap, package.json, JS entrypoints | `agent_harness_rails/skills/writing-javascript/references/patterns.md` |
| Mailer templates (`*_mailer/`) | `agent_harness_rails/skills/writing-mailers/references/patterns.md` |
