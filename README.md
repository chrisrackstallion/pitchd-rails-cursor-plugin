# rails-agent-harness

Rails conventions for coding agents — **rules**, **skills**, and **agent definitions** for building **Rails** applications the way we like: grounded in **DHH and 37signals** (omakase, majestic monolith, REST-shaped boundaries, Hotwire-first front ends).

Ships as a gem that **vendors itself into your app**, so [Cursor](https://cursor.com) and [Claude Code](https://claude.com/claude-code) both read the same files from the project directory alone. No editor plugin to install, nothing outside the repo, nothing per-machine.

## Install

```ruby
# Gemfile
group :development do
  gem "rails-agent-harness", require: false
end
```

```bash
bundle install
bundle exec rails-agent-harness install
```

That vendors the harness into `rails-agent-harness/` and points each editor directory at it:

```
myapp/
  rails-agent-harness/          # the harness — commit this
    skills/  rules/  agents/
    .manifest.json              # which files the gem owns
  .claude/skills        -> ../rails-agent-harness/skills
  .claude/agents        -> ../rails-agent-harness/agents
  .cursor/skills        -> ../rails-agent-harness/skills
  .cursor/agents        -> ../rails-agent-harness/agents
  .cursor/rules/harness -> ../../rails-agent-harness/rules
```

Commit all of it, links included. A teammate clones the repo and it works — no `bundle` step needed to *use* the harness, only to update it.

### Already have skills, rules, or agents in `.claude/` or `.cursor/`?

`install` **moves them into `rails-agent-harness/` first**, before the symlinks go in. Those directories become links, so anything left in them would be shadowed — and in `--mode=copy`, overwritten. Migration happens for both editors' `skills/` and `agents/`, and for `.cursor/rules/*.mdc`.

You come out ahead: a skill that only Claude Code could see because it lived in `.claude/skills/` is now visible to Cursor too, from the one shared directory.

Migrated files stay **yours** — they aren't recorded in `.manifest.json`, so `update` never touches them. If one of your names collides with a vendored one, `install` refuses and changes nothing rather than picking a winner; rename yours, or delete it to accept the harness version. An identical copy is recognised as such and quietly dropped in favour of the vendored file.

`--no-migrate` opts out, in which case `install` refuses to touch a populated editor directory at all.

| Command | What it does |
| --- | --- |
| `rails-agent-harness install` | migrate any existing editor content, vendor the harness, create the links (idempotent) |
| `rails-agent-harness update` | re-vendor after `bundle update`, reporting what changed |
| `rails-agent-harness check` | verify the vendored harness matches the gem — use in CI |
| `rails-agent-harness root` | print the payload path inside the gem |

On Windows or any filesystem without usable symlinks, pass `--mode=copy` for real directories instead of links.

### Adding your own skills

Put them straight into `rails-agent-harness/skills/` alongside the vendored ones — that's why the directory is named for the harness rather than for us. `install` tracks only the files it owns in `.manifest.json`; anything else it leaves alone, and it refuses to overwrite a file it doesn't own rather than clobbering your work.

Two constraints worth knowing:

- **Keep skills flat.** One level: `skills/<name>/SKILL.md`. Claude Code discovers exactly that shape and does not recurse into subdirectories, so a nested skill is invisible to it even though Cursor would find it.
- **Names are global.** Both editors key on the `name:` in frontmatter, so an app skill can't reuse a vendored name.

### Inheriting the RuboCop config

The gem ships a `rubocop.yml` your app can inherit, so the linter and the harness agree:

```yaml
# .rubocop.yml in your app
inherit_gem:
  rubocop-rails-omakase: rubocop.yml
  rails-agent-harness: rubocop.yml
```

Order matters. The harness config is a **thin layer over omakase**, not a replacement — [`rules/rubocop.mdc`](rails-agent-harness/rules/rubocop.mdc) names `rubocop-rails-omakase` as the ruleset source of truth, so the harness never restates or contradicts its cop settings. It adds `NewCops: enable`, on the principle that a pending cop is a deferred offence.

**The gem does not depend on RuboCop, and shouldn't.** It ships a YAML file; reading it requires nothing. RuboCop and `rubocop-rails-omakase` belong in your app's own Gemfile, at whatever versions you pin — a hard dependency here would force RuboCop into the bundle of every app that installs the harness, including ones that don't lint, and would fight your own version constraint.

Most of what the harness asks for is process rather than configuration — zero offences before work is complete, fix in code, never `# rubocop:disable`, never a `.rubocop_todo.yml`. No config can enforce that; the `running-rubocop` skill and the rule are what hold agents to it.

### Your editor will show the harness twice

Both editors expand a symlinked directory inline in the file tree, so `rails-agent-harness/skills/` and `.claude/skills/` appear as separate copies of the same content. They are one set of files — same inode, edit either path. Nothing to clean up.

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

Use the **`rails-omakase-compass`** skill. It answers whether a direction fits 37signals-shaped Rails — omakase defaults, REST gravity, server-owned truth, majestic monolith — and points you at the right `writing-*` skill for tactical detail. It can also pull from the unofficial 37signals guide via **`referencing-unofficial-37signals-guide`**.

### Refactor an existing test suite
> *"The system specs are too heavy"* / *"Rebalance the article specs to the right layers"*

Use the **`refactoring-rails-specs`** skill. It takes a list of specs (typically bloated system specs), discovers their related request, model, policy, job, mailer, and factory specs, then audits every `it` block against the Five Gates and per-layer ownership defined in `writing-tests`. Each test gets a verdict — **KEEP / MOVE / MERGE / DELETE / REWRITE** — and the work proceeds one resource at a time with coverage preserved and the suite kept green.

### Refactor an existing Stimulus fleet
> *"The Stimulus controllers are a mess"* / *"Half of these do the same thing"*

Use the **`refactoring-stimulus-controllers`** skill. It maps every controller and its `data-*` attachments, scores each against single-responsibility, DOM-derived state, lifecycle cleanup, and cross-controller coupling rules, then assigns a verdict — **KEEP / REWRITE / MERGE / SPLIT / DELETE**. After the structural refactor it ensures each Stimulus behaviour has exactly one canonical system spec on the simplest representative page, per `writing-tests`. Pair with **`writing-javascript`** for fresh-write conventions.

### Keep durable primitives (intent, compilation, evaluations, provenance)
> *"Set up primitives"* / *"Document the billing feature"* / *"Why don't we cap thread depth?"*

The harness maintains **`docs/primitives/`** — one markdown doc per capability holding **intent clauses** (what must be true), **shape** (constraints the code compiles into), an **evaluations map** (which RSpec home proves each clause), and append-only **provenance** (decisions, rejected alternatives, accepted debt). Planning creates and amends intent, execution close-out fills evaluations and provenance, and review checks traceability — so the record stays alive as a side effect of the workflows, not as a chore. One-time setup (tree scaffold + a `compilation.md` interview): **`bootstrapping-primitives`**. Backfills, provenance questions, and health passes: **`maintaining-primitives`**, delegated via **`rails-primitives-maintainer`**. Structure rules: **`rails-agent-harness/rules/primitives.mdc`**.

---

New here? Start with **`rails-omakase-compass`** to understand the philosophy, then reach for the workflow skills above.

## What's inside

- **`rails-agent-harness/rules/`** — `.mdc` rules for models, controllers, routes, Hotwire, testing, RuboCop, and more. Cursor attaches them by glob; skills open them by path.
- **`rails-agent-harness/skills/`** — Workflows for planning, implementing, and reviewing Rails work, including layer-specific `writing-*` skills.
- **`rails-agent-harness/agents/`** — Subagent definitions for implementation, review, query, and primitives maintenance.

Every internal reference is written in one canonical form — `rails-agent-harness/rules/models.mdc` — which resolves identically from this repo's root and from a consuming app's root. `bin/check-references` enforces that in CI, so a mistyped path fails the build instead of failing silently inside an agent.

## Credits

This harness stands on the shoulders of two excellent Cursor plugin ecosystems, one reference guide, and one book:

- **Chad Fowler** and his book **[Regenerative Software](https://www.linkedin.com/posts/fowlerchad_im-genuinely-excited-to-share-the-early-share-7488974712543277056-iRQi/)** — the inspiration for the **primitives** tree. Durable intent, the constraints code compiles into, evaluations that prove each clause, and append-only provenance all come from that thinking: the record of *why* outlives any particular implementation.
- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — for strong **planning**, **execution**, and **review** skills and patterns; the **DHH Rails reviewer** persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and **execution** workflows.
- **[37signals-skills](https://github.com/marckohlbrugge/37signals-skills)** (Marc Köhlbrugge, formerly `unofficial-37signals-coding-style-guide`) — the community-maintained guide to 37signals coding patterns, fetched selectively as a supplemental reference.

Thank you to all four for the ideas and structure that made this harness possible.

## License

MIT — see [LICENSE](LICENSE).
