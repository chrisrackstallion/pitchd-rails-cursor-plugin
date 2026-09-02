# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "An assertion must be able to fail for the reason it exists" —
      # agent_harness_rails/rules/testing.mdc.
      #
      # `expect(policy).to be_a(described_class)` is true the moment the example
      # is written. No change to the application can turn it red, so it proves
      # nothing and — the reason this cop exists — it anchors nothing. This is the
      # shape a positive assertion takes when one is added to satisfy a rule
      # rather than to test something: the example gets longer, the reviewer reads
      # a green assertion, and the absence beside it is as unanchored as it was.
      #
      # An anchor has to be something the code could get wrong: the status the
      # request returns, a landmark the page must show, the state the record is
      # left in.
      #
      # @example
      #   # bad — the subject is an instance of the class under test by construction
      #   expect(policy).to be_a(described_class)
      #
      #   # bad — the class exists because the file loaded
      #   expect(described_class).not_to be_nil
      #
      #   # good — the decision the policy actually made
      #   expect(policy.destroy?).to be false
      class TautologicalAssertion < Base
        MSG = "`%<source>s` cannot be turned red by any change to the application — it proves " \
              "nothing, and it anchors nothing. Assert something the code could get wrong."

        # `expect(anything).to be_a(described_class)`: in a spec that describes
        # that class, the subject is an instance of it by construction.
        def_node_matcher :class_identity_assertion?, <<~PATTERN
          (send {(send nil? :expect _) (send nil? :is_expected)} {:to :not_to :to_not}
            (send nil? {:be_a :be_an :be_instance_of :be_kind_of} (send nil? :described_class)))
        PATTERN

        # `expect(described_class).to be_present` and friends: the constant
        # resolved when the file loaded, or the example would have errored.
        def_node_matcher :class_existence_assertion?, <<~PATTERN
          (send (send nil? :expect (send nil? :described_class)) {:to :not_to :to_not}
            (send nil? {:be_present :be_truthy :be_nil :be_falsey} ...))
        PATTERN

        def on_send(node)
          return unless class_identity_assertion?(node) || class_existence_assertion?(node)

          add_offense(node, message: format(MSG, source: node.source))
        end
      end
    end
  end
end
