# Job Patterns Reference

ActiveJob is part of Rails omakase: **no separate async service layer.**
Jobs are thin wrappers that call model methods asynchronously — the same
principle that keeps controllers thin applies here. See **`rules/services.mdc`**
and **`skills/writing-services/SKILL.md`** for where domain logic belongs.

---

## Job Structure

### Minimal job

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

### Pass IDs, not objects

ActiveRecord objects are serialized by GlobalID when passed as job arguments.
If the record is deleted between enqueueing and execution, the job raises
`ActiveJob::DeserializationError`. Pass IDs and find records fresh in `perform`:

```ruby
# Good — pass the ID
NotifySubscribersJob.perform_later(article.id)

def perform(article_id)
  article = Article.find(article_id)
  article.notify_subscribers
end

# Acceptable when you handle DeserializationError at the ApplicationJob level
NotifySubscribersJob.perform_later(article)

def perform(article)
  article.notify_subscribers
end
```

If you pass an ActiveRecord object directly, `discard_on ActiveJob::DeserializationError`
in `ApplicationJob` prevents queue poisoning when the record is deleted before
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

### The after_commit rule

Never enqueue a job inside an open transaction. The queue backend receives
the job immediately — before the transaction commits. If the transaction rolls
back, the job runs against a record that no longer exists or has been
reverted to a previous state.

```ruby
# Bad — job enqueued inside transaction, will run if transaction rolls back
def publish(by: Current.user)
  transaction do
    create_publication!(publisher: by)
    NotifySubscribersJob.perform_later(id)  # runs even on rollback
  end
end

# Good — after_commit fires only when the outer transaction commits
after_create_commit :notify_subscribers_later

private
  def notify_subscribers_later
    NotifySubscribersJob.perform_later(id)
  end
```

Use the `_commit` variants:
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
- `:exponentially_longer` — doubles the wait each attempt (2s, 4s, 8s…)
- `:polynomially_longer` — grows more slowly, good for longer retry windows
- `N.seconds` — fixed interval

### discard_on

For permanent failures — validation errors, records that no longer exist,
states the job cannot handle — use `discard_on` to prevent retrying:

```ruby
class SendWelcomeEmailJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound
  discard_on User::AlreadyOnboarded

  def perform(user_id)
    user = User.find(user_id)
    raise User::AlreadyOnboarded if user.welcomed?
    UserMailer.with(user: user).welcome.deliver_now
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

Jobs can run more than once — retries, duplicate enqueues, or manual
re-processing. Write `perform` so running it twice produces the same result
as running it once.

### Guard clauses

Check the record's current state at the start of `perform` and return early
if the work is already done:

```ruby
def perform(subscription_id)
  subscription = Subscription.find(subscription_id)
  return if subscription.cancelled?   # already done — nothing to do
  subscription.cancel
end
```

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

Solid Queue has scheduling built in — no additional gem required. Define
recurring tasks in `config/solid_queue.yml` (or `config/recurring.yml` if
separated) under the dispatcher's `recurring_tasks` key:

```yaml
# config/solid_queue.yml
dispatchers:
  - polling_interval: 1
    batch_size: 500
    recurring_tasks:
      daily_digest:
        class: DailyDigestJob
        schedule: "0 8 * * *"   # standard cron — every day at 08:00
      weekly_report:
        class: WeeklyReportJob
        args: [ { format: "pdf" } ]
        schedule: "0 9 * * 1"   # every Monday at 09:00
```

The `schedule` field accepts standard cron expressions or Fugit natural-language
syntax (`"every day at 8am"`). Solid Queue uses a `solid_queue_recurring_executions`
table with a unique index on `(task_key, run_at)` to prevent duplicate enqueues
when multiple dispatchers share the same configuration.

Keep the job itself thin — domain logic belongs on the model, the schedule is
configuration, not application code.

---

## Testing

### Asserting enqueueing (callers)

The caller (model callback, controller, another job) should only prove the
job was enqueued — not that the job performed correctly:

```ruby
# spec/models/article_spec.rb
describe "#publish" do
  it "enqueues subscriber notification" do
    article = create(:article)

    expect {
      article.publish
    }.to have_enqueued_job(NotifySubscribersJob).with(article.id)
  end
end
```

### Testing the job itself

Run the job inline to test `perform`:

```ruby
# spec/jobs/notify_subscribers_job_spec.rb
RSpec.describe NotifySubscribersJob, type: :job do
  describe "#perform" do
    it "notifies each subscriber" do
      article = create(:article, :published)
      subscribers = create_list(:user, 3)
      subscribers.each { |u| article.subscribers << u }

      expect {
        described_class.perform_now(article.id)
      }.to have_enqueued_mail(ArticleMailer, :update).exactly(3).times
    end

    it "does nothing when the article is unpublished" do
      article = create(:article)  # not published

      expect {
        described_class.perform_now(article.id)
      }.not_to have_enqueued_mail
    end
  end
end
```

Use `perform_enqueued_jobs` in system or request specs only when you need
to verify end-to-end side effects — prefer unit-level job specs for the
job's own logic.
