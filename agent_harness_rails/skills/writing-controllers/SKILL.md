---
name: writing-controllers
description: >-
  Write Rails controllers — thin CRUD controllers, REST-mapped resources,
  redirect-first Hotwire responses, concerns for shared behaviour, strong
  parameters with params.expect. Use when creating controllers, adding
  actions, extracting concerns, handling Turbo responses, or when the user
  mentions controllers, actions, strong parameters, or REST routing.
---

# Writing Rails Controllers

**Announce:** "I'm using the writing-controllers skill."

<objective>
Write controllers that are thin orchestrators — they receive a request,
delegate to the model, and respond. Every custom action maps to CRUD on a
new resource. Responses use the simplest Turbo mechanism that works:
full-page redirect first, then frames, then streams. Follow opinionated
Rails best practice: REST purity, rich models, vanilla controller code, and
clarity over cleverness.
</objective>

The rules — structure skeleton, response hierarchy, anti-patterns, naming,
and the verification checklist — live in
**`agent_harness_rails/rules/controllers.mdc`**. Read it first. Worked
examples and gotchas live in [references/patterns.md](references/patterns.md).

## Routing

| Task | Read |
|------|------|
| New controller | `agent_harness_rails/rules/controllers.mdc`, then `references/patterns.md` |
| New action on existing controller | `references/patterns.md` § REST Mapping — likely needs a new resource |
| Turbo / Hotwire responses | `agent_harness_rails/skills/writing-hotwire/references/patterns.md` (canonical); `references/patterns.md` § Failed Validations |
| Controller concern | `references/patterns.md` § Concerns |
| Strong parameters | `references/patterns.md` § Strong Parameters |
| Authorization | `agent_harness_rails/rules/policies.mdc` (canonical); `agent_harness_rails/skills/writing-policies/references/patterns.md` for worked examples |
| Error handling | `references/patterns.md` § Error Handling |
| Code review | `agent_harness_rails/rules/controllers.mdc` § Anti-Patterns and § Verification, plus all references |
