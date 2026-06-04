# JavaScript Patterns

This document covers **where JS lives**, **how it is delivered**, **how Stimulus
controllers are written**, and the **modern JavaScript quality** expectations
across the codebase. Turbo Drive, Frames, Streams, and Stimulus *behaviour in
templates* (ERB data attributes, frame markup, stream actions) live in
**`../writing-hotwire/references/patterns.md`**. Refactoring an existing fleet
of Stimulus controllers — merging, splitting, spec coverage — lives in
**`../refactoring-stimulus-controllers/SKILL.md`**.

---

## One Stack Per App

Pick **one** JS delivery story per codebase. Importmap is the omakase default
since Rails 7. Bundling (esbuild, Vite, rollup) is an intentional decision when
you have a real need: deep npm graph, TypeScript as a standard, workers, or
tooling that assumes a Node build step.

What you must **not** ship:

- importmap loading Turbo + a separate webpack bundle also loading Turbo
- a "main" pipeline plus a "legacy" pipeline both registering Stimulus
  controllers from different paths
- half the app from a CDN, half from importmap, with no documented split

Document the choice in `README.md` or the team's onboarding docs. Reference
`bin/dev` and the `Procfile.dev` setup when bundling.

---

## Importmap as the Default (Omakase)

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
pin "@rails/request.js", to: "@rails--request.js.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib",         under: "lib"
```

```js
// app/javascript/application.js
import "@hotwired/turbo-rails"
import "controllers"
```

```js
// app/javascript/controllers/index.js
import { application } from "./application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)
```

Prefer **pinning** over copying vendor files by hand. Pin the **minified**
production build, not the dev build.

---

## Bundling When It Is Justified

Add **jsbundling-rails** (esbuild, rollup, webpack) or **Vite** when you need:

- A deep **npm** dependency graph importmap cannot sanely pin
- **TypeScript** as a team standard
- **Workers**, WASM, or tooling that assumes a Node build step
- A specific library that genuinely requires a bundler (rare)

Keep the build **thin**: one or few entrypoints; still ship **server-rendered
HTML** as the app shell. The bundle augments the page — it does not replace
Rails routing or session.

Document **why** the bundler exists, and **how** to run `bin/dev` /
`Procfile.dev` so JS rebuilds alongside Rails. Pin the Node version in
`package.json`'s `engines` and the team's dev tooling.

---

## File Layout

```
app/javascript/
├── application.js                  # entrypoint; loads Turbo + controllers
└── controllers/
│   ├── index.js                    # registers controllers with Stimulus
│   ├── application.js              # exports the Stimulus Application instance
│   ├── clipboard_controller.js     # one behaviour per file
│   ├── reveal_controller.js
│   └── …
└── lib/
    ├── csrf.js                     # shared helpers
    ├── time.js
    └── …
```

- Controller files are **kebab-case** matching `data-controller="<name>"`:
  `clipboard_controller.js` → `data-controller="clipboard"`,
  `slide_over_controller.js` → `data-controller="slide-over"`.
- Shared modules live in `app/javascript/lib/`. Pin or bundle them, then import
  by name from controllers — no relative `../../../` chains.
- Do not scatter controllers under `vendor/` or load them from random paths.

---

## Modern JavaScript Hygiene

Default to the modern ECMAScript subset Rails and Hotwire already assume.

### Variables and binding

- `const` by default; `let` only when reassignment is genuine; **never `var`**.
- No top-level mutation of imported modules.

### Functions

- Arrow functions for callbacks; named `function` declarations when stack traces
  matter (event handlers attached via `addEventListener`, debouncers).
- Prefer **pure functions** in `lib/` modules; reach for classes only when state
  is genuinely encapsulated (Stimulus controllers are the canonical case).

### Async

- **`async` / `await`** over raw `.then` chains.
- `try / catch` **only** where you can do something useful (render an error,
  retry once, surface a flash). Otherwise let the promise reject and Turbo /
  the browser surface the failure.
- Never swallow errors silently:

  ```js
  // Bad — silently hides failures
  try { await something() } catch (e) {}

  // Good — handle deliberately or don't catch
  try {
    await something()
  } catch (error) {
    this.showError(error.message)
  }
  ```

### Comparisons and operators

- Strict equality `===` / `!==` — never `==` / `!=`.
- Optional chaining `?.` for deep access; nullish coalescing `??` for defaults.
- Template literals over string concatenation; destructuring for params and
  return shapes.

### Iteration

- `map` / `filter` / `reduce` for pure transforms.
- `for…of` when the body needs `await`. (`forEach` does **not** await — using
  it with async callbacks is a common bug.)

### Modules

- Named exports for shared code; default exports are fine for Stimulus
  controllers (Stimulus expects the default export to be the controller class).
- One concern per file. If a `lib/` module exports six unrelated helpers, split.

```js
// app/javascript/lib/csrf.js
export function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content
}

