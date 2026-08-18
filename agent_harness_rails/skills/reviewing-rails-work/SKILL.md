---
name: reviewing-rails-work
description: >-
  Review Rails plans and/or implementation against the harness: first
  rails-omakase-compass (solution shape), then applicable writing-* skills and
  rules (tactics). Use when requesting a code review, plan review, PR review, or
  sign-off before merge. For isolated delegation with a clean context, use the
  rails-reviewer subagent (see `agent_harness_rails/agents/rails-reviewer.md`).
---

# Reviewing Rails Agent Harness (plans & implementation)

<objective>
Run a **two-layer** review: **philosophy** (`rails-omakase-compass`) for whether
the work is the **right kind of Rails solution**, then **tactics**
(`writing-*`, `agent_harness_rails/rules/*.mdc`) for **correct usage**. Do not duplicate the
compass inside this file — read it first when reviewing.

Be direct. State violations as violations, not suggestions. "This violates
`agent_harness_rails/rules/services.mdc`" — not "you might want to consider". The harness rules exist
because DHH and 37signals have already made these decisions; the job here is to
apply them, not re-debate them.
</objective>

**Announce:** "I'm using the reviewing-rails-work skill."

## When to use

- After a **plan** is written (before large implementation).
- After **implementation** (PR, branch, or milestone).
- **Both** when you want end-to-end assurance.

## Process

### 0. Scope check — user revisions

**If this is a final sign-off pass (the prompt says "final sign-off"):** review the full scope regardless of User revisions. User revisions is context — it tells you where to pay closest attention; it does not restrict what you read.

**If User revisions was provided (loop pass — fixes applied after a previous review found issues):** restrict this review to the described changed sections only. Locate and read only those sections or paths in the relevant artifact (plan file, code files, or both depending on Phase); skip the rest. Load compass and tactical skills only for the areas that changed — do not re-run full compass or reload all skills for unchanged sections. Note in the report: "**Scope:** User revisions — [brief restatement of what changed]."

**If User revisions is absent and this is not a final sign-off:** review the full scope as specified.

### 1. Verify before asserting

**Read the actual code** for every finding before reporting it. Do not assert issues from diff headers, file names, memory, or inference alone.

For each finding:
1. Open the cited file and confirm the relevant code exists exactly as you'll state it.
2. Verify the violation is not already handled elsewhere in the same scope.
3. Confirm the rule or skill you're citing actually prohibits what you're claiming — read the rule.

Drop any finding you cannot verify. A missing finding is better than a hallucinated one.

### 2. Load the compass

Read **`agent_harness_rails/skills/rails-omakase-compass/SKILL.md`**. Use it for:

- HTML vs API / parallel JSON app for the same flow
- Server-owned truth vs client-as-source-of-truth
- REST gravity vs RPC
- Fat domain vs orchestration scripts
- Monolith boundaries, progressive enhancement, documented exceptions

Prefix these findings **`philosophy:`**.

### 3. Select tactical skills by scope

From the diff or plan, pick **only** the skills that apply:

