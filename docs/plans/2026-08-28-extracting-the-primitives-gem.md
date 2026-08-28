# Should the primitives tooling be its own gem?

**Status:** proposal — nothing executed. Written to answer a question, not to
authorise work.
**Date:** 2026-08-28
**Question asked:** the gem contains a lot of components. Would the primitives
skills and tools be better extrapolated into their own gem, with a setting for
RSpec or Minitest, leaving `agent_harness_rails` as a standalone of agent
pipelines and skills?

## Short answer

**Yes to extracting the primitives tooling — but as a library the Rails harness
depends on, not as a second thing users install.** The coupling permits it, the
code sizes argue for it, and v0.2.0 is the cheapest moment it will ever be.

**No to the framing that this delivers the RSpec/Minitest setting.** Those are
two different seams running in opposite directions through the repo, and cutting
one does not open the other. Nearly all of the RSpec dependency stays in
`agent_harness_rails` after the primitives gem leaves.

**And there is no generic pipeline hiding underneath.** `writing-rails-plans`,
`executing-rails-plan` and `reviewing-rails-work` are not a framework-neutral
pipeline with Rails plugged into it — REST slices, omakase gravity and the
`rails-implementor` / `rails-reviewer` pair are the substance of those skills,
not a theme applied to them.

## 1. The measurement that settles it

Count the two halves of the repo separately. They do not overlap the way the
question assumes.

| | Ruby (`lib/`, 2,208 lines) | Vendored markdown (19,927 lines) |
| --- | --- | --- |
| **Primitives** — `evals/`, `guard/`, `proof_report.rb` | **1,347 (61%)** | **1,160 (6%)** |
| **RSpec-bound testing content** — `testing.mdc`, `writing-tests/` + 5 references, `refactoring-rails-specs` | ~0 | **4,983 (25%)** |
| Vendoring machinery — `installer`, `manifest`, `migration` | 415 (19%) | — |
| CLI — over half of it formats `evals` / `guard` / `proofs` output | 441 (20%) | — |
| Everything else Rails | 0 | ~13,800 (69%) |

Specs follow the Ruby: `evals_spec.rb` + `guard_spec.rb` + `proof_report_spec.rb`
are 1,569 of 3,538 lines before counting their share of `cli_spec.rb`. The cops
follow the markdown: 16 of 17 enforce Rails and RSpec rules, and only
`intent_tag.rb` (91 lines) belongs to primitives.

Two things fall out of that table.

**The gem is a framework-agnostic traceability toolchain wearing a Rails
documentation bundle.** Outside the RuboCop cops there is essentially *no
Rails-specific Ruby in this repo at all*. `Capability`, `Tags`, `Proofs`,
`Guard` and `ProofReport` parse YAML frontmatter and scan text; they never load
Rails, never touch a database, and by explicit design never boot the test
framework either:

```ruby
# lib/agent_harness_rails/evals/tags.rb:18
# Scanned textually rather than by booting RSpec: this must run in any CI
# job, with no database and no Rails environment.
```

Nothing in that stack needs to ship inside a Rails gem, and a Hanami or Sinatra
team could use all of it unchanged.

**The two seams are near-inverses.** Primitives is 61% of the Ruby and 6% of the
markdown. The RSpec dependency is ~0% of the Ruby and 25% of the markdown. A cut
that frees the first leaves the second exactly where it was.

## 2. What the coupling actually is

Extraction is feasible, and the reason is that the primitives overlay was built
gated from the start.

**Layer skills have no coupling at all.** `writing-controllers`,
`writing-models`, `writing-views`, `writing-routes`, `writing-policies`,
`writing-jobs`, `writing-mailers`, `writing-migrations`, `writing-services`,
`writing-hotwire`, `writing-javascript`, `writing-css-tailwind`,
`writing-i18n`, `writing-naming-conventions`, `rails-omakase-compass` and
`running-rubocop` mention primitives nowhere. Fourteen of eighteen rules are
likewise clean.

**The workflow skills reference it behind an explicit tree-presence gate**, in
consistent language — `writing-rails-plans` says *"Runs when the app has a
`docs/primitives/` tree… If the tree does not exist, skip this gate"*,
`reviewing-rails-work` says *"No tree → note 'No primitives tree' in the report
and skip"*, `executing-rails-plan` says *"Only when the app has no tree do you
skip everything primitives-related"*. Same shape in
`implementing-rails-task`, `writing-tests`, `refactoring-rails-specs` and
`testing.mdc`.

**The dependency runs one way.** Primitives assets reach back into the harness
for `writing-tests`, `testing.mdc` and `docs/plans/` conventions; no layer skill
reaches into primitives.

