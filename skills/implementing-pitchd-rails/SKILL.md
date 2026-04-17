---
name: implementing-pitchd-rails
description: >-
  Implement a plan task in a Rails app using Pitchd plugin conventions: first
  rails-omakase-compass (DHH / 37signals-shaped omakase), then applicable
  writing-* skills and rules/*.mdc for tactics. Use when executing a single task
  from an implementation plan, a vertical slice, or a scoped feature. For
  isolated delegation, use the pitchd-rails-implementor subagent (see
  .cursor/agents/pitchd-rails-implementor.md).
---

# Implementing Pitchd Rails (plan tasks & scoped work)

<objective>
Ship **correct, boring, omakase-shaped Rails** that matches **this plugin**:
**philosophy** from `rails-omakase-compass`, **tactics** from `writing-*` skills
and `rules/*.mdc`. Implement what the task asks — no extra framework, no
drive-by refactors outside scope.

**Voice:** Implement with DHH-level confidence. Pick the Rails-shaped approach
and execute it. Do not hedge about which pattern to use — make the correct omakase
decision and ship. When the plan is clear, implement it. When something is
genuinely ambiguous, pause and ask once — then proceed.

**Plugin rules beat application patterns:** For the **code you write in this
task**, apply plugin rules — do not inherit anti-patterns from the surrounding
codebase. If every controller in the app calls service objects but this task
adds a new action, write the action using model logic per `rules/services.mdc`,
not by calling into an existing service object. If integrating correctly is
genuinely blocked by surrounding anti-pattern infrastructure (e.g. you must
call into an existing service that carries side effects or state), escalate as
**NEEDS_CONTEXT** — do not silently copy the anti-pattern or make the codebase
inconsistent in ways that could break things. Do not refactor surrounding code
outside this task's scope.
</objective>

**Announce:** "I'm using the implementing-pitchd-rails skill."

## When to use

- Executing **Task N** (or equivalent) from an implementation plan.
- A **vertical slice** with a clear spec and acceptance criteria.
- Any scoped implementation where **Pitchd rules** must apply.

## Relationship to other skills

| Skill | Role |
|-------|------|
| `executing-pitchd-rails-plan` | **Orchestration** — run a whole plan (or subset) by delegating each task to **`pitchd-rails-implementor`** and **`pitchd-rails-reviewer`** in a loop; orchestrator does **not** write app code. |
| `rails-omakase-compass` | **Whether** the approach fits majestic monolith / server truth / REST — read **before** coding when the task involves boundaries or product shape. |
| `writing-*` + `rules/*.mdc` | **How** to write routes, models, controllers, Hotwire, tests, etc., for this repo. |
| `writing-plans` | Plan structure and task quality — use when the **plan** is wrong or incomplete, not to rewrite the plan silently during implementation. |
| `writing-tests` | Tests: DHH/37signals philosophy (system backbone, real objects, behaviour over mocks) plus `rules/testing.mdc`. |
| `running-rubocop` | **Lint gate:** `bin/rubocop` **zero offences** before DONE/review — fix code only, no inline or config disables — see `rules/rubocop.mdc`. Not a substitute for compass or tests. |
| `maintaining-llm-wiki` | **Knowledge wiki only** — ingest/query/lint for `docs/llm-wiki/` per `rules/llm-wiki.mdc`; use **`pitchd-rails-wiki-maintainer`** for delegation. Not a substitute for app implementation — if the task is code, stay in this skill. |

**Conflict rule (same as reviewing-pitchd-rails):**

- **Tactics** (`writing-*`, `rules/*.mdc`) win on **specific HOW**.
- **Compass** wins on **whether** the solution shape matches omakase intent — unless the user or plan has **explicitly** chosen a different shape (API-first, SPA); then implement **consistently** with that documented exception.

## Process

### 1. Before you begin

If anything is unclear about **requirements**, **acceptance criteria**, **approach**, **dependencies**, or **assumptions** — **ask now**. Do not guess.

### 2. Load the compass (when the task touches architecture or boundaries)

Read **`../rails-omakase-compass/SKILL.md`** when the task involves:

- New endpoints or HTML vs JSON for a flow
- Where truth lives (server vs client)
- REST vs RPC-shaped actions
- Extracting services, jobs, or boundaries

For purely local edits inside an established pattern, still **skim** the compass if the change could drift (e.g. duplicating business rules in JS).

**Default stack:** Prefer **Hotwire** (Turbo, Stimulus) and **server-rendered HTML** for app flows. Reach for **`writing-javascript`** only when the **task** or **existing app** already requires client-side behaviour beyond that — not as a default for "richer" UX.

**Domain logic:** Keep behaviour in **models**, **jobs**, **mailers**, and plain Ruby where the app already does. Use **`writing-services`** only when the **task**, **plan**, or **established pattern** in the repo justifies a dedicated object — not to "clean up" a controller or avoid a fat model without cause (see `rails-omakase-compass` and `writing-services`).

### 3. Select tactical skills by scope

From the task description and files you will touch, read **only** the relevant:

`writing-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-jobs`, `writing-migrations`, `writing-tests`.

For each area, open the skill's **SKILL.md** and the relevant
**`references/patterns.md`** (or sectioned references). Cross-check
**`rules/<area>.mdc`** for the same area. The list is a **menu**, not permission
to add JS or service layers by reflex — apply the **defaults under Load the compass** first.

### 4. Implement

1. Implement **exactly** what the task specifies (and the plan's file layout if given).
2. **Tests:** Follow `writing-tests` and `rules/testing.mdc`. If the task says **TDD**, follow that order (red → green → refactor).
3. **Verify:** Run the tests and any checks the repo uses for what you changed. If the app uses RuboCop, follow the **fix loop in `running-rubocop`** and **`rules/rubocop.mdc`**: run `bin/rubocop`, fix every offence in code, run again — repeat until **exit 0 with zero offences** before you consider work **complete or ready for review**. Fix offences in code — **no** `# rubocop:disable` and **no** new cop disables / excludes in RuboCop YAML. Do not report BLOCKED after a single failing run; work the fix loop first. If you truly cannot fix an offence after the loop, **BLOCKED** (rare) — see **When you cannot ship RuboCop green** below.
4. **Self-review** (below) before reporting.

**Do not create git commits** (no `git commit`). The parent or human owns version control; leave changes for them to commit unless the delegating prompt says otherwise.

**While you work:** If something unexpected or ambiguous appears — **pause and ask**. Silent assumptions are worse than questions.

## Code organization

- Follow the **file structure** from the plan when one exists.
- **One clear responsibility** per file, with **clear, conventional Rails boundaries**. For **file structure and size decisions** (where to put a class, whether to split a file), match what the **app already does** — not abstract "ports and adapters" for its own sake.
- If a **new** file grows beyond the plan's intent, **stop** and report **DONE_WITH_CONCERNS** — do not split or reorganize without plan guidance.
- If an **existing** file is already large or tangled, touch it **carefully** and note it under concerns.
- For **coding patterns** (service objects, RPC routes, test layer choices), match established patterns **only when they do not contradict plugin rules**. When a current pattern violates plugin rules, implement the correct approach for the code you write in this task and note the deviation in your report — do not refactor surrounding code outside task scope.

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

**Discipline:** YAGNI? Only what was requested? Plugin rules applied (not just existing app patterns)?

**Testing:** Behaviour verified (not only mocked internals)? TDD if required? Right spec layer per `writing-tests`?

**RuboCop (when the app uses it):** **`bin/rubocop` zero offences** on the completion run? No inline or config suppressions added?

Fix issues you find before reporting.

## Report format

```markdown
## Pitchd Rails implementation report

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

The **`pitchd-rails-implementor`** custom subagent at
**`.cursor/agents/pitchd-rails-implementor.md`** runs this workflow in an
**isolated** context (`readonly: false`, `model: inherit`). It does not commit
code. It does not see parent chat — the delegating agent must pass **full task
text** (including acceptance criteria and file layout when the plan would have
them), **context**, **working directory**, and paths to **plan/spec** when
relevant. When **plan path** is `none`, **pasted task text** must stand in for
the plan so nothing is lost. Invoke via the
Task tool or slash command. Subagent instructions add **delegation** and
**input** rules only; process and report shape are defined **here**.

## Related

- **RuboCop:** `../running-rubocop/SKILL.md`, `../../rules/rubocop.mdc`
- **Compass:** `../rails-omakase-compass/SKILL.md`
- **Review after implementation:** `../reviewing-pitchd-rails/SKILL.md` — `pitchd-rails-reviewer`
- **Surroundings / pre-existing code in touched files:** `../reviewing-touched-surroundings/SKILL.md` — `pitchd-rails-surroundings-reviewer`
