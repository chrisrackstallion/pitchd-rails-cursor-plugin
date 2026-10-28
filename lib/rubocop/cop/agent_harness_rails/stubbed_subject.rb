# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Prefer real objects over mocks" and the `allow_any_instance_of`
      # anti-pattern — agent_harness_rails/rules/testing.mdc.
      #
      # Stubbing the thing under test means the test passes when the real method
      # is broken, renamed, or deleted. `allow_any_instance_of` is worse again:
      # it reaches into every instance in the process, including ones the test
      # never meant to touch, and it survives refactors that should have failed.
      #
      # @example
      #   # bad
      #   allow_any_instance_of(Article).to receive(:published?).and_return(true)
      #
      #   # bad
      #   allow(described_class).to receive(:new).and_return(double)
      #
      #   # good — a real record in the state the test needs
      #   article = create(:article, :published)
      class StubbedSubject < Base
        MSG_ANY_INSTANCE = "`allow_any_instance_of` stubs every instance in the process. " \
                           "Use a real record, or inject the dependency."
        MSG_DESCRIBED_CLASS = "Stubbing `described_class` tests the stub, not the subject. " \
                              "Exercise the real object."
        RESTRICT_ON_SEND = %i[allow_any_instance_of expect_any_instance_of allow expect].freeze

        def_node_matcher :any_instance?, "(send nil? {:allow_any_instance_of :expect_any_instance_of} ...)"
        def_node_matcher :stubbed_described_class?, "(send nil? {:allow :expect} (send nil? :described_class))"

        def on_send(node)
          if any_instance?(node)
            add_offense(node.loc.selector, message: MSG_ANY_INSTANCE)
          elsif stubbed_described_class?(node) && receives_message?(node)
            add_offense(node, message: MSG_DESCRIBED_CLASS)
          end
        end

        private

        def_node_search :receive_matcher?, "(send _ {:receive :receive_messages :receive_message_chain} ...)"

        # `expect(described_class).to receive(...)` is a stub; a plain
        # `expect(described_class).to eq(Article)` is an ordinary assertion and
        # none of this cop's business.
        #
        # Searched rather than matched on the outermost call, because the matcher
        # is usually chained — `receive(:new).and_return(double)` presents as
        # `and_return`, with the `receive` buried inside it.
        def receives_message?(node)
          parent = node.parent
          return false unless parent.respond_to?(:send_type?) && parent.send_type?
          return false unless %i[to not_to to_not].include?(parent.method_name)

          matcher = parent.first_argument
          !matcher.nil? && receive_matcher?(matcher)
        end
      end
    end
  end
end
