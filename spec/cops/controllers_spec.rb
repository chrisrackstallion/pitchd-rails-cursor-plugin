# frozen_string_literal: true

require "spec_helper"
require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::NonRestfulAction, :config do
  let(:cop_config) { { "AllowedActions" => %w[index show new create edit update destroy] } }

  it "flags a verb action on a resource controller" do
    expect_offense(<<~RUBY)
      class ArticlesController < ApplicationController
        def publish
            ^^^^^^^ `publish` is not a REST action. Extract a noun resource with CRUD actions, or move it below `private` if it is a helper.
        end
      end
    RUBY
  end

  it "accepts the seven standard actions" do
    expect_no_offenses(<<~RUBY)
      class ArticlesController < ApplicationController
        def index; end
        def show; end
        def new; end
        def create; end
        def edit; end
        def update; end
        def destroy; end
      end
    RUBY
  end

  it "accepts finders and strong parameters below private" do
    # The rule's own controller puts these under private; flagging them would
    # make the cop fight the example it enforces.
    expect_no_offenses(<<~RUBY)
      class ArticlesController < ApplicationController
        def show; end

        private
          def set_article
            @article = Article.find(params[:id])
          end

          def article_params
            params.expect(article: [:title])
          end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::CsrfSkip, :config do
  it "flags skipping the authenticity token check" do
    expect_offense(<<~RUBY)
      class ApiController < ApplicationController
        skip_before_action :verify_authenticity_token
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not skip CSRF verification. If a signed endpoint genuinely needs it, exclude that file in .rubocop.yml as a deliberate, reviewed decision.
      end
    RUBY
  end

  it "flags the shorthand too" do
    expect_offense(<<~RUBY)
      class ApiController < ApplicationController
        skip_forgery_protection
        ^^^^^^^^^^^^^^^^^^^^^^^ Do not skip CSRF verification. If a signed endpoint genuinely needs it, exclude that file in .rubocop.yml as a deliberate, reviewed decision.
      end
    RUBY
  end

  it "leaves other skipped callbacks alone" do
    expect_no_offenses(<<~RUBY)
      class SessionsController < ApplicationController
        skip_before_action :require_authentication
        skip_after_action :verify_authorized
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::DeepNestedResources, :config do
  let(:cop_config) { { "Max" => 2 } }

  it "flags a third level of nesting" do
    expect_offense(<<~RUBY)
      Rails.application.routes.draw do
        resources :projects do
          resources :tasks do
            resources :comments do
            ^^^^^^^^^ Nested 3 deep. Use `shallow: true`, or split this into a top-level resource.
              resources :reactions
              ^^^^^^^^^ Nested 4 deep. Use `shallow: true`, or split this into a top-level resource.
            end
          end
        end
      end
    RUBY
  end

  it "flags a deep leaf resource that has no block of its own" do
    # The routes rule's own bad example ends in a plain `resources :comments`,
    # so a cop that only looked at blocks would miss the exact shape it exists
    # to catch.
    expect_offense(<<~RUBY)
      Rails.application.routes.draw do
        resources :projects do
          resources :tasks do
            resources :comments
            ^^^^^^^^^ Nested 3 deep. Use `shallow: true`, or split this into a top-level resource.
          end
        end
      end
    RUBY
  end

  it "accepts one level of nesting" do
    expect_no_offenses(<<~RUBY)
      Rails.application.routes.draw do
        resources :projects do
          resources :tasks
        end
      end
    RUBY
  end

  it "accepts a deep nest that shallows" do
    expect_no_offenses(<<~RUBY)
      Rails.application.routes.draw do
        resources :projects, shallow: true do
          resources :tasks do
            resources :comments do
              resources :reactions
            end
          end
        end
      end
    RUBY
  end

  it "accepts the scope module pattern the controllers rule documents" do
    # `scope module:` is how a noun resource gets a namespaced controller; it is
    # not another level of URL nesting.
    expect_no_offenses(<<~RUBY)
      Rails.application.routes.draw do
        resources :cards do
          scope module: :cards do
            resource :closure
          end
        end
      end
    RUBY
  end
end