`writing-rails-plans`, `writing-models`, `writing-routes`, `writing-controllers`,
`writing-hotwire`, `writing-views`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-mailers`, `writing-policies`, `writing-services`,
`writing-jobs`, `writing-migrations`, `writing-tests`,
`running-rubocop` (when the app uses RuboCop: expect **zero** offences — fix in code, no disables, no `.rubocop_todo.yml`; not architecture).

Read each skill’s **SKILL.md** and the relevant **`references/patterns.md`**
sections (not necessarily entire files). Cross-check **`rules/<area>.mdc`**.

**Coverage rule:** map every changed file (or plan area) to its skill/rule
pair before concluding. An area reviewed without its skill and rule loaded is
an area you did not review — do not report `Status: Approved` while any
touched area's conventions are unread. If a diff touches a layer with no
matching row (rare), say so in the report rather than silently skipping it.

Prefix these findings **`tactical:`**.

### 4. Conflict rule

- **Tactics** win on **specific** HOW (this repo’s rules and patterns).
- **Compass** wins on **whether** the approach matches **majestic monolith /
  omakase** intent — unless the user or plan has **explicitly** chosen a
  different shape (API-first, SPA, etc.); then treat it as a documented
  exception and review tactics for consistency with that choice.

### 5. Primitives checks

Runs when the app has a **`docs/primitives/`** tree (see `agent_harness_rails/rules/primitives.mdc`).
Read the **one** capability doc named by the plan header's **Capability:** line
(or located via `docs/primitives/index.md`) plus `compilation.md` — never the
whole tree. No tree → note "No primitives tree" in the report and skip.
**Run `agent_harness_rails evals` first.** Clause coverage, dead spec paths, untagged
evaluations, tags naming a superseded clause — it settles all of those with
file:line. Cite its output rather than re-deriving it by hand, and spend the
review on what it cannot judge: whether a clause is the *right* clause.

Prefix these findings **`primitives:`**. They are checkable properties, not
suggestions:

- **Traceability** — every behaviour in the plan or diff maps to an active
  `intent:` clause. Untraceable behaviour is a finding: either a missing clause
  or scope creep. A plan whose header lacks the **Capability:** line when the
  tree exists is a finding.
- **No overlap** — a new capability doc whose intent overlaps an existing one
  is a plan defect (should be an amendment).
- **Compilation and Shape** — nothing contradicts `compilation.md` or the
  doc's recorded Shape; a change that needs a constraint amended says so
  explicitly rather than working around it. These are `philosophy:`-grade.
- **Supersession hygiene** — intent changes are explicit (tombstone + new ID,
  never renumbered or silently deleted). Plan phase: the plan **schedules**
  row retirement and deletion of the superseded clause's now-dead specs.
  Post-close-out: retired clauses have their rows retired and those specs
  actually deleted (a live spec enforcing a dead clause is a zombie). During
  per-task loops that state is pending, not a finding.
- **Eval coverage** — plan phase: every touched clause gets a spec home in the
  plan's tasks. Rows for **new** work are written at close-out — a plan
  pre-filling them from intention is a finding; rows transcribed from
  **already-existing specs** (lazy backfill, prior capture, earlier
  close-outs) and `unproven` rows (`agent_harness_rails/rules/primitives.mdc`) are legitimately
  present at plan time. Implementation phase, **per-task reviews**: rows are
  not yet written — close-out fills them after all tasks approve — so check
  that the task delivered the spec homes its cited clauses need, not the
  rows. **Post-close-out reviews only:** every touched clause has a row
  pointing at real reported specs; `status: built` with a missing row is a
  finding.
- **Provenance conflicts** — the work does not re-litigate a recorded
  rejection or undo a recorded deliberate decision without saying so.

**Provenance candidates (non-blocking):** decisions with rationale, non-obvious
constraints discovered, knowingly accepted debt — list them in the report's
**primitives:** section so the execution close-out pass can file them as
one-line provenance entries. Not routine implementation details, and never run
mechanics (review iterations, fix passes, commands, who did the work) — a
candidate must be something a reader a year out would act on
(`agent_harness_rails/rules/primitives.mdc` § Provenance).

### 6. What to check by phase

**Plan:** Completeness (no blocking TODOs), spec alignment, vertical slices,
runnable tasks, buildability; compass on interface (HTML vs API) and correct
layer for rules; `writing-rails-plans` fit; red flags from `writing-rails-plans` (services,
RPC, missing policy, Turbo escalation before simpler options, duplicate test
coverage). **Cross-task duplication:** read the task list as a whole — the
same method or behaviour defined on more than one entity across tasks is a
finding (one home: a concern or the owning model, `agent_harness_rails/rules/models.mdc`);
per-task reading hides it. **Delivery scope:** the header carries a
**Delivery:** line and the plan honours `writing-rails-plans` § PR and
deployment scope — one PR within the ~400-changed-app-line target, or
declared seam-based PR boundaries, each an independently deployable vertical
increment; when the spec has a `## Delivery sequence`, the plan covers
exactly **one slice** of it. A layer-split boundary, a contract-step
migration riding with its expand step, a task only safe once a later PR
lands, or a plan spanning multiple slices is a finding.
**Frame:** the header's **Problem:** line states a real need (not a
restated mechanism), the **Approach** follows from it, **Alternatives
considered:** is present (an explicit "none credible" counts — absence does
not), and no task works around a framework default. Fighting the framework is
a `philosophy:` finding even when every tactic is clean.

