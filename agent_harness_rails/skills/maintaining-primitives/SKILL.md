---
name: maintaining-primitives
description: >-
  Maintain the durable primitives tree under docs/primitives/ — capability docs
  holding intent clauses, shape constraints, evaluation maps, and append-only
  provenance, plus the human-owned compilation.md. Operations: capture (backfill
  a capability doc from existing code and specs), trace (answer "why is X like
  this" with citations), update (sync status, evaluations, provenance), lint
  (size limits, clause/eval coverage, orphans). Use when backfilling historical
  features, answering provenance questions, or running a health pass — not for
  writing app code or plans. For one-time adoption setup use
  bootstrapping-primitives; for delegation use rails-primitives-maintainer.
---

# Maintaining primitives (durable intent, evaluations, provenance)

<objective>
Keep a small, fixed-shape markdown tree — **`docs/primitives/`** — that holds
what generated code cannot carry: **intent** (what must be true and why),
**compilation** (app-specific constraints), **evaluations** (where each intent
clause is proven in RSpec), and **provenance** (decisions, rejected
alternatives, accepted debt). Plain **git + markdown**, one file per
capability, a reading contract of at most three files.
</objective>

**Announce:** "I'm using the maintaining-primitives skill."

Structure and boundaries: **`agent_harness_rails/rules/primitives.mdc`** (applies automatically to
paths under `docs/primitives/`). Skeletons: **`references/templates.md`**.
One-time adoption (tree scaffold + `compilation.md` interview):
**`agent_harness_rails/skills/bootstrapping-primitives/SKILL.md`**.

## When to use

- **Backfilling** a capability doc for an existing feature (`capture`).
- Answering **"why is X like this?"** with citations (`trace`).
- **Syncing** a doc after work landed outside the standard workflows (`update`).
- A **health pass** over the tree (`lint`).

**When not to use:** Writing plans (`writing-rails-plans` owns Intent
and Shape authorship during planning), executing plans
(`executing-rails-plan` owns the close-out pass), or app implementation.
Those workflows write to the tree at their own defined points — this skill
covers everything outside them.

## The tree

```
docs/primitives/
  SCHEMA.md          # Co-owned contract
  index.md           # One line per capability + status — the only entry point
  compilation.md     # App-wide constraints. Human-owned — propose, never edit.
  capabilities/      # One per capability: intent + evaluations in frontmatter, Shape / Provenance
```

**Reading contract:** `index.md` + the one target capability doc +
`compilation.md`. Never more — with **one exception: `lint`**, which sweeps
every doc by design. Cross-links are for humans — no operation requires
traversing them.

## Operations

| Op | Intent |
|----|--------|
| **capture** | Backfill a capability doc from existing code and specs (below). |
| **trace** | Read `index.md` → the capability doc → answer with citations to clause IDs, provenance lines, and spec paths. If the answer predates the doc, say so — provenance before the backfill line lives in git. |
| **update** | Sync one doc: status (including human-directed deprecation — `status: deprecated`, a provenance line saying why, and the index line moved to the Deprecated stub section), `evaluations:` against real spec homes and their `intent:` tags, one provenance line per event. Update `index.md` in the same change. Close with **`agent_harness_rails guard`** and read your own diff back (below). |
| **lint** | Run **`agent_harness_rails evals`** first, then the judgment checks below across the tree (the one whole-tree operation — exempt from the three-file contract); report findings, fix mechanical ones, leave judgment calls to the human. |

**Structural reshaping** — splitting an oversized capability, merging, or
renaming — is a human-approved **`update`**: redistribute the Intent clauses
to the new docs (tombstone pointers from the old doc, IDs never reused), carry
provenance forward by link rather than rewriting history, and sync `index.md`
in the same change. Lint only *reports* the split tripwire; the human decides;
an `update` pass executes.

### capture — backfilling a historical feature

Existing features get docs **lazily** (the first time planned work touches
them, the planner creates one) or **on demand** via this operation. Never as a
bulk documentation project — batch requests run one capability at a time with
human confirmation between, ordered by where change is coming.

1. **Scope** — a feature name or path list from the human. Check `index.md`:
   if a doc already covers the outcome, this is an `update`, not a capture.
2. **Specs first** — read the feature's spec files. In a suite following
   `writing-tests`, behaviour-first system and request spec descriptions
   *are* draft intent clauses, and each maps to its `evaluations:` for free.
   Add the `intent:` tag to the examples as you go — a clause naming a spec
   that does not carry the tag is a finding, not a capture.

   **Do not aggregate to fit the clause ceiling.** Compressing several
   behaviours into one umbrella sentence — *"a member can manage their
   comments"* — produces exactly the clause no example proves
   (`agent_harness_rails/rules/primitives.mdc` § Intent clauses). If the honest
   clause list runs past ten, the finding is that the **capability** should
   split, not that the sentences should widen.

   **Do not promote an adjacent spec into a proof.** The example you tag has to
   go red if the clause stops being true
   (`agent_harness_rails/rules/intent-tags.mdc` § What counts as proving a clause).
   Backfilled clauses are written from what the code does, so their wording
   arrives *wider* than any single existing example — tagging the nearest happy
   path hides the gap. Where the clause claims *only*, *never*, or *any* and
   only one case is covered, either narrow the clause to what the suite
   actually proves, or keep the wide clause and report the uncovered half as a
   gap under step 4. Both are honest; tagging past it is not.
3. **Code second** — models, routes, policies for the Shape bullets (deltas
   only — nothing derivable from harness rules or stated in `compilation.md`).
4. **Gaps are findings, and they stay red** — observable behaviour with no
   spec home still gets its clause, with no `evaluations:`. There is no marker
   that excuses it: `agent_harness_rails evals` will fail on that clause until
   a spec proves it. Say so when you report — list the uncovered clauses as
   blocking `writing-tests` follow-up, and do not soften the clause or drop it
   to keep the run green.
5. **Provenance opens with one line:**
   `YYYY-MM-DD — backfilled from existing behaviour; prior history in git.`
   Do not mine git log for decision archaeology — noisy, low-yield.
6. **Human confirms the clauses.** Reconstructed intent is marked
   `intent reconstructed, unconfirmed` in the provenance line until the human
   has read and corrected the clauses (~10 sentences; minutes). End the capture
   by asking for that confirmation; once given, **append** a confirmation
   entry — `YYYY-MM-DD — backfill intent confirmed by human.` Provenance is
   append-only: never amend the original line.
7. Add the `index.md` line, `status: built` — the feature exists in
   production, and a clause with no spec is a red run rather than a reason to
   understate the status (`agent_harness_rails/rules/primitives.mdc`).

### Close every writing pass by reading your own diff back

Any operation that **wrote** to the tree — `update`, `capture`, a structural
reshape — ends with:

```bash
agent_harness_rails guard --base <the commit the pass started from>
```

It is notice-only and never fails, and it is the one check aimed at the pass
itself rather than at the tree: what did this change do to promises that already
existed. A maintainer holds the widest write access of any agent here, so it is
also the agent whose edits most need reading back.

- **Expected, and worth reporting**: `intent/deactivated` for a human-directed
  deprecation, `proof/changed` after a spec home moved, `evaluation/relayered`
  where the human approved the new layer.
- **Fix before reporting**: `evaluation/dropped` or `proof/removed` on a clause
  that is still active — a sync pass that removes proof from a live promise has
  gone past syncing.
- **Stop and hand to the human**: `intent/rewritten`, `intent/vanished`,
  `provenance/rewritten`. Clauses are human-co-owned and provenance is
  append-only; a maintainer that rewrote either has edited the record rather
  than maintained it. Report the notice verbatim, restore what you overwrote,
  and let the human decide. Never discharge one of these by writing the
  provenance entry that silences it — the entry states a decision, and the
  decision is not yours.

### lint — run the tool, then judge

**Step 1 — `agent_harness_rails evals`.** It settles everything mechanical
(`agent_harness_rails/rules/primitives.mdc` § Checked mechanically).

```bash
agent_harness_rails evals                    # exits 1 on findings
agent_harness_rails evals --format json      # when you want to summarise a large tree
```

Report its findings as-is — they have file:line and a code, so do not restate
them in prose. Fix the unambiguous ones (a stale path, a missing tag). Leave
anything that changes what a clause *means* to the human.

One of its findings is not a failure and must not be "fixed" into silence:
`clause/in-flight`, a doc whose amendment plan has landed ahead of its code.
Everything else is an error and means what it says — in particular
`clause/unproven`, which is closed by writing the spec, never by editing the
clause out of the doc.

**Step 2 — the judgment checks the tool cannot make:**

- **Umbrella clauses** — a clause built on *manage*, *handle*, *support*, or an
  `and` joining two different actions is several promises in one sentence
  (`agent_harness_rails/rules/primitives.mdc` § Intent clauses). Mechanical
  hint: a clause needing four evaluations is usually a clause needing
  splitting. Report it as a proposed split with the per-action sentences written
  out — the ids are a human call, since splitting a clause changes what the
  system is recorded as promising.
- **Rows that do not prove their clause** — for each `built` clause, read its
  wording against its tagged examples and ask whether breaking the clause would
  turn one of them red
  (`agent_harness_rails/rules/intent-tags.mdc` § What counts as proving a clause).
  Quantifiers are where the rot collects: a clause saying *only* or *never*
  whose evaluations are one happy path is a finding, however green the run.
  Report it as an unproven clause with the missing case named; narrowing the
  clause instead is a human call, since it changes what the system promises.
  Check the reverse too — an evaluation that could be deleted with the clause
  still fully proven is a padded row.
- Every capability doc listed in `index.md`, and vice versa; statuses agree.
- **`index.md` lines that do not discriminate** — the tool checks a line exists,
  not that it earns its place, and this file is the tree's whole discovery surface
  (`agent_harness_rails/rules/primitives.mdc` § Finding the right capability).
  Read the list as a stranger deciding which doc to open: two lines that could
  describe each other's capability are a finding, as is a missing `Owns:` on a
  capability whose filename is not a resource name.
- **Names that fight the flat namespace** — a capability that split, or one that
  never owned a resource, should read `<domain>_<behaviour>` so the prefix groups
  it (§ Style). Propose renames sparingly and say the cost out loud: the filename
  is what `intent:` tags name, so a rename retags every proving example.
- An in-flight doc that is actually **abandoned** — `agent_harness_rails evals` reports the
  rowless clauses, but only a reader can tell a live amendment from a draft
  nobody returned to. Check whether any plan under `docs/plans/` still
  references the capability, and how old the edits are. Unwinding one is a
  human call.
- Size tripwires from `agent_harness_rails/rules/primitives.mdc`: >~10 active clauses (split the
  capability), >~3 evaluations on one clause (two promises sharing an id, or a
  padded row), multi-line provenance entries, doc >~150 lines,
  `compilation.md` >~50 lines.
- **Prose padding inside the limits** — a Shape bullet carrying hedging,
  meta-commentary, or a rationale paragraph (rationale is a one-line provenance
  entry). The constraint stays; the rhetoric goes
  (`agent_harness_rails/rules/primitives.mdc` § Style).
- No content that belongs elsewhere: app code, plan tasks, restated harness rules.
- **Process noise** — provenance lines carrying review or task counts, agent or
  skill names, commands run, or progress narration
  (`agent_harness_rails/rules/primitives.mdc` § Provenance). Report as a
  finding; provenance is append-only, so the fix is a human call, not a rewrite.
- Stray files outside the four allowed types.

## Quick reference

| Do | Avoid |
|----|-------|
| Append provenance; correct with a new entry | Editing or deleting provenance lines |
| Tombstone superseded clauses | Renumbering or reusing clause IDs |
| Propose `compilation.md` amendments to the human | Editing `compilation.md` directly |
| Read 3 files max (`lint` excepted) | Traversing links, loading the whole tree outside `lint` |
| One line per provenance event | A paragraph per event (lint finding) |
| Lines a future reader would act on: decisions, rejected alternatives, debt | Run mechanics: review counts, task counts, agent names, commands, progress narration |

## Common mistakes

- **Wiki thinking** — adding topic/synthesis pages "while you're in there."
  The four file types are the whole tree; scope is the anti-sprawl mechanism.
- **Per-edit provenance** — five plan revisions are one `planned` event, not
  five lines.
- **Process noise as provenance** — "approved after 3 review iterations",
  "implemented by rails-implementor", "suite green". The event, its reasoning,
  and what was rejected are the payload.
- **Capture without confirmation** — reconstructed intent shipped as fact.
  Unconfirmed clauses mislead every future planner; always close the loop.
- **`evaluations:` written from intention** — entries come from specs that
  exist and carry the tag (at close-out, capture, or a planner lazy backfill),
  never from what a plan promises.

## Delegation

Focused capture/trace/update/lint without Rails app work:
**`rails-primitives-maintainer`** (`agent_harness_rails/agents/rails-primitives-maintainer.md`)
with operation + paths/goals; this skill stays canonical.

## Related

- **`agent_harness_rails/rules/primitives.mdc`** — structure, ownership, size limits.
- **`bootstrapping-primitives`** — one-time tree scaffold + `compilation.md`.
- **`writing-rails-plans`** — creates/amends Intent and Shape at planning.
- **`executing-rails-plan`** — close-out pass writes `evaluations:`, status, provenance.
- **`reviewing-rails-work`** — `primitives:` findings check traceability and eval coverage.
