# Job Patterns Reference

Worked mechanics for the conventions in **`agent_harness_rails/rules/jobs.mdc`**.
Where domain logic belongs: **`agent_harness_rails/rules/services.mdc`** and
**`agent_harness_rails/skills/writing-services/SKILL.md`**.

---

## Job Structure

### ApplicationJob defaults

Shared configuration belongs on `ApplicationJob`, not scattered across
individual jobs:

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  # Retry on transient errors automatically
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3

  # Discard jobs for records that no longer exist
  discard_on ActiveJob::DeserializationError
end
```

---

## Arguments

### GlobalID and the ID convention

GlobalID allows passing ActiveRecord objects directly as job arguments — Rails
serializes them automatically. If the record is deleted between enqueueing and
execution, the job raises `ActiveJob::DeserializationError`. The convention is
to pass IDs for explicitness and resilience. As an exception, if you pass an
object directly, ensure `discard_on ActiveJob::DeserializationError` is set on
`ApplicationJob` to prevent queue poisoning when the record is deleted before
the job runs.

### Keyword arguments

For jobs with multiple parameters, use a plain hash or keyword arguments
to keep the `perform` signature readable:

```ruby
def perform(user_id:, role:)
  user = User.find(user_id)
  user.assign_role(role)
end

# Enqueue
AssignRoleJob.perform_later(user_id: user.id, role: "admin")
```

---

## Enqueue Timing

The `_commit` variants for enqueueing after a transaction:

- `after_create_commit` — after a new record is committed
- `after_update_commit` — after an update is committed
- `after_destroy_commit` — after a destroy is committed
- `after_commit` — after any write operation is committed (use when you need
  to react to create, update, or destroy)

### Enqueueing from a controller

When a controller action triggers background work, the model should own the
enqueueing via a callback or domain method — not the controller directly:

```ruby
# Good — controller calls the domain verb; model enqueues the job
def create
  @invitation = Invitation.new(invitation_params)
  authorize @invitation

  if @invitation.save
    redirect_to @invitation, notice: "Invitation sent."
  else
    render :new, status: :unprocessable_content
  end
end

# In the model
after_create_commit :send_invitation_later

private
  def send_invitation_later
    InvitationMailer.with(invitation: self).invite.deliver_later
  end
```

---

## Error Handling

### retry_on

For transient failures — network timeouts, rate limits, temporary service
unavailability — use `retry_on` with a wait strategy:

```ruby
class SyncInventoryJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5
  retry_on RateLimitError, wait: 30.seconds, attempts: 10

  def perform(product_id)
    product = Product.find(product_id)
    product.sync_inventory_from_warehouse
  end
end
```

Wait strategies:
- `:polynomially_longer` — growing backoff (attempts⁴ + jitter); the default choice. Rails 7.1 renamed `:exponentially_longer` to this — the old name is deprecated, don't use it.
- `N.seconds` — fixed interval

### discard_on

For permanent failures — validation errors, records that no longer exist,
states the job cannot handle — use `discard_on` to prevent retrying:

```ruby
class ProcessPaymentJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound
  discard_on Payment::AlreadyProcessed

  def perform(payment_id)
    payment = Payment.find(payment_id)
    raise Payment::AlreadyProcessed if payment.processed?
    payment.process!
  end
end
```

### Callbacks on failure

For alerting, logging, or cleanup after final failure:

```ruby
class ProcessPaymentJob < ApplicationJob
  retry_on PaymentGatewayError, attempts: 3

  after_discard do |job, exception|
    # Alert on final discard — do not silently swallow
    ErrorTracker.report(exception, job_id: job.job_id)
  end
end
```

---

## Idempotency

Mechanics beyond the guard clause shown in **`agent_harness_rails/rules/jobs.mdc`**.

### find_or_create_by for unique records

When the job creates records, use `find_or_create_by` or unique database
indexes to prevent duplicates:

```ruby
def perform(user_id, badge_id)
  user = User.find(user_id)
  badge = Badge.find(badge_id)
  user.earned_badges.find_or_create_by!(badge: badge)
end
```

### Idempotency keys for external APIs

When calling external payment processors, email services, or third-party APIs,
use the provider's idempotency key — typically the job ID or a content hash:

```ruby
def perform(order_id)
  order = Order.find(order_id)
  PaymentGateway.charge(
    amount: order.amount_cents,
    token: order.payment_token,
    idempotency_key: "order-#{order.id}-charge"
  )
end
```

---

## Scheduling

### One-off delayed jobs

Pass timing options when enqueueing:

```ruby
# Run in 30 minutes
DigestEmailJob.set(wait: 30.minutes).perform_later(user.id)

# Run at a specific time
RenewalReminderJob.set(wait_until: subscription.renews_at - 3.days).perform_later(subscription.id)
```

### Recurring jobs (cron-style)

The rule and the minimal `config/recurring.yml` shape live in
**`agent_harness_rails/rules/jobs.mdc`** § Recurring Jobs. Operational detail:

```yaml
# config/recurring.yml
weekly_report:
  class: WeeklyReportJob
  args: [ { format: "pdf" } ]
  schedule: "0 9 * * 1"   # every Monday at 09:00
```

The `schedule` field accepts standard cron expressions or Fugit natural-language
syntax (`"every day at 8am"`). The file path can be overridden with the
`SOLID_QUEUE_RECURRING_SCHEDULE` environment variable or the
`--recurring_schedule_file` flag to `bin/jobs`. To disable all recurring tasks
in an environment (staging, review apps), set `SOLID_QUEUE_SKIP_RECURRING=true`.

Solid Queue uses a `solid_queue_recurring_executions` table with a unique index
on `(task_key, run_at)` to prevent duplicate enqueues when multiple schedulers
share the same configuration.

Keep the job itself thin — domain logic belongs on the model, the schedule is
configuration, not application code.

---

## Testing

Job spec patterns — structure, enqueuing assertions, idempotency testing,
and the boundary between caller specs and job specs — live in:

**`agent_harness_rails/skills/writing-tests/references/support-specs.md`** § Job Specs
