# Harness leanness — single-source every concept

**Status:** planned; deletion targets adversarially verified against the corpus 2026-09-01
**Goal:** cut agent context load roughly in half without losing a single normative
statement, worked example, or template. Every deletion in this plan removes the
Nth copy of something, never the only copy. Where verification found a "copy"
carrying site-specific content, that content is listed under **Must survive**
and the consolidation is a merge, not a delete.

## Measured baseline

The harness corpus is **~114,200 words** (~150k tokens) across 28 skills,
18 rules, and 4 agent files. A typical `rails-implementor` task touching a
controller, a view, and specs loads **35–45k words (~50–60k tokens) of
instructions before reading any app code**: the agent file, `implementing-rails-task`,
the compass, then for each layer a triple stack of `SKILL.md` +
`references/patterns.md` + `rules/<topic>.mdc`, plus the testing cluster.

Duplication measured per cluster:

| Cluster | Current | Duplication found | Target |
|---|---|---|---|
| Topic trios (controllers, models, views, jobs, policies, javascript measured; 8 more verified for merge safety) | 27,800w (six) | 45–60% per trio — same skeletons, anti-pattern tables, and rules restated across all three files | ~17,500w (six) |
| Testing (testing.mdc + writing-tests + 5 references + 2 refactoring skills) | 30,900w | ~60% of testing.mdc restated in SKILL.md and vice versa; Five Gates in 3 places; falsifiability examples duplicated byte-identical | ~21,500w |
| Primitives (primitives.mdc + 3 skills + agent + embedded gates) | 12,450w | CLI semantics, clause theory, and guard-notice taxonomy each stated 3–5× — the taxonomy copies live in the reviewer/maintainer agent files and reviewing-rails-work, not in the embedded gates | ~8,500w |
| Orchestration (plans, executing, reviewing, implementing, brainstorming + 4 agents) | 24,700w | Repeated premises and near-duplicate tables, but most copies carry role-specific consequences — consolidation is parameterized, not wholesale | ~18,000w |
| RuboCop pair (rubocop.mdc + running-rubocop) | 1,641w | Zero-offences bar, no-suppression rules, and the human-owned carve-out stated twice | ~1,200w |
| Skill frontmatter descriptions | 1,985w, loaded into **every** session | writing-rails-plans alone is 148 words | ~1,000w |

Duplication is already causing drift, not just cost: `controllers.mdc` calls
`verify_policy_scoped` required while `policies.mdc` hedges "unless you
customize" — the `authorize`/`policy_scope`/`verify_*` guidance lives in five
places across two topics. `brainstorming-rails-omakase` calls the supplementary
references "required" while every other carrier says "optional".

**Corpus target: ~68–74k words (−35–40%). Per-task load target: ~18–22k words,
because a task loads one canonical file per concept, with worked examples on
demand.**

## Design: three roles per topic, one home per concept

Delivery constraints force three files per topic to keep existing: `SKILL.md`
frontmatter drives Claude Code triggering, `.mdc` `globs:` drives Cursor
auto-attach, `references/` loads on demand. The fix is not fewer files but
**non-overlapping roles**:

| File | Role | Contains | Never contains |
|---|---|---|---|
| `rules/<topic>.mdc` | **Normative canon** | Rules, anti-pattern table (one copy, two-way merged), boundaries/ownership, naming table, decision frameworks, verification checklist | Worked examples beyond one minimal skeleton |
| `skills/writing-<topic>/SKILL.md` | **Trigger + router** (~150–250w) | Frontmatter, one-paragraph objective, task-routing table, pointers | Any rule statement — pointers only |
| `references/patterns.md` | **Worked mechanics** | Code examples, gotchas, API shapes | Restated rules or boundary tables |

All harness paths stay written in canonical `agent_harness_rails/...` form —
`bin/check-references` hard-fails non-canonical prose references (`canonical?`
requires the prefix), and the prefix is what makes one path form correct in
both this repo and consuming apps (see 2026-08-17 plan, D2).

## Phase 1 — shared contract (small, parameterized)

Create `agent_harness_rails/rules/harness-contract.mdc` (~350w) holding only
what verification confirmed is genuinely shared:

- **Conflict rule** (tactics win HOW, compass wins whether, documented
  exceptions) — one statement; each site keeps its one-line role verb
  ("implement consistently with" / "review tactics for consistency with").