## 3. Where the split cannot be clean

The honest limit. Primitives earns its keep by being *woven into* plan →
implement → review — the README's claim that the record "stays alive as a side
effect of the workflows, not as a chore". That weaving is six insertion points,
and every one of them lives on the Rails side:

| Host | Insertion |
| --- | --- |
| `writing-rails-plans` | primitives gate before drafting; `Capability:` header field; sync pass at final approval |
| `executing-rails-plan` | pre-flight capability check; per-task mechanical output; **step 8 close-out, required when the plan has a `Capability:` line** |
| `reviewing-rails-work` | §5 primitives checks; `primitives:` report section; approval blocked without mechanical output |
| `implementing-rails-task` | capability excerpts as acceptance criteria; `proofs --since` / `guard --base` in verify |
| `refactoring-rails-specs` | intent audit during the spec audit; `evals` green at close-out |
| `rules/testing.mdc` | the whole tagging section |

A skill is markdown read top to bottom. **It cannot inject a numbered step into
another skill's procedure.** So those sections stay in `agent_harness_rails`
whatever happens to the gem boundary, and `agent_harness_rails` keeps knowing the
primitives contract in detail.

What extraction buys is therefore a **versioned, independently testable tool and
file format** — not workflow independence. That is still worth having; it is just
less than the question hopes for, and worth saying before anyone starts.

## 4. Why "RSpec or Minitest" is a different seam

The setting is a good idea. It is largely not in the primitives gem.

**The adapter surface inside the primitives tooling is about six values**, and
they are already isolated:

| Knob | Today |
| --- | --- |
| Test directory | `DEFAULT_SPECS_DIR = "spec"` — `lib/agent_harness_rails/evals.rb:19`, already a keyword arg on `Evals.run` |
| File glob | `Dir.glob(File.join(dir, "**", "*_spec.rb"))` — `lib/agent_harness_rails/evals/tags.rb:94` |
| Example / group openers | `EXAMPLE_METHODS`, `GROUP_METHODS`, `OPENER` — `lib/agent_harness_rails/evals/tags.rb:54` |
| Assertion pattern | `/\b(?:expect\|is_expected\|assert\|assert_not)\b/` — `lib/agent_harness_rails/evals/proofs.rb:47`, **already accepts Minitest** |
| Layer inference | `path.split("/")[1]` — `lib/agent_harness_rails/guard.rb:351`, already correct for `test/system/…` |
| Cop scope | `EXAMPLE_METHODS` in `intent_tag.rb:42`; `Include: "**/spec/**/*.rb"` in `config/default.yml:246` |

That is a small, well-bounded piece of work — and it can be done **today, in
this gem, without any extraction at all.**

**What actually costs, and what does not move:** `testing.mdc` (567 lines, ~40%
RSpec mechanics), `writing-tests/SKILL.md` plus five reference files
(`factory-patterns.md` is ~95% FactoryBot), `refactoring-rails-specs` (~90%
RSpec by structure, not just syntax), `rubocop-harness-rspec.yml` (178 lines,
entirely the `rubocop-rspec` / `-capybara` / `-factory_bot` plugin set), and six
of the custom cops. Roughly 5,000 lines of markdown plus the configs, all of it
Rails-harness content that stays put.

**One design cost to decide before building it.** RSpec's `intent:` is real
metadata that both *binds* the clause and *selects* the proof —
`rspec --tag 'intent:comment_threads#I2'` — and the README sells that duality.
Minitest has no metadata. The options are a comment (`# intent: billing#I1`), a
helper call in the test body, or a third-party tagging gem forced into the
consuming app's Gemfile. The first two parse fine for `evals`, `guard` and
`proofs`; both lose "the same tag runs the proof". Worth naming as an accepted
trade-off rather than discovering it mid-implementation.

## 5. What a distribution split costs

Three costs, one of which is structural.

**The installer is single-owner, and that is the hard one.** `.cursor/skills`
and `.claude/skills` are *one symlink each, pointing at one directory*
(`Installer::LINKS`). Two gems that each install cannot both own that link.
Three ways out:

| | Approach | Cost |
| --- | --- | --- |
| a | Both gems vendor into `agent_harness_rails/` | Directory named for the wrong gem; `.manifest.json` is one file at the payload root, so ownership and `prune` need namespacing |
| b | Separate payload dirs; editor dirs become real directories of per-skill symlinks | Real rework of `Installer` and `check`; dozens of links instead of five; the Windows story gets materially worse |
| **c** | **`agent_harness_rails` depends on the primitives gem and vendors both payloads under `agent_harness_rails/`** | **Install UX unchanged; primitives still gets an independent release and a non-Rails life** |

