---
name: writing-plans
description: >-
  Write implementation plans for multi-step Rails work before touching code —
  vertical REST slices, DHH/37signals conventions, and this plugin's rules and skills.
  After drafting, plan review uses the pitchd-rails-reviewer subagent
  (reviewing-pitchd-rails skill, Phase plan). Use when turning a spec into tasks,
  planning a feature, or breaking work into checklisted steps.
---

# Writing Rails Implementation Plans

<objective>
Produce **implementation plans** a skilled developer can follow without guessing
your codebase: exact paths, real Ruby snippets, **RSpec** commands with expected
outcomes, and **Rails-shaped** decomposition. Assume the reader knows Ruby and
Rails but not your app — not that they need hand-holding on “what a test is.”

Plans follow **37signals-style Rails**: **fat models**, **thin controllers**,
**REST-first routing**, **Pundit** at the boundary, **Hotwire** for HTML UX,
**no fake service layer** — and the **testing philosophy** in
`skills/writing-tests/SKILL.md` / `rules/testing.mdc` (RSpec + FactoryBot).
</objective>

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

## Philosophy (DHH / Pitchd Rails)

- **Vertical slices over layers:** Prefer tasks that complete **one resource’s
  slice** (schema → model → policy → routes → controller → views → specs) over
  scattering “all models, then all controllers.”
- **REST is the vocabulary:** New behavior is usually **new resources** or
  **standard CRUD**, not RPC routes — see `rules/routes.mdc`. If the plan adds
  `post :publish`, it needs a **one-line justification** or a **nested resource**
  / `update` shape instead.
- **Domain logic lives on the model** (and concerns, form objects, jobs — not
  `app/services` wrappers). Plans must not introduce **`SomethingService#call`**
  that only forwards to Active Record — see `rules/services.mdc`.
- **Authorization is explicit:** Tasks must name **policy** changes (`authorize`,
  `policy_scope`) — see `rules/policies.mdc`.
- **UI is server-rendered first:** Turbo Drive → Frames → Streams as complexity
  grows — see `rules/hotwire.mdc`, `skills/writing-hotwire/SKILL.md`,
  `rules/views.mdc`, `rules/javascript.mdc`.
- **Tests are behaviour-first:** **System spec** for user-visible flows when
  possible; request / model / policy specs only where
  `skills/writing-tests/SKILL.md` says — **one home per behaviour**, no duplicate
  coverage across layers (`rules/testing.mdc`).

## When to plan

- Run in a **clean branch or worktree** when the change is large enough that
  mainline noise would confuse review (optional but recommended).
- If the spec spans **independent subsystems**, split into **separate plans**
  (one deployable slice each), or separate epics with clear boundaries.

## Save location

Default: **`docs/plans/YYYY-MM-DD-<feature-name>.md`** in the app repo (create
`docs/plans` if needed). **User or team conventions override** this path.

## Plugin conventions to apply

Use these **while writing the plan** so tasks do not contradict the codebase:

| Area | Read |
|------|------|
| Models, domain verbs, state-as-records | `rules/models.mdc`, `skills/writing-models/SKILL.md` |
| Routes, shallow nesting, REST | `rules/routes.mdc`, `skills/writing-routes/SKILL.md` |
| Controllers, params, Hotwire response order | `rules/controllers.mdc`, `skills/writing-controllers/SKILL.md` |
| Pundit | `rules/policies.mdc`, `skills/writing-policies/SKILL.md` |
| No service layer / where logic goes | `rules/services.mdc` |
| Tests (RSpec, FactoryBot, spec types) | `rules/testing.mdc`, `skills/writing-tests/SKILL.md` |
| Hotwire, Stimulus | `rules/hotwire.mdc`, `skills/writing-hotwire/SKILL.md` |
| Views, partials, components discipline | `rules/views.mdc`, `skills/writing-views/SKILL.md` |
| Tailwind / CSS | `rules/css-tailwind.mdc`, `skills/writing-css-tailwind/SKILL.md` |
| JavaScript | `rules/javascript.mdc`, `skills/writing-javascript/SKILL.md` |
| I18n | `rules/i18n.mdc`, `skills/writing-i18n/SKILL.md` |
| Mailers | `rules/mailers.mdc`, `skills/writing-mailers/SKILL.md` |

## Map files before tasks

Before checkbox tasks, add a **short file map**: what will be created or
changed and **why** (single responsibility per file). Prefer **cohesion with the
existing app**: if the codebase uses larger files, do not split “for SRP” unless
the spec or file size demands it.

- **Files that change together** should live together (Rails default: by
  resource/feature, not by abstract “layer”).
- **Interfaces** are REST + Active Record + Pundit — not internal JavaScript APIs
  unless the spec is explicitly an API feature.

## Task order (repeatable template)

Order tasks by **dependency**, not arbitrary numbering:

1. **Migration / schema** — if the data shape changes (`db/migrate/...`).
2. **Model** — associations, domain verbs, transactions, scopes
   (`app/models/...`, concerns under `app/models/concerns/`).
3. **Policy** — if authorization or scoping changes (`app/policies/...`).
4. **Routes** — `config/routes.rb` (`resources`, `shallow: true`, etc.).
5. **Controller** — REST actions only; custom actions are rare and justified.
6. **Views / partials** — `app/views/...` per `skills/writing-views/SKILL.md`.
7. **Hotwire / Stimulus** — only if the UX needs frames, streams, or client
   behavior (`skills/writing-hotwire/SKILL.md`).
