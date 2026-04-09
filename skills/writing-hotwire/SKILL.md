---
name: writing-hotwire
description: >-
  Build Hotwire-first UIs — Turbo Drive, Frames, Streams, morphing, broadcasts,
  and Stimulus — with server-rendered HTML as the source of truth. DHH/37signals
  style: redirect before frames before streams; small Stimulus controllers; no
  accidental SPA. Use when adding Turbo frames or streams, Stimulus behaviour,
  real-time updates, modal/inline-edit flows, or when front-end work drifts
  toward client-side routing or JSON-first CRUD for same-origin pages.
---

# Writing Hotwire (Turbo + Stimulus)

<objective>
Ship server-rendered Rails apps where Turbo handles navigation and partial
updates and Stimulus handles focused DOM behaviour. The HTML the server sends
is the contract — not a parallel data model in JavaScript. Prefer full-page
redirects and morphing over bespoke stream choreography; use Turbo Streams when
multiple DOM targets must update in one response; use Stimulus when HTML plus
Turbo is not enough. Follow DHH/37signals conventions: omakase stack, clarity
over client-side framework patterns, and progressive enhancement.
</objective>

## When to Use This Skill

| Use | Defer |
|-----|--------|
| Frames, lazy frames, `data-turbo-*` | Dedicated API clients — separate API conventions |
| `format.turbo_stream`, stream templates | Replacing Rails with React/Vue for app chrome |
| Stimulus targets, actions, values | Heavy realtime games — different constraints |
| `broadcasts_*`, `turbo_stream_from`, morph meta | Infra/deploy — out of scope |

**Importmap, bundlers, and `application.js` wiring** are not this skill — see **`../writing-javascript`**.

**Tailwind / global CSS** — add or remove utility classes from Stimulus; do not duplicate a styling architecture here — **`../writing-css-tailwind`**, **`rules/css-tailwind.mdc`**.

## Process

### 1. Pick the Response Shape

Work top-down (details in `references/patterns.md`):

1. **Full page** — `redirect_to` on success; `render` + 422 on failure. Enough for most CRUD.
2. **Turbo Frame** — region swaps without full navigation; validation errors stay in the frame.
3. **Turbo Stream** — multiple targets or modal-close + background refresh in **one** response — last resort.

### 2. Wire Forms and Frames

Use **`form_with`**. Set **`data-turbo-frame`** when a form posts into a named frame. Keep frame **`id`s** stable (`dom_id(record)`). Prefer **`button_to`** for mutations, **`link_to`** for GET.

### 3. Add Stimulus Last

Add a Stimulus controller only when behaviour is not expressible as HTML + Turbo (toggle UI, focus, keyboard shortcuts). Keep controllers **single-purpose**; derive state from the DOM (targets, values) so **morphing** does not strand state.

### 4. Real-Time and Broadcasts

Prefer model helpers like **`broadcasts_refreshes_to`** + morphing when the whole page can refresh. Use granular **`broadcast_*`** when lists need surgical updates. The submitter still gets a normal redirect or stream in the same request — do not rely on broadcasts alone for their UX.

### 5. Keep Controllers Thin

Compose stream payloads in **`ApplicationController`** helpers or concerns — not ten-line **`turbo_stream`** arrays inline in every action.

## Verification

- [ ] Response hierarchy is explicit: full page → frame → stream — not “streams first.”
- [ ] No duplicated **routing** or **authorization** in client JS for first-party pages.
- [ ] Forms use Rails helpers; Turbo semantics are intentional (`turbo_confirm`, `data-turbo-frame`).
- [ ] Stimulus: one behaviour per controller; cleanup in `disconnect` when needed.
- [ ] Frames have stable ids; links target the correct frame or `_top` **intentionally**.
- [ ] Stream templates are named (`action.turbo_stream.erb`); broadcasts tied to domain events.
- [ ] Validation errors use **`render` + :unprocessable_content**, not redirects or stream hacks.

## References

- [references/patterns.md](references/patterns.md) — controller responses, frames, streams, Stimulus, morphing, broadcasts, accidental SPA anti-patterns.
- [../writing-javascript/references/patterns.md](../writing-javascript/references/patterns.md) — importmap vs bundling, Stimulus file location, asset pipeline boundary.
