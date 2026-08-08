---
name: writing-pitchd-rails-plans
description: >-
  Write implementation plans for multi-step Rails work before application code.
  Plans follow vertical REST slices, DHH/37signals conventions, and this plugin's
  skills and rules. After drafting: review with pitchd-rails-reviewer and apply
  that feedback to the plan file; re-run for final sign-off when Pass 1
  required edits. Use when turning a spec into tasks, planning a feature, or
  breaking work into checklisted steps. When the app has a docs/primitives/
  tree, planning also creates or amends the feature's capability doc (intent
  clauses, shape) via the primitives gate. May use
  referencing-unofficial-37signals-guide for supplemental Fizzy-derived topic
  fetches or referencing-rails-guides for authoritative Rails API docs when
  compass and scoped plugin material are insufficient for best-practice clarity.
  Also handles post-session revision requests — when the user says something
  needs changing or isn't right after the skill has run, treat it as a
  self-contained plan revision and run a scoped reviewer pass.
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
shapes the code; the existing code does not shape the plan. That decisiveness
applies to the **finished plan document** — the gates below (**Requirements
gate**, **Approach gate**) are where doubt belongs. Interrogate first; write
confidently after.

**Plugin rules beat application patterns:** If the current codebase uses service
objects, custom routes, or test patterns that contradict plugin rules, the plan
does **not** inherit those patterns. Name the correct approach and cite the rule.
If an existing anti-pattern must be worked around for this task, say so explicitly
and mark it as technical debt — do not normalize it.
</objective>

**Announce at start:** "I'm using the writing-pitchd-rails-plans skill to create the implementation plan."

## Requirements gate (before drafting anything)

Do not start writing the plan from a thin prompt. **Grill the requirements
first** — a wrong assumption made here multiplies into every task, snippet,
and spec below it.

1. **Separate the problem from the mechanism.** Restate the underlying
   problem in one sentence, in outcome terms — what the user or system needs,
   not how the prompt says to build it. If the request only describes a
   mechanism ("add a flag to X", "build a service that…"), ask what outcome
   it serves before drafting anything. A requirement that is really a
   pre-selected solution goes through the **Approach gate** below on the same
   footing as any other candidate.
2. **Interrogate the request/spec** for gaps across: the user-visible outcome,
   scope boundaries (what is explicitly *out*), affected resources and their
   relationships, authorization expectations (who may do what), UX surface
   (full page vs frame vs stream), data/migration implications, edge cases,
   and acceptance criteria.
3. **Ask before drafting.** For every gap or ambiguity, ask the user — use the
   harness's structured question tool when one is available (e.g.
   `AskUserQuestion` in Claude Code), which lets you present focused options
   for several decisions in one round; otherwise ask in chat, one question at
   a time. Do not pad the plan with guesses phrased as decisions.
4. **Proceed without answers only on explicit instruction.** If the user says
   "proceed with assumptions", record every assumption in the plan header
   under **Assumptions:** so the reviewer (Pass 1) can challenge them — an
   unstated assumption is invisible to review; a listed one is checkable.

A spec that already answers these questions (e.g. one produced by
`brainstorming-rails-omakase` and signed off) passes this gate without
re-interrogation — ask only about what the spec genuinely leaves open. The
**Approach gate** below still runs even then: a signed-off spec approves a
shape, so the gate's job shrinks to confirming the plan actually uses it.

## Approach gate (before drafting anything)

The requirements gate settles **what**; this gate decides **how** — and
whether the "how" that arrived in the prompt survives scrutiny. A plan can be
fully convention-compliant and still be the wrong solution; this gate is where
that gets caught, because the reviewer only ever sees the finished plan.

1. **Read `skills/rails-omakase-compass/SKILL.md` first** — before the file
   map, before any tasks. This read is mandatory for every plan, not just a
   row in the conventions table below.
2. **A prompter-suggested approach is an input, not a decision.** Evaluate it
   against the compass exactly as you would a candidate you generated
   yourself. "The user asked for it this way" is not a justification a
   reviewer can check.
3. **State one credible alternative shape** and a one-line reason the chosen
   approach wins. If no credible alternative exists, say so explicitly — that
   claim is itself checkable. Record the outcome in the plan header under
   **Alternatives considered:**.
4. **Never fight the framework.** If the chosen approach needs scaffolding to
   work around Rails, Turbo, or plugin defaults — custom plumbing where a
   convention exists, client-owned state for a server-owned flow, RPC where
   REST fits — the approach is wrong, not the framework. Route back to a
   Rails-native shape.