export function csrfHeaders() {
  return { "X-CSRF-Token": csrfToken() }
}
```

---

## Stimulus Controllers — Anatomy

Stimulus controllers are **small, single-purpose, DOM-driven**. Each controller
file is named for its behaviour, registered automatically via
`pin_all_from "app/javascript/controllers"`, and attached in ERB through
`data-controller`.

### Skeleton

```js
// app/javascript/controllers/reveal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle"]
  static values  = { open: { type: Boolean, default: false } }
  static classes = ["hidden"]

  connect() {
    this.render()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.render()
  }

  render() {
    this.panelTarget.classList.toggle(this.hiddenClass, !this.openValue)
    this.toggleTarget.setAttribute("aria-expanded", this.openValue)
  }
}
```

```erb
<div data-controller="reveal"
     data-reveal-hidden-class="hidden">
  <button type="button"
          data-reveal-target="toggle"
          data-action="reveal#toggle"
          aria-expanded="false"
          aria-controls="<%= dom_id(@article, :details) %>">
    Details
  </button>

  <div id="<%= dom_id(@article, :details) %>"
       data-reveal-target="panel"
       class="hidden">
    <%= render @article.details %>
  </div>
</div>
```

### Targets, values, classes, outlets

- **`static targets`** — DOM elements the controller talks to. Use
  `hasFooTarget` before reaching for `fooTarget` when the target is optional.
- **`static values`** — typed state that lives in `data-*-value` attributes.
  Stimulus parses them (`String`, `Number`, `Boolean`, `Array`, `Object`).
  Provide defaults: `{ type: String, default: "" }`.
- **`static classes`** — CSS classes the controller toggles. Defined in HTML
  as `data-<controller>-<name>-class="…"`. Keeps the controller free of
  hard-coded class names; designers can edit ERB without touching JS.
- **`static outlets`** — declarative references to other controllers. Prefer
  outlets over `document.querySelector` when one controller needs to call
  another.

### Lifecycle

```js
connect()      // controller attached (initial render, Turbo navigation, morph re-connect)
disconnect()   // controller detached
fooValueChanged(value, previous)  // value attribute changed
fooTargetConnected(element)       // a target element appeared
fooTargetDisconnected(element)    // a target element disappeared
fooOutletConnected(controller, element)
fooOutletDisconnected(controller, element)
```

- **Only set up external state in `connect()`** — `window` / `document`
  listeners, timers, observers, third-party widgets.
- **Tear it all down in `disconnect()`**. Listeners must be removed by
  reference; bind once:

  ```js
  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }
  ```

- **In-element listeners** belong in `data-action` — don't hand-wire what HTML
  expresses.

### State lives in the DOM, not in closures

Turbo morphing keeps the element but re-runs `connect()`. A controller that
initialises state in `connect()` and never re-reads the DOM will get stale.

```js
// Bad — `this.count` is stranded after morph
connect() {
  this.count = 0
}
increment() {
  this.count += 1
  this.displayTarget.textContent = this.count
}

// Good — DOM holds the truth
static values = { count: { type: Number, default: 0 } }

increment() {
  this.countValue += 1
}

