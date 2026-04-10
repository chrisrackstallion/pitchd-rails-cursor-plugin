---
name: executing-pitchd-rails-plan
description: >-
  Orchestrates execution of a written Rails implementation plan in a DHH /
  37signals omakase style without writing application code: delegates each task
  to pitchd-rails-implementor, reviews via pitchd-rails-reviewer, loops on
  feedback until Approved, then requests recommendations from dhh-rails-reviewer
  before user sign-off. Use when the user says execute the plan, run the plan,
  implement the plan, ship planned tasks, or wants a subset of plan tasks done
  in full with Pitchd conventions.
---

# Executing a Pitchd Rails plan (orchestrator)

<objective>
The agent using this skill is the **orchestrator only**. It **does not** write or
edit application code, tests, or migrations. It **delegates** implementation to
**`pitchd-rails-implementor`**, reviews with **`pitchd-rails-reviewer`**, and
loops until the reviewer **Approves**. Before declaring work complete, it asks
**`dhh-rails-reviewer`** for final recommendations, then hands everything to the
**user** for sign-off.
</objective>

**Announce:** "I'm using the executing-pitchd-rails skill (orchestrator mode — no app code)."

## When to use

- A **written plan** exists (see `../writing-plans/SKILL.md`) and the user wants it **executed**.
- The user names a **subset** of tasks (e.g. "tasks 2–4 only" or "Task 1 and Task 5").
- The user wants **Pitchd / omakase** execution without the main agent touching the codebase.

## Hard rules

1. **No application code** from the orchestrator — use the **Task** tool (or equivalent subagent dispatch) for **`pitchd-rails-implementor`** and **`pitchd-rails-reviewer`**. Shell may be used only for **orchestration** (e.g. `git diff`, `git status`) to describe scope to subagents — not to implement features.
2. **Canonical skills:** Implementor follows **`../implementing-pitchd-rails/SKILL.md`**; reviewer follows **`../reviewing-pitchd-rails/SKILL.md`**.
3. **Sign-off from the Pitchd reviewer** means the latest **`pitchd-rails-reviewer`** report has **`Status: Approved`** (see that skill’s report format). If **Issues found**, feed them back to the implementor and **repeat** until Approved or the user accepts a documented exception (orchestrator records that choice).
4. **`dhh-rails-reviewer`** is a **final lens** (opinionated DHH / Rails gravity), not a substitute for **`pitchd-rails-reviewer`**. Run it **after** Pitchd review Approves the scoped work, **before** the final user handoff.

## Before any delegation

If the user has **not** stated the following, **ask once** and wait for answers:

| Question | Options |
|----------|---------|
| **Execution mode** | **Step-by-step** — one plan task at a time; after each task is Approved, proceed to the next (no code from orchestrator). **Full run** — run the entire selected task list in one session: still **one task at a time** for implement → review loops, but **do not** pause for user confirmation between tasks unless a blocker needs a human decision. |
| **Scope** | Full plan vs **named task ids/numbers** (subset). |

**Subset:** If the user asks for specific tasks only, build an **ordered list** from the plan and execute **only** those tasks end-to-end (each with its own implement → review loop).

**Dependency extraction for subset runs:** Before delegating the first subset task, read all tasks the selected tasks depend on (earlier tasks referenced by "builds on Task N", "uses the schema from Task N", etc.) and summarise their outcomes in the **Context** block of the implementor prompt. The implementor has no parent context — it must not need to infer prior state from an unread plan. If a prior task produced a file or schema change the selected task needs, describe it explicitly (file path, column name, class name). Do not assume the implementor can infer from the plan file alone when the earlier task's *output* (not just description) matters.

Also confirm **plan path**, **spec path** (if any), and **work directory** (repo root or app path) so subagent prompts stay complete.

## Per-task loop (repeat until Pitchd reviewer Approves)

For **each** task in scope (in plan order):

### 1. Delegate implementation

Invoke **`pitchd-rails-implementor`** with a self-contained prompt. Include at minimum:

- **Task name / id** and **full task text** from the plan (acceptance criteria, file layout — or plan path so the subagent can read it).
- **Context:** dependencies on prior tasks, architectural notes, anything the subagent cannot infer.
- **Work directory**, **Plan path**, **Spec path** (use `none` when absent; if `none`, task text must be plan-complete per implementor rules).
- Instruction: follow **`skills/implementing-pitchd-rails/SKILL.md`**, no `git commit` unless the user explicitly overrode that elsewhere.

Use the prompt template in **`.cursor/agents/pitchd-rails-implementor.md`** as the shape of the dispatch.

### 2. Delegate Pitchd review

Invoke **`pitchd-rails-reviewer`** with:

- **Phase:** `implementation` (or `both` if the task required plan-level re-validation).
- **Plan path**, **Spec path**, **Scope:** paths changed, or a short `git diff` summary / file list the orchestrator gathered read-only.

Instruction: follow **`skills/reviewing-pitchd-rails/SKILL.md`** and return the standard **Pitchd Rails review** report.

### 3. Branch on status

- **`Status: Approved`** → proceed to **next task** (or to **final DHH pass** if no tasks remain).
- **`Issues found`** → send the **review feedback** (philosophy + tactical items that matter) back to **`pitchd-rails-implementor`** as a **fix pass** for the **same task**. Include reviewer quotes or bullet list so the subagent can act without parent chat history. **Loop** until Approved.

### 4. Escalation from implementor

If the implementor returns **BLOCKED** or **NEEDS_CONTEXT**, **stop** and present the report to the **user**. Do not invent architecture; wait for decisions or smaller tasks.

## After all tasks are Approved (Pitchd)

### 5. Recommendations from `dhh-rails-reviewer`

Before calling the work **finished**, invoke **`dhh-rails-reviewer`** (Task `subagent_type` **`dhh-rails-reviewer`**). Pass:

- Summary of what was implemented (task list completed).
- **Scope** for review: cumulative changed paths, or diff summary across the branch/session.

Ask explicitly for **recommendations** (non-blocking improvements, residual risks). Surface the full response to the user. If the subagent returns **JSON-only**, also ask in the same dispatch for a **brief prose summary** of top recommendations so the handoff stays readable. If that subagent is unavailable in the environment, say so and offer **`pitchd-rails-reviewer`**-only completion — do not skip documenting the gap.

### 6. Handoff for user sign-off

Deliver a short **completion package**:

- Execution mode used and **task scope** completed.
- Per-task outcome (Approved after how many review iterations).
- **Pitchd reviewer** final notes (if any non-blocking recommendations were in those reports).
- **`dhh-rails-reviewer`** recommendations section.
- Anything still **uncommitted** or **needs manual verification** (tests run are reported by subagents — do not claim green unless subagents reported it).

**Stop** and ask the **user** explicitly for **sign-off** before the orchestrator treats the engagement as closed.

## Related

- **Plans:** `../writing-plans/SKILL.md`
- **Implement:** `../implementing-pitchd-rails/SKILL.md` — **`pitchd-rails-implementor`**
- **Review:** `../reviewing-pitchd-rails/SKILL.md` — **`pitchd-rails-reviewer`**
- **DHH lens (final recommendations):** `dhh-rails-reviewer` subagent (Task tool)
- **Subagent definitions:** `.cursor/agents/pitchd-rails-implementor.md`, `.cursor/agents/pitchd-rails-reviewer.md`
