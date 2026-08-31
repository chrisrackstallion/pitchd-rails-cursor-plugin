# Changelog

All notable changes to this project are documented in this file. The format is
based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Four executable backstops for rules that were previously prose only: a linter
for the primitives tree, a change-review pass over it, a per-example proof
listing, and a RuboCop layer for the rules a parser can settle. Plus one rule
no parser can settle — when a code comment earns its line.

### Added

- **`agent_harness_rails proofs`** — lists the tagged examples proving each
  intent clause, per evaluation file, with a count to hold against the plan's
  proof set.

  It exists because `evals` counts **files**. A clause naming a spec file is
  satisfied by *one* tag in it, so a clause the plan meant to prove with four
  denials passes with three tagged — and `guard` is silent too, because an
  untagged new example is growth. Neither can enforce
  `agent_harness_rails/rules/testing.mdc` § Tagging the Intent a Spec Proves:
  a clause proven by four examples is tagged on all four.

  A tag on a `describe` is named as proving nothing rather than counted as a
  proof, and the footer counts every tag `evals` will reject — naming no active
  clause, sitting on a group, or malformed.

  **Nothing it prints is an offence and the exit code is always 0.** Most
  examples in a spec file carry no tag by design, so a tagged count is a number
  to compare against the plan's proof set, not a verdict; made a gate it would
  fire on nearly every file and get routed around.

  Scope sets the density: bare and `--since main` print one counted line per
  clause (`--since` selecting the clauses whose spec files the change touched,
  untracked files included — the shape a task's verify step runs); naming a
  capability or a clause lists the tagged examples. Untagged examples are not
  printed — they drowned the report in any real spec file, and a reader holding
  the plan already knows which example is missing from the tagged list —
  `--format json` carries them for a reviewer or close-out step.

  Wired into `implementing-rails-task` (verify), `executing-rails-plan`
  (close-out), `reviewing-rails-work` (eval adequacy) and
  `refactoring-rails-specs` (intent audit), against the plan's
  **Intent impact** table, which now names the *cases* a clause needs rather than
  only the file they land in.

- **`agent_harness_rails guard`** — reports what a change did to intent and to
  the specs that prove it, by parsing the primitives tree twice: at `--base`
  (default `HEAD`, or the merge base for `--base main`) and in the working tree.

  It exists because `evals` is stateless. A whole class of drift passes it
  green — a clause reworded under the same id, a tagged example hollowed out
  while it keeps the tag, a browser promise moved onto a model spec, an edited
  provenance entry — because every link stays well-formed. Seeing that needs a
  before. Notices: `intent/rewritten`, `intent/vanished`, `intent/deactivated`,
  `evaluation/dropped`, `evaluation/moved`, `evaluation/relayered`,
  `proof/removed`, `proof/weakened`, `proof/changed`, `doc/removed`,
  `status/downgraded`, `provenance/rewritten`, `doc/unreadable`.

  **Everything it prints is a notice and the exit code is 0 whenever the
  comparison ran.** Each check has an innocent cause as well as a suspicious one
  — a spec refactor produces most of the proof notices legitimately — and a
  check that stops honest work is a check that gets routed around. Growth is
  silent: new clauses, new tagged examples, added evaluations and appended
  provenance produce nothing.

  Wired into `executing-rails-plan` close-out, `reviewing-rails-work`,
  `implementing-rails-task`, `refactoring-rails-specs`, `maintaining-primitives`
  and `rails-primitives-maintainer`, so an agent reads its own notices and
  restores proof it dropped before the work reaches a human. The one thing an
  agent must not do is resolve an **intent** notice: those are discharged by a
  provenance entry naming the clause, and an agent writing that entry to quiet
  its own notice would launder the change the check exists to surface.

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
- **Seventeen `AgentHarnessRails/*` cops** for rules no existing cop covers:
  `ServiceObject`, `GenericOperationMethod`, `NonRestfulAction`, `CsrfSkip`,
  `EnqueueOutsideCommit`, `MailerDeliverNow`, `PolicyVerbMethod`,
  `PolicyContext`, `DeepNestedResources`, `MigrationDataChange`, `SpecSleep`,
  `StubbedSubject`, `ViewSpec`, `UnanchoredAbsence`, `TautologicalAssertion`,
  `HttpStatusComparison`, `IntentTag`. Each names the `.mdc` rule it enforces.

  Three of them exist because of how the other cops get satisfied. Applying the
  layer to a real application turned up agents clearing a message while leaving
  the thing it named in place: `NonRestfulAction` answered by routing the verbs
  through one `show` as `params[:id]` values, and the absence rule answered by
  rewriting `not_to have_http_status(:forbidden)` as
  `expect(response.status).to be < 403` — an assertion that also passes on 200,
  302 and 404 — or by adding `expect(policy).to be_a(described_class)`, which is
  true the moment it is written. `HttpStatusComparison` fails the build on the
  comparison form, `TautologicalAssertion` on the padding;
  `NonRestfulAction`'s message names the fix (a controller per noun, singular
  `resource` routes) and rules out the id-as-action dodge; `running-rubocop` § 4
  states the general form — fix the finding, not the message.

  `ServiceObject` is narrowed to service objects rather than to the words they
  use. A table-backed `Service`, `Operation` or `Command` is domain vocabulary and
  no longer flags: the suffix only marks a wrapper when a name puts a verb in
  front of it, so `PublishArticleService` and `ApplicationService` still do.