8. **I18n** — user-facing copy (`rules/i18n.mdc`) when adding or changing strings.
9. **Mailer** — only if the spec requires email (`rules/mailers.mdc`).

Each **task** should be a **coherent slice** that can reach a green checkpoint
(tests passing), not a ritual sequence of micro-edits with no runnable state
between steps.

## Granularity

Target **meaningful steps** (often 5–30 minutes), not only 2–5 minute micro-steps:

- **Write failing test** → **run RED** → **minimal implementation** → **run GREEN**
  is the core loop; **group** steps so one task might include the model + policy +
  controller change if they belong together as one vertical slice. Sequencing and
  how work is broken into deliverables are up to the user and the implementing agent.

## Plan document header

**Every plan MUST start with this header** (adjust paths if your repo uses a
different docs location):

```markdown
# [Feature Name] Implementation Plan

> Steps use checkbox (`- [ ]`) syntax for tracking. When writing or updating specs,
> follow **`skills/writing-tests/SKILL.md`** and **`rules/testing.mdc`**. Prefer
> **system specs** for user-visible behaviour; add request, model, or policy specs
> only per the decision tree in that skill. **One behaviour, one spec home.**
> How the plan is followed or sequenced is up to the user and the implementing agent.

**Goal:** [One sentence — user-visible or system outcome]

**Approach:** [2–3 sentences — REST resources, where domain logic lives (model,
form object, job), Hotwire surface]

**Rails shape:** [Key models, resources, policies]

**Conventions:** `rules/models.mdc`, `rules/routes.mdc`, `rules/controllers.mdc`,
`rules/policies.mdc`, `rules/services.mdc`, `rules/testing.mdc`, `rules/hotwire.mdc`
(and UI rules as needed — see table above)

---
```

## Task structure

Use **Ruby** in code fences and **`bundle exec rspec`** for commands — never
Python/pytest unless the spec is literally a non-Ruby subproject.

````markdown
### Task N: [Resource or slice name]

**Files:**
- Create: `db/migrate/XXXXXXXXXXXXXX_add_foo_to_bars.rb`
- Modify: `app/models/bar.rb`
- Modify: `app/policies/bar_policy.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/bars_controller.rb`
- Create: `spec/system/bars_spec.rb` (or the spec type chosen per writing-tests)

- [ ] **Step 1: Write the failing test** (system / request / model / policy per `skills/writing-tests/SKILL.md`)

```ruby
# Illustrative — align with the app’s helpers, factories, and I18n keys.
RSpec.describe "A focused behaviour", type: :system do
  it "does what the user cares about" do
    # ...
  end
end
```

- [ ] **Step 2: Run to verify RED**

Run: `bundle exec rspec spec/system/bars_spec.rb:12`
Expected: FAIL — [specific expectation, e.g. missing route, undefined method]

- [ ] **Step 3: Minimal implementation** (model + policy + route + controller as one slice when appropriate)

```ruby
# Show real code the implementer will add or change — no placeholders.
```

- [ ] **Step 4: Run to verify GREEN**

Run: `bundle exec rspec spec/system/bars_spec.rb:12`
Expected: PASS
````

## No placeholders

These are **plan failures** — fix before sharing:

- "TBD", "TODO", "implement later", "add validation as needed"
- "Write tests" without **concrete** spec code and file path
- "Similar to Task N" — **repeat** necessary snippets; tasks may be read out of order
- Steps that only name a layer ("add controller logic") without **what** and **where**
- Types, methods, or policies referenced but **never defined** in an earlier task
- Introducing **service objects**, **repository layers**, or **RPC routes** without
  matching justification and alignment with `rules/services.mdc` / `rules/routes.mdc`

## Rails anti-patterns to flag in plans

Reject or rewrite tasks that:

- Add **`app/services`** wrappers that only call Active Record — use model verbs,
  form objects, or jobs (`rules/services.mdc`).
- Add **custom member routes** for state that belongs in **`update`** or a **small
  resource** (`post :publish` vs `PublicationsController`) without justification
  (`rules/routes.mdc`).
- Duplicate **system + request + model** coverage for the **same** behaviour
  (`rules/testing.mdc`).
- Reach for **Turbo Streams** before **redirect** / **frame** solutions when the
  UX allows (`rules/controllers.mdc`, `skills/writing-hotwire/SKILL.md`).
- Split **one vertical slice** across many tasks that **never** pass CI in between.

## Self-review

After drafting the plan:

1. **Spec coverage:** Every requirement maps to at least one task (list gaps).
2. **Placeholder scan:** Search for forbidden vague phrases (see above).
3. **Naming consistency:** Method names, policy methods, and route helpers match
   across tasks (no `publish` vs `publish!` drift unless intentional).

Fix issues inline; add tasks for missing requirements.

## Plan review

After drafting the plan, run a **second pass** by delegating to the
**`pitchd-rails-reviewer`** subagent (`.cursor/agents/pitchd-rails-reviewer.md` —
see [Cursor subagents](https://cursor.com/docs/subagents)). It implements
`skills/reviewing-pitchd-rails/SKILL.md` in an isolated context.

**Delegation prompt must include:**

| Field | Value |
|-------|--------|
| **Phase** | `plan` (or `both` if you also want implementation-adjacent checks) |
| **Plan path** | Path to this plan file (e.g. `docs/plans/2026-04-09-feature.md`) |
| **Spec path** | Path to the spec or requirements doc, or `none` |
| **Scope** | The plan file path again, or `full plan` |

Invoke with **`/pitchd-rails-reviewer`** plus that context, or use the Task tool.
Incorporate **Approved** or address **Issues found** before implementation.
