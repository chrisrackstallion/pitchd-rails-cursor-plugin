---
name: executing-pitchd-rails-plan
description: >-
  Orchestrates execution of a written Rails implementation plan in a DHH /
  37signals omakase style without writing application code: delegates each task
  to pitchd-rails-implementor, reviews via pitchd-rails-reviewer, and loops on
  feedback until Approved before user sign-off. Use when the user says execute
  the plan, run the plan, implement the plan, ship planned tasks, or wants a
  subset of plan tasks done in full with Pitchd conventions. Also handles
  post-execution revision requests — when the user says something needs changing,
  isn't right, or requests a fix after the skill has run, treat it as a
  self-contained revision task and run the same implement → review loop.
---

# Executing a Pitchd Rails plan (orchestrator)

<objective>
The agent using this skill is the **orchestrator only**. It **does not** write or
edit application code, tests, or migrations. It **delegates** implementation to
**`pitchd-rails-implementor`**, reviews with **`pitchd-rails-reviewer`**, and
loops until the reviewer **Approves**, then hands everything to the **user** for
sign-off.
</objective>

**Announce:** "I'm using the executing-pitchd-rails-plan skill (orchestrator mode — no app code)."

## When to use

- A **written plan** exists (see `../writing-pitchd-rails-plans/SKILL.md`) and the user wants it **executed**.
- The user names a **subset** of tasks (e.g. "tasks 2–4 only" or "Task 1 and Task 5").
- The user wants **Pitchd / omakase** execution without the main agent touching the codebase.

## Hard rules

1. **No application code** from the orchestrator — use the **Task** tool (or equivalent subagent dispatch) for **`pitchd-rails-implementor`** and **`pitchd-rails-reviewer`**. Shell may be used only for **orchestration** (e.g. `git diff`, `git status`) to describe scope to subagents — not to implement features. **Carve-out:** `docs/primitives/**` edits are orchestration bookkeeping, not app code — the orchestrator appends provenance lines, syncs Evaluations rows, flips `status:`, keeps the capability's `index.md` line in sync, and amends Intent clauses when revision mode's R1 classification calls for it (a user-directed intent change), directly per **`rules/primitives.mdc`**. Structural primitives work (splitting a capability, backfills, lint passes) is delegated to **`pitchd-rails-primitives-maintainer`**.
2. **Canonical skills:** Implementor follows **`../implementing-pitchd-rails/SKILL.md`**; reviewer follows **`../reviewing-pitchd-rails/SKILL.md`**.
3. **Sign-off from the Pitchd reviewer** means the latest **`pitchd-rails-reviewer`** report has **`Status: Approved`** (see that skill’s report format). If **Issues found**, feed them back to the implementor and **repeat** until Approved or the user accepts a documented exception (orchestrator records that choice).

## Before any delegation

If the user has **not** stated the following, **ask once** and wait for answers:

| Question | Options |
|----------|---------|
| **Execution mode** | **Step-by-step** — one plan task at a time; after each task is Approved, proceed to the next (no code from orchestrator). **Full run** — run the entire selected task list in one session: still **one task at a time** for implement → review loops, but **do not** pause for user confirmation between tasks unless a blocker needs a human decision. |
| **Scope** | Full plan vs **named task ids/numbers** (subset). |

**Subset:** If the user asks for specific tasks only, build an **ordered list** from the plan and execute **only** those tasks end-to-end (each with its own implement → review loop).

**Dependency extraction for subset runs:** Before delegating the first subset task, read all tasks the selected tasks depend on (earlier tasks referenced by "builds on Task N", "uses the schema from Task N", etc.) and summarise their outcomes in the **Context** block of the implementor prompt. The implementor has no parent context — it must not need to infer prior state from an unread plan. If a prior task produced a file or schema change the selected task needs, describe it explicitly (file path, column name, class name). Do not assume the implementor can infer from the plan file alone when the earlier task's *output* (not just description) matters.

