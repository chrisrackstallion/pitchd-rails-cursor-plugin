# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Request specs own rendering — never write view specs" —
      # agent_harness_rails/rules/testing.mdc, which states this without
      # exception.
      #
      # A view spec renders a template in isolation with stubbed assigns, so it
      # proves the template works against data no controller ever produces. A
      # request spec renders the same template through the real stack, where the
      # assigns are the ones the app actually builds.
      #
      # @example
      #   # bad — spec/views/articles/show.html.erb_spec.rb
      #   RSpec.describe "articles/show", type: :view do
      #     it "shows the title" do
      #       assign(:article, build_stubbed(:article, title: "Hello"))
      #       render
      #       expect(rendered).to include("Hello")
      #     end
      #   end
      #
      #   # good — spec/requests/articles_spec.rb
      #   it "shows the title" do
      #     get article_path(article)
      #     expect(response.body).to include("Hello")
      #   end
      class ViewSpec < Base
        MSG_TYPE = "View specs are never written. Test rendering through a request spec, " \
                   "where the assigns are the ones the app really builds."
        MSG_PATH = "spec/views/ holds view specs, which are never written. Move these to " \
                   "spec/requests/ and assert on `response.body`."

        def_node_matcher :view_type?, "(pair (sym :type) (sym :view))"

        def on_new_investigation
          return unless in_views_directory?
          return if processed_source.blank?

          add_offense(processed_source.buffer.line_range(1), message: MSG_PATH)
        end

        def on_pair(node)
          return unless view_type?(node)

          add_offense(node, message: MSG_TYPE)
        end

        private

        def in_views_directory?
          processed_source.path.to_s.include?("spec/views/")
        end
      end
    end
  end
end
