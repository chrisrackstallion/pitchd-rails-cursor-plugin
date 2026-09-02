# Service Patterns Reference

## Decision Tree

The first question is always: **does this need a new object at all?**

Most "service object" extractions in Rails are premature. A model method
handles 80% of cases. The remaining 20% split between form objects, POROs,
and jobs.

### When a Model Method Is Enough

If the operation acts on a single model instance, it's a method on that
model. Even if the method is 10–15 lines with a transaction, it belongs
on the model.

```ruby
class Article < ApplicationRecord
  def publish(by: Current.user)
    transaction do |txn|
      create_publication!(publisher: by)
      drafts.delete_all

      txn.after_commit { NotifySubscribersJob.perform_later(id) }
    end
  end
end
```

Note the shape: the job is enqueued in `txn.after_commit` (never inside the
open transaction — see the writing-jobs skill) and receives the id, not the
record.

### When Controller Orchestration Is Enough

When two models need coordinating and the logic is straightforward, the
controller *is* the orchestrator. You don't need a class for three lines
of procedural code.

```ruby
class TransfersController < ApplicationController
  def create
    @from_account = Account.find(params[:from_account_id])
    @to_account = Account.find(params[:to_account_id])
    amount = params[:amount].to_d

    @from_account.transaction do
      @from_account.withdraw(amount)
      @to_account.deposit(amount)
    end

    redirect_to @from_account, notice: "Transfer complete."
  end
end
```

If this pattern appears in multiple controllers, *then* extract — but
extract to a model method or PORO, not a service.

---

## Concerns

Concerns are the primary mechanism for sharing behaviour across unrelated
models. When the same capability (archiving, searching, tagging) needs to
exist on two or more models, extract a concern — not a PORO.

### Structure

```ruby
# app/models/concerns/archivable.rb
module Archivable
  extend ActiveSupport::Concern

  included do
    has_one :archival, as: :archivable, dependent: :destroy

    scope :archived,     -> { joins(:archival) }
    scope :unarchived,   -> { where.missing(:archival) }
  end

  def archived?   = archival.present?
  def unarchived? = !archived?

  def archive(by: Current.user)
    create_archival!(creator: by)
  end

  def unarchive
    archival&.destroy!
  end
end

# Included in any model that can be archived
class Article < ApplicationRecord
  include Archivable
end

class Project < ApplicationRecord
  include Archivable
end
```

Concern-vs-PORO criteria: **`agent_harness_rails/rules/services.mdc`**
§ Where Logic Actually Lives. Concern conventions (size, adjective names,
self-containment): **`agent_harness_rails/rules/models.mdc`** § Concerns for
Horizontal Behaviour.

---

## POROs (Plain Old Ruby Objects)

When an operation involves multiple steps within one aggregate, or coordinates
closely related models under a single named concept, extract to a PORO
namespaced under the primary model.

### Structure

```ruby
# app/models/account/onboarding.rb
class Account::Onboarding
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def complete(name:, plan:)
    account.transaction do
      account.update!(name: name, plan: plan)
      account.memberships.create!(user: Current.user, role: :owner)
      create_defaults
    end
  end

  private
    def create_defaults
      account.projects.create!(name: "My First Project")
      account.notification_settings.create!(defaults: true)
    end
end
```

### Usage

```ruby
# In a controller
def create
  @account = Account.new
  onboarding = Account::Onboarding.new(@account)
  onboarding.complete(name: params[:name], plan: params[:plan])
  redirect_to @account
end

# Or as a model method that delegates
class Account < ApplicationRecord
  def onboard(...)
    Onboarding.new(self).complete(...)
  end
end
```

PORO rules (naming, transactions, no base class, every method earning its
place): **`agent_harness_rails/rules/services.mdc`** § POROs Under Model
Namespaces.

### File Organisation

```
app/models/
├── account.rb
├── account/
│   ├── onboarding.rb
│   ├── suspension.rb
│   └── billing_sync.rb
├── order.rb
├── order/
│   ├── fulfillment.rb
│   └── refund.rb
```