Also confirm **plan path**, **spec path** (if any), and **work directory** (repo root or app path) so subagent prompts stay complete.

**Capability doc:** if the plan header has a **Capability:** line, read that
one doc (`docs/primitives/capabilities/<name>.md`) and `docs/primitives/compilation.md`
now — agents always read `compilation.md` when the tree exists — and never the
whole tree (`rules/primitives.mdc` reading contract). The capability doc
supplies the Intent clauses and Shape excerpts pasted into implementor
prompts, and it is the doc the close-out pass updates. If the line's path
does not resolve (doc renamed or deleted since planning), check `index.md`
for a rename; if it is genuinely gone, **stop and flag to the user** — do not
execute against a missing capability doc. No Capability line:
if `docs/primitives/` exists, **flag it to the user before proceeding** — the
plan predates primitives or skipped its gate (the reviewer treats that as a
plan defect), and executing it silently would drift the tree. Only when the
app has no tree do you skip everything primitives-related in this run.

## Per-task loop (repeat until Pitchd reviewer Approves)

For **each** task in scope (in plan order):

### 1. Delegate implementation

Invoke **`pitchd-rails-implementor`** with a self-contained prompt. Include at minimum:

- **Task name / id** and **full task text** from the plan (acceptance criteria, file layout — or plan path so the subagent can read it).
- **Context:** dependencies on prior tasks, architectural notes, anything the subagent cannot infer. When a capability doc exists, **paste the Intent clauses this task cites, the relevant Shape bullets, and any `compilation.md` constraints the task touches** into Context — the implementor reads zero primitives files; the excerpt is its whole primitives context and the only channel app-wide constraints reach it by.
- **Work directory**, **Plan path**, **Spec path** (use `none` when absent; if `none`, task text must be plan-complete per implementor rules).
- Instruction: follow **`skills/implementing-pitchd-rails/SKILL.md`**, no `git commit` unless the user explicitly overrode that elsewhere.

Use the prompt template in **`agents/pitchd-rails-implementor.md`** as the shape of the dispatch.

### 2. Delegate Pitchd review

Invoke **`pitchd-rails-reviewer`** with:

- **Phase:** `implementation` (or `both` if the task required plan-level re-validation).
- **Plan path**, **Spec path**, **Scope:** paths changed, or a short `git diff` summary / file list the orchestrator gathered read-only.
- **User revisions:** omit on the **first review** for a task. On **loop calls** (reviewing after a fix pass), set this to a bullet list of what the implementor changed — the reviewer will read only those areas.

Instruction: follow **`skills/reviewing-pitchd-rails/SKILL.md`** and return the standard **Pitchd Rails review** report.

### 3. Branch on status

- **`Status: Approved`** → proceed to **next task** (or, if no tasks remain, to **After all tasks are Approved** below).
- **`Issues found`** → send the **review feedback** (philosophy + tactical items that matter) back to **`pitchd-rails-implementor`** as a **fix pass** for the **same task**. Include reviewer quotes or bullet list so the subagent can act without parent chat history. When re-invoking the reviewer after the fix, pass **User revisions** scoped to what the implementor changed — do not re-review the full task diff. **Loop** until Approved.

### 4. Escalation from implementor

If the implementor returns **BLOCKED** or **NEEDS_CONTEXT**, **stop** and present the report to the **user**. Do not invent architecture; wait for decisions or smaller tasks.

## Revision mode (post-execution feedback)

### When to enter revision mode

After this skill has already run in the current chat session, treat any user
message as a **revision request** if it matches phrases like — but not limited
to — these:

> "this needs changing", "that's not right", "can you fix…", "this is wrong",
> "update this", "adjust…", "tweak…", "it should do X instead", "change the…"

**Do not** re-run the full plan. When the message is specific enough to act on
— what to change, where, and what "fixed" looks like — treat it as the complete
description of a **small, self-contained revision task** and proceed
immediately, without asking which plan task it relates to. When the message is
**vague** on any of those, **ask for clarification first — do not assume.**
A guessed revision delegated to the implementor wastes a full
implement → review loop on the wrong change.

