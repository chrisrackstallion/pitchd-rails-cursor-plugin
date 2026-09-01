---
name: writing-jobs
description: >-
  Write Rails background jobs following opinionated Rails best practice — thin jobs
  that delegate to model methods, idempotent execution, after_commit timing,
  and retry discipline. Use when writing ActiveJob subclasses, scheduling
  background work, handling async processing, or when the user mentions jobs,
  queues, background processing, perform_later, or ActiveJob.
---

# Writing Rails Jobs

<objective>
Jobs are the async service layer Rails provides: thin orchestrators that
delegate domain logic to models. The queue is a delivery mechanism, not a
place to build features — a job coordinates a model verb asynchronously;
business logic in the job itself belongs on the model.
</objective>

The conventions — job shape, ID arguments, `after_commit` enqueueing,
idempotency, retry discipline, queue choice, naming, anti-patterns, and the
verification checklist — live in **`agent_harness_rails/rules/jobs.mdc`**.
Read it first, then route by task:

| Task | Action |
|------|--------|
| New background job | Read `references/patterns.md` § Job Structure |
| Async email | Use `deliver_later` — see `agent_harness_rails/rules/mailers.mdc`; the mailer IS the job |
| Retry strategy | Read `references/patterns.md` § Error Handling |
| Scheduling / recurring work | Read `references/patterns.md` § Scheduling |
| Job with complex argument passing | Read `references/patterns.md` § Arguments |
| Idempotent execution | Read `references/patterns.md` § Idempotency |
| Writing job specs | Read `agent_harness_rails/skills/writing-tests/references/support-specs.md` § Job Specs |
| Code review | Read `agent_harness_rails/rules/jobs.mdc` and all references, review against conventions |

## References

For detailed patterns and examples, see [references/patterns.md](references/patterns.md).
