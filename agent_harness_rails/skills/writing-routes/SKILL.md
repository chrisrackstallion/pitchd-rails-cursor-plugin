---
name: writing-routes
description: >-
  Declare Rails routes — REST-first resources, shallow nesting, clear path
  helpers, constraints for wiring not auth, boring routes.rb. Use when editing
  config/routes.rb, adding resources, namespaces, member/collection routes,
  API boundaries, or when the user mentions routing, rails routes, paths, or
  URL design.
---

# Writing Rails Routes

<objective>
Shape URLs and `config/routes.rb` so they read like a table of contents:
REST as default, boring routes, predictable helpers, monolith-friendly
clarity.
</objective>

The rules — REST vocabulary, shallow nesting, member vs collection,
constraints, anti-patterns, and the verification checklist — live in
**`agent_harness_rails/rules/routes.mdc`**. Read it first.

## Routing

| Task | Read |
|------|------|
| New resource | `references/patterns.md` § REST Resources |
| Nested routes | `references/patterns.md` § Shallow Nesting |
| Custom action / verb on URL | `references/patterns.md` § Custom Actions vs New Resources; align with writing-controllers REST mapping |
| Singleton (`session`, `account`) | `references/patterns.md` § Singleton `resource` |
| API namespace | `references/patterns.md` § API vs HTML |
| Format / host / subdomain | `references/patterns.md` § Constraints |
| Admin areas, module grouping | `references/patterns.md` § Namespaces and `scope` |
| Helper names, slugs | `references/patterns.md` § Helpers: `as`, `param` |
| Redirects and legacy URLs | `references/patterns.md` § Redirects and Legacy Routes |
| Code review | `agent_harness_rails/rules/routes.mdc` § Verification |
