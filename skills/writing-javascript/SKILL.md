---
name: writing-javascript
description: >-
  Place JavaScript in a Rails app without letting it swallow the server-rendered
  product — importmap-first omakase, optional bundling (esbuild, Vite) when
  justified, Stimulus under app/javascript/controllers, Propshaft-friendly
  entrypoints, and a clear boundary with Turbo/HTML. DHH/37signals style. Use when
  editing importmap, package.json, application.js, Stimulus registration, or
  choosing bundling; not for Hotwire/Turbo behaviour (see writing-hotwire) or
  CSS-only work (see writing-views).
---

# Writing JavaScript (Rails Boundary)

<objective>
Keep JavaScript small and subservient to the Rails app: importmap and Stimulus
are the default; bundling is an intentional exception when npm depth or tooling
requires it. One clear pipeline per codebase — no duplicate routers, no client
authority over domain state for first-party pages. The asset pipeline delivers
what the layout asks for; Hotwire owns in-browser navigation and partial
updates once loaded.
</objective>

## Process

### 1. Identify the Stack

| Signal | Likely stack |
|--------|----------------|
| `config/importmap.rb`, no heavy `package.json` scripts | Importmap + Propshaft |
| `package.json` with `build` / `esbuild` / `vite` | Bundled JS — read `references/patterns.md` § Bundling |

### 2. Entrypoints and Registration

Wire **`application.js`** (or the bundler’s entry) once in the layout. Register Stimulus with **`eagerLoadControllersFrom`** or explicit imports — see **`references/patterns.md`**.

### 3. Stimulus Controllers

Put controllers in **`app/javascript/controllers/`**, kebab-case names matching `data-controller`. Behaviour details: **`../writing-hotwire/references/patterns.md`** § Stimulus.

### 4. Respect the Boundary

Do not add client-side routing, global Redux-style stores, or JSON APIs solely to feed first-party ERB pages. **`references/patterns.md`** § Boundary.

### 5. When Unsure

Hotwire/Turbo/streams: **`../writing-hotwire`**. Views and ERB: **`../writing-views`**.

## Verification

- [ ] One primary JS delivery path (importmap **or** documented bundler — not two masters)
- [ ] Stimulus lives under **`app/javascript/controllers/`** and loads from the app entrypoint
- [ ] Layout uses **`javascript_importmap_tags`** or the bundler’s documented tag — not random script tags for app code
- [ ] No client-side router duplicating Rails routes for same-origin app pages
- [ ] Adding npm packages is justified (see patterns) — not “npm install” by default for CRUD

## References

- [references/patterns.md](references/patterns.md)
