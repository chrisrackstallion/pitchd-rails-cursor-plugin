---
name: reviewing-pitchd-rails
description: >-
  Review Rails plans and/or implementation against the Pitchd plugin: first
  rails-omakase-compass (solution shape), then applicable writing-* skills and
  rules (tactics). Use when requesting a code review, plan review, PR review, or
  sign-off before merge. For isolated delegation with a clean context, use the
  pitchd-rails-reviewer subagent (see `.cursor/agents/pitchd-rails-reviewer.md`).
---

# Reviewing Pitchd Rails (plans & implementation)

<objective>
Run a **two-layer** review: **philosophy** (`rails-omakase-compass`) for whether
the work is the **right kind of Rails solution**, then **tactics**
(`writing-*`, `rules/*.mdc`) for **correct usage**. Do not duplicate the
compass inside this file — read it first when reviewing.
</objective>

**Announce:** "I'm using the reviewing-pitchd-rails skill."

## When to use

- After a **plan** is written (before large implementation).
- After **implementation** (PR, branch, or milestone).
- **Both** when you want end-to-end assurance.

## Process

### 1. Load the compass

Read **`../rails-omakase-compass/SKILL.md`**. Use it for:

- HTML vs API / parallel JSON app for the same flow
- Server-owned truth vs client-as-source-of-truth
- REST gravity vs RPC
- Fat domain vs orchestration scripts
- Monolith boundaries, progressive enhancement, documented exceptions

Prefix these findings **`philosophy:`**.

### 2. Select tactical skills by scope

From the diff or plan, pick **only** the skills that apply:

`writing-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-tests`.

Read each skill’s **SKILL.md** and the relevant **`references/patterns.md`**
sections (not necessarily entire files). Cross-check **`rules/<area>.mdc`**.

Prefix these findings **`tactical:`**.

### 3. Conflict rule

- **Tactics** win on **specific** HOW (this repo’s rules and patterns).
- **Compass** wins on **whether** the approach matches **majestic monolith /
  omakase** intent — unless the user or plan has **explicitly** chosen a
  different shape (API-first, SPA, etc.); then treat it as a documented
  exception and review tactics for consistency with that choice.

### 4. What to check by phase

**Plan:** Completeness (no blocking TODOs), spec alignment, vertical slices,
runnable tasks, buildability; compass on interface (HTML vs API) and correct
layer for rules; `writing-plans` fit; red flags from `writing-plans` (services,
RPC, missing policy, Turbo escalation before simpler options, duplicate test
coverage).

**Implementation:** Map changed files to skills; compass on overall drift; one
home per behaviour for tests (`writing-tests`).

### 5. Calibration

Only flag issues that risk **wrong feature**, **blocked implementer**, or
**likely regression**. Nitpicks without impact are not blockers.

## Report format

Produce a single Markdown report with these sections:

```markdown
## Pitchd Rails review

**Phase covered:** plan | implementation | both

**Status:** Approved | Issues found

### philosophy: (rails-omakase-compass)
- ...

### tactical: (writing-* / rules)
- [file or area]: ... — [skill or rule reference]

### Recommendations (non-blocking)
- ...
```

End with a **one-line summary** for quick scanning.

## Subagent (optional)

The **`pitchd-rails-reviewer`** custom subagent ([Cursor
subagents](https://cursor.com/docs/subagents)) at **`.cursor/agents/pitchd-rails-reviewer.md`**
implements **this skill** in an **isolated context** (`readonly: true`,
`model: inherit`). It does not see parent chat — the delegating agent must pass
**Phase**, plan path, spec path, and **Scope** in the task prompt. Invoke with
`/pitchd-rails-reviewer` or the Task tool. The subagent’s instructions only add
context-isolation rules; the workflow and report shape are defined **here**.

## Related

- **Compass (why / whether):** `../rails-omakase-compass/SKILL.md`
- **Planning:** `../writing-plans/SKILL.md` (plans should be reviewed with this skill via **`pitchd-rails-reviewer`**, Phase `plan`)
