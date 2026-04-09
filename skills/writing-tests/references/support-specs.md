# Support Specs Reference

Specs for policies, jobs, mailers, concerns, and standalone POROs. These
are the "everything else" — write them when the object has meaningful
logic worth testing in isolation.

## Policy Specs

Policy specs test authorization logic — who can do what. They are the
single home for permission assertions. Request specs test that the HTTP
layer enforces authorization (status codes, redirects); policy specs test
the logic itself.

### Structure

Test policies by instantiating them directly and asserting on the boolean
return value. Use `let` for the role × action matrix — this is one place
where `let` is appropriate because the context/role structure is the test's
core organising principle, not obscure shared state.

```ruby
# spec/policies/article_policy_spec.rb
RSpec.describe ArticlePolicy do
  let(:article) { create(:article, creator: creator) }
  let(:creator) { create(:user) }

  context "as a regular user" do
    let(:user) { create(:user) }

    it "permits create but forbids update and destroy" do
      policy = described_class.new(user, article)

      expect(policy.create?).to be true
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end

  context "as the article creator" do
    let(:user) { creator }

    it "permits update but forbids destroy" do
      policy = described_class.new(user, article)

      expect(policy.update?).to be true
      expect(policy.destroy?).to be false
    end
  end

  context "as an admin" do
    let(:user) { create(:user, :admin) }

    it "permits all actions" do
      policy = described_class.new(user, article)

      expect(policy.show?).to be true
      expect(policy.create?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end
  end
end
```

### When `pundit_user` is `Current`

Policy specs instantiate `Policy.new(first_arg, record)` with the **same
shape** production passes — if `pundit_user` returns `Current`, pass `Current`
(or a test double that responds to `account`, `user`, etc.), not a bare `User`.

```ruby
RSpec.describe ArticlePolicy do
  let(:article) { create(:article, creator: creator) }
  let(:creator) { create(:user) }

  around do |example|
    Current.set(user: signed_in_user) { example.run }
  end

  let(:signed_in_user) { create(:user) }

  it "uses Current as the first argument when production uses pundit_user → Current" do
    policy = described_class.new(Current, article)

    # Example: policy compares user.user to record.creator — adjust expectations to your rules
    expect(policy.update?).to be false
  end
end
```

Use `Current.set` (or your app’s equivalent) so `Current` matches what
controllers assign during a request. If you only ever use `pundit_user` →
`Current.user`, keep passing a `User` into `Policy.new` as in the examples
above.

### With pundit-matchers (Optional)

The `pundit-matchers` gem provides concise one-liner syntax. If your
project uses it, the same spec can be written more compactly:

```ruby
RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { create(:article, creator: creator) }
  let(:creator) { create(:user) }

  context "as the article creator" do
    let(:user) { creator }

    it { is_expected.to permit_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end
end
```

> **Note:** The `is_expected.to` + implicit `subject` pattern is normally
> discouraged in this project's testing conventions. Policy specs with
> `pundit-matchers` are an accepted exception — the one-liners map cleanly
> to the permission matrix and remain readable.

### Testing Scopes

```ruby
RSpec.describe ArticlePolicy::Scope do
  describe "#resolve" do
    it "returns all articles for admins" do
      admin = create(:user, :admin)
      create_list(:article, 3)

      scope = described_class.new(admin, Article).resolve

      expect(scope.count).to eq(3)
    end

    it "returns own and published articles for regular users" do
      user = create(:user)
      own_article = create(:article, creator: user)
      published = create(:article, :published)
      other_draft = create(:article) # someone else's draft

      scope = described_class.new(user, Article).resolve

      expect(scope).to contain_exactly(own_article, published)
    end
  end
end
```

### Testing Namespaced Policies

For admin or other namespaced policies, test the namespaced class directly:

```ruby
# spec/policies/admin/article_policy_spec.rb
RSpec.describe Admin::ArticlePolicy do
  context "as a regular user" do
    let(:user) { create(:user) }

    it "forbids all actions" do
      policy = described_class.new(user, create(:article))

      expect(policy.index?).to be false
      expect(policy.destroy?).to be false
    end
  end

  context "as an admin" do
    let(:user) { create(:user, :admin) }

    it "permits all actions" do
      policy = described_class.new(user, create(:article))

      expect(policy.index?).to be true
      expect(policy.destroy?).to be true
    end
  end
end
```

The controller uses `authorize [:admin, @article]` which resolves to
`Admin::ArticlePolicy` — but in the spec, instantiate the class directly.

### Testing State-Change Policies (Noun Resources)

State-change controllers use a dedicated policy class. The spec tests
`create?` and `destroy?` — standard CRUD, no custom verb methods:

```ruby
# spec/policies/cards/closure_policy_spec.rb
RSpec.describe Cards::ClosurePolicy do
  let(:card) { create(:card, creator: card_creator) }
  let(:card_creator) { create(:user) }

  context "as the card creator" do
    let(:user) { card_creator }

    it "permits create and destroy" do
      policy = described_class.new(user, card)

      expect(policy.create?).to be true
      expect(policy.destroy?).to be true
    end
  end

  context "as another user" do
    let(:user) { create(:user) }

    it "forbids create and destroy" do
      policy = described_class.new(user, card)

      expect(policy.create?).to be false
      expect(policy.destroy?).to be false
    end
  end
end
```

The controller calls `authorize @card, policy_class: Cards::ClosurePolicy`
— the spec instantiates the policy class directly with the card as the record.

### Boundaries — What Belongs Here vs. Elsewhere

Policy specs own the permission logic. Other layers trust them:

| Assertion | Tested in | NOT tested in |
|-----------|-----------|---------------|
| Admin can destroy articles | Policy spec | Request spec doesn't re-check the logic |
| Regular user cannot destroy | Policy spec | Request spec tests the redirect |
| Scope filters by user | Policy spec | Controller uses `policy_scope`; request spec trusts it |
| Endpoint redirects unauthorized users | Request spec | Policy spec doesn't test HTTP |
| Button is hidden for unauthorized user | System spec | Policy spec doesn't test views |

```ruby
# Policy spec — owns the logic
it "denies non-owners" do
  policy = described_class.new(other_user, article)
  expect(policy.update?).to be false
end

# Request spec — owns the HTTP gate (e.g. redirect from Pundit handler)
it "redirects unauthorized users" do
  sign_in other_user
  patch article_path(article), params: { article: { title: "Hacked" } }
  expect(response).to redirect_to(root_path)
end

# The request spec does NOT also check policy.update? — that's duplication.
# The policy spec does NOT make HTTP requests — that's the wrong layer.
```

### Guidelines

- **One spec file per policy** — `spec/policies/article_policy_spec.rb`
- **Test every role × action combination** — this is the permission matrix
- **`let` is appropriate here** — the role matrix is declarative, not obscure
- **Test scopes separately** — they have their own logic worth verifying
- **Don't test HTTP in policy specs** — policy specs test `true`/`false`
- **Don't re-test policy logic in request specs** — request specs test the HTTP response
- **Use `pundit-matchers`** for concise one-liner assertions (optional but clean)

---

## Job Specs

Test that jobs do their work correctly. Use `perform_now` to execute
synchronously in the test.

### Structure

```ruby
# spec/jobs/notify_subscribers_job_spec.rb
RSpec.describe NotifySubscribersJob, type: :job do
  describe "#perform" do
    it "sends notification emails to subscribers" do
      article = create(:article, :published)
      subscribers = create_list(:user, 3)
      subscribers.each { |u| create(:subscription, user: u, author: article.author) }

      expect {
        described_class.perform_now(article)
      }.to change { ActionMailer::Base.deliveries.count }.by(3)
    end

    it "skips unsubscribed users" do
      article = create(:article, :published)
      unsubscribed = create(:user)

      expect {
        described_class.perform_now(article)
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
```

### Testing Job Enqueuing

Test that jobs get enqueued at the right time (in model or request specs):

```ruby
# In a model spec
describe "after publishing" do
  it "enqueues a notification job" do
    article = create(:article)

    expect {
      article.publish
    }.to have_enqueued_job(NotifySubscribersJob).with(article)
  end
end
```

### Testing Retry Behaviour

```ruby
describe "retry behaviour" do
  it "retries on network timeout" do
    expect(described_class.new.retry_on).to include(
      a_hash_including(error: Net::TimeoutError)
    )
  end
end
```

### Testing Queue Assignment

```ruby
it "enqueues on the correct queue" do
  article = create(:article)

  expect {
    described_class.perform_later(article)
  }.to have_enqueued_job.on_queue("default")
end
```

---

## Mailer Specs

Mailer classes, `deliver_later`, `Mailer.with`, and previews: **`../writing-mailers/references/patterns.md`**. Below: **RSpec** shape for mail content and enqueueing.

Test mailers by asserting on the generated mail object — recipients,
subject, body content.

### Structure

```ruby
# spec/mailers/notification_mailer_spec.rb
RSpec.describe NotificationMailer, type: :mailer do
  describe "#comment_notification" do
    it "sends to the article author" do
      comment = create(:comment)
      mail = described_class.comment_notification(comment)

      expect(mail.to).to eq([comment.article.author.email_address])
      expect(mail.subject).to include("New comment")
    end

    it "includes the comment body" do
      comment = create(:comment, body: "Insightful feedback")
      mail = described_class.comment_notification(comment)

      expect(mail.body.encoded).to include("Insightful feedback")
    end
  end

  describe "#welcome" do
    it "sends to the new user" do
      user = create(:user, email_address: "alice@example.com")
      mail = described_class.welcome(user)

      expect(mail.to).to eq(["alice@example.com"])
      expect(mail.subject).to eq("Welcome to the platform")
    end
  end
end
```

