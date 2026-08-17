---
name: writing-javascript
description: >-
  Write JavaScript in a Rails app the omakase way — importmap-first delivery,
  optional bundling (esbuild, Vite) when justified, focused Stimulus controllers
  under app/javascript/controllers, modern ES module hygiene, accessible DOM
  updates, safe fetching with CSRF, and a clear boundary with Turbo/HTML. DHH /
  37signals style. Use when editing importmap, package.json, application.js,
  Stimulus controllers, shared JS modules, or choosing bundling; not for
  Hotwire/Turbo *behaviour in templates* (see writing-hotwire),
  Tailwind/config/global CSS (see writing-css-tailwind), or ERB markup (see
  writing-views). For rebalancing an existing Stimulus fleet (merging, splitting,
  spec coverage), see refactoring-stimulus-controllers.
---

# Writing JavaScript (Rails Boundary + Quality)

<objective>
Keep JavaScript small, focused, and subservient to the Rails app: importmap and
Stimulus are the default; bundling is an intentional exception when npm depth or
tooling requires it. One clear pipeline per codebase — no duplicate routers, no
client authority over domain state for first-party pages. Beyond the boundary,
the code itself must be **modern, modular, accessible, and safe** — ES modules,
async/await with real error handling, single-purpose Stimulus controllers,
DOM-derived state, CSRF-respecting fetches, and no secrets in the bundle.
Styling stays in Tailwind + ERB + minimal Stimulus class toggles — not JS theme
systems or CSS-in-JS; **`../writing-css-tailwind`**, **`../writing-views`**.
</objective>

## When to Use This Skill

| Use | Defer |
|-----|--------|
| `config/importmap.rb`, `package.json`, `application.js`, bundler config | Turbo / Stimulus *behaviour in templates* — **`../writing-hotwire`** |
| New or edited Stimulus controllers in `app/javascript/controllers/` | Tailwind config and global CSS — **`../writing-css-tailwind`** |
| Shared JS modules under `app/javascript/lib/` | Helpers and ERB markup — **`../writing-views`** |
| Choosing importmap vs bundler; adding npm packages | Refactoring an existing Stimulus fleet — **`../refactoring-stimulus-controllers`** |
| Hand-rolled `fetch`, CSRF, error handling, accessibility hooks | Native mobile / hybrid clients — out of scope |

## Process

### 1. Identify the Stack

| Signal | Likely stack |
|--------|----------------|
| `config/importmap.rb`, no `build` scripts in `package.json` | Importmap + Propshaft |
| `package.json` with `build` / `esbuild` / `vite` / `rollup` | Bundled JS — read `references/patterns.md` § Bundling |
| Both present | Pick one — see `references/patterns.md` § One Stack Per App |

If the app is on importmap, **stay on importmap** unless you have a concrete reason to bundle. Bundling has real costs (Node toolchain, Procfile.dev, deploy step) and is justified by npm depth, TypeScript, or workers — not by familiarity.

### 2. Wire Entrypoints and Registration