**Implementation:** Map changed files to skills; compass on overall drift; one
home per behaviour for tests (`writing-tests`). **One home per behaviour for
code too:** scan the scope as a whole, not file by file — grep the changed
files for method definitions that repeat across entities. The same method
defined on multiple models is a `tactical:` finding: shared behaviour belongs
in a concern or on the owning model (`agent_harness_rails/rules/models.mdc`).

### 7. Surroundings pass (pre-existing code in touched files)

**When:** `implementation` or `both` phases only. Skip for plan-only reviews.

After reviewing the new code, scan **pre-existing** (unchanged or lightly
adapted) code in the same touched files. Apply compass + tactical checks to
**surrounding blocks** only — methods, concerns, and imports that the diff did
**not** add or materially rewrite.

**Boundary rule:** Lines added or materially rewritten by this change are new
code — already covered above. Lines that were there before and remain
substantially unchanged are surrounding code — covered here. Greenfield files
that are entirely new: skip and note "No surrounding code."

For each surrounding finding:

1. Open the cited file and confirm the surrounding lines exist as stated.
2. Verify the issue is not handled elsewhere in the same scope.
3. Confirm the rule or skill you're citing actually prohibits the pattern.

Drop any finding you cannot verify. Prefix philosophy findings
**`surrounding/philosophy:`** and tactical findings **`surrounding/tactical:`**.
Use the same confidence scale (§8 Calibration). Do not repeat findings already
in the main review.

**Quick wins:** in-file, low blast radius, fits a follow-up commit in the same
PR or a small chore PR.
**Separate follow-ups:** refactors that change behaviour surface, span many
files, or need migrations/QA — still report them; label clearly.

### 8. Calibration

**Flag all violations of harness rules.** Harness conventions — `rails-omakase-compass`,
`writing-*` skills, and `agent_harness_rails/rules/*.mdc` — apply even when the application currently does
otherwise. An established application pattern is not a justification; it may be exactly
the debt worth naming. State violations directly: "This violates `agent_harness_rails/rules/services.mdc`:
a thin wrapper around Active Record is not a service object."

**Assign a confidence score (0.0–1.0) to every finding:**
- **0.9–1.0:** You read the exact code and confirmed the rule violation. High certainty.
- **0.7–0.9:** You read the code; some interpretive judgment involved.
- **0.5–0.7:** Inference required (e.g. plan-only review, no implementation to read yet).
- **Below 0.5:** Drop the finding or flag explicitly as "uncertain — verify before acting."

Suppress only findings you cannot verify at all. Do not suppress because the issue
seems small — small harness violations are still violations.

**Necessity gate for everything that is not a rule violation.** Recommendations
and judgment-based feedback go through a filter before they reach the report:
is this change actually necessary, or does it add complexity to the
implementation, the tests, or both? A recommendation that adds indirection,
another object, another layer of specs, or configuration for a hypothetical
future need is over-engineering wearing a review's clothes — drop it. The
omakase posture applies to the reviewer too: the boring, direct version that
satisfies the rules is the goal, not the most defensively engineered one.
Concretely, before writing a recommendation ask:

- Does acting on it make the code **simpler or more correct** — or merely
  more elaborate?
- Does it create **new test surface** beyond the one-home-per-behaviour rule
  (`agent_harness_rails/rules/testing.mdc`)?