- **"Harness rules beat application patterns" premise** — one sentence plus the
  service-object example. **Must survive at each site:** the role-specific
  consequence (implementor → escalate NEEDS_CONTEXT; reviewer → file under
  Application-pattern violations; query → acknowledge and route around;
  brainstorm → spec the correct direction, note friction; planner → mark as
  technical debt).
- **"No parent context" subagent sentence** — the only genuinely shared
  subagent constraint. Required-inputs tables stay per-agent (implementor and
  reviewer tables share only two rows).
- **Supplementary-reference policy** — one statement with an
  optional/required flag per site. **Must survive:** brainstorming's "required
  consult for gaps" stance; the compass's failed-fetch fallback ("may still
  give general Rails guidance without claiming a source"); rails-query's
  "repeat the unofficial-guide caveat" rule.

**Do not consolidate** (verified as not copies):

- Escalation statuses — defined once in `implementing-rails-task` already;
  other sites are handlers with unique content (executing's "revert the R1
  clause amendments"). Keep the DONE_WITH_CONCERNS RuboCop carve-out.
- RuboCop gate — the four `implementing-rails-task` mentions are four process
  points (fix loop, BLOCKED contents, self-review item, report field), not
  copies. Site-specific rules stay: "cop already off in app `.rubocop.yml` is a
  human decision", reviewer's "no `.rubocop_todo.yml`", executing's "no
  full-suite run at every task stop".
- Delegation tables — the three `writing-rails-plans` tables can collapse to
  one **only** with an explicit per-pass semantics note, because the
  User-revisions cell inverts meaning between Pass 1 (scope: review only
  these) and Pass 2 initial (context: read the full plan). The
  Mechanical-output cell differs by phase (2 commands vs 3, and executing's
  paste-verbatim warning — "a truncated block reads as a clean run" — must
  survive). `rails-implementor.md`'s template and `rails-reviewer.md`'s list
  are different artifacts (sender template vs receiver validation) — leave.
- Revision mode — share only the trigger-phrase list and R1's three bullets;
  the two skills diverge at every other step (plans edits the file itself,
  executing delegates; executing R1's bug-vs-intent classification is unique).

Realistic saving: ~1,000–1,500w.

## Phase 2 — topic trios

Apply the three-role model to every `writing-*` topic. Per the measured six
plus the verified eight, with these merge obligations:

- Move each SKILL.md's routing table, naming table, and verification checklist
  into the `.mdc`; shrink SKILL.md to trigger + router.
- Strip rule restatements and boundary tables from `patterns.md`; keep
  mechanics and gotchas.
- Keep exactly one skeleton per topic (e.g. `ArticlesController` and
  `NotifySubscribersJob` currently appear verbatim in all three files).
- Single-source `authorize`/`policy_scope`/`verify_*` in `policies.mdc`;
  controllers files point to it; resolve the required-vs-hedged drift.

**Must survive (verified unique, currently only in a SKILL.md):**

- *migrations*: the 7-row operation/safety matrix; the
  `ChangeArticleStatusToEnum` up/down example with its "silently resets to
  draft" gotcha; "declare `disable_ddl_transaction!` yourself — Rails does not".
- *services*: the decision tree's standalone-PORO branch with the noun naming
  test ("fails: `ReportGenerator`, `PaymentProcessor`"); "struggling to name it
  → belongs on the model"; form-object-vs-PORO discriminator (user input vs
  model instances).
- *naming*: no patterns.md exists — merge SKILL uniques into `naming.mdc`: the
  tie-break rule (Rails convention wins for class/file names, domain language
  for methods/variables), the add/never-add suffix lists and casing line, the
  bang-method rationale.
- *views*: the canonical `show.html.erb` skeleton; the "static copy is
  hardcoded in examples; real code uses `t()`" reading note; anti-pattern rows
  absent from the other two files (render nesting ≤2, `content_for` control
  flow, fat helpers, the `.truncate`/`.humanize` inline carve-out).
- *javascript*: the escalation "existing fleet without specs → run
  `refactoring-stimulus-controllers`"; verify the outlets-when-structural
  discriminator has a home before deleting.
- *hotwire*: the "When to Use This Skill" scope/Defer table (a fourth artifact
  type — absorb into the .mdc).
- *routes*: SKILL verification (7 items) and `routes.mdc` PR checklist
  (5 items) must be **reconciled into one**, not concatenated.

Also: merge `running-rubocop` and `rubocop.mdc`'s duplicated bar (zero
offences, no suppressions, human-owned carve-out) into the .mdc; the skill
keeps its unique procedure — baseline-file reading table, "fix the finding,
not the message" with the three-cop dodge table, the worked BLOCKED message.
`comments.mdc` is unique — untouched.

