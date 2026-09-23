# CSS and Tailwind — reference patterns

Rules and boundaries live in **`agent_harness_rails/rules/css-tailwind.mdc`**; markup placement (`class_names`, partials, helpers, forms) in **`agent_harness_rails/skills/writing-views/references/patterns.md`**. This document covers **build pipeline**, **config**, and **global CSS** mechanics.

---

## Rails integration (`tailwindcss-rails`)

- Add **`tailwindcss-rails`** to the Gemfile; the installer wires **watch** / **build** tasks and a stylesheet entry under **`app/assets`**.
- **Propshaft** (Rails default) or **Sprockets** serves compiled CSS — follow the **one** pipeline the app uses.
- **Do not** add a second CSS compiler “because npm” unless the project already committed to **cssbundling-rails** or similar — one story per app.

Typical touchpoints:

| Location | Purpose |
|----------|---------|
| `app/assets/builds/tailwind.css` (or similar) | Build output — often gitignored; do not hand-edit |
| `app/assets/tailwind/application.css` or `*.tailwind.css` | Source entry with `@tailwind` / `@import "tailwindcss"` |
| `bin/dev` / `Procfile.dev` | `tailwindcss:watch` alongside the web server |

Exact paths vary by gem version — **read the generated files** in the repo before advising.

---

## Version notes (v3 vs v4)

**Never mix snippets from different major versions** in one change.

| | Tailwind v3 (typical) | Tailwind v4 (typical) |
|--|----------------------|------------------------|
| Config | `tailwind.config.js` / `.ts`, `content:` paths | Often **CSS-first**: `@import "tailwindcss"`, `@theme { }` in CSS |
| CLI | Standalone or via gem | Gem wraps compatible CLI |

**Agent rule:** open the project’s config files and match **their** shape. If you only see CSS with `@import "tailwindcss"`, do not paste a full `module.exports = { theme: … }` block from v3 tutorials.

---

## `@apply` — last resort

Use **`@apply`** only when:

- A **small** number of cross-cutting rules need one name (e.g. shared `.prose` tweak, harness glue).
- A helper or partial would be **more** obscure than one layer in CSS.

**Red flags:**

- Dozens of `.btn-primary` / `.card` classes built from `@apply` — you re-created Bootstrap. Use partials and `btn_classes`-style helpers instead (`agent_harness_rails/skills/writing-views/references/patterns.md`).

Example (acceptable, rare):

```css
@layer components {
  .prose-custom {
    @apply max-w-none text-gray-800 leading-relaxed;
  }
}
```

---

## Extend the theme, not arbitrary values

Project colours, fonts, and spacing belong in the **Tailwind theme** (v3: `theme.extend` in JS config; v4: `@theme` in CSS or equivalent).

- **Occasional** `bg-[#…]` or `w-[13rem]` — OK.
- **Repeated** arbitrary values — extend the theme so the design system stays searchable (`bg-brand-500`).

---

## Responsive and dark mode

- **Responsive:** `sm:`, `md:`, `lg:` live on the same elements as content — behaviour is visible in the template (`agent_harness_rails/skills/writing-views/references/patterns.md`).
- **Dark mode:** pick **one** strategy (`class` vs `media`) and document it for the app. Use `dark:` utilities consistently.

Stimulus-driven theme toggles: add/remove a class on `<html>` or `<body>` when using `darkMode: 'class'`.

---

## Turbo and global CSS

- Turbo Drive replaces `<body>` content; persistent UI uses `data-turbo-permanent` — styling must not assume only full reloads.
- **Morphing** can preserve elements — avoid CSS that breaks when IDs and structure stay stable but text changes.

Anti-patterns, accessibility rules, and the boundary map with views, Hotwire, and JS: **`agent_harness_rails/rules/css-tailwind.mdc`**.
