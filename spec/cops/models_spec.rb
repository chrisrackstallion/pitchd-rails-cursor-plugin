# frozen_string_literal: true

require "spec_helper"
require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::EnqueueOutsideCommit, :config do
  it "flags an enqueue inline in a non-commit callback" do
    expect_offense(<<~RUBY)
      class Article < ApplicationRecord
        after_create { NotifySubscribersJob.perform_later(id) }
        ^^^^^^^^^^^^ Enqueueing in `after_create` runs inside the transaction — the job can run before the commit, or after a rollback. Use `after_create_commit`.
      end
    RUBY
  end

  it "follows a callback through to the method it names" do
    expect_offense(<<~RUBY)
      class Article < ApplicationRecord
        after_save :notify_subscribers_later
        ^^^^^^^^^^ Enqueueing in `after_save` runs inside the transaction — the job can run before the commit, or after a rollback. Use `after_save_commit`.

        private
          def notify_subscribers_later
            NotifySubscribersJob.perform_later(id)
          end
      end
    RUBY
  end

  it "flags mail the same way as jobs" do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        after_create :send_welcome
        ^^^^^^^^^^^^ Enqueueing in `after_create` runs inside the transaction — the job can run before the commit, or after a rollback. Use `after_create_commit`.

        private
          def send_welcome
            WelcomeMailer.with(user: self).welcome.deliver_later
          end
      end
    RUBY
  end

  it "accepts the commit variants" do
    expect_no_offenses(<<~RUBY)
      class Article < ApplicationRecord
        after_create_commit :notify_subscribers_later
        after_update_commit { BroadcastJob.perform_later(id) }

        private
          def notify_subscribers_later
            NotifySubscribersJob.perform_later(id)
          end
      end
    RUBY
  end

  it "accepts a non-commit callback that derives data rather than enqueueing" do
    expect_no_offenses(<<~RUBY)
      class Article < ApplicationRecord
        before_save :set_slug

        private
          def set_slug
            self.slug = title.parameterize
          end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::MailerDeliverNow, :config do
  it "flags deliver_now and corrects it" do
    expect_offense(<<~RUBY)
      UserMailer.with(user: user).welcome.deliver_now
                                          ^^^^^^^^^^^ Use `deliver_later` so sending does not block the request.
    RUBY

    expect_correction(<<~RUBY)
      UserMailer.with(user: user).welcome.deliver_later
    RUBY
  end

  it "flags the bang form and corrects it to deliver_later!" do
    expect_offense(<<~RUBY)
      UserMailer.with(user: user).welcome.deliver_now!
                                          ^^^^^^^^^^^^ Use `deliver_later!` so sending does not block the request.
    RUBY

    expect_correction(<<~RUBY)
      UserMailer.with(user: user).welcome.deliver_later!
    RUBY
  end

  it "accepts deliver_later" do
    expect_no_offenses("UserMailer.with(user: user).welcome.deliver_later\n")
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::MigrationDataChange, :config do
  it "flags a backfill mixed into a schema change" do
    expect_offense(<<~RUBY)
      class AddSlugToArticles < ActiveRecord::Migration[8.0]
        def change
          add_column :articles, :slug, :string
          Article.update_all(slug: "")
                  ^^^^^^^^^^ `update_all` is a data change. Put the backfill in its own migration or a rake task, so the schema change stays instant.
        end
      end
    RUBY
  end

  it "accepts a migration that only changes the schema" do
    expect_no_offenses(<<~RUBY)
      class AddSlugToArticles < ActiveRecord::Migration[8.0]
        def change
          add_column :articles, :slug, :string
          add_index :articles, :slug, unique: true
        end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::EnqueueOutsideCommit, "with the project index", :config do
  it "follows a callback into the method a concern defines" do
    model = <<~RUBY
      class Article < ApplicationRecord
        include Notifying
        after_save :notify_later
        ^^^^^^^^^^ Enqueueing in `after_save` runs inside the transaction — the job can run before the commit, or after a rollback. Use `after_save_commit`.
      end
    RUBY
    path = index_project({
      "app/models/concerns/notifying.rb" => "module Notifying\n  def notify_later\n    NotifySubscribersJob.perform_later(id)\n  end\nend\n",
      "app/models/article.rb" => model
    }, subject: "app/models/article.rb")

    expect_offense(model, path)
  end

  it "follows a concern's included-block callback into the method each includer defines" do
    concern = <<~RUBY
      module Notifying
        extend ActiveSupport::Concern

        included do
          after_create :notify_later
          ^^^^^^^^^^^^ Enqueueing in `after_create` runs inside the transaction — the job can run before the commit, or after a rollback. Use `after_create_commit`.
        end
      end
    RUBY
    path = index_project({
      "app/models/article.rb" => "class Article < ApplicationRecord\n  include Notifying\n\n  private\n    def notify_later\n      NotifySubscribersJob.perform_later(id)\n    end\nend\n",
      "app/models/concerns/notifying.rb" => concern
    }, subject: "app/models/concerns/notifying.rb")

    expect_offense(concern, path)
  end

  it "stays quiet when the method it finds elsewhere does not enqueue" do
    model = <<~RUBY
      class Article < ApplicationRecord
        include Sluggable
        after_save :refresh_slug
      end
    RUBY
    path = index_project({
      "app/models/concerns/sluggable.rb" => "module Sluggable\n  def refresh_slug\n    update_column(:slug, title.parameterize)\n  end\nend\n",
      "app/models/article.rb" => model
    }, subject: "app/models/article.rb")

    expect_no_offenses(model, path)
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::MailerWithoutPreview, :config do
  it "flags a mailer with no preview class" do
    mailer = <<~RUBY
      class UserMailer < ApplicationMailer
            ^^^^^^^^^^ `UserMailer` has no `UserMailerPreview`. Every mail is previewable in development.
        def welcome; end
      end
    RUBY
    path = index_project({ "app/mailers/user_mailer.rb" => mailer }, subject: "app/mailers/user_mailer.rb")

    expect_offense(mailer, path)
  end

  it "flags each mail the preview leaves out, wherever the preview lives" do
    mailer = <<~RUBY
      class UserMailer < ApplicationMailer
        def welcome; end
        def receipt; end
            ^^^^^^^ `UserMailer#receipt` has no method on `UserMailerPreview`.

        private
          def footer; end
      end
    RUBY
    path = index_project({
      "spec/mailers/previews/user_mailer_preview.rb" => "class UserMailerPreview < ActionMailer::Preview\n  def welcome; end\nend\n",
      "app/mailers/user_mailer.rb" => mailer
    }, subject: "app/mailers/user_mailer.rb")

    expect_offense(mailer, path)
  end

  it "does nothing without the project index" do
    expect_no_offenses(<<~RUBY)
      class UserMailer < ApplicationMailer
        def welcome; end
      end
    RUBY
  end
