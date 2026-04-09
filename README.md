# pitchd-rails (Cursor plugin)

A [Cursor](https://cursor.com) plugin with **rules**, **skills**, and **agents** for building **Rails** applications the way we like: grounded in **DHH and 37signals** (omakase, majestic monolith, REST-shaped boundaries, Hotwire-first front ends) with a few **Pitchd-specific** preferences layered on top.

Metadata lives in [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json).

## What’s inside

- **`rules/`** — `.mdc` rules for models, controllers, routes, Hotwire, testing, RuboCop, and more.
- **`skills/`** — Workflows for planning, implementing, and reviewing Rails work (including layer-specific `writing-*` skills).
- **`agents/`** — Subagent definitions for implementation and review passes.

Start with **`rails-omakase-compass`** for philosophy, then **`implementing-pitchd-rails`** and the relevant `writing-*` skills when shipping features.

## Credits

This plugin stands on the shoulders of two excellent Cursor plugin ecosystems:

- **[Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)** (Every) — for strong **planning**, **execution**, and **review** skills and patterns; the **DHH Rails reviewer** persona in particular is a highlight.
- **[Superpowers](https://github.com/obra/superpowers)** — for disciplined **planning** and **execution** workflows.

Thank you to both projects for the ideas and structure that made this plugin possible.

## License

MIT — see the repository license file if present.