5. **If the user's stated approach conflicts with the compass, stop and say
   so before drafting.** Present the Rails-shaped alternative and let the
   user decide — a plan built on a disputed frame wastes every task below it.
   If the right shape is genuinely unclear, recommend a
   `brainstorming-rails-omakase` pass instead of planning around the
   uncertainty.

## Primitives gate (before drafting anything)

Runs when the app has a **`docs/primitives/`** tree (see
**`rules/primitives.mdc`** and `maintaining-primitives`). If the tree does not
exist, skip this gate — optionally mention `bootstrapping-primitives` once —
and omit the **Capability:** header line below.

The reading contract is three files, never more: **`index.md`**, the **one**
target capability doc, and **`compilation.md`**.

1. **Read `docs/primitives/index.md`.** Does an existing capability own this
   outcome? If yes, this plan is an **amendment** to that capability — never
   create a second doc whose intent overlaps an existing one (that is itself
   a plan defect the reviewer will flag). **One capability per plan — always.**
   Work spanning two capabilities is two plans (see **When to plan** —
   independent subsystems split): clause IDs are only unambiguous within one
   doc, and every downstream mechanism (header line, dispatch excerpts,
   review scope, close-out) targets exactly one doc. The reading-contract
   allowance for opening a second capability doc is for **context**, never a
   second target.
2. **Read `docs/primitives/compilation.md`.** These are human-owned, app-wide
   constraints; the plan must not contradict them. If the right approach
   genuinely requires breaking one, **stop and say so** — the constraint
   changes by human amendment, not by a plan working around it.
