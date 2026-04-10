---
name: writing-jobs
description: >-
  Write Rails background jobs following DHH/37signals conventions — thin jobs
  that delegate to model methods, idempotent execution, after_commit timing,
  and retry discipline. Use when writing ActiveJob subclasses, scheduling
  background work, handling async processing, or when the user mentions jobs,
  queues, background processing, perform_later, or ActiveJob.
---

# Writing Rails Jobs

<objective>
Jobs are the async service layer Rails provides. They are thin orchestrators —
the same principle that governs controllers applies here: delegate domain logic
to models, keep the job itself short, and treat the queue as a delivery
mechanism, not a place to build features. A job that reaches directly into
business logic belongs on the model; a job that coordinates a model verb
asynchronously is exactly right.
</objective>

## Process

### 1. Determine What You're Building

| Task | Action |
|------|--------|
| New background job | Read `references/patterns.md` § Job Structure |
| Async email | Use `deliver_later` — see `rules/mailers.mdc`; the mailer IS the job |
| Retry strategy | Read `references/patterns.md` § Error Handling |
| Scheduling / recurring work | Read `references/patterns.md` § Scheduling |
| Job with complex argument passing | Read `references/patterns.md` § Arguments |
| Writing job specs | Read `skills/writing-tests/references/support-specs.md` § Job Specs |
| Code review | Read all references, review against conventions |

### 2. Job Structure

Every job follows this shape:

```ruby
# app/jobs/notify_subscribers_job.rb
class NotifySubscribersJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    article.notify_subscribers
  end
end
```

Key principles:
- **Inherits `ApplicationJob`** — not `ActiveJob::Base` directly; shared
  configuration (queue adapter, retry defaults) belongs on `ApplicationJob`
- **One verb in `perform`** — the job finds the record and calls a model
  method; domain logic lives on the model
- **Pass IDs, not objects** — ActiveRecord objects are not reliably
  serializable across queue restarts; find the record fresh in `perform`
- **Named by what happens, not what triggers it** — `NotifySubscribersJob`,
  not `ArticlePublishedJob`

### 3. Enqueue Timing — the `after_commit` Rule

Never enqueue a job inside a database transaction. If the transaction rolls
back, the job still runs — against a record that no longer exists or is in
a state the job doesn't expect.

```ruby
# Bad — inside a transaction, job may run before commit or after rollback
def publish(by: Current.user)
  transaction do
    create_publication!(publisher: by)
    NotifySubscribersJob.perform_later(self)  # unsafe
  end
end

# Good — after_commit fires only when the transaction commits
after_create_commit :notify_subscribers_later

private
  def notify_subscribers_later
    NotifySubscribersJob.perform_later(id)
  end
```

Use `after_create_commit`, `after_update_commit`, or `after_commit` callbacks
(or the model method equivalent) to enqueue work. For mailers specifically,
use `deliver_later` from an `after_commit` callback or after the transaction.

### 4. Idempotency

Jobs can be retried — by the queue backend on failure, by a developer manually,
or after a deploy with pending jobs. A job that is safe to run twice is
idempotent. Design for it from the start.

```ruby
# Good — idempotent: find_or_create_by is safe to run again
def perform(invitation_id)
  invitation = Invitation.find(invitation_id)
  return if invitation.accepted?   # guard against duplicate execution
  invitation.send_reminder
end
```

Strategies:
- **Guard clauses** — check the record's current state at the start of
  `perform`; return early if the work is already done
- **Database uniqueness** — unique indexes prevent duplicate records even
  if a job runs twice
- **Idempotency keys** — for external API calls, use the provider's
  idempotency key feature

### 5. Decision Framework

Before writing code, ask these questions:

**"Does this need a job?"**
- Work that happens synchronously in the request and is fast enough → inline
- Work that is slow, external, or should not block the HTTP response → job
- Work that should be retried automatically on failure → job
- A mailer → `deliver_later`; not a custom job wrapping a mailer

**"What should the job be named?"**
- Verb + noun + `Job`: `ProcessPaymentJob`, `SyncInventoryJob`, `SendDigestJob`
- Named after what the job *does*, not what caused it

**"What queue?"**
- `default` for ordinary background work
- `critical` for user-facing work that needs low latency (password resets,
  transactional email)
- `mailers` if your configuration separates mail delivery
- `imports` or `exports` for bulk data operations that are slow and can wait
- Match queue names to your worker configuration — unused queues are wasted
  configuration

**"How do I handle failure?"**
- Transient error (network timeout, external API down) → `retry_on`
- Permanent error (record not found, invalid state) → `discard_on`
- Unknown — default retries from `ApplicationJob` are usually sufficient

### 6. Anti-Patterns

| Anti-Pattern | Instead |
|-------------|---------|
| Domain logic in `perform` | Call a model method from `perform` |
| Passing ActiveRecord objects as arguments | Pass IDs; find records in `perform` |
| `perform_now` in production code | `perform_later` — `perform_now` blocks the request |
| Enqueueing inside a transaction | `after_commit` callback or after `save!` |
| One giant job that does everything | Small focused jobs; orchestrate by chaining or enqueueing more jobs |
| God job replacing a service layer | Model methods handle domain logic; job calls them |
| Jobs for synchronous fast work | Inline in the controller or model |
| Wrapping `deliver_later` in a job | Call `deliver_later` directly |
| Silently rescuing all exceptions | `retry_on` and `discard_on` with specific error classes |
| No idempotency consideration | Guard with a state check at the top of `perform` |

### 7. Naming Conventions

| Thing | Convention | Examples |
|-------|-----------|----------|
| Job class | `VerbNounJob` | `NotifySubscribersJob`, `ProcessPaymentJob` |
| Job file | `verb_noun_job.rb` | `notify_subscribers_job.rb` |
| `perform` arguments | IDs or primitives | `(user_id)`, `(article_id, options = {})` |
| Queue names | Lowercase noun | `:default`, `:critical`, `:mailers`, `:imports` |

### 8. Verification

Before finishing, verify:

- [ ] Job inherits `ApplicationJob`, not `ActiveJob::Base`
- [ ] `perform` receives IDs or primitives, not ActiveRecord objects
- [ ] Domain logic lives on the model, not in `perform`
- [ ] Job is not enqueued inside a database transaction — use `after_commit`
- [ ] Job is idempotent — safe to run twice (guard clause or database uniqueness)
- [ ] `retry_on` for transient errors, `discard_on` for permanent failures
- [ ] Queue name matches worker configuration
- [ ] Job spec uses `have_enqueued_job` for callers, `perform_enqueued_jobs` for the job itself
- [ ] No `perform_now` in production paths

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
