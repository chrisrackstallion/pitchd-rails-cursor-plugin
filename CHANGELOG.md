# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Two executable backstops for rules that were previously prose only: a linter for
the primitives tree, and a RuboCop layer for the rules a parser can settle.

### Added

- **`agent_harness_rails evals`** — a subcommand that checks every intent clause
  in `docs/primitives/` is proven by a spec, and that every `intent:` tag in the
  suite names a clause that still exists and sits on the example that proves it.
  Static parse: no database, no Rails environment, runs in any CI job. Scope is
  deliberately clause ↔ evaluation and nothing else, so a green run has one
  meaning; tree health stays with the `maintaining-primitives` skill, where it
  needs judgment.

  Coverage is total. An active clause on a `built` doc names a spec or the run
  fails — there is no key that annotates the gap into passing, because the one
  that existed got reached for exactly when it should not have been. The single
  non-failing state is `clause/in-flight`: a doc whose amendment plan landed
  ahead of its code, which close-out clears.

  Tags go on the example, never on the `describe` or `context` around it
  (`tag/misplaced`). A group tag reads as the tidier option and is the one form
  that can go on lying: delete the example it stood for and the siblings keep
  the group green, so `rspec --tag` still passes while the clause claims a proof
  that no longer exists.
- **`rubocop-harness.yml`** — an opt-in RuboCop layer enabling the existing
  `Rails/*`, `Naming/*`, `Lint/*` and `Security/*` cops that encode rules already
  written down here, with `Layout/ClassStructure` and `Rails/ActionOrder`
  configured to the model and controller ordering the rules document.
- **Fifteen `AgentHarnessRails/*` cops** for rules no existing cop covers:
  `ServiceObject`, `GenericOperationMethod`, `NonRestfulAction`, `CsrfSkip`,
  `EnqueueOutsideCommit`, `MailerDeliverNow`, `PolicyVerbMethod`,
  `PolicyContext`, `DeepNestedResources`, `MigrationDataChange`, `SpecSleep`,
  `StubbedSubject`, `ViewSpec`, `NegativeOnlySpec`, `IntentTag`. Each names the
  `.mdc` rule it enforces.
- **`rubocop-harness-rspec.yml`** — the spec half, covering most of
  `testing.mdc` via `rubocop-rspec`, `-rspec_rails`, `-capybara` and
  `-factory_bot`. Separate because those are gems your app supplies.

### Changed

- **Breaking — capability doc format.** Intent clauses and evaluations move from
  the `## Intent` and `## Evaluations` prose sections into YAML frontmatter, so
  they can be checked rather than read. `specs:` frontmatter is retired —
  `agent_harness_rails evals` derives it. Supersession becomes data (`superseded_by:`,
  `superseded_on:`) instead of strike-through prose. A doc still in the old
  shape is reported as `doc/legacy-format` rather than parsing as zero clauses
  and silently passing.
- Specs that prove an intent clause now carry `intent: "<capability>#I<n>"` RSpec
  metadata, which doubles as a selector:
  `rspec --tag 'intent:comment_threads#I2'`.
- **`testing.mdc` § What counts as proving a clause** — the judgment half of the
  tag, since the tool can only check that the link is well-formed. An evaluation
  proves a clause when *breaking the clause turns it red*; the three ways a tag
  fails that test are asserting the affordance instead of the outcome, proving one
  case where the clause claims a quantifier (*only*, *never*, *any*, *every*), and
  proving it at a layer that cannot hold the denial. One clause proven across
  several files at several layers is normal, not duplication — the ownership table
  already makes it mandatory for anything with an authorization side, since policy
  logic and its HTTP gate have separate homes by rule. The brake is **necessity**:
  the red test asks whether the evaluations are *enough*, so the inverse asks
  whether each is pulling its weight, and an evaluation you could delete with the
  clause still fully proven is padding. `primitives.mdc` gains the matching
  doc-side rules — clauses must be written falsifiable, a row must be earned
  rather than filled — and a new size tripwire at **~3 evaluations per clause**,
  past which the clause is usually two promises wearing one id.
