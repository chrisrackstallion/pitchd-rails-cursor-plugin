---
name: writing-javascript
description: >-
  Write JavaScript in a Rails app the omakase way — importmap-first delivery,
  optional bundling (esbuild, Vite) when justified, focused Stimulus
  controllers under app/javascript/controllers, modern ES module hygiene,
  accessible DOM updates, safe fetching with CSRF, and a clear boundary with
  Turbo/HTML. Opinionated Rails best practice. Use when editing importmap,
  package.json, application.js, Stimulus controllers, shared JS modules, or
  choosing bundling; not for Hotwire/Turbo *behaviour in templates* (see
  writing-hotwire), Tailwind/config/global CSS (see writing-css-tailwind), or
  ERB markup (see writing-views). For rebalancing an existing Stimulus fleet
  (merging, splitting, spec coverage), see refactoring-stimulus-controllers.
---

# Writing JavaScript (Rails Boundary + Quality)

**Announce:** "I'm using the writing-javascript skill."

Keep JavaScript small, focused, and subservient to the Rails app: importmap and Stimulus by default, bundling as an intentional exception, one pipeline per codebase, no client authority over domain state for first-party pages. Beyond the boundary, the code itself must be modern, modular, accessible, and safe.

**The rules — stack choice, scope, boundary, ES module hygiene, Stimulus anatomy, fetching with CSRF, accessibility, performance, anti-patterns, and the verification checklist — live in `agent_harness_rails/rules/javascript.mdc`.** Read it before writing or reviewing JS, and verify against its checklist.

| Task | Read |
|------|------|
| Any JS change — rules and checklist | `agent_harness_rails/rules/javascript.mdc` |
| Importmap pins, bundling setup, file layout, worked Stimulus controller, lifecycle, cross-controller wiring, fetch code | [references/patterns.md](references/patterns.md) |
| Turbo / Stimulus behaviour in templates | `agent_harness_rails/skills/writing-hotwire/SKILL.md` |
| Tailwind config and global CSS | `agent_harness_rails/skills/writing-css-tailwind/SKILL.md` |
| Helpers and ERB markup | `agent_harness_rails/skills/writing-views/SKILL.md` |
| Rebalancing an existing Stimulus fleet, or a fleet without specs | `agent_harness_rails/skills/refactoring-stimulus-controllers/SKILL.md` |
| System specs for JS behaviour (Five Gates, budget) | `agent_harness_rails/skills/writing-tests/references/system-specs.md` |