`app/javascript/application.js` is wired into the layout **once** (via `javascript_importmap_tags` or the bundler's documented tag). Stimulus loads with **`eagerLoadControllersFrom("controllers", application)`** (importmap) or explicit imports (bundler). One discoverable controller tree under `app/javascript/controllers/`. Details: `references/patterns.md`.

### 3. Write Stimulus Controllers Well

A Stimulus controller is good when:

- It has **one responsibility** named in the filename (`clipboard_controller.js`, not `ui_controller.js`).
- It uses `static targets`, `static values`, `static classes`, and `static outlets` — not ad hoc `querySelector` calls or hard-coded class strings.
- It derives **state from the DOM** (targets, values, attributes) — never from a closure variable that morphing will strand.
- It cleans up everything `connect()` set up in `disconnect()`.
- It is **<100 lines** and reads top-to-bottom. If it grows past that, split it (see `../refactoring-stimulus-controllers`).
- It dispatches `CustomEvent`s (`this.dispatch("opened")`) for cross-controller signals; outlets when the dependency is structural.

Worked examples and lifecycle details: `references/patterns.md` § Stimulus.

### 4. Write Vanilla JS Well

When a Stimulus controller isn't the right home (shared utility, third-party integration, presigned upload helper), put it in `app/javascript/lib/<thing>.js`:

- **ES modules** with named exports. No `window.MyApp` globals.
- **`async` / `await`** with `try / catch` only where you can handle the error; otherwise let it bubble.
- **Strict equality** (`===`), optional chaining (`?.`), nullish coalescing (`??`).
- **Pure functions** where possible — easier to reason about and to test.
- No `eval`, no `new Function`, no `innerHTML = userInput`.

### 5. Fetch Safely

If you must hit an endpoint from JS, default to **`@rails/request.js`** for CSRF handling. Send `Accept: text/vnd.turbo-stream.html` when the response is a stream and let Turbo apply the DOM update. Wrap calls in `try / catch`, render errors in the DOM, never `alert()`. Never embed API keys. Patterns: `references/patterns.md` § Fetching.

### 6. Respect Accessibility and DOM Safety

Toggle `aria-*` and `hidden` alongside CSS classes when state changes. Manage focus on overlay open/close. Prefer `textContent`; use `innerHTML` only with server-rendered HTML. Respect `prefers-reduced-motion`. Patterns: `references/patterns.md` § Accessibility.

### 7. Respect the Boundary

Do not add client-side routing, global Redux-style stores, or JSON APIs solely to feed first-party ERB pages. See `references/patterns.md` § Boundary and **`../writing-hotwire`** for the response hierarchy (redirect → frames → streams).

### 8. Verify the Behaviour

Stimulus controllers earn at most **one canonical system spec per behaviour** — see **`agent_harness_rails/skills/writing-tests/references/system-specs.md`** § Budget. The simplest page that exercises the controller is the canonical home; other usages assume it works. For an existing fleet of controllers without specs, run **`../refactoring-stimulus-controllers`**.

## Verification

- [ ] One primary JS delivery path (importmap **or** documented bundler — not two masters)
- [ ] Stimulus lives under `app/javascript/controllers/` and is registered from the app entrypoint
- [ ] Layout uses `javascript_importmap_tags` or the bundler's documented tag — not ad hoc `<script src>` for app code
- [ ] No client-side router duplicating Rails routes for same-origin pages
- [ ] No JSON API exists only to feed your own ERB pages
- [ ] Adding npm packages is justified — not "npm install" by default for CRUD
- [ ] Each Stimulus controller has a single responsibility and is under ~100 lines
- [ ] Stimulus controllers use `static targets / values / classes / outlets`, not query selectors and magic strings
- [ ] `connect()` is paired with `disconnect()` for any external listeners, timers, or observers
- [ ] State is derived from the DOM — controllers survive a Turbo morph
- [ ] `fetch` calls go through `@rails/request.js` (or include CSRF token) and have `try / catch` error handling
- [ ] No secrets, API keys, or auth tokens are embedded in client JS
- [ ] No `innerHTML` with user-controlled input; user input goes through `textContent` or server-rendered HTML
- [ ] Overlay/modal Stimulus controllers manage focus and toggle `aria-*` attributes
- [ ] Each Stimulus behaviour has at most one canonical system spec on the simplest page that exercises it

## References

- [references/patterns.md](references/patterns.md) — importmap vs bundling, ES module hygiene, Stimulus anatomy, fetching with CSRF, accessibility, performance, anti-patterns.
- [agent_harness_rails/skills/writing-hotwire/references/patterns.md](agent_harness_rails/skills/writing-hotwire/references/patterns.md) — Turbo/Stimulus behaviour in templates.
- [agent_harness_rails/skills/refactoring-stimulus-controllers/SKILL.md](agent_harness_rails/skills/refactoring-stimulus-controllers/SKILL.md) — rebalancing an existing Stimulus fleet and ensuring spec coverage.
- [agent_harness_rails/skills/writing-tests/references/system-specs.md](agent_harness_rails/skills/writing-tests/references/system-specs.md) — Five Gates and Budget for JS-driven system specs.
