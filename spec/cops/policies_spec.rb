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

RSpec.describe RuboCop::Cop::AgentHarnessRails::PolicyRecordPredicate, :config do
  it "flags a policy comparing a record attribute" do
    expect_offense(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def update?
          record.creator == user || record.status == "draft"
          ^^^^^^^^^^^^^^ Ask the record, don't interrogate it: replace `record.creator` with a predicate the model defines (`record.created_by?(user)`, `record.draft?`).
                                    ^^^^^^^^^^^^^ Ask the record, don't interrogate it: replace `record.status` with a predicate the model defines (`record.created_by?(user)`, `record.draft?`).
        end
      end
    RUBY
  end

  it "flags a policy walking an association, even to a predicate" do
    expect_offense(<<~RUBY)
      class CardPolicy < ApplicationPolicy
        def update?
          record.board.members.include?(user)
          ^^^^^^^^^^^^ Ask the record, don't interrogate it: replace `record.board` with a predicate the model defines (`record.created_by?(user)`, `record.draft?`).
        end
      end
    RUBY
  end

  it "accepts who and what asked through the record's predicates" do
    expect_no_offenses(<<~RUBY)
      class ArticlePolicy < ApplicationPolicy
        def update?
          user.admin? || (record.created_by?(user) && !record.archived?)
        end
      end
    RUBY
  end
end
