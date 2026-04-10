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

Be direct. State violations as violations, not suggestions. "This violates
`rules/services.mdc`" — not "you might want to consider". The plugin rules exist
because DHH and 37signals have already made these decisions; the job here is to
apply them, not re-debate them.
</objective>

**Announce:** "I'm using the reviewing-pitchd-rails skill."

## When to use

- After a **plan** is written (before large implementation).
- After **implementation** (PR, branch, or milestone).
- **Both** when you want end-to-end assurance.

## Process

### 0. Scope check — user revisions

**If this is a final sign-off pass (the prompt says "final sign-off" or "Pass 3"):** review the full scope regardless of User revisions. User revisions is context — it tells you where to pay closest attention; it does not restrict what you read.

**Otherwise, if User revisions was provided:** restrict this review to the described changed sections only. Locate and read those sections or paths in the relevant artifact (plan file, code files, or both depending on Phase); skip the rest. Note in the report: "**Scope:** User revisions — [brief restatement of what changed]."

**If User revisions is absent:** review the full scope as specified.

### 1. Verify before asserting

**Read the actual code** for every finding before reporting it. Do not assert issues from diff headers, file names, memory, or inference alone.

For each finding:
1. Open the cited file and confirm the relevant code exists exactly as you'll state it.
2. Verify the violation is not already handled elsewhere in the same scope.
3. Confirm the rule or skill you're citing actually prohibits what you're claiming — read the rule.

Drop any finding you cannot verify. A missing finding is better than a hallucinated one.

### 2. Load the compass

Read **`../rails-omakase-compass/SKILL.md`**. Use it for:

- HTML vs API / parallel JSON app for the same flow
- Server-owned truth vs client-as-source-of-truth
- REST gravity vs RPC
- Fat domain vs orchestration scripts
- Monolith boundaries, progressive enhancement, documented exceptions

Prefix these findings **`philosophy:`**.

### 3. Select tactical skills by scope

From the diff or plan, pick **only** the skills that apply:

`writing-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-jobs`, `writing-migrations`, `writing-tests`,
`running-rubocop` (when the app uses RuboCop: expect **zero** offences — fix in code, no disables, no `.rubocop_todo.yml`; not architecture).

Read each skill’s **SKILL.md** and the relevant **`references/patterns.md`**
sections (not necessarily entire files). Cross-check **`rules/<area>.mdc`**.

Prefix these findings **`tactical:`**.

### 4. Conflict rule

- **Tactics** win on **specific** HOW (this repo’s rules and patterns).
- **Compass** wins on **whether** the approach matches **majestic monolith /
  omakase** intent — unless the user or plan has **explicitly** chosen a
  different shape (API-first, SPA, etc.); then treat it as a documented
  exception and review tactics for consistency with that choice.

### 5. What to check by phase

**Plan:** Completeness (no blocking TODOs), spec alignment, vertical slices,
runnable tasks, buildability; compass on interface (HTML vs API) and correct
layer for rules; `writing-plans` fit; red flags from `writing-plans` (services,
RPC, missing policy, Turbo escalation before simpler options, duplicate test
coverage).

**Implementation:** Map changed files to skills; compass on overall drift; one
home per behaviour for tests (`writing-tests`).

### 6. Calibration

**Flag all violations of plugin rules.** Plugin conventions — `rails-omakase-compass`,
`writing-*` skills, and `rules/*.mdc` — apply even when the application currently does
otherwise. An established application pattern is not a justification; it may be exactly
the debt worth naming. State violations directly: "This violates `rules/services.mdc`:
a thin wrapper around Active Record is not a service object."

**Assign a confidence score (0.0–1.0) to every finding:**
- **0.9–1.0:** You read the exact code and confirmed the rule violation. High certainty.
- **0.7–0.9:** You read the code; some interpretive judgment involved.
- **0.5–0.7:** Inference required (e.g. plan-only review, no implementation to read yet).
- **Below 0.5:** Drop the finding or flag explicitly as "uncertain — verify before acting."

Suppress only findings you cannot verify at all. Do not suppress because the issue
seems small — small plugin violations are still violations.

## Report format

Produce a single Markdown report with these sections. Every finding carries a
**confidence score** and a **Verified** note showing what you read to confirm it.

```markdown
## Pitchd Rails review

**Phase covered:** plan | implementation | both

**Scope:** User revisions — [brief restatement of changed sections]  ← include this line only when scope was narrowed; omit entirely for full-scope reviews

**Status:** Approved | Issues found

### philosophy: (rails-omakase-compass)
- [confidence: X.X] `[file or area]`: [Direct statement of the issue — no hedging.]
  **Verified:** [What you opened and read to confirm this.]

### tactical: (writing-* / rules)
- [confidence: X.X] `[file or area]`: [Direct statement of the violation.] — [skill or rule reference]
  **Verified:** [What you opened and read to confirm this.]

### Application-pattern violations
Issues where the current codebase follows a pattern that violates plugin rules.
The pattern's existence does not excuse it — name it clearly. Split by urgency:

**Fix in this PR (quick wins):** violations in code directly touched by this change, low blast radius.
- [confidence: X.X] `[file or area]`: [Direct statement.] — [rule reference]
  **Current pattern:** [What the app currently does.]
  **Plugin requires:** [What the rule or skill says.]
  **Verified:** [What you read to confirm both the pattern and the rule.]

**Record for later (significant debt):** violations that are load-bearing, cross-cutting, or require migrations — name them so the team can prioritize, but do not block the current PR.
- [confidence: X.X] `[file or area]`: [Direct statement.] — [rule reference]
  **Why deferred:** [Scope or risk reason.]

### Recommendations (non-blocking)
- [confidence: X.X] ...
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

- **RuboCop (zero offences, no disables):** `../running-rubocop/SKILL.md`, `../../rules/rubocop.mdc`
- **Compass (why / whether):** `../rails-omakase-compass/SKILL.md`
- **Planning:** `../writing-plans/SKILL.md` (plans should be reviewed with this skill via **`pitchd-rails-reviewer`**, Phase `plan`)
- **Full plan execution (orchestrator):** `../executing-pitchd-rails-plan/SKILL.md` — loops implementor → this reviewer until Approved, then user sign-off
- **Implementation (execute a task):** `../implementing-pitchd-rails/SKILL.md` — **`pitchd-rails-implementor`** for isolated task execution with compass + tactics
- **Pre-existing code in touched files (campground rule):** `../reviewing-touched-surroundings/SKILL.md` — use **`pitchd-rails-surroundings-reviewer`** for an isolated pass on surrounding code, not the new diff
