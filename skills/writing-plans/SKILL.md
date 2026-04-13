---
name: writing-plans
description: >-
  Write implementation plans for multi-step Rails work before application code.
  Plans follow vertical REST slices, DHH/37signals conventions, and this plugin's
  skills and rules. After drafting: review with pitchd-rails-reviewer and apply
  that feedback to the plan file; then run pitchd-rails-surroundings-reviewer on
  the paths the plan will touch, merge quick wins into the plan, record deferred
  follow-ups, and give the user a full summary—including items too large for this
  plan. Re-run pitchd-rails-reviewer for final sign-off when you incorporated Pass
  1 recommendations and/or Pass 2 materially changed the plan. Use when turning
  a spec into tasks, planning a feature, or breaking work into checklisted steps.
  May use referencing-unofficial-37signals-guide for supplemental Fizzy-derived
  topic fetches or referencing-rails-guides for authoritative Rails API docs when
  compass and scoped plugin material are insufficient for best-practice clarity.
  Also handles post-session revision requests — when the user says something needs
  changing or isn't right after the skill has run, treat it as a self-contained
  plan revision and run a scoped reviewer pass.
---

# Writing Rails Implementation Plans

<objective>
Produce **implementation plans** a skilled developer can follow without guessing
your codebase: exact paths, real Ruby snippets, **RSpec** commands with expected
outcomes, and **Rails-shaped** decomposition. Assume the reader knows Ruby and
Rails but not your app — not that they need hand-holding on "what a test is."

Plans follow **37signals-style Rails**: **fat models**, **thin controllers**,
**REST-first routing**, **Pundit** at the boundary, **Hotwire** for HTML UX,
**no fake service layer** — and the **testing philosophy** in
`skills/writing-tests/SKILL.md` / `rules/testing.mdc` (RSpec + FactoryBot).

**Voice:** Write plans with DHH-level confidence. Make decisions; do not present
options and defer to the reader. "Use a model concern here" — not "you might
consider a concern". If the plugin rules say how to do something, the plan
follows them — even if the current application does it differently. The plan
shapes the code; the existing code does not shape the plan.

**Plugin rules beat application patterns:** If the current codebase uses service
objects, custom routes, or test patterns that contradict plugin rules, the plan
does **not** inherit those patterns. Name the correct approach and cite the rule.
If an existing anti-pattern must be worked around for this task, say so explicitly
and mark it as technical debt — do not normalize it.
</objective>

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

## Philosophy (DHH / Pitchd Rails)

- **Vertical slices over layers:** Prefer tasks that complete **one resource's
  slice** (schema → model → policy → routes → controller → views → specs) over
  scattering "all models, then all controllers."
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
| Architecture, omakase fit, boundaries ("whether" before "how") | `skills/rails-omakase-compass/SKILL.md` |
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
| Background jobs | `rules/jobs.mdc`, `skills/writing-jobs/SKILL.md` |
| Migrations | `rules/migrations.mdc`, `skills/writing-migrations/SKILL.md` |
| Naming (classes, methods, columns, routes, specs) | `rules/naming.mdc`, `skills/writing-naming-conventions/SKILL.md` |
| Linting | `rules/rubocop.mdc`, `skills/running-rubocop/SKILL.md` |

### Supplementary reference (optional)

When **`rails-omakase-compass`**, this skill's philosophy section, and the scoped **`rules/*.mdc`** / **`writing-*`** rows above still leave a **Rails best-practice** gap, two sources are available — use the one that fits:

- **`skills/referencing-unofficial-37signals-guide/SKILL.md`** — for 37signals / Fizzy-derived patterns and philosophy not spelled out in the plugin (README TOC → raw `.md`).
- **`skills/referencing-rails-guides/SKILL.md`** — for **authoritative Rails API and feature docs** (GitHub API index → specific guide `.md`).

Both **inform** the plan — they do **not** override plugin rules or skills; **tactics in this plugin win** on HOW, same as the compass conflict rule in **`implementing-pitchd-rails`**. If a fetch fails or returns nothing usable, **report** that; **do not** invent or assert content.

