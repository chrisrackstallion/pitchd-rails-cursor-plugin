---
name: writing-naming-conventions
description: >-
  Name files, classes, methods, columns, routes, and variables following Rails
  conventions and DHH/37signals domain language. Use when creating new files or
  classes, renaming anything, reviewing naming decisions, or when the user asks
  what to call something in a Rails app. Covers every layer: models, concerns,
  controllers, jobs, mailers, policies, database, routes, tests, and locals.
---

# Writing Naming Conventions

<objective>
Names are load-bearing. A good name makes the codebase read like prose and
eliminates a comment. Use Rails idioms for structure, domain language for
behaviour, and invent nothing. When in doubt, pick the boring name — it is
almost always correct. The only names worth agonising over are domain verbs on
models: those should read like English sentences when called.
</objective>

## Process

### 1. Identify the Layer

Look up the convention in `rules/naming.mdc` for the layer you are working in:

| Layer | Section in `rules/naming.mdc` |
|-------|-------------------------------|
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

### 2. Ask: What Does This Thing Do in the Domain?

Before reaching for a generic term, name the domain action or concept:

- A method that marks an article as visible → `publish`, not `update_published_status`
- A concern giving a model lock capability → `Lockable`, not `LockingBehavior`
- A state record representing a project being closed → `Closure`, not `ClosedState`
- A job that sends a digest to watchers → `NotifyWatchersJob`, not `DigestNotificationJob`
- A column tracking when something expired → `expired_at`, not `expiry_time`

The domain answer is almost always a clearer name than the technical description.

### 3. Rails Convention Check

Rails has a name for most things. Use it — do not add suffixes Rails does not expect, and do not drop the ones it does:

- **Add:** `Controller`, `Job`, `Mailer`, `Policy`, `Scope` (Pundit), `_spec`, `_path`
- **Never add:** `Model`, `Class`, `Manager`, `Handler`, `Helper` (on non-helpers), `Service`
- **Singular vs plural:** models and form objects are singular; controllers, tables, and factory names are plural (as symbols, singular: `:article`)
- **Casing:** classes PascalCase, methods and columns snake_case, constants SCREAMING_SNAKE_CASE, Stimulus identifiers kebab-case

When Rails convention and domain language conflict, **Rails convention wins for class and file names**; **domain language wins for method and variable names**.

### 4. Common Decision Points

**Concern or model method?**
Genuine reuse across two or more models → concern (adjective: `Publishable`).
Logic on one model → model method (domain verb: `publish`).

**Domain verb or predicate?**
Changes state → verb (`publish`, `close`, `lock`).
Reads state → predicate with `?` (`published?`, `closed?`, `locked?`).

**Bang or not?**
Default to non-bang for domain verbs — they are the normal path and propagate exceptions from inner `create!` / `update!` naturally.
Add a bang only when you also offer a non-raising alternative (`lock` returns false on failure; `lock!` raises).

**Semantic foreign key or `{model}_id`?**
When the role is generic, use the model name: `user_id`.
When the column encodes a role, use the role: `creator_id`, `approver_id`, `reviewer_id` — even when all three point at the `users` table.

**`status` column?**
Never. Name what it stores: `publication_state`, `review_stage`, `membership_role`.

**`user1` / `user2` in specs?**
Never. Name the role: `author`, `reviewer`, `admin`, `guest`, `member`.

### 5. Anti-Pattern Check

Before finalising any name, check the Anti-Patterns table in `rules/naming.mdc`. Most common traps:

| Trap | Fix |
|------|-----|
| `is_` prefix on a boolean column | Drop it: `active`, not `is_active` |
| `Service` suffix anywhere | Model method or namespaced PORO |
| `execute` / `run` / `do` on a PORO | Domain verb: `complete`, `import`, `transfer` |
| Abbreviations in locals or parameters | Full word: `article`, not `art` |
| Ordinal variables in specs | Role names: `author`, not `user1` |
| `it "should …"` | `it "…"` — no "should" |
| `ConcernBehavior`, `ConcernModule` | Adjective only: `Taggable` |

### 6. Verification

Before finishing, confirm:

- [ ] Class name follows Rails convention for its layer — no extra suffixes, correct plural/singular
- [ ] Methods use domain verbs for state changes; `?` suffix for predicates
- [ ] Boolean columns have no `is_` prefix
- [ ] Concerns are adjectives: `Publishable`, not `PublishingConcern`
- [ ] Database columns are semantic — `_at` for datetimes, `_on` for dates, no generic `status`/`data`/`info`
- [ ] Foreign keys encode the role when the role is specific (`creator_id`, not always `user_id`)
- [ ] Migration name is a descriptive verb phrase: `add_published_at_to_articles`
- [ ] Join table is in alphabetical order: `articles_tags`, not `tags_articles`
- [ ] Spec blocks use domain language: `let(:author)`, `context "when published"`, `it "archives the record"`
- [ ] No abbreviations in locals or block parameters

## Relationship to Other Rules and Skills

| Rule / Skill | Role |
|-------------|------|
| `rules/naming.mdc` | Authoritative naming tables — this skill's reference |
| `rules/models.mdc`, `skills/writing-models` | Domain verbs, concern names, scope names |
| `rules/controllers.mdc`, `skills/writing-controllers` | Action names, REST resource naming |
| `rules/routes.mdc`, `skills/writing-routes` | Resource and helper naming |
| `rules/jobs.mdc`, `skills/writing-jobs` | Job class naming pattern |
| `rules/mailers.mdc`, `skills/writing-mailers` | Mailer class and method naming |
| `rules/policies.mdc`, `skills/writing-policies` | Policy class and permission method naming |
| `rules/testing.mdc`, `skills/writing-tests` | Spec, factory, and example naming |
| `rules/services.mdc` | Why there is no `Service` suffix |
