---
name: brainstorming-rails-omakase
description: >-
  Use when shaping Rails features or behavior changes before planning or code —
  unclear scope, multiple valid directions, HTML vs JSON, client-owned vs
  server-owned truth, REST vs RPC-shaped endpoints, premature service objects or
  SPA layers, or duplication of business rules in JavaScript. Symptoms include
  reaching for new gems or microservices first, CRUD flows dressed as bespoke
  protocols, or designs that would fight omakase defaults in an omakase-shaped app.
---

# Brainstorming Into Rails-Shaped Designs

Turn ideas into an approved **requirements spec** through dialogue, with **omakase Rails best practice** as the constraint: majestic monolith, server-owned truth, REST gravity, fat models and thin orchestration, Hotwire-first HTML, and **harness** tactics (`agent_harness_rails/rules/*.mdc`, `writing-*` skills) as the implementation ceiling.

**Announce:** "I'm using the brainstorming-rails-omakase skill."

**Harness rules beat application patterns:** Where the app contradicts harness rules, the spec describes the **correct** omakase direction for new work and notes integration friction — same as **`agent_harness_rails/agents/rails-query.md`**.

## Grounding order (always)

Use the **same order** as **`agent_harness_rails/agents/rails-query.md`** so this skill has the full harness stack at hand — not just the compass.

1. **`agent_harness_rails/skills/rails-omakase-compass/SKILL.md`** — For **architectural** questions (boundaries, "should we…", API vs HTML, where logic belongs, jobs vs request, anything that could pull the app off-Rails or split ownership badly), read the compass **first**. For **purely tactical** questions (e.g. local Hotwire / Stimulus wiring in an otherwise settled design), you may open the relevant **`writing-*`** skill first; still use the **compass** whenever the answer could change solution shape.

2. **Scoped tactical layer** — Read **`agent_harness_rails/skills/writing-*/SKILL.md`** files that match the brainstorm topic (see **Topic → assets** below). Pair with **`agent_harness_rails/rules/*.mdc`** for the same areas — **do not skip** a rule file that applies to what you are designing.

3. **Supplementary reference — required when compass and writing-* leave a gap** — Consult these when a pattern isn't clearly covered above; treat as a required consult for those gaps, not optional enrichment:
   - **`agent_harness_rails/skills/referencing-unofficial-37signals-guide/SKILL.md`** — supplemental patterns and philosophy from the third-party community guide.
   - **`agent_harness_rails/skills/referencing-rails-guides/SKILL.md`** — authoritative Rails API and feature docs.

   Both **inform** the brainstorm — they do **not** override harness rules or skills. If a fetch fails, **report that** per the skill; **do not** invent or assert content from memory.

4. **User's codebase** — If the workspace is a Rails app and the brainstorm is project-specific, read the **relevant** files (models, controllers, routes, policies, etc.) after the harness layers above; tie the spec to what you saw.

**Routing:** Use **Topic → assets** to load **only** the **`writing-*`** skills and **`agent_harness_rails/rules/*.mdc`** files that match the topic — not every file unless the brainstorm is genuinely cross-cutting.

### Topic → assets (load what applies)

| Area | Skill(s) | Rules |
|------|----------|--------|
| Stack shape, boundaries, "where should this live?" | compass (+ `writing-services` if extraction) | `services.mdc`, `models.mdc`, `controllers.mdc` as needed |
| Models, AR, domain | `writing-models` | `models.mdc` |
| Controllers, params, REST | `writing-controllers` | `controllers.mdc` |
| Routes | `writing-routes` | `routes.mdc` |
| Views, helpers, partials | `writing-views` | `views.mdc` |
| Hotwire, Turbo, Stimulus | `writing-hotwire` | `hotwire.mdc` |
| CSS / Tailwind | `writing-css-tailwind` | `css-tailwind.mdc` |
| JavaScript | `writing-javascript` | `javascript.mdc` |
| I18n | `writing-i18n` | `i18n.mdc` |
| Mailers | `writing-mailers` | `mailers.mdc` |
| Jobs, Solid Queue, async | `writing-jobs` | `jobs.mdc` |
| Policies / authorization | `writing-policies` | `policies.mdc` |
| Migrations, schema | `writing-migrations` | `migrations.mdc` |
| Tests | `writing-tests` | `testing.mdc` |
| RuboCop / style gates | `running-rubocop` when relevant to the design | `rubocop.mdc` |
| Naming (classes, methods, columns, routes, specs) | `writing-naming-conventions` | `naming.mdc` |
| Planning / execution context | `writing-rails-plans`, `executing-rails-plan`, `implementing-rails-task`, `reviewing-rails-work` | only when the brainstorm is about **how** to plan or run those workflows in this harness |