### Testing Mailer Delivery

In request or system specs, test that mailers get delivered:

```ruby
describe "POST /registrations" do
  it "sends a welcome email" do
    expect {
      post registrations_path, params: { registration: valid_params }
    }.to have_enqueued_mail(NotificationMailer, :welcome)
  end
end
```

### ActionMailer Test Helpers

```ruby
# Inline delivery for test assertions
RSpec.configure do |config|
  config.before do
    ActionMailer::Base.deliveries.clear
  end
end

# Or use ActiveJob test adapter
RSpec.configure do |config|
  config.include ActiveJob::TestHelper
end
```

---

## Concern Specs

Test concerns through a real model that includes them. Don't create
anonymous test classes or use doubles.

### Structure

```ruby
# spec/models/concerns/publishable_spec.rb
RSpec.describe Publishable do
  # Article includes Publishable — test through it
  describe "#publish" do
    it "creates a publication record" do
      article = create(:article)

      article.publish

      expect(article).to be_published
      expect(article.publication).to be_present
    end
  end

  describe "#unpublish" do
    it "removes the publication" do
      article = create(:article, :published)

      article.unpublish

      expect(article).not_to be_published
    end
  end

  describe ".published scope" do
    it "returns only published records" do
      published = create(:article, :published)
      draft = create(:article)

      expect(Article.published).to contain_exactly(published)
    end
  end

  describe ".unpublished scope" do
    it "returns records without publications" do
      published = create(:article, :published)
      draft = create(:article)

      expect(Article.unpublished).to contain_exactly(draft)
    end
  end
end
```

### When to Write Concern Specs

- The concern has non-trivial logic (state machines, complex scopes)
- The concern is used by multiple models and you want one canonical test
- The concern has edge cases worth documenting

### When NOT to Write Concern Specs

- The concern just declares associations with no logic
- The model spec already covers the behaviour thoroughly
- The concern is simple enough that model specs are sufficient

---

## PORO Specs

Test POROs (Plain Old Ruby Objects) like any other model — real records,
real database, real assertions.

### Structure

```ruby
# spec/models/account/onboarding_spec.rb
RSpec.describe Account::Onboarding do
  describe "#complete" do
    it "configures the account with defaults" do
      account = create(:account)
      onboarding = described_class.new(account)

      onboarding.complete(name: "Acme Corp", plan: :pro)

      account.reload
      expect(account.name).to eq("Acme Corp")
      expect(account.plan).to eq("pro")
      expect(account.memberships).to be_present
      expect(account.projects).to be_present
    end

    it "creates an owner membership for the current user" do
      user = create(:user)
      Current.user = user
      account = create(:account)

      described_class.new(account).complete(name: "Acme", plan: :basic)

      membership = account.memberships.first
      expect(membership.user).to eq(user)
      expect(membership.role).to eq("owner")
    end

    it "rolls back on failure" do
      account = create(:account)

      # Feed genuinely invalid data that triggers a real validation failure
      expect {
        described_class.new(account).complete(name: "", plan: :basic)
      }.to raise_error(ActiveRecord::RecordInvalid)

      # Transaction rolled back — no partial state
      expect(account.reload.memberships).to be_empty
    end
  end
end
```

---

## Form Object Specs

Form objects combine validation testing with persistence testing.

### Structure

```ruby
# spec/models/registration_spec.rb
RSpec.describe Registration do
  describe "#save" do
    context "with valid attributes" do
      it "creates a user and account" do
        registration = described_class.new(
          name: "Alice",
          email: "alice@example.com",
          password: "secretpass",
          company_name: "Acme Inc"
        )

        expect(registration.save).to be true
        expect(registration.user).to be_persisted
        expect(registration.account).to be_persisted
        expect(registration.account.name).to eq("Acme Inc")
      end
    end

    context "with missing name" do
      it "returns false and has errors" do
        registration = described_class.new(
          name: "",
          email: "alice@example.com",
          password: "secretpass",
          company_name: "Acme"
        )

        expect(registration.save).to be false
        expect(registration.errors[:name]).to be_present
      end
    end

    context "with invalid email" do
      it "returns false and has errors" do
        registration = described_class.new(
          name: "Alice",
          email: "not-an-email",
          password: "secretpass",
          company_name: "Acme"
        )

        expect(registration.save).to be false
        expect(registration.errors[:email]).to be_present
      end
    end

    context "with duplicate email" do
      it "raises on save" do
        create(:user, email_address: "alice@example.com")

        registration = described_class.new(
          name: "Alice",
          email: "alice@example.com",
          password: "secretpass",
          company_name: "Acme"
        )

        # Database constraint catches it — save raises
        expect { registration.save }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
```

