# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Every test must have at least one positive assertion. A test that
      # consists only of `not_to` is not a test — it is a removal receipt" —
      # agent_harness_rails/rules/testing.mdc.
      #
      # An example whose every assertion is `not_to` passes when the page is
      # empty, when the route 404s, and when the feature never existed. It
      # documents nothing a user can do, and it breaks silently the day someone
      # renames the element it is not looking for.
      #
      # `not_to` paired with a positive assertion is fine, and is the rule's own
      # example — confirming a thing disappeared alongside proof of what
      # replaced it.
      #
      # The fix is to *add*, never to convert. When the behaviour under test
      # genuinely is an absence — an unauthorised user sees no edit link, a
      # request is refused — the negative assertion is the one that carries the
      # meaning, and a standalone positive would not say anything. Keep it, and
      # anchor it with a positive assertion about what the example does render,
      # return, or leave unchanged. Rewriting the absence as a range or a
      # comparison satisfies this cop while asserting something weaker than the
      # negative did; AgentHarnessRails/HttpStatusComparison catches the common
      # form of that.
      #
      # @example
      #   # bad
      #   it "does not show the excluded agency" do
      #     expect(page).not_to have_link("New Excluded Agency")
      #   end
      #
      #   # good — the positive assertion carries the test
      #   it "deletes the article" do
      #     click_button "Delete"
      #
      #     expect(page).to have_content("Article deleted.")
      #     expect(page).not_to have_content("To Delete")
      #   end
      #
      #   # good — the absence is the point, so it stays; the positive anchors it
      #   it "does not offer editing to a reader" do
      #     get article_path(article)
      #
      #     expect(response).to have_http_status(:ok)
      #     expect(response.body).not_to include("Edit article")
      #   end
      class NegativeOnlySpec < Base
        MSG = "Every example needs at least one positive assertion — this one only proves " \
              "an absence, so it passes even if the page is empty. Keep the `not_to` and add " \
              "a positive assertion beside it; do not restate the absence as a comparison."
        EXAMPLE_METHODS = %i[it specify example scenario its].freeze
        NEGATIVE_MATCHERS = %i[not_to to_not].freeze

        def_node_search :expectations, "(send (send nil? {:expect :is_expected} ...) {:to :not_to :to_not} ...)"

        def on_block(node)
          return unless example?(node)
          return if node.body.nil?

          assertions = expectations(node).to_a
          return if assertions.empty?
          return unless assertions.all? { |assertion| NEGATIVE_MATCHERS.include?(assertion.method_name) }

          add_offense(node.send_node.loc.selector)
        end
        alias on_numblock on_block

        private

        def example?(node)
          send_node = node.send_node
          send_node.receiver.nil? && EXAMPLE_METHODS.include?(send_node.method_name)
        end
      end
    end
  end
end