- **`rubocop-harness-rspec.yml`** — the spec half, covering most of
  `testing.mdc` via `rubocop-rspec`, `-rspec_rails`, `-capybara` and
  `-factory_bot`. Separate because those are gems your app supplies.
  `FactoryBot/ExcessiveCreateList` is set to **30** rather than the cop's default
  of 10: a pagination spec has to cross the page boundary to assert anything, and
  the ways around the cop — stubbing the page size, looping `create` — are worse
  than the records.

- **`testing.mdc` § Every Assertion Must Be Able to Fail** replaces "every test
  needs at least one positive assertion", which was the wrong rule stated
  confidently. The test is not whether an assertion is positive or negative but
  whether **a failure the example is not about could satisfy it**, which splits
  negations in two. A negation the unit answers directly —
  `expect(policy).not_to permit(...)`, `expect(article).not_to be_published`,
  `expect { card.reopen }.not_to raise_error` — is sound: a missing policy or a
  renamed predicate raises rather than passing, so nothing can land on its passing
  side and there is nothing to add. An absence read off a **by-product** — a
  rendered page, a status, a record reloaded after a request, a count after a
  `post` — is where a 500, a blank render or a wrong guard clause all pass, and
  that is what needs one anchoring assertion beside it.

  The old rule taxed the sound half, and the tax got paid in padding: an example
  asserting a policy denial acquired `expect(policy).to be_a(described_class)` to
  make the linter quiet. Two of the harness's own documented examples — the
  `not_to raise_error` no-op and the job that correctly enqueues nothing — were
  offences under it. `AgentHarnessRails/UnanchoredAbsence` replaces
  `NegativeOnlySpec` accordingly: it fires only when the negation reads a document
  or a response, or the example drove a request or a browser first, and it now sees
  the `expect { }` block form that the old cop's node pattern missed entirely
  (`expect { post ... }.not_to change(Article, :count)` went unreported).

  Two further pieces of the same rule: a **denial usually lacks its counterpart,
  not an anchor** — "the owner cannot destroy" is a real claim because "the admin
  can destroy" passes in the same file — and a denial should be **spelled
  positively** where the language allows, which policy specs already do with
  `expect(policy.destroy?).to be false`. For apps testing policies through a
  matcher, `references/support-specs.md` § Stating a denial gives the one-line
  inverse, `RSpec::Matchers.define_negated_matcher :forbid, :permit`, so
  `expect(policy).to forbid(owner, account)` reads as the assertion it is.
  `refactoring-rails-specs` no longer defaults a `not_to`-only example to
  **DELETE**: that verdict was live coverage loss on every policy spec it met.

