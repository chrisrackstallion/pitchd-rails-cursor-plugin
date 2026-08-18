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