### Revision task loop

Follow the same implement → review pattern as the per-task loop above, scoped
tightly to what the user described:

#### R1. Scope the revision

Extract from the user's message:

- **What to change** — the behaviour, output, or code the user flagged.
- **Where** — infer the file(s) from context (last task completed, files
  mentioned in the plan or conversation).
- **Acceptance** — what "fixed" looks like (derive from the user's wording;
  do not ask for a formal AC).

**Classify against Intent (when a capability doc exists):** read the doc's
`## Intent` and decide which of two revisions this is — the distinction
surfaces *before* delegating, not after:

- **The code failed the intent** (bug): "fixed" matches an existing clause.
  No Intent change and **no provenance line**; if the fix moved or added spec
  homes, sync the Evaluations rows (and `specs:` frontmatter) once the fix is
  Approved — a row sync alone is not a provenance event.
- **The intent changed** ("it should do X instead"): "fixed" contradicts a
  clause. Amend the clauses (supersede / add, per `rules/primitives.mdc`)
  alongside the fix. Once the fix is Approved: retire the superseded clause's
  Evaluations row (tombstone), add or update rows for the amended clauses
  from the fix's **reported** specs, sync `specs:` frontmatter, and append
  one provenance line:
  `YYYY-MM-DD — revised: I<n> amended (X instead of Y) per user feedback.`
  Report all of it in R5.

If any of the three is unclear from the message plus session context, **ask —
do not assume.** One focused message (the structured question tool works well
here) covering everything unclear; delegate only once answered.

#### R2. Delegate implementation

Invoke **`pitchd-rails-implementor`** with a self-contained revision prompt:

- **Task name:** `Revision: <one-line summary of the change>`
- **Task description:** Full description of what needs changing and why,
  including the file(s) to touch and the expected outcome.
- **Context:** Which plan task this relates to; any prior implementor output
  that is relevant (paste key snippets — the subagent has no chat history).
- **Work directory**, **Plan path**, **Spec path** as used in the original run.
- Instruction: scope the change tightly — **do not** refactor surrounding code
  outside the revision; follow `skills/implementing-pitchd-rails/SKILL.md` and
  `rules/rubocop.mdc`; no `git commit`.

#### R3. Delegate review

Invoke **`pitchd-rails-reviewer`** with:

- **Phase:** `implementation`
- **Scope:** only the files changed by the revision (not the full plan scope).
- **Plan path**, **Spec path** as above.
- **User revisions:** omit on the first review call. On loop calls (reviewing after a fix pass), set to a bullet list of what the implementor changed — the reviewer reads only those areas.

#### R4. Branch on status

- **`Status: Approved`** → report back to the user (see **R5** below).
- **`Issues found`** → feed review feedback to the implementor as a fix pass.
  When re-invoking the reviewer after the fix, pass **User revisions** scoped
  to what changed — do not re-review the full revision scope. Loop until Approved.
- **BLOCKED / NEEDS_CONTEXT** from implementor → stop, present the blocker to
  the user, and wait for a decision. If the user abandons an intent-change
  revision here, **revert the R1 clause amendments** — no shipped change
  references them, so the draft-stage edit rule applies
  (`rules/primitives.mdc`); note the reversal in chat, not provenance.

#### R5. Revision completion report

Deliver a brief summary:

- What was changed and in which file(s).
- Reviewer status (`Approved` after N iteration(s)).
- Any non-blocking notes from the reviewer worth the user knowing.
- Whether anything needs manual verification (tests run, RuboCop status).
- Primitives sync, if any (clause amendments, eval rows, the one provenance
  line — per the R1 classification).

**Do not** re-present the full original completion package — this is a targeted
revision report only. If the user's follow-up triggers another revision, repeat
from **R1**.

