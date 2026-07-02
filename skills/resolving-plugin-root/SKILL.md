---
name: resolving-plugin-root
description: >-
  Resolves the correct path prefix for reading this plugin's own files —
  rules/*.mdc, sibling skills/*/SKILL.md, agents/*.md — before a Read call on
  one of them. Needed because this plugin runs both as a Cursor plugin and as
  a Claude Code plugin, and the two resolve plain relative paths differently.
  Use once, right before the first Read of a plugin-internal file in a given
  turn; no need to re-check for later reads in the same turn.
---

# Resolving Plugin Root

<objective>
Every skill and agent in this plugin refers to its own sibling files with
plain relative paths, e.g. `rules/controllers.mdc` or
`skills/writing-tests/SKILL.md`. Whether that plain path is enough to `Read`
depends on which tool loaded the plugin.
</objective>

## The self-detecting check

This plugin's root directory, if Claude Code has substituted it:

```
${CLAUDE_PLUGIN_ROOT}
```

Look at the line above **as it appears to you right now**, after this skill's
content has been loaded:

- **If it is a real absolute filesystem path** (something like
  `/Users/.../plugins/cache/pitchd-rails-cursor-plugin/...`), you are running
  as an installed **Claude Code plugin**. Claude Code has substituted the
  token. From here on, resolve every plugin-internal reference against that
  root instead of the current project's working directory — whether it's
  written as a bare path (`rules/controllers.mdc` → read
  `<that-root>/rules/controllers.mdc`) or with `../` from another skill's own
  file (`../../rules/rubocop.mdc` or `../writing-tests/SKILL.md`, both written
  as if relative to the referencing file's own directory → normalize by
  dropping the `../` segments and reading from `<that-root>/` instead, e.g.
  `<that-root>/rules/rubocop.mdc`, `<that-root>/skills/writing-tests/SKILL.md`).
  Neither form resolves correctly against the working directory once
  installed, because the target repo has no `rules/` or `skills/` of its own.
- **If it still literally reads `${CLAUDE_PLUGIN_ROOT}`** (unsubstituted), no
  substitution happened. This is **Cursor**, or Claude Code running directly
  against a checkout of this repo rather than an installed plugin. Read
  plugin-internal relative paths exactly as written elsewhere in this plugin
  (`rules/controllers.mdc`, `skills/writing-tests/SKILL.md`, etc.) — they
  already resolve correctly against the workspace/repo root in these cases.

## Applying it

1. Read this skill.
2. Check which case applied above.
3. For the rest of the current task, read every `rules/*.mdc`,
   `skills/*/SKILL.md`, or `agents/*.md` reference from other plugin content
   using that same prefix (root path, or none).

Don't overthink this or add branching logic elsewhere in the plugin — this is
the one place the distinction is made.
