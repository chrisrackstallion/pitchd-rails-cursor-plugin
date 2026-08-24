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

Be direct. State violations as violations, not suggestions: "This violates
`agent_harness_rails/rules/services.mdc`" — not "you might want to consider". Harness rules are
settled decisions; apply them, do not re-debate them.
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

**Every diff, whatever the layer:** `agent_harness_rails/rules/naming.mdc` and
`agent_harness_rails/rules/comments.mdc`. A comment that restates the code,
narrates a step, signposts a section, or documents shape the primitives tree
owns is a `tactical:` finding — the default is no comment.

**Coverage rule:** map every changed file (or plan area) to its skill/rule
pair before concluding — do not report `Status: Approved` while any touched
area's conventions are unread. If a diff touches a layer with no matching row
(rare), say so in the report rather than silently skipping it.

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

**The mechanical output arrives with the prompt.** A delegating orchestrator
runs the three commands and pastes their stdout under **Mechanical primitives
output (authoritative — do not re-run)** — cite that block. Run them yourself
only when you are the top-level agent with a working shell:

```bash
agent_harness_rails evals                            # clause coverage; exits 1 on findings
agent_harness_rails guard --base <the diff's base>   # what this change did to the record
agent_harness_rails proofs --since <the diff's base> # what carries each tag, per file
```

**No block and no working shell → `UNVERIFIED (CLI unavailable)`.** Ask the
delegating agent once for the output; retry a call once if you have a shell.
Then report those checks as unverified in the **primitives:** section and name
what stayed unchecked. A hand read of the frontmatter and the `intent:` tags is
**not** the same check — reporting it as coverage hides that nothing ran
(`agent_harness_rails/rules/primitives.mdc` § None of these is quiet). None of
these commands is silent, so an empty result is a missing result and never a
green one: `Status: Approved` resting on the mechanical checks is not available
on one.

**`evals` settles** clause coverage, dead spec paths, untagged evaluations, and
tags naming a superseded clause, with file:line — cite it rather than
re-deriving it by hand, and spend the review on what it cannot judge: whether a
clause is the *right* clause.

**`guard` reads what `evals` cannot.** `evals` reads the tree as it stands;
`guard` reads what this change *did* to it — a clause reworded under the same
id, one deleted rather than superseded, an evaluation dropped or moved to a
layer that cannot hold it, a tagged example hollowed out, an edited provenance
entry. Its output is notices, never offences, so cite them with a
verdict rather than copying them in as findings. Two turn into findings:

- An **intent** notice (`intent/rewritten`, `intent/vanished`, `doc/removed`,
  `status/downgraded`, `provenance/rewritten`) with no matching row in the plan's
  **Intent impact** table — the change amended a promise nothing scheduled, which
  is scope creep into intent whatever the code does.
- A **proof** notice (`proof/removed`, `proof/weakened`, `evaluation/dropped`,
  `evaluation/relayered`) on a clause that is still active — **Eval adequacy**
  below, with the before-state attached: the clause is now proven by less than it
  was, and the report should name what stopped being covered.

Never clear a notice by editing the tree — a reviewer that writes the provenance
entry discharging an intent notice has laundered the finding it was reading.

Prefix these findings **`primitives:`**. They are checkable properties, not
suggestions:

- **Traceability** — every behaviour in the plan or diff maps to an active
  `intent:` clause. Untraceable behaviour is a finding: either a missing clause
  or scope creep. A plan whose header lacks the **Capability:** line when the
  tree exists is a finding.
- **Intent impact declared** — plan phase. The plan header carries the **Intent
  impact** table: every touched clause, its change (`new` / `amended` /
  `superseded by I<n>` / `unchanged — regression contract`), and the layer its
  proof will land at (`writing-rails-plans` § Plan document header). A missing
  table, a clause the tasks touch that the table omits, or a table row no task
  delivers is a finding. A Shape-only plan states `no intent delta` and lists its
  regression contract; a plan claiming `no intent delta` while a clause's wording
  changes is a mislabelled amendment.
- **Clause admissibility** — every new or amended clause passes all four tests:
  observable, falsifiable, one behaviour, **durable**
  (`agent_harness_rails/rules/primitives.mdc` § Intent clauses). Architecture,
  technology choices, refactors, and task lists written as clauses are the common
  failure and belong in `## Shape` or the task list; run the durable test first,
  since it disposes of all four at once.
- **Clause granularity** — **plan phase.** One behaviour per clause: an umbrella
  verb (*manage*, *handle*, *support*) or an `and` joining two different actions
  is several promises in one sentence
  (`agent_harness_rails/rules/primitives.mdc` § Intent clauses); missed here, its
  only possible proof is a sprawling system spec, against the budget and the Five
  Gates. Report the split with the per-action sentences written out. The opposite
  is also a finding: clauses split so fine they differ only by which layer proves
  them are the suite transcribed into the tree.
