---
name: writing-css-tailwind
description: >-
  Style Rails apps with Tailwind — tailwindcss-rails, CSS entrypoints, v3 vs
  v4 config shapes, @apply policy, theme extension, responsive/dark
  conventions, Stimulus class toggles, no CSS-in-JS. Use when editing Tailwind
  config, application stylesheets, or global CSS. Utility-first markup in ERB
  templates: writing-views; JS asset pipeline: writing-javascript.
---

# Writing CSS and Tailwind (Rails)

Tailwind wired through **tailwindcss-rails** and the app’s asset pipeline:
utilities live on elements in ERB, the build compiles one clear entrypoint,
and there is no second frontend. The conventions (stack identification,
smallest-change ladder, `@apply` policy, accessibility, anti-patterns,
verification checklist) live in
**`agent_harness_rails/rules/css-tailwind.mdc`** — read it first, then the
worked mechanics the task needs.

| Task | Read |
|------|------|
| Any styling work — rules, stack signals, verification | `agent_harness_rails/rules/css-tailwind.mdc` |
| tailwindcss-rails wiring, v3 vs v4 config shapes, `@apply` mechanics, theme extension, dark mode, Turbo gotchas | [references/patterns.md](references/patterns.md) |
| Class placement in ERB — partials, `class_names`, helpers, form field classes | `agent_harness_rails/rules/views.mdc`, `agent_harness_rails/skills/writing-views/references/patterns.md` § Tailwind |
| Stimulus class toggles, Turbo-friendly markup | `agent_harness_rails/skills/writing-hotwire/references/patterns.md` |
| Importmap vs bundling, JS entrypoints | `agent_harness_rails/skills/writing-javascript/references/patterns.md` |