## Phase 3 — testing cluster

- `rules/testing.mdc` becomes the canon (~3,400w). The anti-pattern table is a
  **two-way merge**: SKILL.md has ~5 rows testing.mdc lacks (exact error
  messages, giant setup blocks, `is_expected.to`, job-spec-re-testing-model,
  evidence-the-wrong-outcome-shows as a row); testing.mdc has one SKILL lacks
  (status comparison `be < 403`). Merge SKILL's ASCII-diagram-only ownership
  rows (rate limits, scoped collections, multi-request integration) into the
  ownership table.
- Intent tagging (~1,100w) moves to one home — a section of `primitives.mdc`
  or its own rule — cited by testing.mdc, plans, executing, and reviewing.
- `writing-tests/SKILL.md` → router + process (~1,200w): decision tree,
  Arrange-Act-Assert, reference table, verification checklist. Gates text,
  pyramid, and falsifiability prose become pointers (verified safe —
  testing.mdc's versions are supersets).
- References: **merge, then strip** the Boundaries sections (four files have
  them; factory-patterns has none; support-specs has two). Rows to merge into
  the ownership table first: request-specs' CSRF/security-headers, Turbo
  content type, 429 rate-limit, per-field round-tripping rows and its
  "show/edit/update/destroy: request spec is the only spec — happy path +
  auth gate, not the validation matrix" rule; system-specs' helper-output row;
  model-specs' `Current`/`travel_to`/counter-cache rows; support-specs'
  policy-vs-request split rows (button-hidden → system; scope-filters →
  policy spec).
- **Keep `support-specs.md` intact** (minus merged boundaries). There are no
  per-layer homes for its policy/job/mailer/concern/PORO/form/API-client/
  channel/RSpec-config content, and eight files cite it (testing.mdc ×2,
  writing-policies, writing-jobs ×2, writing-mailers ×2,
  refactoring-rails-specs). Splitting it is a separate decision with its own
  citation-update task — not part of this plan.
- `refactoring-rails-specs`: keep the audit tables — their diagnostic column
  ("Move it if…") and default-verdict column (MOVE/REWRITE/DELETE per
  anti-pattern) are unique decision content testing.mdc cannot supply, and
  three rows have no testing.mdc counterpart. Strip only the restated
  ownership-rationale prose; keep pre-flight, discovery map, verdict taxonomy,
  sequencing, intent audit, report template.
- `refactoring-stimulus-controllers`: ~85% unique; only cut §6's re-listed
  gates to a pointer.

## Phase 4 — primitives cluster

Corrected baseline: the embedded gate sections are **945w**
(writing-rails-plans §Primitives gate + final-approval sync) and **834w**
(executing-rails-plan §8) — realistic combined saving ~600w, not ~2,100.

- `rules/primitives.mdc` stays the sole normative home (~2,600w); split the
  CLI reference (`evals`/`guard`/`proofs`, notice taxonomy, silent-CLI
  protocol) into `rules/primitives-cli.mdc` (~900w).
- The duplicate guard-notice taxonomy lives in **`rails-reviewer.md`,
  `rails-primitives-maintainer.md`, and `reviewing-rails-work`** — those become
  pointers to the CLI rule. The embedded gates already cite it.
- Trim the embedded gates only where they restate the rule. **Must survive
  in place (workflow-specific, no other home):**
  - the planner's Intent-impact row spec — "the task list names the denial or
    boundary case at the layer that owns it, and the Intent-impact row names
    those cases one by one" (this *is* the row spec; it lives inside the
    paragraph previously slated for deletion);
  - executing's "regression contract" rule (an `unchanged` clause whose
    evaluation's assertions were edited = mislabelled amendment);
  - executing's two-step proofs drill and its loop-back rule ("a case the row
    named and the listing does not show goes back through implement → review,
    not into `evaluations:`");
  - all **four** classification branches (including the refactor branch, which
    primitives.mdc does not state);
  - executing §8's handling regroup (proof-got-smaller / intent-moved /
    expected / unreadable → executor actions).
