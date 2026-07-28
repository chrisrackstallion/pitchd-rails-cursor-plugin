# pitchd-rails (Cursor + Claude Code plugin)

A plugin for [Cursor](https://cursor.com) and [Claude Code](https://claude.com/claude-code) with **rules**, **skills**, and **agents** for building **Rails** applications the way we like: grounded in **DHH and 37signals** (omakase, majestic monolith, REST-shaped boundaries, Hotwire-first front ends) with a few **Pitchd-specific** preferences layered on top.

Cursor metadata lives in [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json); Claude Code metadata lives in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json). Both manifests point at the same `skills/`, `agents/`, and `rules/` directories — there's no duplication between the two.

## Installing in Claude Code

Clone this repo locally, then from any Claude Code session:

```
/plugin marketplace add /path/to/pitchd-rails-cursor-plugin
/plugin install pitchd-rails-cursor-plugin@pitchd-rails
```

This adds the local checkout as a marketplace (via [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)) and installs the plugin from it — `skills/` and `agents/` are auto-discovered, so the workflows below work the same way they do in Cursor. Pull the repo to pick up updates, then run `/plugin marketplace update pitchd-rails` (or reinstall) to refresh.

## What you can do

### Write a plan
> *"Write a plan for adding comment threads to posts"*

Use the **`writing-pitchd-rails-plans`** skill. It turns a spec or feature description into a checklisted implementation plan — exact file paths, real Ruby snippets, RSpec commands, and REST-shaped decomposition. A philosophy check and a tactical pass run before you see the final plan.

### Execute a plan
> *"Execute the plan"*

Use the **`executing-pitchd-rails-plan`** skill. An orchestrator delegates each task to a `pitchd-rails-implementor` subagent, then runs `pitchd-rails-reviewer` after each task and loops on feedback until every item is approved.

### Review existing code
> *"Review this PR"* / *"Review the code I just wrote"*

Use the **`reviewing-pitchd-rails`** skill. It runs a two-layer review: **philosophy** (is this the right kind of Rails solution?) via `rails-omakase-compass`, then **tactics** (is it implemented correctly?) via the relevant `writing-*` skills and rules. During implementation reviews it also checks the **surroundings** — pre-existing code in touched files — flagging quick wins and deferred follow-ups in the same report.

### Query for Rails best practice
> *"How should I handle this in Rails?"* / *"What's the right pattern for background jobs here?"*

Use the **`rails-omakase-compass`** skill. It answers whether a direction fits 37signals-shaped Rails — omakase defaults, REST gravity, server-owned truth, majestic monolith — and points you at the right `writing-*` skill for tactical detail. It can also pull from the unofficial 37signals guide via **`referencing-unofficial-37signals-guide`**.

### Refactor an existing test suite
> *"The system specs are too heavy"* / *"Rebalance the article specs to the right layers"*

Use the **`refactoring-rails-specs`** skill. It takes a list of specs (typically bloated system specs), discovers their related request, model, policy, job, mailer, and factory specs, then audits every `it` block against the Five Gates and per-layer ownership defined in `writing-tests`. Each test gets a verdict — **KEEP / MOVE / MERGE / DELETE / REWRITE** — and the work proceeds one resource at a time with coverage preserved and the suite kept green.

### Refactor an existing Stimulus fleet
> *"The Stimulus controllers are a mess"* / *"Half of these do the same thing"*

Use the **`refactoring-stimulus-controllers`** skill. It maps every controller and its `data-*` attachments, scores each against single-responsibility, DOM-derived state, lifecycle cleanup, and cross-controller coupling rules, then assigns a verdict — **KEEP / REWRITE / MERGE / SPLIT / DELETE**. After the structural refactor it ensures each Stimulus behaviour has exactly one canonical system spec on the simplest representative page, per `writing-tests`. Pair with **`writing-javascript`** for fresh-write conventions.

### Maintain a compounding LLM wiki (Karpathy pattern)
> *"Ingest this article into our wiki"* / *"Lint the knowledge base for stale links"*

Use the **`maintaining-llm-wiki`** skill. It treats **`docs/llm-wiki/`** as a git-backed, agent-maintained markdown graph with immutable **`raw/`** sources, **`index.md`**, **`log.md`**, and a **`SCHEMA.md`** contract — boring defaults first (index + grep), optional local search later. Pair with **`rules/llm-wiki.mdc`** when editing those paths. Delegate focused passes to **`pitchd-rails-wiki-maintainer`**.

---

New here? Start with **`rails-omakase-compass`** to understand the philosophy, then reach for the workflow skills above.

## What's inside

- **`rules/`** — `.mdc` rules for models, controllers, routes, Hotwire, testing, RuboCop, and more.
- **`skills/`** — Workflows for planning, implementing, and reviewing Rails work (including layer-specific `writing-*` skills). **`resolving-plugin-root`** is a small internal skill other skills/agents read first, so `rules/*.mdc` and sibling skill references resolve correctly whether this plugin is loaded by Cursor or installed as a Claude Code plugin.
- **`agents/`** — Subagent definitions for implementation, review, and focused wiki maintenance passes.

## Credits

This plugin stands on the shoulders of two excellent Cursor plugin ecosystems and one reference guide:

- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — for strong **planning**, **execution**, and **review** skills and patterns; the **DHH Rails reviewer** persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and **execution** workflows.
- **[37signals-skills](https://github.com/marckohlbrugge/37signals-skills)** (Marc Köhlbrugge, formerly `unofficial-37signals-coding-style-guide`) — the community-maintained guide to 37signals coding patterns, fetched selectively as a supplemental reference.

Thank you to all three projects for the ideas and structure that made this plugin possible.

## License

MIT — see the repository license file if present.