## Map files before tasks

Before checkbox tasks, add a **short file map**: what will be created or
changed and **why** (single responsibility per file). Prefer **cohesion with the
existing app**: if the codebase uses larger files, do not split "for SRP" unless
the spec or file size demands it.

- **Files that change together** should live together (Rails default: by
  resource/feature, not by abstract "layer").
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
10. **Jobs** — only if the spec requires background processing (`rules/jobs.mdc`).
11. **Tests** — spec type per `skills/writing-tests/SKILL.md`: system spec for
    user-visible flows, model/request/policy specs for their respective layers.
    Each task should include the test step inline (write failing test → red →
    implement → green); this step is the reminder to include tests in **every**
    task, not only at the end.

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

**Conventions:** `skills/rails-omakase-compass/SKILL.md` (shape), `rules/models.mdc`,
`rules/routes.mdc`, `rules/controllers.mdc`, `rules/policies.mdc`, `rules/services.mdc`,
`rules/testing.mdc`, `rules/hotwire.mdc` (and UI rules as needed — see table above)

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
# Illustrative — align with the app's helpers, factories, and I18n keys.
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

## Rails anti-patterns to reject in plans

**Reject or rewrite tasks that follow these patterns — regardless of whether the
current application already does them.** If an anti-pattern is already present in
the codebase, do not extend it. Name it, cite the rule, and route around it.

- **`app/services` wrappers** that only call Active Record — use model verbs,
  form objects, or jobs (`rules/services.mdc`).
- **Custom member routes** for state that belongs in **`update`** or a **small
  resource** (`post :publish` vs `PublicationsController`) without justification
  (`rules/routes.mdc`).
- **Duplicate system + request + model** coverage for the **same** behaviour
  (`rules/testing.mdc`).
- **Turbo Streams** before **redirect** / **frame** solutions when the UX allows
  (`rules/controllers.mdc`, `skills/writing-hotwire/SKILL.md`).
- **One vertical slice split** across many tasks that **never** pass CI in between.

## Self-review

After drafting the plan:

1. **Spec coverage:** Every requirement maps to at least one task (list gaps).
2. **Placeholder scan:** Search for forbidden vague phrases (see above).
3. **Naming consistency:** Method names, policy methods, and route helpers match
   across tasks (no `publish` vs `publish!` drift unless intentional).
4. **Anti-pattern scan:** Check that no task normalizes a current application
   anti-pattern — even if the existing code does it. Flag and route around it.

Fix issues inline; add tasks for missing requirements.

## Plan review

**Happy path (default):** Draft → **Pass 1** → apply feedback to the plan file →
**Pass 2** → **Merge surroundings** → **Present findings** → **Pass 3** only when
required (see Pass 3). Even **small** plans still run Pass 2 once so
touched-path surroundings are not skipped by habit.

Follow **ordered passes**. After Pass 1 feedback is in the plan, **always** run
Pass 2: it reviews **pre-existing** code along the plan's touched paths (see
`skills/reviewing-touched-surroundings/SKILL.md`), not the new feature blocks.

### User revisions (at any point)

If the user requests changes to the plan at any point during the session, enter
**Revision mode** (see `## Revision mode` below). After the revision is applied
and the scoped review is complete, resume or close the pass flow as described
there.

### Pass 1 — Feature / plan shape (`pitchd-rails-reviewer`)

