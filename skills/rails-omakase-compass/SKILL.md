---
name: rails-omakase-compass
description: >-
  High-level decision lens for Rails work in the Pitchd plugin tradition —
  omakase defaults, server-owned truth, REST gravity, majestic monolith, and
  when to simplify vs extract. Use before debating architecture, when choosing
  HTML vs API, or when a change feels "off-Rails"; defers HOW to writing-* skills
  and rules/*.mdc. Not for Stimulus/Turbo syntax, plan templates, or file layout.
---

# Rails Omakase Compass

<objective>
Answer **whether** a direction fits **37signals-shaped Rails** and **this
plugin’s stack** — not **how** to implement it. Tactical detail lives in
`skills/writing-*` and `rules/*.mdc`; this skill is the **compass**: defaults,
tradeoffs, smells as **questions**, and **documented exceptions**.
</objective>

## When to use this skill

| Use the compass | Use a `writing-*` skill instead |
|-----------------|--------------------------------|
| "Should this be JSON or HTML?" | "How do I wire this Turbo Stream?" |
| "Is this the right boundary (job vs request)?" | Exact Stimulus controller shape |
| "Are we inventing a framework?" | Route macros, `params.expect`, patterns |
| "Does the client own too much state?" | View partial structure, CSS patterns |

**Announce:** "I'm using the rails-omakase-compass skill for solution shape."

## Principles (decision tests, not slogans)

### 1. Omakase first

Rails’ choices are the default until **measured cost** appears (complexity,
team boundary, regulation — not taste alone).

**Before adding a layer, answer:** What concrete problem does the default stack
fail to solve?

### 2. Server owns truth

Persisted state and authorization live on the **server**; the browser reflects
and requests. The client must not be the **source of truth** for server-owned
flows.

**Smell:** Business rules duplicated in JS without a server round-trip or clear
sync story.

### 3. HTML as the primary interface

Prefer **full-page and fragment HTML** for app flows. A parallel JSON surface
for the **same** user journey needs an explicit product or integration reason.

**Defer:** `writing-hotwire`, `writing-views`, `writing-controllers`.

### 4. RESTful gravity

Model URLs and controllers around **resources** and conventional verbs. RPC
shapes are **exceptions** — name the exception (see `writing-routes`,
`writing-controllers`).

### 5. Fat models / rich domain, thin orchestration

Business vocabulary and rules belong in **models and obvious collaborators**,
not in controller scripts. **Defer:** `writing-models`, `writing-controllers`.

### 6. Boring over clever

Linear, readable code beats indirection. **Extract on repetition**, not on
ceremony — new objects need a **clear job**; thin wrappers around Active Record
are a smell (see `writing-services`, `rules/services.mdc`).

### 7. One deployable monolith by default

Split boundaries only with **evidence** (team, scale, compliance), not
aesthetics.

### 8. Progressive enhancement

JS **improves** UX; core actions should work without depending on undocumented
client-only behavior unless that is an explicit bet.

**Defer:** `writing-javascript`, `writing-hotwire`.

### 9. Document exceptions

When convention is violated, a **one-line why** in the plan or PR beats tribal
knowledge.

## Smells (frame as questions)

Ask — do not treat answers as automatic fail:

- Are we **dressing up CRUD** with a bespoke protocol?
- Is there **invented framework** (generic executors, repositories on thin models)
  where Rails objects would suffice?
- Does **authorization** live at the boundary (`writing-policies`) or leak into
  ad hoc checks?
- Are we testing the **same behaviour** in three layers without a split of
  concerns (`writing-tests`)?

## Conflict resolution

- **`rules/*.mdc` and `writing-*` skills** win on **specifics** (this repo’s HOW).
- **This compass** wins on **kind of solution** — e.g. "this drifts toward a
  client-as-source-of-truth SPA" — unless the user or plan has **explicitly**
  chosen that product shape (API-first, SPA, public JSON API); then treat it as
  a **documented exception** and review tactics for consistency with that choice.

## Where to go next (tactical index)

Read only what the task touches:

| Area | Skill |
|------|--------|
| Plans / task breakdown | `writing-plans` |
| Models / concerns / domain | `writing-models` |
| Controllers / Turbo responses | `writing-controllers` |
| Routes / REST mapping | `writing-routes` |
| Hotwire / Turbo / Stimulus | `writing-hotwire` |
| Views / partials | `writing-views` |
| JS | `writing-javascript` |
| CSS / Tailwind | `writing-css-tailwind` |
| I18n | `writing-i18n` |
| Mailers | `writing-mailers` |
| Policies / Pundit | `writing-policies` |
| Service objects (when justified) | `writing-services` |
| Background jobs / ActiveJob | `writing-jobs` |
| Database migrations | `writing-migrations` |
| Tests / RSpec | `writing-tests` |

## What this skill deliberately omits

Patterns, checklists, APIs, and file layout — those are **longer** in sibling
skills so this file stays a **compass**.
