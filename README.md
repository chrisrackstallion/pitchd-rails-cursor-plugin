# pitchd-rails (Cursor + Claude Code plugin)

**Rules, skills, and agents for building Rails the vanilla way — extracted from and used daily
to build [Pitch'd](https://pitchd.ai), a production Rails SaaS — enforced by a
plan → implement → review agent pipeline that ships with the plugin.**

## Why these rules exist

Every AI coding assistant can write Rails. Very few write *your* Rails. Left to its training
distribution, a model produces the statistical average of every Rails codebase it has seen:
service objects wrapping one `update!`, `post :publish` member routes, boolean soup, a system
spec for every assertion. None of it is wrong, exactly. All of it is somebody else's taste.

This plugin encodes one specific, coherent position — the vanilla Rails of DHH and 37signals
(omakase defaults, majestic monolith, REST-shaped boundaries, Hotwire-first, server-owned
truth) — precisely enough that an agent can *apply* it and a second agent can *enforce* it:

- **Rich domain models, no service layer.** Business logic lives on models, concerns,
  noun-shaped POROs, form objects, and jobs. `rules/services.mdc` exists to fire the moment an
  agent reaches for `app/services/` — and to say where the logic actually goes.
- **State as records, not booleans.** "Who archived this and when?" is a child record whose
  existence *is* the state — not `archived` + `archived_at` + `archived_by` columns. The rules
  encode the full decision ladder (enum → state record → history table → state-machine gem).
- **Everything maps to CRUD**, consistently across four layers: routes
  (`resource :closure`), controllers (`Cards::ClosuresController#create`), policies
  (`Cards::ClosurePolicy#create?` — custom verb methods are banned), and naming.
- **Tests with a budget.** System specs are the backbone, not the coverage: Five Gates every
  system spec must pass, a numeric per-resource budget, and an "each behaviour has one home"
  ownership matrix across model/request/policy/system layers.
- **Boring over clever, and documented exceptions.** When convention is violated, the plan or
  PR carries a one-line why.

These aren't aspirations collected from blog posts. They're the working conventions of a
production Rails 8 app, extracted into rules when they proved themselves and revised when the
pipeline's own review loop exposed gaps (see the git history — the rules are downstream of
real usage).

## The stack: declared, not apologised for

The architecture rules are vanilla Rails. The tooling is what we actually ship with:

- **RSpec + FactoryBot + Capybara** — the testing *philosophy* (system specs as backbone, real
  objects, behaviour over implementation) is DHH's; the tooling is an adaptation for teams
  that prefer RSpec. The rules say this out loud rather than pretending Minitest.
- **Pundit** — one policy per model, CRUD methods only, `authorize` in every action,
  `verify_authorized` as the safety net. DHH would hand-roll it; we think ~300 lines of
  convention earns its dependency.
- **Hotwire (Turbo + Stimulus), Tailwind, Solid Queue, Postgres** — omakase where omakase.

Yes, we see the irony of a vanilla-Rails plugin with non-vanilla test and auth tooling. The
principle is *real rules from a real app* — we ship what we battle-test, not configurable
variants of things we don't use. The directory structure can accommodate community variants
(Minitest, other authorization layers) if contributors battle-test them.

**Scope note:** rules ship when they've earned it in production. Caching (fragment/russian-doll,
Solid Cache), Active Storage, Action Text, and AI-feature patterns (pgvector et al.) are on the
bench until we'd defend them line by line.

## Portable vs. stack-specific

If you don't share our tooling, the architectural core still applies:

| Portable (any Rails stack) | Stack-specific (our choices) |
|---|---|
| `rules/models.mdc` — rich models, state-as-records, constraints over validations | `rules/testing.mdc` + `skills/writing-tests` — RSpec, FactoryBot, spec-layer budget |
| `rules/services.mdc` — where logic lives without a service layer | `rules/policies.mdc` + `skills/writing-policies` — Pundit |
| `rules/controllers.mdc`, `rules/routes.mdc` — CRUD mapping, REST gravity | `rules/css-tailwind.mdc` — Tailwind the Rails way |
| `rules/naming.mdc` — domain verbs, state nouns, schema naming | `rules/rubocop.mdc` — zero-offence gate, no disables |
| `rules/hotwire.mdc`, `rules/views.mdc`, `rules/javascript.mdc` — server-owned truth, response hierarchy | parts of `rules/jobs.mdc` — Solid Queue specifics |
| `rules/migrations.mdc`, `rules/jobs.mdc` (core), `rules/i18n.mdc`, `rules/mailers.mdc` | |
| `skills/rails-omakase-compass` — the decision lens all of it hangs off | |

