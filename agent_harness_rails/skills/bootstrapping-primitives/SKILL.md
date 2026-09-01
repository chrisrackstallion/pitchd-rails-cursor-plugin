---
name: bootstrapping-primitives
description: >-
  One-time adoption of the primitives tree in a Rails app: scaffold
  docs/primitives/ (SCHEMA.md, index.md, capabilities/) and draft the
  human-owned compilation.md via codebase survey plus structured interview.
  Use when a repo has no docs/primitives/ tree, or the user says set up
  primitives, adopt primitives, or generate compilation. Maintenance and
  backfill: maintaining-primitives.
---

# Bootstrapping primitives (one-time adoption)

<objective>
Stand up **`docs/primitives/`** in about one sitting: scaffold the tree, then
draft **`compilation.md`** — the app-specific compilation primitive — from a
read-only survey plus a human interview. The deliverable is a **strawman the
human edits**, not a finished document: `compilation.md` is human-owned from
its first commit. Everything else (capability docs) accrues per-feature
afterwards — this skill deliberately does **not** backfill the app.
</objective>

**Announce:** "I'm using the bootstrapping-primitives skill."

Structure rules: **`agent_harness_rails/rules/primitives.mdc`**. Skeletons:
**`agent_harness_rails/skills/maintaining-primitives/references/templates.md`**.

## Preconditions

- **`docs/primitives/` must not already exist.** If it does, this is
  maintenance — route to **`maintaining-primitives`** instead.
- A Rails app in the workspace (the survey reads its config).

## Process

### 1. Scaffold the tree

Create from the starters in `references/templates.md` of `maintaining-primitives`:

```
docs/primitives/
  SCHEMA.md          # contract starter
  index.md           # empty catalog — one line per capability, see templates.md
  capabilities/      # empty (add .keep if the repo tracks empty dirs)
```

`compilation.md` comes from steps 2–4, not the skeleton alone.

The first capability docs arrive later, from planning or a `capture` backfill
(format: `agent_harness_rails/rules/primitives.mdc`).

Mention `agent_harness_rails evals` to the user once, here: it ships with this gem and belongs
in CI beside RuboCop, so the tree cannot quietly rot. Say what it does and does
not settle (`agent_harness_rails/rules/primitives-cli.mdc` § Checked
mechanically) — the judgment it cannot make, whether a tagged spec would
actually go red, is a review responsibility from day one
(`agent_harness_rails/rules/intent-tags.mdc` § What counts as proving a clause).

### 2. Survey (read-only)

Read the code that reveals **binding choices**: `Gemfile`, `config/` (queue,
cache, storage adapters, `database.yml`), deploy config (Kamal / CI files),
authentication approach, engine or namespace boundaries, anything the repo's
CLAUDE.md / README declares as policy.

Output: a **candidate list** of detected choices. Detected is not the same as
binding — that distinction is the interview's job.

### 3. Interview (human)

The survey finds *what*; only the human knows *which choices are constraints*
and why. Use the harness's structured question tool when available; otherwise
ask in chat, grouped tightly. Two question shapes:

1. **Per candidate:** "Is this a decision future work must respect, or just how
   it happens to be today?" Keep only the former.
2. **What code can't reveal:** boundaries and their reasons, external
   commitments (contractual, compliance, sales — the "must render without
   JavaScript" type), operational red lines ("no new datastores"), and any
   deliberate deviation from harness defaults.

### 4. Draft `compilation.md`

Apply the filter to every line: **not derivable from the code or the harness,
and it would change what an agent proposes.** "We use Solid Queue" is derivable
— cut. "No Redis; anything proposing it needs an amendment here first" is a
constraint with teeth — keep. Target **under 50 lines**; if it runs longer, it
is describing the app rather than constraining it.

Use the skeleton's three headings (Runtime & operations / Boundaries &
ownership / Constraints with teeth); drop or add headings as the app demands —
the filter matters, the headings don't.

### 5. Hand to the human

> `compilation.md` drafted at `docs/primitives/compilation.md`. It's yours —
> please edit: cut anything you wouldn't enforce in review, add what I
> couldn't see. From here agents read it before every plan and propose
> amendments via review findings; they won't edit it.

Wait for the human's pass before treating bootstrap as done. Then offer —
**do not run unprompted** — a first backfill:

> Want to backfill capability docs for any features change is coming to soon?
> That's the `capture` operation in `maintaining-primitives`
> (via `rails-primitives-maintainer`), one capability at a time.

## What this skill does NOT do

- **No bulk backfill.** Capability docs accrue lazily (the planner creates one
  the first time planned work touches an undocumented area) or on demand via
  `capture`; a bulk documentation project produces half-accurate docs and dies.
- **No app code, no plans.**
- **No re-runs.** Once the tree exists, `compilation.md` changes only through
  human edits prompted by review findings; the tree changes through the
  standard workflow write points.

## Common mistakes

- **Describing instead of constraining** — `compilation.md` lines that restate
  the Gemfile. Apply the filter; when in doubt, cut.
- **Skipping the interview** — a survey-only draft encodes the agent's guesses
  about which choices are load-bearing; the interview makes the document
  human-specified.
- **Backfilling everything while you're at it** — resist; see above.

## Related

- **`maintaining-primitives`** — recurring operations (capture, trace, update, lint).
- **`agent_harness_rails/rules/primitives.mdc`** — structure, ownership, size limits.
- **`writing-rails-plans`** — first consumer: reads `compilation.md` and
  the target capability doc at its primitives gate.
