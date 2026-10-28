# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "An assertion must be able to fail for the reason it exists" —
      # agent_harness_rails/rules/testing.mdc.
      #
      # A negative assertion is not suspect for being negative. It is suspect
      # when the thing it looks at is a **by-product of machinery that can fail
      # into the passing side**: a rendered page, a response status, a record
      # reloaded after a request. `expect(page).not_to have_button("Delete")`
      # passes when the button is correctly hidden, and equally when the request
      # 500s, when the route is gone, and when the page renders blank. Every one
      # of those is a failure the example is not about, and the negation absorbs
      # all of them.
      #
      # A negation whose verdict comes straight back from the unit under test is
      # sound and gets no complaint from this cop, because nothing sits in
      # between to fail quietly:
      #
      #   expect(policy).not_to permit(reader, article)   # the policy answered
      #   expect(article).not_to be_published             # the record answered
      #   expect { card.reopen }.not_to raise_error       # the method ran
      #
      # So the cop fires on a negative-only example only when it observes a
      # document or a response (`DocumentSubjects`, `DocumentMatchers`), or when
      # it drives a request or a browser first (`ActionMethods`) — the two shapes
      # where a silent breakage lands on the passing side.
      #
      # The fix is an anchor: one assertion that goes red when the machinery
      # breaks. It must be something the code could get wrong —
      # `expect(policy).to be_a(described_class)` is true by construction and
      # anchors nothing (AgentHarnessRails/TautologicalAssertion).
      #
      # @example
      #   # bad — a 500, a blank page and a missing route all pass
      #   it "does not offer deleting to a reader" do
      #     visit article_path(article)
      #
      #     expect(page).not_to have_button("Delete")
      #   end
      #
      #   # good — the landmark proves the page rendered; the absence is the point
      #   it "does not offer deleting to a reader" do
      #     visit article_path(article)
      #
      #     expect(page).to have_content(article.title)
      #     expect(page).not_to have_button("Delete")
      #   end
      #
      #   # good — nothing between the example and the verdict, so nothing to anchor
      #   it "denies destroy to the account owner" do
      #     expect(policy).not_to permit(owner, account)
      #   end
      class UnanchoredAbsence < Base
        MSG = "This example asserts only absences, and what it looks at can be absent for " \
              "reasons the example is not about — a redirect, a blank render, a 500 all pass. " \
              "Anchor it with one assertion that goes red when the request breaks, and keep the " \
              "`not_to`. An assertion that cannot fail is not an anchor."

        EXAMPLE_METHODS = %i[it specify example scenario its].freeze
        NEGATIVE_MATCHERS = %i[not_to to_not].freeze

        # `expect(x).to`, `is_expected.to`, and the block form `expect { }.to` —
        # the last one is how `not_to change` and `not_to raise_error` are always
        # written, so a matcher that only understood the value form would miss
        # the negations that matter most.
        def_node_matcher :expectation?, <<~PATTERN
          (send {(send nil? {:expect :is_expected} ...) (block (send nil? :expect) ...)} {:to :not_to :to_not} ...)
        PATTERN

        def on_block(node)
          return unless example?(node)
          return if node.body.nil?

          assertions = expectations_in(node.body)
          return if assertions.empty?
          return unless assertions.all? { |assertion| NEGATIVE_MATCHERS.include?(assertion.method_name) }
          return unless assertions.any? { |assertion| document_observation?(assertion) } || drives_machinery?(node.body)

          add_offense(node.send_node.loc.selector)
        end
        alias on_numblock on_block

        private

        def example?(node)
          send_node = node.send_node
          send_node.receiver.nil? && EXAMPLE_METHODS.include?(send_node.method_name)
        end

        def expectations_in(body)
          candidates = body.each_descendant(:send).to_a
          candidates.unshift(body) if body.send_type?
          candidates.select { |candidate| expectation?(candidate) }
        end

        # Either half gives it away: `expect(response)` names the response
        # whatever it then asks, and `not_to have_content` reads a document
        # whatever it was handed.
        def document_observation?(assertion)
          document_subject?(assertion.receiver) || document_matcher?(assertion.first_argument)
        end

        def document_subject?(receiver)
          return false unless receiver.send_type? && receiver.method_name == :expect

          subject = receiver.first_argument
          return false if subject.nil?

          config_list("DocumentSubjects").include?(root_receiver_name(subject))
        end

        # `response.body`, `page.find(...)`, `last_response.status` — walk to the
        # name at the bottom, which is the object actually being read.
        def root_receiver_name(node)
          node = node.receiver while node.respond_to?(:receiver) && node.receiver

          node.respond_to?(:method_name) ? node.method_name.to_s : nil
        end

        def document_matcher?(matcher)
          matcher.respond_to?(:method_name) && config_list("DocumentMatchers").include?(matcher.method_name.to_s)
        end

        # A request or a browser interaction anywhere in the example — including
        # inside an `expect { }` block, which is where `post` sits in
        # `expect { post ... }.not_to change(Article, :count)`.
        def drives_machinery?(body)
          nodes = body.each_descendant(:send).to_a
          nodes.unshift(body) if body.send_type?

          nodes.any? { |node| config_list("ActionMethods").include?(node.method_name.to_s) }
        end

        def config_list(key)
          cop_config.fetch(key, [])
        end
      end
    end
  end
end
