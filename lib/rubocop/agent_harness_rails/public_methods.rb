# frozen_string_literal: true

module RuboCop
  module Cop
    module AgentHarnessRails
      # The public `def`s of a class body: everything before the first bare
      # `private` or `protected`, which is where the controller and policy rules
      # put their helpers.
      module PublicMethods
        private

        def public_defs(body)
          return [] if body.nil?

          nodes = body.begin_type? ? body.children : [ body ]
          nodes.take_while { |child| !visibility_modifier?(child) }.select { |child| child.is_a?(RuboCop::AST::DefNode) }
        end

        def visibility_modifier?(node)
          node.respond_to?(:send_type?) && node.send_type? &&
            node.receiver.nil? && node.arguments.empty? &&
            %i[private protected].include?(node.method_name)
        end
      end
    end
  end
end
