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
      # `create` on Articles::PublicationsController, routed as
      # `resource :publication` inside `resources :articles`.
      #
      # The fix is a new controller, not a new route to this one. Folding the
      # action names into `params[:id]` and serving them all from `show` clears
      # the cop while keeping the RPC shape it exists to find — one controller
      # branching on a verb, now with the verb hidden in a path segment that
      # claims to identify a record. If the actions are genuinely one resource,
      # they are `create`/`destroy` on that resource; if they are not, they are
      # separate controllers.
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
      #
      #   # bad — the same RPC controller, with the verbs moved into the id
      #   class ArticlesController < ApplicationController
      #     def show
      #       @article.public_send(params[:id])
      #     end
      #   end
      class NonRestfulAction < Base
        MSG = "`%<name>s` is not a REST action. Extract the noun it implies into a controller " \
              "of its own, routed as a singular `resource` under the parent (`publish` -> " \
              "`Articles::PublicationsController#create`), or move it below `private` if it is a " \
              "helper. Not a `show` that reads the action name out of `params[:id]`."

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
