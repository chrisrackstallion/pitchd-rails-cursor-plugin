# Stimulus Refactor Patterns

This document is the **playbook** for the audit-and-execute work. Anatomy
basics (what `static targets` is, how `dispatch` works) live in
**`rails-agent-harness/skills/writing-javascript/references/patterns.md`** § Stimulus. ERB-side
wiring lives in **`rails-agent-harness/skills/writing-hotwire/references/patterns.md`**.

---

## Discovery Commands

The exact shell snippets the skill runs during step 2.

```bash
# Every controller file
find app/javascript/controllers -name "*_controller.js"

# Every attachment in templates
grep -rEn 'data-controller="' app/views

# Every action/target/value/class/outlet attribute
grep -rEn 'data-(action|[a-z][a-z0-9-]*-(target|value|class|outlet))=' app/views

# Cross-controller wiring inside JS
grep -rEn 'static outlets|this\.dispatch\(' app/javascript/controllers

# Any helper / Ruby code emitting controllers (rare but possible)
grep -rEn 'controller: "[a-z]' app/helpers app/models app/views
```

For each controller name `foo`, the migration must consider every one of:

- `data-controller="foo"` (alone or composed: `data-controller="foo bar"`)
- `data-foo-target="…"`
- `data-foo-<name>-value="…"`
- `data-foo-<name>-class="…"`
- `data-foo-<name>-outlet="…"`
- `data-action="…->foo#…"`
- `foo:eventName` listeners (dispatched events)
- `static outlets = ["foo"]` in other controllers

A pre-delete grep for all of those is non-negotiable.

---

## The Controller Map (Audit Artifact)

A markdown table dumped to `tmp/refactor-stimulus-<cluster>-plan.md`. Example
header and a couple of rows:

| Controller | Purpose (1 sentence) | Pages | Targets | Values | Outlets | Dispatched events | External listeners | Findings | Verdict |
|------------|----------------------|-------|---------|--------|---------|---------------------|---------------------|----------|---------|
| `reveal` | Toggle a panel open/closed with `aria-expanded` sync | articles/show, settings/index | panel, toggle | open: Boolean | — | reveal:opened | — | OK | KEEP |
| `disclosure` | Toggle a panel | articles/show | panel | — | — | — | — | Duplicate of `reveal`; missing static values; uses querySelector | MERGE → `reveal` |
| `form` | Debounces input **and** submits via fetch **and** flashes a success class | settings/index | input, status | url: String | — | form:submitted | window:keydown | God controller; closure state; missing CSRF | SPLIT → `debounce` + `autosubmit` |

If the table won't fit on one screen per cluster, the cluster is too big —
split the work.

---

## Verdict Worked Examples

### KEEP — already in good shape

```js
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static classes = ["copied"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    this.flash()
  }

  flash() {
    this.element.classList.add(...this.copiedClasses)
    setTimeout(() => this.element.classList.remove(...this.copiedClasses), 1500)
  }
}
```

Single behaviour, static declarations, no closure state, no leaked listeners.
Confirm the canonical system spec exists; otherwise add one.

### REWRITE — same behaviour, brought to standard

Before / after pair shown in the parent SKILL § Execute the Verdicts.
Common rewrites:

| Smell | Rewrite |
|-------|---------|
| `this.foo = …` in `connect()` referenced later | `static values = { foo: { type: …, default: … } }`; read `this.fooValue` |
| `this.element.querySelector(".thing")` | `static targets = ["thing"]`; read `this.thingTarget` |
| `element.classList.add("bg-red-500")` | `static classes = ["error"]`; `this.errorClasses` in JS, `data-foo-error-class="bg-red-500"` in ERB |
| `this.button.addEventListener("click", …)` on a child of `this.element` | `data-action="foo#bar"` in ERB |
| `connect()` adds `window.addEventListener` with no `disconnect` | Bind handler in `connect`, remove in `disconnect` |
| `this.timer = setTimeout(…)` with no cleanup | Store on `this`, `clearTimeout` in `disconnect` |
| Manual focus juggling without saving / restoring | Save previously-focused element on open, restore on close |

### MERGE — same behaviour duplicated

```js
// Before
// app/javascript/controllers/reveal_controller.js  — uses static targets
// app/javascript/controllers/disclosure_controller.js  — uses querySelector

// After
// reveal_controller.js absorbs the (small) extra behaviour from disclosure
// disclosure_controller.js DELETED
```

ERB diff (the bulk of MERGE work):