- **No overlap** — a new capability doc whose intent overlaps an existing one
  is a plan defect (should be an amendment). Read `index.md` end to end before
  accepting a new doc — the only place overlap is visible without opening the
  whole tree. If two lines are too vague to tell apart, report **that** as the
  finding: an indiscriminate index line is how duplicate capabilities get
  created (`agent_harness_rails/rules/primitives.mdc`
  § Finding the right capability).
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
  close-outs) are legitimately present at plan time
  (`agent_harness_rails/rules/primitives.mdc`). Implementation phase, **per-task reviews**: rows are
  not yet written — close-out fills them after all tasks approve — so check
  that the task delivered the spec homes its cited clauses need, not the
  rows. **Post-close-out reviews only:** every touched clause has a row
  pointing at real reported specs; `status: built` with a missing row is a
  finding, and no annotation excuses one. Check the tags landed on the
  **examples** that prove each clause — a tag on a `describe` or `context` is a
  finding, because it keeps resolving after the example it stood for is
  deleted.
- **Eval adequacy** — the check `agent_harness_rails evals` cannot make: **would
  breaking the clause turn a tagged example red?** Start from the
  **`proofs`** output for each touched clause: it lists what carries the tag and,
  per evaluation file, what carries none. `proofs --since <base>` carries that
  untagged listing for every clause the change touched — the same detail
  `proofs '<capability>#I<n>'` gives for one — so the pasted block usually
  answers this without a further call. Read that against the plan's **Intent
  impact** row, which names the cases the clause needs. A case the row named that sits in the untagged list is a finding —
  `evals` is green on it, because one tag makes the whole file a carrier, so a
  clause meant to be proven by four denials passes with three tagged. Then read
  each touched clause's wording against its evaluations. A quantifier (*only*, *never*, *any*, *every*) proven by one
  happy path is a finding; so is an example asserting the affordance (form
  renders, `200` returned) where the clause names an outcome; so is a denial
  bolted onto a canonical journey instead of living in the policy or request
  spec that owns it (`agent_harness_rails/rules/testing.mdc`
  § What counts as proving a clause). Report the missing case, not "add more
  tests" — name the clause, the half that is unproven, and the layer it belongs
  at.

  Then run it the other way: **is every listed evaluation necessary?** An
  evaluation you could delete with the clause still fully proven is padding.
  More than ~3 on one clause is a tripwire — usually two promises sharing an id
  (`agent_harness_rails/rules/primitives.mdc` § Size discipline).
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
files for method definitions that repeat across entities; the same method on
multiple models is a `tactical:` finding (shared behaviour belongs in a
concern or on the owning model, `agent_harness_rails/rules/models.mdc`).

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

Verify each surrounding finding per §1 (read the lines, confirm the issue is
not handled elsewhere, read the cited rule); drop any you cannot verify.
Prefix philosophy findings
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

**Necessity gate for everything that is not a rule violation.** Before a
recommendation or judgment-based item reaches the report: is it actually
necessary, or does it add complexity to the implementation, the tests, or
both? A recommendation that adds indirection, another object, another layer of
specs, or configuration for a hypothetical future need is over-engineering —
drop it. The omakase posture applies to the reviewer too: the boring, direct
version that satisfies the rules is the goal. Before writing a recommendation
ask:

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

**Mechanical checks:** [`evals` / `guard` / `proofs` summary lines quoted from the pasted **Mechanical primitives output** block — or `UNVERIFIED (CLI unavailable)`, the checks that did not run, and the findings that would have rested on them.]

- [confidence: X.X] `[file or area]`: [Direct statement — untraceable behaviour, compilation/Shape contradiction, missing evaluation, supersession hygiene, provenance conflict.] — `agent_harness_rails/rules/primitives.mdc`
  **Verified:** [Capability doc + code you read to confirm, and the `agent_harness_rails evals` result — or that it was unavailable.]

**Provenance candidates (non-blocking):** decisions, constraints, or accepted debt worth a one-line provenance entry at close-out. Only durable value — not every implementation detail.
- ...
```

End with a **one-line summary** for quick scanning.

## Subagent (optional)

The **`rails-reviewer`** custom subagent ([Cursor
subagents](https://cursor.com/docs/subagents)) at **`agent_harness_rails/agents/rails-reviewer.md`**
implements **this skill** in an **isolated context** (`readonly: true`,
`model: inherit`). It does not see parent chat — the delegating agent must pass
**Phase**, plan path, spec path, **Scope**, and, when the app has a primitives
tree, the **Mechanical primitives output** block in the task prompt.
`readonly: true` is deliberate — a reviewer that edits the tree launders the
notice it was reading — and it is also why that block is pasted rather than
shelled out for: a readonly worker may have no shell at all. Invoke with
`/rails-reviewer` or the Task tool. The subagent’s instructions only add
context-isolation rules; the workflow and report shape are defined **here**.

## Related

- **RuboCop (zero offences, no disables):** `agent_harness_rails/skills/running-rubocop/SKILL.md`, `agent_harness_rails/rules/rubocop.mdc`
- **Compass (why / whether):** `agent_harness_rails/skills/rails-omakase-compass/SKILL.md`
- **Planning:** `agent_harness_rails/skills/writing-rails-plans/SKILL.md` (plans should be reviewed with this skill via **`rails-reviewer`**, Phase `plan`)
- **Full plan execution (orchestrator):** `agent_harness_rails/skills/executing-rails-plan/SKILL.md` — loops implementor → this reviewer until Approved, then user sign-off
- **Implementation (execute a task):** `agent_harness_rails/skills/implementing-rails-task/SKILL.md` — **`rails-implementor`** for isolated task execution with compass + tactics
