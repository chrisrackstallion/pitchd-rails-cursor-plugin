# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Everything maps to CRUD" — agent_harness_rails/rules/controllers.mdc,
      # and "Seven standard REST actions only" —
      # agent_harness_rails/rules/naming.mdc.
      #
      # A public controller method outside the seven REST actions is the signal
      # to extract a resource: `publish` on ArticlesController wants to be
      # `create` on Articles::PublicationsController.
      #
      # Only public methods are flagged. Finders, strong-parameter methods, and
      # other helpers live under `private`, which is where the rule's own
      # example puts them.
      #
      # @example
      #   # bad
      #   class ArticlesController < ApplicationController
      #     def publish
      #       @article.publish
      #     end
      #   end
      #
      #   # good — a noun resource with a CRUD action
      #   class Articles::PublicationsController < ApplicationController
      #     def create
      #       @article.publish
      #     end
      #   end
      class NonRestfulAction < Base
        MSG = "`%<name>s` is not a REST action. Extract a noun resource with CRUD actions, " \
              "or move it below `private` if it is a helper."

        def on_class(node)
          public_methods_in(node.body).each do |method|
            next if allowed?(method.method_name.to_s)

            add_offense(method.loc.name, message: format(MSG, name: method.method_name))
          end
        end

        private

        # Walks the class body in order, stopping at the first bare `private` or
        # `protected` — everything after it is out of scope for this cop.
        def public_methods_in(body)
          return [] if body.nil?

          nodes = body.begin_type? ? body.children : [ body ]
          nodes.take_while { |child| !visibility_modifier?(child) }.select { |child| child.is_a?(RuboCop::AST::DefNode) }
        end

        def visibility_modifier?(node)
          node.respond_to?(:send_type?) && node.send_type? &&
            node.receiver.nil? && node.arguments.empty? &&
            %i[private protected].include?(node.method_name)
        end

        def allowed?(name)
          cop_config.fetch("AllowedActions", []).include?(name)
        end
      end
    end
  end
end
