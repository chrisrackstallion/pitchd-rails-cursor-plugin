# agent_harness_rails

A harness for coding agents working on Rails apps, built around one idea: **keep a durable record of what your app must do, and prove it with tests.**

That record is the **primitives tree**. Around it, the gem ships the skills, rules, and agent definitions that teach [Cursor](https://cursor.com) and [Claude Code](https://claude.com/claude-code) to build Rails the omakase way — and to keep the record alive as a side effect of planning, implementing, and reviewing.

## Primitives

Code can't carry *why*. It shows what the app does today, not what it must keep doing, which alternatives were rejected, or which test proves which promise. When agents write most of the code, that knowledge evaporates unless something holds it.

The primitives tree is that something: plain markdown in `docs/primitives/`, one doc per capability, four sections each.

| Section | Holds |
| --- | --- |
| **Intent** | Numbered clauses stating what must be true. `I1 — A reader can reply to any comment.` |
| **Shape** | Constraints the implementation must respect, beyond the framework defaults |
| **Evaluations** | Which spec proves each clause |
| **Provenance** | Append-only history: decisions, rejected alternatives, accepted debt |

Intent and evaluations live in YAML frontmatter so tools can check them. Each proving example carries its clause id as RSpec metadata:

```ruby
it "shows replies nested under their parent", intent: "comment_threads#I2" do
```

The same tag runs the proof on demand: `bundle exec rspec --tag 'intent:comment_threads#I2'`.

### Three tools keep the record true

**`evals`** — a CI check that every clause is proven, in both directions: a clause with no spec fails, and a tag pointing at a clause that no longer exists fails. It parses statically — no database, no Rails boot — so it runs in any CI job.

```console
$ bundle exec agent_harness_rails evals
docs/primitives/capabilities/comment_threads.md:12:1: E: I3 has no evaluation — a built clause must name the spec that proves it [clause/unproven]

3 capabilities inspected, 14 clauses, 1 offence detected
```

**`guard`** — compares the tree against a base revision and reports what got smaller or different: a clause reworded under the same id, a proving example that lost assertions. Growth is silent by design; only shrinkage or substitution needs your attention. Everything it prints is a notice, never a failure — agents read their own notices and restore proof they dropped by accident, and intent notices come to you, because only the user's decision changes intent.

```console
$ bundle exec agent_harness_rails guard --base main
spec/system/comment_threads_spec.rb:7:1: N: the example proving comment_threads#I2 lost 1 assertion(s) — it still carries the tag while proving less of the clause [proof/weakened]
```

**`proofs`** — a lookup, not a check: which examples prove a clause, and which examples in the same file carry no tag. `proofs --since main` scopes it to what a branch touched, which is the shape a task's verify step runs.

### The record stays alive on its own

You never "go document things." Planning writes intent clauses. Execution close-out fills in evaluations and provenance. Review checks traceability. The workflows below do this automatically whenever a `docs/primitives/` tree exists — and skip it cleanly when one doesn't.

To adopt it, ask your agent to **"set up primitives"** (the `bootstrapping-primitives` skill scaffolds the tree and interviews you for app-wide constraints). Backfills, provenance questions, and health passes go through `maintaining-primitives`.

## Install

```ruby
# Gemfile
group :development do
  gem "agent_harness_rails", require: false
end
```

```bash
bundle install
bundle exec agent_harness_rails install
git add -A && git commit -m "Install agent harness"
```

`install` vendors the harness into `agent_harness_rails/` and points both editors at it with symlinks:

```
myapp/
  agent_harness_rails/          # the harness — commit this
    skills/  rules/  agents/
  .claude/skills        -> ../agent_harness_rails/skills
  .claude/agents        -> ../agent_harness_rails/agents
  .cursor/skills        -> ../agent_harness_rails/skills
  .cursor/agents        -> ../agent_harness_rails/agents
  .cursor/rules/harness -> ../../agent_harness_rails/rules
```

Teammates clone the repo and it works — no bundle step needed to *use* the harness, only to update it. Anything already in `.claude/` or `.cursor/` is moved into the shared directory first, so both editors see it; your files stay yours and are never overwritten on update.

| Command | What it does |
| --- | --- |
| `install` | vendor the harness and create the links (idempotent) |
| `update` | re-vendor after `bundle update`, reporting what changed |
| `check` | verify the vendored harness matches the gem — use in CI |
| `evals` | check every intent clause is proven — use in CI |
| `guard --base <rev>` | report what a change did to intent and its proofs |
| `proofs <scope>` | list the examples proving a clause |

## The Rails harness

The rest of the payload is conventions: opinionated Rails best practice — omakase defaults, majestic monolith, REST-shaped boundaries, server-owned truth, Hotwire-first front ends.

- **Workflow skills** — say it, and the agent picks the right one:
  - *"I want to let people follow projects, not sure how it should work"* → `brainstorming-rails-omakase` shapes the idea into an approved spec before any code.
  - *"Write a plan for comment threads"* → `writing-rails-plans` produces a checklisted plan with real file paths and code, reviewed before you see it.
  - *"Execute the plan"* → `executing-rails-plan` delegates each task to an implementor subagent and loops a reviewer on it until approved.
  - *"Review this PR"* → `reviewing-rails-work` checks philosophy first (is this the right kind of Rails solution?), then tactics.
  - *"The system specs are too heavy"* → `refactoring-rails-specs` rebalances a test suite layer by layer. `refactoring-stimulus-controllers` does the same for a Stimulus fleet.
  - *"How should I handle this in Rails?"* → `rails-omakase-compass`, the philosophy reference behind everything else.
- **Layer skills and rules** — `writing-models`, `writing-controllers`, `writing-tests`, and a dozen more, each paired with an `.mdc` rule file. Cursor attaches rules by glob; skills open them by path.
- **Agents** — subagent definitions for implementation, review, querying, and primitives maintenance.

## RuboCop

The gem ships three configs your app can inherit, in increasing strictness:

```yaml
# .rubocop.yml
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
  agent_harness_rails:
    - rubocop.yml                 # thin layer over omakase — changes almost nothing
    - rubocop-harness.yml         # opt-in: turns the parseable rules into real cops
    - rubocop-harness-rspec.yml   # opt-in: needs rubocop-rspec and friends in your Gemfile
```

`rubocop-harness.yml` enables ~100 existing cops that encode rules already written down here, plus fifteen custom `AgentHarnessRails/*` cops for what no existing cop covers — service objects, non-REST actions, enqueueing inside transactions, view specs, `sleep` in specs. Each names the rule it enforces, and your own `.rubocop.yml` can turn any of it off; agents are told to respect your opt-outs. The gem deliberately does not depend on RuboCop — it ships YAML and cop files, and your app's bundle provides RuboCop at your version.

## Good to know

- **Adding your own skills:** put them in `agent_harness_rails/skills/` alongside the vendored ones. Keep them flat (`skills/<name>/SKILL.md`) and don't reuse a vendored name. Write to `agent_harness_rails/`, not through the `.claude/` or `.cursor/` links.
- **Git and the symlinks:** git can't stage paths through a symlink, so commit the install with `git add -A`, and stage your own new skills under `agent_harness_rails/`.
- **Windows:** committed symlinks need Developer Mode plus `core.symlinks=true` *before* cloning. Or run `bundle exec agent_harness_rails install --mode copy` after cloning to use real directories locally.
- **Your editor shows the harness twice** — the vendored directory and the linked one are the same files. Nothing to clean up.

## Credits

- **Chad Fowler** and **[Regenerative Software](https://www.linkedin.com/posts/fowlerchad_im-genuinely-excited-to-share-the-early-share-7488974712543277056-iRQi/)** — the inspiration for the primitives tree: durable intent, evaluations that prove each clause, and provenance that outlives any implementation.
- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — planning, execution, and review skill patterns.
- **[Superpowers](https://github.com/obra/superpowers)** — disciplined planning and execution workflows.
- **[37signals-skills](https://github.com/marckohlbrugge/37signals-skills)** (Marc Köhlbrugge) — a community guide to Rails coding patterns, fetched selectively as a supplemental reference.

## License

MIT — see [LICENSE](LICENSE).
