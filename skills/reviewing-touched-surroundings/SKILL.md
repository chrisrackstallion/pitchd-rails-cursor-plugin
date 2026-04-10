---
name: reviewing-touched-surroundings
description: >-
  Review pre-existing code in files touched by a plan or diff — not the new
  implementation — for Rails best practice, omakase/37signals fit, and Pitchd
  plugin rules. Use to leave the codebase better when shipping features; for
  isolated delegation use pitchd-rails-surroundings-reviewer.
---

# Reviewing touched surroundings (pre-existing code)

<objective>
When a **plan** or **implementation** changes a file, the **unchanged**
portions of that file (and closely related context in the same file) are
**surrounding code**. This pass asks: did we miss chances to align that
surrounding code with **Rails omakase**, **DHH / 37signals-shaped** practice,
and **this plugin's** `writing-*` skills and `rules/*.mdc` — without re-reviewing
the new feature code itself?

Be direct. State what the code does wrong and what the rule says. Do not suggest
or hedge — a violation is a violation whether the surrounding code has been there
for two weeks or two years.
</objective>

**Announce:** "I'm using the reviewing-touched-surroundings skill."

## When to use

- After you have a **plan** and know which files it touches, or after an
  **implementation** with a **diff** (or file list).
- When the goal is **campground rule**: leave files we touched in **better
  shape**, not only add the new behavior.
- **Not** a substitute for `reviewing-pitchd-rails` on the **new** work — use
  both: one for the feature, this one for **legacy / surrounding** code in the
  same paths.

## Inputs

| Input | Meaning |
|-------|---------|
| **Phase** | `plan` \| `implementation` \| `both` |
| **Plan path** | Plan file(s), or `none` |
| **Spec path** | Requirements/spec, or `none` |
| **Scope** | Paths or globs touched, plus **git diff** or **explicit new-line list** from the implementer |

If diff or line ranges for *new* code are missing, infer from the plan's task
list and still flag **file-level** surrounding smells — but say when inference
was needed.

## What counts as "pre-existing" vs in-scope for this pass

| In scope (review this) | Out of scope (do not dwell here) |
|------------------------|----------------------------------|
| Lines **not** added or materially rewritten by the current plan/PR | The **new** implementation blocks (the planned feature / diff additions) |
| **Adjacent** methods, classes, partials, or concerns **in the same file** that the diff didn't replace | Greenfield files that are **entirely** new in this change |
| **Imports**, **constants**, and **comments** left untouched if they conflict with current rules | — |
| **Nearby** violations that are **cheap** to fix in the same edit (call out even if small) | — |

**Materially rewritten:** treat as new for this pass. **Moved** code: review it
as surrounding in its **destination** file.

If the entire file is new, report **"No surrounding code in touched files"**
and stop after a one-line summary.

## Process

### 0. Verify before asserting

**Read the actual surrounding code** before reporting any finding. Do not assert
violations from file names, diff headers, or memory alone.

For each finding:
1. Open the cited file and confirm the relevant surrounding lines exist exactly as you'll state.
2. Verify the violation is not handled elsewhere in the same scope.
3. Confirm the rule or skill you're citing actually prohibits what you're claiming — read the rule.

Drop any finding you cannot verify. A missing finding is better than a hallucinated one.

### 1. Establish boundaries

From **Scope**, list **touched files**. For each, separate:

- **New / changed blocks** (implementation or plan-owned) — **ignore** for
  findings (except to avoid duplicating reviewing-pitchd-rails).
- **Surrounding blocks** — **analyze** these.

### 2. Load the compass (philosophy)

Read **`../rails-omakase-compass/SKILL.md`**. Apply its **decision tests** to
surrounding code only: omakase first, server-owned truth, HTML-first, REST
gravity, fat domain vs scripts, boundaries.

Prefix findings **`philosophy:`**.

### 3. Tactical skills and rules

Map **surrounding** code to **`writing-*`** skills and **`rules/*.mdc`** the same
way as `reviewing-pitchd-rails`, but **only** for pre-existing regions:

`writing-models`, `writing-routes`, `writing-controllers`, `writing-hotwire`,
`writing-views`, `writing-javascript`, `writing-css-tailwind`, `writing-i18n`,
`writing-mailers`, `writing-policies`, `writing-services`, `writing-jobs`,
`writing-migrations`, `writing-tests`,
`writing-plans` (if the touched artifact is a plan file).

Prefix findings **`tactical:`** and cite skill or rule.

### 4. DHH / 37signals lens

Align with **clarity over cleverness**, **convention over configuration** where
Rails already has an answer, **RESTful resources**, **thin controllers / rich
models**, **progressive enhancement**, and **no invented frameworks** — as
expressed in the compass and `writing-*` patterns, not as generic slogans.

### 5. Calibration

**Flag all plugin violations** in surrounding code — even when the surrounding
code predates the plugin or "has always been that way." An application pattern
is not an exemption from plugin rules.

**Assign a confidence score (0.0–1.0) to every finding:**
- **0.9–1.0:** You read the exact surrounding lines; rule is unambiguous.
- **0.7–0.9:** You read the code; some interpretive judgment involved.
- **0.5–0.7:** Inferred from plan or file structure (no diff to read directly).
- **Below 0.5:** Drop the finding or label explicitly as "uncertain — verify before acting."

Prefer **actionable** items: what to change and **where**.
- **Quick wins:** in-file, low blast radius, fits a follow-up commit in the same PR or a tiny chore PR.
- **Significant / separate:** refactors that change **behavior surface**, **many files**, **public APIs**, or need **migration / QA** — still **report** them; label clearly (see report format).

## Report format

Every finding carries a **confidence score** and a **Verified** note showing what you read to confirm it.

```markdown
## Touched surroundings review (pre-existing code)

**Phase covered:** plan | implementation | both

**Touched files:** …

**Boundary note:** how new vs surrounding was determined (diff, plan, or inference).

**Status:** Clear | Opportunities found

### philosophy: (rails-omakase-compass)
- [confidence: X.X] `[surrounding area]`: [Direct statement of the violation.]
  **Verified:** [What you opened and read to confirm this.]

### tactical: (writing-* / rules)
- [confidence: X.X] `[path]` (surrounding): [Direct statement.] — [reference]
  **Verified:** [What you opened and read to confirm this.]

### Application-pattern violations
Surrounding code that follows a current app pattern which violates plugin rules.
The pattern's existence does not excuse it.
- [confidence: X.X] `[path]`: [Direct statement.] — [rule reference]
  **Current pattern:** [What the app currently does.]
  **Plugin requires:** [What the rule or skill says.]
  **Verified:** [What you read to confirm both the pattern and the rule.]

### Quick wins (same PR or small chore)
- …

### Separate follow-ups (significant — handle outside this feature)
- **Why separate:** …
- **Suggestion:** …

**One-line summary:** …
```

## Subagent

**`pitchd-rails-surroundings-reviewer`** at
**`.cursor/agents/pitchd-rails-surroundings-reviewer.md`** runs this skill in an
isolated, readonly subagent. Pass **Phase**, plan path, spec path, and **Scope**
including diff or line attribution for new code.

## Related

- **Feature / plan review (new code):** `../reviewing-pitchd-rails/SKILL.md`
- **Compass:** `../rails-omakase-compass/SKILL.md`