Rails autoloads these namespaces automatically. `Account::Onboarding` resolves
to `app/models/account/onboarding.rb`.

---

## Form Objects

Form objects handle the gap between user input and model persistence. When
to use one (and when a PORO instead): **`agent_harness_rails/rules/services.mdc`**
§ Form Objects for Multi-Model Writes.

### Basic Form Object

```ruby
# app/models/registration.rb
class Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :company_name, :string

  validates :name, :email, :password, :company_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }

  def save
    return false unless valid?

    Account.transaction do
      @account = Account.create!(name: company_name)
      @user = User.create!(
        name: name,
        email: email,
        password: password,
        account: @account
      )
    end

    true
  end

  def user    = @user
  def account = @account
end
```

### Controller Integration

Form objects work with `form_with` just like ActiveRecord models:

```ruby
class RegistrationsController < ApplicationController
  def new
    @registration = Registration.new
  end

  def create
    @registration = Registration.new(registration_params)

    if @registration.save
      start_session_for(@registration.user)
      redirect_to dashboard_path, notice: "Welcome!"
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def registration_params
      params.expect(registration: %i[name email password company_name])
    end
end
```

### View Integration

```erb
<%= form_with model: @registration, url: registration_path do |f| %>
  <div>
    <%= f.label :name %>
    <%= f.text_field :name %>
  </div>

  <div>
    <%= f.label :email %>
    <%= f.email_field :email %>
  </div>

  <div>
    <%= f.label :company_name %>
    <%= f.text_field :company_name %>
  </div>

  <div>
    <%= f.label :password %>
    <%= f.password_field :password %>
  </div>

  <%= f.submit "Sign up" %>
<% end %>
```

### Update Form Objects

Form objects can also wrap updates. Use an explicit `url:` in `form_with`
to avoid route inference complexity:

```ruby
# app/models/profile_update.rb
class ProfileUpdate
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :user

  attribute :name, :string
  attribute :email, :string
  attribute :avatar

  validates :name, :email, presence: true

  def initialize(user, attributes = {})
    @user = user
    super(attributes)
    self.name  ||= user.name
    self.email ||= user.email
  end

  def save
    return false unless valid?

    user.update!(name: name, email: email)
    user.avatar.attach(avatar) if avatar.present?

    true
  end
end
```

In the controller and view, pass the URL explicitly rather than relying on
route inference:

```ruby
# Controller
def edit
  @form = ProfileUpdate.new(Current.user)
end

def update
  @form = ProfileUpdate.new(Current.user, profile_params)
  if @form.save
    redirect_to profile_path, notice: "Profile updated."
  else
    render :edit, status: :unprocessable_content
  end
end
```

```erb
<%= form_with model: @form, url: profile_path, method: :patch do |f| %>
  ...
<% end %>
```

---

## Jobs as the Async Layer

Jobs are Rails' built-in service layer for asynchronous work. Anything that
should happen in the background — emails, webhooks, data sync, heavy
computation — is a job.

### Structure

```ruby
# app/jobs/sync_inventory_job.rb
class SyncInventoryJob < ApplicationJob
  queue_as :default
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 5

  def perform(product_id)
    product = Product.find(product_id)
    response = InventoryApi.new.fetch(product.sku)
    product.update!(stock_count: response[:quantity])
  end
end
```

### Enqueuing from Models

```ruby
class Order < ApplicationRecord
  after_create_commit :fulfill_later

  private
    def fulfill_later
      FulfillOrderJob.perform_later(id)
    end
end
```

### Enqueuing from Controllers

```ruby
def create
  @import = Import.create!(import_params)
  ProcessImportJob.perform_later(@import.id)
  redirect_to @import, notice: "Import started."
end
```

Job conventions — one responsibility, IDs not objects (and the GlobalID
alternative), `retry_on` / `discard_on`, idempotency — live in
**`agent_harness_rails/rules/jobs.mdc`**. Jobs have no return values — they
communicate through side effects (database writes, emails, broadcasts).