---

## After all tasks are Approved (Pitchd)

### 5. Whole-run coherence review (required for multi-task runs)

Per-task reviews only ever see one task's diff — defects that span tasks are
structurally invisible to them. Before the primitives close-out, invoke
**`pitchd-rails-reviewer`** once more over the **entire run's combined scope**:

- **Phase:** `implementation`
- **Scope:** every file changed across the run (gather read-only via
  `git diff` / `git status`). State that this is a **final sign-off** pass so
  the reviewer reads full scope; omit **User revisions**.
- **Focus (name it in the prompt):** cross-task coherence the per-task loops
  could not see — the **same method or behaviour defined on more than one
  entity** (one home: a concern or the owning model, `rules/models.mdc`),
  duplicated logic across tasks, naming drift between tasks, and duplicate
  test coverage across layers (`rules/testing.mdc`).

**Issues found** → route each finding back to **`pitchd-rails-implementor`**
as a fix pass (same shape as the per-task loop), then re-run this review
scoped via **User revisions** to what changed. Loop until Approved.

**Skip only** when the run executed a **single task** — that task's own review
already saw the whole diff.

### 6. Primitives close-out pass (required when the plan has a Capability line)

Part of the definition of done — **not an offer to the user**. The orchestrator
updates the capability doc directly (see the Hard rules carve-out):

1. **Evaluations rows** — fill or update one row per intent clause this plan
   touched, from the **specs the implementor actually reported** (file +
   example description) — never from what the plan promised. Superseded
   clauses get their rows retired with a one-line tombstone; delete-listed
   specs must actually be gone. Sync the `specs:` frontmatter.
2. **Status** — flip to **`status: built`** only when every active clause has
   an Evaluations row; otherwise report the gap instead of flipping.
3. **Provenance** — append **one** line for the whole run:

   ```markdown
   - YYYY-MM-DD — built [or amended]: docs/plans/<plan>.md; N tasks, approved
     after M review iterations. [Accepted debt or notable reviewer-approved
     exceptions, one line.]
   ```

   Fold in any **`primitives:` provenance candidates** from the reviewer
   reports (decisions, constraints, accepted debt) — one line each, only those
   with durable value.
4. **Index** — update the capability's `docs/primitives/index.md` line to the
   new status (it still says `planned` from plan approval — sync it, don't
   merely confirm it).

If a reviewer report proposed a **`compilation.md` amendment**, surface it to
the user — that file is human-owned; the orchestrator never edits it.

### 7. Handoff for user sign-off

Deliver a short **completion package**:

- Execution mode used and **task scope** completed.
- Per-task outcome (Approved after how many review iterations).
- **Whole-run coherence review** outcome (Step 5): Approved after N iterations, or skipped (single-task run).
- **Pitchd reviewer** final notes (if any non-blocking recommendations were in those reports).
- **Primitives close-out** summary (Step 6): status, eval rows updated, the provenance line appended — or why status could not flip.
- Anything still **uncommitted** or **needs manual verification** (tests run are reported by subagents — do not claim green unless subagents reported it).

**Stop** and ask the **user** explicitly for **sign-off** before the orchestrator treats the engagement as closed. Surface any proposed `compilation.md` amendments (Step 6) for the user's decision.

## Related

- **Plans:** `../writing-pitchd-rails-plans/SKILL.md`
- **Implement:** `../implementing-pitchd-rails/SKILL.md` — **`pitchd-rails-implementor`**
- **Review:** `../reviewing-pitchd-rails/SKILL.md` — **`pitchd-rails-reviewer`**
- **Primitives:** `../maintaining-primitives/SKILL.md`, `rules/primitives.mdc` — **`pitchd-rails-primitives-maintainer`** for structural passes
- **Subagent definitions:** `agents/pitchd-rails-implementor.md`, `agents/pitchd-rails-reviewer.md`, `agents/pitchd-rails-primitives-maintainer.md`
