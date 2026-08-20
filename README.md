# agent_harness_rails

Rails conventions for coding agents — **rules**, **skills**, and **agent definitions** for building **Rails** applications the way we like: **opinionated Rails best practice** (omakase, majestic monolith, REST-shaped boundaries, Hotwire-first front ends).

Ships as a gem that **vendors itself into your app**, so [Cursor](https://cursor.com) and [Claude Code](https://claude.com/claude-code) both read the same files from the project directory alone. No editor plugin to install, nothing outside the repo, nothing per-machine.

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
```

That vendors the harness into `agent_harness_rails/` and points each editor directory at it — one name throughout: the gem, the require, the command, and the vendored directory all match.

```
myapp/
  agent_harness_rails/          # the harness — commit this
    skills/  rules/  agents/
    .manifest.json              # which files the gem owns
  .claude/skills        -> ../agent_harness_rails/skills
  .claude/agents        -> ../agent_harness_rails/agents
  .cursor/skills        -> ../agent_harness_rails/skills
  .cursor/agents        -> ../agent_harness_rails/agents
  .cursor/rules/harness -> ../../agent_harness_rails/rules
```

Commit all of it, links included. A teammate on macOS or Linux clones the repo and it works — no `bundle` step needed to *use* the harness, only to update it. Windows needs one extra step: see [Windows](#windows) below.

### Already have skills, rules, or agents in `.claude/` or `.cursor/`?

`install` **moves them into `agent_harness_rails/` first**, before the symlinks go in. Those directories become links, so anything left in them would be shadowed — and in `--mode=copy`, overwritten. Migration happens for both editors' `skills/` and `agents/`, and for `.cursor/rules/*.mdc`.

You come out ahead: a skill that only Claude Code could see because it lived in `.claude/skills/` is now visible to Cursor too, from the one shared directory.

Migrated files stay **yours** — they aren't recorded in `.manifest.json`, so `update` never touches them. If one of your names collides with a vendored one, `install` refuses and changes nothing rather than picking a winner; rename yours, or delete it to accept the harness version. An identical copy is recognised as such and quietly dropped in favour of the vendored file.

`--no-migrate` opts out, in which case `install` refuses to touch a populated editor directory at all.

If git was tracking those files at their old paths, **commit the install with `git add -A`** — the deletions now sit beneath a symlink and cannot be staged by name. See [Git cannot name paths through the links](#git-cannot-name-paths-through-the-links).

| Command | What it does |
| --- | --- |
| `agent_harness_rails install` | migrate any existing editor content, vendor the harness, create the links (idempotent) |
| `agent_harness_rails update` | re-vendor after `bundle update`, reporting what changed |
| `agent_harness_rails check` | verify the vendored harness matches the gem — use in CI |
| `agent_harness_rails evals` | check every intent clause in `docs/primitives/` is proven by a spec — use in CI ([below](#checking-that-intent-is-proven)) |
| `agent_harness_rails guard` | report what a change did to intent and the specs that prove it ([below](#seeing-what-a-change-did-to-the-record)) |
| `agent_harness_rails proofs` | list the examples proving each clause, and what they leave untagged ([below](#seeing-which-examples-prove-a-clause)) |

### Windows

Git for Windows checks out committed symlinks as **plain text files** containing the link path unless symlink support is on — which needs Developer Mode (or admin) plus `core.symlinks=true` *before* cloning. Neither editor resolves those text files, so a stock-Windows teammate cloning a link-mode repo gets a harness that silently doesn't load. Two ways out:

- **Enable symlinks, then clone**: turn on Developer Mode, `git config --global core.symlinks true`, and re-clone. The committed links then work exactly as on macOS and Linux.
- **Or switch to copies locally**: run `bundle exec agent_harness_rails install --mode copy` after cloning. It replaces the broken link files with real directories. This shows up as a local change against the committed links — don't commit it unless the whole team is moving to copy mode.

The same `--mode=copy` applies to any filesystem without usable symlinks.

### Adding your own skills

Put them straight into `agent_harness_rails/skills/` alongside the vendored ones — that's why the directory is named for the harness rather than for us. `install` tracks only the files it owns in `.manifest.json`; anything else it leaves alone, and it refuses to overwrite a file it doesn't own rather than clobbering your work.

Two constraints worth knowing:

- **Keep skills flat.** One level: `skills/<name>/SKILL.md`. Claude Code discovers exactly that shape and does not recurse into subdirectories, so a nested skill is invisible to it even though Cursor would find it.
- **Names are global.** Both editors key on the `name:` in frontmatter, so an app skill can't reuse a vendored name.
- **Write to `agent_harness_rails/`, not through `.claude/` or `.cursor/`.** Writing through a link works; committing that path doesn't — see [Git cannot name paths through the links](#git-cannot-name-paths-through-the-links).

### Inheriting the RuboCop config

The gem ships a `rubocop.yml` your app can inherit, so the linter and the harness agree:

```yaml
# .rubocop.yml in your app
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
  agent_harness_rails: rubocop.yml
```

Order matters. The harness config is a **thin layer over omakase**, not a replacement — [`rules/rubocop.mdc`](agent_harness_rails/rules/rubocop.mdc) names `rubocop-rails-omakase` as the ruleset source of truth, so the harness never restates or contradicts its cop settings. It deliberately does **not** set `NewCops` either: a shipped config that auto-enables cops would change your lint results whenever your RuboCop version bumps. Whether new cops are pending or enabled is your app's call — though the harness position is that a pending cop is a deferred offence, and this repo enables them for itself.

**The gem does not depend on RuboCop, and shouldn't.** It ships YAML and cop files; RuboCop is what loads them, from your bundle, and only when you opt in below. RuboCop and `rubocop-rails-omakase` belong in your app's own Gemfile, at whatever versions you pin — a hard dependency here would force RuboCop into the bundle of every app that installs the harness, including ones that don't lint, and would fight your own version constraint.

### Enforcing the rules, not just describing them

`rubocop.yml` above changes almost nothing. Two further files, each opt-in, turn the slice of these rules a parser can settle into actual cops:

```yaml
# .rubocop.yml in your app
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
  agent_harness_rails:
    - rubocop.yml                 # thin omakase layer, as above
    - rubocop-harness.yml         # harness rules — needs nothing extra
    - rubocop-harness-rspec.yml   # needs rubocop-rspec and friends in your Gemfile
```

`rubocop-harness.yml` enables around a hundred existing `Rails/*`, `Naming/*`, `Lint/*` and `Security/*` cops that encode rules already written down here, configures `Layout/ClassStructure` and `Rails/ActionOrder` to the model and controller ordering the rules document, and adds fifteen custom `AgentHarnessRails/*` cops for the rules no existing cop covers — no service objects, non-REST controller actions, enqueueing inside a transaction, policies reaching for `params`, view specs, `sleep` in specs, examples whose only assertion is `not_to`. Each names the `.mdc` file it enforces.

**Why separate from `rubocop.yml`:** omakase disables every `Lint`, `Rails`, `Metrics`, `Naming` and `Style` cop and re-enables only formatting. That is a deliberate position — omakase Rails does not lint semantics. Turning these on is a real change of stance, so you choose it rather than inheriting it on a gem bump.

**You can turn any of it off.** Your own `.rubocop.yml` wins:

```yaml
Layout/ClassStructure:
  Enabled: false            # We order models by reading flow, not macro type.

AgentHarnessRails:
  Enabled: false            # Or drop the whole custom department.
```

That is a standing, human-owned decision, and the harness distinguishes it from suppressing an offence to get a branch green — which stays forbidden. Agents are told to leave your opt-outs alone rather than re-enable them or work around them ([`rules/rubocop.mdc`](agent_harness_rails/rules/rubocop.mdc) § The one carve-out).

**What no config can reach:** RuboCop parses Ruby, so ERB, Stimulus, and Tailwind get nothing — roughly a quarter of the rules stay review-only. Neither can config enforce the process: zero offences before work is complete, fix in code, never `# rubocop:disable`, never a `.rubocop_todo.yml`. The `running-rubocop` skill and the rule are what hold agents to those.

### Checking that intent is proven

`agent_harness_rails evals` is the other half: a linter for the [primitives tree](#keep-durable-primitives-intent-compilation-evaluations-provenance). Each capability doc declares its intent clauses and the specs that prove them in YAML frontmatter; each proving example carries the clause id as RSpec metadata:

```ruby
it "shows replies nested under their parent", intent: "comment_threads#I2" do
```

The tag goes on the example, never on the `describe` or `context` around it. A group tag looks tidier and is the one form that can go on lying: delete the example it was standing for, and the siblings keep the group green while the clause still claims a proof that no longer exists.

```console
$ bundle exec agent_harness_rails evals
docs/primitives/capabilities/comment_threads.md:12:1: E: I3 has no evaluation — a built clause must name the spec that proves it [clause/unproven]
spec/system/billing_spec.rb:8:25: E: intent tag "billing#I1" is on `describe` — tag the example that proves the clause, or the tag outlives the example it stood for [tag/misplaced]
spec/system/billing_spec.rb:12:5: E: intent tag "billing#I9" names no such clause [tag/unresolved]

3 capabilities inspected, 14 clauses, 3 offences detected
```

It checks both directions — a clause with no proof, and a proof pointing at a clause that no longer exists — so the map cannot quietly stop matching the suite. Coverage is total: every active clause on a `built` doc names a spec, and there is no annotation that excuses one. It parses statically: no database, no Rails environment, runs in any CI job. The same tag runs the proof on demand: `bundle exec rspec --tag 'intent:comment_threads#I2'`.

Scope is deliberately narrow, so a green run means one thing. Tree health — index sync, size limits, provenance style — stays with the `maintaining-primitives` skill, where it needs judgment rather than a parser.

### Seeing what a change did to the record

`evals` is stateless: it asks whether the tree is well-formed *now*. A whole class of drift passes it green — reword a clause under the same id, hollow out the example proving it, move a browser promise onto a model spec, and every link stays well-formed while the record quietly stops describing the app. Seeing that needs a *before*.

`agent_harness_rails guard` parses the tree twice, at a base revision and in the working tree, and reports what got **smaller or different**:

```console
$ bundle exec agent_harness_rails guard --base main
docs/primitives/capabilities/comment_threads.md:4:1: N: I1 now promises something else, under the same id and with no provenance entry. Was: "A reader can reply to any comment.". Now: "A signed-in reader can reply to any comment.". An amendment supersedes the old clause and records the decision — only the user's decision changes intent [intent/rewritten]
spec/system/comment_threads_spec.rb:7:1: N: the example proving comment_threads#I2 lost 1 assertion(s) — it still carries the tag while proving less of the clause [proof/weakened]

compared against 8f59dec5d2c8: 2 notices for review — none of this fails the run
```

Growth is silent by design — new clauses, new tagged examples, added evaluations and appended provenance produce nothing. Only shrinkage or substitution is worth your attention.

**Everything it prints is a notice, and the exit code is 0 whenever the comparison ran.** Every check in it has an innocent cause as well as a suspicious one — a spec refactor legitimately produces most of the proof notices — and a check that stops honest work is a check that gets routed around. It is wired into the skills (`executing-rails-plan` close-out, `reviewing-rails-work`, `implementing-rails-task`, `refactoring-rails-specs`, `maintaining-primitives`) so an agent reads its own notices and restores proof it dropped by accident, before the work reaches you.

What an agent is told *not* to do is resolve an **intent** notice. Those are discharged by a provenance entry naming the clause — and an agent writing that entry to quiet its own notice would launder exactly the change the check exists to surface. Intent notices come to you.

### Seeing which examples prove a clause

`evals` counts **files**. A clause naming `spec/policies/long_list_policy_spec.rb` is satisfied the moment *one* example in that file carries the tag — so a clause the plan meant to prove with four denials passes with three tagged, and `guard` is silent too, because an untagged new example is growth. The rule neither of them can enforce is the one in `agent_harness_rails/rules/testing.mdc`: a clause proven by four examples is tagged on all four.

`agent_harness_rails proofs` is that missing view — a **lookup**, not a check:

```console
$ bundle exec agent_harness_rails proofs 'project_stages#I3'
project_stages (built)

  I3  Only a published stage accepts entries.
    spec/policies/long_list_policy_spec.rb  3 of 5 examples carry this tag
      :3  allows entry to a published stage  (1 assertion)
      :11  denies entry to an archived stage  (2 assertions)
      :16  denies entry to a locked stage  (1 assertion)
      carrying no intent tag — check each against the plan's proof set:
      :7  denies entry to a draft stage
      :22  returns only published stages

1 clause, 3 tagged examples
```

The scope is quoted so no shell reads the `#` as a comment or a glob. Output density follows the scope. Bare, it is one line per clause — a health pass that stays scannable at two hundred of them. A capability adds each clause's proving examples. Naming a single clause adds the file's **untagged** examples, which is the line that shows the denial the plan asked for and the implementation never tagged. `--since main` reports every clause whose spec files the branch touched, untracked files included, which is the shape a task's verify step runs:

```console
$ bundle exec agent_harness_rails proofs --since main
```

A tag on a `describe` or `context` is named as proving nothing rather than shown among the proofs — it has no example under it, so it would otherwise print with no description and no assertions and read as a real, weak proof. The footer counts every tag `evals` will reject: naming no active clause, sitting on a group, or malformed.

**Nothing here is an offence and the exit code is always 0.** Most examples in a spec file carry no tag by design — "only evaluation examples are tagged" — so `3 of 5` is a number to compare against the plan's proof set, never a verdict. Made a gate it would fire on nearly every file and get routed around. `--format json` feeds it to a reviewer or a close-out step.

### Your editor will show the harness twice

Both editors expand a symlinked directory inline in the file tree, so `agent_harness_rails/skills/` and `.claude/skills/` appear as separate copies of the same content. They are one set of files — same inode, edit either path. Nothing to clean up.

### Git cannot name paths through the links

Git tracks the **symlinks** in `.claude/` and `.cursor/` — never the files behind them. Any pathspec that traverses one is refused, even when the file is sitting right there:

```
$ git add .cursor/skills/writing-spec-text-assertions/SKILL.md
fatal: pathspec '.cursor/skills/writing-spec-text-assertions/SKILL.md' is beyond a symbolic link
```

It shows up in two shapes.

**Committing the install itself.** Migration moved files git was tracking at their old `.cursor/` and `.claude/` paths, so git wants those deletions staged — and those paths now sit beneath a link, so they cannot be named at all. Stage in bulk:

```bash
git add -A
```

That records the deletions, the new symlinks, and the vendored harness together — the whole install, which is what you're committing anyway. (`git add -u` alone if you want only the deletions; `git rm --cached` also reaches them, since it works on the index.)

**A new file authored through a link.** The write is fine — it landed in `agent_harness_rails/skills/` — so stage it there:

```bash
git add agent_harness_rails/skills/writing-spec-text-assertions/SKILL.md
```

Then author under `agent_harness_rails/` from then on. `.cursor/skills/` is where skills *look* like they live, so it is the path an agent writes to unless told otherwise — worth saying explicitly when you ask one to add a skill.

## What you can do

### Shape an idea before planning it
> *"I want to let people follow projects, not sure how it should work"*

Use the **`brainstorming-rails-omakase`** skill. It turns a half-formed idea into an approved requirements spec through dialogue, with omakase Rails as the constraint — server-owned truth, REST gravity, fat models, Hotwire-first, no premature service layer. One question at a time, two or three approaches with their trade-offs stated in Rails terms, and each approach naming **where the domain logic will live**. It ends by writing a spec to `docs/brainstorms/` with a **delivery sequence**: the ordered deployable slices, one plan each. A hard gate stops it writing code or migrations before you've approved the spec.

Reach for it when the scope is unclear or several directions look valid. When you already know what you want built, go straight to a plan.

### Write a plan
> *"Write a plan for adding comment threads to posts"*

Use the **`writing-rails-plans`** skill. It turns a spec or feature description into a checklisted implementation plan — exact file paths, real Ruby snippets, RSpec commands, and REST-shaped decomposition. A philosophy check and a tactical pass run before you see the final plan.

### Execute a plan
> *"Execute the plan"*

Use the **`executing-rails-plan`** skill. An orchestrator delegates each task to a `rails-implementor` subagent, then runs `rails-reviewer` after each task and loops on feedback until every item is approved.

### Review existing code
> *"Review this PR"* / *"Review the code I just wrote"*

Use the **`reviewing-rails-work`** skill. It runs a two-layer review: **philosophy** (is this the right kind of Rails solution?) via `rails-omakase-compass`, then **tactics** (is it implemented correctly?) via the relevant `writing-*` skills and rules. During implementation reviews it also checks the **surroundings** — pre-existing code in touched files — flagging quick wins and deferred follow-ups in the same report.

### Query for Rails best practice
> *"How should I handle this in Rails?"* / *"What's the right pattern for background jobs here?"*

Use the **`rails-omakase-compass`** skill. It answers whether a direction fits opinionated best-practice Rails — omakase defaults, REST gravity, server-owned truth, majestic monolith — and points you at the right `writing-*` skill for tactical detail. It can also pull from a third-party community guide via **`referencing-unofficial-37signals-guide`**.

### Refactor an existing test suite
> *"The system specs are too heavy"* / *"Rebalance the article specs to the right layers"*

Use the **`refactoring-rails-specs`** skill. It takes a list of specs (typically bloated system specs), discovers their related request, model, policy, job, mailer, and factory specs, then audits every `it` block against the Five Gates and per-layer ownership defined in `writing-tests`. Each test gets a verdict — **KEEP / MOVE / MERGE / DELETE / REWRITE** — and the work proceeds one resource at a time with coverage preserved and the suite kept green.

### Refactor an existing Stimulus fleet
> *"The Stimulus controllers are a mess"* / *"Half of these do the same thing"*

Use the **`refactoring-stimulus-controllers`** skill. It maps every controller and its `data-*` attachments, scores each against single-responsibility, DOM-derived state, lifecycle cleanup, and cross-controller coupling rules, then assigns a verdict — **KEEP / REWRITE / MERGE / SPLIT / DELETE**. After the structural refactor it ensures each Stimulus behaviour has exactly one canonical system spec on the simplest representative page, per `writing-tests`. Pair with **`writing-javascript`** for fresh-write conventions.

### Keep durable primitives (intent, compilation, evaluations, provenance)
> *"Set up primitives"* / *"Document the billing feature"* / *"Why don't we cap thread depth?"*

The harness maintains **`docs/primitives/`** — one markdown doc per capability holding **intent clauses** (what must be true), **shape** (constraints the code compiles into), an **evaluations map** (which RSpec home proves each clause), and append-only **provenance** (decisions, rejected alternatives, accepted debt). Planning creates and amends intent, execution close-out fills evaluations and provenance, and review checks traceability — so the record stays alive as a side effect of the workflows, not as a chore. Intent and evaluations live in each doc's YAML frontmatter so **[`agent_harness_rails evals`](#checking-that-intent-is-proven)** can check them; a record nothing verifies is a record that quietly stops being true. One-time setup (tree scaffold + a `compilation.md` interview): **`bootstrapping-primitives`**. Backfills, provenance questions, and health passes: **`maintaining-primitives`**, delegated via **`rails-primitives-maintainer`**. Structure rules: **`agent_harness_rails/rules/primitives.mdc`**.

---

New here? Start with **`rails-omakase-compass`** to understand the philosophy, then reach for the workflow skills above.

## What's inside

- **`agent_harness_rails/rules/`** — `.mdc` rules for models, controllers, routes, Hotwire, testing, RuboCop, and more. Cursor attaches them by glob; skills open them by path.
- **`agent_harness_rails/skills/`** — Workflows for planning, implementing, and reviewing Rails work, including layer-specific `writing-*` skills.
- **`agent_harness_rails/agents/`** — Subagent definitions for implementation, review, query, and primitives maintenance.

Every internal reference is written in one canonical form — `agent_harness_rails/rules/models.mdc` — which resolves identically from this repo's root and from a consuming app's root. `bin/check-references` enforces that in CI, so a mistyped path fails the build instead of failing silently inside an agent.

## Credits

This harness stands on the shoulders of two excellent Cursor plugin ecosystems, one reference guide, and one book:

- **Chad Fowler** and his book **[Regenerative Software](https://www.linkedin.com/posts/fowlerchad_im-genuinely-excited-to-share-the-early-share-7488974712543277056-iRQi/)** — the inspiration for the **primitives** tree. Durable intent, the constraints code compiles into, evaluations that prove each clause, and append-only provenance all come from that thinking: the record of *why* outlives any particular implementation.
- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — for strong **planning**, **execution**, and **review** skills and patterns; its opinionated Rails reviewer persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and **execution** workflows.
- **[37signals-skills](https://github.com/marckohlbrugge/37signals-skills)** (Marc Köhlbrugge, formerly `unofficial-37signals-coding-style-guide`) — a community-maintained, explicitly unofficial guide to Rails coding patterns, fetched selectively as a supplemental reference.

Thank you to all four for the ideas and structure that made this harness possible.

## License

MIT — see [LICENSE](LICENSE).