- **`agent_harness_rails/rules/comments.mdc`** — the default is no comment.
  Agents annotate liberally, and the annotations are the one artefact in a diff
  that nothing verifies: a comment restating the code drifts the moment the code
  changes, and the next reader believes the comment over the lines under it.

  Every kind of explanation an agent reaches for already has a durable home —
  what the code does is the code's job (`naming.mdc`), how the feature is
  arranged is `## Shape` in the capability doc, what must stay true is an intent
  clause proven by a tagged example, why we rejected the alternative is
  provenance or the PR, and what is left to do is a task. The rule is one
  question — what would a reader get wrong without this comment? — plus the four
  answers that pass (a constraint enforced elsewhere, a workaround naming its
  upstream bug, a measured decision, a deliberate omission), and the annotations
  that are interface rather than commentary (`frozen_string_literal`, strict
  `locals:`, the required why on a custom route segment).

  No cop settles it: RuboCop cannot tell narration from necessity. The gate is
  the question when the comment is written, and `reviewing-rails-work` § 3, where
  a comment restating the code, narrating a step, signposting a section, or
  documenting shape the primitives tree owns is now a `tactical:` finding on
  every diff regardless of layer.

### Changed

- **The three primitives commands print for a reader now.** `evals` and `guard`
  group findings under one path header per file instead of repeating the path
  on every line; `guard`'s `intent/rewritten` notice puts the old and new
  clause on their own indented `was:` / `now:` lines (clipped in text, whole in
  `--format json`); `proofs` prints tagged examples only, aligned, with a count
  per file and per clause — the untagged listing moved to `--format json`,
  where close-out steps read it, because in any real spec file it drowned the
  report. Severity letters and clause ids get colour on a TTY; piped output is
  byte-identical to before colour existed. Summary lines tightened to match:
  `3 capabilities, 14 clauses — 1 offence`.

- **The primitives CLIs are run by the orchestrator and pasted into review
  prompts.** `rails-reviewer` is `readonly: true` and may have no shell at all;
  a Task worker's shell can also return a result with no stdout, no stderr and
  no exit code. Either way the reviewer sees silence and — as happened — falls
  back to hand-reading frontmatter and `intent:` tags, then reports that as
  coverage. `evals`, `guard`, and `proofs` all print a summary line on every
  run, so silence was never the CLI: an empty result is a missing result.

  `executing-rails-plan` (step 2, step 6, R3) and `writing-rails-plans`
  (Pass 1, Pass 2, R3) now run the three commands in the orchestrator's own
  shell and paste the full stdout into the review prompt under **Mechanical
  primitives output (authoritative — do not re-run)**. `reviewing-rails-work`
  cites that block instead of shelling out, and shells out only when it is the
  top-level agent. When no block arrives and no shell works, the report's new
  **Mechanical checks** line reads `UNVERIFIED (CLI unavailable)` with the
  checks that did not run — a hand audit is a different check and does not
  discharge them, and `Status: Approved` cannot rest on one.
  `primitives.mdc` § None of these is quiet is the rule; `readonly: true` on the
  reviewer stays deliberate (a reviewer that edits the tree launders the notice
  it was reading).
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
- **Capability naming and discovery, for trees that grow.** `capabilities/` is
  explicitly flat and **the name prefix is the namespace**: capabilities that split
  off a resource (`comment_threads`, `comment_moderation`) or never owned one
  (authentication, search, notifications) read `<domain>_<behaviour>`, so
  `ls capabilities/ | grep billing` is a working namespace query and the tag format
  never has to change. `primitives.mdc` gains a § Finding the right capability
  naming the three routes — from a spec's own tag, from code by grep, from
  `index.md` — and `index.md`'s line contract is now
  `name — status — outcome. Owns: models.`, with the outcome required to
  *discriminate*: that file is the tree's entire discovery surface and the only
  place an overlap is visible, so a vague line is the mechanism by which a
  duplicate capability gets created. `lint` and plan review both check for it.

### Fixed

- **Capability docs in a subdirectory were silently ignored.** `Capability.load_all`
  globs one level deep, and an `intent:` tag names a bare filename with no path in
  it, so a nested doc's clauses did not exist as far as the tool was concerned —
  with a green run over the gap. Now reported as `doc/nested`, pointing at the name
  prefix that does work. A flat tree is a defensible constraint; failing quietly
  when someone assumes otherwise was not.

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