- `maintaining-primitives/SKILL.md` → operations only (~1,100w); its ~700–800w
  of rule restatement (tripwires ×3, provenance noise ×3, naming, umbrella
  clauses) become pointers. `references/templates.md` → skeletons + worked
  lifecycle lines (~600w).

## Phase 5 — orchestration skills

- **Single-source the routing tables in the compass, not by deletion:** extend
  the compass's tactical index with the **Rules column** and the
  primitives/planning rows that `writing-rails-plans` ("Harness conventions to
  apply"), `rails-query.md`, and `brainstorming-rails-omakase` each carry
  today. Each of those three then keeps only its framing plus a pointer.
  **Must survive:** the plans table's gate semantics ("this table is a gate,
  not a suggestion — a plan specifying code for an area whose conventions were
  never loaded is not ready for review"); rails-query's scoping notes on the
  primitives and planning rows.
- `writing-rails-plans` 6,337w → ~4,000w: Philosophy section becomes pointers
  (verified safe; keep "vertical slices over layers" in §Task order);
  "Anti-patterns to reject" keeps its **two plan-shaped rows** (vertical slice
  split that never passes CI between tasks; same method defined on multiple
  entities across tasks — entity-by-entity drafting hides the drift) and the
  "regardless of what the app already does" framing, drops only rule-cited
  rows; the three delegation tables collapse per Phase 1's semantics note;
  "Executing the plan" becomes a pointer.
- `executing-rails-plan` 4,057w → ~2,900w: same treatment; revision-mode
  sharing per Phase 1 (trigger list + R1 bullets only).
- `reviewing-rails-work` and `implementing-rails-task` keep their canonical
  report formats; their conflict-rule and premise restatements become contract
  pointers with the role verb kept.
- The compass grows slightly (Rules column + 2 rows) and stays the model.

## Phase 6 — agents and frontmatter

- Agent files slim toward dispatch contracts, with two verified exceptions:
  - `rails-implementor.md` **keeps its prompt template** —
    `executing-rails-plan` instructs parents to use it as the dispatch shape.
    Dedupe the template's skill restatements, but first move its unique
    sentence into `implementing-rails-task`: "if the task's spec list does not
    cover a cited clause's full wording, say so in your report instead of
    tagging past it" (exists nowhere else). Target ~500w, not ~300w.
  - `rails-reviewer.md` keeps its readonly CLI constraint (~200w, incl.
    `UNVERIFIED (CLI unavailable)` and "a reviewer that edits the tree
    launders the notice") — that is receiver-side and unique.
  - `rails-query.md` and `rails-primitives-maintainer.md` → dispatch contract +
    pointers (guard-triage and grounding-order restatements go).
- Frontmatter descriptions: trim workflow summaries, **keep trigger
  vocabulary** — descriptions drive skill selection, so phrases like "the
  system specs are too heavy" stay. Cap ~40 words where possible, up to ~60
  where trigger phrasing demands. ~1,985w → ~1,000w.
- Paths stay canonical (see Design) — the earlier idea of dropping the
  `agent_harness_rails/` prefix in prose is rejected: `bin/check-references`
  exits 1 on non-canonical references, by design.

## Information-preservation protocol

1. **Inventory before deletion.** Per cluster, list every normative statement,
   table, template, and worked example with its surviving home. A deletion is
   legal only when the inventory shows another copy surviving. The **Must
   survive** lists above are pre-verified entries in that inventory — treat
   them as blocking.
2. **One cluster per branch/PR**, in phase order (contract first — later
   phases point at it).
3. **After each cluster:** `bin/check-references` (all references resolve,
   canonical form), gem specs, RuboCop, and a manifest check
   (`lib/agent_harness_rails/manifest.rb`) for any file added/removed.
4. **Closing verify pass:** an agent diffs old corpus vs new per cluster and
   reports any statement with no surviving home; fix before merge.
5. **Load-stack acceptance test:** for three sampled tasks (controller+view+
   spec, migration+model, Stimulus refactor), enumerate the files the lean
   harness instructs an implementor to read and confirm (a) every rule the fat
   stack carried is reachable, (b) total words loaded ≤ 22k.

## Expected outcome

| Metric | Before | After |
|---|---|---|
| Corpus | ~114k words | ~68–74k words |
| Implementor load per task | 35–45k words (~50–60k tokens) | ~18–22k words (~24–29k tokens) |
| Always-loaded descriptions | ~2,000 words | ~1,000 words |
| Copies of any given rule | 2–7 | 1 (plus role-specific consequences at their sites) |