---

## External Integrations

Wrapping external APIs follows the same principle: name the object after
the domain concept, not the action.

### Structure

```ruby
# app/models/inventory_api.rb
class InventoryApi
  BASE_URL = "https://api.warehouse.example.com/v2"

  def initialize(api_key: Rails.application.credentials.warehouse_api_key)
    @api_key = api_key
  end

  def fetch(sku)
    response = connection.get("/products/#{sku}")
    parse(response)
  end

  def update_stock(sku, quantity:)
    connection.patch("/products/#{sku}", { quantity: quantity }.to_json)
  end

  private
    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :raise_error
        f.headers["Authorization"] = "Bearer #{@api_key}"
      end
    end

    def parse(response)
      JSON.parse(response.body, symbolize_names: true)
    end
end
```

### Namespaced Under a Model

When an API client is tightly coupled to a model, namespace it:

```ruby
# app/models/product/warehouse_sync.rb
class Product::WarehouseSync
  def initialize(product)
    @product = product
    @api = InventoryApi.new
  end

  def sync
    data = @api.fetch(@product.sku)
    @product.update!(stock_count: data[:quantity], synced_at: Time.current)
  end
end
```

### Guidelines

- **API clients are domain objects** — they live in `app/models/`, named
  after the external system: `StripeGateway`, `InventoryApi`, `SlackNotifier`
- **Wrap HTTP details** — callers should not know about endpoints, headers,
  or JSON parsing
- **Credential access via `Rails.application.credentials`** — never in
  constructor arguments
- **Error classes namespaced under the client** — `InventoryApi::NotFound`,
  `StripeGateway::PaymentDeclined`
- **Call from jobs for resilience** — external calls should usually be async
  with retry logic

---

## Bulk Operations

Imports, exports, and batch processing follow the same patterns. Use a
form object for input validation, a PORO for the processing logic, and
a job for the async execution.

### Import Pattern

```ruby
# app/models/contact_import.rb — the record
class ContactImport < ApplicationRecord
  has_one_attached :file
  belongs_to :account
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  enum :status, { pending: "pending", processing: "processing",
                  completed: "completed", failed: "failed" }, default: :pending

  def process
    return if completed?  # idempotency guard — retried jobs are no-ops

    update!(status: :processing)
    result = ContactImport::Processor.new(self).run
    update!(status: :completed, processed_count: result.processed, error_count: result.errors.size)
  end
end

# app/models/contact_import/processor.rb — the logic
class ContactImport::Processor
  Result = Data.define(:processed, :errors)

  def initialize(import)
    @import = import
    @account = import.account
  end

  def run
    processed = 0
    errors = []

    parse_csv.each_with_index do |row, i|
      @account.contacts.find_or_create_by!(email: row["email"]) do |contact|
        contact.name = row["name"]
        contact.phone = row["phone"]
      end
      processed += 1
    rescue => e
      errors << { row: i + 1, message: e.message }
    end

    Result.new(processed: processed, errors: errors)
  end

  private
    def parse_csv
      CSV.parse(@import.file.download, headers: true)
    end
end

# app/jobs/process_contact_import_job.rb — async execution
class ProcessContactImportJob < ApplicationJob
  discard_on ActiveRecord::RecordNotFound

  def perform(import_id)
    ContactImport.find(import_id).process
  end
end
```

The import is a **model** (it has a database record, status, file
attachment). The processor is a **PORO** namespaced under the import.
The job is just the async wrapper.

Per-row errors are accumulated rather than aborting — one bad row should not
cancel the entire import. The `return if completed?` guard makes the job
idempotent: a retry after success is a no-op instead of a double import.

---

## Migration Guide

When refactoring existing `app/services/` code to these patterns, follow
this mapping:

### Single-Model Services → Model Methods