- Would the implementor have to add a method, object, or abstraction that
  fails the "earns its place" test (`agent_harness_rails/rules/models.mdc`, `agent_harness_rails/rules/services.mdc`)?

If a recommendation fails this gate, it does not belong in the report at any
confidence level. Rule violations are exempt — they are always reported.

## Report format

Produce a single Markdown report with these sections. Every finding carries a
**confidence score** and a **Verified** note showing what you read to confirm it.

```markdown
## Harness review

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
Issues where the current codebase follows a pattern that violates harness rules.
The pattern's existence does not excuse it — name it clearly. Split by urgency:

**Fix in this PR (quick wins):** violations in code directly touched by this change, low blast radius.
- [confidence: X.X] `[file or area]`: [Direct statement.] — [rule reference]
  **Current pattern:** [What the app currently does.]
  **Harness requires:** [What the rule or skill says.]
  **Verified:** [What you read to confirm both the pattern and the rule.]

**Record for later (significant debt):** violations that are load-bearing, cross-cutting, or require migrations — name them so the team can prioritize, but do not block the current PR.
- [confidence: X.X] `[file or area]`: [Direct statement.] — [rule reference]
  **Why deferred:** [Scope or risk reason.]

### Recommendations (non-blocking)
_Necessity-gated (§8): only recommendations whose benefit outweighs the
implementation and test complexity they add. No speculative hardening,
no extra layers, no nice-to-haves._
- [confidence: X.X] ...

### Surroundings (pre-existing code in touched files)
_Implementation and both phases only. Omit this section for plan-only reviews._

**Boundary:** [How new vs surrounding was determined — diff, plan, or inference.]

**Quick wins (same PR or small chore):**
- [confidence: X.X] `[path]` (surrounding): [Direct statement.] — [rule reference]
  **Verified:** [What you read.]

**Separate follow-ups (handle outside this feature):**
- [confidence: X.X] `[path]`: [Direct statement — why separate.]

### primitives: (traceability, compilation, evals, provenance)
_Only when the app has a `docs/primitives/` tree; otherwise state "No primitives tree" and omit the findings._

- [confidence: X.X] `[file or area]`: [Direct statement — untraceable behaviour, compilation/Shape contradiction, missing evaluation, supersession hygiene, provenance conflict.] — `agent_harness_rails/rules/primitives.mdc`
  **Verified:** [Capability doc + code you read to confirm, and the `agent_harness_rails evals` result.]

**Provenance candidates (non-blocking):** decisions, constraints, or accepted debt worth a one-line provenance entry at close-out. Only durable value — not every implementation detail.
- ...
```

End with a **one-line summary** for quick scanning.

## Subagent (optional)

The **`rails-reviewer`** custom subagent ([Cursor
subagents](https://cursor.com/docs/subagents)) at **`agent_harness_rails/agents/rails-reviewer.md`**
implements **this skill** in an **isolated context** (`readonly: true`,
`model: inherit`). It does not see parent chat — the delegating agent must pass
**Phase**, plan path, spec path, and **Scope** in the task prompt. Invoke with
`/rails-reviewer` or the Task tool. The subagent’s instructions only add
context-isolation rules; the workflow and report shape are defined **here**.

## Related

- **RuboCop (zero offences, no disables):** `agent_harness_rails/skills/running-rubocop/SKILL.md`, `agent_harness_rails/rules/rubocop.mdc`
- **Compass (why / whether):** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **Planning:** `agent_harness_rails/skills/writing-rails-plans/SKILL.md` (plans should be reviewed with this skill via **`rails-reviewer`**, Phase `plan`)
- **Full plan execution (orchestrator):** `agent_harness_rails/skills/executing-rails-plan/SKILL.md` — loops implementor → this reviewer until Approved, then user sign-off
- **Implementation (execute a task):** `agent_harness_rails/skills/implementing-rails-task/SKILL.md` — **`rails-implementor`** for isolated task execution with compass + tactics
