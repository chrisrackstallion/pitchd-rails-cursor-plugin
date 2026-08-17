# Primitives tree starters

Copy these when scaffolding `docs/primitives/` (normally via
`bootstrapping-primitives`) or creating a new capability doc.

## `SCHEMA.md` starter

```markdown
# Primitives — contract

This tree holds the four durable primitives: intent, compilation, evaluations,
provenance. Structure and ownership rules: the harness's
`agent_harness_rails/rules/primitives.mdc` (canonical — this file only records app-specific
deviations agreed between agent and human).

## Layout

    docs/primitives/
      SCHEMA.md          # This contract
      index.md           # One line per capability + status
      compilation.md     # App-wide constraints. Human-owned.
      capabilities/      # One doc per capability

## App-specific deviations

(None yet.)
```

## `index.md` starter

```markdown
# Capabilities

One line per capability. Status: shaping → planned → built → deprecated.

(None yet.)

## Deprecated

(None yet.)
```

## `compilation.md` skeleton

Human-owned. Every line must pass the filter: **not derivable from the code or
the harness, and it would change what an agent proposes.** Target under 50 lines.

```markdown
# Compilation — app-specific architecture

App-wide constraints agents read before planning. Human-owned: agents propose
amendments via review findings, never edit directly. Generic Rails shape lives
in the harness (compass + rules) — only what is true of THIS app
and not derivable from the code belongs here.

## Runtime & operations
- [Binding choices with teeth, e.g.: No Redis. Anything proposing
  Redis-backed state needs an amendment here first.]

## Boundaries & ownership
- [e.g.: `Post` is the aggregate root for reader-facing content; comments and
  reactions hang off it and are authorized through it.]

## Constraints with teeth
- [External commitments and red lines, e.g.: all reader-facing pages must
  render without JavaScript — sales commitment, not preference.]
```

## Capability doc skeleton

```markdown
---
status: shaping
specs: []
---
# [Capability name]

## Intent

- **I1** — [One sentence, outcome terms — what must be true for the user or
  system.]

## Shape

- [Deltas only: constraints specific to this capability, not derivable from
  harness rules, not stated in compilation.md. Link, don't repeat.]

## Evaluations

[Rows are written from specs that exist — at execution close-out, capture, or
a planner lazy backfill — never from what a plan promises. A `shaping` or
`planned` doc for new work has an empty table.]

| Clause | Proven at |
|--------|-----------|
| I1 | [spec/system/..._spec.rb — "example description"] |

## Provenance

- YYYY-MM-DD — [one line per event: shaped / planned / built / amended /
  revised / backfilled / confirmed / deprecated; link plan or PR; rejected
  alternatives; accepted debt.]
```

## Worked lifecycle lines (for reference)

```markdown
- 2026-08-04 — shaped via brainstorming session; reactions explicitly out of scope.
- 2026-08-05 — planned: docs/plans/2026-08-05-comment-threads.md. Rejected
  separate Thread model (threading is comment shape, not an addressable resource).
- 2026-08-07 — built; 4 tasks, approved after 2 review iterations. Accepted:
  depth cap is validation-only, no DB constraint.
- 2026-09-18 — planned: docs/plans/2026-09-18-deep-comment-threads.md.
  Rejected raising the cap (same cliff, deferred).
- 2026-09-19 — amended: I4 superseded by I5/I6 — depth cap removed;
  readability moved to view-layer disclosure. Moots the 2026-08-07
  depth-constraint note.
- 2026-10-02 — backfilled from existing behaviour; prior history in git.
  Intent reconstructed, unconfirmed.
- 2026-10-03 — backfill intent confirmed by human.
```

Supersession in place:

```markdown
- ~~**I4** — Threads never nest deeper than 3 levels.~~
  *Superseded by I5 + I6, 2026-09-18.*
- **I5** — A reader can reply at any depth.
```
