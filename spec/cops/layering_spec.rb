# frozen_string_literal: true

require "spec_helper"

require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::ServiceObject, :config do
  let(:cop_config) { { "Suffixes" => %w[Service Manager Handler Interactor Operation Command] } }

  it "flags a class named for a service" do
    expect_offense(<<~RUBY)
      class PublishArticleService
            ^^^^^^^^^^^^^^^^^^^^^ Avoid `PublishArticleService`. Put the behaviour on the model, in a PORO namespaced under it, or in a job.
        def call(article)
          article.publish
        end
      end
    RUBY
  end

  it "flags the base class the pattern grows around" do
    expect_offense(<<~RUBY)
      class ApplicationService
            ^^^^^^^^^^^^^^^^^^ Avoid `ApplicationService`. Put the behaviour on the model, in a PORO namespaced under it, or in a job.
      end
    RUBY
  end

  it "flags anything under app/services, whatever it is called" do
    expect_offense(<<~RUBY, "app/services/publisher.rb")
      class Publisher
            ^^^^^^^^^ Avoid app/services/. Put the behaviour on the model, in a PORO namespaced under it, or in a job.
      end
    RUBY
  end

  it "accepts a PORO namespaced under the aggregate it serves" do
    expect_no_offenses(<<~RUBY, "app/models/account/onboarding.rb")
      class Account::Onboarding
        def complete(params)
          @account.update!(params)
        end
      end
    RUBY
  end

  it "accepts a table-backed model whose name is the domain noun itself" do
    # A billing app has services in it. The word is the whole name, so there is
    # no wrapped verb for the suffix to be a suffix of.
    expect_no_offenses(<<~RUBY, "app/models/service.rb")
      class Service < ApplicationRecord
        belongs_to :account
      end
    RUBY
  end

  it "accepts a table-backed model that ends in a suffix" do
    # `Put the behaviour on the model` is the advice, and this class is the model.
    expect_no_offenses(<<~RUBY, "app/models/payment_service.rb")
      class PaymentService < ApplicationRecord
      end
    RUBY
  end

  it "accepts an STI subclass of a domain noun" do
    expect_no_offenses(<<~RUBY, "app/models/payment_service.rb")
      class PaymentService < Service
      end
    RUBY
  end

  it "accepts a model recognised by its associations rather than its superclass" do
    expect_no_offenses(<<~RUBY, "app/models/dispatch_operation.rb")
      class DispatchOperation < LegacyRecord
        has_many :dispatches
      end
    RUBY
  end

  it "flags a form object even though it validates, because a form is not a table" do
    expect_offense(<<~RUBY, "app/models/checkout_operation.rb")
      class CheckoutOperation
            ^^^^^^^^^^^^^^^^^ Avoid `CheckoutOperation`. Put the behaviour on the model, in a PORO namespaced under it, or in a job.
        include ActiveModel::Model

        validates :card_token, presence: true
      end
    RUBY
  end

  it "flags a class under app/services whatever the domain calls that word" do
    expect_offense(<<~RUBY, "app/services/service.rb")
      class Service
            ^^^^^^^ Avoid app/services/. Put the behaviour on the model, in a PORO namespaced under it, or in a job.
      end
    RUBY
  end

  it "accepts a model whose name merely contains a suffix word" do
    # `Commander` ends in neither `Command` nor any other listed suffix at the
    # end of the word — a real domain noun must not trip this.
    expect_no_offenses(<<~RUBY, "app/models/commandment.rb")
      class Commandment < ApplicationRecord
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::GenericOperationMethod, :config do
  let(:cop_config) { { "ForbiddenMethods" => %w[call execute run], "AllowedMethods" => %w[perform] } }

  it "flags a generic entry point on a PORO" do
    expect_offense(<<~RUBY)
      class Account::Onboarding
        def call(params)
            ^^^^ `call` says nothing about the domain. Name the verb: `complete`, `import`, `publish`.
        end
      end
    RUBY
  end

  it "flags the class-method form, the classic service-object entry point" do
    expect_offense(<<~RUBY)
      class Account::Onboarding
        def self.call(params)
                 ^^^^ `call` says nothing about the domain. Name the verb: `complete`, `import`, `publish`.
        end
      end
    RUBY
  end

  it "flags a do_-prefixed verb" do
    expect_offense(<<~RUBY)
      def do_publish
          ^^^^^^^^^^ `do_publish` says nothing about the domain. Name the verb: `complete`, `import`, `publish`.
      end
    RUBY
  end

  it "leaves perform alone, because ActiveJob owns that name" do
    expect_no_offenses(<<~RUBY)
      class NotifySubscribersJob < ApplicationJob
        def perform(article_id)
          Article.find(article_id).notify_subscribers
        end
      end
    RUBY
  end

  it "accepts a domain verb" do
    expect_no_offenses(<<~RUBY)
      class Account::Onboarding
        def complete(params)
        end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::ServiceObject, "with the project index", :config do
  let(:cop_config) { { "Suffixes" => %w[Service Manager Handler Interactor Operation Command] } }

  it "accepts a record reached through inheritance the superclass spelling does not reveal" do
    model = <<~RUBY
      class PaymentService < Billing::Record
        def charge; end
      end
    RUBY
    path = index_project({
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base; end\n",
      "app/models/billing/record.rb" => "class Billing::Record < ApplicationRecord; end\n",
      "app/models/payment_service.rb" => model
    }, subject: "app/models/payment_service.rb")

    expect_no_offenses(model, path)
  end
end
