# frozen_string_literal: true

require "spec_helper"

return unless RUBOCOP_AVAILABLE

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
