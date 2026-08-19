# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # A response status is an identity, not a magnitude —
      # agent_harness_rails/rules/testing.mdc.
      #
      # `expect(response.status).to be < 403` is not a weaker version of
      # `expect(response).to have_http_status(:forbidden)`; it is a different
      # assertion, and a much emptier one. It passes on 200, on 302, on 404, on a
      # route that does not exist — every status the example never meant to
      # accept, plus the one it did. The same goes for `be_between(200, 299)` and
      # `be >= 400`: a band of statuses is never the behaviour under test.
      #
      # This exists because of where it comes from. The shape appears when an
      # example that correctly said `not_to have_http_status(:forbidden)` gets
      # rewritten to satisfy AgentHarnessRails/NegativeOnlySpec — the negative is
      # converted into an inequality rather than joined by a positive assertion,
      # and the example ends up asserting less than it did before the fix. When
      # the behaviour is "not this status", say that, and add a positive
      # assertion beside it.
      #
      # @example
      #   # bad
      #   expect(response.status).to be < 403
      #
      #   # bad
      #   expect(response.status).to be_between(200, 299)
      #
      #   # bad
      #   expect(response.status < 400).to be true
      #
      #   # good — the status the request does return
      #   expect(response).to have_http_status(:ok)
      #
      #   # good — the refusal itself, when that is the behaviour
      #   expect(response).to have_http_status(:forbidden)
      #
      #   # good — "not forbidden", paired with what the request does do
      #   expect(response).to have_http_status(:ok)
      #   expect(response).not_to have_http_status(:forbidden)
      class HttpStatusComparison < Base
        MSG = "Assert the status, not a range around it: `have_http_status(:ok)`. A comparison " \
              "also passes for every other status on its side of the number — if the behaviour " \
              "is \"not this status\", write `not_to have_http_status(...)` with a positive " \
              "assertion beside it."

        COMPARISONS = %i[< <= > >=].freeze
        RANGE_MATCHERS = %i[be_between be_within].freeze

        # `response.status`, `response.code`, `last_response.status`,
        # `page.status_code` — the readers that hold a bare status code, with or
        # without the `to_i` that `response.code` usually needs.
        def_node_matcher :status_reader?, <<~PATTERN
          {
            (send {(send nil? :response) (send nil? :last_response)} {:status :code})
            (send (send nil? :page) :status_code)
          }
        PATTERN

        def_node_matcher :status_expression?, <<~PATTERN
          {#status_reader? (send #status_reader? :to_i)}
        PATTERN

        # expect(response.status).to <matcher>
        def_node_matcher :status_expectation, <<~PATTERN
          (send (send nil? :expect #status_expression?) {:to :not_to :to_not} $_)
        PATTERN

        def on_send(node)
          matcher = status_expectation(node)
          return add_offense(matcher) if matcher && ranged?(matcher)

          add_offense(node) if bare_comparison?(node)
        end

        private

        def ranged?(matcher)
          return false unless matcher.send_type?

          RANGE_MATCHERS.include?(matcher.method_name) || COMPARISONS.include?(matcher.method_name)
        end

        # `expect(response.status < 400).to be true`, and the same comparison in
        # an `assert` or a guard — the status still gets compared rather than
        # named.
        def bare_comparison?(node)
          return false unless COMPARISONS.include?(node.method_name)

          status_expression?(node.receiver) || node.arguments.any? { |argument| status_expression?(argument) }
        end
      end
    end
  end
end