- **`primitives.mdc` gains a clause-granularity rule: one behaviour per clause.**
  An umbrella verb (*manage*, *handle*, *support*) or an `and` joining two
  different actions is several promises in one sentence, and it is the upstream
  cause of unprovable rows: a broad clause has no spec home but a wide system
  spec, against the budget and the Five Gates. Bounded on both sides — scope words
  (*only*, *never*) sharpen a clause rather than splitting it, and clauses split
  so fine they differ only by which layer proves them are the suite transcribed
  into the tree. Enforced where clauses are written rather than where they are
  read: `brainstorming-rails-omakase` seeds one behaviour each,
  `writing-rails-plans` splits umbrella gate answers as it transcribes them,
  `capture` may not aggregate behaviours to fit the ~10-clause ceiling (the
  finding is that the capability should split), and `reviewing-rails-work` plus
  `maintaining-primitives`' `lint` report umbrella clauses with the per-action
  sentences written out.
- **An explicit admissibility test for clauses, and an intent-impact statement in
  brainstorms and plans.** `primitives.mdc` § Intent clauses now states the
  boundary directly: a clause is acceptable only if it is **observable**,
  **falsifiable**, **one behaviour**, and **durable** — still worth stating after
  the implementation is rewritten. The durable test is the one to run first, since
  it disposes of architecture, technology choices, refactors, and task lists in a
  single move, and a table names each of those with the home it actually belongs in
  (`## Shape`, `compilation.md`, the plan's task list, or nothing at all).
  Architecture and refactors are Compilation, never Intent.

  Plans now carry a required **Intent impact** table in the header — every touched
  clause, its change (`new` / `amended` / `superseded by I<n>` / `unchanged —
  regression contract`), and the layer its proof will land at — so what a plan
  promises is reviewable before any code exists. The `Proof lands at` column is a
  plan and stays in the plan file; `evaluations:` are still filled at close-out
  from what was actually reported. Brainstorm specs gain a matching `## Intent`
  block separating new clauses from impacted ones, with the proving layer named
  coarsely: if the only honest answer is "a journey spec", the clause wants
  splitting before a plan is built around it.

  This makes **Shape-only work expressible**, which it previously was not — the
  planner's primitives gate had three branches (serves / supersedes / adds) and a
  refactor fits none, so it pressured an agent into inventing a clause. A fourth
  branch leaves `intent:` and `status:` untouched, turns the active clauses into the
  plan's regression contract, records constraints in `## Shape`, and appends a
  `refactored` provenance line (new in the event vocabulary) only when a constraint
  actually changed. Close-out reconciles declared against actual, and treats an
  `unchanged` clause whose evaluation had its **assertions** edited as a
  mislabelled amendment — a refactor may move an evaluation's file, never change
  what it asserts.

  The workflows that write or check evaluations were updated to carry the test
  rather than repeat it — `writing-rails-plans` plans the spec homes a quantifier
  needs, `rails-implementor` reports instead of tagging past a gap,
  `executing-rails-plan` reads the reported examples before filling a row,
  `reviewing-rails-work` and `maintaining-primitives`' `lint` treat an unearned
  row as a finding, `capture` may narrow a clause or report the gap but not tag
  the nearest happy path, and `refactoring-rails-specs` gains an intent audit so
  a move, merge, or delete cannot silently unprove a capability.
- `rules/rubocop.mdc` gains one carve-out to never-suppress: a **human-owned**,
  reasoned `Enabled: false` on a harness cop is a standing decision agents must
  leave alone — distinct from suppressing an offence to get a branch green,
  which stays forbidden.

### Added earlier, unreleased

- `install` vendors the skills, rules, and agent definitions into
  `agent_harness_rails/` and links `.claude/` and `.cursor/` at it, migrating any
  content the app already had in those directories so nothing is shadowed or lost.
- `check` verifies the vendored harness against the gem for use in CI, reporting
  local overrides without failing and drift with a non-zero exit.
- `update` re-vendors after a gem bump, keeping local edits and pruning files the
  gem no longer ships.
- Ships `rubocop.yml` for consuming apps to `inherit_gem` as a thin layer over
  rubocop-rails-omakase.
- `install` closes with where to author new harness files, and — when it migrated
  files — that the install commits with `git add -A`, since git cannot name a
  path through the editor links.
