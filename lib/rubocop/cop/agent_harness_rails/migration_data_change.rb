# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Data migrations (backfills) belong in a separate migration file or a
      # rake task — not mixed with DDL" —
      # agent_harness_rails/rules/migrations.mdc.
      #
      # Schema changes run instantly; a backfill can run for hours. Mixed
      # together, a deploy holds a migration lock for the length of the slowest
      # UPDATE, and a failure halfway leaves the schema half-changed with no
      # clean way back.
      #
      # @example
      #   # bad
      #   def change
      #     add_column :articles, :slug, :string
      #     Article.find_each { |a| a.update!(slug: a.title.parameterize) }
      #   end
      #
      #   # good — schema here, backfill in its own migration or a rake task
      #   def change
      #     add_column :articles, :slug, :string
      #   end
      class MigrationDataChange < Base
        MSG = "`%<name>s` is a data change. Put the backfill in its own migration or a rake task, " \
              "so the schema change stays instant."
        RESTRICT_ON_SEND = %i[update_all delete_all insert_all upsert_all find_each update! save!].freeze

        def on_send(node)
          return if node.receiver.nil?

          add_offense(node.loc.selector, message: format(MSG, name: node.method_name))
        end
      end
    end
  end
end