## The pipeline: how the rules are enforced, not just stated

A 17,000-line convention set is useless if it depends on a model attending to all of it at
once. The plugin doesn't. It's structured as a **four-role pipeline** where every role loads
the same rules, scoped to what it's touching — and implementation and review run as **isolated
subagents** with no shared chat context:

```
 spec ──▶ PLAN ──▶ plan review ──▶ ORCHESTRATE ──▶ IMPLEMENT ──▶ REVIEW ──▶ user sign-off
          (skill)  (reviewer agent,  (skill: no app   (subagent)     (subagent, readonly)
                    2-pass loop)      code, delegates      ▲               │
                                      task by task)        └── fix pass ◀──┘
                                                            loops until Approved
```

1. **Plan** — `writing-pitchd-rails-plans` turns a spec into a checklisted plan: exact paths,
   real Ruby, RSpec commands, REST-shaped decomposition. A hard requirements gate runs before
   drafting; the **reviewer agent** then reviews the plan itself (philosophy first, tactics
   second) before any code exists.
2. **Orchestrate** — `executing-pitchd-rails-plan` runs the plan but writes no application
   code. It delegates each task and carries context between isolated agents.
3. **Implement** — `pitchd-rails-implementor` (subagent, fresh context) has a hard gate: *do
   not write code for a layer before reading that layer's rule and skill in this session.*
   Rules also attach by glob to the files being touched. Plugin rules beat existing
   application patterns — with an escalation path (`NEEDS_CONTEXT`) instead of silent
   compliance when the surrounding code makes that impossible.
4. **Review** — `pitchd-rails-reviewer` (subagent, readonly, fresh context) re-derives
   violations *from the rules*: it must open the cited code, re-read the rule it's citing,
   attach a confidence score, and drop anything it can't verify. `Issues found` loops back to
   the implementor, scoped to what changed, until `Approved`.

The claim is deliberately not "the model remembers everything." It's **"violations don't
survive the loop."** The reviewer catches real drift from the implementor in daily use — and
what it catches feeds back into the rules.

Two more agents ship alongside: `pitchd-rails-query` (Q&A over the conventions — "how should I
handle this?" answered with rule citations) and `pitchd-rails-wiki-maintainer` (optional
compounding-knowledge wiki under `docs/llm-wiki/`).

## Receipts

Don't take the claims on faith — [`docs/receipts/`](docs/receipts/) contains reproducible
demonstrations with full prompts and unedited output:

- **[Same prompt, with and without the rules](docs/receipts/02-after-with-rules.md)** — the
  baseline (no rules) produces competent, mainstream Rails: timestamp+FK columns,
  `patch :archive` member routes, custom policy verbs. With the rules loaded, the same model
  produces an `Archival` state record, a `Projects::ArchivalsController` noun resource, and a
  CRUD-only policy — every decision cited to the rule that drove it.
- **[The reviewer catching violations](docs/receipts/03-review-catch.md)** — the reviewer
  agent's unedited report on the baseline: 14 findings, each citing the exact rule section,
  with confidence scores and verification notes.
- **[A generalisation test](docs/receipts/04-generalisation-test.md)** — a feature the rules
  never mention. The agent transfers the principles (state record, singleton noun resource, a
  DB-level at-most-one-row constraint) instead of pattern-matching examples.

## Installing in Cursor

Once listed on the Cursor Marketplace, install **Pitchd Rails** from the in-app plugin
marketplace.

Until then, use it from a local checkout: clone this repo and open it in (or add it to) your
workspace — Cursor reads the `.cursor-plugin` manifest and discovers `rules/`, `skills/`, and
`agents/` from the repo root. The repo passes the official
[cursor/plugin-template](https://github.com/cursor/plugin-template) validation
(`node scripts/validate-template.mjs`).

## Installing in Claude Code

Clone this repo locally, then from any Claude Code session:

```
/plugin marketplace add /path/to/pitchd-rails-cursor-plugin
/plugin install pitchd-rails-cursor-plugin@pitchd-rails
```

This adds the local checkout as a marketplace (via
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)) and installs the plugin
from it — `skills/` and `agents/` are auto-discovered, so the workflows below work the same way
they do in Cursor. Pull the repo to pick up updates, then run
`/plugin marketplace update pitchd-rails` (or reinstall) to refresh.

