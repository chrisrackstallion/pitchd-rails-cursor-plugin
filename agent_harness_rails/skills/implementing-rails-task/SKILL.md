---
name: implementing-rails-task
description: >-
  Implement a plan task in a Rails app using harness conventions: first
  rails-omakase-compass (opinionated best-practice omakase), then applicable
  writing-* skills and agent_harness_rails/rules/*.mdc for tactics. Use when
  executing a single task from an implementation plan, a vertical slice, or a
  scoped feature. For isolated delegation, use the rails-implementor subagent
  (see agent_harness_rails/agents/rails-implementor.md).
---

# Implementing Rails Agent Harness (plan tasks & scoped work)

<objective>
Ship **correct, boring, omakase-shaped Rails** that matches **this harness**:
**philosophy** from `rails-omakase-compass`, **tactics** from `writing-*` skills
and `agent_harness_rails/rules/*.mdc`. Implement what the task asks — no extra framework, no
drive-by refactors outside scope.

**Voice:** Implement with conviction — pick the Rails-shaped approach and
execute it without hedging. When something is genuinely ambiguous, pause and
ask once — then proceed.

**Harness rules beat application patterns**
(`agent_harness_rails/rules/harness-contract.mdc`) for the **code you write in
this task**. If integrating correctly is genuinely blocked by surrounding
anti-pattern infrastructure (e.g. you must call into an existing service that
carries side effects or state), escalate as **NEEDS_CONTEXT** — do not silently
copy the anti-pattern. Do not refactor surrounding code outside this task's
scope.
</objective>

**Announce:** "I'm using the implementing-rails-task skill."

## When to use

- Executing **Task N** (or equivalent) from an implementation plan.
- A **vertical slice** with a clear spec and acceptance criteria.
- Any scoped implementation where **harness rules** must apply.

## Relationship to other skills

| Skill | Role |
|-------|------|
| `executing-rails-plan` | **Orchestration** — run a whole plan (or subset) by delegating each task to **`rails-implementor`** and **`rails-reviewer`** in a loop; orchestrator does **not** write app code. |
| `rails-omakase-compass` | **Whether** the approach fits majestic monolith / server truth / REST — read **before** coding when the task involves boundaries or product shape. |
| `writing-*` + `agent_harness_rails/rules/*.mdc` | **How** to write routes, models, controllers, Hotwire, tests, etc., for this repo. |
| `writing-rails-plans` | Plan structure and task quality — use when the **plan** is wrong or incomplete, not to rewrite the plan silently during implementation. |
| `writing-tests` | Tests: opinionated best-practice philosophy (system backbone, real objects, behaviour over mocks) plus `agent_harness_rails/rules/testing.mdc`. |
| `running-rubocop` | **Lint gate:** `bin/rubocop` **zero offences** before DONE/review — fix code only, no inline or config disables — see `agent_harness_rails/rules/rubocop.mdc`. Not a substitute for compass or tests. |
| `maintaining-primitives` | **Primitives tree only** — capability docs, `compilation.md`, provenance under `docs/primitives/` per `agent_harness_rails/rules/primitives.mdc`. Implementation **reads** intent/shape excerpts pasted into the task prompt but **never writes** to the tree — the planner and execution close-out own those write points. If the task is code, stay in this skill. |

**Conflict rule:** per `agent_harness_rails/rules/harness-contract.mdc` — under a documented exception, implement **consistently** with that documented exception.

## Process

### 1. Before you begin

If anything is unclear about **requirements**, **acceptance criteria**, **approach**, **dependencies**, or **assumptions** — **ask now**. Do not guess.

If the task prompt includes **capability excerpts** (Intent clauses like
`I1 — …`, Shape bullets, and any `compilation.md` constraints from
`docs/primitives/`), treat the clauses as acceptance-criteria context and the
Shape bullets and compilation constraints as binding for this task. Do not
open or edit `docs/primitives/` yourself — the excerpt is your whole
primitives context by design.

### 2. Load the compass (when the task touches architecture or boundaries)

Read **`agent_harness_rails/skills/rails-omakase-compass/SKILL.md`** when the task involves:

- New endpoints or HTML vs JSON for a flow
- Where truth lives (server vs client)
- REST vs RPC-shaped actions
- Extracting services, jobs, or boundaries

For purely local edits inside an established pattern, still **skim** the compass if the change could drift (e.g. duplicating business rules in JS).

**Default stack:** Prefer **Hotwire** (Turbo, Stimulus) and **server-rendered HTML** for app flows. Reach for **`writing-javascript`** only when the **task** or **existing app** already requires client-side behaviour beyond that — not as a default for "richer" UX.

**Domain logic:** Keep behaviour in **models**, **jobs**, **mailers**, and plain Ruby where the app already does. Use **`writing-services`** only when the **task**, **plan**, or **established pattern** in the repo justifies a dedicated object — not to "clean up" a controller or avoid a fat model without cause (see `rails-omakase-compass` and `writing-services`).

### 3. Select tactical skills by scope

From the task description and files you will touch, read **only** the relevant:

`writing-rails-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-jobs`, `writing-migrations`, `writing-tests`.

For each area, open the skill's **SKILL.md** and the relevant
**`references/patterns.md`** (or sectioned references). Cross-check
**`rules/<area>.mdc`** for the same area. The list is a **menu**, not permission
to add JS or service layers by reflex — apply the **defaults under Load the compass** first.

**Hard rule:** do not write or edit code for a layer before reading that
layer's `writing-*` SKILL and `rules/<area>.mdc` in this session. Touching a
migration means `writing-migrations` + `agent_harness_rails/rules/migrations.mdc` are open first;
touching a spec means `writing-tests` + `agent_harness_rails/rules/testing.mdc`; and so on. "I
know Rails" is not a substitute — harness conventions deliberately differ from
common practice.

### 4. Implement

1. Implement **exactly** what the task specifies (and the plan's file layout if given).
2. **Search before defining:** before adding a new public method, grep the app
   (and the plan's other tasks, when a plan path was given) for the same method
   name on other entities. If the behaviour already exists — or the plan defines
   it on another model — do **not** write a second copy: reuse the existing home,
   or name the shared capability as a concern-extraction candidate
   (`agent_harness_rails/rules/models.mdc`) in your report. Restructuring beyond
   task scope is the orchestrator's call — escalate it, never silently duplicate.
3. **Tests:** Follow `writing-tests` and `agent_harness_rails/rules/testing.mdc`. If the task says **TDD**, follow that order (red → green → refactor).
4. **Verify:** Run the **narrowest spec slice that covers what you changed** — the spec files for the objects you touched, not `bin/rspec` bare. A full-suite run is earned (cross-cutting change, spec-refactor session, final pre-handoff verification), not the default (`agent_harness_rails/rules/testing.mdc` § Running Specs). Report the commands you actually ran — never call the suite green off a slice.
**Red run → re-run the failures, not the run:** fix, then run just those examples or
files; widen only if your fix was cross-cutting, and after a red full run at most once
more once the failures are green. A failure that will not reproduce is a flake to report
with its seed (`agent_harness_rails/rules/testing.mdc` § When a Run Comes Back Red, §
Flaky and Order-Dependent Failures). If the app uses RuboCop, follow the **fix loop in `running-rubocop`** and **`agent_harness_rails/rules/rubocop.mdc`**: run `bin/rubocop`, fix every offence in code, run again — repeat until **exit 0 with zero offences** before you consider work **complete or ready for review**. **No** `# rubocop:disable` and **no** new cop disables / excludes in RuboCop YAML. Do not report BLOCKED after a single failing run; work the fix loop first. If you truly cannot fix an offence after the loop, **BLOCKED** (rare) — see **When you cannot ship RuboCop green** below.

   **When the app has a `docs/primitives/` tree and the task served an intent clause,** run **`agent_harness_rails proofs --since HEAD`** and read it against the plan's **Intent impact** row for each clause you served. The row names the cases the clause needs; the output counts each clause's tagged examples. A count that comes up short against the row means a proof you wrote and never tagged, or never wrote — drill in with **`agent_harness_rails proofs '<capability>#I<n>'`**, whose tagged listing shows which planned case is missing, then find the example in the spec file and tag it (or write it) before reporting. No other check can see this, because `evals` treats one tag as proof of the whole file and `guard` says nothing about an untagged new example. Quote each touched clause's tagged-count line in **Tests and verification**, so the count reaches review rather than your reading of it.

   **When the task touched a spec carrying an `intent:` tag,** finish with **`agent_harness_rails guard --base HEAD`** (notices only — it never fails). It reports what your work did to promises that already existed. A **proof** notice (`proof/removed`, `proof/weakened`, `evaluation/dropped`) on a still-active clause is yours to fix before reporting: you took coverage off a promise the app still makes, so restore the assertion or the example. An **intent** notice (`intent/rewritten`, `intent/vanished`, `provenance/rewritten`) means an intent clause moved — **you do not own that file**. Report it in the completion notes and change nothing: intent is amended by the user's decision, never by an implementor, and never by writing the provenance line that silences the notice (`agent_harness_rails/rules/primitives.mdc` § Ownership and write points).
5. **Self-review** (below) before reporting.

**Do not create git commits** (no `git commit`). The parent or human owns version control; leave changes for them to commit unless the delegating prompt says otherwise.

**While you work:** If something unexpected or ambiguous appears — **pause and ask**. Silent assumptions are worse than questions.

## Code organization

- Follow the **file structure** from the plan when one exists.
- **One clear responsibility** per file, with **clear, conventional Rails boundaries**. For **file structure and size decisions** (where to put a class, whether to split a file), match what the **app already does** — not abstract "ports and adapters" for its own sake.
- If a **new** file grows beyond the plan's intent, **stop** and report **DONE_WITH_CONCERNS** — do not split or reorganize without plan guidance.
- If an **existing** file is already large or tangled, touch it **carefully** and note it under concerns.
- **Write no comment you cannot justify.** The default is none: names and structure carry the explanation, shape belongs in `## Shape` of the capability doc, and a rejected alternative belongs in provenance or the PR. A comment ships only when a reader would get something **wrong** without it — see `agent_harness_rails/rules/comments.mdc` for the test and the exceptions.
- For **coding patterns** (service objects, RPC routes, test layer choices), match established patterns **only when they do not contradict harness rules**. When a current pattern violates harness rules, implement the correct approach for the code you write in this task and note the deviation in your report — do not refactor surrounding code outside task scope.

## When you are in over your head

Bad work is worse than no work. **Escalate** — you will not be penalized.

**STOP** and report **BLOCKED** or **NEEDS_CONTEXT** when:

- The task needs **architectural** choices with multiple valid approaches and the plan does not decide.
- You cannot get clarity from the codebase within reasonable effort.
- You are **uncertain** whether the approach is correct.
- The task implies **restructuring** the app in ways the plan did not anticipate.
- You are stuck **reading without progress**.

**How to escalate:** Status **BLOCKED** or **NEEDS_CONTEXT**, what you tried, what you need (context, smaller tasks, decision).

### When you cannot ship RuboCop green

If a cop cannot be satisfied with a **correct** code fix and needs a human policy or product call, report **BLOCKED**: cop name, full offence text, what you tried, and what decision is needed. **Do not** use disable comments or YAML excludes to ship. Residual RuboCop debt is **not** **DONE_WITH_CONCERNS** — either green or **BLOCKED**.

## Self-review (before reporting)

**Completeness:** Spec fully implemented? Edge cases? Missed requirements?

**Quality:** Best work? Names accurate? Code maintainable?

**Discipline:** YAGNI? Only what was requested? Harness rules applied (not just existing app patterns)? Every comment you added carries context the code cannot — no narration, no banners, no notes to the next agent (`agent_harness_rails/rules/comments.mdc`)?

**Duplication:** No method you added already exists on another entity? You searched before defining (Implement step 2)?

**Failure paths:** For every mutation you touched — did you follow the failure
branch through to a **successful retry**, not just to the error? The form a failed
save re-renders has to reach a route that exists with the verb it emits
(`bin/rails routes -g <resource>`; `form_with model:` infers it from `persisted?`,
so a finder that can return either a new or an existing record gives you two
renderings). Which record states can reach each branch you wrote, and does an
example cover each of them (`agent_harness_rails/rules/controllers.mdc` § Response
Hierarchy, `agent_harness_rails/rules/testing.mdc`)?

**Testing:** Behaviour verified (not only mocked internals)? TDD if required? Right spec layer per `writing-tests`? Every case the plan's Intent impact row named carries its `intent:` tag — a clause proven by four examples is tagged on all four? Every spec you are leaving behind asserts behaviour a user or caller gets — no spec whose only job is to prove a former feature is gone; any `not_to` scaffolding you wrote to confirm a deletion is deleted (`agent_harness_rails/rules/testing.mdc`).

**RuboCop (when the app uses it):** **`bin/rubocop` zero offences** on the completion run? No inline or config suppressions added?

Fix issues you find before reporting.

## Report format

```markdown
## Rails Agent Harness implementation report

**Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT

### What I implemented
- ...

### Tests and verification
- Commands run: ... (include `bin/rubocop` with exit 0 / zero offences when RuboCop applies)
- Results: ...

### Files changed
- ...

### Self-review
- ...

### Issues or concerns
- ...
```

- **DONE_WITH_CONCERNS:** Finished but residual doubt about correctness or follow-up risk — **not** for leftover RuboCop offences (those require **green** or **BLOCKED**).
- **BLOCKED:** Cannot complete.
- **NEEDS_CONTEXT:** Missing information that blocks correct implementation.

End with a **one-line summary**.

## Subagent (optional)

The **`rails-implementor`** custom subagent at
**`agent_harness_rails/agents/rails-implementor.md`** runs this workflow in an
**isolated** context (`readonly: false`, `model: inherit`). It does not commit
code. Context isolation applies (`agent_harness_rails/rules/harness-contract.mdc`) — the delegating agent must pass **full task
text** (including acceptance criteria and file layout when the plan would have
them), **context**, **working directory**, and paths to **plan/spec** when
relevant. When **plan path** is `none`, **pasted task text** must stand in for
the plan so nothing is lost. Invoke via the
Task tool or slash command. Subagent instructions add **delegation** and
**input** rules only; process and report shape are defined **here**.

## Related

- **RuboCop:** `agent_harness_rails/skills/running-rubocop/SKILL.md`, `agent_harness_rails/rules/rubocop.mdc`
- **Compass:** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **Review after implementation:** `agent_harness_rails/skills/reviewing-rails-work/SKILL.md` — `rails-reviewer` (includes surroundings pass for pre-existing code in touched files)