(c) is the one to take. The primitives gem gains a version, a test suite and a
consumer that is not this repo; the app still runs one `install`.

**`bin/check-references` becomes partly blind.** Every internal reference is
written in one canonical form (`agent_harness_rails/rules/models.mdc`) and CI
fails on a typo. References crossing a gem boundary cannot be resolved from
either repo alone, so renaming a primitives skill would break the Rails gem's
references with nothing catching it — losing precisely the guarantee the README
advertises. Under (c) this is recoverable: the primitives payload is present at
check time, and `check-references` learns a second canonical prefix.

**Version coupling is real and permanent.** The six insertion points name
primitives skills and CLI commands by path and by flag. The two gems will move
together regardless of how they are packaged.

## 6. Recommendation — three moves, each independently valuable

Ordered so any one of them can be the last one taken.

### Step 1 — make the payload selectable at install

The felt problem is "a lot of components", and a gem split is an expensive way to
address it. Skills are discovered by description, so every vendored skill costs
context on every run and costs a new reader attention in the README, whether or
not they use it.

Add payload groups to `install` (`--without primitives`, or a `profile` concept)
so an app vendors the Rails harness without the primitives overlay, or a subset
of layer skills. `Manifest` already tracks per-file ownership and `prune` already
removes files the gem stopped shipping, so this is a modest addition to
`Installer#classify` and the manifest format rather than new machinery.

**If this satisfies the itch, stop here.** It costs a fraction of the rest and it
is the only step that changes anything for someone who already installed the gem.

### Step 2 — extract the primitives gem (library + payload), keep one installer

Move `Capability`, `Tags`, `Proofs`, `Finding`, `Guard`, `Baseline`,
`ProofReport`, the `evals` / `guard` / `proofs` commands, the `IntentTag` cop,
`rules/primitives.mdc`, `bootstrapping-primitives`, `maintaining-primitives` and
its templates, and `rails-primitives-maintainer` into a new gem. Introduce the
test-framework adapter from §4 at the same time, since the seam is being touched
anyway. `agent_harness_rails` takes a runtime dependency, vendors both payloads
under `agent_harness_rails/`, keeps the six insertion points, and extends
`check-references` to the second prefix.

Do it now or not at all: at v0.2.0 with an open `[Unreleased]` section this is
cheap, and every release makes it dearer.

### Step 3 — test-framework variants for the Rails testing content

The large, genuinely separate piece: `testing.mdc`, `writing-tests` and its
references, `refactoring-rails-specs`, `rubocop-harness-rspec.yml` and the six
spec cops. Two plausible shapes — an install-time `--test-framework` flag that
vendors one of two variants, or philosophy kept in the shared file with mechanics
pushed behind `references/rspec.md` and `references/minitest.md`. The second is
truer to how the content already splits: both `testing.mdc:15` and
`writing-tests/SKILL.md:29` already say the philosophy is the Minitest-shaped
vanilla-Rails position and the tooling is an RSpec adaptation of it.

Scope honestly. This is the largest of the three by a wide margin, it doubles the
maintenance surface of the most-used part of the harness, and it should not start
until someone actually wants to run the harness on a Minitest suite.

## 7. What I would not do

- **A three-gem decomposition** with a generic `agent_harness` installer core.
  Tempting — the installer is 415 lines with nothing Rails or primitives about it
  — but it triples release overhead for a v0.2 project and does not solve the
  single-owner link problem, which is the actual hard part.
- **Two independently-installed products.** Options (a) and (b) in §5 both buy
  packaging purity with install-time complexity that every consumer pays.
- **Treating step 2 as delivering Minitest support.** It delivers the adapter
  seam for the six values in §4. The other ~5,000 lines are step 3.
- **Carving a generic pipeline gem out of the workflow skills.** The Rails
  opinions are the content, not a coat of paint.

## 8. Open questions

1. **Whose problem is "a lot of components"** — a consumer's (too much vendored,
   too much context, too much README) or a maintainer's (one repo, one release,
   two unrelated test suites)? Step 1 answers the first; step 2 answers the
   second. The answer changes the order.
2. **Is there a non-Rails consumer for primitives**, actual or intended? That is
   the strongest argument for step 2 and the only one that makes a separate
   RubyGems listing worth its overhead.
3. **Minitest: real demand or hypothetical?** Step 3 is the largest piece of work
   in this document and should be pulled by a user, not pushed by symmetry.
4. **Naming**, if step 2 proceeds. The gem is not Rails-specific, so
   `agent_harness_primitives` would misdescribe it and `primitives` is far too
   generic to claim.