Pull in workflow skills only when the conversation is explicitly about those processes — not for routine feature design (those stay behind the HARD-GATE until **`writing-rails-plans`**).

<HARD-GATE>
Do **not** invoke **`implementing-rails-task`**, **`executing-rails-plan`**, or any implementation skill; do **not** write application code, migrations, or tests; do **not** scaffold until you have presented a design and the user has approved it, then written the spec file and passed the user review gate below. This applies to every change regardless of perceived size.
</HARD-GATE>

## Anti-pattern: "Too small to need a spec"

Unexamined assumptions waste the most effort on "small" changes. The spec can be a short paragraph, but you **must** present it, get approval, write it to disk, and get user sign-off on the file before **`writing-rails-plans`**.

## Checklist

Create a task for each item and complete **in order**:

1. **Ground in harness order** — For every substantive turn and before locking a design direction, apply **Grounding order (always)** for the areas this brainstorm touches (compass → scoped **`writing-*`** + **`agent_harness_rails/rules/*.mdc`** → supplementary refs if needed → then relevant app files). Re-run when the topic shifts to a new area (e.g. from routes to jobs). When the app has a `docs/primitives/` tree, this grounding includes `docs/primitives/index.md` (an existing capability makes this brainstorm an **amendment** to it, not a new doc) and `compilation.md` (human-owned constraints that bound every approach you propose) — read both **before proposing approaches**, not after the design is agreed.
2. **Offer visual companion** (if upcoming questions are visual) — **its own message only**; see Visual Companion below.
3. **Ask clarifying questions** — one per message; purpose, constraints, success criteria.
4. **Propose 2–3 approaches** — trade-offs in **Rails terms** (resources vs RPC, HTML vs JSON, sync vs job, model vs controller vs policy), consistent with what you already loaded. For each approach, **state explicitly where the domain logic will live** (model method, callback, scope, concern) — not implicit.
5. **Present design in sections** — scaled to complexity; approval after each section.
6. **Write spec** — default path **`docs/brainstorms/YYYY-MM-DD-<topic>.md`** in the app repo (create `docs/brainstorms` if needed; user or team conventions override). End it with **`## Delivery sequence`** (see **Delivery sequence (in the spec)**) — the ordered deployable slices, one plan each. **When the app has a `docs/primitives/` tree**, also create or update the capability doc (`docs/primitives/capabilities/<name>.md`): the spec's agreed outcomes become one-sentence Intent clauses (`I1`, `I2`, …) and the chosen direction a rough `## Shape` — per `agent_harness_rails/rules/primitives.mdc`. `status: shaping` applies only to docs this brainstorm **creates**; when updating an existing doc (shaping an amendment to a `planned` or `built` capability), leave its status untouched — a brainstorm never downgrades status. What's explicitly out of scope is worth a provenance line. The planner's primitives gate confirms and extends this doc instead of re-deriving intent.
7. **Spec self-review** — placeholders, contradictions, ambiguity, scope; fix inline.
8. **User reviews written spec** — wait for approval or revision requests.
9. **Transition to planning** — invoke **`writing-rails-plans`** only.

## Process flow

