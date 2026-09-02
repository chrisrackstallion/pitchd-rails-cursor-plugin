---
name: writing-models
description: >-
  Write Rails models — rich domain models, concerns for horizontal behaviour,
  state-as-records, scopes, database constraints, vanilla Rails patterns. Use
  when creating models, adding model methods, extracting concerns, refactoring
  model logic, or when the user mentions models, concerns, scopes, callbacks,
  or domain logic.
---

# Writing Rails Models

<objective>
Write models as rich domain objects that own business logic, express domain
language, and keep controllers thin. Opinionated Rails best practice: concerns
for horizontal behaviour, state tracked as records, database-backed everything,
clarity over cleverness.
</objective>

## Process

1. Read **`agent_harness_rails/rules/models.mdc`** — the normative canon:
   model structure and ordering, the state ladder (enum → state record →
   history → gem), decision framework, naming, anti-patterns, and the
   verification checklist.

2. For the task at hand, read the matching section of
   [references/patterns.md](references/patterns.md):

| Task | Section |
|------|---------|
| New concern | § Concerns |
| State tracking mechanics (migration, state record, concern) | § State as Records |
| Scopes / queries | § Scopes |
| Validations and form objects | § Validations |
| Callbacks | § Callbacks |
| Associations (counter caches, touch chains, strict loading) | § Associations |
| Normalizes, delegated types, enums, tokens, encryption, attachments, broadcasts | § Modern Rails Features |
| POROs | § POROs |
| Errors and transactions | § Error Handling, § Transactions |
| Code review | All of the above, against the rule's conventions |

3. Before finishing, run the verification checklist in
   **`agent_harness_rails/rules/models.mdc`**.