```ruby
# Before: app/services/publish_article_service.rb
class PublishArticleService
  def initialize(article, user)
    @article = article
    @user = user
  end

  def call
    @article.update!(published: true, published_at: Time.current, publisher: @user)
    NotifySubscribersJob.perform_later(@article)
  end
end

# After: model method
class Article < ApplicationRecord
  def publish(by: Current.user)
    update!(published: true, published_at: Time.current, publisher: by)
  end

  after_update_commit :notify_subscribers_later, if: :published_previously_changed?

  private
    def notify_subscribers_later
      NotifySubscribersJob.perform_later(id)
    end
end
```

This first step is mechanical — it keeps the existing boolean schema and
only relocates the logic. The follow-up refactor is to replace the
`published`/`published_at`/`publisher` columns with a `Publication` state
record (see the writing-models skill § State as Records).

### Multi-Step Services → POROs Under Models

```ruby
# Before: app/services/onboard_account_service.rb
class OnboardAccountService
  def initialize(params, user)
    @params = params
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      account = Account.create!(name: @params[:company_name])
      account.memberships.create!(user: @user, role: :owner)
      account.projects.create!(name: "Default")
    end
  end
end

# After: app/models/account/onboarding.rb
class Account::Onboarding
  attr_reader :account

  def initialize(account)
    @account = account
  end

  def complete(name:)
    account.transaction do
      account.update!(name: name)
      account.memberships.create!(user: Current.user, role: :owner)
      account.projects.create!(name: "Default")
    end
  end
end
```

### Form-Handling Services → Form Objects

```ruby
# Before: app/services/create_user_service.rb
class CreateUserService
  def initialize(params)
    @params = params
  end

  def call
    user = User.new(@params)
    return { success: false, errors: user.errors } unless user.valid?
    user.save!
    WelcomeMailer.welcome(user).deliver_later
    { success: true, user: user }
  end
end

# After: app/models/registration.rb
class Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string

  validates :name, :email, :password, presence: true

  def save
    return false unless valid?
    @user = User.create!(name: name, email: email, password: password)
    true
  end

  def user = @user
end
```

### Async Services → Jobs

```ruby
# Before: app/services/sync_stripe_service.rb
class SyncStripeService
  def call(account)
    # ... stripe API calls ...
  end
end

# After: app/jobs/sync_stripe_job.rb
class SyncStripeJob < ApplicationJob
  retry_on Stripe::RateLimitError, wait: :polynomially_longer

  def perform(account)
    # ... stripe API calls ...
  end
end
```

---

## Error Handling

### Let Exceptions Propagate

POROs and form objects use bang methods internally. The exception bubbles
to the controller where `rescue_from` can handle it uniformly.

```ruby
class Account::Onboarding
  def complete(name:)
    account.transaction do
      account.update!(name: name)
      account.memberships.create!(user: Current.user, role: :owner)
    end
  end
end
```

### Domain Exceptions

When a business rule prevents an operation, raise a domain exception
namespaced under the model:

```ruby
class Account < ApplicationRecord
  class AlreadySuspended < StandardError; end

  def suspend(reason:, by: Current.user)
    raise AlreadySuspended if suspended?
    create_suspension!(reason: reason, creator: by)
  end
end
```

Handle in the controller:

```ruby
class Account::SuspensionsController < ApplicationController
  rescue_from Account::AlreadySuspended do
    redirect_to @account, alert: "Account is already suspended."
  end

  def create
    @account.suspend(reason: params[:reason])
    redirect_to @account, notice: "Account suspended."
  end
end
```

### No Result Objects

Don't wrap outcomes in result monads or success/failure structs. Rails
has a perfectly good convention:

- **Success** → return the record, redirect
- **Validation failure** → return `false` from `save`, render the form
- **Business rule violation** → raise a domain exception
- **Unexpected error** → let it propagate to the error handler

```ruby
# Bad — result monad
def call
  Result.new(success: true, data: account)
rescue => e
  Result.new(success: false, error: e.message)
end

# Good — standard Rails patterns
def save
  return false unless valid?
  @account = Account.create!(attributes)
  true
end
```