```dot
digraph brainstorming_rails {
    "Grounding order\n(compass → writing-* + rules → refs? → codebase)" [shape=box];
    "Visual questions ahead?" [shape=diamond];
    "Offer Visual Companion\n(own message only)" [shape=box];
    "Ask clarifying questions" [shape=box];
    "Propose 2-3 approaches\n(Rails trade-offs)" [shape=box];
    "Present design sections\n(Rails-shaped)" [shape=box];
    "User approves design?" [shape=diamond];
    "Write spec to docs/brainstorms" [shape=box];
    "Spec self-review" [shape=box];
    "User approves spec file?" [shape=diamond];
    "Invoke writing-rails-plans" [shape=doublecircle];

    "Grounding order\n(compass → writing-* + rules → refs? → codebase)" -> "Visual questions ahead?";
    "Visual questions ahead?" -> "Offer Visual Companion\n(own message only)" [label="yes"];
    "Visual questions ahead?" -> "Ask clarifying questions" [label="no"];
    "Offer Visual Companion\n(own message only)" -> "Ask clarifying questions";
    "Ask clarifying questions" -> "Propose 2-3 approaches\n(Rails trade-offs)";
    "Propose 2-3 approaches\n(Rails trade-offs)" -> "Present design sections\n(Rails-shaped)";
    "Present design sections\n(Rails-shaped)" -> "User approves design?";
    "User approves design?" -> "Present design sections\n(Rails-shaped)" [label="no, revise"];
    "User approves design?" -> "Write spec to docs/brainstorms" [label="yes"];
    "Write spec to docs/brainstorms" -> "Spec self-review";
    "Spec self-review" -> "User approves spec file?";
    "User approves spec file?" -> "Write spec to docs/brainstorms" [label="changes requested"];
    "User approves spec file?" -> "Invoke writing-rails-plans" [label="approved"];
}
```

**Terminal state is `writing-rails-plans`.** Do **not** jump to **`implementing-rails-task`**, **`writing-hotwire`**, or other implementation skills from this workflow.

## Rails-shaped design content

Scale sections to complexity. Prefer vocabulary that will survive into **`writing-rails-plans`** without re-litigating philosophy:

| Lens | Cover |
|------|--------|
| **Domain** | Nouns, verbs, state. Model state per the writing-models ladder: an **enum** for a single obvious lifecycle, a **state record** (child row whose existence *is* the state) when you need who/when or joins — never accumulating boolean flags or timestamp-column proliferation (`published_at` + `archived_at` + `deleted_at`). For request context (who, which account), thread through `Current` attributes (`Current.user`, `Current.account`) rather than method parameters or redundant queries. |
| **REST surface** | Resources and conventional verbs. **When an action seems RPC-shaped, first model it RESTfully** — what resource does this action create, update, or destroy? (`send_invoice` → `POST /invoices/:id/deliveries`; `approve` → `POST /approvals`). Only after that attempt fails should you document the exception, stating what you tried and why no conventional mapping fits. |
| **Truth** | Server owns persisted state, authorization, **derived state** (totals, computed fields, summaries), and access context (user role, account). Client must not be the source of truth for any of these — including caching roles in localStorage or computing summaries from already-rendered data. |
| **Account scoping** | If the app has accounts, confirm: is every resource in this design scoped to an account? How does the query enforce scope? Unscoped queries are where cross-tenant leaks begin — catch it here, not in implementation. |
| **Logic placement** | State explicitly where domain rules live for each proposed approach — model method, callback, scope, concern. If logic doesn't fit a model or concern, name the specific collaborator type (form object for multi-model forms, value object for domain types, query object for complex scopes) and explain why a model method cannot handle it. Generic service objects as orchestrators are not an option. Is behavior cross-cutting across multiple models? Name the concern. |
| **UI** | Hotwire (Turbo, Stimulus) and server-rendered HTML first; extra JS only with explicit need (see `agent_harness_rails/rules/hotwire.mdc`, `agent_harness_rails/rules/javascript.mdc`). |
| **Authorization** | Who may do what — aligns with **Pundit** / policies at the boundary (`agent_harness_rails/rules/policies.mdc`). |
| **Async** | Ask first: does this actually need to be async (slow, unreliable third-party, high-volume side effect)? "Separation of concerns" is not a reason for a job. When async is warranted, jobs are thin wrappers around model behavior (`agent_harness_rails/rules/jobs.mdc`). |
| **Data** | Migrations only at planning/implementation — here, entities and constraints only as needed for decisions. Prefer simple foreign keys and denormalized columns over junction tables and polymorphic joins until domain complexity is proven. |
| **Testing intent** | Behaviour-first, right layer — delegate detail to **`writing-tests`** / `agent_harness_rails/rules/testing.mdc` in the plan phase. |

**Design for clear Rails boundaries:** Vertical slices (resource/feature cohesion), one obvious home for domain rules (models, concerns — not generic service registries). If the brainstorm drifts toward "generic executor," "repository on thin models," or duplicated rules in JS, stop and realign with **`rails-omakase-compass`**.