---

## External API Client Specs

Mock external HTTP calls with WebMock or VCR. Never hit real APIs in tests.

### With WebMock

```ruby
# spec/models/inventory_api_spec.rb
RSpec.describe InventoryApi do
  describe "#fetch" do
    it "returns product data" do
      stub_request(:get, "https://api.warehouse.example.com/v2/products/SKU123")
        .to_return(
          status: 200,
          body: { sku: "SKU123", quantity: 42 }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      api = described_class.new
      result = api.fetch("SKU123")

      expect(result[:quantity]).to eq(42)
    end

    it "raises on server error" do
      stub_request(:get, "https://api.warehouse.example.com/v2/products/SKU123")
        .to_return(status: 500)

      api = described_class.new

      expect { api.fetch("SKU123") }.to raise_error(Faraday::ServerError)
    end
  end
end
```

### With VCR

```ruby
RSpec.describe InventoryApi do
  describe "#fetch", vcr: { cassette_name: "inventory_api/fetch" } do
    it "returns product data" do
      result = described_class.new.fetch("SKU123")

      expect(result[:quantity]).to be_a(Integer)
    end
  end
end
```

---

## Channel Specs (Action Cable)

```ruby
# spec/channels/room_channel_spec.rb
RSpec.describe RoomChannel, type: :channel do
  it "subscribes to the room stream" do
    room = create(:room)

    subscribe(room_id: room.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(room)
  end

  it "rejects without a room_id" do
    subscribe(room_id: nil)

    expect(subscription).to be_rejected
  end
end
```

---

## RSpec Configuration

### rails_helper.rb Essentials

```ruby
# spec/rails_helper.rb
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # FactoryBot
  config.include FactoryBot::Syntax::Methods

  # ActiveJob test helpers
  config.include ActiveJob::TestHelper

  # ActionMailer test helpers
  config.before { ActionMailer::Base.deliveries.clear }
end
```

### Support Files

```
spec/support/
├── authentication.rb      # sign_in helpers for request specs
├── system_authentication.rb # sign_in helpers for system specs
├── current_user.rb        # Current.user helper
└── capybara.rb            # Capybara configuration
```

---

## Boundaries — What Belongs Here vs. Elsewhere

Support specs own the work that jobs, mailers, concerns, and POROs perform.
Callers (models, controllers) only assert that work was enqueued — they
don't re-test the work itself.

### Enqueuing vs. Performing

```ruby
# Model spec — asserts the job is enqueued (does NOT test what the job does)
describe "#publish" do
  it "enqueues a notification job" do
    expect { article.publish }.to have_enqueued_job(NotifySubscribersJob)
  end
end

# Job spec — owns what the job actually does
describe NotifySubscribersJob do
  it "sends notification emails" do
    expect {
      described_class.perform_now(article)
    }.to change { ActionMailer::Base.deliveries.count }.by(3)
  end
end
```

The model spec does not call `perform_now` and check that emails were sent.
The job spec does not re-test that `article.publish` enqueues the job.
Each spec owns its layer.

The same applies to mailers:

```ruby
# Request spec — asserts the mailer was enqueued
it "sends a welcome email" do
  expect {
    post registrations_path, params: { registration: valid_params }
  }.to have_enqueued_mail(NotificationMailer, :welcome)
end

# Mailer spec — owns the mail content
describe "#welcome" do
  it "addresses the new user" do
    mail = described_class.welcome(user)
    expect(mail.to).to eq([user.email_address])
  end
end
```

### Concern Specs and Model Specs

If a concern is simple and only used by one model, test it through that
model's spec — don't create a separate concern spec. Write a dedicated
concern spec when:

- The concern is used by multiple models
- You want one canonical test covering the concern's contract
- The concern has complex logic worth testing in isolation

When a concern spec exists, the model spec for each including model does
NOT need to re-test the concern's behaviour. The model spec trusts the
concern spec.

## Guidelines

- **Test through real models** — concerns are tested via including models
- **Use `perform_now`** for job specs — test the job's work, not the queue
- **Mock external HTTP only** — WebMock or VCR for APIs, real everything else
- **Form objects get validation AND persistence tests** — both paths matter
- **POROs get the same treatment as models** — real records, real database
- **One spec file per object** — `spec/models/account/onboarding_spec.rb`
- **Test observable behaviour** — emails sent, records created, state changed
- **Don't test that Rails works** — `has_many` declarations, built-in validations
- **Callers assert enqueuing, not performing** — `have_enqueued_job`, not inline `perform_now`
- **Don't re-test across layers** — model spec says "job enqueued"; job spec says "job works"
- **One home per concern** — test in concern spec OR model spec, not both