3. **Read (or create) the capability doc** under
   `docs/primitives/capabilities/<name>.md`:
   - **Exists (from brainstorming, `status: shaping`, or earlier work):**
     confirm and extend. Classify every part of this plan against the Intent
     clauses — serves an existing clause / **supersedes** one (strike through,
     tombstone, new ID — never renumber or delete) / adds a new clause. Read
     `## Provenance` before proposing an approach: do not re-litigate a
     recorded rejection or "fix" a recorded deliberate decision without
     saying so explicitly.
   - **Missing, new feature:** create it now. The requirements-gate answers
     **are** the Intent section — transcribe them as one-sentence clauses
     (`I1`, `I2`, …) instead of discarding them into chat history. Draft
     `## Shape` (deltas only) from the approach-gate outcome.
   - **Missing, existing feature (lazy backfill):** create it from what the
     code demonstrably does plus the requirements-gate answers; Evaluations
     from specs that exist — shipped behaviour with **no** spec home gets a
     row marked `unproven`, same as a `capture` backfill (an honest test-gap
     record, not a blocker); provenance opens with
     `YYYY-MM-DD — backfilled from existing behaviour; prior history in git.`
     Set **`status: built`** — the feature is already shipped, and the plan
     being drafted is an amendment to it (final approval leaves `built` docs
     at `built`, same as a `capture` backfill). Gate-answer clauses are
     self-confirming — the user stated them live. Clauses reconstructed
     **purely from code** (behaviour this plan doesn't touch) are not:
     present them to the user for a quick confirmation as part of the gate
     questions, so nothing reconstructed ships as fact unconfirmed
     (`capture` parity).
4. **Write Intent and Shape before drafting tasks.** Tasks then cite clause
   IDs (`serves I1, I4` / `supersedes I4 → I5`) instead of restating
   requirements — the plan is ephemeral; the capability doc is the durable
   record. When this gate **creates** a doc (new feature or lazy backfill),
   add its `docs/primitives/index.md` line at creation, same as `capture` —
   final approval then updates it.

**Write points:** during drafting this skill writes **Intent** and **Shape**;
at final approval it also flips `status:` to `planned`, appends the one
`planned` provenance line, and syncs `index.md` (see **At final approval**
below). Evaluations rows, `status: built`, and the `built` provenance line
belong to execution close-out (`executing-pitchd-rails-plan`); do not fill
them from intention. The one exception is the **lazy backfill** above:
Evaluations rows transcribed from **already-existing specs** record reality,
not intention, and are correct to write at plan time.

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

**Reading plugin files:** Before your first `Read` from the table below,
resolve the correct path prefix via **`resolving-plugin-root`** — bare
relative paths only resolve correctly against Cursor's workspace root or a
raw checkout; a Claude Code plugin install needs the resolved prefix instead.

**This table is a gate, not a suggestion.** Before writing tasks for an area,
read the matching row (rule + skill). Do not write migration tasks before
`rules/migrations.mdc`, controller tasks before `rules/controllers.mdc`, spec
tasks before `skills/writing-tests/SKILL.md` — and so on for every row the
plan touches. A plan that specifies code for an area whose conventions were
never loaded is **not ready for review**, regardless of how plausible the
snippets look:

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

**Capability:** `docs/primitives/capabilities/<name>.md` — serves I1–I4
[Clause IDs this plan serves, supersedes, or adds. Omit this line only when
the app has no `docs/primitives/` tree.]

**Problem:** [One sentence — the underlying need in the user's terms: what
breaks or is missing without this. Distinct from Goal, which describes the
outcome of the chosen solution.]

**Goal:** [One sentence — user-visible or system outcome]

**Approach:** [2–3 sentences — REST resources, where domain logic lives (model,
form object, job), Hotwire surface]

**Alternatives considered:** [1–2 rejected shapes with a one-line reason each,
or an explicit "none credible" — an unstated frame is invisible to review;
a listed one is checkable.]

**Rails shape:** [Key models, resources, policies]

**Assumptions:** [Only when the user said to proceed without answering
requirements-gate questions — list each assumption so review can challenge it.
Omit this line otherwise.]

**Conventions:** `skills/rails-omakase-compass/SKILL.md` (shape), `rules/models.mdc`,
`rules/routes.mdc`, `rules/controllers.mdc`, `rules/policies.mdc`, `rules/services.mdc`,
`rules/testing.mdc`, `rules/hotwire.mdc` (and UI rules as needed — see table above)

---
```

## Task structure

Use **Ruby** in code fences and **`bundle exec rspec`** for commands — never
Python/pytest unless the spec is literally a non-Ruby subproject.

````markdown
### Task N: [Resource or slice name] (serves I1, I4)

[The clause citation replaces restated requirements — the capability doc owns
intent. Use `(supersedes I4 → I5)` when the task changes intent. Omit the
parenthetical only when the app has no primitives tree.]

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
- **Standalone `not_to` assertions** that only prove an element is absent — every
  spec must assert positive behaviour the user *sees*; `not_to` is a secondary
  side-effect assertion, not a primary one (`rules/testing.mdc`).
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
5. **Convention coverage:** List every area the plan touches (migrations,
   models, policies, routes, controllers, views, Hotwire, i18n, mailers, jobs,
   tests, …) and confirm you read that area's rule + skill from the table
   before writing its tasks. Any area written from memory: re-read the row
   and re-check those tasks now.
6. **Frame check:** Re-read the **Problem:** line. Confirm every task serves
   it, no task exists only to prop up the chosen mechanism, and nothing in the
   plan works around a framework default. If a task fails this check, the
   issue is usually the approach, not the task — go back through the
   **Approach gate** before patching.
7. **Primitives trace (when the tree exists):** Every task's behaviour maps to
   an active Intent clause in the capability doc; every clause this plan
   touches appears in the header's **Capability:** line; supersessions are
   explicit in both plan and doc; nothing contradicts `compilation.md` or the
   doc's recorded Shape and Provenance. Untraceable behaviour means either a
   missing clause (add it) or scope creep (cut it).

Fix issues inline; add tasks for missing requirements.

## Plan review

**Happy path (default):** Draft → **Pass 1** → apply feedback to the plan file →
**Pass 2** only when required (see Pass 2).

### User revisions (at any point)

If the user requests changes to the plan at any point during the session, enter
**Revision mode** (see `## Revision mode` below). After the revision is applied
and the scoped review is complete, resume or close the pass flow as described
there.

### Pass 1 — Feature / plan shape (`pitchd-rails-reviewer`)

After drafting, delegate to **`pitchd-rails-reviewer`**
(`agents/pitchd-rails-reviewer.md` — [Cursor subagents](https://cursor.com/docs/subagents)).
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

Present a brief summary to the user: Pass 1 outcome and what was changed in the plan.

### Pass 2 — Final sign-off (`pitchd-rails-reviewer`, conditional)

**When:** **Skip** Pass 2 only when Pass 1 required **no** edits to the plan.
**Run** Pass 2 when you incorporated Pass 1 recommendations or user revisions
materially changed the plan (tasks added/removed, approach changed, file map
altered).

Then delegate to **`pitchd-rails-reviewer`** again.

**Initial Pass 2 call:**

| Field | Value |
|-------|--------|
| **Phase** | `plan` (use `both` only if you also need implementation-shaped checks) |
| **Plan path** | Updated plan file |
| **Spec path** | Unchanged from Pass 1, or `none` |
| **Scope** | `full plan` — state that this is **final sign-off before implementation** and whether prompted by **Pass 1 edits** or **user revisions** |
| **User revisions** | (optional) Bullet summary — **context only**: the reviewer reads the full plan; User revisions tells them where to pay extra attention, not where to stop |

**Loop call (after fixing Pass 2 issues):**

| Field | Value |
|-------|--------|
| **Phase** | same as initial |
| **Plan path** | Updated plan file |
| **Spec path** | Unchanged, or `none` |
| **Scope** | The changed sections only (e.g. `Task 3 — replaced approach`, `File map — removed entry`) |
| **User revisions** | Bullet list of exactly what was fixed — the reviewer reads only these sections |

Treat the outcome as **final plan approval** before implementation. If Pass 2
raises issues, fix the plan and re-run **scoped to the fixes only** — set
`User revisions` to a bullet list of what changed and `Scope` to those
sections; do not send the full plan again. One scoped fix cycle is usually
enough — if a second loop is needed, repeat the same scoped pattern.

### At final approval — primitives sync (when the tree exists)

Once the plan is finally approved (Pass 1 with no edits, or Pass 2 Approved):

1. Flip the capability doc's frontmatter to **`status: planned`** (leave
   `built` docs at `built` — an amendment plan does not un-build a capability).
2. Append **one** provenance line covering the whole planning session —
   **provenance records events, not edits**; five drafting revisions are still
   one `planned` event:

   ```markdown
   - YYYY-MM-DD — planned: docs/plans/YYYY-MM-DD-<feature>.md. [Rejected
     alternatives from the header's Alternatives considered, one line.]
   ```

3. Add or update the capability's line in `docs/primitives/index.md`.

## Revision mode

### When to enter revision mode

After this skill has run in the current chat session — whether mid-pass, after
findings have been presented, or after final sign-off — treat any user message
as a **revision request** if it matches phrases like — but not limited to — these:

> "this needs changing", "that's not right", "can you fix…", "this is wrong",
> "update this", "adjust…", "tweak…", "it should do X instead", "change the…",
> "rewrite task N", "the approach is wrong"

**Do not** restart the full pass flow. When the message is specific enough to
act on — what to change, where, and what "fixed" looks like — treat it as the
complete description of a **self-contained plan revision** and proceed
immediately, without asking which pass or section it relates to. When the
message is **vague** on any of those, **ask for clarification first — do not
assume.** A guessed revision that lands wrong costs more than one question.

### Revision task loop

#### R1. Scope the revision

Extract from the user's message:

- **What to change** — the section, task, snippet, approach, or field they flagged.
- **Where in the plan** — infer from context (last pass reviewed, section mentioned).
- **Acceptance** — what "fixed" looks like (derive from the user's wording;
  do not ask for a formal AC).

If any of the three is unclear from the message plus session context, **ask —
do not assume.** One focused message (the structured question tool works well
here) covering everything unclear; proceed once answered.

#### R2. Edit the plan

Apply the change directly to the plan document on disk. This skill edits the plan;
there is no implementor subagent for plan edits. Scope the edit tightly — do not
rewrite unrelated sections or re-run the self-review on unchanged content.

**Primitives sync (when the tree exists):** classify the revision. Tactics
only (snippets, file map, task order) → capability doc untouched. Changes to
**what the feature does** (scope, outcome) → amend the Intent clauses in the
same edit as the plan (add / supersede; pre-approval clauses not yet
referenced by an approved plan may simply be edited). No provenance line per
revision — the single `planned` line at final approval covers the session.

After editing:

- **Summarize what changed** — concise bullet list of which sections were affected
  (header fields, file map, task list, snippets, approach, deferred items, etc.),
  including any Intent clause changes in the capability doc.

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
    approach changed, file map altered) **and** Pass 2 has already run, run
    Pass 2 again on the full plan before treating the plan as finally approved.
  - Otherwise, continue from wherever the pass flow was interrupted.
- **`Issues found`** → apply the reviewer's feedback to the plan and loop
  from **R2** until Approved.

#### R5. Revision completion report

Deliver a brief summary:

- What was changed and in which plan sections.
- Reviewer status (`Approved` after N iteration(s)).
- Any non-blocking notes from the reviewer worth the user knowing.
- Whether the revision triggers a Pass 2 re-run (and if so, that it will run next).

**Do not** re-present the full findings from earlier passes — this is a targeted
revision report only. If the user's follow-up triggers another revision, repeat
from **R1**.

---

## Executing the plan (orchestration)

To **run** an approved plan without the main agent writing app code, use
**`../executing-pitchd-rails-plan/SKILL.md`**: delegate each task to
**`pitchd-rails-implementor`**, review with **`pitchd-rails-reviewer`** in a loop
until Approved, then hand off to the user for sign-off. In **step-by-step** mode
that skill stops after each Approved task for the user to review and commit it —
so each task in this plan is also a **commit checkpoint**, which is what the
granularity guidance above is sizing.