```diff
-<div data-controller="disclosure">
-  <button data-action="disclosure#toggle" aria-expanded="false">…</button>
-  <div class="hidden">…</div>
+<div data-controller="reveal" data-reveal-hidden-class="hidden">
+  <button data-reveal-target="toggle"
+          data-action="reveal#toggle"
+          aria-expanded="false">…</button>
+  <div data-reveal-target="panel" class="hidden">…</div>
 </div>
```

Run a grep for every `disclosure*` data-attribute after the rename; nothing
should match.

### SPLIT — one controller, two behaviours

```js
// Before
// form_controller.js — 180 lines, debounces input, posts via fetch, flashes
// status, manages a "dirty" indicator. Four responsibilities, one file.

// After
// debounce_controller.js     — emits a `debounce:fired` CustomEvent
// autosubmit_controller.js   — listens for `debounce:fired`, posts via fetch
// dirty_indicator_controller.js — toggles a class on form input
```

ERB:

```diff
-<form data-controller="form" data-form-url-value="<%= search_path %>">
-  <input data-form-target="input" />
-  <div data-form-target="status"></div>
+<form data-controller="debounce autosubmit dirty-indicator"
+      data-debounce-delay-value="200"
+      data-autosubmit-url-value="<%= search_path %>"
+      data-action="debounce:fired->autosubmit#submit
+                   input->dirty-indicator#mark">
+  <input data-debounce-target="input"
+         data-action="input->debounce#schedule" />
+  <div data-autosubmit-target="status"></div>
 </form>
```

Split rules:

- Each new controller has a verb in its name and a one-sentence purpose.
- New controllers communicate via `CustomEvent` or outlets, not via reaching
  into each other's targets.
- The original controller file is **deleted** at the end of the batch, not
  left as a shim.

### DELETE — unused or duplicated

Required preconditions (re-stated from the SKILL):

- `grep -rEn 'data-controller="<name>"' app/views` returns nothing.
- `grep -rEn 'data-<name>(-|"|=)' app/views` returns nothing.
- No other controller declares `static outlets = ["<name>"]`.
- No spec drives behaviour that depends on it.

Then delete the file and any orphan specs. If a spec was the *only* place the
controller was exercised, the spec was likely testing nothing real — drop it
with a note in the report.

---

## Lifecycle Cleanup Checklist

For every controller that reaches outside `this.element`:

- [ ] Handler bound once in `connect`, removed in `disconnect`
- [ ] `setTimeout` / `setInterval` IDs stored on `this`, cleared in `disconnect`
- [ ] `MutationObserver` / `IntersectionObserver` / `ResizeObserver` disconnected in `disconnect`
- [ ] `AbortController` for in-flight fetches aborted in `disconnect`
- [ ] Third-party widgets destroyed (`tippy.destroy()`, `chart.destroy()`, etc.) in `disconnect`
- [ ] No state held in `this` that won't be re-derived on the next `connect`

---

## DOM-Derived State — Worked Example

The morphing failure mode:

```js
// Renders fine on first load; goes blank after a Turbo morph
connect() {
  this.count = 0
  this.render()
}

increment() {
  this.count += 1
  this.render()
}

render() {
  this.displayTarget.textContent = this.count
}
```

After a morph, one of two things happens — and closure state loses either
way. A preserved element keeps its controller instance: `connect()` does
**not** re-run, so `this.count` holds its old value while the morph rewrites
the element's children from the server's HTML. An unmatched element is
replaced outright: a fresh controller instance, `this.count` back to 0
regardless of what the user had counted to. The number on screen and the
number in the closure disagree.

The fix is to put state in the DOM:

```js
static values = { count: { type: Number, default: 0 } }

connect() {
  this.render()
}

increment() {
  this.countValue += 1
}

countValueChanged() {
  this.render()
}

render() {
  this.displayTarget.textContent = this.countValue
}
```

Now `data-foo-count-value` is the source of truth — it's a regular DOM
attribute, so a morph that changes it fires `countValueChanged`, and a
replaced element's fresh controller instance reads it on `connect()`.

---

## Canonical Stimulus System Spec — Recipes

These are the only shapes that should land in `spec/system/` after the
refactor.

### Recipe: toggle / disclosure / reveal

```ruby
RSpec.describe "Disclosure", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "expands and collapses a disclosure" do
    sign_in create(:user)
    visit page_that_uses_reveal_path

    expect(page).to have_selector("button[aria-expanded='false']", text: "Details")
    click_button "Details"
    expect(page).to have_selector("button[aria-expanded='true']", text: "Details")
  end
end
```

### Recipe: clipboard / copy

