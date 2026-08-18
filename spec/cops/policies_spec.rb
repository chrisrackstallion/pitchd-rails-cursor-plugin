# frozen_string_literal: true

require "spec_helper"
require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::PolicyVerbMethod, :config do
  let(:cop_config) { { "AllowedMethods" => %w[index? show? new? create? edit? update? destroy?] } }

  it "flags a custom verb permission" do
    expect_offense(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def publish?
            ^^^^^^^^ `publish?` is not a CRUD permission. Map the state change to a noun-resource policy (Articles::PublicationPolicy#create?), or make this a private predicate.
          user.editor?
        end
      end
    RUBY
  end

  it "accepts the CRUD set" do
    expect_no_offenses(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def index?
          true
        end

        def update?
          owner_or_admin?
        end
      end
    RUBY
  end

  it "accepts private predicates that compose a permission" do
    # `owner_or_admin?` is the rule's own example of composing a policy method.
    expect_no_offenses(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def update?
          owner_or_admin?
        end

        private
          def owner_or_admin?
            record.creator == user || user.admin?
          end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::PolicyContext, :config do
  it "flags a policy reaching for the request" do
    expect_offense(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def update?
          user.admin? || params[:token] == record.share_token
                         ^^^^^^ A policy sees only `user` and `record`; `params` belongs to the controller.
        end
      end
    RUBY
  end

  it "accepts a policy composing model predicates" do
    expect_no_offenses(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def update?
          user.admin? || record.shared_with?(user)
        end
      end
    RUBY
  end
end
