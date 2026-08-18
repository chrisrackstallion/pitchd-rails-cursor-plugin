# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # "Permission methods: CRUD action + `?` only — no custom verbs" —
      # agent_harness_rails/rules/naming.mdc, and the matching anti-pattern in
      # agent_harness_rails/rules/policies.mdc.
      #
      # A `publish?` on ArticlePolicy is the same signal as a `publish` action on
      # ArticlesController: the state change wants to be CRUD on a noun resource,
      # so it becomes `create?` on Articles::PublicationPolicy. Keeping policies
      # to the CRUD set is what makes "one policy method per controller action"
      # a checkable claim rather than a hope.
      #
      # Private predicates are untouched — `owner_or_admin?` is the rule's own
      # example of composing a policy method.
      #
      # @example
      #   # bad
      #   class ArticlePolicy < ApplicationPolicy
      #     def publish? = user.editor?
      #   end
      #
      #   # good
      #   class Articles::PublicationPolicy < ApplicationPolicy
      #     def create? = user.editor?
      #   end
      class PolicyVerbMethod < Base
        MSG = "`%<name>s` is not a CRUD permission. Map the state change to a noun-resource " \
              "policy (Articles::PublicationPolicy#create?), or make this a private predicate."

        def on_class(node)
          public_predicates(node.body).each do |method|
            name = method.method_name.to_s
            next if allowed?(name)

            add_offense(method.loc.name, message: format(MSG, name: name))
          end
        end

        private

        def public_predicates(body)
          return [] if body.nil?

          nodes = body.begin_type? ? body.children : [ body ]
          nodes.take_while { |child| !visibility_modifier?(child) }
               .select { |child| child.is_a?(RuboCop::AST::DefNode) && child.method_name.to_s.end_with?("?") }
        end

        def visibility_modifier?(node)
          node.respond_to?(:send_type?) && node.send_type? &&
            node.receiver.nil? && node.arguments.empty? &&
            %i[private protected].include?(node.method_name)
        end

        def allowed?(name)
          cop_config.fetch("AllowedMethods", []).include?(name)
        end
      end
    end
  end
end
