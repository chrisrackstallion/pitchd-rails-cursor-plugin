# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "A policy asks the record; it never interrogates it" —
      # agent_harness_rails/rules/policies.mdc.
      #
      # A policy decides who may act and whether the record's state allows it,
      # but the meaning of that state belongs to the model. Reading an attribute
      # or walking an association (`record.status == "draft"`,
      # `record.board.members.include?(user)`) copies a domain rule into the
      # policy, where it drifts from the model's own. Every call on `record` is
      # therefore a predicate the model defines.
      #
      # @example
      #   # bad
      #   def update?
      #     record.creator == user && record.status == "draft"
      #   end
      #
      #   # good
      #   def update?
      #     record.created_by?(user) && record.draft?
      #   end
      class PolicyRecordPredicate < Base
        MSG = "Ask the record, don't interrogate it: replace `record.%<name>s` with a predicate " \
              "the model defines (`record.created_by?(user)`, `record.draft?`)."

        def_node_matcher :record_call, "(call (send nil? :record) $_ ...)"

        def on_send(node)
          record_call(node) do |name|
            next if name.to_s.end_with?("?") || name == :!

            add_offense(node, message: format(MSG, name: name))
          end
        end
        alias on_csend on_send
      end
    end
  end
end
