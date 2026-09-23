# JavaScript Patterns

Worked mechanics for JS delivery and Stimulus in a Rails app. The normative
rules — one stack per app, boundary, hygiene, fetching, accessibility,
performance, anti-patterns, verification — live in
**`agent_harness_rails/rules/javascript.mdc`**. Turbo Drive, Frames, Streams,
and Stimulus *behaviour in templates* (ERB data attributes, frame markup,
stream actions) live in
**`agent_harness_rails/skills/writing-hotwire/references/patterns.md`**.
Refactoring an existing fleet of Stimulus controllers — merging, splitting,
spec coverage — lives in
**`agent_harness_rails/skills/refactoring-stimulus-controllers/SKILL.md`**.

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
├── controllers/
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

## Hygiene Gotchas

Rules: **`agent_harness_rails/rules/javascript.mdc`** § Modern JavaScript
Hygiene. Two shapes worth pinning:

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

```js
// app/javascript/lib/csrf.js — named exports for shared code
export function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content
}

export function csrfHeaders() {
  return { "X-CSRF-Token": csrfToken() }
}
```

---

## Stimulus Controllers — Anatomy

Each controller file is named for its behaviour, registered automatically via
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
connect()      // controller attached (initial render, Turbo navigation, element replacement)
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

Turbo morphing rewrites the DOM underneath a connected controller: for a
preserved element `connect()` does **not** re-run (the closure keeps its old
value while the markup changes), and an unmatched element is replaced
outright — a fresh controller instance whose closures reset. Either way,
closure state and the DOM drift apart. Values stored in `data-*-value`
attributes survive both cases: morphs that change them fire
`xValueChanged`, and a fresh instance reads them on `connect()`.

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
**`agent_harness_rails/skills/refactoring-stimulus-controllers/SKILL.md`**.

---

## Fetching from JavaScript

For first-party pages, the right answer is almost always **`form_with` + Turbo**
(see `agent_harness_rails/skills/writing-hotwire/references/patterns.md`).
Rules — when `fetch` is warranted, CSRF, error handling, no secrets:
**`agent_harness_rails/rules/javascript.mdc`** § Fetching from JavaScript.

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

Don't manually parse JSON when an HTML/Turbo response would do.

---

## Propshaft and Assets

**Propshaft** (Rails 7+ default) serves **`app/assets`**, **`vendor/assets`**,
and manifest paths — fingerprinted assets, no Sprockets pipeline. Put images,
fonts, and compiled CSS there per team conventions.

**Sprockets**-legacy apps: same *mental* rule — one pipeline, do not fight it
with ad hoc copies in `public/` for assets that belong in the manifest.

This skill does **not** duplicate Tailwind or view styling guidance — templates
and utilities: **`agent_harness_rails/skills/writing-views/references/patterns.md`**; pipeline and
global CSS: **`agent_harness_rails/skills/writing-css-tailwind/references/patterns.md`**.

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
