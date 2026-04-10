# pitchd-rails (Cursor plugin)

A [Cursor](https://cursor.com) plugin with **rules**, **skills**, and **agents** for building **Rails** applications the way we like: grounded in **DHH and 37signals** (omakase, majestic monolith, REST-shaped boundaries, Hotwire-first front ends) with a few **Pitchd-specific** preferences layered on top.

Metadata lives in [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json).

## What you can do

### Write a plan
> *"Write a plan for adding comment threads to posts"*

Use the **`writing-plans`** skill. It turns a spec or feature description into a checklisted implementation plan — exact file paths, real Ruby snippets, RSpec commands, and REST-shaped decomposition. A philosophy check and a tactical pass run before you see the final plan.

### Execute a plan
> *"Execute the plan"*

Use the **`executing-pitchd-rails-plan`** skill. An orchestrator delegates each task to a `pitchd-rails-implementor` subagent, then runs `pitchd-rails-reviewer` after each task and loops on feedback until every item is approved.

### Review existing code
> *"Review this PR"* / *"Review the code I just wrote"*

Use the **`reviewing-pitchd-rails`** skill. It runs a two-layer review: **philosophy** (is this the right kind of Rails solution?) via `rails-omakase-compass`, then **tactics** (is it implemented correctly?) via the relevant `writing-*` skills and rules.

You can also ask it to review the **surroundings** of files you touched — `reviewing-touched-surroundings` will flag issues in adjacent code worth cleaning up before merging.

### Query for Rails best practice
> *"How should I handle this in Rails?"* / *"What's the right pattern for background jobs here?"*

Use the **`rails-omakase-compass`** skill. It answers whether a direction fits 37signals-shaped Rails — omakase defaults, REST gravity, server-owned truth, majestic monolith — and points you at the right `writing-*` skill for tactical detail. It can also pull from the unofficial 37signals guide via **`referencing-unofficial-37signals-guide`**.

---

New here? Start with **`rails-omakase-compass`** to understand the philosophy, then reach for the workflow skills above.

## What's inside

- **`rules/`** — `.mdc` rules for models, controllers, routes, Hotwire, testing, RuboCop, and more.
- **`skills/`** — Workflows for planning, implementing, and reviewing Rails work (including layer-specific `writing-*` skills).
- **`agents/`** — Subagent definitions for implementation and review passes.

## Credits

This plugin stands on the shoulders of two excellent Cursor plugin ecosystems:

- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — for strong **planning**, **execution**, and **review** skills and patterns; the **DHH Rails reviewer** persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and **execution** workflows.

Thank you to both projects for the ideas and structure that made this plugin possible.

## License

MIT — see the repository license file if present.