countValueChanged(value) {
  this.displayTarget.textContent = value
}
```

### Cross-controller communication

Prefer the lightest mechanism that works:

1. **`data-action` on the same element** — when one button drives one
   controller, just use HTML.
2. **`this.dispatch("eventName", { detail })`** — emits a `CustomEvent`
   namespaced to the controller (`reveal:opened`). Listeners use
   `data-action="reveal:opened@window->other#handle"` or `connect()`.
3. **Outlets** — when the dependency is structural (a `toolbar` controller
   always needs the `editor` controller it lives beside). Outlets give you
   typed access and lifecycle callbacks.

Do **not** build global event buses, `window.MyApp`, or a Stimulus "store".

### Size and split rules

A Stimulus controller is too big when any of these are true:

- It has more than **one** verb in the filename (`tabs_and_filters_controller`).
- It exceeds **~100 lines** without a clear reason.
- It mixes UI concerns (toggle, focus) with network concerns (fetch, persist).
- Two unrelated behaviours could be attached independently and still work.

When you see those signals, split — see
**`../refactoring-stimulus-controllers/SKILL.md`**.

---

## Layout and Tags

- **Importmap:** `<%= javascript_importmap_tags %>` in `app/views/layouts/application.html.erb`.
- **Bundled:** use the helper your integration documents (`javascript_include_tag` for the compiled bundle, or Vite helpers). **One** canonical include for application JS.
- **CSP / nonces:** if Content Security Policy is enabled, the importmap and Stimulus pipelines respect Rails' nonce helpers — don't hand-roll `<script>` tags that bypass them.

Avoid loading half the app from a CDN and half from importmap without a clear
split (e.g. only analytics from CDN, with a documented reason).

---

## Fetching from JavaScript

For first-party pages, the right answer is almost always **`form_with` + Turbo**
(see `../writing-hotwire/references/patterns.md`). Reach for `fetch` only when
HTML + Turbo cannot express the interaction — presigned uploads, debounced
search-as-you-type that hits a JSON endpoint, third-party widget integration.

### Use @rails/request.js by default

```js
import { post } from "@rails/request.js"

async function publish(articleId) {
  const response = await post(`/articles/${articleId}/publication`, {
    responseKind: "turbo-stream"
  })
  if (!response.ok) throw new Error(`Publish failed: ${response.statusCode}`)
  return response
}
```

`@rails/request.js`:

- reads the CSRF meta tag and sets `X-CSRF-Token` automatically
- sets the right `Accept` header for `responseKind: "turbo-stream"` (or `json`, `html`)
- exposes `response.ok`, `response.statusCode`, and helpers like `response.text`, `response.json`

### Hand-rolled fetch when you must

```js
import { csrfHeaders } from "lib/csrf"