After drafting, delegate to **`pitchd-rails-reviewer`**
(`.cursor/agents/pitchd-rails-reviewer.md` — [Cursor subagents](https://cursor.com/docs/subagents)).
**Canonical workflow and report format:** `skills/reviewing-pitchd-rails/SKILL.md`.

**Delegation prompt must include:**

| Field | Value |
|-------|--------|
| **Phase** | `plan` (or `both` if you also want implementation-adjacent checks) |
| **Plan path** | Path to this plan file (e.g. `docs/plans/2026-04-09-feature.md`) |
| **Spec path** | Path to the spec or requirements doc, or `none` |
| **Scope** | The plan file path again, or `full plan` |
| **User revisions** | (optional) Bullet summary of what the user changed — reviewer focuses only on these sections. Example: `- Task 3: replaced form object with model verb; - File map: removed app/forms/publish_form.rb` |

Invoke with **`/pitchd-rails-reviewer`** plus that context, or use the Task tool.

**Incorporate** Approved items or **address** Issues found by **editing the plan**
(tasks, file map, snippets). "Implemented" at this stage means **feedback is
applied in the plan document** — not yet shipping code.

### Pass 2 — Touched surroundings (`pitchd-rails-surroundings-reviewer`)

**When:** After Pass 1 feedback is **incorporated into the plan** (and before
starting implementation), delegate to **`pitchd-rails-surroundings-reviewer`**
(`.cursor/agents/pitchd-rails-surroundings-reviewer.md`). **Canonical workflow
and report format:** `skills/reviewing-touched-surroundings/SKILL.md` (**pre-existing**
code on touched paths, not new feature blocks).

**Delegation prompt must include:**

| Field | Value |
|-------|--------|
| **Phase** | `plan` |
| **Plan path** | Same plan file as Pass 1 |
| **Spec path** | Same as Pass 1, or `none` |
| **Scope** | **Touched paths** from the plan's file map (and related globs if listed). If no diff exists yet, say **plan-inferred scope** and list paths; the subagent may infer boundaries — that is expected for a pre-code plan. |
| **User revisions** | (optional) Bullet summary of what the user changed — reviewer focuses only on sections or paths affected by those changes |

Invoke with **`/pitchd-rails-surroundings-reviewer`** or the Task tool.

### Merge surroundings into the plan

This step **edits the plan file** (markdown on disk). **Present findings** (below)
is the separate **user-facing** summary in chat or PR—do not duplicate long Pass 2
verbatim in both places if the plan already records deferred items.

Use the surroundings **Report format** output to update the plan:

- **Quick wins** that fit this effort: add **checkbox tasks**, extra steps, or a
  short **"Surrounding improvements (in scope)"** subsection with concrete file
  references — so the codebase improves in the same paths as the feature.
- **Separate follow-ups** (large refactors, behavior surface changes, migrations,
  multi-file churn): add a **"Deferred / out-of-plan"** (or similar) subsection
  **in the plan** with one line each — *or* a pointer that the full list lives in
  your user-facing summary (see below). Do **not** silently drop these; they
  belong in the record even when not scheduled.

If Pass 2 finds nothing actionable for the plan body, note that explicitly
(e.g. one line under the header).

### Present findings to the user

Narrative for the user (chat/PR), not a substitute for **Merge surroundings**—the
plan document is the checklist source of truth.

Return a **single user-visible summary** that includes:

1. **Pass 1** outcome (already folded into the plan — keep this brief).
2. **Pass 2** surroundings report: include the important philosophy and tactical
   lines, **Quick wins** vs **Separate follow-ups**, and the report's **one-line
   summary**.
3. **Items too large to carry in this plan** — always list these explicitly
   (copy or paraphrase from **Separate follow-ups**), with **why** they are
   deferred, so the user can prioritize later work.

### Pass 3 — Final sign-off (`pitchd-rails-reviewer`, conditional)

**Order:** Run Pass 3 **after** Pass 2 and **Merge surroundings** (not between Pass
1 and Pass 2—you need the final plan state).

**When:** **Skip** Pass 3 only when Pass 1 required **no** edits to the plan **and**
Pass 2 did **not** materially change it after merge. **Run** Pass 3 in every other
case—for example you **incorporated Pass 1 recommendations**, or Pass 2 added
tasks, map entries, approach or snippet edits, or deferred sections that change
scope.

Then delegate to **`pitchd-rails-reviewer`** again.

| Field | Value |
|-------|--------|
| **Phase** | `plan` (use `both` only if you also need implementation-shaped checks) |
| **Plan path** | Updated plan file |
| **Spec path** | Unchanged from earlier passes, or `none` |
| **Scope** | `full plan` — and state in the prompt that this is **final sign-off before implementation**, and whether this run is prompted by **Pass 1 edits**, **Pass 2 merge**, **user revisions**, or any combination |
| **User revisions** | (optional) Bullet summary of what the user changed — **context only for Pass 3**: the reviewer reads the full plan; User revisions tells them where to pay extra attention, not where to stop |

Treat the outcome as **final plan approval** before implementation. If Pass 3
raises issues, fix the plan once; call Pass 3 again **only if** those fixes or a
further surroundings merge **materially** change scope again (avoid loops—one edit
cycle is usually enough).

### After code exists (optional repeat)

If you run a **post-implementation** surroundings review (Phase `implementation`
or `both`; see `reviewing-touched-surroundings`), merge any new quick wins or
follow-ups into the plan **or** the PR description. Use the same **Present
findings** and **conditional pitchd-rails-reviewer** steps whenever the **plan
document** changes as a result.

## Revision mode

### When to enter revision mode

After this skill has run in the current chat session — whether mid-pass, after
findings have been presented, or after final sign-off — treat any user message
as a **revision request** if it matches phrases like — but not limited to — these:

> "this needs changing", "that's not right", "can you fix…", "this is wrong",
> "update this", "adjust…", "tweak…", "it should do X instead", "change the…",
> "rewrite task N", "the approach is wrong"

**Do not** restart the full pass flow. **Do not** ask which pass or section this
relates to. Treat the user's message as the complete description of a
**self-contained plan revision** and proceed immediately.

### Revision task loop

#### R1. Scope the revision

Extract from the user's message:

- **What to change** — the section, task, snippet, approach, or field they flagged.
- **Where in the plan** — infer from context (last pass reviewed, section mentioned).
  If genuinely ambiguous, ask **one** short question before proceeding.
- **Acceptance** — what "fixed" looks like (derive from the user's wording;
  do not ask for a formal AC).

#### R2. Edit the plan

Apply the change directly to the plan document on disk. This skill edits the plan;
there is no implementor subagent for plan edits. Scope the edit tightly — do not
rewrite unrelated sections or re-run the self-review on unchanged content.

After editing:

- **Summarize what changed** — concise bullet list of which sections were affected
  (header fields, file map, task list, snippets, approach, deferred items, etc.).

#### R3. Delegate a scoped review

Invoke **`pitchd-rails-reviewer`** with:

- **Phase:** `plan`
- **Plan path:** the plan file.
- **Spec path:** as used earlier in this session, or `none`.
- **Scope:** the changed sections only (not the full plan).
- **User revisions:** the bullet summary from R2 — the reviewer focuses only on
  what changed.

**Exception:** if no full pass has yet reviewed the plan (the revision happened
before Pass 1 ever ran), send a **full-scope** review — scoping to changed
sections only applies once at least one full pass is on record.

#### R4. Branch on status

- **`Status: Approved`** → report back to the user (see **R5** below), then
  resume or close the pass flow:
  - If the revision materially changed plan scope (tasks added or removed,
    approach changed, file map altered) **and** Pass 3 has already run, run
    Pass 3 again on the full plan before treating the plan as finally approved.
  - Otherwise, continue from wherever the pass flow was interrupted.
- **`Issues found`** → apply the reviewer's feedback to the plan and loop
  from **R2** until Approved.

#### R5. Revision completion report

Deliver a brief summary:

- What was changed and in which plan sections.
- Reviewer status (`Approved` after N iteration(s)).
- Any non-blocking notes from the reviewer worth the user knowing.
- Whether the revision triggers a Pass 3 re-run (and if so, that it will run next).

**Do not** re-present the full findings from earlier passes — this is a targeted
revision report only. If the user's follow-up triggers another revision, repeat
from **R1**.

---

## Executing the plan (orchestration)

To **run** an approved plan without the main agent writing app code, use
**`../executing-pitchd-rails-plan/SKILL.md`**: delegate each task to
**`pitchd-rails-implementor`**, review with **`pitchd-rails-reviewer`** in a loop
until Approved, then hand off to the user for sign-off.
