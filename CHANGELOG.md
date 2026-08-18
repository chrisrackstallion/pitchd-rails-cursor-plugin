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
