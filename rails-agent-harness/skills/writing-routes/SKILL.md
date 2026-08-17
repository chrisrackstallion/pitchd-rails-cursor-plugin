---
name: writing-routes
description: >-
  Declare Rails routes in DHH/37signals style — REST-first resources, shallow
  nesting, clear path helpers, constraints for wiring not auth, boring
  routes.rb. Use when editing config/routes.rb, adding resources, namespaces,
  member/collection routes, API boundaries, or when the user mentions routing,
  rails routes, paths, or URL design.
---

# Writing Rails Routes

<objective>
Shape URLs and `config/routes.rb` so they read like a table of contents:
REST as default, shallow nesting where parents scope identity, member vs
collection used correctly, constraints for real routing predicates only,
and no clever meta-programming that hides the map of the app. Follow
DHH/37signals instincts — boring routes, predictable helpers, monolith-friendly
clarity.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New resource | Read `references/patterns.md` § REST Resources |
| Nested routes | Read `references/patterns.md` § Shallow Nesting |
| Custom action / verb on URL | Read `references/patterns.md` § Custom Actions vs New Resources; align with writing-controllers REST mapping |
| Singleton (`session`, `account`) | Read `references/patterns.md` § Singleton `resource` |
| API namespace | Read `references/patterns.md` § API vs HTML |
| Format / host / subdomain | Read `references/patterns.md` § Constraints |
| Redirects and legacy URLs | Read `references/patterns.md` § Redirects |
| Code review | Read all references, run PR checklist below |

### 2. Decision Hints

**Should this be nested?** Nest when the child does not make sense without the parent in the URL for `index` / `create`. Use `shallow: true` so member routes drop the parent prefix.

**Member or collection?** One record → `member`; the collection → `collection`. Otherwise consider `index` with query params or a new resource.

**Non-RESTful route?** Allowed when rare, named, and honest — not as a junk drawer. Prefer new resources + CRUD (see writing-controllers) when the custom verb keeps multiplying.

### 3. Verification

Before finishing, verify:

- [ ] `rails routes` output is scannable — no unexplained duplication of huge blocks
- [ ] Nesting is at most one parent deep for member routes, or shallowing is used
- [ ] `only` / `except` match real controller actions
- [ ] Path helpers read clearly in views (`*_path` / `*_url` — no ambiguous names)
- [ ] `constraints` are for format/host/subdomain — not user permissions
- [ ] No meta-programmed route tables that obscure `rails routes`
- [ ] Custom routes are justified in a comment or PR (why not standard REST?)

## References

For examples, edge cases, and testing notes, see [references/patterns.md](references/patterns.md).