end

RSpec.describe RuboCop::Cop::AgentHarnessRails::UnreferencedMethod, :config do
  let(:cop_config) do
    { "AllowedMethods" => %w[initialize], "AllowedPatterns" => [ '\Ato_' ],
      "TemplateGlobs" => [ File.join(project, "app/views/**/*.erb") ] }
  end
  let(:model) do
    <<~RUBY
      class Article < ApplicationRecord
        def legacy_slug
          title.parameterize
        end
      end
    RUBY
  end

  it "flags a method nothing in the project mentions" do
    flagged = <<~RUBY
      class Article < ApplicationRecord
        def legacy_slug
            ^^^^^^^^^^^ Nothing in the project calls `legacy_slug` — no call, symbol, or template mentions it. Delete it, or name the caller RuboCop cannot see in `AllowedMethods`.
          title.parameterize
        end
      end
    RUBY
    path = index_project({ "app/models/article.rb" => flagged }, subject: "app/models/article.rb")

    expect_offense(flagged, path)
  end

  it "counts a call from any indexed file" do
    path = index_project({
      "app/models/article.rb" => model,
      "app/models/feed.rb" => "class Feed\n  def entries\n    Article.all.map { |article| article.legacy_slug }\n  end\nend\n"
    }, subject: "app/models/article.rb")

    expect_no_offenses(model, path)
  end

  it "counts the name as a symbol in another file, which is how callbacks and delegate name their targets" do
    path = index_project({
      "app/models/article.rb" => model,
      "app/models/post.rb" => "class Post < ApplicationRecord\n  delegate :legacy_slug, to: :article\nend\n"
    }, subject: "app/models/article.rb")

    expect_no_offenses(model, path)
  end

  it "counts a mention in a view template, which the index never sees" do
    FileUtils.mkdir_p(File.join(project, "app/views/articles"))
    File.write(File.join(project, "app/views/articles/show.html.erb"), "<p><%= @article.legacy_slug %></p>\n")
    path = index_project({ "app/models/article.rb" => model }, subject: "app/models/article.rb")

    expect_no_offenses(model, path)
  end

  it "leaves a policy's public predicates alone, since Pundit dispatches to them by name" do
    policy = <<~RUBY
      class ArticlePolicy < ApplicationPolicy
        def show?
          true
        end
      end
    RUBY
    path = index_project({ "app/policies/article_policy.rb" => policy }, subject: "app/policies/article_policy.rb")

    expect_no_offenses(policy, path)
  end

  it "leaves an override of an inherited method alone" do
    override = <<~RUBY
      class Article < Content
        def summary
          title
        end
      end
    RUBY
    path = index_project({
      "app/models/content.rb" => "class Content < ApplicationRecord\n  def summary\n    body.truncate(80)\n  end\nend\n",
      "app/models/article.rb" => override
    }, subject: "app/models/article.rb")

    expect_no_offenses(override, path)
  end

  it "does nothing without the project index" do
    expect_no_offenses(model)
  end
end
