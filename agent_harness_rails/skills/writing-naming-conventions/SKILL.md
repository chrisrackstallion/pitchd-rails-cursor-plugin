---
name: writing-naming-conventions
description: >-
  Name files, classes, methods, columns, routes, and variables following Rails
  conventions and opinionated best-practice domain language. Use when creating
  new files or classes, renaming anything, reviewing naming decisions, or when
  the user asks what to call something in a Rails app. Covers every layer:
  models, concerns, controllers, jobs, mailers, policies, database, routes,
  tests, and locals.
---

# Writing Naming Conventions

<objective>
Use Rails idioms for structure, domain language for behaviour, and invent
nothing. When in doubt, pick the boring name. The only names worth agonising
over are domain verbs on models: they should read like English sentences when
called.
</objective>

## Process

Every naming rule — the per-layer tables, suffix and casing rules, tie-breaks,
and the anti-pattern table — lives in **`agent_harness_rails/rules/naming.mdc`**.
Look up the section for the layer you are naming:

| Layer | Section in `agent_harness_rails/rules/naming.mdc` |
|-------|-------------------------------|
| Suffixes, singular vs plural, casing | § Suffixes and Casing |
| Model, concern, scope, domain verb, state record, PORO, form object | § Domain Layer |
| Controller class or action name | § Controllers |
| View template, partial, local variable, Stimulus identifier | § Views and Partials |
| Job class | § Jobs |
| Mailer class or method | § Mailers |
| Policy class or permission method | § Policies |
| Table, column, migration | § Database |
| Route resource, path helper, namespace | § Routes and Helpers |
| Spec file, factory, trait, `let`, `context`, `it` | § Tests and Factories |
| Local variable, block parameter, boolean local | § Variables and Locals |

Before finalising any name, check it against § Anti-Patterns in the same rule.
