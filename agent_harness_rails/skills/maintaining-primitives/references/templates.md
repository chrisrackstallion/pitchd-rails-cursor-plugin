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

Intent and evaluations are frontmatter — one record per clause, so a clause list
and an evaluation table cannot disagree. Shape and provenance stay prose.

```markdown
---
status: shaping
intent:
  - id: I1
    clause: [One sentence, outcome terms — what must be true for the user or system.]
    evaluations: []
---
# [Capability name]

## Shape

- [Deltas only: constraints specific to this capability, not derivable from
  harness rules, not stated in compilation.md. Link, don't repeat.]

## Provenance

- YYYY-MM-DD — [one line per event: shaped / planned / built / amended /
  revised / backfilled / confirmed / deprecated; link plan or PR; rejected
  alternatives; accepted debt. Nothing a future reader would not act on —
  no review counts, agent names, or commands run.]
```

`evaluations:` is filled from specs that **exist** — at execution close-out,
capture, or a planner lazy backfill — never from what a plan promises. A
`shaping` or `planned` doc for new work leaves it empty.

## Tagging the proof

Each named spec file must carry the clause id as RSpec metadata, or `agent_harness_rails evals`
reports the evaluation as untagged — a path alone is a claim, the tag is proof:

```ruby
# spec/system/comment_threads_spec.rb
it "shows replies nested under their parent", intent: "comment_threads#I2" do
```

On the example, never on the group around it (`tag/misplaced`). One example may
carry several clauses as a list:

```ruby
it "nests three deep", intent: %w[comment_threads#I2 comment_threads#I3] do
```

The same tag runs the proof: `bundle exec rspec --tag 'intent:comment_threads#I2'`.

## Built doc, fully wired

```markdown
---
status: built
intent:
  - id: I1
    clause: A reader can reply to any comment.
    evaluations:
      - spec/system/comment_threads_spec.rb
  - id: I2
    clause: Replies show nested under their parent.
    evaluations:
      - spec/system/comment_threads_spec.rb
      - spec/requests/comments_spec.rb
  - id: I3
    clause: A reader sees who replied and when.
---
```

I3 has no `evaluations:` — shipped behaviour nothing proves yet. On a `built`
doc that is a **failing** run (`clause/unproven`), and deliberately so: there
is no key that annotates the gap into passing. Record the clause anyway, report
the red as blocking `writing-tests` work, and close it by writing the spec.

## Worked lifecycle lines (for reference)

```markdown
- 2026-08-04 — shaped via brainstorming session; reactions explicitly out of scope.
- 2026-08-05 — planned: docs/plans/2026-08-05-comment-threads.md. Rejected
  separate Thread model (threading is comment shape, not an addressable resource).
- 2026-08-07 — built: docs/plans/2026-08-05-comment-threads.md. Accepted:
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

Supersession in place — the old clause stays as a tombstone with its successors
and date recorded as data; only the new clause carries evaluations:

```yaml
intent:
  - id: I4
    clause: Threads never nest deeper than 3 levels.
    superseded_by: [ I5, I6 ]
    superseded_on: 2026-09-18
  - id: I5
    clause: A reader can reply at any depth.
    evaluations:
      - spec/system/comment_threads_spec.rb
```

The key is **`superseded_on:`**, not `on:` — YAML resolves a bare `on` to the
boolean `true`, so an `on:` key silently loses its date. A clause withdrawn with
no replacement uses `retired_on: YYYY-MM-DD` instead.

Retagging is part of the amendment: examples tagged `#I4` must move to `#I5`, or
`agent_harness_rails evals` reports them as pointing at a superseded clause.