### Delivery sequence (in the spec)

Every spec ends with a **`## Delivery sequence`**: an ordered list of the
**deployable slices** this capability ships in, each naming the Intent clauses it
satisfies. Clause IDs are already the currency between spec, capability doc, and
plan — reuse them rather than restating requirements.

```markdown
## Delivery sequence

1. **Invitation records** (I1, I2) — schema, model, policy. Deployable: nothing
   links to it yet.
2. **Sending and accepting** (I3, I4) — routes, controllers, mailer, views.
   Deployable: the flow works end to end for admins.
3. **Expiry and resend** (I5) — deployable: refines a flow already live.
```

Rules for the sequence:

- **A slice must be worth shipping on its own**, not merely severable. If an
  early slice delivers nothing a user or the system benefits from and only
  exists to make the list longer, fold it into the next one. **One slice is a
  valid answer** — most features are one deployable change, and inventing
  boundaries to satisfy this section is worse than not having it.
- **Never split a vertical slice horizontally.** "Migration slice, then model
  slice, then controller slice" is the anti-pattern
  (`writing-rails-plans`), not a delivery sequence. Each slice runs
  schema → model → policy → routes → controller → views for the part it covers.
- **Additive first.** Prefer sequences where early slices add unreached code over
  ones needing feature flags; reach for a flag only when a slice genuinely
  changes behaviour already in front of users.
- **Every active clause lands in exactly one slice.** A clause in no slice is
  unshipped scope; a clause in two is an unclear boundary.

**One plan per slice, written just-in-time.** The sequence is the spec's; the
plans are written **one at a time, as each slice comes up** — not all up front.
Drafting later plans before earlier slices are executed spends full review passes
on documents that execution will invalidate.

**Working in existing codebases:** Follow patterns that match **harness rules**. Where the app contradicts those rules, the spec should describe the **correct** Rails-shaped direction for new work (same rule as **`implementing-rails-task`** and **`writing-rails-plans`**) and note integration friction — not silently entrench anti-patterns.

## The process (mirrors superpowers brainstorming)

**Understanding the idea**

- After **Grounding order (always)**, use what you read in the app (step 4) to describe current state — verify claims; do not assume tables or routes exist without checking when that matters.
- If the request bundles multiple **independent subsystems**, decompose first; brainstorm one slice per cycle (spec → plan → implementation). Each subsystem is its own capability, its own spec, its own plan.
- If the request is **one** capability that is simply **too large to ship in one go**, do **not** split the brainstorm — split the **delivery**. A big feature is usually one cohesive subsystem with a lot of surface, so the "independent subsystems" test above never fires on it and the result is a single enormous plan. One spec and one capability doc still cover the whole outcome; the spec's **`## Delivery sequence`** (see **Delivery sequence (in the spec)** above) breaks it into deployable slices that become **separate, sequenced plans**.
- One question per message; prefer multiple choice when it speeds alignment.
- Clarify purpose, constraints, success criteria.

**Exploring approaches**

- Always offer **2–3** options when meaningful, with trade-offs in **Rails** terms.
- State a recommendation and why — omakase defaults win until a **measured** cost appears (**`rails-omakase-compass`**).

**Presenting the design**

- Sections sized to nuance; pause for approval between sections.
- Include architecture, data flow, errors, and **where tests will eventually prove behaviour** (not full RSpec here — intent only).

## After the design

**Documentation**

