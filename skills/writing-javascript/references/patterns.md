# JavaScript and Asset Pipeline Patterns

This document is about **where JS lives** and **how it is delivered**. Turbo
Drive, Frames, Streams, and Stimulus *behaviour* in templates are covered in
**`../writing-hotwire/references/patterns.md`**.

---

## Importmap as the default (omakase)

Rails ships **`importmap-rails`**: pin modules in **`config/importmap.rb`**, load
them in **`app/javascript/application.js`**, expose tags with
**`javascript_importmap_tags`** in the layout. No `node_modules` required for
Stimulus + Turbo + small libraries.

```ruby
# config/importmap.rb
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
```

```js
// app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"
```

Prefer **pinning** over copying vendor files by hand unless you have a reason.

---

## Stimulus controller location

- Files: **`app/javascript/controllers/<name>_controller.js`** (e.g.
  `clipboard_controller.js` → `data-controller="clipboard"`).
- Registration: **`import "controllers"`** with **`stimulus-loading`** / eager
  load, or explicit `import ...` per controller — match the Rails generator
  output for your Rails version.

Do not scatter controllers under `vendor/` or load them from random paths — one
discoverable tree.

---

## Bundling when it is justified

Add **jsbundling-rails** (esbuild, rollup, webpack) or **Vite** when you need:

- A deep **npm** dependency graph Stimulus alone cannot sanely pin
- **TypeScript** as a team standard
- **Workers** or tooling that assumes a Node build step

Keep the build **thin**: one or few entrypoints; still ship **server-rendered
HTML** as the app shell. The bundle augments the page — it does not replace
Rails routing or session.

Document in **`README`** or team docs: **why** the bundler exists, **how** to run
`bin/dev` / `Procfile.dev` so JS rebuilds alongside Rails.

---

## Propshaft and assets

**Propshaft** (Rails 7+ default) serves **`app/assets`**, **`vendor/assets`**, and
manifest paths — fingerprinted assets, no Sprockets pipeline. Put images, fonts,
and compiled CSS there per team conventions.

**Sprockets**-legacy apps: same *mental* rule — one pipeline, do not fight it
with ad hoc copies in `public/` for assets that belong in the manifest.

This skill does **not** duplicate Tailwind or view styling guidance — see
**`../writing-views/references/patterns.md`**.

---

## Layout and tags

- **Importmap:** `<%= javascript_importmap_tags %>` in **`app/views/layouts/application.html.erb`** (or equivalent).
- **Bundled:** use the helper your integration documents (e.g. `javascript_include_tag` to the compiled bundle, or vite helpers). **One** canonical include for application JS.

Avoid loading half the app from a CDN and half from importmap without a clear
split (e.g. only analytics from CDN).

---

## Boundary: server owns truth

- **Sessions and cookies** authenticate same-origin browser requests — you do
  not need JWT in JS for your own ERB pages.
- **Routes** live in **`config/routes.rb`** — not a client-side router mapping
  `/articles` parallel to Rails.
- **Authorization** runs on the server (Pundit, etc.) — Stimulus may hide UI,
  not enforce security.

Repeated from Hotwire: **`fetch` + JSON** for CRUD on pages you fully control is
usually pipeline drift — prefer **`form_with`**, Turbo, and streams.

---

## Defer to Hotwire

For **`data-turbo-*`**, frame targeting, stream templates, morphing, and
Stimulus *patterns* (targets, values, actions): **`../writing-hotwire/references/patterns.md`**.

---

## Anti-patterns

- **Two bootstraps** — importmap-loaded Turbo plus a separate webpack bundle
  both initializing Stimulus or Turbo.
- **`node_modules` by default** — adding npm for every feature without a build
  requirement.
- **Embedding secrets in JS** — use server-rendered data attributes or
  dedicated endpoints; never API keys in the bundle for client-exposed trees.
- **Micro-frontends** and module federation for a typical Basecamp-shaped Rails
  app — out of scope and opposite of omakase.

---

## Out of scope

- **React / Vue / Svelte** as the primary application shell replacing Rails
  views.
- **GraphQL** or JSON-first APIs for same-origin pages that could stay HTML-first.
- **Deployment** (CDN-only assets, edge workers) — infra; not this doc.
- **Detailed Vite/webpack configuration** — link to upstream docs when you
  adopt a bundler; keep this repo’s story at the boundary level.