async function uploadAvatar(file) {
  const body = new FormData()
  body.append("avatar", file)

  const response = await fetch("/profile/avatar", {
    method: "POST",
    headers: { Accept: "text/vnd.turbo-stream.html", ...csrfHeaders() },
    body
  })

  if (!response.ok) {
    throw new Error(`Avatar upload failed: ${response.status}`)
  }
  return response
}
```

- Always send the CSRF header for first-party endpoints.
- Send `Accept: text/vnd.turbo-stream.html` when the response is a Turbo
  Stream; the Turbo runtime applies the DOM update for you.
- Wrap calls in `try / catch` **where you can act**. Render an error message
  in the DOM; never `alert()`; never swallow.
- Don't manually parse JSON when an HTML/Turbo response would do.

### Never embed secrets

API keys, signing tokens, or any credential **must not** ship in the JS bundle.
Use server-side proxies, signed URLs, or server-rendered nonces.

---

## Accessibility and DOM Safety

JavaScript that changes UI state has to keep the UI accessible.

- Toggle **`aria-*`** alongside CSS classes:
  - `aria-expanded` on disclosure buttons
  - `aria-hidden` on offscreen panels
  - `aria-busy` on regions doing async work
  - `aria-selected` / `aria-current` on tab-like UI
- Toggle the **`hidden`** attribute (not just `display: none`) when an element
  should be removed from the accessibility tree.
- Manage **focus** on overlay open and close. Save the previously-focused
  element on open; restore it on close. Trap focus inside true modal dialogs.
- Respect **`prefers-reduced-motion`**:

  ```js
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  if (!reduceMotion) element.animate(...)
  ```

- Honor keyboard interaction: `Escape` closes overlays, `Enter` / `Space`
  activates buttons, `Tab` moves focus normally.

### XSS hygiene

- **`textContent`**, not `innerHTML`, for user-controlled strings.
- `innerHTML` is fine for server-rendered HTML responses (Turbo handles that).
- Never `eval`, never `new Function`, never `setTimeout("…string…")`.
- Don't assemble URLs from user input without `encodeURIComponent`.

---

## Performance

- **Debounce** input handlers (search-as-you-type) at 150–300 ms.
- **Throttle** high-frequency events (scroll, resize) — `requestAnimationFrame`
  is usually the right ceiling.
- Tear down `MutationObserver` / `IntersectionObserver` in `disconnect()`.
- Use `{ passive: true }` for scroll/touch listeners that don't `preventDefault`.
- Importmap: pin the **minified** vendor build for production.
- Don't ship dev-only debug logging; gate behind a build flag or remove.

---

## Propshaft and Assets

**Propshaft** (Rails 7+ default) serves **`app/assets`**, **`vendor/assets`**,
and manifest paths — fingerprinted assets, no Sprockets pipeline. Put images,
fonts, and compiled CSS there per team conventions.

**Sprockets**-legacy apps: same *mental* rule — one pipeline, do not fight it
with ad hoc copies in `public/` for assets that belong in the manifest.

This skill does **not** duplicate Tailwind or view styling guidance — templates
and utilities: **`../writing-views/references/patterns.md`**; pipeline and
global CSS: **`../writing-css-tailwind/references/patterns.md`**.

---

## Boundary: Server Owns Truth

- **Sessions and cookies** authenticate same-origin browser requests — you do
  not need JWT in JS for your own ERB pages.
- **Routes** live in **`config/routes.rb`** — not a client-side router mapping
  `/articles` parallel to Rails.
- **Authorization** runs on the server (Pundit, etc.) — Stimulus may hide UI,
  but it does not enforce security. Anything you hide in JS is still callable
  via direct request.

Repeated from Hotwire: **`fetch` + JSON** for CRUD on pages you fully control
is usually pipeline drift — prefer **`form_with`**, Turbo, and streams.

---

## Defer to Hotwire

For **`data-turbo-*`**, frame targeting, stream templates, morphing, and
*how Stimulus is wired into ERB*: **`../writing-hotwire/references/patterns.md`**.

---

## Anti-Patterns

- **Two bootstraps** — importmap-loaded Turbo plus a separate webpack bundle
  both initializing Stimulus or Turbo.
- **`node_modules` by default** — adding npm for every feature without a build
  requirement.
- **God controllers** — one Stimulus controller doing five unrelated things.
  Split per behaviour.
- **State in closures** — `this.count = 0` in `connect()` instead of a
  `countValue`. Morphing strands it.
- **Leaked listeners** — `connect()` calls `addEventListener` on `window`
  without a matching `removeEventListener` in `disconnect()`.
- **`querySelector` over targets** — bypassing `static targets` and reaching
  into the DOM by selector defeats Stimulus' contract.
- **Hard-coded class strings** — `element.classList.add("bg-red-500")`
  scattered across controllers instead of `static classes`.
- **Global event buses** — `window.dispatchEvent` to coordinate controllers
  instead of `this.dispatch` + outlets.
- **`fetch` + JSON for first-party CRUD** — re-implementing what `form_with`
  and Turbo already do.
- **Embedding secrets in JS** — API keys in the bundle for client-exposed
  trees.
- **`innerHTML = userInput`** — XSS waiting to happen.
- **`alert()` and `console.log`** in production code paths.
- **Micro-frontends** and module federation for a typical Basecamp-shaped
  Rails app — out of scope and opposite of omakase.

---

## Out of Scope

- **React / Vue / Svelte** as the primary application shell replacing Rails
  views.
- **GraphQL** or JSON-first APIs for same-origin pages that could stay
  HTML-first.
- **Deployment** (CDN-only assets, edge workers) — infra; not this doc.
- **Detailed Vite / webpack configuration** — link to upstream docs when you
  adopt a bundler; keep this repo's story at the boundary level.
- **Service workers / PWAs** — separate decision; document if adopted.
- **Native mobile clients** — they consume the same endpoints with their own
  conventions.