- Write the validated spec to **`docs/brainstorms/YYYY-MM-DD-<topic>.md`** (unless the user names another path).
- When the app has a `docs/primitives/` tree, seed the capability doc per checklist step 6 (`status: shaping`; Intent clauses from the spec's outcomes; one `shaped` provenance line noting explicit scope exclusions) and add its `index.md` line.
- Commit the spec when the repo is yours to commit; otherwise leave changes ready for the human.

**Spec self-review**

1. Placeholder scan — no TBD that blocks planning.
2. Internal consistency — behaviour vs boundaries.
3. **Scope and delivery** — `## Delivery sequence` is present and each slice is
   independently deployable **and** worth shipping alone; every active clause
   lands in exactly one slice; no slice is a horizontal layer split; each slice
   is sized to ship as one reviewable PR (see `writing-rails-plans`
   § PR and deployment scope), so oversized scope is cut here, not discovered
   at planning. A **single-slice** sequence is correct for most features —
   check that any split earns itself rather than that a split exists.
4. Ambiguity — resolve dual interpretations.

**User review gate**

> Spec written to `<path>`. Please review and say if you want changes before we write the implementation plan.

Wait for response; revise and re-review until approved.

**Planning**

- Invoke **`writing-rails-plans`** with the spec as input. **Only** that skill follows this one.
- When the spec has **more than one** slice in its `## Delivery sequence`, plan the **first slice only** — name the slice and its clause IDs in the handoff so the planner scopes to it. Later slices are planned when they come up, against a codebase the earlier slices have already changed.

## Key principles

- **One question at a time**
- **Multiple choice when it helps**
- **YAGNI** on features and on architectural novelty
- **Alternatives** before commitment
- **Incremental validation** of the design
- **Omakase first** — documented exceptions, not silent drift

## Visual companion

When upcoming questions will benefit from mockups, layout comparisons, or diagrams in a browser, offer the companion **once**, in **its own message** (no other content):

> Some of what we're working on might be easier to show in a web browser — mockups, diagrams, comparisons. This can be token-intensive. Want to try it?

Wait for an answer. If declined, continue in text.

Per question: use visuals only when **seeing** beats **reading** (layouts, wireframes). Pure trade-off or requirement questions stay in chat.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Reading the app before compass / **`writing-*`** / **`agent_harness_rails/rules/*.mdc`** on architectural questions | Follow **Grounding order (always)** — same order as **`rails-query`**. |
| Loading every `writing-*` and rule without routing | Use **Topic → assets**; expand only when cross-cutting. |
| Coding or migrating during brainstorm | Stop; complete spec and **`writing-rails-plans`** first. |
| Defaulting to JSON/SPA for app flows | Re-read **HTML as primary interface** in **`rails-omakase-compass`**. |
| "If an RPC-shaped action is unavoidable…" | It almost never is. Model it RESTfully first — find the resource the action creates, updates, or destroys. Document exception only after the attempt. |
| New "service object" as the first idea | Ask what **model** or **concern** owns the behaviour (`agent_harness_rails/rules/services.mdc`). Name the specific collaborator type if extraction is genuinely needed. |
| "Justified collaborator" as rationale for extraction | Justify specifically: form object, value object, query object. "Justified" without specifics is how service layer creep starts. |
| Skipping compass on "small" features | Skim **`rails-omakase-compass`** whenever boundaries move. |
| Skipping account scoping on any resource design | Ask: is every query in this design scoped to the account? |
| Skipping `Current` attributes for request context | Thread `Current.user` / `Current.account`; do not pass context as method parameters or re-query it redundantly. |
| Premature namespacing (`Admin::`, `Api::V1::`) | Ask: does this namespace pay for itself **today**? Speculative structure is YAGNI. |
| Speculative polymorphism | Build for what exists today; extract when the second concrete case actually arrives. |
| Over-normalized schema for unproven domain richness | Prefer simple foreign keys and denormalized columns; add junction tables and polymorphic joins when domain complexity is demonstrated. |
| Async for "separation of concerns" | Job if it's slow, unreliable, or high-volume. Not as an architectural default. |
| Big cohesive feature sent to planning as one plan | "Independent subsystems" does not fire on a single large capability. Use `## Delivery sequence` — one spec, deployable slices, one plan each. |
| Splitting a spec into slices that cannot ship alone | Severable is not shippable. Fold it into the next slice, or keep one slice. |
| Drafting every slice's plan up front | Plan one slice at a time; execution of slice 1 changes what slice 2's plan should say. |
| Skipping user approval of the **file** | Chat agreement is not enough — gate on reviewed spec on disk. |

## Related

- **`agent_harness_rails/agents/rails-query.md`** — same **Grounding order** and **Topic → assets** table (readonly Q&A; this skill is brainstorm + spec).
- **`agent_harness_rails/skills/rails-omakase-compass/SKILL.md`** — whether the shape fits.
- **`agent_harness_rails/skills/writing-rails-plans/SKILL.md`** — next step after an approved spec.
- **`agent_harness_rails/skills/implementing-rails-task/SKILL.md`** — after a plan exists, not during brainstorm.
