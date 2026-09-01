---
name: writing-policies
description: >-
  Write Pundit authorization policies — one policy per model, plain Ruby
  objects, deny-by-default, scoped collections, authorize/policy_scope in
  controllers. Use when creating policies, adding authorization, scoping
  queries by user, or when the user mentions policies, Pundit, authorization,
  permissions, or access control.
---

# Writing Pundit Policies

**Announce:** "I'm using the writing-policies skill."

<objective>
Write policies that answer one question: "can this user perform this action
on this record?" Policies are plain Ruby objects — no DSL, no magic. One
policy per model, one method per controller action, deny by default.
Authorization stays in one predictable place; business rules and state
transitions stay on the model.
</objective>

The rules — why Pundit, policy structure, controller integration, scoping,
verification callbacks, anti-patterns, naming, and the verification
checklist — live in **`agent_harness_rails/rules/policies.mdc`**. Read it
first. Worked examples and gotchas live in
[references/patterns.md](references/patterns.md).

## Routing

| Task | Read |
|------|------|
| New policy for a model | `agent_harness_rails/rules/policies.mdc`, then `references/patterns.md` |
| Adding an action to a policy | `references/patterns.md` § Action Methods |
| Scoping a collection | `references/patterns.md` § Scopes |
| Role-based permissions | `references/patterns.md` § Roles |
| Nested / namespaced resource | `references/patterns.md` § Namespaced Policies |
| Controller integration | `agent_harness_rails/rules/policies.mdc` § Controller Integration; `references/patterns.md` § One Gate, One Home |
| Verification callbacks / skipping | `agent_harness_rails/rules/policies.mdc` § Verification Callbacks; `references/patterns.md` § Skipping Verification |
| Multi-tenant / `pundit_user` shape | `references/patterns.md` § Pundit User |
| Testing a policy | `agent_harness_rails/skills/writing-tests/references/support-specs.md` § Policy Specs |
| Code review | `agent_harness_rails/rules/policies.mdc` § Anti-Patterns and § Verification, plus all references |
