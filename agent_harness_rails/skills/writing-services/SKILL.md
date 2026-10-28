---
name: writing-services
description: >-
  Where application logic lives in Rails without an app/services layer — rich
  models, concerns, model-namespaced POROs, ActiveModel form objects, jobs.
  Use when deciding where behaviour belongs, or when the user mentions
  services, service objects, POROs, forms, jobs, operations, interactors, or
  use cases.
---

# Writing Services (The Rails Way)

<objective>
Rails has no service layer. Business logic belongs on models. When an operation
outgrows a single model method, extract to a PORO namespaced under the primary
model, a form object, or a job — never to `app/services/`. Opinionated Rails
best practice: rich domain models, minimal indirection, objects that represent
real concepts.
</objective>

## Process

1. Read **`agent_harness_rails/rules/services.mdc`** — the normative canon:
   the decision tree, where each kind of logic lives, PORO and form-object
   rules, naming and placement, anti-patterns, and the verification checklist.

2. For the task at hand, read the matching section of
   [references/patterns.md](references/patterns.md):

| Task | Section |
|------|---------|
| Deciding where logic lives | § Decision Tree (worked examples) |
| Shared behaviour across models | § Concerns |
| Extracting a complex model method | § POROs |
| Multi-model form | § Form Objects |
| Async processing | § Jobs as the Async Layer |
| External API wrapper | § External Integrations |
| Data import / export | § Bulk Operations |
| Refactoring existing `app/services/` code | § Migration Guide |
| Exceptions and outcomes | § Error Handling |
| Code review | All of the above, against the rule's conventions |

3. Before finishing, run the verification checklist in
   **`agent_harness_rails/rules/services.mdc`**.