```ruby
RSpec.describe "Clipboard", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "flashes a confirmation when copying" do
    sign_in create(:user)
    visit page_with_clipboard_path

    click_button "Copy"
    expect(page).to have_css("[data-controller='clipboard'].copied")
  end
end
```

Asserting the `copied` class is fine when the *visible* behaviour the user
sees is exactly that class (the controller's contract). Don't reach into JS
internals.

### Recipe: debounced auto-submit

```ruby
RSpec.describe "Search", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "submits the search after the user stops typing" do
    create(:article, title: "Rails")
    sign_in create(:user)

    visit search_path
    fill_in "Search", with: "Ra"
    expect(page).to have_content("Rails", wait: 2)
  end
end
```

`wait:` is Capybara's auto-waiting; never `sleep`.

### Recipe: live-updating Turbo Stream after Stimulus event

```ruby
RSpec.describe "Live comments", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "shows the comment after posting" do
    article = create(:article)
    sign_in create(:user)

    visit article_path(article)
    fill_in "Comment", with: "Hello"
    click_button "Post Comment"
    expect(page).to have_content("Hello")
  end
end
```

This is more a Turbo Stream test than a Stimulus test, but it's the most
common shape — Stimulus often coordinates the form submit and the stream
landing.

---

## Picking the "Simplest Page"

When a controller appears on three pages, the canonical system spec lives on
the **simplest** one. Heuristics:

1. **Fewest collaborating features** — pick the page where the controller
   isn't tangled up with five other behaviours under test.
2. **Fewest fixtures required** — pick the page that needs the least setup.
3. **Most stable copy** — pick the page where the button text / labels are
   least likely to change.
4. **Existing spec home** — if one of the pages already has a spec for this
   controller, keep that one and delete duplicates elsewhere.

If two pages are equally simple, pick the one that exists in harness examples
already (article-shaped resources) — easier for reviewers to match against.

---

## Common Refactor Clusters

Patterns that come up repeatedly. Group by cluster and refactor a cluster
per session.

### Disclosure family

`reveal`, `disclosure`, `accordion`, `details_panel`, `expand`, `collapse` —
all toggling visibility. Pick one canonical name (`reveal` is shortest), one
controller with `panel`, `toggle` targets, `open` value, `hidden` class.

### Dropdown / popover family

`dropdown`, `menu`, `popover`, `flyout` — open/close with click-outside
dismiss. Often *two* controllers: `dropdown` (open/close) + `dismiss`
(click-outside-to-close). The dismiss behaviour is reusable across modals,
popovers, slide-overs — split it out.

### Form helpers family

`autosubmit`, `debounce`, `dirty_indicator`, `confirm_submit`,
`disable_with`, `character_count`. Each is one verb — each is its own
controller. Composed in ERB: `data-controller="debounce autosubmit
disable-with"`.

### Modal / overlay family

`modal`, `slide_over`, `drawer`, `dialog` — open/close overlays, manage
focus, trap focus, restore on close. Usually one controller per *visual
treatment* (modal vs slide-over) if the layout is different; share an outlet
to `dismiss` for click-outside.

### Realtime / Turbo family

`broadcast_refresh`, `stream_listener` — usually don't need custom
controllers; Turbo Streams handle this. If a controller is "listening to a
broadcast and calling `Turbo.renderStreamMessage`", delete it.

### Third-party integrations

`tippy`, `chart`, `flatpickr`, `tom_select` — wrap the library. One
controller per library. Initialize in `connect`, destroy in `disconnect`.
Don't put two libraries in one controller.

---

## Anti-Patterns Specific to Refactoring

| Anti-Pattern | Instead |
|--------------|---------|
| "Rename and we'll fix the data attributes later" | Migrate ERB in the same batch; orphan attributes silently break behaviour |
| Splitting a 60-line controller because the rules say split | Split when responsibilities are *independently useful*, not on LOC alone |
| Merging two controllers because they share two methods | Shared methods → `lib/<name>.js` module; controllers stay separate if behaviour differs |
| Deleting an unused controller without checking helpers | `grep` everywhere `data-controller` might be emitted (helpers, mailers, JSON-embedded HTML) |
| Keeping a "shim" controller that just re-exports another | Delete; the rename is the rename |
| Writing one system spec per (controller × page) cell | One per controller, on the simplest page |
| Letting the spec count grow during refactor | Net spec count goes **down**; Stimulus dedup is the headline win |
| Skipping the audit plan because "the changes are small" | The plan is the reviewer's contract; always write it |
| Mixing JS refactor with server refactor in the same PR | Two diffs are reviewable; one mixed diff isn't |
