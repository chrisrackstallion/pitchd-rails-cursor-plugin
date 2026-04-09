---
name: writing-css-tailwind
description: >-
  Style Rails apps with Tailwind the Rails way — tailwindcss-rails, CSS
  entrypoints, v3 vs v4 config shapes, @apply policy, theme extension,
  responsive/dark conventions, accessibility, Stimulus class toggles. DHH/37signals:
  utility-first markup in ERB (see writing-views), partials over parallel design
  systems, no CSS-in-JS for Hotwire-first UIs. Use when editing Tailwind config,
  application stylesheets, global CSS, or clarifying styling vs views (templates)
  and javascript (asset pipeline).
---

# Writing CSS and Tailwind (Rails)

<objective>
Keep styling aligned with Rails omakase: Tailwind wired through
**tailwindcss-rails** and the app’s asset pipeline. Utilities live on elements in
ERB; the build compiles one clear entrypoint. Avoid inventing a second frontend —
no repository-style token layers, no CSS-in-JS mental models for server-rendered
pages. Stimulus changes classes; Turbo updates HTML. Clarity over framework
fashion.
</objective>

## Process

### 1. Identify the stack

| Signal | Action |
|--------|--------|
| `tailwindcss-rails` in Gemfile, `bin/rails tailwindcss:watch` in Procfile | Read `references/patterns.md` § Rails integration |
| `tailwind.config.js` at repo root or under `config/` | Likely **v3**-style JS config — read § Version notes |
| `@import "tailwindcss"` in a single CSS file, theme in CSS | Likely **v4** CSS-first — do not paste v3-only snippets |
| Editing only a partial / helper | Prefer **`../writing-views`** — this skill is for pipeline + global rules |

### 2. Prefer the smallest change

- **One-off layout** → utilities in the template (`../writing-views`).
- **Repeated styled block** → partial (`../writing-views`).
- **Repeated class string across many templates** → helper with `class_names` (`../writing-views`).
- **Cross-cutting prose/forms glue** → consider `@apply` in **one** place — see `references/patterns.md` § @apply.

### 3. Stimulus and Turbo

- **Stimulus:** toggle Tailwind classes with `classList` or `class_names` in JS — **`../writing-hotwire/references/patterns.md`** § Stimulus.
- **Turbo:** styles persist across Drive navigations; avoid CSS that assumes only a cold full-page load.

### 4. JavaScript pipeline

Importmap vs bundler is **`../writing-javascript`** — not this skill. This skill does **not** prescribe styled-components, theme providers, or JS-driven design tokens for first-party ERB.

## Verification

- [ ] Tailwind config and docs match the project’s **major** version (v3 JS config vs v4 CSS-first).
- [ ] Global `@tailwind` / `@import "tailwindcss"` live in the **documented** entry stylesheet, not ERB.
- [ ] `@apply` is exceptional — not a second utility system.
- [ ] Project colours/spacing live in **theme extension**, not endless arbitrary values.
- [ ] Focus states and contrast are not stripped for aesthetics.
- [ ] No duplicate “design system” in JS for Hotwire-first CRUD UI.

## References

- [references/patterns.md](references/patterns.md) — tailwindcss-rails, v3/v4, `@apply`, theme, responsive/dark, a11y, anti-patterns.
