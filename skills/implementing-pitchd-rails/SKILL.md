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
</objective>

**Announce:** "I'm using the implementing-pitchd-rails skill."

## When to use

- Executing **Task N** (or equivalent) from an implementation plan.
- A **vertical slice** with a clear spec and acceptance criteria.
- Any scoped implementation where **Pitchd rules** must apply.

## Relationship to other skills

| Skill | Role |
|-------|------|
| `rails-omakase-compass` | **Whether** the approach fits majestic monolith / server truth / REST — read **before** coding when the task involves boundaries or product shape. |
| `writing-*` + `rules/*.mdc` | **How** to write routes, models, controllers, Hotwire, tests, etc., for this repo. |
| `writing-plans` | Plan structure and task quality — use when the **plan** is wrong or incomplete, not to rewrite the plan silently during implementation. |
| `writing-tests` | Tests: DHH/37signals philosophy (system backbone, real objects, behaviour over mocks) plus `rules/testing.mdc`. |

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

### 3. Select tactical skills by scope

From the task description and files you will touch, read **only** the relevant:

`writing-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-tests`.

For each area, open the skill’s **SKILL.md** and the relevant
**`references/patterns.md`** (or sectioned references). Cross-check
**`rules/<area>.mdc`** for the same area.

### 4. Implement

1. Implement **exactly** what the task specifies (and the plan’s file layout if given).
2. **Tests:** Follow `writing-tests` and `rules/testing.mdc`. If the task says **TDD**, follow that order (red → green → refactor).
3. **Verify:** Run the tests and any checks the repo uses (e.g. lint) for what you changed.
4. **Self-review** (below) before reporting.

**Do not create git commits** (no `git commit`). The parent or human owns version control; leave changes for them to commit unless the delegating prompt says otherwise.

**While you work:** If something unexpected or ambiguous appears — **pause and ask**. Silent assumptions are worse than questions.

## Code organization

- Follow the **file structure** from the plan when one exists.
- **One clear responsibility** per file; **well-defined** public interface.
- If a **new** file grows beyond the plan’s intent, **stop** and report **DONE_WITH_CONCERNS** — do not split or reorganize without plan guidance.
- If an **existing** file is already large or tangled, touch it **carefully** and note it under concerns.
- In existing codebases, **match established patterns**. Improve only what you are touching in a way a good teammate would — **no** scope creep.

## When you are in over your head

Bad work is worse than no work. **Escalate** — you will not be penalized.

**STOP** and report **BLOCKED** or **NEEDS_CONTEXT** when:

- The task needs **architectural** choices with multiple valid approaches and the plan does not decide.
- You cannot get clarity from the codebase within reasonable effort.
- You are **uncertain** whether the approach is correct.
- The task implies **restructuring** the app in ways the plan did not anticipate.
- You are stuck **reading without progress**.

**How to escalate:** Status **BLOCKED** or **NEEDS_CONTEXT**, what you tried, what you need (context, smaller tasks, decision).

## Self-review (before reporting)

**Completeness:** Spec fully implemented? Edge cases? Missed requirements?

**Quality:** Best work? Names accurate? Code maintainable?

**Discipline:** YAGNI? Only what was requested? Existing patterns followed? Plugin rules applied?

**Testing:** Behaviour verified (not only mocked internals)? TDD if required? Right spec layer per `writing-tests`?

Fix issues you find before reporting.

## Report format

```markdown
## Pitchd Rails implementation report

**Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT

### What I implemented
- ...

### Tests and verification
- Commands run: ...
- Results: ...

### Files changed
- ...

### Self-review
- ...

### Issues or concerns
- ...
```

- **DONE_WITH_CONCERNS:** Finished but residual doubt about correctness or follow-up risk.
- **BLOCKED:** Cannot complete.
- **NEEDS_CONTEXT:** Missing information that blocks correct implementation.

End with a **one-line summary**.

## Subagent (optional)

The **`pitchd-rails-implementor`** custom subagent at
**`.cursor/agents/pitchd-rails-implementor.md`** runs this workflow in an
**isolated** context (`readonly: false`, `model: inherit`). It does not commit
code. It does not see parent chat — the delegating agent must pass **full task
text**, **context**, **working directory**, and paths to **plan/spec** when
relevant. Invoke via the
Task tool or slash command. Subagent instructions add **delegation** and
**input** rules only; process and report shape are defined **here**.

## Related

- **Compass:** `../rails-omakase-compass/SKILL.md`
- **Review after implementation:** `../reviewing-pitchd-rails/SKILL.md` — `pitchd-rails-reviewer`
- **Surroundings / pre-existing code in touched files:** `../reviewing-touched-surroundings/SKILL.md` — `pitchd-rails-surroundings-reviewer`