Cursor metadata lives in [`.cursor-plugin/`](.cursor-plugin/); Claude Code metadata in
[`.claude-plugin/`](.claude-plugin/). Both manifests point at the same `skills/`, `agents/`,
and `rules/` directories — no duplication.

## What you can do

### Write a plan
> *"Write a plan for adding comment threads to posts"*

Uses **`writing-pitchd-rails-plans`**: a spec or feature description becomes a checklisted
implementation plan — exact file paths, real Ruby snippets, RSpec commands, REST-shaped
decomposition. A philosophy check and a tactical pass run before you see the final plan.

### Execute a plan
> *"Execute the plan"*

Uses **`executing-pitchd-rails-plan`**: an orchestrator delegates each task to
`pitchd-rails-implementor`, runs `pitchd-rails-reviewer` after each task, and loops on
feedback until every item is Approved.

### Review existing code
> *"Review this PR"* / *"Review the code I just wrote"*

Uses **`reviewing-pitchd-rails`**: a two-layer review — **philosophy** (is this the right kind
of Rails solution?) via `rails-omakase-compass`, then **tactics** (is it implemented
correctly?) via the relevant `writing-*` skills and rules. Implementation reviews also check
the **surroundings** — pre-existing code in touched files — flagging quick wins and deferred
follow-ups.

### Query for Rails best practice
> *"How should I handle this in Rails?"* / *"What's the right pattern for background jobs here?"*

Uses **`rails-omakase-compass`** (and the `pitchd-rails-query` agent): answers whether a
direction fits 37signals-shaped Rails and points at the right `writing-*` skill for tactical
detail, with rule citations.

### Refactor an existing test suite
> *"The system specs are too heavy"* / *"Rebalance the article specs to the right layers"*

Uses **`refactoring-rails-specs`**: audits every `it` block against the Five Gates and
per-layer ownership, hands each test a verdict — **KEEP / MOVE / MERGE / DELETE / REWRITE** —
and proceeds one resource at a time with the suite kept green.

### Refactor an existing Stimulus fleet
> *"The Stimulus controllers are a mess"* / *"Half of these do the same thing"*

Uses **`refactoring-stimulus-controllers`**: maps every controller and its `data-*`
attachments, scores each against single-responsibility, DOM-derived state, lifecycle cleanup,
and coupling rules, then assigns verdicts and rebalances the canonical system specs.

### Maintain a compounding LLM wiki
> *"Ingest this article into our wiki"* / *"Lint the knowledge base for stale links"*

Uses **`maintaining-llm-wiki`** with the `pitchd-rails-wiki-maintainer` agent: a git-backed,
agent-maintained markdown graph under `docs/llm-wiki/` — boring defaults first (index + grep).

---

New here? Start with **`rails-omakase-compass`** to understand the philosophy, then reach for
the workflow skills above.

## What's inside

- **`rules/`** — 17 `.mdc` rules (~1,800 lines): models, controllers, routes, policies,
  services, testing, Hotwire, views, JS, CSS/Tailwind, i18n, mailers, jobs, migrations,
  naming, RuboCop. Glob-scoped so they attach to the files being touched.
- **`skills/`** — 28 skills (~15,000 lines with references): the workflow skills above,
  layer-specific `writing-*` skills with `references/patterns.md` deep-dives, the compass, and
  two fetch-based reference skills (Rails guides, the unofficial 37signals guide) with a
  strict no-fetch-no-citation rule. **`resolving-plugin-root`** is a small internal skill that
  makes paths resolve in both Cursor and Claude Code installs.
- **`agents/`** — 4 subagent definitions: `pitchd-rails-implementor`, `pitchd-rails-reviewer`,
  `pitchd-rails-query`, `pitchd-rails-wiki-maintainer`.
- **`docs/receipts/`** — the reproducible demonstrations linked above.

## Credits

This plugin stands on the shoulders of two excellent Cursor plugin ecosystems and one
reference guide:

- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every)
  — for strong **planning**, **execution**, and **review** skills and patterns; the **DHH
  Rails reviewer** persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and
  **execution** workflows.
- **[37signals-skills](https://github.com/marckohlbrugge/37signals-skills)** (Marc Köhlbrugge,
  formerly `unofficial-37signals-coding-style-guide`) — the community-maintained guide to
  37signals coding patterns, fetched selectively as a supplemental reference.

Thank you to all three projects for the ideas and structure that made this plugin possible.

## License

MIT — see [LICENSE](LICENSE).
